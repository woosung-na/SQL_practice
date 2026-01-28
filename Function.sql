-- 1. Enrollment: 동일 학생이 동일 과정에 중복 신청 방지
ALTER TABLE Enrollment 
ADD CONSTRAINT unique_student_course UNIQUE (Student_ID, Course_ID);

-- 2. Grade: 성적 점수 범위 제한 (0~100점) 및 등급 형식 제한
ALTER TABLE Grade 
ADD CONSTRAINT check_score_range CHECK (Score >= 0 AND Score <= 100),
ADD CONSTRAINT check_grade_level CHECK (Level IN ('A', 'B', 'C', 'D', 'F'));

-- 3. Review: 별점 범위 제한 (1~5점)
ALTER TABLE Review 
ADD CONSTRAINT check_rating_range CHECK (Rating >= 1 AND Rating <= 5);

-- 4. Attendance: 출결 상태 값 고정
ALTER TABLE Attendance 
ADD CONSTRAINT check_attendance_status CHECK (Status IN ('출석', '결석', '지각', '조퇴'));

-- 로직을 담당할 함수(Function) 생성
CREATE OR REPLACE FUNCTION fn_create_default_grade()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Grade (Enrollment_ID, Score, Level)
    VALUES (NEW.Enrollment_ID, 0, 'F');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 설정 (Functions 폴더와 Triggers 폴더에 각각 생성됨)
CREATE TRIGGER trg_after_enrollment
AFTER INSERT ON Enrollment
FOR EACH ROW
EXECUTE FUNCTION fn_create_default_grade();

CREATE OR REPLACE FUNCTION fn_update_grade_level()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Score >= 90 THEN NEW.Level := 'A';
    ELSIF NEW.Score >= 80 THEN NEW.Level := 'B';
    ELSIF NEW.Score >= 70 THEN NEW.Level := 'C';
    ELSIF NEW.Score >= 60 THEN NEW.Level := 'D';
    ELSE NEW.Level := 'F';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_before_grade_update
BEFORE UPDATE OF Score ON Grade
FOR EACH ROW
EXECUTE FUNCTION fn_update_grade_level();