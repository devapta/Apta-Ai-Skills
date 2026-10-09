import json, subprocess, re, sys
from pathlib import Path
R = Path(__file__).resolve().parent
def sh(cmd, cwd): return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)
def rd(p): return p.read_text() if p.exists() else ""
def grep_any(root, pat):
    for f in root.rglob("*"):
        if f.is_file() and "docs" not in f.parts and f.suffix in (".go",".md",".yml",".mod",".env","") and re.search(pat, rd(f)): return str(f.relative_to(root))
def check_builds(root):
    r = sh("go build ./... && go vet ./...", root); return r.returncode == 0, (r.stderr or "ok")[:200]
def e0(root):
    out = []
    ok, ev = check_builds(root); out.append(("Project builds and vets", ok, ev))
    hit = grep_any(root, r"(?i)fleet"); out.append(("No leftover 'fleet' references", hit is None, hit or "none found"))
    out.append(("go.mod module is github.com/devapta/inventory-api", "module github.com/devapta/inventory-api" in rd(root/"go.mod"), ""))
    out.append(("Retains versioned layered layout for users/roles/user-roles",
        all((root/f"internal/v1/{d}/{n}").exists() for d,n in [("handlers","user.handler.go"),("handlers","role.handler.go"),("handlers","user_role.handler.go"),("services","user.service.go"),("repositories","user_role.repo.go"),("routes","router.go")]), ""))
    out.append(("Env defaults retained (PORT=7008)", "PORT=7008" in rd(root/"example.env"), re.findall(r"PORT=\d+", rd(root/"example.env"))[:1].__str__()))
    out.append(("S3/Infisical/NATS present in code but commented out",
        all((root/f).exists() for f in ["internal/configs/s3.go","internal/configs/infisical.go","internal/configs/nats.go"]) and
        "c.Provide(configs.ConnectNats)" not in rd(root/"internal/container/di.go").replace("// c.Provide(configs.ConnectNats)",""), ""))
    out.append(("Default stack present (cobra, dig, otel, swagger, slog, jwt)",
        all(grep_any(root,p) for p in [r"spf13/cobra", r"go.uber.org/dig", r"otelgin", r"swaggo", r"log/slog", r"golang-jwt"]), ""))
    out.append(("Go version in go.mod matches Dockerfile base (1.26.x)", bool(re.search(r"^go 1\.26", rd(root/"go.mod"), re.M)), re.findall(r"^go .*", rd(root/"go.mod"), re.M).__str__()))
    return out
def e1(root):
    out = []
    ok, ev = check_builds(root); out.append(("Project builds and vets", ok, ev))
    layers = ["internal/entities/warehouse.entity.go","internal/v1/models/warehouse.model.go","internal/v1/repositories/warehouse.repo.go","internal/v1/services/warehouse.service.go","internal/v1/handlers/warehouse.handler.go","internal/v1/routes/warehouse.route.go"]
    out.append(("All six layer files created", all((root/f).exists() for f in layers), ""))
    out.append(("Registered in di.go, router.go, postgres.go (migrate+drop)",
        "NewWarehouseRepo" in rd(root/"internal/container/di.go") and "setupWarehouseRoutes" in rd(root/"internal/v1/routes/router.go") and rd(root/"internal/configs/postgres.go").count("entities.Warehouse{}") >= 2, ""))
    out.append(("Four warehouses#<action> permissions added", rd(root/"internal/enums/permissions.go").count("warehouses#")==4, ""))
    ent = rd(root/"internal/entities/warehouse.entity.go")
    out.append(("Name unique + not null; ownerId and commissionedAt fields present", "unique" in ent and "OwnerID" in ent and "CommissionedAt" in ent, ""))
    out.append(("Name required in request model (binding)", 'binding:"required"' in rd(root/"internal/v1/models/warehouse.model.go"), ""))
    out.append(("Swagger annotations on handler", "@Router" in rd(root/"internal/v1/handlers/warehouse.handler.go"), ""))
    return out
cases = {"eval-0-new-project": (e0, "inventory-api"), "eval-1-add-crud-existing-project": (e1, "project")}
for ev, (fn, sub) in cases.items():
    for cfg in ("with_skill","without_skill"):
        res = fn(R/ev/cfg/"run-1"/"outputs"/sub)
        exp = [{"text":t,"passed":bool(p),"evidence":str(e)} for t,p,e in res]
        n = sum(x["passed"] for x in exp)
        (R/ev/cfg/"run-1"/"grading.json").write_text(json.dumps({"expectations":exp,"summary":{"passed":n,"failed":len(exp)-n,"total":len(exp),"pass_rate":n/len(exp)}},indent=2))
        print(ev, cfg, f"{n}/{len(exp)}", [x["text"] for x in exp if not x["passed"]])
