WITH raw_users AS (
    -- _sources.yml에 raw_users 소스가 정의되어 있어야 합니다.
    SELECT * FROM {{ source('raw_data', 'raw_users') }}
)

SELECT
    -- 식별자
    user_id,
    
    -- 개인 정보 (암호화가 필요한 경우 여기서 마스킹 처리를 하기도 합니다)
    user_name,
    email,
    
    -- FDS의 핵심 기준점: 유저의 거주 국가
    base_country,
    
    -- 상태 및 시간 정보
    CAST(created_at AS TIMESTAMP) AS created_at_utc,
    is_active,
    
    -- 데이터 적재 시간
    _loaded_at AS extracted_at

FROM raw_users