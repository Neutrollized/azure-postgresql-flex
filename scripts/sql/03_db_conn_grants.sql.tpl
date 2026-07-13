%{ for db, grants in db_conn_grants ~}
-- ==========================================
-- Hardening & Connection Grants for: ${db}
-- ==========================================
-- 1. Revoke default public permissions (Happens exactly once per DB)
REVOKE CONNECT, TEMPORARY ON DATABASE "${db}" FROM PUBLIC;

-- 2. Grant CONNECT privileges if roles are specified
%{ if length(grants.connect_roles) > 0 ~}
GRANT CONNECT ON DATABASE "${db}" TO ${join(", ", grants.connect_roles)};
%{ endif ~}

-- 3. Grant TEMPORARY privileges if roles are specified
%{ if length(grants.temporary_roles) > 0 ~}
GRANT TEMPORARY ON DATABASE "${db}" TO ${join(", ", grants.temporary_roles)};
%{ endif ~}

%{ endfor ~}
