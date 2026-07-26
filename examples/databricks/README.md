# Databricks to PostgreSQL Flex

This Terraform example code will setup Databricks Secret Scope for you so you can connect to your PostgreSQL Flex server to do data things.

## Requirements & Assumptions
From a network perspective, Databricks and PostgreSQL Flex private endpoint should either be in the same VNet or be peered (if they are in different VNets)

> [!NOTE]
> If you're using `az login` to authenticate, but have `DATABRICKS_TOKEN` set in your env vars,
> you will get an error. I would just unset the Databricks token, or you can pass it in as a var
> in your provider config


### Code Example
Here's an example of how you would get the secrets from Key Vault and then connect to your Postgres database from your Databricks environment (e.g., via Notebook)


```python
pg_username = dbutils.secrets.get(scope="my-psql-flex-kv-scope", key="my-psql-flex-server-admin-username")

pg_password = dbutils.secrets.get(scope="my-psql-flex-kv-scope", key="my-psql-flex-server-admin-password")
```

```python
import psycopg2

host = "my-psql-flex-server.postgres.database.azure.com"
port = "5432"
dbname = "geospatial_db"

try:
    conn = psycopg2.connect(
        host=host,
        port=port,
        dbname=dbname,
        user=pg_username,
        password=pg_password,
        sslmode="require"
    )

    cursor = conn.cursor()
    cursor.execute("SELECT versio();")
    db_version = cursor.fetchone()

    print(f"Successfully connected to PostgreSQL Flex. Postgres version: {db_version}")
    
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Connection failed: {e}")
```
