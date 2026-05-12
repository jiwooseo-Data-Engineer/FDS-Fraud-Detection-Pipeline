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

-- 이 dim_users가 추가되면, 최종적으로 보안팀이 대시보드(BI)에서 데이터를 분석할 때 이런 쿼리가 가능해집니다.

-- "fct_fraud_alerts에서 이상 거래로 탐지된 건들 중에서, dim_users와 조인해 보니 가입한 지 3일 이내(days_since_creation <= 3)인 신규 유저의 비율이 80%네? 신규 가입 방어 로직을 강화해야겠다!"

-- 이처럼 팩트 테이블(사건)과 디멘션 테이블(주체)이 결합될 때 진정한 데이터 마트의 가치가 발휘됩니다