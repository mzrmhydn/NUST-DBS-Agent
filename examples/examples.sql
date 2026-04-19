-- =============================================================================
-- NUST University Database - Example Queries
-- =============================================================================
-- Mirrors the few-shot examples in examples.json. Demonstrates the common
-- query patterns over the admissions + academic pipelines using the
-- normalized schema (Student is 1:1 with Application; Course is owned by
-- School and linked to Program via the M:N ProgramCourse junction; all
-- fees flow through the unified Fee table, typed by FeeType).

/*
Which program received the most applications?
*/
SELECT
    Program.ProgramName,
    COUNT(Application.ApplicationID) AS application_count
FROM Application
INNER JOIN Program ON Program.ProgramID = Application.ProgramID
GROUP BY Application.ProgramID
ORDER BY application_count DESC
LIMIT 5;

/*
What is the average NET score per entry test series?
*/
SELECT
    EntryTest.SeriesName,
    AVG(TestScore.Score) AS avg_score
FROM TestScore
INNER JOIN EntryTest ON EntryTest.TestID = TestScore.TestID
GROUP BY TestScore.TestID
ORDER BY avg_score DESC;

/*
List all applicants who were selected for BSCS.
*/
SELECT
    Applicant.FirstName || ' ' || Applicant.LastName AS applicant_name
FROM Applicant
INNER JOIN Application ON Application.ApplicantID = Applicant.ApplicantID
INNER JOIN Program     ON Program.ProgramID       = Application.ProgramID
WHERE Program.DegreeType = 'BSCS'
  AND Application.Status IN ('Selected','Enrolled');

/*
How many students are enrolled in each program?
(Student -> Application -> Program; Student has no direct ProgramID.)
*/
SELECT
    Program.ProgramName,
    COUNT(Student.StudentID) AS student_count
FROM Student
INNER JOIN Application ON Application.ApplicationID = Student.ApplicationID
INNER JOIN Program     ON Program.ProgramID         = Application.ProgramID
GROUP BY Program.ProgramID
ORDER BY student_count DESC;

/*
What is the top 5 highest NET scores of all time?
*/
SELECT
    Applicant.FirstName || ' ' || Applicant.LastName AS applicant_name,
    EntryTest.SeriesName,
    TestScore.Score
FROM TestScore
INNER JOIN Applicant ON Applicant.ApplicantID = TestScore.ApplicantID
INNER JOIN EntryTest ON EntryTest.TestID      = TestScore.TestID
ORDER BY TestScore.Score DESC
LIMIT 5;

/*
How many waitlisted applicants scored above 140 in the NET?
*/
SELECT COUNT(DISTINCT Applicant.ApplicantID) AS waitlisted_high_scorers
FROM Applicant
INNER JOIN Application ON Application.ApplicantID = Applicant.ApplicantID
WHERE Application.Status = 'Waitlisted'
  AND Applicant.ApplicantID IN (
      SELECT TestScore.ApplicantID
      FROM TestScore
      WHERE TestScore.Score > 140
  );

/*
Which school generated the most tuition revenue?
(Fee -> Student -> Application -> Program -> School; filter FeeType='Tuition'.)
*/
SELECT
    School.Name AS school_name,
    SUM(Fee.Amount) AS total_tuition
FROM Fee
INNER JOIN Student     ON Student.StudentID         = Fee.StudentID
INNER JOIN Application ON Application.ApplicationID = Student.ApplicationID
INNER JOIN Program     ON Program.ProgramID         = Application.ProgramID
INNER JOIN School      ON School.SchoolID           = Program.SchoolID
WHERE Fee.FeeType = 'Tuition'
GROUP BY School.SchoolID
ORDER BY total_tuition DESC
LIMIT 5;

/*
List all courses offered by the SEECS school.
(Course is owned by School directly, no join through Program.)
*/
SELECT
    Course.CourseCode,
    Course.CourseName,
    Course.Credits
FROM Course
INNER JOIN School ON School.SchoolID = Course.SchoolID
WHERE School.Name = 'SEECS';

/*
Which courses are shared across multiple programs?
(ProgramCourse junction demonstrates the M:N relationship.)
*/
SELECT
    Course.CourseCode,
    Course.CourseName,
    COUNT(ProgramCourse.ProgramID) AS num_programs
FROM Course
INNER JOIN ProgramCourse ON ProgramCourse.CourseID = Course.CourseID
GROUP BY Course.CourseID
HAVING num_programs > 1
ORDER BY num_programs DESC;

/*
Which instructor is teaching the most sections in Fall 2026?
*/
SELECT
    Instructor.FirstName || ' ' || Instructor.LastName AS instructor_name,
    COUNT(Section.SectionID) AS section_count
FROM Section
INNER JOIN Instructor ON Instructor.InstructorID = Section.InstructorID
INNER JOIN Term       ON Term.TermID             = Section.TermID
WHERE Term.TermName = 'Fall 2026'
GROUP BY Section.InstructorID
ORDER BY section_count DESC
LIMIT 5;

/*
List the full transcript (course, term, grade, status) for student Ali Khan.
(Student -> Application -> Applicant for identity.)
*/
SELECT
    Course.CourseCode,
    Course.CourseName,
    Term.TermName,
    Enrollment.Grade,
    Enrollment.Status
FROM Enrollment
INNER JOIN Student     ON Student.StudentID         = Enrollment.StudentID
INNER JOIN Application ON Application.ApplicationID = Student.ApplicationID
INNER JOIN Applicant   ON Applicant.ApplicantID     = Application.ApplicantID
INNER JOIN Section     ON Section.SectionID         = Enrollment.SectionID
INNER JOIN Course      ON Course.CourseID           = Section.CourseID
INNER JOIN Term        ON Term.TermID               = Section.TermID
WHERE Applicant.FirstName = 'Ali'
  AND Applicant.LastName  = 'Khan'
ORDER BY Term.StartDate;

/*
How many students are currently enrolled in 'Database Systems'?
*/
SELECT COUNT(Enrollment.EnrollmentID) AS enrollment_count
FROM Enrollment
INNER JOIN Section ON Section.SectionID = Enrollment.SectionID
INNER JOIN Course  ON Course.CourseID   = Section.CourseID
WHERE Course.CourseName = 'Database Systems';

/*
Which applicants scored above the average score of the test series they took?
*/
SELECT
    Applicant.FirstName || ' ' || Applicant.LastName AS applicant_name,
    EntryTest.SeriesName,
    TestScore.Score
FROM TestScore
INNER JOIN Applicant ON Applicant.ApplicantID = TestScore.ApplicantID
INNER JOIN EntryTest ON EntryTest.TestID      = TestScore.TestID
WHERE TestScore.Score > (
    SELECT AVG(ts2.Score) FROM TestScore ts2 WHERE ts2.TestID = TestScore.TestID
);

/*
What is the conversion rate (applicants to students) for each school?
*/
SELECT
    School.Name AS school_name,
    COUNT(DISTINCT Application.ApplicantID) AS total_applicants,
    COUNT(DISTINCT Student.StudentID)       AS converted_students
FROM School
INNER JOIN Program     ON Program.SchoolID        = School.SchoolID
LEFT  JOIN Application ON Application.ProgramID   = Program.ProgramID
LEFT  JOIN Student     ON Student.ApplicationID   = Application.ApplicationID
GROUP BY School.SchoolID;

/*
Show students with CGPA above 3.5.
*/
SELECT
    Applicant.FirstName || ' ' || Applicant.LastName AS student_name,
    Program.ProgramName,
    Student.CGPA
FROM Student
INNER JOIN Application ON Application.ApplicationID = Student.ApplicationID
INNER JOIN Applicant   ON Applicant.ApplicantID     = Application.ApplicantID
INNER JOIN Program     ON Program.ProgramID         = Application.ProgramID
WHERE Student.CGPA > 3.5
ORDER BY Student.CGPA DESC;

/*
Which courses have no sections offered in Fall 2026?
*/
SELECT
    Course.CourseCode,
    Course.CourseName
FROM Course
LEFT JOIN Section ON Section.CourseID = Course.CourseID
   AND Section.TermID = (SELECT Term.TermID FROM Term WHERE Term.TermName = 'Fall 2026')
WHERE Section.SectionID IS NULL;

/*
How much total application fee revenue came from the 2026 intake?
(Unified Fee table; restrict to FeeType='Application'.)
*/
SELECT SUM(Fee.Amount) AS total_fees
FROM Fee
WHERE Fee.FeeType = 'Application'
  AND strftime('%Y', Fee.PaymentDate) = '2026';

/*
Which core courses does the BSCS program require in its first two semesters?
(Program <-> Course M:N via ProgramCourse.)
*/
SELECT
    Course.CourseCode,
    Course.CourseName,
    ProgramCourse.Semester
FROM ProgramCourse
INNER JOIN Course  ON Course.CourseID  = ProgramCourse.CourseID
INNER JOIN Program ON Program.ProgramID = ProgramCourse.ProgramID
WHERE Program.DegreeType = 'BSCS'
  AND ProgramCourse.CourseType = 'Core'
  AND ProgramCourse.Semester <= 2
ORDER BY ProgramCourse.Semester;
