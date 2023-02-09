{{ config(materialized='table') }}

WITH full_join AS (
    SELECT *
    FROM {{ ref('int_gtfs_quality__naive_organization_service_dataset_full_join') }}
),

initial_assessed AS (
    SELECT
        {{ dbt_utils.surrogate_key([
            'organization_key',
            'service_key',
            'gtfs_service_data_key',
            'gtfs_dataset_key',
            'schedule_feed_key']) }} AS key,
        date,
        organization_name,
        service_name,
        gtfs_dataset_name,
        gtfs_dataset_type,

        organization_source_record_id,
        service_source_record_id,
        gtfs_service_data_source_record_id,
        gtfs_dataset_source_record_id,

        (organization_assessed
            AND service_assessed
            AND gtfs_service_data_assessed) AS assessed,

        organization_assessed,

        organization_itp_id,
        organization_hubspot_company_record_id,
        organization_ntd_id,
        service_assessed,
        gtfs_service_data_assessed,
        gtfs_service_data_customer_facing,
        regional_feed_type,
        backdated_regional_feed_type,

        agency_id,
        route_id,
        network_id,

        base64_url,

        organization_key,
        service_key,
        gtfs_service_data_key,
        gtfs_dataset_key,
        schedule_feed_key,
        schedule_to_use_for_rt_validation_gtfs_dataset_key
    FROM full_join
),

-- checking for regional feed types to determine reports site assessment status
check_regional_feed_types AS (
    SELECT
        date,
        organization_key,
        service_key,
        -- use subfeed only if this org/service pair:
        --  has both feed types
        --  one of those feed types is assessed for the pair
        ('Regional Subfeed' IN UNNEST(ARRAY_AGG(backdated_regional_feed_type))
            AND 'Combined Regional Feed' IN UNNEST(ARRAY_AGG(backdated_regional_feed_type)))
        AND LOGICAL_OR(assessed) AS use_subfeed_for_reports
    FROM initial_assessed
    WHERE backdated_regional_feed_type IN ('Regional Subfeed', 'Combined Regional Feed')
    GROUP BY date, organization_key, service_key
),

-- checking for schedule feed presence for reports site assessment status
-- note that this determination does not handle checking for the MTC 511 regional feed
check_for_schedule_feed AS (
    SELECT
        date,
        organization_key,
        service_key,
        LOGICAL_OR(gtfs_dataset_key IS NOT NULL) AS has_guidelines_assessed_schedule_feed
    FROM initial_assessed
    WHERE gtfs_dataset_type = "schedule"
        AND assessed
    GROUP BY date, organization_key, service_key
),

int_gtfs_quality__daily_assessment_candidate_entities AS (
    SELECT
        key,
        date,
        organization_name,
        service_name,
        gtfs_dataset_name,
        gtfs_dataset_type,

        organization_source_record_id,
        service_source_record_id,
        gtfs_service_data_source_record_id,
        gtfs_dataset_source_record_id,

        assessed AS guidelines_assessed,
        CASE
            -- can only generate reports if ITP ID is present
            WHEN organization_itp_id IS NULL THEN FALSE
            -- suppress combined feed reports if a subfeed is present
            WHEN (check_regional_feed_types.use_subfeed_for_reports
                AND backdated_regional_feed_type = 'Combined Regional Feed') THEN FALSE
            -- mark subfeed for assessment
            WHEN (check_regional_feed_types.use_subfeed_for_reports
                AND backdated_regional_feed_type = 'Regional Subfeed'
                AND has_guidelines_assessed_schedule_feed) THEN TRUE
            -- finally, confirm we have at least one schedule feed and that the overall entity is assessed
            -- and we suppress the MTC regional combined feed from being used in reporting
            ELSE has_guidelines_assessed_schedule_feed AND assessed AND gtfs_dataset_source_record_id != 'rec9AyXUSMUHFnLsH'
        END AS reports_site_assessed,
        organization_assessed,
        service_assessed,
        gtfs_service_data_assessed,
        organization_itp_id,
        organization_hubspot_company_record_id,
        organization_ntd_id,
        gtfs_service_data_customer_facing,
        regional_feed_type,
        backdated_regional_feed_type,
        COALESCE(check_regional_feed_types.use_subfeed_for_reports, FALSE) AS use_subfeed_for_reports,
        agency_id,
        route_id,
        network_id,
        base64_url,
        organization_key,
        service_key,
        gtfs_service_data_key,
        gtfs_dataset_key,
        schedule_feed_key,
        schedule_to_use_for_rt_validation_gtfs_dataset_key
    FROM initial_assessed
    LEFT JOIN check_regional_feed_types
        USING (date, organization_key, service_key)
    LEFT JOIN check_for_schedule_feed
        USING (date, organization_key, service_key)
)

SELECT * FROM int_gtfs_quality__daily_assessment_candidate_entities
