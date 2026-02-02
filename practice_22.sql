-- 1. 실행 계획 맛보기 (사번이 100인 사람 검색)
explain analyze
select a.first_name, a.last_name
from employees a
where a.employee_id = 100;
--------------
drop index idx_employee_id;
---------------
create index idx_employee_id on employees(employee_id);

analyze employees;

explain analyze
select a.first_name, a.last_name
from employees a
where a.employee_id = 100;
----------------------------------------------
----------------------------------------------
-- 2. 인덱스 없는 느린 쿼리 작성 후 쿼리 튜닝 (이메일 주소가 user1234@corp.com인 사람, lower(email) 사용)
-- 느린 쿼리
explain analyze
select a.first_name 
from employees a
where lower(a.email) = 'user1234@corp.com';
---------------
drop index idx_email_lower;
-- 튜닝 쿼리 ([B-tree] 정확한 값lower idx 생성)
create index idx_email_lower on employees(lower(email));

analyze employees;
-- index scan
explain analyze
select a.first_name 
from employees a
where a.email = 'user1234@corp.com';
----------------------------------------------
----------------------------------------------
-- 3. LIKE 검색 쿼리 작성 후 쿼리 튜닝 (대상: ‘%gmail.com’ 같은 접미사 검색)
-- 느린 쿼리 0.015
-- drop index idx_email_include;
explain analyze
select a.first_name
from employees a
where a.email like '%gmail.com';
---------------
-- 튜닝 쿼리 1 ([GIN] 포함 값 IDX 생성) 0.011
-- trgm 확장 활성화
CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- 인덱스 정의
create index idx_email_include on employees using gin (email gin_trgm_ops);

analyze employees;

explain analyze
select a.first_name
from employees a
where a.email like '%gmail.com';
---------------
-- 튜닝 쿼리 2 ([B-Tree] 뒤집어서 저장 IDX 생성) 0.015
create index id_email_rev on employees (reverse(email) varchar_pattern_ops) include (first_name);
drop index id_email_rev;

analyze employees;

explain analyze
SELECT first_name
FROM employees
WHERE reverse(email) LIKE reverse('%gmail.com');
----------------------------------------------
----------------------------------------------
-- 4. 정렬(ORDER BY)과 필터가 결합된 쿼리 작성 후 쿼리 튜닝 
-- (hire_date ≥ CURRENT_DATE - INTERVAL ‘365 days’ 이면서 재직중인 사람을 연봉순으로 상위 100명만 출력)
-- 느린 쿼리 0.015s
explain analyze
select a.first_name, a.last_name, a.salary
from employees a
where a.hire_date >= CURRENT_DATE - INTERVAL '365 days' 
	and a.status = 'ACTIVE'
order by 3 desc
limit 100;
-----------------
-- drop index idx_filter;
-- 튜닝 쿼리 (필터링 조건 복합 인덱싱-status, hire_date, salary desc) 0.007
create index idx_filter on employees (status, hire_date, salary desc);

analyze employees;

explain analyze
select a.first_name, a.last_name, a.salary
from employees a
where a.hire_date >= CURRENT_DATE - INTERVAL '365 days' 
	and a.status = 'ACTIVE'
order by 3 desc
limit 100;
----------------------------------------------
----------------------------------------------
-- 5. OR 조건 쿼리 작성 후 쿼리 튜닝 (조건: 부서코드가 10 또는 직무가 3, 4, 5 안에 있는 사람 검색)
-- 느린 쿼리 0.012
explain analyze
select a.first_name, a.department_id, a.job_id
from employees a
where a.department_id = '10' or a.job_id in (3, 4, 5);
-----------------
-- drop index idx_dept_id;
-- drop index idx_job_id;
-- 튜닝 쿼리 (각 필터링 조건 indexing, or 조건 union으로 분기)
create index idx_dept_id on employees (department_id);
create index idx_job_id on employees (job_id);

analyze employees;

explain analyze
select a.first_name, a.department_id, a.job_id
from employees a
where a.department_id = '10'

union all

select a.first_name, a.department_id, a.job_id
from employees a
where a.job_id in (3, 4, 5)
	and (a.department_id <> '10' or a.department_id is null);
