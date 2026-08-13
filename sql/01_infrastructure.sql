-- =============================================
-- Create databases and schema
-- =============================================
CREATE OR REPLACE DATABASE airline_dwh;

CREATE OR REPLACE SCHEMA airline_dwh.raw;
CREATE OR REPLACE SCHEMA airline_dwh.staging;
CREATE OR REPLACE SCHEMA airline_dwh.marts;
CREATE OR REPLACE SCHEMA airline_dwh.audit;
CREATE OR REPLACE SCHEMA airline_dwh.procedures;
CREATE OR REPLACE SCHEMA airline_dwh.security;

-- =============================================
-- WAREHOUSE FOR ETL
-- =============================================
CREATE OR REPLACE WAREHOUSE wh_airline_etl
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE wh_airline_etl;
USE DATABASE airline_dwh;

-- =============================================
-- FILE FORMAT
-- =============================================
CREATE OR REPLACE FILE FORMAT airline_dwh.raw.csv_airline_format
    TYPE = CSV
    FIELD_DELIMITER = '\t'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL', 'null', 'N/A')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- =============================================
-- INTERNAL NAMED STAGE
-- =============================================
CREATE OR REPLACE STAGE airline_dwh.raw.airline_stage
    FILE_FORMAT = airline_dwh.raw.csv_airline_format;

-- =============================================
-- LAYER 1: RAW
-- =============================================
CREATE OR REPLACE TRANSIENT TABLE airline_dwh.raw.airline_flights (
    passenger_id         VARCHAR,
    first_name           VARCHAR,
    last_name            VARCHAR,
    gender               VARCHAR,
    age                  NUMBER,
    nationality          VARCHAR,
    airport_name         VARCHAR,
    airport_country_code VARCHAR,
    country_name         VARCHAR,
    airport_continent    VARCHAR,
    continents           VARCHAR,
    departure_date       VARCHAR,
    arrival_airport      VARCHAR,
    pilot_name           VARCHAR,
    flight_status        VARCHAR,
    ticket_type          VARCHAR,
    passenger_status     VARCHAR,
    _loaded_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file         VARCHAR
);

-- =============================================
-- LAYER 2: STAGING (Views)
-- =============================================
CREATE OR REPLACE VIEW airline_dwh.staging.stg_passengers AS
SELECT DISTINCT
    passenger_id,
    TRIM(first_name)    AS first_name,
    TRIM(last_name)     AS last_name,
    UPPER(TRIM(gender)) AS gender,
    TRY_CAST(age AS NUMBER) AS age,
    TRIM(nationality)   AS nationality
FROM airline_dwh.raw.airline_flights
WHERE passenger_id IS NOT NULL;

CREATE OR REPLACE VIEW airline_dwh.staging.stg_airports AS
SELECT DISTINCT
    TRIM(arrival_airport)              AS airport_code,
    TRIM(airport_name)                 AS airport_name,
    UPPER(TRIM(airport_country_code))  AS country_code,
    TRIM(country_name)                 AS country_name,
    UPPER(TRIM(airport_continent))     AS continent_code,
    TRIM(continents)                   AS continent_name
FROM airline_dwh.raw.airline_flights
WHERE arrival_airport IS NOT NULL;

CREATE OR REPLACE VIEW airline_dwh.staging.stg_flights AS
SELECT
    passenger_id,
    TRIM(arrival_airport)                     AS arrival_airport_code,
    TRY_TO_DATE(departure_date, 'MM/DD/YYYY') AS departure_date,
    TRIM(pilot_name)                          AS pilot_name,
    TRIM(flight_status)                       AS flight_status,
    TRIM(ticket_type)                         AS ticket_type,
    TRIM(passenger_status)                    AS passenger_status
FROM airline_dwh.raw.airline_flights
WHERE passenger_id IS NOT NULL
  AND TRY_TO_DATE(departure_date, 'MM/DD/YYYY') IS NOT NULL;

-- =============================================
-- LAYER 3: MARTS
-- =============================================
CREATE OR REPLACE TABLE airline_dwh.marts.dim_passengers (
    passenger_key    NUMBER AUTOINCREMENT PRIMARY KEY,
    passenger_id     VARCHAR NOT NULL,
    first_name       VARCHAR,
    last_name        VARCHAR,
    gender           VARCHAR,
    age              NUMBER,
    nationality      VARCHAR,
    _valid_from      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _valid_to        TIMESTAMP_NTZ,
    _is_current      BOOLEAN DEFAULT TRUE
) DATA_RETENTION_TIME_IN_DAYS = 30;

CREATE OR REPLACE TABLE airline_dwh.marts.dim_airports (
    airport_key      NUMBER AUTOINCREMENT PRIMARY KEY,
    airport_code     VARCHAR NOT NULL,
    airport_name     VARCHAR,
    country_code     VARCHAR,
    country_name     VARCHAR,
    continent_code   VARCHAR,
    continent_name   VARCHAR
) DATA_RETENTION_TIME_IN_DAYS = 30;

CREATE OR REPLACE TABLE airline_dwh.marts.fact_flights (
    flight_key       NUMBER AUTOINCREMENT PRIMARY KEY,
    passenger_key    NUMBER NOT NULL,
    airport_key      NUMBER NOT NULL,
    departure_date   DATE NOT NULL,
    pilot_name       VARCHAR,
    flight_status    VARCHAR,
    ticket_type      VARCHAR,
    passenger_status VARCHAR,
    _loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) DATA_RETENTION_TIME_IN_DAYS = 30;

-- =============================================
-- AUDIT LOG
-- =============================================
CREATE OR REPLACE TABLE airline_dwh.audit.etl_log (
    log_id             NUMBER AUTOINCREMENT PRIMARY KEY,
    pipeline_name      VARCHAR NOT NULL,
    layer              VARCHAR NOT NULL,
    table_name         VARCHAR NOT NULL,
    operation          VARCHAR NOT NULL,
    rows_affected      NUMBER NOT NULL,
    status             VARCHAR NOT NULL,
    error_message      VARCHAR,
    started_at         TIMESTAMP_NTZ NOT NULL,
    finished_at        TIMESTAMP_NTZ NOT NULL,
    execution_time_sec NUMBER
);

-- =============================================
-- STREAM FOR CDC
-- =============================================
CREATE OR REPLACE STREAM airline_dwh.raw.stream_airline_flights
ON TABLE airline_dwh.raw.airline_flights;