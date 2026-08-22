# postgres-cnpg-extensions

CNPG PostgreSQL 18 image bundling extensions used across Hubbitus projects.

Public re-usable image — not tied to any specific downstream project.

## What's inside

Built on top of [`cloudnative-pg/postgresql`](https://github.com/cloudnative-pg/postgres-containers) `18.x-bookworm` (upstream operational layer preserved — init hooks, `barman-cloud`, pgaudit, healthcheck).

Extensions added:

| Extension         | Version | Source                                                                                         |
|-------------------|---------|------------------------------------------------------------------------------------------------|
| `pgvector`        | 0.8.6   | [pgvector/pgvector](https://github.com/pgvector/pgvector) — source build                       |
| `pg_cron`         | 1.6.x   | PGDG apt (`postgresql-18-cron`)                                                                |
| `pg_jsonschema`   | 0.3.4   | [supabase/pg_jsonschema](https://github.com/supabase/pg_jsonschema) — source build (Rust/pgrx) |
| `temporal_tables` | 1.2.2   | [arkhipov/temporal_tables](https://github.com/arkhipov/temporal_tables) — source build         |

## Image tags

Published to Docker Hub as `docker.io/hubbitus/postgres-cnpg-extensions`:

- `pg18-latest` — head of `main`, rebuilt on every push
- `pg18-YYYYMMDD-<shortsha>` — pinned reproducible daily builds
- `v<semver>` — explicit releases (git tag `v0.1.0` → tag `v0.1.0`)

Multi-arch: `linux/amd64` + `linux/arm64`.

Signed with [cosign](https://github.com/sigstore/cosign) (keyless / OIDC); SBOM attached via buildx `--sbom=true`.

## Usage with CNPG

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg
spec:
  instances: 2
  imageName: docker.io/hubbitus/postgres-cnpg-extensions:pg18-latest
  postgresql:
    shared_preload_libraries:
      - pg_cron
    parameters:
      cron.database_name: app
  bootstrap:
    initdb:
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS vector;
        - CREATE EXTENSION IF NOT EXISTS pg_cron;
        - CREATE EXTENSION IF NOT EXISTS pg_jsonschema;
        - CREATE EXTENSION IF NOT EXISTS temporal_tables;
```

## Local build

```bash
podman build -t postgres-cnpg-extensions:local .
podman run --rm -it -e POSTGRES_PASSWORD=x postgres-cnpg-extensions:local \
    postgres --version
```

Multi-arch check requires QEMU:

```bash
podman build --platform=linux/arm64 -t postgres-cnpg-extensions:arm64 .
```

## Version bump

1. Update `ARG` values in `Dockerfile` (`PGVECTOR_VERSION`, `PG_JSONSCHEMA_VERSION`, `TEMPORAL_TABLES_VERSION`, base digest).
2. Update version table above.
3. Add entry to [`CHANGELOG.md`](CHANGELOG.md).
4. Tag release: `git tag v0.x.y && git push --tags`.

## License

MIT — matches CNPG upstream. See [`LICENSE`](LICENSE).
