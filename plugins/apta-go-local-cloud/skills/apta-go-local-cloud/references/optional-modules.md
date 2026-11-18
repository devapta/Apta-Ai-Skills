# Optional modules: S3, Infisical, NATS

All three ship fully commented on both services (S3 also has shared helpers). Enable with
`scaffold.py enable <module>... [--side local|cloud|both]`: it uncomments the files, DI providers, env struct
fields and example env vars, adds imports, and runs `go mod tidy` in `shared` and the chosen services. Then the
user fills in the new variables in each service's `.env`.

| Module | Files | Env vars | DI providers |
| --- | --- | --- | --- |
| s3 | `<svc>/internal/configs/s3.go`, `<svc>/internal/v1/repositories/s3.repo.go`, `shared/common/s3.go` (`IS3Repo`), `shared/pkg/aws/s3.go` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_BUCKET`, `AWS_URL` (+ `AWS_SCHEME`, `AWS_USE_PATH_STYLE_ENDPOINT` documented only) | `configs.ConnectS3`, `repositories.NewS3Repo` as `common.IS3Repo` |
| infisical | `<svc>/internal/configs/infisical.go`, `<svc>/internal/v1/repositories/infisical.repo.go` | `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`, `…_CLIENT_SECRET`, `INFISICAL_BASE_URL`, `INFISICAL_KMP_SIGN` | `configs.SetupInfisicalClient`, `repositories.NewInfisicalRepo` |
| nats | `<svc>/internal/configs/nats.go`, `<svc>/internal/v1/consumers/example.consumer.go` | `NATS_URI` | `configs.ConnectNats`, `consumers.NewExampleConsumer` |

Notes:
- Enable per side when only one service needs a module (`--side cloud`); shared S3 helpers are enabled once.
- S3: `NewS3` honours access key, secret and region; `AWS_URL` is loaded but not applied as a custom endpoint — add
  `s3.Options.BaseEndpoint` in `shared/pkg/aws/s3.go` for MinIO-style stores.
- Infisical: `InfisicalRepo` signs / verifies data with KMS (`ECDSA_SHA_256`). Deploy-time secrets in
  `deploy-dev.yml` use Infisical independently of this module.
- NATS: `ExampleConsumer` creates a JetStream stream and durable consumer and acks messages. Rename it per stream and
  add each new consumer as an `app.New` parameter so dig constructs it at startup.
- Verify SDK API details with Context7 before extending these.
