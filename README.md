# Azure PostgreSQL Flexible

Deploys an Azure PostgreSQL Flexible server along with an Azure Bastion and Linux VM jumpbox for secure connectivity. 

Core resources used:
- Azure PostgreSQL Flexible Server
- Azure Bastion
- Azure Linux VM
- Azure Key Vault
- Azure Private Endpoint

> [!NOTE]
> If you deploy in separate resource groups, Private DNS Zone + Virtual Network Link should be in your Network RG,
> while the Private Endpoint should be in your Database and Key Vault RGs as they align with the resource's lifecycle. 


# Prerequisites
You will need the Azure CLI and the following [extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list?view=azure-cli-latest) if you're using the *Standard Bastion SKU*:
```sh
az extension add --name bastion
az extension add --name ssh
```


## Installing PostgreSQL Extensions
If you have a public endpoint, you can probably allowlist your IP and use a `null_resource` to connect to your PostgreSQL server to execute the necessary `psql` commands. You might even leverage the [PostgreSQL provider](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs) to do so. However, we have a secure, private server and I don't have an Azure DevOps runner (or something equivalent) and just want to be able to set this up all from my Macbook!

For this, I leverage [cloud-init](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init) and a private VM in the same VNet as my PostgreSQL Flexible server. The init script will execute *once* upon being the VM being deployed. The script will install the `psql` and `az` binaries so that I can then use connect to connect to my DB server and install the extensions. I then use a `null_resource` to run a command to delete the init VM.


### Validation
If you wish to validate, you can connect to the jumpbox via bastion and connect to the PostgreSQL Flexible server from there (commands can be found in `terraform output`). Once connected, you can see list all the available PG Extensions with:

```sql 
SELECT * FROM pg_available_extensions;
```

> [!TIP]
> Schema: `\dn`
> Default access privileges: `\ddp`
> Users: `\du`
> Tables: `\dt` (`\dt [schema].*` to see tables in other schemas)
> Functions: `\df` 
> Triggers: `\dS` 
