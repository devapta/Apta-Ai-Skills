#!/usr/bin/env python3
"""Scaffold an Apta Go (Gin + GORM) backend split into shared / local / cloud modules,
add CRUD resources to it, or enable its optional modules.

  scaffold.py init   --module github.com/acme/orders [--dir DIR] [--name NAME] ...
  scaffold.py crud   --name Driver --authority cloud [--field code:string:unique ...] [--dir DIR]
  scaffold.py enable s3 infisical nats [--side local|cloud|both] [--dir DIR]

Standard library only. Templates live in ../assets/project and ../assets/crud and use __TOKEN__
placeholders. `crud` wires new resources into the `// scaffold:<marker>` comments the project
templates carry.
"""
import argparse
import os
import re
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
PROJECT_TPL = SKILL / "assets" / "project"
CRUD_TPL = SKILL / "assets" / "crud"
SIDES = ("local", "cloud")

GO_TYPES = {
    "string": "string", "int": "int", "int64": "int64", "uint": "uint",
    "float": "float64", "float64": "float64", "bool": "bool", "time": "time.Time", "date": "time.Time",
}


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def words(s):
    """'VehicleType' / 'vehicle-type' / 'vehicle_type' / 'vehicle type' / 'userId' -> ['vehicle','type']"""
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
    return [w.lower() for w in re.split(r"[\s_\-]+", s) if w]


def pascal(ws):
    return "".join("ID" if w == "id" else w.capitalize() for w in ws)


def json_name(ws):
    """JSON tag style: lowerCamel with abbreviations as plain words (user id -> userId, standalone id -> id)."""
    return ws[0] + "".join(w.capitalize() for w in ws[1:])


def camel(ws):
    p = pascal(ws)
    return p[0].lower() + p[1:] if ws[0] != "id" else "id" + p[2:]


def pluralize(word):
    if re.search(r"(s|x|z|ch|sh)$", word):
        return word + "es"
    if re.search(r"[^aeiou]y$", word):
        return word[:-1] + "ies"
    return word + "s"


def render(text, tokens):
    # longest token first so __Entities__ is never clobbered by a shorter overlapping one
    for k in sorted(tokens, key=len, reverse=True):
        text = text.replace(k, tokens[k])
    return text


def gofmt(paths):
    paths = [p for p in paths if str(p).endswith(".go")]
    if shutil.which("gofmt") and paths:
        subprocess.run(["gofmt", "-w", *map(str, paths)], check=False)


def run_go(args, cwd, label):
    r = subprocess.run(args, cwd=cwd, env={**os.environ, "GOWORK": "off"})
    if r.returncode != 0:
        print(f"warning: `{' '.join(args)}` failed in {label} (offline?). Run it manually.")
    return r.returncode == 0


def project_root(start):
    """The workspace root: the nearest directory (from `start` upward) holding go.work."""
    d = Path(start or ".").resolve()
    for cand in [d, *d.parents]:
        if (cand / "go.work").exists():
            return cand
    die(f"no go.work found from {d} upward - run inside the project or pass --dir")


def base_module(root):
    m = re.search(r"^module\s+(\S+)/local\s*$", (root / "local" / "go.mod").read_text(), re.M)
    if not m:
        die(f"{root}/local/go.mod does not declare '<module>/local'")
    return m.group(1)


# --------------------------------------------------------------------------- init
def default_short(name):
    ws = words(name)
    short = "".join(w[0] for w in ws) if len(ws) > 1 else ws[0][:6]
    return re.sub(r"[^a-z0-9]", "", short.lower())[:15] or "svc"


def cmd_init(a):
    module = a.module.strip().rstrip("/")
    name = a.name or module.split("/")[-1]
    title = a.title or " ".join(w.capitalize() for w in words(name))
    short = a.short or default_short(name)
    gv = a.go_version
    tokens = {
        "__MODULE__": module,
        "__APP_NAME__": name,
        "__APP_TITLE__": title,
        "__DB_NAME__": a.db_name or "_".join(words(name)),
        "__SHORT__": short,
        "__MDNS_NAME__": title,
        "__MDNS_TYPE__": f"_{short}._tcp",
        "__LOCAL_PORT__": str(a.local_port),
        "__CLOUD_PORT__": str(a.cloud_port),
        "__GO_VERSION__": gv,
        "__GO_MINOR__": ".".join(gv.split(".")[:2]),
    }
    target = Path(a.dir or name).resolve()
    target.mkdir(parents=True, exist_ok=True)

    plan = []
    for src in sorted(p for p in PROJECT_TPL.rglob("*") if p.is_file()):
        rel = str(src.relative_to(PROJECT_TPL))[: -len(".tmpl")]
        if a.no_mdns and rel == "local/internal/configs/service_advertiser.go":
            continue
        plan.append((src, target / rel))
    clashes = [str(d.relative_to(target)) for _, d in plan if d.exists()]
    if clashes and not a.force:
        die("refusing to overwrite existing files (use --force): " + ", ".join(clashes[:8]))

    written = []
    for src, dest in plan:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(render(src.read_text(), tokens))
        written.append(dest)

    if a.no_mdns:
        app = target / "local/internal/app/app.go"
        t = app.read_text()
        t = re.sub(r"\n\tserverAd, err := configs\.SetupServiceAdvertiser\(\).*?defer serverAd\.Shutdown\(\)\n", "\n", t, flags=re.S)
        app.write_text(t)
        gm = target / "local/go.mod"
        gm.write_text(gm.read_text().replace("\tgithub.com/grandcat/zeroconf v1.0.0\n", ""))
        rd = target / "README.md"
        rd.write_text(re.sub(r" announces itself via mDNS \(`[^`]*`\)\.", "", rd.read_text()))

    # main.go blank-imports each service's git-ignored swagger package, which `swag init` generates.
    # A stub lets `go mod tidy` resolve the import before swag has run (swag needs go.sum first).
    for side in SIDES:
        stub = target / side / "docs" / "docs.go"
        if not stub.exists():
            stub.parent.mkdir(exist_ok=True)
            stub.write_text("// Package docs is a placeholder; `make swag` (swag init) regenerates it.\npackage docs\n")

    # .env files are git-ignored, so they can carry a real random secret
    for side in SIDES:
        ex, env = target / side / "example.env", target / side / ".env"
        if ex.exists() and (a.force or not env.exists()):
            env.write_text(ex.read_text().replace("change-me-to-a-random-32-char-secret", secrets.token_urlsafe(24)))

    gofmt(written)

    leftovers = []
    for w in written:
        t = w.read_text()
        if re.search(r"__[A-Za-z_-]+__", t) or re.search(r"weighbridge|\bsws\b|palmtec", t, re.I):
            leftovers.append(str(w.relative_to(target)))
    if leftovers:
        die("unreplaced placeholders / reference-project names left in: " + ", ".join(leftovers))

    print(f"Scaffolded {name} ({module}) in {target} - {len(written)} files")
    if not a.no_tidy and shutil.which("go"):
        ok = True
        for mod in ("shared", *SIDES):
            print(f"Running `go mod tidy` in {mod}/ ...")
            ok = run_go(["go", "mod", "tidy"], target / mod, mod) and ok
        if ok and shutil.which("swag"):
            for side in SIDES:
                print(f"Running `swag init` in {side}/ ...")
                subprocess.run(["swag", "init", "--parseDependency", "--parseInternal"], cwd=target / side, check=False)
        elif ok:
            print("`swag` not found - install it (go install github.com/swaggo/swag/cmd/swag@latest) and run `make swag` in local/ and cloud/.")
    else:
        print("Skipped `go mod tidy` - run it in shared/, local/ and cloud/ before building (it also creates go.sum).")
    print("Next: review local/.env and cloud/.env, then `make swag`, `make migrate`, `make go` in each service (the user runs these).")
    print("Add resources with: scaffold.py crud --name <Entity> --authority local|cloud")


# --------------------------------------------------------------------------- crud
def parse_field(spec):
    parts = spec.split(":")
    if len(parts) < 2 or parts[1] not in GO_TYPES:
        die(f"bad --field '{spec}': use name:type[:unique][:notnull], type in {sorted(GO_TYPES)}")
    ws = words(parts[0])
    if ws == ["id"]:
        die("bad --field '%s': 'id' already exists on every entity (gorm.Model)" % spec)
    mods = set(parts[2:])
    unknown = mods - {"unique", "notnull"}
    if unknown:
        die(f"bad --field '{spec}': unknown modifier(s) {sorted(unknown)}")
    gorm = [m for m in ("not null" if "notnull" in mods else None, "unique" if "unique" in mods else None,
                        "type:date" if parts[1] == "date" else None) if m]
    return pascal(ws), GO_TYPES[parts[1]], json_name(ws), ";".join(gorm), "notnull" in mods


def insert(path, marker, line, after=False):
    lines = path.read_text().split("\n")
    for i, l in enumerate(lines):
        if l.strip().startswith(f"// scaffold:{marker}") or l.strip().startswith(f"<!-- scaffold:{marker}"):
            lines.insert(i + 1 if after else i, line)
            path.write_text("\n".join(lines))
            return
    die(f"marker 'scaffold:{marker}' not found in {path} - was it removed? Insert by hand: {line.strip()}")


def ensure_import(path, imp):
    t = path.read_text()
    line = f'\t"{imp}"'
    if line in t:
        return
    path.write_text(t.replace("import (\n", f"import (\n{line}\n", 1))


def cmd_crud(a):
    root = project_root(a.dir)
    module = base_module(root)
    authority = a.authority
    other = "local" if authority == "cloud" else "cloud"

    ws = words(a.name)
    pws = words(a.plural) if a.plural else ws[:-1] + [pluralize(ws[-1])]
    snake, pkebab = "_".join(ws), "-".join(pws)  # files are snake_case; URLs/permissions stay kebab-case
    human, phuman = " ".join(ws), " ".join(pws)
    table = "_".join(pws)

    fields = [parse_field(f) for f in (a.field or [])] or [("Name", "string", "name", "not null", True)]
    uses_time = any(f[1] == "time.Time" for f in fields)

    def fmt(kind):
        out = []
        for gname, gtype, jname, gorm, required in fields:
            tag = (f'gorm:"{gorm}" ' if gorm and kind == "entity" else "") + f'json:"{jname}"'
            if required and kind == "input":
                tag += ' binding:"required"'
            out.append(f"\t{gname} {gtype} `{tag}`")
        return "\n".join(out)

    E, Es = pascal(ws), pascal(pws)
    base_tokens = {
        "__MODULE__": module,
        "__Entity__": E, "__entity__": camel(ws),
        "__Entities__": Es, "__entities__": camel(pws),
        "__entities-kebab__": pkebab,
        "__entity_human__": human, "__Entity_human__": human.capitalize(),
        "__entities_human__": phuman,
        "__table__": table,
        "__ENTITY_FIELDS__": fmt("entity"),
        "__INPUT_FIELDS__": fmt("input"), "__PAGE_FIELDS__": fmt("page"),
        "__ENTITY_IMPORTS__": '\t"time"\n\n' if uses_time else "",
        "__MODEL_IMPORTS__": '\t"time"\n\n' if uses_time else "",
    }

    plan = [("shared/entity", root / f"shared/entities/{snake}.entity.go", {})]
    for side in SIDES:
        rw = "" if side == authority else "_ro"
        plan += [
            (f"{side}/model", root / f"{side}/internal/v1/models/{snake}.model.go", {"__SIDE__": side}),
            (f"{side}/repo", root / f"{side}/internal/v1/repositories/{snake}.repo.go", {"__SIDE__": side}),
            (f"{side}/service{rw}", root / f"{side}/internal/v1/services/{snake}.service.go", {}),
            (f"{side}/handler{rw}", root / f"{side}/internal/v1/handlers/{snake}.handler.go", {}),
            (f"{side}/route{rw}", root / f"{side}/internal/v1/routes/{snake}.route.go", {}),
        ]
    clashes = [str(d.relative_to(root)) for _, d, _ in plan if d.exists()]
    if clashes:
        die("already exists: " + ", ".join(clashes))

    created = []
    for tpl, dest, extra in plan:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(render((CRUD_TPL / f"{tpl}.go.tmpl").read_text(), {**base_tokens, **extra}))
        created.append(dest)

    touched = set()

    def wire(rel, marker, line, after=False, imports=()):
        p = root / rel
        insert(p, marker, line, after)
        for imp in imports:
            ensure_import(p, imp)
        touched.add(p)

    for side in SIDES:
        s = f"{module}/{side}/internal"
        wire(f"{side}/internal/container/di.go", "repos", f"\tc.Provide(repositories.New{E}Repo, dig.As(new(repositories.I{E}Repo)))", imports=[f"{s}/v1/repositories"])
        wire(f"{side}/internal/container/di.go", "services", f"\tc.Provide(services.New{E}Service, dig.As(new(services.I{E}Service)))", imports=[f"{s}/v1/services"])
        wire(f"{side}/internal/container/di.go", "handlers", f"\tc.Provide(handlers.New{E}Handler)", imports=[f"{s}/v1/handlers"])
        wire(f"{side}/internal/v1/routes/router.go", "api-handlers", f"\t{E} *handlers.{E}Handler", imports=[f"{s}/v1/handlers"])
        call = f"\tsetup{E}Routes(v1, authM, h.{E}, h.SchemaM)" if side == "cloud" else f"\tsetup{E}Routes(v1, h.{E})"
        wire(f"{side}/internal/v1/routes/router.go", "routes", call)
        ent = f"{module}/shared/entities"
        wire(f"{side}/internal/configs/postgres.go", "migrate", f"\t\tentities.{E}{{}},", imports=[ent])
        wire(f"{side}/internal/configs/postgres.go", "drop", f"\t\tentities.{E}{{}},", after=True, imports=[ent])
    if authority == "cloud":
        wire("local/internal/configs/postgres.go", "cloud-tables", f'\t"{table}",')

    # permissions are only checked by the cloud service; the read-only side of an entity needs just `read`
    acts = ("create", "read", "update", "delete") if authority == "cloud" else ("read",)
    perm_file = root / "shared/enums/permissions.go"
    if f"Perm{Es}Read" not in perm_file.read_text():
        insert(perm_file, "perm-consts", "\n".join(f'\tPerm{Es}{x.capitalize()} = "{pkebab}#{x}"' for x in acts) + "\n")
        insert(perm_file, "perm-list", "\n".join(f"\tPerm{Es}{x.capitalize()}," for x in acts) + "\n")
        touched.add(perm_file)

    readme = root / "README.md"
    if readme.exists() and "scaffold:authority" in readme.read_text():
        direction = f"{authority} → {other}"
        insert(readme, "authority", f"| `{table}` | {authority.capitalize()} | {other.capitalize()} | {direction} |")
        touched.add(readme)

    gofmt(created + sorted(touched))
    if not a.no_tidy and shutil.which("go"):
        for mod in ("shared", *SIDES):  # the first resource pulls in dependencies the empty skeleton did not use
            run_go(["go", "mod", "tidy"], root / mod, mod)
    print(f"Created {E} (authority: {authority}; /api/v1/{pkebab}, table {table}):")
    for p in created:
        print("  +", p.relative_to(root))
    for p in sorted(touched):
        print("  ~", p.relative_to(root))
    print(f"Write endpoints exist on {authority} only; {other} is read-only (GET). Replication for `{table}` must run {authority} -> {other}.")
    print("Next: `make swag` and `make migrate` in local/ and cloud/ (the user runs these).")


# --------------------------------------------------------------------------- enable
# Optional modules ship fully commented. `enable` uncomments exactly what each module owns: whole
# files (the body after the header comment) and tagged lines inside shared files.
# Paths are relative to a service dir (<root>/local or <root>/cloud) unless prefixed with `@`
# (relative to the workspace root).
MODULES = {
    "s3": {
        "files": ["internal/configs/s3.go", "internal/v1/repositories/s3.repo.go", "@shared/common/s3.go", "@shared/pkg/aws/s3.go"],
        "lines": {"internal/configs/env.go": r"AWS", "internal/container/di.go": r"ConnectS3|NewS3Repo", "example.env": r"^# AWS_"},
        "imports": {"internal/container/di.go": ["{m}/shared/common", "{m}/{side}/internal/v1/repositories"]},
    },
    "infisical": {
        "files": ["internal/configs/infisical.go", "internal/v1/repositories/infisical.repo.go"],
        "lines": {"internal/configs/env.go": r"Infisical", "internal/container/di.go": r"SetupInfisicalClient|NewInfisicalRepo", "example.env": r"^# INFISICAL_"},
        "imports": {"internal/container/di.go": ["{m}/{side}/internal/v1/repositories"]},
    },
    "nats": {
        "files": ["internal/configs/nats.go", "internal/v1/consumers/example.consumer.go"],
        "lines": {"internal/configs/env.go": r"NATSURI", "internal/container/di.go": r"ConnectNats|NewExampleConsumer",
                  "internal/app/app.go": r"exampleConsumer", "example.env": r"^# NATS_URI"},
        "imports": {"internal/container/di.go": ["{m}/{side}/internal/v1/consumers"], "internal/app/app.go": ["{m}/{side}/internal/v1/consumers"]},
    },
}


def uncomment_file_body(path):
    lines = path.read_text().split("\n")
    out, i = [], 0
    while i < len(lines) and not lines[i].startswith("package "):
        out.append(lines[i]); i += 1
    out.append(lines[i]); i += 1                       # package clause
    while i < len(lines) and (lines[i] == "" or lines[i].startswith("//")) and not lines[i].startswith("// import") \
            and not re.match(r"//\s*(type|func|var|const)\b", lines[i]) and lines[i] != "//":
        out.append(lines[i]); i += 1                   # header comment block
    for l in lines[i:]:
        out.append(re.sub(r"^// ?", "", l, count=1) if l.startswith("//") else l)
    path.write_text("\n".join(out))


def uncomment_matching(path, pattern):
    keep = re.compile(r"\(optional|uncomment|Optional modules")
    rx = re.compile(pattern)
    out = []
    for l in path.read_text().split("\n"):
        m = re.match(r"^(\s*)(?://|#) ?(.*)$", l)
        if m and not keep.search(l) and rx.search(l):
            out.append(m.group(1) + m.group(2))
        else:
            out.append(l)
    path.write_text("\n".join(out))


def cmd_enable(a):
    root = project_root(a.dir)
    module = base_module(root)
    sides = SIDES if a.side == "both" else (a.side,)
    touched, seen = [], set()
    for name in a.modules:
        spec = MODULES[name]
        for side in sides:
            svc = root / side
            for rel in spec["files"]:
                p = root / rel[1:] if rel.startswith("@") else svc / rel
                if p not in seen:               # shared files are common to both services
                    uncomment_file_body(p); touched.append(p); seen.add(p)
            for rel, pat in spec["lines"].items():
                f = svc / rel
                if f.exists():
                    uncomment_matching(f, pat); touched.append(f)
            for rel, imps in spec["imports"].items():
                for imp in imps:
                    ensure_import(svc / rel, imp.format(m=module, side=side))
            env = svc / ".env"
            if env.exists() and spec["lines"].get("example.env"):
                uncomment_matching(env, spec["lines"]["example.env"])
    gofmt(touched)
    print("Enabled:", ", ".join(a.modules), "on", ", ".join(sides))
    if not a.no_tidy and shutil.which("go"):
        for mod in ("shared", *sides):
            print(f"Running `go mod tidy` in {mod}/ ...")
            run_go(["go", "mod", "tidy"], root / mod, mod)
    print("Next: fill in the new variables in each service's .env / example.env.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("init", help="scaffold a new shared/local/cloud workspace")
    i.add_argument("--module", required=True, help="base Go module path, e.g. github.com/devapta/orders (modules become <module>/shared|local|cloud)")
    i.add_argument("--dir", help="target directory (default ./<name>; use . for the current empty repo)")
    i.add_argument("--name", help="app name, kebab-case; used for images and containers (default: last module segment)")
    i.add_argument("--title", help="human title used in swagger, README and the mDNS service name")
    i.add_argument("--db-name", help="base DB_NAME; the cloud database gets a _cloud suffix")
    i.add_argument("--short", help="short mDNS service label (<=15 chars, default: initials of the name)")
    i.add_argument("--local-port", type=int, default=7008)
    i.add_argument("--cloud-port", type=int, default=7009)
    i.add_argument("--go-version", default="1.27.1")
    i.add_argument("--no-mdns", action="store_true", help="omit the local service's mDNS advertisement")
    i.add_argument("--no-tidy", action="store_true", help="skip `go mod tidy` / `swag init`")
    i.add_argument("--force", action="store_true", help="overwrite existing files")
    i.set_defaults(fn=cmd_init)

    c = sub.add_parser("crud", help="add a CRUD resource to both services (write endpoints on the authority side only)")
    c.add_argument("--name", required=True, help="singular entity name, any case: VehicleType, vehicle-type, 'vehicle type'")
    c.add_argument("--authority", required=True, choices=SIDES, help="side that creates/edits this data; the other side is read-only")
    c.add_argument("--plural", help="override the plural when the default rule is wrong (e.g. person -> people)")
    c.add_argument("--field", action="append", help="name:type[:unique][:notnull]; repeatable. types: " + ", ".join(sorted(GO_TYPES)))
    c.add_argument("--dir", help="project root or any directory inside it (default: cwd)")
    c.add_argument("--no-tidy", action="store_true", help="skip `go mod tidy`")
    c.set_defaults(fn=cmd_crud)

    e = sub.add_parser("enable", help="uncomment optional modules (s3, infisical, nats)")
    e.add_argument("modules", nargs="+", choices=sorted(MODULES))
    e.add_argument("--side", choices=("local", "cloud", "both"), default="both")
    e.add_argument("--dir", help="project root or any directory inside it (default: cwd)")
    e.add_argument("--no-tidy", action="store_true")
    e.set_defaults(fn=cmd_enable)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
