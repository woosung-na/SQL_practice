# ERD
<img width="699" height="581" alt="myapp_db-diagram" src="https://github.com/user-attachments/assets/fab9a1da-6351-4570-8dd9-d8073078373c" />
범례 (Legend): - 🔑 PK: 기본키 (Primary Key) - 🔗 FK: 외래키 (Foreign Key) - 연결선: 테이블 간 참조 관계 및 데이터 흐름

# 테이블 구성 및 관계
총 9개의 테이블로 구성되어 있으며, 각 주체별로 역할을 분리하였습니다. 
- **기초 정보 테이블**: student(학생), staff(운영진), instructor(강사) 
- **과정 관리 테이블**: course(교육 과정), subject(세부 과목) 
- **운영 데이터 테이블**: enrollment(수강 신청), attendance(출결), grade(성적), review(수강 후기)
  
# 핵심 기능 및 자동화 (Trigger)
데이터 무결성을 보장하고 관리 효율을 높이기 위해 다음의 트리거를 적용했습니다.
- 수강 신청 시 성적부 자동 생성: enrollment 테이블에 데이터가 추가되면 자동으로 해당 학생의 grade 행을 생성합니다.
- 성적 등급 자동 업데이트: grade 테이블의 점수(score)가 수정될 때마다 미리 정의된 로직에 따라 등급(level)이 A~F로 자동 계산됩니다.
  
# 데이터 무결성 제약 조건
- 출결 상태 제한: status 컬럼에 '출석', '결석', '지각', '조퇴'만 입력 가능하도록 설정했습니다. 
- 점수 범위 제한: score는 0점에서 100점 사이의 값만 가질 수 있습니다. 
- 평점 범위 제한: review의 별점은 1점에서 5점 사이로 고정했습니다.
  
# **향후 발전 방향**
- 보안 강화 (Schema Separation): 현재 public 스키마에 구현된 테이블들을 전용 스키마로 분리하여 접근 권한을 세분화할 계획입니다.
- 출결 정밀도 향상: 현재 일자별 기록 방식에서 수업 회차(Session) 단위 관리로 확장하여 교시별 출결 관리를 지원하겠습니다.
- 이력 추적: 데이터 변경 시점을 기록하는 타임스탬프(created_at, updated_at)를 전 테이블에 도입하겠습니다.
