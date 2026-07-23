%{ for role, cfg in roles ~}
-- ==========================================
-- Create Roles
-- ==========================================
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${role}') THEN
      %{ if try(cfg.password, null) != null ~}
      CREATE ROLE ${role} WITH LOGIN PASSWORD '${cfg.password}';
      %{ else ~}
      CREATE ROLE ${role};
      %{ endif ~}
   ELSE
      %{ if try(cfg.password, null) != null ~}
      ALTER ROLE ${role} WITH LOGIN PASSWORD '${cfg.password}';
      %{ else ~}
      ALTER ROLE ${role} NOLOGIN;
      %{ endif ~}
   END IF;
END
$$;
%{ endfor ~}
