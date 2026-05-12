from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta


# DAG 기본설정 (재시도,소유자)
# 데이터 파이프라인은 외부 API 통신이나 DB 연결 등 일시적인 네트워크 장애(Transient Error)에 매우 취약하다. 
# 이를 방어하기 위해 Airflow의 retries와 retry_delay를 설정하여 파이프라인의 내결함성(Fault Tolerance)을 높힘. 
# 특히 실패 시 처음부터 다시 도는 것이 아니라, 실패한 해당 Task부터 재시작하므로 불필요한 컴퓨팅 비용과 시간을 절약할 수 있다.

default_args = {
    'owner': 'data_engineer_jiwoo',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2, #Task 실패시 2번 재시도
    'retry_delay': timedelta(minutes=5), #재시도 간격 5분 
    }

#DAG 정의 (매일 자정에 실행)
with DAG(
    'fds_daily_fraud_detection_pipeline',
    default_args=default_args,
    description='해외 결제 데이터 수집 및 FDS 이상 거래 탐지 dbt 파이프라인',
    schedule_interval='0 0 * * *', # 매일 자정(UTC 기준) 실행
    start_date=datetime(2024, 1, 1),
    catchup=False, # 과거의 밀린 작업은 실행하지 않음
    tags=['FDS', 'dbt', 'Data_Mart'],
) as dag:
    # Task 1: 가상 결제 데이터 생성 스크립트 실행 (수집 단계)
    # 실제 실무라면 여기에 API 호출이나 DB 추출 로직이 들어갑니다.
    extract_raw_data = BashOperator(
        task_id='extract_transactions_data',
        bash_command='python /opt/airflow/data_generator/generate_fds_raw_data.py ',
    )

    # Task 2: dbt 실행 (Staging -> Intermediate -> Marts 변환)
    # dbt run 명령어를 통해 SQL 파일들을 실행하여 웨어하우스에 테이블을 만든다
    run_dbt_models = BashOperator(
        task_id='run_dbt_transformations',
        bash_command='cd /opt/airflow/dbt_fds_marts && dbt run',
    )

    # Task 3: dbt 데이터 품질 테스트
    # NULL 값이 있는지, 비즈니스 룰을 위반한 데이터가 있는지 검사
    test_dbt_models = BashOperator(
        task_id='test_dbt_data_quality',
        bash_command='cd /opt/airflow/dbt_fds_marts && dbt test',
    )

    # 3. 파이프라인 실행 순서 (의존성) 설정
    # 데이터 수집 -> dbt 변환 -> dbt 테스트 순으로 실행
    extract_raw_data >> run_dbt_models >> test_dbt_models