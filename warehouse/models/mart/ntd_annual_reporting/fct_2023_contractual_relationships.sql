WITH staging_contractual_relationships AS (
    SELECT *
    FROM {{ ref('stg_ntd__2023_contractual_relationships') }}
),

fct_2023_contractual_relationships AS (
    SELECT *
    FROM staging_contractual_relationships
)

SELECT * FROM fct_2023_contractual_relationships
