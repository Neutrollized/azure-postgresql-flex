%{ for creator_role, schemas in default_schema_privileges ~}
-- ====================================================================
-- DEFAULT PRIVILEGES FOR OBJECTS CREATED BY ROLE: ${creator_role}
-- ====================================================================
%{ for schema_name, privs in schemas ~}
%{ for grantee in privs.grantee_roles ~}

-- Schema: ${schema_name} -> Granting to ${grantee}
%{ if length(privs.table_privileges) > 0 ~}
ALTER DEFAULT PRIVILEGES FOR ROLE "${creator_role}" IN SCHEMA "${schema_name}" 
GRANT ${join(", ", privs.table_privileges)} ON TABLES TO "${grantee}";
%{ endif ~}

%{ if length(privs.sequence_privileges) > 0 ~}
ALTER DEFAULT PRIVILEGES FOR ROLE "${creator_role}" IN SCHEMA "${schema_name}" 
GRANT ${join(", ", privs.sequence_privileges)} ON SEQUENCES TO "${grantee}";
%{ endif ~}

%{ endfor ~}
%{ endfor ~}
%{ endfor ~}
