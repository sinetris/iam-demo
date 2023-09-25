#!/usr/bin/env bash
set -e

echo "Initialize database $POSTGRES_DB using user $POSTGRES_USER"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE USER notary;
	CREATE DATABASE notaryserver;
	CREATE DATABASE notarysigner;
	GRANT ALL PRIVILEGES ON DATABASE notaryserver TO notary;
	GRANT ALL PRIVILEGES ON DATABASE notarysigner TO notary;
EOSQL
