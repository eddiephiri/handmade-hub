# syntax=docker/dockerfile:1.7

# ---- Builder image ----
FROM elixir:1.16.2 AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Install build dependencies: build-essential, git, node for assets if needed
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git curl nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Prepare build cache layers
RUN mix local.hex --force && \
    mix local.rebar --force

# Install Node deps only if assets exist (Phoenix 1.7 with esbuild/tailwind Mix tasks)
COPY mix.exs mix.lock ./
COPY config config
COPY package.json package-lock.json ./

# Fetch deps
RUN mix deps.get --only prod && \
    mix deps.compile

# Install Node.js dependencies (including Preline)
RUN npm ci --only=production

# Copy the rest of the app
COPY . .

# Ensure deps are up to date in case options changed after cache step
RUN mix deps.get --only prod

# Build assets
RUN mix assets.deploy

# Compile and build the release
RUN mix compile && \
    mix release

# Copy static assets into the release directory structure
RUN cp -r priv/static _build/prod/rel/handmade_hub/

# ---- Runtime image ----
FROM debian:bookworm-slim AS app

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends openssl ca-certificates libstdc++6 curl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true

WORKDIR /app

# Copy release from build stage (now includes static assets)
COPY --from=build /app/_build/prod/rel/handmade_hub ./

# Copy the priv directory (contains seeds and migrations)
COPY --from=build /app/priv ./priv

# Copy entrypoint script
COPY docker/entry.sh /app/entry.sh
RUN chmod +x /app/entry.sh

# Default port (can be overridden by PORT env)
EXPOSE 9706

CMD ["/app/entry.sh"]
