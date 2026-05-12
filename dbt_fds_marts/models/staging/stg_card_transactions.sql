WITH raw_data AS (
    SELECT * FROM {{ source('raw_data', 'raw_card_transactions') }}
)

SELECT
    -- 식별자 (Identifiers)
    trx_id,
    user_id,
    card_number,
    
    -- 시간 데이터 (Timestamp로 명시적 캐스팅)
    CAST(trx_at AS TIMESTAMP) AS trx_at_utc,
    
    -- 결제 정보
    CAST(amount AS FLOAT64) AS amount,
    currency,
    
    -- 가맹점/위치 정보
    merchant_country,
    CAST(merchant_lat AS FLOAT64) AS merchant_lat,
    CAST(merchant_lon AS FLOAT64) AS merchant_lon,
    
    -- 기기/네트워크 정보
    ip_address,
    user_agent
    
FROM raw_data