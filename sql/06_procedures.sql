CREATE OR REPLACE PROCEDURE airline_dwh.raw.sp_load_raw()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_loaded NUMBER;
    start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    end_time TIMESTAMP_NTZ;
    exec_seconds NUMBER;
BEGIN
    -- Truncate raw table
    TRUNCATE TABLE airline_dwh.raw.airline_flights;
    
    -- Load from stage
    COPY INTO airline_dwh.raw.airline_flights
    FROM (
        SELECT $1, $2, $3, $4, $5, TRY_CAST($6 AS NUMBER), $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, CURRENT_TIMESTAMP(), 'Airline Dataset.csv'
        FROM '@airline_dwh.raw.airline_stage/Airline Dataset.csv'
    )
    FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' TRIM_SPACE = TRUE NULL_IF = ('', 'NULL', 'null', 'N/A') ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE)
    FORCE = TRUE
    ON_ERROR = 'CONTINUE';
    
    -- Get row count and end time
    SELECT COUNT(*) INTO :rows_loaded FROM airline_dwh.raw.airline_flights;
    end_time := CURRENT_TIMESTAMP();
    exec_seconds := DATEDIFF('second', start_time, end_time);
    
    -- Log to audit
    INSERT INTO airline_dwh.audit.etl_log (pipeline_name, layer, table_name, operation, rows_affected, status, started_at, finished_at, execution_time_sec)
    VALUES ('sp_load_raw', 'RAW', 'airline_flights', 'COPY_INTO', :rows_loaded, 'SUCCESS', :start_time, :end_time, :exec_seconds);
    
    RETURN 'Loaded ' || :rows_loaded || ' rows into raw.airline_flights';
END;
$$;

CREATE OR REPLACE PROCEDURE airline_dwh.marts.sp_load_marts()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    passengers_loaded NUMBER;
    airports_loaded NUMBER;
    flights_loaded NUMBER;
    start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    end_time TIMESTAMP_NTZ;
    exec_seconds NUMBER;
BEGIN
    -- Truncate marts tables
    TRUNCATE TABLE airline_dwh.marts.dim_passengers;
    TRUNCATE TABLE airline_dwh.marts.dim_airports;
    TRUNCATE TABLE airline_dwh.marts.fact_flights;
    
    -- Load dim_passengers
    INSERT INTO airline_dwh.marts.dim_passengers (passenger_id, first_name, last_name, gender, age, nationality)
    SELECT passenger_id, first_name, last_name, gender, age, nationality
    FROM airline_dwh.staging.stg_passengers;
    
    SELECT COUNT(*) INTO :passengers_loaded FROM airline_dwh.marts.dim_passengers;
    
    -- Load dim_airports
    INSERT INTO airline_dwh.marts.dim_airports (airport_code, airport_name, country_code, country_name, continent_code, continent_name)
    SELECT airport_code, airport_name, country_code, country_name, continent_code, continent_name
    FROM airline_dwh.staging.stg_airports;
    
    SELECT COUNT(*) INTO :airports_loaded FROM airline_dwh.marts.dim_airports;
    
    -- Load fact_flights
    INSERT INTO airline_dwh.marts.fact_flights (passenger_key, airport_key, departure_date, pilot_name, flight_status, ticket_type)
    SELECT
        p.passenger_key,
        a.airport_key,
        f.departure_date,
        f.pilot_name,
        f.flight_status,
        f.ticket_type
    FROM airline_dwh.staging.stg_flights f
    JOIN airline_dwh.marts.dim_passengers p ON f.passenger_id = p.passenger_id
    JOIN airline_dwh.marts.dim_airports a ON f.arrival_airport_code = a.airport_code;
    
    SELECT COUNT(*) INTO :flights_loaded FROM airline_dwh.marts.fact_flights;
    
    -- Calculate execution time
    end_time := CURRENT_TIMESTAMP();
    exec_seconds := DATEDIFF('second', start_time, end_time);
    
    -- Log to audit
    INSERT INTO airline_dwh.audit.etl_log (pipeline_name, layer, table_name, operation, rows_affected, status, started_at, finished_at, execution_time_sec)
    VALUES ('sp_load_marts', 'MARTS', 'dim_passengers', 'INSERT', :passengers_loaded, 'SUCCESS', :start_time, :end_time, :exec_seconds);
    
    INSERT INTO airline_dwh.audit.etl_log (pipeline_name, layer, table_name, operation, rows_affected, status, started_at, finished_at, execution_time_sec)
    VALUES ('sp_load_marts', 'MARTS', 'dim_airports', 'INSERT', :airports_loaded, 'SUCCESS', :start_time, :end_time, :exec_seconds);
    
    INSERT INTO airline_dwh.audit.etl_log (pipeline_name, layer, table_name, operation, rows_affected, status, started_at, finished_at, execution_time_sec)
    VALUES ('sp_load_marts', 'MARTS', 'fact_flights', 'INSERT', :flights_loaded, 'SUCCESS', :start_time, :end_time, :exec_seconds);
    
    RETURN 'Marts loaded: passengers=' || :passengers_loaded || ', airports=' || :airports_loaded || ', flights=' || :flights_loaded;
END;
$$;

CALL airline_dwh.raw.sp_load_raw();

CALL airline_dwh.marts.sp_load_marts();

SELECT * FROM airline_dwh.audit.etl_log ORDER BY started_at;