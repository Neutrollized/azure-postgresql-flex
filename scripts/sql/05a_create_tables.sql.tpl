%{ for table_name, config in database_tables ~}
-- ====================================================================
-- DDL, GRANTS & INDEXES FOR TABLE: ${config.schema}.${table_name}
-- ====================================================================

-- 1. Create Table Structure with Inline Column Constraints
CREATE TABLE IF NOT EXISTS "${config.schema}"."${table_name}" (
  %{ for field in config.fields ~}
  "${field.name}" ${field.type}%{ if field.default_value != null } DEFAULT ${field.default_value}%{ endif }%{ if field.null == false } NOT NULL%{ endif }%{ if length(field.inline_constraints) > 0 } ${join(" ", field.inline_constraints)}%{ endif },
  %{ endfor ~}
  CONSTRAINT "${table_name}_pkey" PRIMARY KEY ("${join("\", \"", config.primary_keys)}")%{ if length(config.constraints) > 0 ~},
  ${join(",\n  ", config.constraints)}
  %{ endif ~}

);

-- 2. Execute Explicit Table Grants
%{ if config.grants != null ~}
%{ for role, privileges in config.grants ~}
GRANT ${join(", ", privileges)} ON TABLE "${config.schema}"."${table_name}" TO "${role}";
%{ endfor ~}
%{ endif ~}

-- 3. Automatic Sequence Provisioning
%{ if config.grants != null ~}
%{ for role, privileges in config.grants ~}
%{ if contains(privileges, "INSERT") || contains(privileges, "UPDATE") ~}
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "${config.schema}" TO "${role}";
%{ endif ~}
%{ endfor ~}
%{ endif ~}

-- 4. Create Standalone Indexes
%{ if config.indexes != null ~}
%{ for idx in config.indexes ~}
CREATE ${idx.unique ? "UNIQUE " : ""}INDEX IF NOT EXISTS "${idx.name}" 
ON "${config.schema}"."${table_name}" USING ${idx.type} (${join(", ", idx.columns)});
%{ endfor ~}
%{ endif ~}

%{ endfor ~}
