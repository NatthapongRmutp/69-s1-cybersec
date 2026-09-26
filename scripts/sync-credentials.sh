#!/bin/bash
# Makes ADMIN_PASSWORD and USER_PASSWORD in .env actually usable.
#
# These are only read by api.http; they are NOT Strapi settings, so changing
# them in .env does not change the stored passwords. The hashes in admin_users
# and up_users keep whatever they were set to when each account was created,
# which makes /admin/login fail with "Invalid credentials" and breaks both
# chains in api.http (1.1 -> Prereq.1 -> section 3, and 2.1 -> 2.4).
#
# Run this after rotating either password in .env, or after a fresh clone:
#
#   ./scripts/sync-credentials.sh
#
# bcrypt and the Postgres client are both already inside the app image, so this
# needs no extra tooling. The password is passed through the container
# environment and into a parameterised statement, so it never appears in the
# process list. The existing account is updated in place; none is created or
# deleted.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "ERROR: .env not found in $(pwd)" >&2
    exit 1
fi

# Read a single key from .env without sourcing the file (it is not shell-safe).
read_env() {
    sed -n "s/^$1=//p" .env | tail -n 1
}

ADMIN_EMAIL="$(read_env ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env ADMIN_PASSWORD)"
USER_EMAIL="$(read_env USER_EMAIL)"
USER_PASSWORD="$(read_env USER_PASSWORD)"

if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "ERROR: ADMIN_EMAIL and ADMIN_PASSWORD must both be set in .env" >&2
    exit 1
fi

if ! docker compose exec -T app true 2>/dev/null; then
    echo "ERROR: the app service is not running. Start it with: docker compose up -d" >&2
    exit 1
fi

docker compose exec -T -e ADMIN_EMAIL="$ADMIN_EMAIL" -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
                  -e USER_EMAIL="$USER_EMAIL" -e USER_PASSWORD="$USER_PASSWORD" \
    app node -e '
const bcrypt = require("bcryptjs");
const { Client } = require("pg");

(async () => {
  const client = new Client({
    host: process.env.DATABASE_HOST,
    port: Number(process.env.DATABASE_PORT || 5432),
    user: process.env.DATABASE_USERNAME,
    password: process.env.DATABASE_PASSWORD,
    database: process.env.DATABASE_NAME,
  });
  await client.connect();
  try {
    const { rowCount: adminRows } = await client.query(
      "UPDATE admin_users SET password = $1 WHERE email = $2",
      [bcrypt.hashSync(process.env.ADMIN_PASSWORD, 10), process.env.ADMIN_EMAIL]
    );
    if (adminRows === 0) {
      console.error("ERROR: no admin account with that email exists.");
      console.error("       Register one first: run the 1.2 request in api.http.");
      process.exit(1);
    }
    console.log("Admin password synced for " + process.env.ADMIN_EMAIL + ".");

    if (!process.env.USER_EMAIL || !process.env.USER_PASSWORD) {
      console.log("USER_EMAIL / USER_PASSWORD not set, skipping the user account.");
      return;
    }
    const { rowCount: userRows } = await client.query(
      "UPDATE up_users SET password = $1, confirmed = true WHERE email = $2",
      [bcrypt.hashSync(process.env.USER_PASSWORD, 10), process.env.USER_EMAIL]
    );
    if (userRows === 0) {
      console.log("User account " + process.env.USER_EMAIL + " does not exist yet.");
      console.log("Run the 2.2 Register request in api.http, then run this script again.");
      return;
    }
    console.log("User password synced for " + process.env.USER_EMAIL + ".");
  } finally {
    await client.end();
  }
})().catch((err) => {
  console.error("ERROR: " + err.message);
  process.exit(1);
});
'

echo "Re-run the login requests in api.http; old JWTs are no longer valid."
