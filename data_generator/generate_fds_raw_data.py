import pandas as pd
from faker import Faker
import random
from datetime import timedelta

# 한국어와 글로벌(영어) Faker 객체 두 개를 생성
fake_ko = Faker('ko_KR')
fake_en = Faker('en_US')

def generate_realistic_fds_data(num_records=2000, num_users=100):
    """
    FDS 분석에 최적화된 고도화된 가상 카드 결제 로그 생성 함수
    """
    transactions = []
    
    # 1. 유저 풀(Pool) 생성: 유저별로 고유한 카드 번호를 맵핑해 둠
    users = {}
    for _ in range(num_users):
        user_id = fake_en.uuid4()
        users[user_id] = {
            'card_number': fake_en.credit_card_number(card_type='visa16'),
            'card_expire': fake_en.credit_card_expire(),
            # 유저별로 주로 사용하는 기기(User Agent) 고정
            'main_device': fake_en.user_agent()
        }
    
    user_id_list = list(users.keys())

    # 2. 결제 로그 생성 루프
    for i in range(num_records):
        user_id = random.choice(user_id_list)
        user_info = users[user_id]
        
        # 기본 결제 시간 생성 (최근 30일 이내)
        trx_at = fake_en.date_time_between(start_date='-30d', end_date='now')
        
        # 80%는 정상적인 국내 결제, 20%는 해외 결제로 비중(가중치) 설정
        is_domestic = random.random() < 0.8
        
        if is_domestic:
            currency = 'KRW'
            amount = round(random.uniform(5000, 1500000), 0) # 5천원 ~ 150만원
            merchant_country = 'KR'
            lat, lon = fake_ko.local_latlng(country_code='KR')[:2] # 한국 내 위경도
            ip_address = fake_ko.ipv4()
        else:
            # 해외 결제 케이스 (USD, EUR 등)
            currency = random.choice(['USD', 'EUR', 'GBP', 'JPY'])
            amount = round(random.uniform(10.0, 3000.0), 2) # 10달러 ~ 3000달러
            merchant_country = fake_en.country_code()
            lat, lon = fake_en.latitude(), fake_en.longitude()
            ip_address = fake_en.ipv4()

        # 도용(Fraud) 케이스: 가끔 유저의 원래 기기가 아닌 처음 보는 기기(User Agent)에서 결제 발생
        is_new_device = random.random() < 0.05 # 5% 확률로 기기 변경
        user_agent = fake_en.user_agent() if is_new_device else user_info['main_device']

        transactions.append({
            'trx_id': fake_en.uuid4(),
            'user_id': user_id,
            'card_number': user_info['card_number'],
            'card_expire_dt': user_info['card_expire'],
            'trx_at': trx_at.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': amount,
            'currency': currency,
            'merchant_country': merchant_country,
            'merchant_lat': float(lat),
            'merchant_lon': float(lon),
            'ip_address': ip_address,
            'user_agent': user_agent
        })
        
    # DataFrame 변환 및 시간순 정렬
    df = pd.DataFrame(transactions)
    df = df.sort_values(by='trx_at').reset_index(drop=True)
    
    # '시공간 물리적 모순(Impossible Travel)' 강제 주입
    #  "사기 거래" 시나리오를 고의로 5세트 만듬

    fraud_indices = random.sample(range(len(df) - 1), 5)
    for idx in fraud_indices:
        fraud_user = df.at[idx, 'user_id']
        original_time = pd.to_datetime(df.at[idx, 'trx_at'])
        
        # 직전 결제 후 불과 '30분 뒤'에 결제
        fraud_time = original_time + timedelta(minutes=30)
        
        # '미국'에서 고액의 결제가 발생하는 상황을 강제로 바로 다음 행에 덮어씌움
        df.at[idx + 1, 'user_id'] = fraud_user
        df.at[idx + 1, 'trx_at'] = fraud_time.strftime('%Y-%m-%d %H:%M:%S')
        df.at[idx + 1, 'merchant_country'] = 'US'
        df.at[idx + 1, 'currency'] = 'USD'
        df.at[idx + 1, 'amount'] = 4999.99  # 약 650만원
        df.at[idx + 1, 'merchant_lat'] = 40.7128 # 뉴욕 위도
        df.at[idx + 1, 'merchant_lon'] = -74.0060 # 뉴욕 경도
        df.at[idx + 1, 'user_agent'] = fake_en.user_agent() # 해커의 낯선 기기

    # 다시 시간순 정렬
    df = df.sort_values(by='trx_at').reset_index(drop=True)
    return df

if __name__ == "__main__":
    df = generate_realistic_fds_data(num_records=5000, num_users=100)
    df.to_csv("advanced_fds_raw_data.csv", index=False)
    print(" FDS 고도화 데이터 5,000건 생성 완료!")