WITH source AS (
    SELECT * FROM {{ source('external_littlepay', 'micropayment_adjustments') }}
),

clean_columns AS (
    SELECT
        {{ trim_make_empty_string_null('micropayment_id') }} AS micropayment_id,
        {{ trim_make_empty_string_null('adjustment_id') }} AS adjustment_id,
        {{ trim_make_empty_string_null('participant_id') }} AS participant_id,
        {{ trim_make_empty_string_null('customer_id') }} AS customer_id,
        {{ trim_make_empty_string_null('product_id') }} AS product_id,
        {{ trim_make_empty_string_null('type') }} AS type,
        {{ trim_make_empty_string_null('description') }} AS description,
        CAST({{ trim_make_empty_string_null('amount') }} AS NUMERIC) AS amount,
        {{ trim_make_empty_string_null('time_period_type') }} AS time_period_type,
        {{ safe_cast('applied', type_boolean()) }} AS applied,
        {{ trim_make_empty_string_null('zone_ids_used') }} AS zone_ids_used,
        {{ trim_make_empty_string_null('incentive_product_id') }} AS incentive_product_id,
        CAST(_line_number AS INTEGER) AS _line_number,
        `instance`,
        extract_filename,
        ts,
        {{ extract_littlepay_filename_ts() }} AS littlepay_export_ts,
        {{ extract_littlepay_filename_date() }} AS littlepay_export_date,
        -- hash all content not generated by us to enable deduping full dup rows
        -- hashing at this step will preserve distinction between nulls and empty strings in case that is meaningful upstream
        {{ dbt_utils.generate_surrogate_key(['micropayment_id', 'adjustment_id', 'participant_id',
            'customer_id', 'product_id', 'type', 'description', 'amount', 'time_period_type',
            'applied', 'zone_ids_used', 'incentive_product_id']) }} AS _content_hash,
    FROM source
),

add_keys_drop_full_dupes AS (
    SELECT
        *,
        -- generate keys now that input columns have been trimmed & cast and files deduped
        {{ dbt_utils.generate_surrogate_key(['littlepay_export_ts', '_line_number', 'instance']) }} AS _key,
        {{ dbt_utils.generate_surrogate_key(['micropayment_id', 'adjustment_id']) }} AS _payments_key,
    FROM clean_columns
    {{ qualify_dedupe_full_duplicate_lp_rows() }}
),

drop_additional_dupes AS (
    SELECT
        *
    FROM add_keys_drop_full_dupes
    -- drops four true duplicates from two micropayments that generated multiple IDs seemingly
    -- unintentionally (those micropayments are themselves dropped in the micropayments model)
    WHERE _key not in ('3d78961ec137c0a16e7e3b888d81c024', '748f95a050d6f45598d1571381b17fad', 'af41f1341756c8feea02d4b8aa9de973', '61fccf1b84e7e3f0afddaae426f29f36')
),

stg_littlepay__micropayment_adjustments AS (
    SELECT
        micropayment_id,
        adjustment_id,
        participant_id,
        customer_id,
        product_id,
        type,
        description,
        amount,
        time_period_type,
        applied,
        zone_ids_used,
        incentive_product_id,
        _line_number,
        `instance`,
        extract_filename,
        ts,
        littlepay_export_ts,
        littlepay_export_date,
        _key,
        _payments_key,
        _content_hash,
    FROM drop_additional_dupes
)

SELECT * FROM stg_littlepay__micropayment_adjustments
