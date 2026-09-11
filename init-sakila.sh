#!/usr/bin/env sh
set -e

echo "=== [Sakila Init] Downloading Sakila Schema and Base Data ==="
wget -q "https://raw.githubusercontent.com/jOOQ/sakila/main/postgres-sakila-db/postgres-sakila-schema.sql" -O /tmp/schema.sql
wget -q "https://raw.githubusercontent.com/jOOQ/sakila/main/postgres-sakila-db/postgres-sakila-insert-data.sql" -O /tmp/data.sql

echo "=== [Sakila Init] Loading Schema into PostgreSQL ==="
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/schema.sql

echo "=== [Sakila Init] Loading Base Sakila Data ==="
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/data.sql

rm -f /tmp/schema.sql /tmp/data.sql
echo "=== [Sakila Init] Complete! Base Sakila database ready. ==="