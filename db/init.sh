#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER "$DATABASE_USERNAME" WITH PASSWORD '$DATABASE_PASSWORD';
    ALTER DATABASE "$POSTGRES_DB" OWNER TO "$DATABASE_USERNAME";
EOSQL

echo "App DB user created with least privilege."