INSERT INTO airline_dwh.marts.dim_passengers (passenger_id, first_name, last_name, gender, age, nationality)
SELECT passenger_id, first_name, last_name, gender, age, nationality
FROM airline_dwh.staging.stg_passengers;

INSERT INTO airline_dwh.marts.dim_airports (airport_code, airport_name, country_code, country_name, continent_code, continent_name)
SELECT airport_code, airport_name, country_code, country_name, continent_code, continent_name
FROM airline_dwh.staging.stg_airports;

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

SELECT 'dim_passengers' AS table_name, COUNT(*) AS row_count FROM airline_dwh.marts.dim_passengers
UNION ALL
SELECT 'dim_airports', COUNT(*) FROM airline_dwh.marts.dim_airports
UNION ALL
SELECT 'fact_flights', COUNT(*) FROM airline_dwh.marts.fact_flights
UNION ALL
SELECT 'raw_airline_flights', COUNT(*) FROM airline_dwh.raw.airline_flights;

SELECT
    a.airport_name,
    a.country_name,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN f.flight_status = 'On Time' THEN 1 ELSE 0 END) AS on_time,
    SUM(CASE WHEN f.flight_status = 'Delayed' THEN 1 ELSE 0 END) AS delayed,
    ROUND(SUM(CASE WHEN f.flight_status = 'On Time' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS on_time_pct
FROM airline_dwh.marts.fact_flights f
JOIN airline_dwh.marts.dim_airports a ON f.airport_key = a.airport_key
GROUP BY a.airport_name, a.country_name
ORDER BY total_flights DESC
LIMIT 10;