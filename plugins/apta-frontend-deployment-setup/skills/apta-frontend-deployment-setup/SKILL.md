---
name: apta-frontend-deployment-setup
description: Set up Docker + docker compose + GitHub Actions deployment for a Vite/React frontend, following the Apta pattern (registry.apta.works, Infisical secrets, self-hosted runners, nginx SPA image). Use when asked to add deploy setup, Dockerfile, compose files, or CI/CD workflows to a project.
---

# Setup Deploy (Apta frontend pattern)

Produces these files in the target repo:

```
Dockerfile
nginx.conf
.dockerignore
docker-compose.yml              # prod  → image tag :release
docker-compose.dev.yml          # dev   → image tag :latest
.github/workflows/deploy-dev.yml   # push to `dev` → build :latest → deploy on dev runner
.github/workflows/build-prod.yml   # push tag v*.*.* → build :release + :vX.Y.Z
.github/workflows/deploy-prod.yml  # manual → pull :release on prod runner
```

## Flow

- **Dev**: push to `dev` branch → build & push `:latest` → self-hosted `dev` runner pulls and restarts `docker-compose.dev.yml`.
- **Prod**: push tag `vX.Y.Z` → build & push `:release` and `:vX.Y.Z`. Then run **Deploy to Prod** manually (workflow_dispatch) → prod runner pulls `:release` and restarts `docker-compose.yml`.
- Build-time env (`VITE_*`) comes from Infisical, with a hardcoded fallback in the workflow. Vite bakes env at build time, so it is passed as a Docker `build-arg`, never at runtime.

## Step 0 — Prerequisites (check first, tell the user before anything else)

The first message to the user must show both tables below (0a logins, 0b infrastructure) with their status, before gathering values or writing files.

### 0a — Logins and tools on this machine

Run these checks and show the user the result as a short table (requirement, purpose, status ✅/❌, what to do if ❌):

```bash
gh auth status 2>&1 | grep -E "Logged in|Token scopes"                 # needs scopes: repo, workflow
which infisical >/dev/null && echo "infisical CLI: installed" || echo "infisical CLI: missing"
infisical user get token --plain >/dev/null 2>&1 && echo "infisical: logged in" || echo "infisical: not logged in"
which npm >/dev/null && echo "npm: ok" || echo "npm: missing"
docker info >/dev/null 2>&1 && echo "docker: running" || echo "docker: not running (optional)"
```

| Requirement | Purpose | If missing |
|---|---|---|
| **gh** logged in, scopes `repo` + `workflow`, permission to manage secrets on the target repo | Check/set repo secrets (Step 9), push `.github/workflows/*` | `! gh auth login` or `! gh auth refresh -s workflow` |
| **Infisical CLI** logged in to `https://infisical.apta.works`, member of project `general-ci-secrets-uy-kt` with read on `dev` | Read the CI secret values in Step 9 | Install (see below), then `! infisical login` → Self-Hosting → `https://infisical.apta.works` |
| **npm** (or Homebrew on macOS) | Installing the Infisical CLI | Comes with Node.js, which the frontend project already needs |
| **Docker Desktop** running (optional) | Local `docker build` test only | Start Docker Desktop, or skip the local test |

No Docker registry login is needed locally; GitHub Actions logs in using the repo secrets. Both logins are once per machine. If gh or Infisical is ❌, say so up front and ask the user to fix it (interactive logins must be run by the user with `!`). You may continue writing the files meanwhile, but Step 9 cannot run until both are ✅.

### 0b — Infrastructure requirements (show these at the start too)

These live outside the laptop. Check what can be checked, and list the rest for the user to confirm, in the same first message as the 0a table:

```bash
git ls-remote --heads origin dev | grep -q . && echo "dev branch: exists" || echo "dev branch: missing"
gh api repos/<OWNER/REPO>/actions/runners --jq '.runners[] | "\(.name)\t\(.status)\t\([.labels[].name]|join(","))"' 2>&1   # needs repo admin; 404/403 or empty output does NOT mean no runner exists, so ask the user
```

| Requirement | Why | How to fix / confirm |
|---|---|---|
| **App Infisical project** `<INFISICAL_PROJECT_SLUG>` exists, with `dev` (and `prod`) environments containing `VITE_API_BASE_URL` and any other `VITE_*` | Build-time env for the image | Create it in Infisical; the slug usually has a generated suffix, so copy it from project settings |
| **CI machine identity** (the `INFISICAL_CLIENT_ID` in `general-ci-secrets-uy-kt`) added to the app project with read on `dev`/`prod` | Otherwise **Load secrets from Infisical** returns 403 and shows green only because of `continue-on-error`, silently using the fallback URL | Infisical → app project → Access Control → Machine Identities → add |
| **Self-hosted runners** labelled `dev` (and `<PROD_RUNNER_LABEL>` for prod) available to the repo | The deploy jobs run on them | If the API lists the labels, ✅. Otherwise ask the user: org-level runners are not listed, and non-admins get 404 |
| **Docker networks** on the servers: `infra-app` (dev), `net` (prod) | Compose files declare them as external | `docker network create <name>` on the server |
| **Free host port** `<PORT>` on the target server | Container port mapping | Ask the user to confirm; it can't be checked from the laptop |
| **`dev` branch** on the remote | Pushing to it triggers the dev deploy | `git push origin HEAD:dev` when the user asks |

## Step 1 — Gather values (ask the user for anything not inferable)

| Placeholder | Meaning | How to get it |
|---|---|---|
| `<APP_NAME>` | image + container name | Repo name from `git remote get-url origin`; confirm with the user |
| `<PORT>` | host port on the server | Ask the user; it must not clash with other apps on the same server |
| `<INFISICAL_PROJECT_SLUG>` | the app's Infisical project slug | Ask the user; copy it from Infisical project settings, since it usually has a generated suffix (`<name>-xxxx`) |
| `<DEV_API_URL>` | fallback `VITE_API_BASE_URL` for dev | Ask the user |
| `<PROD_API_URL>` | fallback `VITE_API_BASE_URL` for prod | Ask the user (only when setting up prod) |
| `<PROD_RUNNER_LABEL>` | self-hosted prod runner label | Ask the user; `sraya-prod` is the usual one (only when setting up prod) |

Also ask whether to set up **dev only** or **dev + prod**. For dev only, skip `docker-compose.yml` and Steps 7–8.

Fixed across projects: registry `registry.apta.works`, Infisical `https://infisical.apta.works`, dev runner `[self-hosted, dev]`, dev network `infra-app`, prod network `net`.

Before writing, check what already exists (`Dockerfile`, compose files, `.github/workflows/`) and read `package.json` + `.env.example` to find every `VITE_*` var and the build command. Don't overwrite existing files without confirming.

**Check the lockfile before writing the Dockerfile.** The image runs `npm ci`, which fails when `package-lock.json` is out of sync with `package.json` (e.g. `Missing: @oxlint/binding-… from lock file`). Check it without touching `node_modules`:

```bash
npm ci --dry-run --ignore-scripts >/dev/null 2>/tmp/npmci.err && echo "lockfile: in sync" || grep -m3 -E "in sync|Missing" /tmp/npmci.err
```

If it's out of sync, tell the user, run `npm install` to regenerate the lockfile, and report that `package-lock.json` changed (it must be committed with the deploy files). Then confirm with `npm ci && npm run build`. If the repo uses pnpm or yarn (no `package-lock.json`), adapt the Dockerfile install step to that package manager instead.

## Step 2 — Dockerfile

Use `node:22-alpine`: Node 20 reached end of life in April 2026. If `package.json` has an `engines.node` that needs a different major, use that instead.

```dockerfile
# Stage 1: Build (Vite + React)
FROM node:22-alpine AS builder
WORKDIR /app

ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Add one `ARG`/`ENV` pair per extra `VITE_*` var.

## Step 3 — nginx.conf (SPA routing + gzip + asset caching)

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript application/json;

    # SPA fallback so client-side routes survive refresh
    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(?:ico|css|js|gif|jpe?g|png|woff2?|eot|ttf|svg|webp)$ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        access_log off;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

## Step 4 — .dockerignore

```
node_modules
dist
.git
.agents
.env
.env.local
.env.*.local
*.md
```

`.env` is excluded so local values never leak into the image; build args supply them instead.

## Step 5 — Compose files

`docker-compose.dev.yml`:

```yaml
services:
  <APP_NAME>:
    image: registry.apta.works/<APP_NAME>:latest
    container_name: <APP_NAME>
    restart: unless-stopped
    ports:
      - "${PORT:-<PORT>}:80"
    networks:
      - infra-app

networks:
  infra-app:
    external: true
    name: infra-app
```

`docker-compose.yml` (prod):

```yaml
services:
  <APP_NAME>:
    image: registry.apta.works/<APP_NAME>:release
    container_name: <APP_NAME>
    restart: always
    ports:
      - "${PORT:-<PORT>}:80"
    networks:
      - net

networks:
  net:
    name: net
    external: true
```

Pick a `<PORT>` not used by other apps on the same server.

## Step 6 — `.github/workflows/deploy-dev.yml`

```yaml
name: Build and Deploy to Dev

on:
  push:
    branches:
      - dev
  workflow_dispatch:

concurrency:
  group: dev-deploy
  cancel-in-progress: true

env:
  REGISTRY: registry.apta.works
  IMAGE_NAME: <APP_NAME>
  INFISICAL_DOMAIN: https://infisical.apta.works
  INFISICAL_PROJECT_SLUG: <INFISICAL_PROJECT_SLUG>
  INFISICAL_ENV_SLUG: dev

jobs:
  build:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Load secrets from Infisical
        uses: Infisical/secrets-action@v1.0.12
        continue-on-error: true
        with:
          method: "universal"
          domain: ${{ env.INFISICAL_DOMAIN }}
          client-id: ${{ secrets.INFISICAL_CLIENT_ID }}
          client-secret: ${{ secrets.INFISICAL_CLIENT_SECRET }}
          project-slug: ${{ env.INFISICAL_PROJECT_SLUG }}
          env-slug: ${{ env.INFISICAL_ENV_SLUG }}
          export-type: "env"

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - name: Log in to private Docker Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and Push Image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile
          push: true
          build-args: |
            VITE_API_BASE_URL=${{ env.VITE_API_BASE_URL || '<DEV_API_URL>' }}
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    name: Deploy on Dev Server
    needs: build
    runs-on: [self-hosted, dev]
    steps:
      - uses: actions/checkout@v4

      - name: Log in to private Docker Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Pull Latest Image and Restart Stack
        run: |
          docker compose -f docker-compose.dev.yml pull
          docker compose -f docker-compose.dev.yml down
          docker compose -f docker-compose.dev.yml up -d

      - name: Remove unused images
        run: docker image prune -f
```

## Step 7 — `.github/workflows/build-prod.yml`

Same `build` job as dev, with these differences:

```yaml
name: Build Prod

on:
  push:
    tags:
      - 'v*.*.*'

concurrency:
  group: prod-build-${{ github.ref }}
  cancel-in-progress: true

env:
  # ...same as dev, but:
  INFISICAL_ENV_SLUG: prod

# build-push-action `with:` block:
          build-args: |
            VITE_API_BASE_URL=${{ env.VITE_API_BASE_URL || '<PROD_API_URL>' }}
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:release
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
```

No `deploy` job — prod deploy is a separate manual step.

## Step 8 — `.github/workflows/deploy-prod.yml`

```yaml
name: Deploy to Prod

on:
  workflow_dispatch:

concurrency:
  group: prod-deploy
  cancel-in-progress: true

env:
  REGISTRY: registry.apta.works

jobs:
  deploy:
    name: Deploy on Prod Server
    runs-on: [self-hosted, <PROD_RUNNER_LABEL>]
    steps:
      - uses: actions/checkout@v4

      - name: Log in to private Docker Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Pull Latest Image and Restart Stack
        run: |
          docker compose pull
          docker compose down
          docker compose up -d

      - name: Remove unused images
        run: docker image prune -f
```

## Step 9 — GitHub secrets (check, then fill from Infisical)

The workflows need four secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET`. Without the registry pair, the build fails at **Log in to private Docker Registry** ("Username and password required").

**9a. Check what the repo already has.** `<OWNER/REPO>` comes from `git remote get-url origin`.

```bash
gh secret list -R <OWNER/REPO>
gh api repos/<OWNER/REPO>/actions/organization-secrets --jq '.secrets[].name'   # org secrets shared with the repo
```

If all four names already appear in either list, skip to Step 10. Never overwrite an existing secret without asking.

**9b. Source of truth.** The values live in Infisical project slug `general-ci-secrets-uy-kt`, environment `dev`, path `/`, under the same four key names.

**9c. Infisical CLI + user login.** The project is read with the user's own Infisical account, not a machine identity (the per-app identities get 403 on this project).

```bash
which infisical || npm install -g @infisical/cli   # any OS; on macOS `brew install infisical/get-cli/infisical` also works
infisical user get token --plain >/dev/null 2>&1 && echo LOGGED_IN || echo NEED_LOGIN
```

If `NEED_LOGIN`, the login is interactive, so ask the user to run it: `! infisical login`, choose **Self-Hosting or Dedicated Instance**, and enter `https://infisical.apta.works`.

**9d. Fetch and set only the missing secrets.** Run this as one command so values go straight from Infisical into `gh` via stdin and are never printed, written to a file, or put on a command line:

```bash
REPO=<OWNER/REPO>
TOKEN=$(infisical user get token --plain)
JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" \
  "https://infisical.apta.works/api/v3/secrets/raw?workspaceSlug=general-ci-secrets-uy-kt&environment=dev&secretPath=/") \
  || { echo "Infisical fetch failed (check login / project access)"; exit 1; }
EXISTING=$(gh secret list -R "$REPO" --json name --jq '.[].name')
for NAME in REGISTRY_USERNAME REGISTRY_PASSWORD INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET; do
  if printf '%s\n' "$EXISTING" | grep -qx "$NAME"; then echo "skip   $NAME (already set)"; continue; fi
  VAL=$(printf '%s' "$JSON" | python3 -c 'import json,sys
n=sys.argv[1]
v=[s["secretValue"] for s in json.load(sys.stdin)["secrets"] if s["secretKey"]==n]
sys.stdout.write(v[0]) if v and v[0] else sys.exit(1)' "$NAME") \
    || { echo "MISSING $NAME in Infisical"; continue; }
  printf '%s' "$VAL" | gh secret set "$NAME" -R "$REPO" && echo "set    $NAME"
done
gh secret list -R "$REPO"
```

Report which secrets were set, skipped, or missing. If any key is missing in Infisical, tell the user rather than inventing a value.

## Step 10 — Checklist for the user (things Claude can't do)

At the end, repeat only the Step 0 items that are still ❌ or unconfirmed, plus any secret Step 9 reported missing. Don't re-list items already confirmed.

After the first deploy run, check the **Load secrets from Infisical** step log for `403` or `error`. It is green even when it fails, because of `continue-on-error`.

For prod: `git tag v1.0.0 && git push origin v1.0.0`, wait for **Build Prod**, then run **Deploy to Prod** from the Actions tab.

## Verify locally

```bash
docker build --build-arg VITE_API_BASE_URL=<DEV_API_URL> -t <APP_NAME>:local .
docker run --rm -p 8080:80 <APP_NAME>:local   # open http://localhost:8080, refresh a deep route to test SPA fallback
```

Don't commit or push unless the user asks.
