# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


## [0.11.1] - 2026-07-21
### Changed
- Reordered `az vm run-command invoke` command order in the `null_resource.destroy_init_vm`

## [0.11.0] - 2026-07-20
### Added
- Azure Private Endpoints resources for Azure Key Vault and Azure PostgreSQL Flexible
### Changed
- Moved Key Vault resources to its own Terraform file (`keyvault.tf`) for better organization

## [0.10.0] - 2026-07-18
### Changed
- Azure Key Vault to use [RBAC for authorization](https://learn.microsoft.com/en-us/azure/key-vault/general/access-control-default?tabs=azure-cli) over the legacy vault access policies
- Access policies replaced by role assignments

## [0.9.1] - 2026-07-14
### Changed
- Updated error message when `azure vm run-command invoke` in `null_resource.destroy_init_vm` fails to make it more clear

## [0.9.0] - 2026-07-13
### Added
- `hashicorp/cloudinit` provider for managing/rendering Cloud Init configs
### Changed
- Major changes to how the server is initializerd
- SQL statements are run with multiple templated SQL scripts in `scripts/sql`

## [0.8.0] - 2026-07-11
### Added
- `terraform/time` provider so I can add in a sleep timer as sometimes the Bastion provisioning may fail if the VNet isn't yet ready
### Changed
- Added more verbose output during the `null_resource.destroy_init_vm` local-exec loop
- Reduced check interval from 30s to 20s

## [0.7.0] - 2026-07-06
### Changed
- This update reduces costs significantly by reducing Bastion SKU/tier!
- Changes to Bastion SKU from `Standard` (~$5/day) to `Developer` (free!), but as a result, Bastion access is via Azure Portal
- Removed AzureBastionSubnet and added required App subnet NSG rules to accommodate the change

## [0.6.0] - 2026-07-03
### Added
- Added Private Endpoint subnet
- Added variable, `disable_password_authentication` (default: `false`), which then triggers the use of a random password for VM admin. If set `true`, uses SSH key auth instead.
### Removed
- Redundant `depends_on` statements for subnet resources

## [0.5.0] - 2026-07-02
### Added
- Added `network_acl` configuration for Azure Key Vault for additional security
- Added variable, `network_acls_ip_rules` (default: `[]`) to allow-list IPs for anyone running Terraform apply from local machine
- Added variables, `pgbouncer_enabled` (default: `false`) and `pgbouncer_setting` for enabling and configuring [PgBouncer on PostgreSQL Flexible](https://learn.microsoft.com/en-us/azure/postgresql/connectivity/concepts-pgbouncer)
- Added `tags` to PostgreSQL Flexible server's lifecycle `ignore_changes` list
### Removed
- Provider blocks for `random` and `null` as they have no configurable arguments

## [0.4.1] - 2026-07-01 - Happy birthday, Canada!
### Added
- Added variables, `collation` (default: `en_US.utf8`), and `charset` (default: `utf8`) used for setting up database

## [0.4.0] - 2026-06-27
### Added
- `hashicorp/random` provider to generate the admin password instead
- Added variable, `auto_grow_enabled` (default: `false`) for toggling the [storage autogrow](https://learn.microsoft.com/en-us/azure/postgresql/scale/how-to-auto-grow-storage) feature.
### Removed
- Removed variable, `storage_tier`, leaving Azure to set its default value, which is dependent on `storage_mb`
- Removed variable, `admin_password`, and leveraging Random provider and `random_password` resource to generate a random one instead
### Changed
- Default `sku` changed from `GP_Standard_D2s_v3` to `B_Standard_B1ms`

## [0.3.1] - 2026-06-23
### Changed
- Added variable, `zone` (default: `null`), to replace hardcoded `zone` in `postgresql_flexible_server` config
- Added `lifecycles` rules for `zone` and `high_availability` standby zone changes that can show up in subsequent Terraform applies to be ignored
- The PostgreSQL Flexible server's name is incorporated into the init VM's name
- Default `enable_initialization` changed from `false` to `true`

## [0.3.0] - 2026-06-20
### Changed
- `null_resource.destroy_init_vm` logic for determining whether `scripts/psql_init.sh` is complete (for existence of `/tmp/psql_init_done`)

## [0.2.0] - 2026-06-19
### Added
- AzureRM provider features for `postgresql_flexible_server` and `virtual_machine`
### Changed
- `scripts/psql-init.sh` for full templating
- `scripts/psql-init.sh` to run loop to valid Azure Key Vault access propagation status

## [0.1.0] - 2026-06-17
### Added
- Initial commit
