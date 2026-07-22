%{ for schema in schema_names ~}
-- ==========================================
-- Create Schemas
-- ==========================================
CREATE SCHEMA IF NOT EXISTS ${schema};
%{ endfor ~}

%{ if length(schema_names) > 0 ~}
DO $$
BEGIN
   EXECUTE format('ALTER DATABASE %I SET search_path TO %s, public', current_database(), '${join(", ", schema_names)}');
END $$;
%{ else ~}
DO $$
BEGIN
   EXECUTE format('ALTER DATABASE %I SET search_path TO public', current_database());
END $$;
%{ endif ~}
