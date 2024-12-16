WITH staging_stations_by_mode_and_age AS (
    SELECT *
    FROM {{ ref('stg_ntd__stations_by_mode_and_age') }}
),

fct_stations_by_mode_and_age AS (
    SELECT *
    FROM staging_stations_by_mode_and_age
)

SELECT * FROM fct_stations_by_mode_and_age
