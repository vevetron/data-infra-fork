WITH external_funding_sources_directly_generated AS (
    SELECT *
    FROM {{ source('external_ntd__annual_reporting', 'multi_year__funding_sources_directly_generated') }}
),

get_latest_extract AS(

    SELECT *
    FROM external_funding_sources_directly_generated
    -- we pull the whole table every month in the pipeline, so this gets only the latest extract
    QUALIFY DENSE_RANK() OVER (ORDER BY execution_ts DESC) = 1
),

stg_ntd_annual_data__funding_sources_directly_generated AS (
    SELECT *
    FROM get_latest_extract
)

SELECT * FROM stg_ntd_annual_data__funding_sources_directly_generated
