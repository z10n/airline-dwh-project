CREATE OR REPLACE STREAM airline_dwh.raw.stream_airline_flights
ON TABLE airline_dwh.raw.airline_flights;

SHOW STAGES IN SCHEMA airline_dwh.raw;