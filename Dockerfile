# syntax=docker/dockerfile:1.7

# ---- Builder image ----
FROM elixir:1.16.2 AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Install build dependencies: build-essential, git, node for assets if needed
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git curl nodejs npm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

# Prepare build cache layers
RUN mix local.hex --force && \
    mix local.rebar --force

# Install Node deps only if assets exist (Phoenix 1.7 with esbuild/tailwind Mix tasks)
COPY mix.exs mix.lock ./
COPY config config
COPY package.json package-lock.json ./

# Fetch deps and clean build cache
RUN mix deps.get --only prod && \
    mix deps.compile && \
    mix deps.clean --unused

# Install Node.js dependencies (including Preline)
# Use --omit=dev instead of --only=production (deprecated)
# Clean npm cache to save space
RUN npm ci --omit=dev && \
    npm cache clean --force

# Copy the rest of the app
COPY . .

# Ensure deps are up to date in case options changed after cache step
# Clean unused deps to save space
RUN mix deps.get --only prod && \
    mix deps.clean --unused

# Build assets
RUN mix assets.deploy

# Remove node_modules after building assets to save space
RUN rm -rf node_modules

# Compile and build the release
# Clean up build artifacts to save space
RUN mix compile && \
    mix release && \
    rm -rf _build/prod/lib/*/ebin/*.beam.d && \
    find _build/prod/lib -name "*.beam" -not -path "*/rel/*" -delete || true

# Copy static assets into the release directory structure
RUN cp -r priv/static _build/prod/rel/handmade_hub/

# ---- Runtime image ----
FROM debian:bookworm-slim AS app

# Install runtime dependencies including wkhtmltopdf for PDF generation
# and locales for UTF-8 support
RUN mkdir -p /tmp/apt-cache && \
    apt-get update -y && \
    apt-get install -y -o Dir::Cache::Archives=/tmp/apt-cache \
        --no-install-recommends \
        openssl \
        ca-certificates \
        libstdc++6 \
        curl \
        netcat-openbsd \
        wkhtmltopdf \
        locales && \
    # Generate UTF-8 locale
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/apt-cache/*

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    ELIXIR_ERL_OPTIONS="+fnu +fnl"

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
