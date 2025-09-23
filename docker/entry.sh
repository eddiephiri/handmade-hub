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

echo "Starting app..."
exec bin/handmade_hub start


