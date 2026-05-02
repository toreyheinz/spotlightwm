# =============================================================================
# spotlight Dockerfile — Phoenix release for GitBlixt PaaS
# Postgres is external (host PG via host.docker.internal) — see DATABASE_URL.
# =============================================================================

ARG ELIXIR_VERSION=1.19.3
ARG OTP_VERSION=27.3.1
ARG DEBIAN_VERSION=bookworm-20260112-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

# =============================================================================
# Stage 1: deps — fetch and compile dependencies
# =============================================================================
FROM ${BUILDER_IMAGE} AS deps

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Prevent prim_tty NIF crash when building under QEMU emulation
ENV ERL_FLAGS="-noinput"

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# =============================================================================
# Stage 2: builder — compile the release
# =============================================================================
FROM deps AS builder

ENV MIX_ENV="prod"

RUN mix assets.setup

COPY priv priv
COPY lib lib
RUN mix compile

COPY assets assets
RUN mix assets.deploy

COPY config/runtime.exs config/
COPY rel rel
RUN mix release --overwrite

RUN find /app/_build/prod/rel/spotlight -name "*.so" -exec strip --strip-debug {} + 2>/dev/null || true

# =============================================================================
# Stage 3: runner — production image
# =============================================================================
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libncurses6 \
    locales \
    ca-certificates \
    curl \
    postgresql-client \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/spotlight ./

# Phoenix runtime expects PHX_SERVER=true to actually bind the listener
ENV PHX_SERVER=true
ENV PORT=4000

HEALTHCHECK --interval=10s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -sf http://localhost:${PORT}/ || exit 1

EXPOSE 4000

# Wait for DB, run migrations, then start the release.
# Inlined entrypoint avoids shipping a separate script.
CMD ["sh", "-c", "\
  if [ -n \"${DATABASE_URL:-}\" ]; then \
    DB_HOST=$(echo \"$DATABASE_URL\" | sed 's|.*@\\([^/:]*\\).*|\\1|'); \
    echo \"Waiting for database at ${DB_HOST}...\"; \
    until pg_isready -h \"$DB_HOST\" -q 2>/dev/null; do sleep 1; done; \
  fi; \
  echo 'Running migrations...'; \
  /app/bin/migrate; \
  echo 'Starting spotlight...'; \
  exec /app/bin/server\
"]
