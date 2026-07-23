%{ for grant in user_role_grants ~}
-- ==========================================
-- Grant Roles to Users
-- ==========================================
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${grant.role}') THEN
      CREATE ROLE ${grant.role};
   END IF;
END
$$;

GRANT ${grant.role} TO ${grant.user};
%{ endfor ~}
