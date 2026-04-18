# Phase 3: Implementation & Queries

This document contains the functional implementation of the Phase 3 requirements on the normalized NUST database. All queries are written in **SQLite** (the concrete dialect used by the backing `db/NUST.db`). Views, triggers, and indexes are created inside [db/NUST.sql](db/NUST.sql).

## 1. 10+ Complex SQL Queries

### Query 1: Full Student Transcript View (Joins & Views)
*A view that unifies a student's academic record with their program. Because `Student` carries only `ApplicationID`, applicant identity and program are reached through `Application`.*
```sql
CREATE VIEW StudentTranscript AS
SELECT
    s.StudentID,
    ap.FirstName,
    ap.LastName,
    pr.ProgramName,
    c.CourseCode,
    c.CourseName,
    t.TermName,
    e.Grade,
    e.Status AS EnrollmentStatus
FROM Student     s
JOIN Application app ON app.ApplicationID = s.ApplicationID
JOIN Applicant   ap  ON ap.ApplicantID    = app.ApplicantID
JOIN Program     pr  ON pr.ProgramID      = app.ProgramID
JOIN Enrollment  e   ON e.StudentID       = s.StudentID
JOIN Section     sec ON sec.SectionID     = e.SectionID
JOIN Course      c   ON c.CourseID        = sec.CourseID
JOIN Term        t   ON t.TermID          = sec.TermID;

SELECT * FROM StudentTranscript WHERE StudentID = 1;
```

### Query 2: Average NET Score of Selected/Enrolled Applicants per Program
```sql
SELECT
    p.ProgramName,
    AVG(ts.Score) AS avg_net_score
FROM Program p
JOIN Application app ON p.ProgramID     = app.ProgramID
JOIN TestScore   ts  ON app.ApplicantID = ts.ApplicantID
WHERE app.Status IN ('Selected','Enrolled')
GROUP BY p.ProgramName
ORDER BY avg_net_score DESC;
```

### Query 3: Find Students Taking "Database Systems" (Nested Subquery)
```sql
SELECT ap.FirstName, ap.LastName
FROM Applicant ap
JOIN Application a ON a.ApplicantID = ap.ApplicantID
JOIN Student     s ON s.ApplicationID = a.ApplicationID
WHERE s.StudentID IN (
    SELECT e.StudentID
    FROM Enrollment e
    JOIN Section sec ON e.SectionID = sec.SectionID
    WHERE sec.CourseID = (
        SELECT CourseID FROM Course WHERE CourseName = 'Database Systems'
    )
);
```

### Query 4: Application Fee Revenue per NET Series (Aggregation)
*Tallies per-application fees paid by applicants who attempted each NET series.*
```sql
SELECT
    et.SeriesName,
    SUM(af.Amount) AS total_revenue
FROM EntryTest      et
JOIN TestScore      ts ON et.TestID       = ts.TestID
JOIN Application    a  ON a.ApplicantID   = ts.ApplicantID
JOIN ApplicationFee af ON af.ApplicationID = a.ApplicationID
GROUP BY et.SeriesName
ORDER BY total_revenue DESC;
```

### Query 5: Instructors and Student Count in 'Fall 2026'
```sql
SELECT
    i.FirstName,
    i.LastName,
    COUNT(e.EnrollmentID) AS total_students_taught
FROM Instructor i
JOIN Section    sec ON i.InstructorID = sec.InstructorID
JOIN Term       t   ON sec.TermID     = t.TermID
LEFT JOIN Enrollment e ON sec.SectionID = e.SectionID
WHERE t.TermName = 'Fall 2026'
GROUP BY i.InstructorID
ORDER BY total_students_taught DESC;
```

### Query 6: Waitlisted Applicants with >140 in NET (Subquery)
```sql
SELECT ap.FirstName, ap.LastName, a.Status
FROM Applicant ap
JOIN Application a ON ap.ApplicantID = a.ApplicantID
WHERE a.Status = 'Waitlisted'
  AND ap.ApplicantID IN (SELECT ApplicantID FROM TestScore WHERE Score > 140);
```

### Query 7: Applicants scoring above Series Average (Correlated Subquery)
```sql
SELECT ap.FirstName, ts.Score, et.SeriesName
FROM Applicant ap
JOIN TestScore ts ON ap.ApplicantID = ts.ApplicantID
JOIN EntryTest et ON ts.TestID      = et.TestID
WHERE ts.Score > (
    SELECT AVG(ts2.Score) FROM TestScore ts2 WHERE ts2.TestID = ts.TestID
);
```

### Query 8: Classroom Utilization View
```sql
CREATE VIEW ClassroomUtilization AS
SELECT
    sch.Name         AS SchoolName,
    cr.RoomNumber,
    cr.Capacity,
    cr.RoomType,
    COUNT(sec.SectionID) AS SectionsHosted
FROM Classroom cr
JOIN School    sch ON cr.SchoolID   = sch.SchoolID
LEFT JOIN Section sec ON cr.ClassroomID = sec.ClassroomID
GROUP BY cr.ClassroomID;
```

### Query 9: Conversion Rate (Applicants → Students per School)
*Follows the admissions→academic bridge through `Student.ApplicationID`.*
```sql
SELECT
    sch.Name AS school_name,
    COUNT(DISTINCT app.ApplicantID) AS total_applicants,
    COUNT(DISTINCT s.StudentID)     AS converted_students
FROM School sch
JOIN      Program     p   ON sch.SchoolID    = p.SchoolID
LEFT JOIN Application app ON p.ProgramID     = app.ProgramID
LEFT JOIN Student     s   ON s.ApplicationID = app.ApplicationID
GROUP BY sch.SchoolID
ORDER BY converted_students DESC;
```

### Query 10: Courses with NO offerings in Fall 2026 (LEFT JOIN / IS NULL)
```sql
SELECT c.CourseCode, c.CourseName
FROM Course c
LEFT JOIN Section sec
       ON c.CourseID = sec.CourseID
      AND sec.TermID = (SELECT TermID FROM Term WHERE TermName = 'Fall 2026')
WHERE sec.SectionID IS NULL;
```

### Query 11: Top Revenue Schools from Tuition (Multi-hop traversal)
*A hybrid query that starts at `StudentFee`, travels `Student → Application → Program → School`.*
```sql
SELECT
    sch.Name AS school_name,
    SUM(sf.Amount) AS total_tuition
FROM StudentFee sf
JOIN Student     s   ON s.StudentID     = sf.StudentID
JOIN Application a   ON a.ApplicationID = s.ApplicationID
JOIN Program     pr  ON pr.ProgramID    = a.ProgramID
JOIN School      sch ON sch.SchoolID    = pr.SchoolID
WHERE sf.FeeType = 'Tuition'
GROUP BY sch.SchoolID
ORDER BY total_tuition DESC;
```

### Query 12: Courses Shared Across Multiple Programs (M:N demonstration)
*Proves the `ProgramCourse` junction is pulling its weight: one `Course` row can map to many programs.*
```sql
SELECT
    c.CourseCode,
    c.CourseName,
    COUNT(pc.ProgramID) AS num_programs
FROM Course c
JOIN ProgramCourse pc ON pc.CourseID = c.CourseID
GROUP BY c.CourseID
HAVING num_programs > 1
ORDER BY num_programs DESC;
```

### Query 13: BSCS Core Curriculum (Junction with attributes)
```sql
SELECT c.CourseCode, c.CourseName, pc.Semester
FROM ProgramCourse pc
JOIN Course  c ON c.CourseID  = pc.CourseID
JOIN Program p ON p.ProgramID = pc.ProgramID
WHERE p.DegreeType  = 'BSCS'
  AND pc.CourseType = 'Core'
ORDER BY pc.Semester;
```

## 2. Triggers

### Trigger 1: Prevent Enrollment Beyond Classroom Capacity
```sql
CREATE TRIGGER EnforceClassCapacity
BEFORE INSERT ON Enrollment
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN (SELECT COUNT(*) FROM Enrollment WHERE SectionID = NEW.SectionID) >=
             (SELECT c.Capacity
                FROM Classroom c
                JOIN Section   s ON s.ClassroomID = c.ClassroomID
               WHERE s.SectionID = NEW.SectionID)
        THEN RAISE(ABORT, 'Enrollment failed: Classroom capacity reached.')
    END;
END;
```

### Trigger 2: Auto-Update Admission Status
*When a `Student` is inserted, the referenced `Application` flips `Selected → Enrolled`. Sibling applications by the same applicant (Waitlisted / Rejected / Declined) are left alone — the trigger scopes strictly to `NEW.ApplicationID`.*
```sql
CREATE TRIGGER AutoUpdateApplicationStatus
AFTER INSERT ON Student
FOR EACH ROW
BEGIN
    UPDATE Application
       SET Status = 'Enrolled'
     WHERE ApplicationID = NEW.ApplicationID
       AND Status        = 'Selected';
END;
```

## 3. Stored Procedures and Functions

> **Note on SQLite.** SQLite does not support stored procedures or user-defined functions natively from SQL; these are expressed as application-side helpers (or, in MySQL/PostgreSQL, as real `PROCEDURE`/`FUNCTION` objects). The MySQL-equivalent syntax is shown below for completeness.

### Stored Procedure: Generate Tuition Challan
*Inserts a tuition entry into `StudentFee` for the given student.*
```sql
-- MySQL syntax
DELIMITER //
CREATE PROCEDURE GenerateTuitionChallan(
    IN p_student_id INT,
    IN p_amount     DECIMAL(10,2)
)
BEGIN
    INSERT INTO StudentFee (StudentID, Amount, PaymentDate, FeeType, Method)
    VALUES (p_student_id, p_amount, CURDATE(), 'Tuition', 'Bank');

    SELECT 'Challan generated successfully' AS Message;
END //
DELIMITER ;
```

### User-Defined Function: Check Admissions Eligibility
*Returns TRUE if the applicant has scored ≥ 140 on at least one Engineering NET.*
```sql
-- MySQL syntax
DELIMITER //
CREATE FUNCTION IsEligibleForEngineering(p_applicant_id INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE max_score INT;

    SELECT MAX(ts.Score) INTO max_score
      FROM TestScore ts
      JOIN EntryTest et ON et.TestID = ts.TestID
     WHERE ts.ApplicantID = p_applicant_id
       AND et.TestType    = 'Engineering';

    RETURN (max_score >= 140);
END //
DELIMITER ;
```

## 4. Index Creation and Optimization Analysis

```sql
-- Frequent academic-side JOINs
CREATE INDEX IDX_Enrollment_Student   ON Enrollment(StudentID);
CREATE INDEX IDX_Section_Course       ON Section(CourseID);
CREATE INDEX IDX_Section_Term         ON Section(TermID);
CREATE INDEX IDX_Section_Instructor   ON Section(InstructorID);

-- Admissions dashboard: filter by status / program
CREATE INDEX IDX_Application_Status   ON Application(Status);
CREATE INDEX IDX_Application_Program  ON Application(ProgramID);

-- Per-test analytics
CREATE INDEX IDX_TestScore_Test       ON TestScore(TestID);

-- Curriculum lookups (Course is keyed by School; ProgramCourse is bidirectional)
CREATE INDEX IDX_Course_School        ON Course(SchoolID);
CREATE INDEX IDX_ProgramCourse_Course ON ProgramCourse(CourseID);
```

## 5. Transaction Handling Example
When a candidate accepts their admission, three things must happen atomically:
1. The `Student` row is created (which fires `AutoUpdateApplicationStatus`, promoting the accepted `Application` from `Selected` to `Enrolled`).
2. A tuition payment is recorded in `StudentFee`.
3. Any prior `ApplicationFee` remains untouched.

If any step fails the whole transaction must `ROLLBACK` — we cannot end up with a Student who never paid tuition, or a tuition row with no matching Student.

```sql
BEGIN TRANSACTION;

-- 1. Create Student (fires AutoUpdateApplicationStatus trigger on Application 8)
INSERT INTO Student (ApplicationID, EnrollmentDate, CGPA)
VALUES (8, DATE('now'), 0.00);

-- 2. Record the tuition payment against the freshly-created student
INSERT INTO StudentFee (StudentID, Amount, PaymentDate, FeeType, Method)
VALUES (
    (SELECT StudentID FROM Student WHERE ApplicationID = 8),
    120000.00,
    DATE('now'),
    'Tuition',
    'Bank'
);

COMMIT;
-- On error: ROLLBACK;
```
