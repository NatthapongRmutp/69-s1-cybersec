#!/bin/bash
# Runs once, on first initialisation of the Postgres data volume
# (postgres image executes everything in /docker-entrypoint-initdb.d).
# Creates the dedicated least-privilege application account used by Strapi.
set -euo pipefail

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${DATABASE_USERNAME:?DATABASE_USERNAME is required}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}"

if [ "$DATABASE_USERNAME" = "$POSTGRES_USER" ]; then
    echo "ERROR: DATABASE_USERNAME must differ from the Postgres superuser '$POSTGRES_USER'."
    exit 1
fi

# Password is passed as a psql variable and quoted with :'...' so that any
# character (including single quotes) is escaped correctly.
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     --set=app_user="$DATABASE_USERNAME" \
     --set=app_password="$DATABASE_PASSWORD" \
     --set=db_name="$POSTGRES_DB" <<-'EOSQL'
    CREATE USER :"app_user" WITH PASSWORD :'app_password' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

    -- CONNECT is granted to PUBLIC by default, restated here for clarity.
    GRANT CONNECT ON DATABASE :"db_name" TO :"app_user";

    -- PostgreSQL 15+ removed CREATE for non-owners on schema "public",
    -- so Strapi needs this explicitly to create its own tables.
    GRANT USAGE, CREATE ON SCHEMA public TO :"app_user";

    -- Tables/sequences Strapi creates are owned by app_user already;
    -- these cover anything created later by the superuser.
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO :"app_user";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO :"app_user";
EOSQL

echo "App DB user '$DATABASE_USERNAME' created with least privilege (no superuser, no database ownership)."
