{{ config(materialized="table") }}
with
    dim_monthly_ntd_ridership_with_adjustments_upt as (
        select * from {{ ref("int_ntd__monthly_ridership_with_adjustments_upt") }}
    )
select
    uza_name,
    uace_cd,
    _dt,
    ts,
    ntd_id,
    reporter_type,
    agency,
    mode_type_of_service_status,
    mode,
    _3_mode,
    tos,
    legacy_ntd_id,
    period_year,
    period_month,
    upt,
from dim_monthly_ntd_ridership_with_adjustments_upt
