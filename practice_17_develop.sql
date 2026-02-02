-- 1. 학생과 수강을 INNER JOIN하여 수강 존재 학생의 과목/성적을 조회
explain analyze
select a.name, b.course, b.grade
from student a 
	join enroll b on a.student_id = b.student_id;

explain analyze
SELECT a.name, b.course, b.grade
FROM student a, enroll b
WHERE a.student_id = b.student_id;

-- 2. 모든 학생 기준으로 수강을 붙이고, 과목(없으면 NULL)까지 보이기 → OUTER JOIN
explain analyze
select a.name, b.course, b.grade 
from student a
	left outer join enroll b on a.student_id = b.student_id
ORDER BY a.student_id;

explain analyze
SELECT a.name, b.course, b.grade 
FROM enroll b 
RIGHT OUTER JOIN student a ON a.student_id = b.student_id
ORDER BY a.student_id;

-- 3. 수강이 기준. 학생이 없으면 학생 정보가 NULL
explain analyze
select a.course, b.name, a.grade
from enroll a
	left outer join student b on a.student_id = b.student_id
order by a.course;

explain analyze
SELECT a.course, b.name, a.grade
FROM student b
RIGHT OUTER JOIN enroll a ON a.student_id = b.student_id
ORDER BY a.course;

-- 4. 학생/수강 모두 포함
explain analyze
select a.name, b.course, b.grade
from student a
	full outer join enroll b on a.student_id = b.student_id
order by 1, 2;

explain analyze
SELECT a.name, b.course, b.grade
FROM student a
FULL JOIN enroll b ON a.student_id = b.student_id
WHERE a.student_id IS NOT NULL OR b.student_id IS NOT NULL
ORDER BY 1, 2;
	
-- 5. 한 번도 수강하지 않은 학생 목록
explain analyze
select a.name, b.course, a.major, a.gpa
from student a
	left outer join enroll b on a.student_id = b.student_id
where b.student_id is null;

explain analyze
SELECT a.name, NULL as course, a.major, a.gpa
FROM student a
WHERE NOT EXISTS (
    SELECT 1 
    FROM enroll b 
    WHERE b.student_id = a.student_id -- 연결 고리
);

-- 6. 한 과목 이상 수강한 학생 목록(중복 제거)
explain analyze
select distinct a.student_id, b.student_id, a.name, a.major, a.gpa
from student a
	left outer join enroll b on a.student_id = b.student_id
where b.student_id is not null
order by 1;

explain analyze
SELECT DISTINCT a.student_id, a.name, a.major, a.gpa
FROM student a
JOIN enroll b ON a.student_id = b.student_id
ORDER BY 1;

-- 7. 고객별 주문건수/총액
explain analyze
select a.customer_id, count(order_id) 주문건수, sum(b.amount) 총액
from customers a
	left join orders b on a.customer_id = b.customer_id
group by a.customer_id
order by 1;

-- 안좋은 쿼리의 대표적인 예. 버퍼 수 개많음 
explain analyze
SELECT 
    a.customer_id,
    (SELECT COUNT(*) FROM orders b WHERE b.customer_id = a.customer_id) AS 주문건수,
    (SELECT SUM(amount) FROM orders b WHERE b.customer_id = a.customer_id) AS 총액
FROM customers a
ORDER BY 1;

-- 8. 총액 상위 10명과 금액
explain analyze
select a.customer_id, count(order_id) 주문건수, sum(b.amount) 총액
from customers a
	left join orders b on a.customer_id = b.customer_id
group by a.customer_id
order by 3 desc
limit 10;

explain analyze
SELECT 
    a.customer_id, 
    COUNT(b.order_id) AS 주문건수, 
    SUM(b.amount) AS 총액
FROM customers a
LEFT JOIN orders b ON a.customer_id = b.customer_id
GROUP BY a.customer_id
ORDER BY 총액 DESC NULLS LAST  -- 별칭 사용 및 NULL 처리 추가
LIMIT 10;

-- 9. 모든 직원과 그 매니저 이름
explain analyze
select a.emp_id, a.name 직원, b.name 매니저
from emp a
	left join emp b on a.manager_id = b.emp_id
order by 1;

explain analyze
SELECT b.emp_id, b.name AS 직원, a.name AS 매니저
FROM emp a
RIGHT JOIN emp b ON b.manager_id = a.emp_id
ORDER BY 1;
	
-- 10. “모든 학생 기준”으로 과목 분포를 보고 싶다 → LEFT JOIN + 집계
explain analyze
select a.student_id, count(b.course) 과목분포
from student a
	left outer join enroll b on a.student_id = b.student_id
group by a.student_id
ORDER BY 1;

explain analyze
SELECT 
    s.student_id, 
    (SELECT COUNT(*) FROM enroll e WHERE e.student_id = s.student_id) AS 과목분포
FROM student s
ORDER BY 1;


-- 11. DB 과목을 듣지 않은 모든 학생을 나열
explain analyze
select a.student_id, a.name, b.course DB유무
from student a
	left join enroll b on a.student_id = b.student_id
	and b.course = 'DB'
where b.student_id is null;
-- 0.018

explain analyze
SELECT a.student_id, a.name, 'N' AS DB유무
FROM student a
WHERE NOT EXISTS (
    SELECT 1 FROM enroll b 
    WHERE b.student_id = a.student_id AND b.course = 'DB'
);
-- 0.004

explain analyze
select s.name
from student s
left join enroll e
on s.student_id = e.student_id
and e.course = 'DB'
where e.course is NULL;
-- 0.002

explain analyze
SELECT DISTINCT s.student_id, s.major, s.gpa
FROM student s
WHERE NOT EXISTS (
	SELECT 1
	FROM enroll e
	WHERE s.student_id = e.student_id AND e.course = 'DB'
);
-- 0.002 지성2

explain analyze
SELECT s.name
FROM student s
LEFT JOIN enroll e 
    ON s.student_id = e.student_id 
    AND e.course = 'DB'
WHERE e.student_id IS NULL;
-- 0.002 진

-- 12. (가정) 과목별로 매니저가 운영 책임을 갖는다고 가정하고, 
-- emp의 매니저(이름 ‘Mgr_’로 시작)와 과목을 임의로 매핑한 
-- 테이블 course_owner(course, manager_id)를 만든 뒤, 
-- 과목별 수강 인원 + 책임 매니저 이름 리포트를 작성하세요.
CREATE TABLE course_owner (
  course VARCHAR(50),
  manager_id INT NULL REFERENCES emp(emp_id)
);

INSERT INTO course_owner (course, manager_id)
VALUES 
  ('DB', 2),        -- Mgr_1
  ('Course_1', 3),  -- Mgr_2
  ('Course_2', 4),  -- Mgr_3
  ('Course_3', 5),  -- Mgr_4
  ('Course_4', 6);  -- Mgr_5

explain analyze
select a.course 과목, count(b.student_id) 과목별_수강_인원, c.name 매니저_이름
from course_owner a
	left join enroll b on a.course = b.course
	left join emp c on a.manager_id = c.emp_id
group by a.course, c.name;
-- 0.011

explain analyze
WITH enroll_count AS (
    SELECT course, COUNT(student_id) AS cnt FROM enroll GROUP BY course
)
SELECT a.course, COALESCE(e.cnt, 0) AS 수강인원, c.name AS 매니저
FROM course_owner a
LEFT JOIN enroll_count e ON a.course = e.course
JOIN emp c ON a.manager_id = c.emp_id;
-- 0.008



-- 13. 학생 x 과목 전체 조합을 만들어 “학생별 과목 추천 후보”를 만들되, 샘플 100건만 본다.
explain analyze
select a.student_id , a.name, c.course 과목_추천_후보
from student a
	cross join (
		select distinct course
		from enroll) c
limit 100;

explain analyze
SELECT a.student_id, a.name, b.course
FROM student a
CROSS JOIN (SELECT course FROM enroll GROUP BY course) b
LIMIT 100;
-- 0.003

explain analyze
select s.name, c.course
from student s
cross join (
    select distinct course 
    from enroll
) c
left join enroll e
on s.student_id = e.student_id 
and c.course = e.course
where e.student_id is null
limit 100;
-- 0.003 건욱

explain analyze
SELECT s.student_id, ef.course
FROM student s CROSS JOIN (
	SELECT DISTINCT course FROM enroll
) ef
WHERE NOT EXISTS (
	SELECT 1
	FROM enroll e
	WHERE e.student_id = s.student_id AND e.course = ef.course
)
LIMIT 100;
-- 0.003 지성2



-- 14. 스칼라 서브쿼리 (SELECT 절) 사용. 학생 + 소속 학과명 붙이기
explain analyze
select a.name, (select b.major 
				from student b 
				where a.student_id = b.student_id) 소속_학과명
from student a;

explain analyze
SELECT name, major AS 소속_학과명
FROM student;
-- 0.003

explain analyze
select
	student_id,
	(
		select row(name, major)
		from student s
		where s.student_id = ss.student_id
	) as student_info
from student ss;
-- 0.006 건욱

explain analyze
SELECT name || '/' || major AS info
FROM student;
-- 0.002 지성1

explain analyze
select 
	s.name || '_' || s.major
from student s;
-- 0.001 진

-- 15. 평균 GPA 보다 높은 학생 (WHERE 서브쿼리)
explain analyze
select a.name, a.major, a.gpa, (select avg(b.gpa) from student b) 평균_GPA
from student a
where a.gpa > (select avg(b.gpa)
			 from student b);
-- 0.009

explain analyze
SELECT name, major, gpa, avg_gpa
FROM (
    SELECT name, major, gpa, AVG(gpa) OVER() AS avg_gpa
    FROM student
) t
WHERE gpa > avg_gpa;
-- 0.003

explain analyze
select s.name, s.gpa
from student s
where s.gpa > (
	select avg(gpa)
	from student
);
-- 0.002 건욱


-- 16. 자신의 학과 평균 GPA보다 높은 학생 (Correlated subquery)
explain analyze
select a.name, a.major, a.gpa, (select avg(b.gpa)
			 					from student b
			 					where b.major = a.major) 학과_평균_GPA
from student a
where a.gpa > (select avg(b.gpa)
			 from student b
			 where b.major = a.major)
order by 2, 3, 1;

explain analyze
WITH major_avg AS (
    SELECT major, AVG(gpa) as m_avg FROM student GROUP BY major
)
SELECT s.name, s.major, s.gpa, m.m_avg AS 학과_평균_GPA
FROM student s
JOIN major_avg m ON s.major = m.major
WHERE s.gpa > m.m_avg
ORDER BY 2, 3, 1;

-- 17. 수강(enroll) 기록이 있는 학생만
explain analyze
select *
from student a
where exists (select 1
			from enroll b
			where a.student_id = b.student_id);

explain analyze
SELECT *
FROM student
WHERE student_id IN (SELECT student_id FROM enroll);

-- 18. 한 번도 수강하지 않은 학생
explain analyze
select *
from student a
where not exists (select 1
				from enroll b
				where a.student_id = b.student_id);

explain analyze
SELECT a.*
FROM student a
LEFT JOIN enroll b ON a.student_id = b.student_id
WHERE b.student_id IS NULL;

-- 19. HR vs CS 학과 평균 GPA 비교
explain analyze
select distinct(select avg(b.gpa)
			from student b
			where b.major = a.major and a.major = 'HR') HR_평균_GPA, (select avg(c.gpa)
			from student c
			where c.major = a.major and a.major = 'CS') CS_평균_GPA
from student a;

explain analyze
SELECT 
    (SELECT AVG(gpa) FROM student WHERE major = 'HR') AS HR_평균_GPA,
    (SELECT AVG(gpa) FROM student WHERE major = 'CS') AS CS_평균_GPA;

-- 성현이거
explain analyze
SELECT major, AVG(gpa) AS avg_gpa 
FROM student 
WHERE major IN ('HR', 'CS') 
GROUP BY major;

-- 20. CS 학과 학생 또는 DB 과목을 수강한 학생 목록
explain analyze
select a.name, a.major, b.course
from student a
	left join enroll b on a.student_id = b.student_id
where a.major = 'CS' or b.course = 'DB';

explain analyze
SELECT name, major, NULL as course 
FROM student 
WHERE major = 'CS'
UNION
SELECT s.name, s.major, e.course 
FROM student s 
JOIN enroll e ON s.student_id = e.student_id
WHERE e.course = 'DB';





