{% macro calc_distance_km(lat1, lon1, lat2, lon2) %}
    -- BigQuery의 지리 공간(GIS) 함수를 활용하여 두 위경도 사이의 직선 거리(km)를 계산합니다.
    -- 입력값 중 하나라도 NULL(예: 첫 결제라서 이전 위치가 없는 경우)이면 NULL을 반환하여 에러를 방지합니다.
    CASE 
        WHEN {{ lat1 }} IS NULL OR {{ lon1 }} IS NULL OR {{ lat2 }} IS NULL OR {{ lon2 }} IS NULL 
        THEN NULL
        ELSE (
            ST_DISTANCE(
                ST_GEOGPOINT(CAST({{ lon1 }} AS FLOAT64), CAST({{ lat1 }} AS FLOAT64)),
                ST_GEOGPOINT(CAST({{ lon2 }} AS FLOAT64), CAST({{ lat2 }} AS FLOAT64))
            ) / 1000.0 -- 미터(m) 단위로 나오므로 1000으로 나누어 킬로미터(km)로 변환
        )
    END
{% endmacro %}