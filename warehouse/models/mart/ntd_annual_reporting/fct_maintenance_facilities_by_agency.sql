WITH staging_maintenance_facilities_by_agency AS (
    SELECT *
    FROM {{ ref('stg_ntd__maintenance_facilities_by_agency') }}
),

fct_maintenance_facilities_by_agency AS (
    SELECT *
    FROM staging_maintenance_facilities_by_agency
)

SELECT * FROM fct_maintenance_facilities_by_agency
