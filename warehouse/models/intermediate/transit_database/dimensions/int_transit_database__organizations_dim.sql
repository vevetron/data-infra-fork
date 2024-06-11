{{ config(materialized='table') }}

WITH dim AS (
    {{ transit_database_make_historical_dimension(
        once_daily_staging_table = 'stg_transit_database__organizations',
        date_col = 'dt',
        record_id_col = 'id',
        array_cols = ['roles', 'alias', 'mobility_services_managed', 'parent_organization',
            'funding_programs', 'gtfs_datasets_produced', 'hq_county_geography']
        ) }}
),

int_transit_database__organizations_dim AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id', '_valid_from']) }} AS key,
        id AS source_record_id,
        name,
        organization_type,
        roles,
        itp_id,
        ntd_agency_info_key,
        hubspot_company_record_id,
        alias,
        details,
        caltrans_district,
        mobility_services_managed,
        parent_organization,
        website,
        reporting_category,
        funding_programs,
        gtfs_datasets_produced,
        gtfs_static_status,
        gtfs_realtime_status,
        assessment_status,
        manual_check__contact_on_website,
        hq_county_geography,
        is_public_entity,
        raw_ntd_id,
        ntd_id_2022,
        public_currently_operating,
        public_currently_operating_fixed_route,
        _is_current,
        _valid_from,
        _valid_to
    FROM dim
)

SELECT * FROM int_transit_database__organizations_dim
