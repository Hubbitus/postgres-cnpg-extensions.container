# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Dual-mode entrypoint ([#2](https://github.com/Hubbitus/postgres-cnpg-extensions.container/issues/2)):
  standalone `podman run` / `docker run` / Testcontainers now boot the container
  via the stock `postgres:18` `docker-entrypoint.sh` (honouring `POSTGRES_PASSWORD`,
  `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_INITDB_ARGS`, `docker-entrypoint-initdb.d/*`).
  CNPG operator mode unaffected — operator overrides `command`/`args`, our
  `ENTRYPOINT` + `CMD` never execute under operator management.
- Initial scaffold: Dockerfile (multi-stage), GHA build+publish workflow, README.
- Bundled extensions on CNPG PG 18 `bookworm` base:
  - `pgvector` v0.8.6 (source build)
  - `pg_cron` from PGDG apt
  - `pg_jsonschema` v0.3.4 (source build via pgrx)
  - `temporal_tables` v1.2.2 (source build)
- Multi-arch build (`linux/amd64` + `linux/arm64`) → Docker Hub.
- Cosign keyless signing + SBOM via buildx.
