{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={
            'field': 'date',
            'data_type': 'date',
            'granularity': 'day',
        },
        partitions=['current_date()'],
        cluster_by='job_type',
    )
}}
-- we should use https://cloud.google.com/bigquery/docs/reference/standard-sql/json_functions#parse_json when available

-- Note these two source CTEs a direct reference instead of source, because a new table is created daily
WITH latest AS (
    {% set today = modules.datetime.date.today() %}

    SELECT *
    FROM cal-itp-data-infra.audit.cloudaudit_googleapis_com_data_access_{{ today.strftime('%Y%m%d') }}
),

everything AS (
    {% set start_date = modules.datetime.date(year=2022, month=4, day=11) %}
    {% set days = (modules.datetime.date.today() - start_date).days + 1 %}

    {% for add in range(days) %}

    {% set current = start_date + modules.datetime.timedelta(days=add) %}

    SELECT *
    FROM cal-itp-data-infra.audit.cloudaudit_googleapis_com_data_access_{{ current.strftime('%Y%m%d') }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}

    {% endfor %}
),

data_to_process AS (
    SELECT
        *,
        EXTRACT(DATE FROM timestamp) AS date,
        -- do some initial renaming/unnesting here since we can't refer to same-SELECT aliases
        protopayload_auditlog AS payload,
        protopayload_auditlog.metadataJson AS metadata,

        JSON_QUERY(protopayload_auditlog.metadataJson, '$.jobChange.job') AS job

    {% if is_incremental() %}
    FROM latest
    {% else %}
    FROM everything
    {% endif %}
),

stg_audit__cloudaudit_googleapis_com_data_access AS (
    SELECT
        timestamp,
        date,
        payload.resourceName as resource_name,

        JSON_VALUE(metadata, '$.jobChange.job.jobName') as job_name,
        JSON_VALUE(job, '$.jobConfig.type') as job_type,
        JSON_VALUE(job, '$.jobConfig.labels.dbt_invocation_id') AS dbt_invocation_id,
        TIMESTAMP_DIFF(
            CAST(JSON_VALUE(job, '$.jobStats.endTime') AS timestamp),
            CAST(JSON_VALUE(job, '$.jobStats.createTime') AS timestamp),
            SECOND
        ) AS duration_in_seconds,
        JSON_VALUE_ARRAY(job, '$.jobStats.queryStats.referencedTables') as referenced_tables,
        5.0 * CAST(JSON_VALUE(job, '$.jobStats.queryStats.totalBilledBytes') AS INT64) / POWER(2, 40) AS estimated_cost_usd, -- $5/TB
        CAST(JSON_VALUE(job, '$.jobStats.totalSlotMs') AS INT64) / 1000 AS total_slots_seconds,

        JSON_VALUE(metadata, '$.tableDataRead.jobName') as table_data_read_job_name,

        payload,
        metadata,
        job
    FROM data_to_process

    WHERE job IS NOT NULL
)

SELECT * FROM stg_audit__cloudaudit_googleapis_com_data_access
