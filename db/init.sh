#!/bin/bash
# Creates (or repairs) the dedicated least-privilege application account used
# by Strapi.
#
# The postgres image runs everything in /docker-entrypoint-initdb.d, so this
# runs automatically on the FIRST initialisation of the data volume only.
# On a volume that already exists it is never executed, so it is written to be
# idempotent and can be re-run by hand to upgrade an older database:
#
#   docker compose exec db bash /docker-entrypoint-initdb.d/10-init.sh
#
# That is required after switching DATABASE_USERNAME away from the Postgres
# superuser, otherwise the app fails with
# "password authentication failed for user <name>".
set -euo pipefail

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${DATABASE_USERNAME:?DATABASE_USERNAME is required}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}"

if [ "$DATABASE_USERNAME" = "$POSTGRES_USER" ]; then
    echo "ERROR: DATABASE_USERNAME must differ from the Postgres superuser '$POSTGRES_USER'."
    exit 1
fi

# The password is passed as a psql variable and quoted with :'...' so that any
# character (including single quotes) is escaped correctly.
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     --set=app_user="$DATABASE_USERNAME" \
     --set=app_password="$DATABASE_PASSWORD" \
     --set=db_name="$POSTGRES_DB" <<-'EOSQL'
    -- Create the role on a fresh volume, or leave an existing one alone.
    -- \gexec runs the generated command, and produces nothing when the role
    -- is already there, which makes this safe to re-run. (A DO $$ block
    -- cannot be used here: psql does not substitute variables inside
    -- dollar-quoted strings.)
    SELECT format('CREATE ROLE %I LOGIN', :'app_user')
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
    \gexec

    -- Idempotent, so this also repairs a role left over from an older setup.
    ALTER ROLE :"app_user" WITH LOGIN PASSWORD :'app_password'
        NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

    -- CONNECT is granted to PUBLIC by default, restated here for clarity.
    GRANT CONNECT ON DATABASE :"db_name" TO :"app_user";

    -- PostgreSQL 15+ removed CREATE for non-owners on schema "public",
    -- so Strapi needs this explicitly to create its own tables.
    GRANT USAGE, CREATE ON SCHEMA public TO :"app_user";

    -- Tables/sequences Strapi creates are owned by app_user already;
    -- these cover anything created later by the superuser.
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO :"app_user";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO :"app_user";

    -- Adopt tables a previous setup created under the superuser account.
    -- Strapi must own its own tables to run migrations, and without this the
    -- app user gets "permission denied" on an upgraded database. No-op on a
    -- fresh volume, and safe to repeat.
    SELECT format('ALTER TABLE %I.%I OWNER TO %I', schemaname, tablename, :'app_user')
    FROM pg_tables
    WHERE schemaname = 'public' AND tableowner <> :'app_user'
    \gexec

    SELECT format('ALTER SEQUENCE %I.%I OWNER TO %I', sequence_schema, sequence_name, :'app_user')
    FROM information_schema.sequences
    WHERE sequence_schema = 'public'
    \gexec
EOSQL

echo "App DB user '$DATABASE_USERNAME' is ready (no superuser, no database ownership)."
