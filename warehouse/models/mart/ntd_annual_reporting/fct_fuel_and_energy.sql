WITH staging_fuel_and_energy AS (
    SELECT *
    FROM {{ ref('stg_ntd__fuel_and_energy') }}
),

fct_fuel_and_energy AS (
    SELECT *
    FROM staging_fuel_and_energy
)

SELECT * FROM fct_fuel_and_energy
