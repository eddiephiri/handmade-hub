#!/bin/sh
set -eu

# Wait for database if DATABASE_URL provided and host:port can be parsed
if [ -n "${DATABASE_URL:-}" ]; then
  # Extract hostname and port from ecto URL: ecto://USER:PASS@HOST:PORT/DB
  hostport=$(printf "%s" "$DATABASE_URL" | sed -E 's#^ecto://[^@]+@([^/]+)/.*$#\1#')
  host=$(printf "%s" "$hostport" | cut -d: -f1)
  port=$(printf "%s" "$hostport" | cut -d: -f2)
  port=${port:-5432}
  if [ -n "$host" ]; then
    echo "Waiting for DB $host:$port ..."
    for i in $(seq 1 60); do
      if nc -z "$host" "$port" >/dev/null 2>&1; then
        echo "Database is up"
        break
      fi
      sleep 1
    done
  fi
fi

echo "Running migrations..."
bin/handmade_hub eval 'HandmadeHub.Release.migrate()'

# Ensure uploads directory exists
mkdir -p /app/priv/static/uploads

# Set crash dump location to a mounted volume for easier access
export ERL_CRASH_DUMP=/app/crash_dumps/erl_crash.dump
mkdir -p /app/crash_dumps

echo "Starting app..."
# Set UTF-8 encoding for Elixir/Erlang VM (critical for proper operation)
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ELIXIR_ERL_OPTIONS="+fnu +fnl"

# Start the app and capture all output
echo "Starting application (this may take a moment)..."
bin/handmade_hub start 2>&1 | tee /tmp/app_start.log || {
  EXIT_CODE=$?
  echo "=== Application failed to start (exit code: $EXIT_CODE) ==="
  echo "=== Last 100 lines of startup log ==="
  tail -n 100 /tmp/app_start.log 2>/dev/null || echo "Could not read log file"
  echo "=== Checking for crash dump ==="
  if [ -f /app/crash_dumps/erl_crash.dump ]; then
    echo "Crash dump found at /app/crash_dumps/erl_crash.dump"
    echo "Last 50 lines of crash dump:"
    tail -n 50 /app/crash_dumps/erl_crash.dump | strings | tail -n 20
  fi
  exit $EXIT_CODE
}


