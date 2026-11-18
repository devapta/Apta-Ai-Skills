# Optional modules: S3, Infisical, NATS

All three are committed fully commented. Enable with `scaffold.py enable <module>...`; it uncomments the
files, DI providers, env fields and env vars, adds imports, and runs `go mod tidy`. Afterwards fill the
new variables in `.env`.

| Module | Files | Env vars | DI providers |
| --- | --- | --- | --- |
| s3 | `configs/s3.go`, `common/s3.go` (`IS3Repo`), `pkg/aws/s3.go`, `repositories/s3.repo.go` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_BUCKET`, `AWS_URL` (+ `AWS_SCHEME`, `AWS_USE_PATH_STYLE_ENDPOINT` documented only) | `configs.ConnectS3`, `repositories.NewS3Repo` as `common.IS3Repo` |
| infisical | `configs/infisical.go`, `repositories/infisical.repo.go` | `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`, `…_CLIENT_SECRET`, `INFISICAL_BASE_URL`, `INFISICAL_KMP_SIGN` | `configs.SetupInfisicalClient`, `repositories.NewInfisicalRepo` |
| nats | `configs/nats.go`, `v1/consumers/example.consumer.go` | `NATS_URI` | `configs.ConnectNats`, `consumers.NewExampleConsumer` |

Using them: inject `common.IS3Repo` / `*repositories.InfisicalRepo` / `*configs.NatsConnection` into a
service or consumer constructor like any other dependency.

Notes:
- S3: `UploadFile` takes the bucket; `DownloadFile` reads `Env.AWSBucket`. `NewS3` currently honours
  access key, secret and region; `AWS_URL` is loaded into `Env` but not yet applied as a custom endpoint —
  add `s3.Options.BaseEndpoint` in `pkg/aws/s3.go` for MinIO-style stores.
- Infisical: `InfisicalRepo` signs/verifies data with KMS (`ECDSA_SHA_256`). Deploy-time secrets
  (`.github/workflows/deploy-dev.yml`) already use Infisical independent of this module; set the
  `project-slug` there.
- NATS: `ExampleConsumer` creates a JetStream stream + durable consumer and acks messages. Rename it per
  stream, parse `msg.Data()` into a model, call a service, then `Ack`. `app.New` takes the consumer as a
  parameter so dig constructs it at startup — add each new consumer there too (`enable` handles the
  example one).
- Verify SDK API details with Context7 before extending these; the pinned versions are in `go.mod` after tidy.
