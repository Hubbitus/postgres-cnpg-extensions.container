# postgres-cnpg-extensions

[![Build](https://github.com/Hubbitus/postgres-cnpg-extensions.container/actions/workflows/build.yml/badge.svg)](https://github.com/Hubbitus/postgres-cnpg-extensions.container/actions/workflows/build.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/hubbitus/postgres-cnpg-extensions?logo=docker&label=Docker%20Hub)](https://hub.docker.com/r/hubbitus/postgres-cnpg-extensions)
[![Image size](https://img.shields.io/docker/image-size/hubbitus/postgres-cnpg-extensions/pg18-latest?logo=docker)](https://hub.docker.com/r/hubbitus/postgres-cnpg-extensions/tags)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

CNPG PostgreSQL 18 image bundling extensions used across Hubbitus projects.

Public re-usable image — not tied to any specific downstream project.

Published: [`docker.io/hubbitus/postgres-cnpg-extensions`](https://hub.docker.com/r/hubbitus/postgres-cnpg-extensions).

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

## Usage with podman / docker run

Standalone boot uses the stock `postgres:18` entrypoint (dual-mode, [#2](https://github.com/Hubbitus/postgres-cnpg-extensions.container/issues/2)) — same env vars as the official `postgres` image:

```bash
podman run --rm \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=app \
    -p 5432:5432 \
    docker.io/hubbitus/postgres-cnpg-extensions:pg18-latest
```

Supported env: `POSTGRES_USER` (default `postgres`), `POSTGRES_PASSWORD` (required unless `POSTGRES_HOST_AUTH_METHOD=trust`), `POSTGRES_DB`, `POSTGRES_INITDB_ARGS`, `POSTGRES_HOST_AUTH_METHOD`, `POSTGRES_INITDB_WALDIR`. Init SQL: mount into `/docker-entrypoint-initdb.d/`. See [official postgres docs](https://hub.docker.com/_/postgres) for details.

Standalone mode does not auto-load `pg_cron` (CNPG operator manages `shared_preload_libraries` in the CNPG mode). To enable `pg_cron` in standalone runs, mount a custom config with `shared_preload_libraries=pg_cron` and pass `-c config_file=...`.

Under the CNPG operator our `ENTRYPOINT` / `CMD` are silently overridden — no behavioural change vs. the previous release.

(Replace `podman` with `docker` — same flags.)

### Testcontainers (Java)

```java
var image = DockerImageName
    .parse("docker.io/hubbitus/postgres-cnpg-extensions:pg18-latest")
    .asCompatibleSubstituteFor("postgres");
try (var pg = new PostgreSQLContainer<>(image)) {
    pg.start();
    // pg.getJdbcUrl(), pg.getUsername(), pg.getPassword()
}
```

## Usage with podman-compose / docker-compose

```yaml
services:
  pg:
    image: docker.io/hubbitus/postgres-cnpg-extensions:pg18-latest
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: app
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/18/docker

volumes:
  pgdata:
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
