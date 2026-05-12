-- "모든 결제 금액의 단위를 하나로 통일"
SELECT 
    t.*,
    e.exchange_rate,
    (t.amount * e.exchange_rate) AS amount_krw  -- 원화 환산 금액
FROM {{ ref('stg_card_transactions') }} t
LEFT JOIN {{ ref('stg_exchange_rate') }} e 
    ON t.currency = e.currency_code 
    AND DATE(t.trx_at_utc) = DATE(e.rate_at_utc)

-- 미국에서 결제한 100 달러 (USD)
-- 일본에서 결제한 100 엔 (JPY)

-- 이 둘은 가치가 완전히 다르지만, 환율을 안 곱해주면 컴퓨터는 둘 다 똑같은 '100'이라는 숫자로 인식해버린다. 100엔(약 900원)은 소액 결제고, 100달러(약 13만 원)는 제법 큰 결제인데 
-- LEFT JOIN 로직을 통해 "달러든 엔화든 유로든, 일단 전부 한국 돈(amount_krw)으로 바꿔서 옆에 적어둬"라고 데이터를 정규화(정리)해 준 것입니다.