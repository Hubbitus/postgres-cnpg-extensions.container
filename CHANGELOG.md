# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING** — Image tags now start with the major version digit instead of the `pg` prefix
  ([#6](https://github.com/Hubbitus/postgres-cnpg-extensions.container/issues/6)):
  `pg18-latest` → `18-latest`, `pg18-<date>-<sha>` → `18-<date>-<sha>`, `pg18-<sha>` → `18-<sha>`.
  Required because the CloudNativePG (CNPG) `Cluster` admission webhook rejects tags that do
  not start with a digit (regex `^(\d\.?)+` in `cloudnative-pg/machinery` `pkg/postgres/version`),
  which makes every previous tag unusable via `spec.imageName` — the primary intended consumer.
  Consumers pinning `pg18-*` tags must switch to `18-*`. Old tags remain published historically
  but are no longer produced by CI.

### Added

- Dual-mode entrypoint ([#2](https://github.com/Hubbitus/postgres-cnpg-extensions.container/issues/2)):
  standalone `podman run` / `docker run` / Testcontainers now boot the container
  via the stock `postgres:18` `docker-entrypoint.sh` (honouring `POSTGRES_PASSWORD`,
  `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_INITDB_ARGS`, `docker-entrypoint-initdb.d/*`).
  CNPG operator mode unaffected — operator overrides `command`/`args`, our
  `ENTRYPOINT` + `CMD` never execute under operator management.
- CI smoke job: builds amd64 image on every PR, boots it standalone, asserts
  `pg_isready`, PG major = 18, and all four extensions (`vector`, `temporal_tables`,
  `pg_jsonschema`, `pg_cron`) `CREATE EXTENSION` successfully.
- CI `smoke-cnpg` job ([#4](https://github.com/Hubbitus/postgres-cnpg-extensions.container/issues/4)):
  spins up kind cluster + CNPG operator v1.30.0, applies a `Cluster` CR pointing at
  the just-built image, waits for healthy, asserts all four extensions loaded via
  operator-managed init. Catches regressions in ENTRYPOINT/CMD override contract,
  `USER 26`, PGDATA perms, and extension load under operator management.
- Initial scaffold: Dockerfile (multi-stage), GHA build+publish workflow, README.
- Bundled extensions on CNPG PG 18 `bookworm` base:
  - `pgvector` v0.8.6 (source build)
  - `pg_cron` from PGDG apt
  - `pg_jsonschema` v0.3.4 (source build via pgrx)
  - `temporal_tables` v1.2.2 (source build)
- Multi-arch build (`linux/amd64` + `linux/arm64`) → Docker Hub.
- Cosign keyless signing + SBOM via buildx.
