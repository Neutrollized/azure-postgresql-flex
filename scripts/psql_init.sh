#!/bin/bash
# NOTE: templated script can be found in /var/lib/cloud/instance/ on VM
set -e
exec > /var/log/cloud-init-output.log 2>&1

export TERM=xterm-256color
export PAGER=cat

echo "\n----- STARTING psql_init.sh -----\n"

apt-get update -y
apt-get install -y postgresql-client

# install azure-cli
curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash

echo "Login using managed identity..."
az login --identity --allow-no-subscriptions

echo "Giving time for manage identity permissions to propagate..."
for i in {1..30}; do
  if az keyvault secret show \
       --vault-name ${akv_name} \
       --name "${akv_secret_db_username}" \
       --query value -o tsv > /dev/null 2>&1; then
    echo "Key Vault access confirmed"
    break
  fi
  echo "Attempt $i: Key Vault access not yet propagated, retrying in 10s..."
  sleep 10
done

echo "Fetching DB username from Key Vault..."
export DB_USER=$(az keyvault secret show \
  --vault-name ${akv_name} \
  --name ${akv_secret_db_username} \
  --query value -o tsv)

echo "Fetching DB password from Key Vault..."
export DB_PASSWORD=$(az keyvault secret show \
  --vault-name ${akv_name} \
  --name ${akv_secret_db_password} \
  --query value -o tsv)


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


echo "Executing SQL scripts..."
for f in $(ls /opt/psql_init/sql/*.sql | sort); do
  echo "Running $f"
  PGPASSWORD="$${DB_PASSWORD}" psql \
    "host=${db_host} port=5432 dbname=${db_name} user=$${DB_USER} sslmode=require" \
    -f "$f"
done

# Signal success
touch /tmp/psql_init_done
