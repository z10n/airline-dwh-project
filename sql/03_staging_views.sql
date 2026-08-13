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