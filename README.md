FDS (Fraud Detection System) Data Pipeline
시공간 모순(Impossible Travel) 및 비즈니스 로직 기반의 해외 결제 이상 거래 탐지 파이프라인

<br>

## Project Overview
본 프로젝트는 글로벌 카드 결제 서비스에서 발생할 수 있는 이상 거래(Fraud)를 사전에 탐지하고 분석하기 위한 End-to-End 데이터 파이프라인입니다. 단순히 데이터를 적재하는 것에 그치지 않고, 물리적 이동 한계를 초과하는 결제 패턴을 정밀하게 타격하는 비즈니스 로직을 구현했습니다.

데이터 엔지니어링의 핵심인 멱등성(Idempotency), 내결함성(Fault Tolerance), 그리고 데이터 무결성(Data Integrity)을 확보하는 데 초점을 맞추어 설계되었습니다.

* **기여도:** 100% (개인 프로젝트)
* **주요 스택:** Python, Apache Airflow, dbt(data build tool), SQL
* **목적:** 보안/리스크팀이 즉각적으로 활용 가능한 고품질의 FDS 데이터 마트 제공

<br>

## Architecture & Data Flow
![Architecture Diagram](architecture_diagram.png) 


1. **Data Generation:** `Python Faker`를 활용해 일일 5,000건의 비즈니스 룰(국내 80/해외 20)이 반영된 가상 결제 로그 데이터 생성
2. **Orchestration:** `Apache Airflow`를 이용해 일일 배치(Daily Batch) 파이프라인 구축 및 내결함성(Fault Tolerance) 확보
3. **Transformation:** `dbt`를 도입하여 Staging - Intermediate - Marts 3계층으로 데이터 모델링 및 품질 테스트 자동화

<br>

💡 Key Engineering Challenges & Solutions

### 1. `LAG` 윈도우 함수를 활용한 '시공간 모순(Impossible Travel)' 탐지
* **문제:** 서울에서 결제한 지 30분 만에 뉴욕에서 결제가 발생하는 도용 케이스를 찾아야 함. 수백만 건의 데이터를 루프(Loop)로 탐색하는 것은 비효율적.
* **해결:** dbt Intermediate 계층에서 SQL `LAG()` 함수를 사용하여 현재 결제 건에 '직전 결제 시간 및 국가'를 결합. 두 결제 간의 시간 차이(분 단위)와 국가 변경 여부를 계산하여 즉각적으로 사기 여부(`is_fraud`)를 판별하는 비정규화 테이블 구축.

### 2. Airflow를 통한 파이프라인 멱등성 및 내결함성 확보
* **문제:** 외부 API 통신 지연이나 DB 연결 오류 등 일시적 장애(Transient Error)로 인한 파이프라인 중단 방지 필요.
* **해결:** `retries=2`, `retry_delay=5m` 속성을 부여하여 실패한 Task부터 자동으로 재시작하도록 구성. `catchup=False`를 적용하여 스케줄러 지연 시 데이터 중복 적재(Fan-out) 방지.

### 3. dbt Test를 통한 무결성 보장
* **해결:** `schema.yml`을 구성하여 원본 및 마트 테이블의 주요 컬럼(`trx_id`, `amount`)에 대해 `not_null` 및 `unique` 테스트를 강제. 테스트 실패 시 후속 작업이 중단되도록 하여 오염된 데이터의 서빙을 원천 차단.

<br>

## 🛠️ Tech Stack
Language: Python 3.x, SQL

Orchestration: Apache Airflow

Data Transformation: dbt (data build tool)

Data Warehouse: Google BigQuery (Standard SQL)

Version Control: Git / GitHub

## 프로젝트를 진행하며 단순히 데이터를 옮기는 것을 넘어, '유지보수성'과 '비즈니스 로직의 정확성'을 확보하기 위해 다음 세 가지를 고민하고 해결했습니다.

### 1. 사용자의 물리적 동선을 데이터 모델링으로 치환하는 방법
* **고민:** '시공간 모순(Impossible Travel)'이라는 비즈니스 룰을 데이터로 어떻게 구현할 것인가? 단순히 국가 코드가 변경된 것만으로는 정상적인 출장/여행과 도용을 구분하기 어려웠습니다.
* **해결:** 사용자의 여정이 물리적으로 끊어지는 지점을 찾기 위해, `LAG` 윈도우 함수와 하버사인(Haversine) 공식을 결합했습니다. 두 결제 건 사이의 '거리(km)'와 '시간차(Hour)'를 계산해 **이동 속도**를 도출하고, 상용 여객기 한계 속도(1,000km/h)를 임계치(Threshold)로 설정하여 오탐율을 획기적으로 낮췄습니다.

### 2. 거대한 레거시 SQL을 방지하기 위한 dbt 모듈화 설계
* **고민:** 복잡한 거리 계산과 환율 변환 로직을 하나의 쿼리(Fact 테이블)에 몰아넣을 경우, 데이터의 입자(Grain)가 섞이고 추후 코드 재사용이 불가능해지는 문제가 예상되었습니다. 웹 개발에서 관심사의 분리(MVC)를 적용하듯 데이터 로직도 분리가 필요했습니다.
* **해결:** dbt를 도입하여 데이터 가공 계층을 3단계로 명확히 분리했습니다.
  * `Staging`: 원천 데이터 1:1 매핑 및 타입 캐스팅
  * `Intermediate`: 거리 계산 Macro 호출, 환율 변환 등 복잡한 중간 연산 전담
  * `Marts`: 최종 비즈니스 룰(CASE WHEN) 및 필터링만 적용
* 이를 통해 각 단계별 테이블의 Grain을 명확히 통제하고, 중복 코드를 제거했습니다.

### 3. 클라우드 웨어하우스 최적화를 위한 구체화
* **고민:** 모든 가공 단계의 데이터를 물리적 테이블(Table)로 저장하면 스토리지 비용이 증가하고 I/O 병목이 발생합니다.
* **해결:** `dbt_project.yml`을 통해 전역 구체화 전략을 수립했습니다. 원본을 비추는 Staging은 가벼운 `View`로, 복잡한 중간 연산이 일어나는 Intermediate는 하드디스크에 쓰지 않는 `Ephemeral`로 설정했습니다. BI 툴이 직접 바라보는 최종 Marts 계층만 `Table`로 굽도록 설정하여 쿼리 성능과 스토리지 비용의 균형을 맞췄습니다.

### 4. 일시적 네트워크 장애(Transient Error)에 대한 파이프라인 내결함성 확보
* **고민:** 외부 환율 API나 원천 데이터 DB의 일시적인 순단으로 인해 자정에 도는 배치 파이프라인이 실패한다면?
* **해결:** Airflow DAG 설정에 `retries=2`와 `retry_delay=5m` 속성을 부여했습니다. 파이프라인 실패 시 처음부터 도는 것이 아니라 실패한 Task부터 자동으로 재시작되도록 하여 불필요한 컴퓨팅 자원 낭비를 막고 운영 안정성을 높였습니다.

## 📂 Repository Structure
```text
📦 FDS-Fraud-Detection-Pipeline
 ┣ 📂 dags/                   # Airflow DAGs (Scheduling & Retries)
 ┣ 📂 data_generator/         # Python Faker 기반 데이터 생성 로직
 ┣ 📂 dbt_fds_marts/
 ┃ ┣ 📂 macros/               # 하버사인 거리 계산 등 재사용 로직
 ┃ ┣ 📂 models/
 ┃ ┃ ┣ 📂 staging/            # Raw 데이터 정제 (Staging Layer)
 ┃ ┃ ┣ 📂 intermediate/       # 비즈니스 로직 가공 (Intermediate Layer)
 ┃ ┃ ┗ 📂 marts/              # 최종 분석용 데이터 (Marts Layer)
 ┃ ┣ 📜 dbt_project.yml       # dbt 전역 설정 및 구체화 전략
 ┃ ┗ 📜 profiles.sample.yml   # DB 접속 설정 샘플 (보안 가이드 포함)
 ┣ 📜 README.md
 ┗ 📜 requirements.txt
