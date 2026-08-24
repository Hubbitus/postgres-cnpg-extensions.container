# syntax=docker/dockerfile:1.7
# CNPG PostgreSQL 18 image bundling extensions used across Hubbitus projects.
# Base pinned by digest for reproducibility — bump via renovate / manual PR.
ARG CNPG_BASE=ghcr.io/cloudnative-pg/postgresql:18.6-202608170814-system-bookworm@sha256:83229f82cf85a38c3b13d9edbc0667763006514b499510540d704a21c9aa725a

ARG PG_MAJOR=18
ARG PGVECTOR_VERSION=v0.8.6
# pg_jsonschema: latest tag v0.3.4 depends on pgrx 0.16 (max PG17). PG 18 support only on master
# (pgrx 0.19.2). Pinned by commit SHA until upstream cuts v0.3.5+.
ARG PG_JSONSCHEMA_REF=d08e4dea14549858b54791d6da4f606dc58a512e
ARG PGRX_VERSION=0.19.2
ARG TEMPORAL_TABLES_VERSION=v1.2.2

# ---------- Stage 1: build extensions from source ----------
FROM ${CNPG_BASE} AS builder

USER root

ARG PG_MAJOR
ARG PGVECTOR_VERSION
ARG PG_JSONSCHEMA_REF
ARG PGRX_VERSION
ARG TEMPORAL_TABLES_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        pkg-config \
        libssl-dev \
        libclang-dev \
        clang \
        "postgresql-server-dev-${PG_MAJOR}" \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain for pg_jsonschema (pgrx).
ENV CARGO_HOME=/opt/cargo RUSTUP_HOME=/opt/rustup PATH=/opt/cargo/bin:${PATH}
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
        --default-toolchain stable --profile minimal -y

WORKDIR /build

# pgvector — plain C, make USE_PGXS=1.
RUN git clone --depth 1 --branch "${PGVECTOR_VERSION}" https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make USE_PGXS=1 OPTFLAGS="" \
    && make USE_PGXS=1 install \
    && cd .. && rm -rf pgvector

# temporal_tables — plain C, PGXS.
RUN git clone --depth 1 --branch "${TEMPORAL_TABLES_VERSION}" https://github.com/arkhipov/temporal_tables.git \
    && cd temporal_tables \
    && make USE_PGXS=1 \
    && make USE_PGXS=1 install \
    && cd .. && rm -rf temporal_tables

# pg_jsonschema — Rust via cargo-pgrx.
# pgrx version tracks upstream Cargo.toml; pin conservatively — bump on release.
RUN cargo install --locked cargo-pgrx --version "${PGRX_VERSION}" \
    && cargo pgrx init --pg${PG_MAJOR} "$(command -v pg_config)" \
    && git clone https://github.com/supabase/pg_jsonschema.git \
    && cd pg_jsonschema \
    && git checkout "${PG_JSONSCHEMA_REF}" \
    && cargo pgrx install --release --pg-config "$(command -v pg_config)" \
    && cd .. && rm -rf pg_jsonschema

# ---------- Stage 2: final runtime image ----------
FROM ${CNPG_BASE}

USER root

ARG PG_MAJOR
ENV DEBIAN_FRONTEND=noninteractive

# pg_cron from PGDG apt (already present in CNPG base's PGDG list).
RUN apt-get update && apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}-cron" \
    && rm -rf /var/lib/apt/lists/*

# Copy extension artefacts from builder — libs + .control + .sql + docs (bitcode optional).
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/           /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/   /usr/share/postgresql/${PG_MAJOR}/extension/

# pg_cron needs shared_preload_libraries — CNPG operator injects postgresql.auto.conf,
# but we ship a sensible default that gets picked up if operator does not override.
# Operator override wins; this is defence in depth for direct-container debugging.
RUN mkdir -p /usr/share/postgresql/${PG_MAJOR}/extension \
    && printf "shared_preload_libraries = 'pg_cron'\n" > /etc/postgresql-cnpg-extensions.conf

# ---------- Dual-mode entrypoint (issue #2) ----------
# Under CNPG operator: operator sets `command`/`args` on the pod, overriding both
# ENTRYPOINT and CMD below — this block is a no-op for operator-managed clusters.
# Under standalone `docker run` / `podman run` / Testcontainers: the stock postgres:18
# entrypoint kicks in, honouring POSTGRES_PASSWORD / POSTGRES_USER / POSTGRES_DB /
# POSTGRES_INITDB_ARGS / docker-entrypoint-initdb.d/*.
#
# PG binaries already on PATH via CNPG base (/usr/lib/postgresql/18/bin).
# PGDATA matches stock postgres:18 default (docker-library/postgres convention).
# Ownership: /var/lib/postgresql is owned by uid 26 (postgres) in CNPG base, so
# non-root container start (USER 26 below) can mkdir/init PGDATA without chown.
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-ensure-initdb.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-ensure-initdb.sh \
    && ln -sf docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh \
    && mkdir -p /docker-entrypoint-initdb.d /var/lib/postgresql/${PG_MAJOR}/docker \
    && chown 26:102 /docker-entrypoint-initdb.d /var/lib/postgresql/${PG_MAJOR}/docker \
    && chmod 0750 /docker-entrypoint-initdb.d
ENV PGDATA=/var/lib/postgresql/${PG_MAJOR}/docker

USER 26

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]

LABEL org.opencontainers.image.title="postgres-cnpg-extensions" \
      org.opencontainers.image.description="CNPG PostgreSQL 18 with pgvector, pg_cron, pg_jsonschema, temporal_tables (dual-mode: CNPG operator + standalone)" \
      org.opencontainers.image.source="https://github.com/Hubbitus/postgres-cnpg-extensions.container" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Hubbitus"
