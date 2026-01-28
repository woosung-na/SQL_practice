-- 1. 학생 등록
INSERT INTO Student (Name, Phone, Email) VALUES ('김철수', '010-1111-2222', 'chul@test.com');

-- 2. 운영자 등록
INSERT INTO Staff (Name, Dept, Position) VALUES ('박운영', '학사팀', '과장');

-- 3. 강사 등록
INSERT INTO Instructor (Name, Major) VALUES ('최강사', '데이터베이스');

-- 4. 교육 과정 등록 (운영자 1번 참조)
INSERT INTO Course (Staff_ID, Course_Name, Category) VALUES (1, '파이썬 기초', 'Programming');

--
-- 수강 신청 (학생 1번이 과정 1번 신청)
INSERT INTO Enrollment (Student_ID, Course_ID, Status) VALUES (1, 1, '수강중');

-- 검증: Grade 테이블에 데이터가 생겼는지 조회
SELECT * FROM Grade;

--
-- 오류 테스트: 별점 6점 입력 (제약 조건에 의해 에러가 나야 함)
INSERT INTO Review (Enrollment_ID, Rating, Comment) VALUES (1, 6, '너무 좋아요!');

-- 성적 계산 트리거 검증
-- 점수를 95점으로 업데이트
UPDATE Grade SET Score = 95 WHERE Enrollment_ID = 1;

-- 검증: Level이 자동으로 'A'로 바뀌었는지 조회
SELECT * FROM Grade;