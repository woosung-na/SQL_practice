-- ==============================================
-- PostgreSQL JOIN 실습 (대용량 샘플 데이터 1,000+)
-- 요구 사항: PostgreSQL 11+
-- ==============================================

-- =========================
-- 0) 초기화 (FK 의존성 고려)
-- =========================
DROP TABLE IF EXISTS enroll;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS emp;
DROP TABLE IF EXISTS student;
DROP TABLE IF EXISTS customers;

-- =========================
-- 1) 스키마 생성
-- =========================

-- 1-1) student
CREATE TABLE student (
  student_id INT PRIMARY KEY,
  name       VARCHAR(50),
  major      VARCHAR(50),
  gpa        NUMERIC(3,2)
);

-- 1-2) enroll
-- NOTE: 실습 의도(고아 데이터 삽입)를 위해 FK를 걸지 않음
CREATE TABLE enroll (
  student_id INT,
  course     VARCHAR(50),
  grade      CHAR(1)
);

-- 1-3) customers / orders (FK 유지)
CREATE TABLE customers (
  customer_id   INT PRIMARY KEY,
  customer_name VARCHAR(50)
);

CREATE TABLE orders (
  order_id    INT PRIMARY KEY,
  customer_id INT REFERENCES customers(customer_id),
  amount      NUMERIC(10,2)
);

-- 1-4) emp (자기참조 FK 유지)
CREATE TABLE emp (
  emp_id     INT PRIMARY KEY,
  name       VARCHAR(50),
  manager_id INT NULL REFERENCES emp(emp_id)
);

-- =========================
-- 2) 인덱스
-- =========================
CREATE INDEX ix_enroll_student ON enroll(student_id);
CREATE INDEX ix_orders_customer ON orders(customer_id);
CREATE INDEX ix_emp_manager ON emp(manager_id);

-- =========================
-- 3) 데이터 적재
-- =========================

-- 3-1) 학생 1,000건
INSERT INTO student (student_id, name, major, gpa)
SELECT gs AS student_id,
       'Student_' || gs AS name,
       CASE gs % 5
         WHEN 0 THEN 'CS'
         WHEN 1 THEN 'EE'
         WHEN 2 THEN 'ME'
         WHEN 3 THEN 'CE'
         ELSE 'BIO'
       END AS major,
       ROUND(2.0 + (gs % 30)/10.0, 2) AS gpa
FROM generate_series(1,1000) AS gs;

-- (19번 데모용) HR 전공 학생 20명 만들기
UPDATE student
SET major = 'HR'
WHERE student_id BETWEEN 981 AND 1000;

-- 3-2) 수강(enroll) 0~3개/학생
--     - 10%는 수강 0개(미수강 학생 생성: 5,18,10번용)
--     - DB 과목이 데이터에 존재하도록 섞음(11,20번용)
INSERT INTO enroll (student_id, course, grade)
SELECT
  s.student_id,
  CASE
    WHEN ((s.student_id + k) % 21) = 0 THEN 'DB'  -- 21 중 1개는 DB
    ELSE 'Course_' || (((s.student_id + k) % 20) + 1)
  END AS course,
  (ARRAY['A','B','C','D'])[((s.student_id + k) % 4) + 1] AS grade
FROM student s
JOIN LATERAL generate_series(
  1,
  CASE
    WHEN (s.student_id % 10) = 0 THEN 0         -- 10% 미수강
    WHEN (s.student_id % 2)  = 0 THEN 2         -- 짝수 2과목
    ELSE 3                                      -- 홀수 3과목
  END
) AS g(k) ON TRUE;

-- 3-2-1) 고아(학생 미존재) 수강 데이터 (FULL OUTER JOIN 관찰용)
INSERT INTO enroll (student_id, course, grade) VALUES
(1001,'AI','A'),
(1010,'ML','B');

-- 3-3) 고객 500건
INSERT INTO customers (customer_id, customer_name)
SELECT gs, 'Customer_' || gs
FROM generate_series(1,500) gs;

-- 3-4) 주문 3,000건
INSERT INTO orders (order_id, customer_id, amount)
SELECT gs AS order_id,
       (gs % 500) + 1 AS customer_id,
       ROUND(5 + (gs * 13) % 5000 + (gs % 100) / 100.0, 2) AS amount
FROM generate_series(1,3000) gs;

-- 3-5) 직원 조직도: 1 CEO + 10 매니저 + 300 직원
INSERT INTO emp VALUES (1,'CEO',NULL);

INSERT INTO emp (emp_id, name, manager_id)
SELECT 1 + gs, 'Mgr_' || (1 + gs), 1
FROM generate_series(1,10) gs;

INSERT INTO emp (emp_id, name, manager_id)
SELECT 11 + gs, 'Dev_' || (11 + gs), 1 + ((gs - 1) % 10)
FROM generate_series(1,300) gs;

