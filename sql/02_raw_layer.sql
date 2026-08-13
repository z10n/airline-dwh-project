USE ROLE ACCOUNTADMIN;
USE WAREHOUSE wh_airline_etl;
USE DATABASE airline_dwh;
USE SCHEMA raw;

CREATE OR REPLACE FILE FORMAT airline_dwh.raw.csv_airline_format
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL', 'null', 'N/A')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

CREATE OR REPLACE STAGE airline_dwh.raw.airline_stage
    FILE_FORMAT = airline_dwh.raw.csv_airline_format;

CREATE OR REPLACE TRANSIENT TABLE airline_dwh.raw.airline_flights (
    row_number           VARCHAR,
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
    _loaded_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file         VARCHAR
);