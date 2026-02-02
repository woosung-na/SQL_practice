-- =========================================
-- HR Slow Query Lab (PostgreSQL) - FIXED
-- PostgreSQL 11+
-- =========================================

-- (선택) 재실행 용도: 기존 테이블 제거
-- DROP TABLE IF EXISTS job_history;
-- DROP TABLE IF EXISTS employees;
-- DROP TABLE IF EXISTS jobs;
-- DROP TABLE IF EXISTS departments;
-- DROP TABLE IF EXISTS locations;

-- 1) 테이블 생성
CREATE TABLE locations (
  location_id   SERIAL PRIMARY KEY,
  city          TEXT NOT NULL,
  country       TEXT NOT NULL,
  region        TEXT NOT NULL
);

CREATE TABLE departments (
  department_id   SERIAL PRIMARY KEY,
  department_name TEXT NOT NULL,
  location_id     INT NOT NULL REFERENCES locations(location_id)
);

CREATE TABLE jobs (
  job_id     SERIAL PRIMARY KEY,
  job_title  TEXT NOT NULL,
  min_salary INT NOT NULL,
  max_salary INT NOT NULL
);

CREATE TABLE employees (
  employee_id   BIGSERIAL PRIMARY KEY,
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  phone         TEXT,
  hire_date     DATE NOT NULL,
  salary        INT NOT NULL,
  manager_id    BIGINT NULL,
  department_id INT NOT NULL REFERENCES departments(department_id),
  job_id        INT NOT NULL REFERENCES jobs(job_id),
  status        TEXT NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE job_history (
  employee_id   BIGINT NOT NULL REFERENCES employees(employee_id),
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  department_id INT NOT NULL REFERENCES departments(department_id),
  job_id        INT NOT NULL REFERENCES jobs(job_id),
  PRIMARY KEY (employee_id, start_date)
);

-- 2) 기준 데이터 적재 (locations/departments/jobs)
INSERT INTO locations(city, country, region)
SELECT
  'City_'||gs::text,
  (ARRAY['KR','US','JP','DE','FR','GB','IN','CN'])[1 + (random()*7)::int],
  (ARRAY['APAC','EMEA','AMER'])[1 + (random()*2)::int]
FROM generate_series(1, 50) gs;

INSERT INTO departments(department_name, location_id)
SELECT
  'Dept_'||gs::text,
  1 + (random() * 49)::int
FROM generate_series(1, 200) gs;

INSERT INTO jobs(job_title, min_salary, max_salary)
SELECT
  'Job_'||gs::text,
  2000 + (random()*1000)::int,
  8000 + (random()*7000)::int
FROM generate_series(1, 40) gs;

-- 3) 대량 employees 생성 (약 50,000건)
-- FIX: hire_date를 CURRENT_DATE 기준으로 생성하여 "최근 365일" 데이터가 항상 존재하도록 함
--      - 약 20%는 최근 365일 내, 나머지는 과거(약 10년)로 분산
WITH nums AS (
  SELECT gs AS n FROM generate_series(1, 50000) gs
)
INSERT INTO employees(
  first_name, last_name, email, phone, hire_date, salary,
  manager_id, department_id, job_id, status
)
SELECT
  'First_'||n,
  'Last_'||n,
  lower('user'||n||'@'||(ARRAY['corp.com','example.com','mail.com','gmail.com','outlook.com'])[1+(random()*4)::int]),
  '010-'||lpad(((random()*9999)::int)::text,4,'0')||'-'||lpad(((random()*9999)::int)::text,4,'0'),
  CASE
    WHEN random() < 0.20
      THEN CURRENT_DATE - ((random() * 364)::int)          -- 최근 365일 (20%)
    ELSE
      CURRENT_DATE - (365 + (random() * 3300)::int)        -- 그 이전 (약 9년) (80%)
  END AS hire_date,
  2000 + (random()*10000)::int,
  CASE WHEN random() < 0.2 THEN NULL ELSE 1 + (random()*200)::int END,
  1 + (random()*199)::int,
  1 + (random()*39)::int,
  CASE WHEN random() < 0.05 THEN 'INACTIVE' ELSE 'ACTIVE' END
FROM nums;

-- 4) job_history 일부 생성 (직무/부서 이동 이력)
INSERT INTO job_history(employee_id, start_date, end_date, department_id, job_id)
SELECT
  e.employee_id,
  e.hire_date,
  e.hire_date + (30 + (random()*900)::int),
  1 + (random()*199)::int,
  1 + (random()*39)::int
FROM employees e
WHERE e.employee_id % 10 = 0;  -- 10명 중 1명만 이력 생성

VACUUM ANALYZE;

-- (선택) 문제 방지 확인: 최근 365일 조건에 걸리는 직원 수 (0이 아니어야 함)
SELECT COUNT(*) AS recent_365_cnt
FROM employees
WHERE hire_date >= CURRENT_DATE - INTERVAL '365 days';