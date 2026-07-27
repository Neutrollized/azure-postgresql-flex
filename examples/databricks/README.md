# Databricks to PostgreSQL Flex

This Terraform example code will setup Databricks Secret Scope for you so you can connect to your PostgreSQL Flex server to do data things.

> [!IMPORTANT]
> Because I'm using a private endpoint for the PostgreSQL Flex, you will need an actual compute cluster.
> Otherwise Databricks will attach *Serverless Compute* to the execution, which will fail as it has no VNet connectivity.

## Requirements & Assumptions
From a network perspective, Databricks and PostgreSQL Flex private endpoint should either be in the same VNet or be peered (if they are in different VNets)

> [!NOTE]
> If you're using `az login` to authenticate, but have `DATABRICKS_TOKEN` set in your env vars,
> you will get an error. I would just unset the Databricks token, or you can pass it in as a var
> in your provider config


### Code Example
Here's an example of how you would get the secrets from Key Vault and then connect to your Postgres database from your Databricks environment (e.g., via Notebook)

- validate Key Vault/secret scope config:
```python
pg_username = dbutils.secrets.get(scope="my-psql-flex-kv-scope", key="my-psql-flex-server-admin-username")

pg_password = dbutils.secrets.get(scope="my-psql-flex-kv-scope", key="my-psql-flex-server-admin-password")
```

- validate networking:
```python
import socket
import ssl

host = "my-psql-flex-server.postgres.database.azure.com"
port = 5432

print(f"--- 1. Testing DNS Resolution for {host} ---")
try:
    ip_address = socket.gethostbyname(host)
    print(f"SUCCESS: Resolve {host} to IP: {ip_address}")
except Exception as e:
    print(f"FAILED (DNS Issue): Could not resolve hostname. Error: {e}")

print(f"\n--- 2. Testing TCP Port Connectivity to {host}:{port} ---")
try:
    sock = socket.create_connection((host, port), timeout=5)
    print(f"SUCCESS: Port {port} is OPEN and reachable!")
except Exception as e:
    print(f"FAILED (Network/NSG Issue): Cannot reach port {port}. Error: {e}")
```

> [!NOTE]
> If you're finding that a DNS is returning an IP *not* from you PE subnet,
> check to make sure you notebook is being backed by a compute cluster.
> (click the green circle next to the play button in the upper-right corner of notebook)


- validate DB connectivity:
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
    cursor.execute("SELECT version();")
    db_version = cursor.fetchone()

    print(f"Successfully connected to PostgreSQL Flex. Postgres version: {db_version}")
    
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Connection failed: {e}")
```
