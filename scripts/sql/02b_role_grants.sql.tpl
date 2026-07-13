%{ for grant in user_role_grants ~}
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${grant.role}') THEN
      CREATE ROLE ${grant.role};
   END IF;
END
$$;

GRANT ${grant.role} TO ${grant.user};
%{ endfor ~}
