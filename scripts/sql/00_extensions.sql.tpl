%{ for ext in allowed_extensions ~}
-- ==========================================
-- Installing PostgreSQL Extensions
-- ==========================================
CREATE EXTENSION IF NOT EXISTS "${ext}" CASCADE;
%{ endfor ~}
