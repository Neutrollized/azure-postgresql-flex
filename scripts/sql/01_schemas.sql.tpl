%{ for schema in schema_names ~}
-- ==========================================
-- Create Schemas
-- ==========================================
CREATE SCHEMA IF NOT EXISTS ${schema};
%{ endfor ~}

%{ if length(schema_names) > 0 ~}
ALTER DATABASE IF EXISTS current_database() SET search_path TO ${join(", ", schema_names)}, public;
%{ else ~}
ALTER DATABASE IF EXISTS current_database() SET search_path TO public;
%{ endif ~}
