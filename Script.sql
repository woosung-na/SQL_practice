-- 1. 기존 잔재 삭제 (에러 방지용)
DROP TABLE IF EXISTS Attendance, Grade, Review, Subject, Enrollment, Course, Student, Staff, Instructor CASCADE;

-- 2. 독립 테이블 (부모)
CREATE TABLE Student (
    Student_ID SERIAL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Phone VARCHAR(20) UNIQUE,
    Email VARCHAR(100) UNIQUE
);

CREATE TABLE Staff (
    Staff_ID SERIAL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Dept VARCHAR(50),
    Position VARCHAR(50)
);

CREATE TABLE Instructor (
    Instructor_ID SERIAL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Major VARCHAR(100)
);

-- 3. 1차 참조 테이블 (부모가 있어야 생성 가능)
CREATE TABLE Course (
    Course_ID SERIAL PRIMARY KEY,
    Staff_ID INT REFERENCES Staff(Staff_ID), 
    Course_Name VARCHAR(100) NOT NULL,
    Category VARCHAR(50)
);

-- 4. 2차 참조 테이블 (Student와 Course가 모두 있어야 생성 가능)
CREATE TABLE Enrollment (
    Enrollment_ID SERIAL PRIMARY KEY,
    Student_ID INT REFERENCES Student(Student_ID),
    Course_ID INT REFERENCES Course(Course_ID),
    Status VARCHAR(20) CHECK (Status IN ('신청', '수강중', '수료', '중도탈락')),
    Enrollment_Date DATE DEFAULT CURRENT_DATE
);

-- 5. 3차 참조 테이블 (Enrollment나 Course가 있어야 생성 가능)
CREATE TABLE Subject (
    Subject_ID SERIAL PRIMARY KEY,
    Course_ID INT REFERENCES Course(Course_ID) ON DELETE CASCADE,
    Instructor_ID INT REFERENCES Instructor(Instructor_ID),
    Content JSONB
);

CREATE TABLE Attendance (
    Attendance_ID SERIAL PRIMARY KEY,
    Enrollment_ID INT REFERENCES Enrollment(Enrollment_ID) ON DELETE CASCADE,
    Attendance_Date DATE NOT NULL DEFAULT CURRENT_DATE,
    Status VARCHAR(10) CHECK (Status IN ('출석', '결석', '지각', '조퇴'))
);

CREATE TABLE Grade (
    Grade_ID SERIAL PRIMARY KEY,
    Enrollment_ID INT REFERENCES Enrollment(Enrollment_ID) ON DELETE CASCADE,
    Score NUMERIC(5,2) CHECK (Score >= 0 AND Score <= 100),
    Level CHAR(1)
);

CREATE TABLE Review (
    Review_ID SERIAL PRIMARY KEY,
    Enrollment_ID INT REFERENCES Enrollment(Enrollment_ID) ON DELETE CASCADE,
    Rating INT CHECK (Rating >= 1 AND Rating <= 5),
    Comment TEXT
);