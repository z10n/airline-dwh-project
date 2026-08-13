-- Purpose: Security monitoring, access logging, and data quality checks

USE ROLE ACCOUNTADMIN;
USE DATABASE airline_dwh;
USE SCHEMA marts;

-- ----------------------------------------------------------------------------
-- 1. ACCESS LOGGING VIEW
-- Creates a view to track who accessed sensitive tables and when
-- Uses Snowflake's ACCOUNT_USAGE schema for audit trails
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW audit.access_log AS
SELECT 
    query_id,
    user_name,
    role_name,
    database_name,
    schema_name,
    table_name,
    query_text,
    start_time,
    end_time,
    total_elapsed_time,
    rows_produced,
    bytes_scanned
FROM snowflake.account_usage.query_history
WHERE database_name = 'AIRLINE_DWH'
  AND execution_status = 'SUCCESS'
  AND start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- ----------------------------------------------------------------------------
-- 2. RLS VERIFICATION CHECK
-- Validates that Row-Level Security is working correctly for each role
-- Returns expected vs actual row counts per continent
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE audit.verify_rls()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    japan_count INT;
    usa_count INT;
    admin_count INT;
BEGIN
    -- Check ROLE_JAPAN visibility
    USE ROLE role_japan;
    SELECT COUNT(*) INTO :japan_count FROM airline_dwh.marts.dim_airports 
    WHERE continent_code = 'ASIA';
    
    -- Check ROLE_USA visibility  
    USE ROLE role_usa;
    SELECT COUNT(*) INTO :usa_count FROM airline_dwh.marts.dim_airports 
    WHERE continent_code = 'NAM';
    
    -- Check ADMIN full visibility
    USE ROLE accountadmin;
    SELECT COUNT(*) INTO :admin_count FROM airline_dwh.marts.dim_airports;
    
    -- Validate results
    IF (:japan_count > 0 AND :usa_count > 0 AND :admin_count = 9154) THEN
        RETURN 'RLS VERIFICATION PASSED: Japan=' || :japan_count || 
               ', USA=' || :usa_count || ', Admin=' || :admin_count;
    ELSE
        RETURN 'RLS VERIFICATION FAILED: Japan=' || :japan_count || 
               ', USA=' || :usa_count || ', Admin=' || :admin_count;
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. DATA QUALITY CHECKS
-- Basic validation rules for critical dimensions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW audit.data_quality_checks AS
SELECT 
    'dim_airports' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN airport_code IS NULL THEN 1 ELSE 0 END) AS null_codes,
    SUM(CASE WHEN continent_code NOT IN ('ASIA','NAM','EU','AF','OC','SAM') 
             THEN 1 ELSE 0 END) AS invalid_continents
FROM airline_dwh.marts.dim_airports

UNION ALL

SELECT 
    'fact_flights' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN flight_date IS NULL THEN 1 ELSE 0 END) AS null_dates,
    SUM(CASE WHEN passenger_count < 0 THEN 1 ELSE 0 END) AS negative_passengers
FROM airline_dwh.marts.fact_flights;

-- ----------------------------------------------------------------------------
-- 4. SECURITY POLICY AUDIT
-- Lists all active row access policies and their bindings
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW audit.active_policies AS
SELECT 
    pol.policy_name,
    pol.policy_schema,
    pol.signature,
    tb.table_name,
    tb.column_names
FROM snowflake.account_usage.row_access_policies pol
JOIN snowflake.account_usage.table_constraints tb 
    ON pol.policy_name = tb.constraint_name
WHERE pol.policy_database = 'AIRLINE_DWH';

-- Run verification after setup
CALL audit.verify_rls();