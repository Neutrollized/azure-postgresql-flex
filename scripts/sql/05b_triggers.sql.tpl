-- ====================================================================
-- 1. TRIGGER FUNCTIONS (Instantiated exactly once per unique Schema)
-- ====================================================================
%{ for schema in unique_trigger_schemas ~}
CREATE OR REPLACE FUNCTION "${schema}".update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;
%{ endfor ~}

-- ====================================================================
-- 2. AUTOMATED TIMESTAMP TRIGGER ASSIGNMENTS
-- ====================================================================
%{ for key, cfg in triggers ~}
-- Trigger for: ${cfg.schema}.${cfg.table}
DROP TRIGGER IF EXISTS "update_${cfg.table}_updated_at" ON "${cfg.schema}"."${cfg.table}";

CREATE TRIGGER "update_${cfg.table}_updated_at"
   BEFORE UPDATE ON "${cfg.schema}"."${cfg.table}"
   FOR EACH ROW
   EXECUTE FUNCTION "${cfg.schema}".update_updated_at_column();

%{ endfor ~}
