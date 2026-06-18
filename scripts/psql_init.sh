#!/bin/bash
set -e
exec > /var/log/cloud-init-output.log 2>&1

echo "export TERM=xterm-256color" | sudo tee /etc/profile.d/set-term.sh
export TERM=xterm-256color
export PAGER=cat

apt-get update -y
apt-get install -y postgresql-client

# install azure-cli
curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash

# Wait for managed identity to be available
echo "Waiting for managed identity..."
sleep 10
# login using managed identity
az login --identity --allow-no-subscriptions

# Fetch secrets from Key Vault
export DB_PASSWORD=$(az keyvault secret show \
  --vault-name my-psql-kv \
  --name psql-admin-password \
  --query value -o tsv)

export DB_USER=$(az keyvault secret show \
  --vault-name my-psql-kv \
  --name psql-admin-username \
  --query value -o tsv)

sleep 2

echo "Waiting for PostgreSQL to be ready..."
for i in {1..10}; do
  if PGPASSWORD="$${DB_PASSWORD}" psql \
    "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
    -c "SELECT 1;" > /dev/null 2>&1; then
    echo "PostgreSQL is ready"
    break
  fi
  echo "Attempt $i failed, retrying in 10s..."
  sleep 10
done


PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS postgis CASCADE;"

PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS postgis_raster CASCADE;"

PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS postgis_topology CASCADE;"

PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch CASCADE;"

PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS address_standardizer CASCADE;"

PGPASSWORD="$${DB_PASSWORD}" psql \
  "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS pg_trgm CASCADE;"

# Signal success
touch /tmp/psql_init_done
