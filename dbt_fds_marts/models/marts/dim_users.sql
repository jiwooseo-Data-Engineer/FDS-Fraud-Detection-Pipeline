WITH raw_users AS (
    -- 유저 원천 데이터를 가져옵니다 (Staging을 거쳤다고 가정)
    SELECT * FROM {{ ref('stg_users') }}
)

SELECT
    user_id,
    
    -- 유저의 기본 속성 (Dimension)
    user_grade,            -- 예: VIP, Normal
    base_country,          -- 원래 거주 국가 (이 국가와 결제 국가가 다르면 가중치 부여)
    account_created_at,    -- 계정 생성일
    
    -- 현재 활성화 상태 여부 (Slowly Changing Dimension 관점)
    is_active,
    
    -- 계정 생성 후 경과 일수 (신규 계정일수록 Fraud 위험도 높음)
    DATE_DIFF(CURRENT_DATE(), DATE(account_created_at), DAY) AS days_since_creation

FROM raw_users