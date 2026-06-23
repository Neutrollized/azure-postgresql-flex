# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


## [0.3.1] - 2026-06-23
### Changed
- Added variable, `zone` (default: `null`), to replace hardcoded `zone` in `postgresql_flexible_server` config
- Added `lifecycles` rules for `zone` and `high_availability` standby zone changes that can show up in subsequent Terraform applies to be ignored
- The PostgreSQL Flexible server's name is incorporated into the init VM's name

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
