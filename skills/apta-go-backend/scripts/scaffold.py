#!/usr/bin/env python3
"""Scaffold an Apta Go (Gin + GORM) backend, or add a CRUD resource to one.

  scaffold.py init --module github.com/acme/orders-api [--dir DIR] [--name NAME] ...
  scaffold.py crud --name VehicleType [--field code:string:unique ...] [--dir DIR]

Standard library only. Templates live in ../assets/project and ../assets/crud and use
__TOKEN__ placeholders; this script renders them and, for `crud`, wires the new resource
into the `// scaffold:<marker>` comments that the project templates carry.
"""
import argparse
import re
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
PROJECT_TPL = SKILL / "assets" / "project"
CRUD_TPL = SKILL / "assets" / "crud"

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
    """JSON tag style: lowerCamel with abbreviations treated as plain words (user id -> userId, not userID)."""
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
    if shutil.which("gofmt") and paths:
        subprocess.run(["gofmt", "-w", *map(str, paths)], check=False)


# --------------------------------------------------------------------------- init
def cmd_init(a):
    module = a.module.strip()
    name = a.name or module.rstrip("/").split("/")[-1]
    title = a.title or " ".join(w.capitalize() for w in words(name))
    tokens = {
        "__MODULE__": module,
        "__APP_NAME__": name,
        "__APP_TITLE__": title,
        "__DB_NAME__": a.db_name or "_".join(words(name)),
        "__PORT__": str(a.port),
        "__GO_VERSION__": a.go_version,
    }
    target = Path(a.dir or name).resolve()
    target.mkdir(parents=True, exist_ok=True)

    plan = []
    for src in sorted(p for p in PROJECT_TPL.rglob("*") if p.is_file()):
        rel = src.relative_to(PROJECT_TPL)
        plan.append((src, target / str(rel)[: -len(".tmpl")]))
    clashes = [str(d.relative_to(target)) for _, d in plan if d.exists()]
    if clashes and not a.force:
        die("refusing to overwrite existing files (use --force): " + ", ".join(clashes[:8]))

    written = []
    for src, dest in plan:
        dest.parent.mkdir(parents=True, exist_ok=True)
        text = render(src.read_text(), {**tokens, "__JWT_SECRET__": "change-me-to-a-random-32-char-secret"})
        dest.write_text(text)
        written.append(dest)

    # main.go blank-imports the git-ignored swagger package, which `swag init` generates. A stub lets
    # `go mod tidy` resolve the import before swag has run (swag only works once go.sum exists).
    stub = target / "docs" / "docs.go"
    if not stub.exists():
        stub.parent.mkdir(exist_ok=True)
        stub.write_text("// Package docs is a placeholder; `make swag` (swag init) regenerates it.\npackage docs\n")

    # .env is git-ignored, so it can carry a real random secret
    env_example = target / "example.env"
    env = target / ".env"
    if env_example.exists() and (a.force or not env.exists()):
        env.write_text(env_example.read_text().replace(
            "change-me-to-a-random-32-char-secret", secrets.token_urlsafe(24)))

    gofmt([w for w in written if w.suffix == ".go"])

    leftovers = []
    for w in written:
        t = w.read_text()
        if re.search(r"__[A-Z_]+__", t) or ("fleet" in t.lower() and "fleet" not in module.lower()):
            leftovers.append(str(w.relative_to(target)))
    if leftovers:
        die("unreplaced placeholders / reference-project names left in: " + ", ".join(leftovers))

    print(f"Scaffolded {name} ({module}) in {target} - {len(written)} files")
    if not a.no_tidy and shutil.which("go"):
        print("Running `go mod tidy` ...")
        r = subprocess.run(["go", "mod", "tidy"], cwd=target)
        if r.returncode != 0:
            print("warning: go mod tidy failed (offline?). Run it manually before building.")
        elif shutil.which("swag"):
            print("Running `swag init` ...")
            subprocess.run(["swag", "init", "--parseDependency", "--parseInternal"], cwd=target, check=False)
        else:
            print("`swag` not found - install it (go install github.com/swaggo/swag/cmd/swag@latest) and run `make swag`.")
    else:
        print("Skipped `go mod tidy` - run it before building (it also creates go.sum).")
    print("Next: edit .env, `make swag`, `make migrate`, `make go` (the user runs these).")


# --------------------------------------------------------------------------- crud
def parse_field(spec):
    parts = spec.split(":")
    if len(parts) < 2 or parts[1] not in GO_TYPES:
        die(f"bad --field '{spec}': use name:type[:unique][:notnull], type in {sorted(GO_TYPES)}")
    ws = words(parts[0])
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
        if l.strip().startswith(f"// scaffold:{marker}"):
            lines.insert(i + 1 if after else i, line)
            path.write_text("\n".join(lines))
            return True
    die(f"marker '// scaffold:{marker}' not found in {path} - was it removed? Insert the line by hand: {line.strip()}")


def cmd_crud(a):
    root = Path(a.dir or ".").resolve()
    gomod = root / "go.mod"
    if not gomod.exists():
        die(f"{root} has no go.mod - run from the project root or pass --dir")
    module = re.search(r"^module\s+(\S+)", gomod.read_text(), re.M).group(1)

    ws = words(a.name)
    pws = words(a.plural) if a.plural else ws[:-1] + [pluralize(ws[-1])]
    snake, pkebab = "_".join(ws), "-".join(pws)  # files are snake_case; URLs/permissions stay kebab-case
    human, phuman = " ".join(ws), " ".join(pws)

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

    tokens = {
        "__MODULE__": module,
        "__Entity__": pascal(ws), "__entity__": camel(ws),
        "__Entities__": pascal(pws), "__entities__": camel(pws),
        "__entities-kebab__": pkebab,
        "__entity_human__": human, "__Entity_human__": human.capitalize(),
        "__entities_human__": phuman,
        "__table__": "_".join(pws),
        "__ENTITY_FIELDS__": fmt("entity"),
        "__INPUT_FIELDS__": fmt("input"), "__PAGE_FIELDS__": fmt("page"),
        "__ENTITY_IMPORTS__": '\t"time"\n\n' if uses_time else "",
        "__MODEL_IMPORTS__": '\t"time"\n\n' if uses_time else "",
    }

    files = [
        ("entity", f"internal/entities/{snake}.entity.go"),
        ("model", f"internal/v1/models/{snake}.model.go"),
        ("repo", f"internal/v1/repositories/{snake}.repo.go"),
        ("service", f"internal/v1/services/{snake}.service.go"),
        ("handler", f"internal/v1/handlers/{snake}.handler.go"),
        ("route", f"internal/v1/routes/{snake}.route.go"),
    ]
    clashes = [rel for _, rel in files if (root / rel).exists()]
    if clashes:
        die("already exists: " + ", ".join(clashes))

    E, Es = tokens["__Entity__"], tokens["__Entities__"]
    created = []
    for tpl, rel in files:
        dest = root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(render((CRUD_TPL / f"{tpl}.go.tmpl").read_text(), tokens))
        created.append(dest)

    wiring = [
        ("internal/container/di.go", "repos", f"\tc.Provide(repositories.New{E}Repo, dig.As(new(repositories.I{E}Repo)))", False),
        ("internal/container/di.go", "services", f"\tc.Provide(services.New{E}Service, dig.As(new(services.I{E}Service)))", False),
        ("internal/container/di.go", "handlers", f"\tc.Provide(handlers.New{E}Handler)", False),
        ("internal/v1/routes/router.go", "api-handlers", f"\t{E} *handlers.{E}Handler", False),
        ("internal/v1/routes/router.go", "routes", f"\tsetup{E}Routes(v1, authM, h.{E})", False),
        ("internal/configs/postgres.go", "migrate", f"\t\tentities.{E}{{}},", False),
        ("internal/configs/postgres.go", "drop", f"\t\tentities.{E}{{}},", True),
    ]
    touched = set()
    for rel, marker, line, after in wiring:
        if insert(root / rel, marker, line, after):
            touched.add(root / rel)

    perm_file = root / "internal/enums/permissions.go"
    consts = "\n".join(f'\tPerm{Es}{act.capitalize()} = "{pkebab}#{act}"' for act in ("create", "read", "update", "delete"))
    names = "\n".join(f"\tPerm{Es}{act.capitalize()}," for act in ("create", "read", "update", "delete"))
    if f"Perm{Es}Create" not in perm_file.read_text():
        insert(perm_file, "perm-consts", consts + "\n", False)
        insert(perm_file, "perm-list", names + "\n", False)
        touched.add(perm_file)

    gofmt(created + sorted(touched))
    print(f"Created {E} CRUD (/api/v1/{pkebab}, table {tokens['__table__']}):")
    for p in created:
        print("  +", p.relative_to(root))
    for p in sorted(touched):
        print("  ~", p.relative_to(root))
    print("Next: `make swag` to refresh swagger docs, `make migrate` to create the table (the user runs these).")


# --------------------------------------------------------------------------- enable
# Optional modules ship fully commented. `enable` uncomments exactly what each module owns:
# whole files (body after the header comment) and tagged lines inside shared files.
MODULES = {
    "s3": {
        "files": ["internal/configs/s3.go", "internal/common/s3.go", "pkg/aws/s3.go", "internal/v1/repositories/s3.repo.go"],
        "lines": {
            "internal/configs/env.go": r"AWS",
            "internal/container/di.go": r"ConnectS3|NewS3Repo",
            "example.env": r"^# AWS_",
        },
        "imports": {"internal/container/di.go": ["internal/common"]},
    },
    "infisical": {
        "files": ["internal/configs/infisical.go", "internal/v1/repositories/infisical.repo.go"],
        "lines": {
            "internal/configs/env.go": r"Infisical",
            "internal/container/di.go": r"SetupInfisicalClient|NewInfisicalRepo",
            "example.env": r"^# INFISICAL_",
        },
        "imports": {},
    },
    "nats": {
        "files": ["internal/configs/nats.go", "internal/v1/consumers/example.consumer.go"],
        "lines": {
            "internal/configs/env.go": r"NATSURI",
            "internal/container/di.go": r"ConnectNats|NewExampleConsumer",
            "internal/app/app.go": r"exampleConsumer",
            "example.env": r"^# NATS_URI",
        },
        "imports": {"internal/container/di.go": ["internal/v1/consumers"], "internal/app/app.go": ["internal/v1/consumers"]},
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


def add_import(path, module, pkg):
    text = path.read_text()
    imp = f'\t"{module}/{pkg}"'
    if imp in text:
        return
    path.write_text(text.replace("import (\n", f"import (\n{imp}\n", 1))


def cmd_enable(a):
    root = Path(a.dir or ".").resolve()
    gomod = root / "go.mod"
    if not gomod.exists():
        die(f"{root} has no go.mod - run from the project root or pass --dir")
    module = re.search(r"^module\s+(\S+)", gomod.read_text(), re.M).group(1)
    touched = []
    for name in a.modules:
        spec = MODULES[name]
        for rel in spec["files"]:
            uncomment_file_body(root / rel); touched.append(root / rel)
        for rel, pat in spec["lines"].items():
            f = root / rel
            if f.exists():
                uncomment_matching(f, pat); touched.append(f)
        for rel, pkgs in spec["imports"].items():
            for pkg in pkgs:
                add_import(root / rel, module, pkg)
        # the example env file is the template for .env; keep a local .env in sync if present
        env = root / ".env"
        if env.exists():
            for pat in [spec["lines"].get("example.env")]:
                if pat:
                    uncomment_matching(env, pat)
    gofmt([t for t in touched if t.suffix == ".go"])
    print("Enabled:", ", ".join(a.modules))
    if not a.no_tidy and shutil.which("go"):
        print("Running `go mod tidy` ...")
        if subprocess.run(["go", "mod", "tidy"], cwd=root).returncode != 0:
            print("warning: go mod tidy failed (offline?). Run it manually, then fill in the new env vars.")
    print("Next: fill in the new variables in .env / example.env.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("init", help="scaffold a new project")
    i.add_argument("--module", required=True, help="Go module path, e.g. github.com/devapta/orders-api")
    i.add_argument("--dir", help="target directory (default ./<name>)")
    i.add_argument("--name", help="app / binary / docker image name, kebab-case (default: last module segment)")
    i.add_argument("--title", help="human title used in swagger and README")
    i.add_argument("--db-name", help="default DB_NAME in example.env")
    i.add_argument("--port", type=int, default=7008)
    i.add_argument("--go-version", default="1.26.4")
    i.add_argument("--no-tidy", action="store_true", help="skip `go mod tidy`")
    i.add_argument("--force", action="store_true", help="overwrite existing files")
    i.set_defaults(fn=cmd_init)

    c = sub.add_parser("crud", help="add a CRUD resource to an initialized project")
    c.add_argument("--name", required=True, help="singular entity name, any case: VehicleType, vehicle-type, 'vehicle type'")
    c.add_argument("--plural", help="override the plural when the default rule is wrong (e.g. person -> people)")
    c.add_argument("--field", action="append", help="name:type[:unique][:notnull]; repeatable. types: " + ", ".join(sorted(GO_TYPES)))
    c.add_argument("--dir", help="project root (default: cwd)")
    c.set_defaults(fn=cmd_crud)

    e = sub.add_parser("enable", help="uncomment optional modules (s3, infisical, nats)")
    e.add_argument("modules", nargs="+", choices=sorted(MODULES))
    e.add_argument("--dir", help="project root (default: cwd)")
    e.add_argument("--no-tidy", action="store_true")
    e.set_defaults(fn=cmd_enable)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
