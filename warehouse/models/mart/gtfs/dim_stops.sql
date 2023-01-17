{{ config(materialized='table') }}

WITH dim_schedule_feeds AS (
    SELECT *
    FROM {{ ref('dim_schedule_feeds') }}
),

int_gtfs_schedule__incremental_stops AS (
    SELECT *
    FROM {{ ref('int_gtfs_schedule__incremental_stops') }}
),

make_dim AS (
{{ make_schedule_file_dimension_from_dim_schedule_feeds('dim_schedule_feeds', 'int_gtfs_schedule__incremental_stops') }}
),

bad_rows AS (
    SELECT
        base64_url,
        ts,
        stop_id,
        TRUE AS warning_duplicate_primary_key
    FROM make_dim
    GROUP BY base64_url, ts, stop_id
    HAVING COUNT(*) > 1
),

dim_stops AS (
    SELECT
        {{ dbt_utils.surrogate_key(['feed_key', 'stop_id']) }} AS key,
        base64_url,
        feed_key,
        stop_id,
        tts_stop_name,
        stop_lat,
        stop_lon,
        ST_GEOGPOINT(
            stop_lon,
            stop_lat
        ) AS pt_geom,
        zone_id,
        parent_station,
        stop_code,
        stop_name,
        stop_desc,
        stop_url,
        location_type,
        stop_timezone,
        wheelchair_boarding,
        level_id,
        platform_code,
        COALESCE(warning_duplicate_primary_key, FALSE) AS warning_duplicate_primary_key,
        _valid_from,
        _valid_to
    FROM make_dim
    LEFT JOIN bad_rows
        USING (base64_url, ts, stop_id)
)

SELECT * FROM dim_stops
