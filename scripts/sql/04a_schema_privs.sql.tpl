%{ for role_name, schemas in schema_privileges ~}
-- ====================================================================
-- PRIVILEGES FOR ROLE: ${role_name}
-- ====================================================================
%{ for schema_name, privs in schemas ~}

-- ----------- Schema: ${schema_name} -----------

-- 1. Schema-level Privileges
%{ if length(privs.schema_privileges) > 0 ~}
GRANT ${join(", ", privs.schema_privileges)} ON SCHEMA "${schema_name}" TO "${role_name}";
%{ endif ~}

-- 2. Table-level Privileges
%{ if length(privs.table_privileges) > 0 ~}
GRANT ${join(", ", privs.table_privileges)} ON ALL TABLES IN SCHEMA "${schema_name}" TO "${role_name}";
-- ALTER DEFAULT PRIVILEGES IN SCHEMA "${schema_name}" GRANT ${join(", ", privs.table_privileges)} ON TABLES TO "${role_name}";
%{ endif ~}

-- 3. Sequence-level Privileges
%{ if length(privs.sequence_privileges) > 0 ~}
GRANT ${join(", ", privs.sequence_privileges)} ON ALL SEQUENCES IN SCHEMA "${schema_name}" TO "${role_name}";
-- ALTER DEFAULT PRIVILEGES IN SCHEMA "${schema_name}" GRANT ${join(", ", privs.sequence_privileges)} ON SEQUENCES TO "${role_name}";
%{ endif ~}

%{ endfor ~}
%{ endfor ~}
