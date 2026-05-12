WITH intermediate_trx AS (
    -- 시공간 거리와 속도가 계산된 중간 모델
    SELECT * FROM {{ ref('int_trx_with_lag') }}
),

user_dim AS (
    -- 유저의 거주 국가(base_country) 정보가 담긴 디멘션 모델
    SELECT * FROM {{ ref('dim_users') }}
),

final_logic AS (
    SELECT
        t.trx_id,
        t.user_id,
        u.base_country AS user_home_country,
        t.merchant_country,
        t.trx_at_utc,
        t.amount,
        t.currency,
        
        -- 중간 단계에서 계산된 핵심 지표들
        t.time_diff_minutes,
        t.distance_km,
        t.speed_kmh,
        
        --  1. 시공간  (Impossible Travel) 탐지 로직
        -- 비행기 최고 속도(1,000km/h)를 초과하는 물리적 이동 발생 시 TRUE
        CASE 
            WHEN t.speed_kmh > 1000 THEN TRUE 
            ELSE FALSE 
        END AS is_impossible_travel,

        --  2. 거주 국가 외 비정상 결제 탐지 로직
        -- 유저의 원래 거주 국가와 결제 국가가 다를 경우 TRUE
        CASE 
            WHEN t.merchant_country != u.base_country THEN TRUE 
            ELSE FALSE 
        END AS is_out_of_home_country,

        -- 3. 종합 사기 의심 플래그
        -- 물리적 이동이 불가능하거나, 타국에서 고액($1000 이상) 결제 시 의심 대상으로 분류
        CASE 
            WHEN t.speed_kmh > 1000 
                 OR (t.merchant_country != u.base_country AND t.amount > 1000)
            THEN TRUE 
            ELSE FALSE 
        END AS is_fraud_suspected

    FROM intermediate_trx t
    LEFT JOIN user_dim u ON t.user_id = u.user_id
)

SELECT * FROM final_logic
ORDER BY trx_at_utc DESC