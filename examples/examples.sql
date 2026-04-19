-- =============================================================================
-- NUST University Database - Example Queries (MySQL 8.0+)
-- =============================================================================
-- Mirrors the few-shot examples in examples.json. Targets the normalized
-- schema in db/NUST.sql:
--   * Admissions : applicant -> test_attempt -> entry_test,
--                  applicant -> application  -> program / term,
--                  application -> offer
--   * Academic   : school -> program -> student,
--                  school -> course, program <-> course via program_course,
--                  term + classroom + faculty + course -> section,
--                  student <-> section via enrollment (grade + attendance).
-- All identifiers are lowercase snake_case. term_name is an ENUM('Fall',
-- 'Spring','Summer'); filter on term_name AND academic_year to pin a term.

/*
Which program received the most applications?
*/
SELECT
    program.program_name,
    COUNT(application.application_id) AS application_count
FROM application
INNER JOIN program ON program.program_id = application.program_id
GROUP BY application.program_id
ORDER BY application_count DESC
LIMIT 5;

/*
What is the average NET score per test type?
*/
SELECT
    entry_test.test_type,
    AVG(test_attempt.score) AS avg_score
FROM test_attempt
INNER JOIN entry_test ON entry_test.test_id = test_attempt.test_id
GROUP BY entry_test.test_type
ORDER BY avg_score DESC;

/*
List all applicants who were offered admission to BS Computer Science.
*/
SELECT applicant.full_name
FROM applicant
INNER JOIN application ON application.applicant_id = applicant.applicant_id
INNER JOIN program     ON program.program_id       = application.program_id
WHERE program.program_id = 'BSCS'
  AND application.status IN ('Offered','Accepted');

/*
How many students are enrolled in each program?
(student.program_id is a direct FK on student, no join through application needed.)
*/
SELECT
    program.program_name,
    COUNT(student.student_id) AS student_count
FROM student
INNER JOIN program ON program.program_id = student.program_id
GROUP BY student.program_id
ORDER BY student_count DESC;

/*
What are the top 5 highest NET scores of all time?
*/
SELECT
    applicant.full_name,
    entry_test.test_type,
    test_attempt.score
FROM test_attempt
INNER JOIN applicant  ON applicant.applicant_id = test_attempt.applicant_id
INNER JOIN entry_test ON entry_test.test_id     = test_attempt.test_id
ORDER BY test_attempt.score DESC
LIMIT 5;

/*
How many rejected applicants scored above 140 in the NET?
*/
SELECT COUNT(DISTINCT applicant.applicant_id) AS rejected_high_scorers
FROM applicant
INNER JOIN application ON application.applicant_id = applicant.applicant_id
WHERE application.status = 'Rejected'
  AND applicant.applicant_id IN (
      SELECT test_attempt.applicant_id
      FROM test_attempt
      WHERE test_attempt.score > 140
  );

/*
Which school owns the most courses?
(Course is owned by School directly via course.school_id.)
*/
SELECT
    school.school_name,
    COUNT(course.course_code) AS course_count
FROM school
INNER JOIN course ON course.school_id = school.school_id
GROUP BY school.school_id
ORDER BY course_count DESC
LIMIT 5;

/*
List all courses offered by SEECS.
*/
SELECT
    course.course_code,
    course.course_title,
    course.credit_hours
FROM course
INNER JOIN school ON school.school_id = course.school_id
WHERE school.abbreviation = 'SEECS';

/*
Which courses are shared across multiple programs?
(program_course junction demonstrates the M:N relationship.)
*/
SELECT
    course.course_code,
    course.course_title,
    COUNT(program_course.program_id) AS num_programs
FROM course
INNER JOIN program_course ON program_course.course_code = course.course_code
GROUP BY course.course_code
HAVING num_programs > 1
ORDER BY num_programs DESC;

/*
Which faculty member is teaching the most sections in Fall 2025?
*/
SELECT
    faculty.full_name,
    COUNT(section.section_id) AS section_count
FROM section
INNER JOIN faculty ON faculty.faculty_id = section.faculty_id
INNER JOIN term    ON term.term_id       = section.term_id
WHERE term.term_name = 'Fall' AND term.academic_year = 2025
GROUP BY section.faculty_id
ORDER BY section_count DESC
LIMIT 5;

/*
Full transcript (course, term, grade, attendance) for student S001.
*/
SELECT
    course.course_code,
    course.course_title,
    term.term_name,
    term.academic_year,
    enrollment.grade,
    enrollment.attendance_percentage
FROM enrollment
INNER JOIN section ON section.section_id = enrollment.section_id
INNER JOIN course  ON course.course_code = section.course_code
INNER JOIN term    ON term.term_id       = section.term_id
WHERE enrollment.student_id = 'S001'
ORDER BY term.start_date;

/*
How many students are currently enrolled in 'Database Systems'?
*/
SELECT COUNT(*) AS enrollment_count
FROM enrollment
INNER JOIN section ON section.section_id = enrollment.section_id
INNER JOIN course  ON course.course_code = section.course_code
WHERE course.course_title = 'Database Systems';

/*
Which applicants scored above the average score of the test they took?
*/
SELECT
    applicant.full_name,
    entry_test.test_type,
    test_attempt.score
FROM test_attempt
INNER JOIN applicant  ON applicant.applicant_id = test_attempt.applicant_id
INNER JOIN entry_test ON entry_test.test_id     = test_attempt.test_id
WHERE test_attempt.score > (
    SELECT AVG(ta2.score)
    FROM test_attempt ta2
    WHERE ta2.test_id = test_attempt.test_id
);

/*
What is the conversion rate (applications -> students) for each school?
(A student is linked back to applicant via student.applicant_id; matching on
program_id as well keeps the pairing program-accurate.)
*/
SELECT
    school.school_name,
    COUNT(DISTINCT application.applicant_id) AS total_applicants,
    COUNT(DISTINCT student.student_id)       AS converted_students
FROM school
INNER JOIN program         ON program.school_id      = school.school_id
LEFT  JOIN application     ON application.program_id = program.program_id
LEFT  JOIN student         ON student.applicant_id   = application.applicant_id
                           AND student.program_id    = program.program_id
GROUP BY school.school_id;

/*
Show all students with CGPA above 3.5.
(GPA is computed from enrollment.grade via a CASE map; I/W/NULL are excluded.)
*/
SELECT
    student.student_id,
    student.full_name,
    program.program_name,
    ROUND(
        SUM(course.credit_hours *
            CASE enrollment.grade
                WHEN 'A'  THEN 4.0 WHEN 'B+' THEN 3.5 WHEN 'B' THEN 3.0
                WHEN 'C+' THEN 2.5 WHEN 'C'  THEN 2.0 WHEN 'D+' THEN 1.5
                WHEN 'D'  THEN 1.0 WHEN 'F'  THEN 0.0 WHEN 'XF' THEN 0.0
            END)
        / SUM(course.credit_hours), 2
    ) AS cgpa
FROM enrollment
INNER JOIN section ON section.section_id = enrollment.section_id
INNER JOIN course  ON course.course_code = section.course_code
INNER JOIN student ON student.student_id = enrollment.student_id
INNER JOIN program ON program.program_id = student.program_id
WHERE enrollment.grade IS NOT NULL
  AND enrollment.grade NOT IN ('I','W')
GROUP BY student.student_id, student.full_name, program.program_name
HAVING cgpa > 3.5
ORDER BY cgpa DESC;

/*
Which classrooms are over-utilized (hosting more than 2 sections)?
*/
SELECT
    classroom.building,
    classroom.room_number,
    COUNT(section.section_id) AS sections_hosted
FROM classroom
LEFT JOIN section ON section.classroom_id = classroom.classroom_id
GROUP BY classroom.classroom_id
HAVING sections_hosted > 2
ORDER BY sections_hosted DESC;

/*
List all applicants from the Sindh board.
*/
SELECT
    applicant.full_name,
    applicant.email
FROM applicant
WHERE applicant.high_school_board = 'Sindh';

/*
Which courses have no sections offered in Fall 2025?
*/
SELECT
    course.course_code,
    course.course_title
FROM course
LEFT JOIN section ON section.course_code = course.course_code
   AND section.term_id = (
       SELECT term.term_id
       FROM term
       WHERE term.term_name = 'Fall' AND term.academic_year = 2025
   )
WHERE section.section_id IS NULL;

/*
Which core courses does the BSCS program require in its first two semesters?
(program <-> course M:N via program_course; recommended_semester pins the term.)
*/
SELECT
    course.course_code,
    course.course_title,
    program_course.recommended_semester
FROM program_course
INNER JOIN course ON course.course_code = program_course.course_code
WHERE program_course.program_id = 'BSCS'
  AND program_course.is_core = TRUE
  AND program_course.recommended_semester <= 2
ORDER BY program_course.recommended_semester;

/*
Merit list: rank all applicants for BSCS in Fall 2026 by aggregate score.
*/
SELECT
    application.application_id,
    applicant.full_name,
    application.aggregate_score,
    RANK() OVER (ORDER BY application.aggregate_score DESC) AS merit_rank
FROM application
INNER JOIN applicant ON applicant.applicant_id = application.applicant_id
WHERE application.program_id = 'BSCS'
  AND application.term_id    = 'T-F26'
  AND application.status    <> 'Withdrawn';

/*
Which students are at risk of XF due to attendance below 80%?
(A BEFORE UPDATE trigger auto-assigns XF once attendance drops under 75%;
this query is the early-warning view.)
*/
SELECT
    student.student_id,
    student.full_name,
    course.course_code,
    enrollment.attendance_percentage
FROM enrollment
INNER JOIN student ON student.student_id = enrollment.student_id
INNER JOIN section ON section.section_id = enrollment.section_id
INNER JOIN course  ON course.course_code = section.course_code
WHERE enrollment.attendance_percentage < 80.00
ORDER BY enrollment.attendance_percentage ASC;

/*
Show all offers (and their statuses) for applicant AP006.
*/
SELECT
    offer.offer_id,
    application.program_id,
    application.aggregate_score,
    offer.status,
    offer.expiry_date
FROM offer
INNER JOIN application ON application.application_id = offer.application_id
WHERE application.applicant_id = 'AP006';
