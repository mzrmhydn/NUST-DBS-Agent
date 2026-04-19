-- =============================================================================
-- NUST University Database (Undergraduate Only) - MySQL 8.0+
-- Academic Module + Admissions Module
-- =============================================================================

DROP DATABASE IF EXISTS nust_university;
CREATE DATABASE nust_university;
USE nust_university;

SET NAMES utf8mb4;

-- =============================================================================
-- 1. DDL - CREATE TABLE STATEMENTS (parents before children)
-- =============================================================================

-- ---------- school ----------
CREATE TABLE school (
    school_id       VARCHAR(20)  PRIMARY KEY,
    school_name     VARCHAR(255) NOT NULL,
    abbreviation    VARCHAR(20)  NOT NULL UNIQUE,
    established_year SMALLINT
) ENGINE=InnoDB;

-- ---------- faculty ----------
CREATE TABLE faculty (
    faculty_id      VARCHAR(20)  PRIMARY KEY,
    school_id       VARCHAR(20)  NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100) UNIQUE,
    designation     VARCHAR(100),
    CONSTRAINT fk_faculty_school FOREIGN KEY (school_id)
        REFERENCES school(school_id) ON DELETE RESTRICT,
    INDEX idx_faculty_school (school_id)
) ENGINE=InnoDB;

-- ---------- program ----------
CREATE TABLE program (
    program_id      VARCHAR(20)  PRIMARY KEY,
    school_id       VARCHAR(20)  NOT NULL,
    program_name    VARCHAR(255) NOT NULL,
    degree_type     ENUM('BS','BE','B.Arch','LLB','BBA') NOT NULL,
    total_semesters TINYINT      NOT NULL,
    total_credits   SMALLINT     NOT NULL,
    total_seats     SMALLINT     NOT NULL DEFAULT 100,
    CONSTRAINT fk_program_school FOREIGN KEY (school_id)
        REFERENCES school(school_id) ON DELETE RESTRICT,
    CONSTRAINT chk_program_sem CHECK (total_semesters IN (8,10)),
    INDEX idx_program_school (school_id)
) ENGINE=InnoDB;

-- ---------- course ----------
CREATE TABLE course (
    course_code     VARCHAR(20)  PRIMARY KEY,
    school_id       VARCHAR(20)  NOT NULL,
    course_title    VARCHAR(255) NOT NULL,
    course_type     ENUM('Theory','Lab','Project') NOT NULL,
    credit_hours    TINYINT      NOT NULL,
    contact_hours   TINYINT      NOT NULL,
    CONSTRAINT fk_course_school FOREIGN KEY (school_id)
        REFERENCES school(school_id) ON DELETE RESTRICT,
    INDEX idx_course_school (school_id)
) ENGINE=InnoDB;

-- ---------- prerequisite (self-ref M:N on course) ----------
CREATE TABLE prerequisite (
    course_code         VARCHAR(20) NOT NULL,
    prereq_course_code  VARCHAR(20) NOT NULL,
    PRIMARY KEY (course_code, prereq_course_code),
    CONSTRAINT fk_prereq_course FOREIGN KEY (course_code)
        REFERENCES course(course_code) ON DELETE CASCADE,
    CONSTRAINT fk_prereq_prereq FOREIGN KEY (prereq_course_code)
        REFERENCES course(course_code) ON DELETE CASCADE,
    CONSTRAINT chk_prereq_no_self CHECK (course_code <> prereq_course_code)
) ENGINE=InnoDB;

-- ---------- program_course (M:N) ----------
CREATE TABLE program_course (
    program_id            VARCHAR(20) NOT NULL,
    course_code           VARCHAR(20) NOT NULL,
    recommended_semester  TINYINT     NOT NULL,
    is_core               BOOLEAN     NOT NULL DEFAULT TRUE,
    PRIMARY KEY (program_id, course_code),
    CONSTRAINT fk_pc_program FOREIGN KEY (program_id)
        REFERENCES program(program_id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_course FOREIGN KEY (course_code)
        REFERENCES course(course_code) ON DELETE CASCADE,
    CONSTRAINT chk_pc_sem CHECK (recommended_semester BETWEEN 1 AND 10),
    INDEX idx_pc_course (course_code)
) ENGINE=InnoDB;

-- ---------- term ----------
CREATE TABLE term (
    term_id         VARCHAR(20)  PRIMARY KEY,
    term_name       ENUM('Fall','Spring','Summer') NOT NULL,
    academic_year   SMALLINT     NOT NULL,
    start_date      DATE         NOT NULL,
    end_date        DATE         NOT NULL,
    UNIQUE KEY uk_term (term_name, academic_year)
) ENGINE=InnoDB;

-- ---------- classroom ----------
CREATE TABLE classroom (
    classroom_id    VARCHAR(20)  PRIMARY KEY,
    building        VARCHAR(100) NOT NULL,
    room_number     VARCHAR(20)  NOT NULL,
    capacity        SMALLINT     NOT NULL
) ENGINE=InnoDB;

-- ---------- applicant ----------
CREATE TABLE applicant (
    applicant_id        VARCHAR(20)  PRIMARY KEY,
    full_name           VARCHAR(100) NOT NULL,
    cnic                VARCHAR(20)  UNIQUE,
    email               VARCHAR(100) UNIQUE,
    high_school_board   ENUM('FBISE','Punjab','Sindh','KPK','AKU-EB','Balochistan','Cambridge') NOT NULL,
    high_school_score   DECIMAL(5,2) NOT NULL,
    best_test_score     DECIMAL(5,2) DEFAULT 0.00
) ENGINE=InnoDB;

-- ---------- student ----------
CREATE TABLE student (
    student_id          VARCHAR(20)  PRIMARY KEY,
    program_id          VARCHAR(20)  NOT NULL,
    applicant_id        VARCHAR(20)  NULL,
    full_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(100) UNIQUE,
    current_semester    TINYINT      NOT NULL DEFAULT 1,
    enrollment_date     DATE         NOT NULL,
    CONSTRAINT fk_student_program FOREIGN KEY (program_id)
        REFERENCES program(program_id) ON DELETE RESTRICT,
    CONSTRAINT fk_student_applicant FOREIGN KEY (applicant_id)
        REFERENCES applicant(applicant_id) ON DELETE SET NULL,
    CONSTRAINT chk_student_sem CHECK (current_semester BETWEEN 1 AND 10),
    INDEX idx_student_program (program_id),
    INDEX idx_student_applicant (applicant_id)
) ENGINE=InnoDB;

-- ---------- section ----------
CREATE TABLE section (
    section_id      VARCHAR(20)  PRIMARY KEY,
    course_code     VARCHAR(20)  NOT NULL,
    term_id         VARCHAR(20)  NOT NULL,
    classroom_id    VARCHAR(20)  NOT NULL,
    faculty_id      VARCHAR(20)  NOT NULL,
    section_label   VARCHAR(10)  NOT NULL,
    CONSTRAINT fk_section_course FOREIGN KEY (course_code)
        REFERENCES course(course_code) ON DELETE RESTRICT,
    CONSTRAINT fk_section_term FOREIGN KEY (term_id)
        REFERENCES term(term_id) ON DELETE RESTRICT,
    CONSTRAINT fk_section_classroom FOREIGN KEY (classroom_id)
        REFERENCES classroom(classroom_id) ON DELETE RESTRICT,
    CONSTRAINT fk_section_faculty FOREIGN KEY (faculty_id)
        REFERENCES faculty(faculty_id) ON DELETE RESTRICT,
    INDEX idx_section_course (course_code),
    INDEX idx_section_term (term_id),
    INDEX idx_section_classroom (classroom_id),
    INDEX idx_section_faculty (faculty_id)
) ENGINE=InnoDB;

-- ---------- enrollment ----------
CREATE TABLE enrollment (
    student_id          VARCHAR(20) NOT NULL,
    section_id          VARCHAR(20) NOT NULL,
    attendance_percentage DECIMAL(5,2) NULL,
    grade               ENUM('A','B+','B','C+','C','D+','D','F','XF','I','W') NULL,
    PRIMARY KEY (student_id, section_id),
    CONSTRAINT fk_enroll_student FOREIGN KEY (student_id)
        REFERENCES student(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_enroll_section FOREIGN KEY (section_id)
        REFERENCES section(section_id) ON DELETE CASCADE,
    INDEX idx_enroll_section (section_id)
) ENGINE=InnoDB;

-- ---------- entry_test ----------
CREATE TABLE entry_test (
    test_id         VARCHAR(20)  PRIMARY KEY,
    test_type       ENUM('NET-1','NET-2','NET-3','NET-4') NOT NULL,
    test_date       DATE         NOT NULL,
    total_marks     SMALLINT     NOT NULL DEFAULT 200
) ENGINE=InnoDB;

-- ---------- test_attempt ----------
CREATE TABLE test_attempt (
    applicant_id    VARCHAR(20)  NOT NULL,
    test_id         VARCHAR(20)  NOT NULL,
    score           DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (applicant_id, test_id),
    CONSTRAINT fk_ta_applicant FOREIGN KEY (applicant_id)
        REFERENCES applicant(applicant_id) ON DELETE CASCADE,
    CONSTRAINT fk_ta_test FOREIGN KEY (test_id)
        REFERENCES entry_test(test_id) ON DELETE CASCADE,
    INDEX idx_ta_test (test_id)
) ENGINE=InnoDB;

-- ---------- application ----------
CREATE TABLE application (
    application_id          VARCHAR(20) PRIMARY KEY,
    applicant_id            VARCHAR(20) NOT NULL,
    program_id              VARCHAR(20) NOT NULL,
    term_id                 VARCHAR(20) NOT NULL,
    snapshot_hs_score       DECIMAL(5,2) NOT NULL,
    snapshot_best_test      DECIMAL(5,2) NOT NULL,
    aggregate_score         DECIMAL(6,2) NOT NULL,
    submission_date         DATE NOT NULL,
    status                  ENUM('Submitted','Offered','Accepted','Rejected','Withdrawn') NOT NULL DEFAULT 'Submitted',
    CONSTRAINT fk_app_applicant FOREIGN KEY (applicant_id)
        REFERENCES applicant(applicant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_program FOREIGN KEY (program_id)
        REFERENCES program(program_id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_term FOREIGN KEY (term_id)
        REFERENCES term(term_id) ON DELETE RESTRICT,
    UNIQUE KEY uk_app (applicant_id, program_id, term_id),
    INDEX idx_app_program (program_id),
    INDEX idx_app_term (term_id)
) ENGINE=InnoDB;

-- ---------- offer ----------
CREATE TABLE offer (
    offer_id        VARCHAR(20)  PRIMARY KEY,
    application_id  VARCHAR(20)  NOT NULL UNIQUE,
    issue_date      DATE         NOT NULL,
    expiry_date     DATE         NOT NULL,
    status          ENUM('Pending','Accepted','Declined','Expired') NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_offer_app FOREIGN KEY (application_id)
        REFERENCES application(application_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =============================================================================
-- TRIGGERS
-- =============================================================================
DELIMITER $$

CREATE TRIGGER trg_enrollment_xf
BEFORE UPDATE ON enrollment
FOR EACH ROW
BEGIN
    IF NEW.attendance_percentage IS NOT NULL AND NEW.attendance_percentage < 75.00 THEN
        SET NEW.grade = 'XF';
    END IF;
END$$

CREATE TRIGGER trg_best_test_score
AFTER INSERT ON test_attempt
FOR EACH ROW
BEGIN
    UPDATE applicant
       SET best_test_score = NEW.score
     WHERE applicant_id = NEW.applicant_id
       AND NEW.score > best_test_score;
END$$

DELIMITER ;

-- =============================================================================
-- 2. SAMPLE DATA - INSERT STATEMENTS
-- =============================================================================

-- school
INSERT INTO school VALUES
('SEECS','School of Electrical Engineering and Computer Science','SEECS',2008),
('NBS','NUST Business School','NBS',2005),
('SADA','School of Art Design and Architecture','SADA',2010),
('SMME','School of Mechanical and Manufacturing Engineering','SMME',2008),
('SCEE','School of Civil and Environmental Engineering','SCEE',2008),
('SNS','School of Natural Sciences','SNS',2004),
('S3H','School of Social Sciences and Humanities','S3H',2011),
('NICE','NUST Institute of Civil Engineering','NICE',2000),
('NSTP','NUST Science and Technology Park','NSTP',2016),
('ASAP','Atta-ur-Rahman School of Applied Biosciences','ASAB',2006);

-- faculty
INSERT INTO faculty VALUES
('F001','SEECS','Dr. Muhammad Usman Ilyas','usman.ilyas@seecs.nust.edu.pk','Associate Professor'),
('F002','SEECS','Dr. Ayesha Khan','ayesha.khan@seecs.nust.edu.pk','Assistant Professor'),
('F003','NBS','Dr. Naukhez Sarwar','naukhez@nbs.nust.edu.pk','Professor'),
('F004','SADA','Ar. Sana Tariq','sana.tariq@sada.nust.edu.pk','Assistant Professor'),
('F005','SMME','Dr. Zaheer Abbas','zaheer@smme.nust.edu.pk','Associate Professor'),
('F006','SCEE','Dr. Hassan Raza','hassan.raza@scee.nust.edu.pk','Professor'),
('F007','SNS','Dr. Fatima Zehra','fatima.zehra@sns.nust.edu.pk','Assistant Professor'),
('F008','S3H','Dr. Imran Saeed','imran.saeed@s3h.nust.edu.pk','Associate Professor'),
('F009','SEECS','Dr. Bilal Ahmed','bilal.ahmed@seecs.nust.edu.pk','Lecturer'),
('F010','ASAP','Dr. Nida Javaid','nida.javaid@asab.nust.edu.pk','Assistant Professor');

-- program
INSERT INTO program VALUES
('BSCS','SEECS','BS Computer Science','BS',8,133,120),
('BSSE','SEECS','BS Software Engineering','BS',8,136,80),
('BEEE','SEECS','BE Electrical Engineering','BE',8,136,100),
('BEME','SMME','BE Mechanical Engineering','BE',8,136,90),
('BECE','SCEE','BE Civil Engineering','BE',8,140,80),
('BBA','NBS','Bachelor of Business Administration','BBA',8,130,120),
('BSMATH','SNS','BS Mathematics','BS',8,130,60),
('BARCH','SADA','Bachelor of Architecture','B.Arch',10,165,40),
('LLB','S3H','Bachelor of Laws','LLB',10,160,50),
('BSBI','ASAP','BS Biotechnology','BS',8,133,50);

-- course
INSERT INTO course VALUES
('CS110','SEECS','Programming Fundamentals','Lab',3,9),
('CS211','SEECS','Object Oriented Programming','Lab',3,9),
('CS212','SEECS','Data Structures and Algorithms','Theory',3,3),
('CS351','SEECS','Database Systems','Theory',3,3),
('MT101','SNS','Calculus and Analytical Geometry','Theory',3,3),
('MT102','SNS','Calculus II','Theory',3,3),
('EE201','SEECS','Circuit Analysis','Theory',4,4),
('ME211','SMME','Engineering Mechanics','Theory',3,3),
('HU100','S3H','English Comprehension','Theory',2,2),
('CS499','SEECS','Final Year Project','Project',3,9);

-- prerequisite
INSERT INTO prerequisite VALUES
('CS211','CS110'),
('CS212','CS211'),
('CS351','CS212'),
('MT102','MT101'),
('EE201','MT101'),
('ME211','MT101'),
('CS499','CS351'),
('CS499','CS212'),
('CS351','MT102'),
('CS211','MT101');

-- program_course
INSERT INTO program_course VALUES
('BSCS','CS110',1,TRUE),
('BSCS','MT101',1,TRUE),
('BSCS','HU100',1,TRUE),
('BSCS','CS211',2,TRUE),
('BSCS','MT102',2,TRUE),
('BSCS','CS212',3,TRUE),
('BSCS','CS351',5,TRUE),
('BSCS','CS499',8,TRUE),
('BSSE','CS110',1,TRUE),
('BEEE','EE201',2,TRUE);

-- term
INSERT INTO term VALUES
('T-F22','Fall',2022,'2022-09-01','2023-01-15'),
('T-S23','Spring',2023,'2023-02-01','2023-06-15'),
('T-F23','Fall',2023,'2023-09-01','2024-01-15'),
('T-S24','Spring',2024,'2024-02-01','2024-06-15'),
('T-F24','Fall',2024,'2024-09-01','2025-01-15'),
('T-S25','Spring',2025,'2025-02-01','2025-06-15'),
('T-F25','Fall',2025,'2025-09-01','2026-01-15'),
('T-S26','Spring',2026,'2026-02-01','2026-06-15'),
('T-F26','Fall',2026,'2026-09-01','2027-01-15'),
('T-S27','Spring',2027,'2027-02-01','2027-06-15');

-- classroom
INSERT INTO classroom VALUES
('CR-A01','SEECS Block A','A-101',60),
('CR-A02','SEECS Block A','A-102',60),
('CR-B01','SEECS Block B','B-201',40),
('CR-LAB1','SEECS Block A','Lab-1',30),
('CR-LAB2','SEECS Block A','Lab-2',30),
('CR-NBS1','NBS Building','NBS-G01',80),
('CR-SNS1','SNS Building','SNS-101',50),
('CR-SMM1','SMME Block','SMME-201',45),
('CR-CEE1','SCEE Block','CEE-101',55),
('CR-ARCH','SADA Studio','STD-1',25);

-- applicant
INSERT INTO applicant VALUES
('AP001','Ali Raza','35202-1234567-1','ali.raza@gmail.com','FBISE',92.50,0),
('AP002','Sara Ahmed','42101-7654321-2','sara.ahmed@gmail.com','Punjab',88.00,0),
('AP003','Hamza Shah','17301-9876543-3','hamza.shah@gmail.com','KPK',85.75,0),
('AP004','Zainab Bhatti','41301-1122334-4','zainab.b@gmail.com','Sindh',90.20,0),
('AP005','Usman Tariq','35201-5566778-5','usman.tariq@gmail.com','FBISE',78.40,0),
('AP006','Maryam Noor','42201-9988776-6','maryam.noor@gmail.com','AKU-EB',94.10,0),
('AP007','Bilal Khan','17201-3344556-7','bilal.k@gmail.com','KPK',82.00,0),
('AP008','Fatima Arshad','35202-4455667-8','fatima.a@gmail.com','Cambridge',89.50,0),
('AP009','Ahmad Zia','54201-7788990-9','ahmad.zia@gmail.com','Balochistan',76.30,0),
('AP010','Hira Siddiqui','42301-1212121-0','hira.s@gmail.com','Sindh',91.00,0);

-- student (AP006 becomes student S002 via offer acceptance)
INSERT INTO student VALUES
('S001','BSCS',NULL,'Omer Farooq','omer.farooq@seecs.nust.edu.pk',5,'2022-09-01'),
('S002','BSCS','AP006','Maryam Noor','maryam.noor@seecs.nust.edu.pk',1,'2026-09-01'),
('S003','BSCS',NULL,'Hassan Javed','hassan.javed@seecs.nust.edu.pk',4,'2023-09-01'),
('S004','BSSE',NULL,'Laiba Khan','laiba.khan@seecs.nust.edu.pk',3,'2024-09-01'),
('S005','BEEE',NULL,'Talha Mahmood','talha.m@seecs.nust.edu.pk',6,'2022-09-01'),
('S006','BEME',NULL,'Rizwan Ali','rizwan.ali@smme.nust.edu.pk',2,'2024-09-01'),
('S007','BBA',NULL,'Anum Shehzad','anum.s@nbs.nust.edu.pk',7,'2021-09-01'),
('S008','BARCH',NULL,'Mehreen Raza','mehreen.r@sada.nust.edu.pk',4,'2023-09-01'),
('S009','LLB',NULL,'Saad Butt','saad.butt@s3h.nust.edu.pk',2,'2024-09-01'),
('S010','BSMATH',NULL,'Aiman Javed','aiman.j@sns.nust.edu.pk',3,'2024-09-01');

-- section
INSERT INTO section VALUES
('SEC001','CS110','T-F23','CR-LAB1','F001','A'),
('SEC002','MT101','T-F23','CR-A01','F007','A'),
('SEC003','CS211','T-S24','CR-LAB2','F002','A'),
('SEC004','MT102','T-S24','CR-A01','F007','A'),
('SEC005','CS212','T-F24','CR-A02','F009','A'),
('SEC006','CS351','T-F25','CR-B01','F001','A'),
('SEC007','HU100','T-F23','CR-A01','F008','A'),
('SEC008','EE201','T-S25','CR-A02','F002','A'),
('SEC009','ME211','T-F24','CR-SMM1','F005','A'),
('SEC010','CS499','T-F25','CR-LAB1','F001','A');

-- enrollment (S001 takes CS110->CS211->CS212 across terms; one XF; one NULL; one W)
INSERT INTO enrollment VALUES
('S001','SEC001',92.00,'A'),
('S001','SEC002',88.00,'B+'),
('S001','SEC007',95.00,'A'),
('S001','SEC003',85.00,'B+'),
('S001','SEC004',80.00,'B'),
('S001','SEC005',82.00,'B+'),
('S001','SEC006',90.00,NULL),      -- in progress
('S003','SEC001',70.00,'XF'),      -- attendance < 75
('S004','SEC003',78.00,'W'),
('S005','SEC008',86.00,'A');

-- entry_test
INSERT INTO entry_test VALUES
('ET001','NET-1','2025-12-15',200),
('ET002','NET-2','2026-02-20',200),
('ET003','NET-3','2026-04-10',200),
('ET004','NET-4','2026-06-15',200),
('ET005','NET-1','2024-12-10',200),
('ET006','NET-2','2025-02-18',200),
('ET007','NET-3','2025-04-12',200),
('ET008','NET-4','2025-06-20',200),
('ET009','NET-1','2023-12-12',200),
('ET010','NET-2','2024-02-22',200);

-- test_attempt (triggers will update applicant.best_test_score)
INSERT INTO test_attempt VALUES
('AP001','ET001',165.50),
('AP001','ET002',172.00),
('AP002','ET001',150.00),
('AP003','ET002',142.75),
('AP004','ET003',178.25),
('AP005','ET001',120.00),
('AP006','ET001',185.50),
('AP006','ET002',190.00),
('AP007','ET003',155.00),
('AP008','ET004',168.00);

-- application (snapshot HS + best-test from time of submission)
INSERT INTO application VALUES
('APL001','AP001','BSCS','T-F26',92.50,172.00,264.50,'2026-07-10','Offered'),
('APL002','AP002','BSCS','T-F26',88.00,150.00,238.00,'2026-07-12','Rejected'),
('APL003','AP003','BSSE','T-F26',85.75,142.75,228.50,'2026-07-14','Rejected'),
('APL004','AP004','BEEE','T-F26',90.20,178.25,268.45,'2026-07-11','Offered'),
('APL005','AP005','BBA','T-F26',78.40,120.00,198.40,'2026-07-13','Withdrawn'),
('APL006','AP006','BSCS','T-F26',94.10,190.00,284.10,'2026-07-09','Accepted'),
('APL007','AP007','BEME','T-F26',82.00,155.00,237.00,'2026-07-15','Offered'),
('APL008','AP008','BARCH','T-F26',89.50,168.00,257.50,'2026-07-16','Offered'),
('APL009','AP006','BSSE','T-F26',94.10,190.00,284.10,'2026-07-09','Offered'),
('APL010','AP010','BSMATH','T-F26',91.00,0.00,91.00,'2026-07-20','Submitted');

-- offer
INSERT INTO offer VALUES
('OFR001','APL001','2026-08-01','2026-08-20','Pending'),
('OFR002','APL004','2026-08-01','2026-08-20','Pending'),
('OFR003','APL006','2026-08-01','2026-08-20','Accepted'),
('OFR004','APL007','2026-08-01','2026-08-20','Declined'),
('OFR005','APL008','2026-08-01','2026-08-20','Pending'),
('OFR006','APL009','2026-08-01','2026-08-20','Declined'),
('OFR007','APL002','2026-08-01','2026-08-05','Expired'),
('OFR008','APL003','2026-08-01','2026-08-05','Expired'),
('OFR009','APL005','2026-08-01','2026-08-05','Expired'),
('OFR010','APL010','2026-08-01','2026-08-20','Pending');

-- =============================================================================
-- 3. USEFUL QUERIES
-- =============================================================================

-- Q1: Student transcript (all enrollments for S001, ordered by term)
-- SELECT s.student_id, c.course_code, c.course_title, c.credit_hours,
--        e.grade, t.term_name, t.academic_year,
--        CASE e.grade WHEN 'A' THEN 4.0 WHEN 'B+' THEN 3.5 WHEN 'B' THEN 3.0
--                     WHEN 'C+' THEN 2.5 WHEN 'C' THEN 2.0 WHEN 'D+' THEN 1.5
--                     WHEN 'D' THEN 1.0 WHEN 'F' THEN 0.0 WHEN 'XF' THEN 0.0
--                     ELSE NULL END AS gpa_points
-- FROM enrollment e
-- JOIN student s   ON s.student_id = e.student_id
-- JOIN section  se ON se.section_id = e.section_id
-- JOIN course   c  ON c.course_code = se.course_code
-- JOIN term     t  ON t.term_id = se.term_id
-- WHERE s.student_id = 'S001'
-- ORDER BY t.academic_year, t.term_name;

-- Q2: Semester GPA for a student in a given term
-- SELECT s.student_id, se.term_id,
--        ROUND(SUM(c.credit_hours *
--              CASE e.grade WHEN 'A' THEN 4.0 WHEN 'B+' THEN 3.5 WHEN 'B' THEN 3.0
--                           WHEN 'C+' THEN 2.5 WHEN 'C' THEN 2.0 WHEN 'D+' THEN 1.5
--                           WHEN 'D' THEN 1.0 WHEN 'F' THEN 0.0 WHEN 'XF' THEN 0.0 END)
--              / SUM(c.credit_hours), 2) AS gpa
-- FROM enrollment e
-- JOIN student s  ON s.student_id = e.student_id
-- JOIN section se ON se.section_id = e.section_id
-- JOIN course c   ON c.course_code = se.course_code
-- WHERE s.student_id = 'S001' AND se.term_id = 'T-F23'
--   AND e.grade IS NOT NULL AND e.grade NOT IN ('I','W')
-- GROUP BY s.student_id, se.term_id;

-- Q3: Cumulative GPA (CGPA)
-- SELECT e.student_id,
--        ROUND(SUM(c.credit_hours *
--              CASE e.grade WHEN 'A' THEN 4.0 WHEN 'B+' THEN 3.5 WHEN 'B' THEN 3.0
--                           WHEN 'C+' THEN 2.5 WHEN 'C' THEN 2.0 WHEN 'D+' THEN 1.5
--                           WHEN 'D' THEN 1.0 WHEN 'F' THEN 0.0 WHEN 'XF' THEN 0.0 END)
--              / SUM(c.credit_hours), 2) AS cgpa
-- FROM enrollment e
-- JOIN section se ON se.section_id = e.section_id
-- JOIN course c   ON c.course_code = se.course_code
-- WHERE e.grade IS NOT NULL AND e.grade NOT IN ('I','W')
-- GROUP BY e.student_id;

-- Q4: Courses recommended for a student's current semester
-- SELECT s.student_id, s.full_name, s.current_semester,
--        pc.course_code, c.course_title
-- FROM student s
-- JOIN program_course pc ON pc.program_id = s.program_id
-- JOIN course c          ON c.course_code = pc.course_code
-- WHERE s.student_id = 'S001' AND pc.recommended_semester = s.current_semester;

-- Q5: Prerequisite check for student S001 taking course CS351
-- SELECT p.prereq_course_code,
--        MAX(CASE WHEN e.grade IS NOT NULL
--                  AND e.grade NOT IN ('F','XF','I','W') THEN 1 ELSE 0 END) AS passed
-- FROM prerequisite p
-- LEFT JOIN section se  ON se.course_code = p.prereq_course_code
-- LEFT JOIN enrollment e ON e.section_id = se.section_id AND e.student_id = 'S001'
-- WHERE p.course_code = 'CS351'
-- GROUP BY p.prereq_course_code;

-- Q6: Merit list for program BSCS in Fall 2026
-- SELECT program_id, application_id, applicant_id, aggregate_score,
--        RANK() OVER (PARTITION BY program_id ORDER BY aggregate_score DESC) AS merit_rank
-- FROM application
-- WHERE term_id = 'T-F26' AND program_id = 'BSCS' AND status <> 'Withdrawn';

-- Q7: Faculty workload for Fall 2024
-- SELECT f.faculty_id, f.full_name,
--        COUNT(se.section_id) AS sections_taught,
--        SUM(c.contact_hours) AS total_contact_hours
-- FROM faculty f
-- LEFT JOIN section se ON se.faculty_id = f.faculty_id AND se.term_id = 'T-F24'
-- LEFT JOIN course c   ON c.course_code = se.course_code
-- GROUP BY f.faculty_id, f.full_name;

-- Q8: Section enrollment vs classroom capacity for a term
-- SELECT se.section_id, c.course_code, cr.capacity,
--        COUNT(e.student_id) AS enrolled,
--        (cr.capacity - COUNT(e.student_id)) AS seats_left
-- FROM section se
-- JOIN classroom cr  ON cr.classroom_id = se.classroom_id
-- JOIN course c      ON c.course_code = se.course_code
-- LEFT JOIN enrollment e ON e.section_id = se.section_id
-- WHERE se.term_id = 'T-F24'
-- GROUP BY se.section_id, c.course_code, cr.capacity;

-- Q9: Applicant offer summary for AP006
-- SELECT a.applicant_id, a.full_name, o.offer_id, o.status,
--        app.program_id, app.aggregate_score
-- FROM applicant a
-- JOIN application app ON app.applicant_id = a.applicant_id
-- JOIN offer o         ON o.application_id = app.application_id
-- WHERE a.applicant_id = 'AP006';

-- Q10: Students at risk (attendance < 80% in current term)
-- SELECT e.student_id, s.full_name, se.section_id, c.course_code,
--        e.attendance_percentage
-- FROM enrollment e
-- JOIN student s   ON s.student_id = e.student_id
-- JOIN section se  ON se.section_id = e.section_id
-- JOIN course c    ON c.course_code = se.course_code
-- WHERE se.term_id = 'T-F25' AND e.attendance_percentage < 80.00;

-- Q11: Semester derivation cross-check (distinct terms a student has enrolled in)
-- SELECT e.student_id, COUNT(DISTINCT se.term_id) AS terms_enrolled,
--        s.current_semester AS stored_semester
-- FROM enrollment e
-- JOIN section se ON se.section_id = e.section_id
-- JOIN student s  ON s.student_id = e.student_id
-- GROUP BY e.student_id, s.current_semester;
