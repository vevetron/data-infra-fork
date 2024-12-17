WITH external_agency_information AS (
    SELECT *
    FROM {{ source('external_ntd__annual_reporting', '2023__annual_database_agency_information') }}
),

get_latest_extract AS(
    SELECT *
    FROM external_agency_information
    -- we pull the whole table every month in the pipeline, so this gets only the latest extract
    QUALIFY DENSE_RANK() OVER (ORDER BY execution_ts DESC) = 1
),

stg_ntd__2023_agency_information AS (
    SELECT *
    FROM get_latest_extract
)

SELECT
    number_of_state_counties,
    tam_tier,
    personal_vehicles,
    uza_name,
    tribal_area_name,
    service_area_sq_miles,
    voms_do,
    url,
    region,
    state_admin_funds_expended,
    zip_code_ext,
    zip_code,
    ueid,
    address_line_2,
    number_of_counties_with_service,
    reporter_acronym,
    original_due_date,
    sq_miles,
    address_line_1,
    p_o__box,
    division_department,
    fy_end_date,
    service_area_pop,
    state,
    subrecipient_type,
    primary_uza_uace_code,
    reported_by_name,
    population,
    reporting_module,
    volunteer_drivers,
    doing_business_as,
    reporter_type,
    legacy_ntd_id,
    total_voms,
    fta_recipient_id,
    city,
    voms_pt,
    organization_type,
    agency_name,
    ntd_id,
    reported_by_ntd_id,
    density,
    state_parent_ntd_id,
    dt,
    execution_ts
FROM stg_ntd__2023_agency_information
