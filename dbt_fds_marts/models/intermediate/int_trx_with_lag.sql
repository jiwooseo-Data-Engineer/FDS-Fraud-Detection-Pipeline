WITH lagged_data AS (
    SELECT
        *,
        -- 현재 유저의 '직전 결제 시간'을 가져옴
        LAG(trx_at_utc) OVER (
            PARTITION BY user_id 
            ORDER BY trx_at_utc
        ) AS prev_trx_at,
        
        -- 현재 유저의 '직전 결제 국가'를 가져옴
        LAG(merchant_country) OVER (
            PARTITION BY user_id 
            ORDER BY trx_at_utc
        ) AS prev_country,
        
        LAG(merchant_lat) OVER (PARTITION BY user_id ORDER BY trx_at_utc) AS prev_lat,
        LAG(merchant_lon) OVER (PARTITION BY user_id ORDER BY trx_at_utc) AS prev_lon

    FROM {{ ref('stg_card_transactions') }}
),

time_diff_calculated AS (
    SELECT
        *,
        -- 직전 결제와 현재 결제 사이의 시간 차이를 '분(Minute)' 단위로 계산
        TIMESTAMP_DIFF(trx_at_utc, prev_trx_at, MINUTE) AS time_diff_minutes
    FROM lagged_data
)

SELECT * FROM time_diff_calculated

-- 데이터의 섞임 방지 (PARTITION BY)
-- 단순히 시간순으로만 정렬하면 A 유저의 결제 직전에 B 유저의 결제가 끼어들 수 있습니다. 하지만 PARTITION BY user_id를 명시함으로써, 데이터베이스가 유저별로 방을 따로 만들어서 오직 '해당 유저의 직전 결제'만 정확하게 매칭했습니다.

--비싼 연산의 최소화 (윈도우 함수 사용)
-- Python의 for문으로 수백만 건을 돌면서 이전 결제 기록을 찾으면 엄청난 시간과 비용이 듭니다. 하지만 SQL의 LAG() 윈도우 함수를 사용함으로써, 데이터 웨어하우스(BigQuery 등)의 병렬 처리 엔진을 100% 활용해 한 번의 스캔으로 연산을 끝냄.

--명확한 역할 분담 (모듈화)
-- TIMESTAMP_DIFF를 사용해 '분(Minute)' 단위로 시간차를 계산하는 로직을 이 Intermediate 계층에서 미리 처리했습니다. 다음 단계인 최종 마트(fct_fraud_alerts.sql)에서는 복잡한 계산 없이 time_diff_minutes < 60 처럼 아주 직관적인 조건문만 쓸 수 있게 되었습니다.


time_diff_calculated AS (
    SELECT
        *,
        -- 1. 시간차 계산 (분)
        TIMESTAMP_DIFF(trx_at_utc, prev_trx_at, MINUTE) AS time_diff_minutes,
        
        -- 2. Macro를 호출하여 물리적 거리(km) 계산
        {{ calc_distance_km('merchant_lat', 'merchant_lon', 'prev_lat', 'prev_lon') }} AS distance_km
        
    FROM lagged_data
),

speed_calculated AS (
    SELECT
        *,
        -- 3. 이동 속도 계산 (거리 / 시간)
        -- 분(minute)을 60으로 나누어 시간(hour) 단위로 바꾸고 거리를 나눔. 
        -- 0으로 나누는 에러(Divide by zero)를 막기 위해 NULLIF 사용!
        distance_km / NULLIF((time_diff_minutes / 60.0), 0) AS speed_kmh
        
    FROM time_diff_calculated
)

SELECT * FROM speed_calculated