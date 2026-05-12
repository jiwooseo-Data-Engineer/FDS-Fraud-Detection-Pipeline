WITH raw_exchange_rate AS (
    -- _sources.yml에 exchange_rate 소스가 정의되어 있다고 가정합니다.
    SELECT * FROM {{ source('raw_data', 'raw_exchange_rates') }}
)

SELECT
    -- 통화 코드 (예: 'USD', 'EUR')
    currency_code,
    
    -- 기준 통화 대비 환율 (예: 1350.50)
    CAST(exchange_rate AS FLOAT64) AS exchange_rate,
    
    -- 환율 고시 시간 (결제 시간과 조인하기 위해 TIMESTAMP로 변환)
    CAST(base_date AS TIMESTAMP) AS rate_at_utc,
    
    -- 데이터 수집 시간
    extracted_at
    
FROM raw_exchange_rate

-- 데이터 정규화(Normalization): 해외 결제는 통화가 제각각입니다. 1,000달러와 1,000엔은 가치가 완전히 다릅니다. 이 staging 모델이 있어야 나중에 int_trx_converted.sql에서 모든 금액을 KRW로 환산하여 동일한 이상 거래를 탐지할 수 있습니다.

-- Point-in-time Join 준비: 환율은 매시간 변합니다. rate_at_utc를 타임스탬프로 잘 정제해 두어야, 나중에 결제 시점과 가장 가까운 시점의 환율을 정확하게 Join할 수 있습니다.