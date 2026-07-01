# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


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
