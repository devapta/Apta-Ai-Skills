#!/usr/bin/env bash
#
# scripts/test-apta-investigate.sh — end-to-end test of the apta-investigate
# scripts against throwaway Postgres, Loki and Grafana containers.
#
# Proves the guarantees the skill makes:
#   - writes are rejected (by the script and, failing that, by the server)
#   - the row cap and the statement timeout hold
#   - no Environment Secret ever appears in any output, errors included
#   - Docker leaves no containers behind, even after an interrupted run
#   - Grafana mode reaches Loki through Grafana's data source proxy
#   - unconfigured Evidence Sources exit 3 instead of failing
#   - the Claude Code hook denies tool calls into secrets/
#
# Needs Docker, curl and jq. Downloads postgres, loki, grafana and logcli images
# on first run. Nothing outside a temp directory and the containers it starts
# (all removed at exit) is touched.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SK="$REPO/skills/apta-investigate/scripts"
PG_IMAGE="postgres:17-alpine"
LOKI_IMAGE="grafana/loki:3.7.10"
GRAFANA_IMAGE="grafana/grafana:13.2"
ID="apta-it-$$"
NET="$ID-net"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { pass=$((pass + 1)); echo "  ok  $*"; }
for t in docker curl jq; do command -v "$t" >/dev/null || fail "$t is required"; done
docker info >/dev/null 2>&1 || fail "Docker is not running"

tmp="$(mktemp -d)"
ALL_OUT="$tmp/all-output.log"   # every line any skill script printed, scanned for secrets at the end
: >"$ALL_OUT"
cleanup() {
  docker rm -f "$ID-pg" "$ID-loki" "$ID-grafana" >/dev/null 2>&1
  docker network rm "$NET" >/dev/null 2>&1
  docker ps -aq --filter label=apta-investigate | xargs -r docker rm -f >/dev/null 2>&1
  rm -rf "$tmp"
}
trap cleanup EXIT

# run NAME EXPECTED_RC CMD... : runs CMD, records its output, checks its exit code.
OUT=""
run() {
  local name="$1" want="$2"; shift 2
  OUT="$("$@" 2>&1)"; local rc=$?
  printf '%s\n' "$OUT" >>"$ALL_OUT"
  [[ "$rc" == "$want" ]] || { printf '%s\n' "$OUT" | sed 's/^/      | /' >&2; fail "$name: exit $rc, wanted $want"; }
}
has()    { grep -qF -- "$1" <<<"$OUT" || { printf '%s\n' "$OUT" | sed 's/^/      | /' >&2; fail "$2: output lacks '$1'"; }; }
hasnt()  { ! grep -qF -- "$1" <<<"$OUT" || { printf '%s\n' "$OUT" | sed 's/^/      | /' >&2; fail "$2: output contains '$1'"; }; }
wait_http() { local url="$1" i; for i in $(seq 1 90); do curl -fsS -o /dev/null "$url" 2>/dev/null && return 0; sleep 1; done; fail "timed out waiting for $url"; }

rand() { head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
PG_ADMIN_PW="adminpw-$(rand)"
PG_RO_PW="ropw-$(rand)"
LOKI_PW="lokipw-$(rand)"

echo "== starting containers =="
docker network create "$NET" >/dev/null
docker run -d --name "$ID-pg" --network "$NET" -p 127.0.0.1::5432 \
  -e POSTGRES_PASSWORD="$PG_ADMIN_PW" -e POSTGRES_DB=weighbridge "$PG_IMAGE" >/dev/null
docker run -d --name "$ID-loki" --network "$NET" -p 127.0.0.1::3100 "$LOKI_IMAGE" \
  -config.file=/etc/loki/local-config.yaml >/dev/null
docker run -d --name "$ID-grafana" --network "$NET" -p 127.0.0.1::3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin -e GF_ANALYTICS_REPORTING_ENABLED=false \
  -e GF_ANALYTICS_CHECK_FOR_UPDATES=false -e GF_NEWS_NEWS_FEED_ENABLED=false "$GRAFANA_IMAGE" >/dev/null
PG_PORT="$(docker port "$ID-pg" 5432/tcp | head -1 | sed 's/.*://')"
LOKI_PORT="$(docker port "$ID-loki" 3100/tcp | head -1 | sed 's/.*://')"
GRAFANA_PORT="$(docker port "$ID-grafana" 3000/tcp | head -1 | sed 's/.*://')"

for i in $(seq 1 60); do docker exec "$ID-pg" pg_isready -U postgres -d weighbridge >/dev/null 2>&1 && break; sleep 1; done
sleep 2
docker exec -i "$ID-pg" psql -q -v ON_ERROR_STOP=1 -U postgres -d weighbridge >/dev/null <<SQL || fail "seeding postgres"
CREATE TABLE weighings (id serial PRIMARY KEY, site text NOT NULL, net_kg int NOT NULL, synced boolean NOT NULL DEFAULT false);
INSERT INTO weighings (site, net_kg) SELECT 'medan', g FROM generate_series(1, 250) g;
CREATE ROLE investigator LOGIN PASSWORD '$PG_RO_PW';
GRANT pg_read_all_data TO investigator;
SQL
ok "postgres seeded (port $PG_PORT)"

wait_http "http://127.0.0.1:$LOKI_PORT/ready"
now_ns="$(date +%s)000000000"
push() { # service level message
  curl -fsS -H 'Content-Type: application/json' "http://127.0.0.1:$LOKI_PORT/loki/api/v1/push" --data-binary @- <<JSON || fail "push to loki"
{"streams":[{"stream":{"service_name":"$1","level":"$2"},"values":[["$now_ns","$3"]]}]}
JSON
}
push weighbridge.medan.prod error "sync failed: weighing 42 rejected by cloud"
push weighbridge.medan.prod info "weighing 43 saved"
push weighbridge.riau.prod error "riau only line"
ok "loki seeded (port $LOKI_PORT)"

wait_http "http://127.0.0.1:$GRAFANA_PORT/api/health"
G="http://admin:admin@127.0.0.1:$GRAFANA_PORT"
curl -fsS -H 'Content-Type: application/json' "$G/api/datasources" \
  -d "{\"name\":\"Loki\",\"type\":\"loki\",\"uid\":\"apta-loki\",\"access\":\"proxy\",\"url\":\"http://$ID-loki:3100\"}" >/dev/null || fail "grafana datasource"
sa_id="$(curl -fsS -H 'Content-Type: application/json' "$G/api/serviceaccounts" -d '{"name":"apta-it","role":"Viewer"}' | jq -r .id)"
GRAFANA_TOKEN="$(curl -fsS -H 'Content-Type: application/json' "$G/api/serviceaccounts/$sa_id/tokens" -d '{"name":"apta-it"}' | jq -r .key)"
[[ -n "$GRAFANA_TOKEN" && "$GRAFANA_TOKEN" != null ]] || fail "grafana service-account token"
ok "grafana ready with a Loki data source and a Viewer service-account token (port $GRAFANA_PORT)"

echo "== init.sh =="
proj="$tmp/project"
mkdir -p "$proj/.claude" && git -C "$proj" init -q
cd "$proj" || fail "cd project"
run "init" 0 "$SK/init.sh" dev dev-admin dev-grafana logs-only
has "git: the folder is ignored" "init"
D="$proj/.apta-investigate"
[[ "$(cat "$D/.gitignore" | grep -v '^#')" == "*" ]] || fail ".gitignore is not '*'"
[[ "$(stat -c %a "$D/secrets/dev.env")" == 600 ]] || fail "secrets file is not mode 600"
[[ -z "$(git -C "$proj" status --porcelain --ignored=no -- .apta-investigate)" ]] || fail "git sees .apta-investigate"
jq -e '.permissions.deny | index("Read(./.apta-investigate/secrets/**)")' "$proj/.claude/settings.json" >/dev/null || fail "deny rule missing"
run "init again" 0 "$SK/init.sh" dev
has "kept     environments/dev.env" "init is idempotent"
ok "init creates an ignored folder, 600 secrets, Claude deny rules, and is idempotent"

setkv() { sed -i "s|^$2=.*|$2=$3|" "$D/$1"; }
for e in dev dev-admin; do
  setkv "environments/$e.env" DB_HOST 127.0.0.1
  setkv "environments/$e.env" DB_PORT "$PG_PORT"
  setkv "environments/$e.env" DB_NAME weighbridge
  setkv "environments/$e.env" DB_SSLMODE disable
done
setkv environments/dev.env DB_USER investigator
setkv secrets/dev.env DB_PASSWORD "$PG_RO_PW"
setkv environments/dev-admin.env DB_USER postgres
setkv secrets/dev-admin.env DB_PASSWORD "$PG_ADMIN_PW"
setkv environments/dev.env LOKI_MODE direct
setkv environments/dev.env LOKI_URL "http://127.0.0.1:$LOKI_PORT"
setkv environments/dev.env LOKI_USERNAME someone
setkv secrets/dev.env LOKI_PASSWORD "$LOKI_PW"
setkv environments/dev.env LOKI_SELECTOR '{service_name="weighbridge.medan.prod"}'
setkv environments/dev-grafana.env LOKI_MODE grafana
setkv environments/dev-grafana.env GRAFANA_URL "http://127.0.0.1:$GRAFANA_PORT"
setkv environments/dev-grafana.env GRAFANA_LOKI_UID apta-loki
setkv environments/dev-grafana.env LOKI_SELECTOR '{service_name="weighbridge.medan.prod"}'
setkv secrets/dev-grafana.env LOKI_TOKEN "$GRAFANA_TOKEN"
cp "$D/environments/dev-grafana.env" "$D/environments/logs-only.env"
cp "$D/secrets/dev-grafana.env" "$D/secrets/logs-only.env"

echo "== envs.sh =="
run "envs" 0 "$SK/envs.sh"
has "postgres://investigator@127.0.0.1:$PG_PORT/weighbridge (password set)" "envs"
has "grafana http://127.0.0.1:$GRAFANA_PORT (data source apta-loki, token set)" "envs"
run "envs one" 0 "$SK/envs.sh" dev
has "DB_PASSWORD: set" "envs one"
ok "envs lists Evidence Sources and says 'set' instead of secret values"

echo "== db.sh (psql via Docker) =="
export APTA_INVESTIGATE_RUNTIME=docker
run "select" 0 "$SK/db.sh" dev "SELECT count(*) AS n FROM weighings"
has "250" "select"
run "row cap" 0 "$SK/db.sh" dev "SELECT id FROM weighings ORDER BY id"
has "(200 rows)" "row cap"; has "-- truncated: more than 200 rows" "row cap"
run "limit" 0 "$SK/db.sh" dev --limit 5 "SELECT id FROM weighings ORDER BY id"
has "(5 rows)" "limit"
run "no truncation" 0 "$SK/db.sh" dev "SELECT id FROM weighings WHERE id <= 3"
hasnt "truncated" "no truncation"
run "csv" 0 "$SK/db.sh" dev --csv "SELECT id, site FROM weighings WHERE id = 1"
has "1,medan" "csv"
run "describe" 0 "$SK/db.sh" dev '\d weighings'
has "net_kg" "describe"
run "explain" 0 "$SK/db.sh" dev "EXPLAIN SELECT * FROM weighings"
has "Seq Scan" "explain"
run "stdin" 0 bash -c "echo 'SELECT 7 AS seven -- comment; not a statement' | '$SK/db.sh' dev -"
has "7" "stdin"
ok "reads work: cursor with row cap, --limit, --csv, \\d, EXPLAIN, stdin"

run "update"        2 "$SK/db.sh" dev-admin "UPDATE weighings SET synced = true"
run "delete"        2 "$SK/db.sh" dev-admin "delete from weighings"
run "two stmts"     2 "$SK/db.sh" dev-admin "SELECT 1; UPDATE weighings SET synced = true"
run "commit trick"  2 "$SK/db.sh" dev-admin "SELECT 1; COMMIT; SET default_transaction_read_only = off"
run "set_config"    2 "$SK/db.sh" dev-admin "SELECT set_config('default_transaction_read_only', 'off', false)"
run "terminate"     2 "$SK/db.sh" dev-admin "SELECT pg_terminate_backend(1)"
run "shell escape"  2 "$SK/db.sh" dev-admin '\! touch /tmp/apta-pwned'
run "copy"          2 "$SK/db.sh" dev-admin "COPY weighings TO STDOUT"
run "cte delete"    1 "$SK/db.sh" dev-admin "WITH d AS (DELETE FROM weighings RETURNING *) SELECT count(*) FROM d"
run "select into"   1 "$SK/db.sh" dev-admin "SELECT * INTO copy_of_weighings FROM weighings"
run "for update"    1 "$SK/db.sh" dev-admin "SELECT * FROM weighings FOR UPDATE"
run "explain analyze delete" 1 "$SK/db.sh" dev-admin "EXPLAIN ANALYZE DELETE FROM weighings"
has "read-only transaction" "explain analyze delete"
run "string with keywords" 0 "$SK/db.sh" dev "SELECT 'x; DELETE FROM weighings; COMMIT' AS s, \$\$ ; UPDATE \$\$ AS d"
run "count unchanged" 0 "$SK/db.sh" dev-admin "SELECT count(*) AS n, bool_or(synced) AS any_synced FROM weighings"
has "250" "count unchanged"; has " f" "count unchanged"
[[ -z "$(docker exec "$ID-pg" psql -tA -U postgres -d weighbridge -c "SELECT to_regclass('copy_of_weighings')")" ]] || fail "SELECT INTO created a table"
ok "writes are rejected by the script (exit 2) or by the read-only transaction (exit 1); data unchanged"

setkv environments/dev.env DB_STATEMENT_TIMEOUT 1s
run "timeout" 1 "$SK/db.sh" dev "SELECT pg_sleep(3)"
has "statement timeout" "timeout"
setkv environments/dev.env DB_STATEMENT_TIMEOUT 120s
ok "statement timeout holds"

run "secret in result" 0 "$SK/db.sh" dev "SELECT '$PG_RO_PW' AS leaked"
has "****" "secret in result"; hasnt "$PG_RO_PW" "secret in result"
run "secret in error" 1 "$SK/db.sh" dev "SELECT '$PG_RO_PW'::int"
has "****" "secret in error"
setkv secrets/dev.env DB_PASSWORD "wrong-$PG_RO_PW"
run "wrong password" 1 "$SK/db.sh" dev "SELECT 1"
has "password authentication failed" "wrong password"
setkv secrets/dev.env DB_PASSWORD "$PG_RO_PW"
ok "secrets are masked in results and errors"

echo "== check.sh =="
run "check" 0 "$SK/check.sh" dev dev-admin logs-only nope
has "database: ok (investigator,weighbridge," "check dev"
has "WARNING the user is a superuser" "check dev-admin"
has "database: not configured" "check logs-only"
has "not configured (known:" "check nope"
grep -A3 '^dev$' <<<"$OUT" | grep -q WARNING && fail "check warned for the read-only role"
ok "check reports ok / not configured and warns only for a writable user"

echo "== unconfigured sources exit 3 =="
run "no db" 3 "$SK/db.sh" logs-only "SELECT 1"
run "no logs" 3 "$SK/logs.sh" dev-admin labels
run "no env" 3 "$SK/db.sh" prod-aceh "SELECT 1"
ok "missing database / logs / Environment exit 3 with a carry-on message"

echo "== logs.sh direct mode =="
for rt in local docker; do
  if [[ "$rt" == local ]] && ! command -v logcli >/dev/null; then echo "  skip local logcli (not installed)"; continue; fi
  export APTA_INVESTIGATE_RUNTIME="$rt"
  run "query $rt" 0 "$SK/logs.sh" dev query '|= "sync failed"' --since 1h
  has "weighing 42 rejected" "query $rt"; hasnt "riau only line" "query $rt"
  run "labels $rt" 0 "$SK/logs.sh" dev labels
  has "service_name" "labels $rt"
  run "label-values $rt" 0 "$SK/logs.sh" dev label-values service_name
  has "weighbridge.riau.prod" "label-values $rt"
  run "series $rt" 0 "$SK/logs.sh" dev series
  has "weighbridge.medan.prod" "series $rt"
  run "placeholder $rt" 0 "$SK/logs.sh" dev query 'sum(count_over_time({{selector}} [1h]))' --since 1h
  ok "direct mode works with $rt logcli"
done
export APTA_INVESTIGATE_RUNTIME=docker
run "long window" 2 "$SK/logs.sh" dev query '|= "x"' --since 3d
has "Ask the user first" "long window"
run "long window ok" 0 "$SK/logs.sh" dev query '|= "x"' --since 3d --allow-long-window
run "absolute window" 0 "$SK/logs.sh" dev query '|= "sync failed"' --from "$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)" --to "$(date -u -d '+1 minute' +%Y-%m-%dT%H:%M:%SZ)"
has "weighing 42 rejected" "absolute window"
ok "windows over 24h need --allow-long-window; --from/--to work"

echo "== logs.sh grafana mode =="
run "grafana query" 0 "$SK/logs.sh" dev-grafana query '|= "sync failed"' --since 1h
has "weighing 42 rejected" "grafana query"
hasnt "$GRAFANA_TOKEN" "grafana query"
run "grafana check" 0 "$SK/check.sh" dev-grafana
has "selector matches 2 stream(s)" "grafana check"
setkv secrets/dev-grafana.env LOKI_TOKEN "bad-$GRAFANA_TOKEN"
run "grafana bad token" 1 "$SK/logs.sh" dev-grafana labels
setkv secrets/dev-grafana.env LOKI_TOKEN "$GRAFANA_TOKEN"
ok "grafana mode reaches Loki through the data source proxy with a service-account token"

echo "== Docker leaves nothing behind =="
[[ -z "$(docker ps -aq --filter label=apta-investigate)" ]] || fail "containers left after normal runs"
"$SK/db.sh" dev "SELECT pg_sleep(60)" >/dev/null 2>&1 &
bg=$!
for _ in $(seq 1 30); do [[ -n "$(docker ps -q --filter label=apta-investigate)" ]] && break; sleep 1; done
[[ -n "$(docker ps -q --filter label=apta-investigate)" ]] || fail "no container seen for the interrupted run"
t0=$SECONDS
kill -TERM "$bg"; wait "$bg" 2>/dev/null
for _ in $(seq 1 15); do [[ -z "$(docker ps -aq --filter label=apta-investigate)" ]] && break; sleep 1; done
[[ -z "$(docker ps -aq --filter label=apta-investigate)" ]] || fail "an interrupted run left its container behind"
(( SECONDS - t0 < 20 )) || fail "an interrupted run took $((SECONDS - t0))s to exit"
docker run -d --label apta-investigate=1 "$PG_IMAGE" sleep 300 >/dev/null   # a stray one for cleanup.sh
run "cleanup" 0 "$SK/cleanup.sh"
has "Removed 1 leftover container(s)" "cleanup"
[[ -z "$(docker ps -aq --filter label=apta-investigate)" ]] || fail "containers left after cleanup.sh"
ok "no containers after normal runs; an interrupted run removes its own at once; cleanup.sh removes strays"

echo "== guard-secrets.sh hook =="
hook() { printf '%s' "$1" | "$SK/guard-secrets.sh"; }
denied()  { hook "$1" | grep -q '"permissionDecision":"deny"' || fail "hook allowed: $1"; }
allowed() { [[ -z "$(hook "$1")" ]] || fail "hook denied: $1"; }
denied  '{"tool_name":"Read","cwd":"/p","tool_input":{"file_path":"/p/.apta-investigate/secrets/dev.env"}}'
denied  '{"tool_name":"Edit","cwd":"/p","tool_input":{"file_path":"/p/.apta-investigate//secrets/dev.env","old_string":"a","new_string":"b"}}'
denied  '{"tool_name":"Bash","cwd":"/p","tool_input":{"command":"cat .apta-investigate/secrets/dev.env"}}'
denied  '{"tool_name":"Bash","cwd":"/p/.apta-investigate","tool_input":{"command":"grep -r PASSWORD secrets"}}'
denied  '{"tool_name":"Grep","cwd":"/p","tool_input":{"pattern":"PASSWORD","path":"/p/.apta-investigate/secrets"}}'
allowed '{"tool_name":"Read","cwd":"/p","tool_input":{"file_path":"/p/.apta-investigate/environments/dev.env"}}'
allowed '{"tool_name":"Bash","cwd":"/p","tool_input":{"command":"/x/scripts/db.sh dev \"SELECT 1\""}}'
allowed '{"tool_name":"Write","cwd":"/p","tool_input":{"file_path":"/p/README.md","content":"never open .apta-investigate/secrets/"}}'
ok "hook denies Read/Edit/Bash/Grep into secrets/ and allows everything else"

echo "== no secret ever printed =="
for s in "$PG_RO_PW" "$PG_ADMIN_PW" "$LOKI_PW" "$GRAFANA_TOKEN"; do
  if grep -qF -- "$s" "$ALL_OUT"; then fail "a secret appeared in script output"; fi
done
ok "none of the 4 secrets appears in $(wc -l <"$ALL_OUT") lines of output"

echo
echo "test-apta-investigate: all $pass checks passed"
