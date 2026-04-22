# Complex SQL Queries — NUST University Database

> **Database:** `nust_university`  
> **Phase:** 2 — DDL & Data Insertion  
> All queries are written for **MySQL 8+**.

---

## Query 1 — Multi-table JOIN: Full Student Academic Profile

Retrieves each student's name, program, school, current semester, GPA, and the
faculty member who taught them in at least one section.

```sql
SELECT
    s.student_id,
    s.full_name                          AS student_name,
    p.program_name,
    p.degree_type,
    sch.school_name,
    s.current_semester,
    s.gpa,
    GROUP_CONCAT(DISTINCT f.full_name ORDER BY f.full_name SEPARATOR ', ')
                                         AS instructors
FROM student      s
JOIN program      p   ON s.program_id   = p.program_id
JOIN school       sch ON p.school_id    = sch.school_id
JOIN enrollment   e   ON s.student_id   = e.student_id
JOIN section      sec ON e.section_id   = sec.section_id
JOIN faculty      f   ON sec.faculty_id = f.faculty_id
GROUP BY
    s.student_id, s.full_name, p.program_name,
    p.degree_type, sch.school_name,
    s.current_semester, s.gpa
ORDER BY s.gpa DESC NULLS LAST;
```

---

## Query 2 — Subquery + JOIN: Applicants Who Beat the Program Average Aggregate Score

Finds applicants whose aggregate score is higher than the average aggregate
score of all applicants to the same program.

```sql
SELECT
    ap.applicant_id,
    ap.full_name,
    app.program_id,
    p.program_name,
    app.aggregate_score,
    prog_avg.avg_score                   AS program_avg_score,
    ROUND(app.aggregate_score - prog_avg.avg_score, 2)
                                         AS score_above_avg
FROM application app
JOIN applicant   ap       ON app.applicant_id = ap.applicant_id
JOIN program     p        ON app.program_id   = p.program_id
JOIN (
    SELECT program_id,
           AVG(aggregate_score) AS avg_score
    FROM   application
    WHERE  aggregate_score IS NOT NULL
    GROUP  BY program_id
) prog_avg ON app.program_id = prog_avg.program_id
WHERE app.aggregate_score > prog_avg.avg_score
ORDER BY score_above_avg DESC;
```

---

## Query 3 — Aggregation + HAVING: Schools with More Than One Professor

Lists schools that have at least two faculty members holding the 'Professor'
designation.

```sql
SELECT
    sch.school_id,
    sch.school_name,
    COUNT(f.faculty_id)              AS professor_count,
    GROUP_CONCAT(f.full_name ORDER BY f.full_name SEPARATOR ', ')
                                     AS professor_names
FROM school   sch
JOIN faculty  f ON sch.school_id = f.school_id
WHERE f.designation = 'Professor'
GROUP BY sch.school_id, sch.school_name
HAVING COUNT(f.faculty_id) > 1
ORDER BY professor_count DESC;
```

---

## Query 4 — VIEW: Admission Funnel Summary per Program

Creates a reusable view summarising every stage of the admission pipeline for
each program: total applicants, selected, waitlisted, rejected, offered, and
enrolled.

```sql
CREATE OR REPLACE VIEW vw_admission_funnel AS
SELECT
    p.program_id,
    p.program_name,
    p.degree_type,
    sch.abbreviation                       AS school,
    COUNT(app.application_id)             AS total_applications,
    SUM(app.status = 'Selected')          AS selected,
    SUM(app.status = 'Waitlisted')        AS waitlisted,
    SUM(app.status = 'Rejected')          AS rejected,
    COUNT(o.offer_id)                     AS offers_issued,
    COUNT(st.student_id)                  AS enrolled_students,
    p.total_seats,
    ROUND(COUNT(st.student_id) / p.total_seats * 100, 1)
                                          AS seat_fill_pct
FROM program     p
JOIN school      sch ON p.school_id    = sch.school_id
LEFT JOIN application app ON p.program_id   = app.program_id
LEFT JOIN offer       o   ON app.application_id = o.application_id
LEFT JOIN student     st  ON p.program_id   = st.program_id
GROUP BY
    p.program_id, p.program_name, p.degree_type,
    sch.abbreviation, p.total_seats;

-- Query the view
SELECT * FROM vw_admission_funnel ORDER BY total_applications DESC;
```

---

## Query 5 — Correlated Subquery: Students Enrolled in More Courses Than the Average Student

Returns students whose current active (in-progress) course load exceeds the
average across all students.

```sql
SELECT
    s.student_id,
    s.full_name,
    s.current_semester,
    s.gpa,
    (
        SELECT COUNT(*)
        FROM   enrollment e2
        JOIN   section    sec2 ON e2.section_id = sec2.section_id
        WHERE  e2.student_id = s.student_id
          AND  e2.grade IS NULL           -- currently in progress
    ) AS active_courses
FROM student s
WHERE (
    SELECT COUNT(*)
    FROM   enrollment e2
    JOIN   section    sec2 ON e2.section_id = sec2.section_id
    WHERE  e2.student_id = s.student_id
      AND  e2.grade IS NULL
) > (
    SELECT AVG(course_load)
    FROM (
        SELECT student_id, COUNT(*) AS course_load
        FROM   enrollment e3
        JOIN   section    sec3 ON e3.section_id = sec3.section_id
        WHERE  e3.grade IS NULL
        GROUP  BY e3.student_id
    ) loads
)
ORDER BY active_courses DESC;
```

---

## Query 6 — VIEW: Faculty Workload per Term

Creates a view showing how many sections and distinct courses each faculty
member taught in each term, along with the total classroom capacity they
managed.

```sql
CREATE OR REPLACE VIEW vw_faculty_workload AS
SELECT
    f.faculty_id,
    f.full_name                              AS faculty_name,
    f.designation,
    sch.abbreviation                         AS school,
    t.term_id,
    CONCAT(t.term_name, ' ', t.academic_year) AS term_label,
    COUNT(sec.section_id)                    AS sections_taught,
    COUNT(DISTINCT sec.course_code)          AS distinct_courses,
    SUM(cl.capacity)                         AS total_seat_capacity
FROM faculty    f
JOIN school     sch ON f.school_id    = sch.school_id
JOIN section    sec ON f.faculty_id   = sec.faculty_id
JOIN term       t   ON sec.term_id    = t.term_id
JOIN classroom  cl  ON sec.classroom_id = cl.classroom_id
GROUP BY
    f.faculty_id, f.full_name, f.designation,
    sch.abbreviation, t.term_id, t.term_name, t.academic_year;

-- Query the view
SELECT * FROM vw_faculty_workload ORDER BY term_label, sections_taught DESC;
```

---

## Query 7 — EXISTS Subquery: Courses That Have Never Been Enrolled In

Identifies courses that exist in the catalog but have no enrollment records
(either in current or past terms).

```sql
SELECT
    c.course_code,
    c.course_title,
    c.course_type,
    c.credit_hours,
    sch.school_name
FROM course  c
JOIN school  sch ON c.school_id = sch.school_id
WHERE NOT EXISTS (
    SELECT 1
    FROM   section    sec
    JOIN   enrollment e  ON sec.section_id = e.section_id
    WHERE  sec.course_code = c.course_code
)
ORDER BY sch.school_name, c.course_code;
```

---

## Query 8 — Window Function + JOIN: Grade Rank within Each Course Section

Ranks students by their final grade within each section using DENSE_RANK.
Only completed (graded) enrollments are included.

```sql
SELECT
    sec.section_id,
    c.course_title,
    CONCAT(t.term_name, ' ', t.academic_year) AS term_label,
    s.student_id,
    s.full_name                               AS student_name,
    e.grade,
    e.attendance_percentage,
    DENSE_RANK() OVER (
        PARTITION BY e.section_id
        ORDER BY
            FIELD(e.grade,'A','A-','B+','B','B-','C+','C','C-','D+','D','F')
    )                                         AS grade_rank
FROM enrollment  e
JOIN student     s   ON e.student_id   = s.student_id
JOIN section     sec ON e.section_id   = sec.section_id
JOIN course      c   ON sec.course_code = c.course_code
JOIN term        t   ON sec.term_id    = t.term_id
WHERE e.grade IS NOT NULL
ORDER BY sec.section_id, grade_rank;
```

---

## Query 9 — CTE + Aggregation: Top Applicants by Entry Test Type

Uses a Common Table Expression to find the highest-scoring applicant for each
NET test type, together with their high-school score and the program they
applied to.

```sql
WITH ranked_attempts AS (
    SELECT
        ta.applicant_id,
        et.test_type,
        ta.score                           AS test_score,
        ap.full_name,
        ap.high_school_score,
        ROW_NUMBER() OVER (
            PARTITION BY et.test_type
            ORDER BY ta.score DESC
        )                                  AS rnk
    FROM test_attempt ta
    JOIN entry_test   et ON ta.test_id      = et.test_id
    JOIN applicant    ap ON ta.applicant_id = ap.applicant_id
)
SELECT
    ra.test_type,
    ra.full_name                           AS top_scorer,
    ra.test_score,
    ra.high_school_score,
    GROUP_CONCAT(
        DISTINCT CONCAT(app.program_id, ' (', app.status, ')')
        ORDER BY app.program_id SEPARATOR ', '
    )                                      AS applications
FROM ranked_attempts ra
LEFT JOIN application app ON ra.applicant_id = app.applicant_id
WHERE ra.rnk = 1
GROUP BY ra.test_type, ra.full_name, ra.test_score, ra.high_school_score
ORDER BY ra.test_score DESC;
```

---

## Query 10 — Multi-level Subquery + Aggregation: Programs with Highest Average Applicant Aggregate Score (above overall mean)

Finds programs whose average applicant aggregate score beats the overall
average, and shows which term drew the most applicants.

```sql
SELECT
    p.program_id,
    p.program_name,
    p.degree_type,
    sch.abbreviation                          AS school,
    COUNT(app.application_id)                AS total_applicants,
    ROUND(AVG(app.aggregate_score), 2)       AS avg_aggregate,
    ROUND(AVG(app.aggregate_score) -
          (SELECT AVG(aggregate_score) FROM application
           WHERE aggregate_score IS NOT NULL), 2)
                                             AS vs_overall_avg,
    (
        SELECT t2.term_name
        FROM   application  app2
        JOIN   term         t2  ON app2.term_id = t2.term_id
        WHERE  app2.program_id = p.program_id
          AND  app2.aggregate_score IS NOT NULL
        GROUP  BY app2.term_id, t2.term_name
        ORDER  BY COUNT(*) DESC
        LIMIT  1
    )                                        AS busiest_term
FROM program     p
JOIN school      sch ON p.school_id    = sch.school_id
JOIN application app ON p.program_id   = app.program_id
WHERE app.aggregate_score IS NOT NULL
GROUP BY p.program_id, p.program_name, p.degree_type, sch.abbreviation
HAVING AVG(app.aggregate_score) > (
    SELECT AVG(aggregate_score)
    FROM   application
    WHERE  aggregate_score IS NOT NULL
)
ORDER BY avg_aggregate DESC;
```

---

## Query 11 — Three-Way JOIN + CASE: Classroom Utilisation Report

Compares actual enrolled students per section against classroom capacity and
classifies each as Under-utilised, Optimal, or Over-capacity.

```sql
SELECT
    sec.section_id,
    c.course_title,
    cl.building,
    cl.room_number,
    cl.capacity                             AS room_capacity,
    COUNT(e.student_id)                     AS enrolled_count,
    ROUND(COUNT(e.student_id) / cl.capacity * 100, 1)
                                            AS utilisation_pct,
    CASE
        WHEN COUNT(e.student_id) = 0                       THEN 'Empty'
        WHEN COUNT(e.student_id) / cl.capacity < 0.60      THEN 'Under-utilised'
        WHEN COUNT(e.student_id) / cl.capacity BETWEEN 0.60 AND 1.00
                                                           THEN 'Optimal'
        ELSE                                                    'Over-capacity'
    END                                     AS utilisation_status,
    f.full_name                             AS instructor,
    CONCAT(t.term_name, ' ', t.academic_year) AS term_label
FROM section    sec
JOIN course     c   ON sec.course_code   = c.course_code
JOIN classroom  cl  ON sec.classroom_id  = cl.classroom_id
JOIN faculty    f   ON sec.faculty_id    = f.faculty_id
JOIN term       t   ON sec.term_id       = t.term_id
LEFT JOIN enrollment e ON sec.section_id = e.student_id   -- all sections, even empty
GROUP BY
    sec.section_id, c.course_title, cl.building,
    cl.room_number, cl.capacity, f.full_name,
    t.term_name, t.academic_year
ORDER BY utilisation_pct DESC;
```

> **Note:** The LEFT JOIN ensures sections with zero enrolments still appear.

---

## Query 12 — VIEW + Recursive-style CTE: Full Prerequisite Chain for a Course

Creates a view that flattens the prerequisite graph up to 4 levels deep using
a recursive CTE, allowing you to see the complete dependency tree for any course.

```sql
CREATE OR REPLACE VIEW vw_prerequisite_chain AS
WITH RECURSIVE prereq_tree AS (
    -- Anchor: direct prerequisites
    SELECT
        p.course_code,
        p.prereq_course_code,
        1                       AS depth,
        CAST(p.prereq_course_code AS CHAR(200)) AS chain
    FROM prerequisite p

    UNION ALL

    -- Recursive: prerequisites of prerequisites
    SELECT
        pt.course_code,
        p2.prereq_course_code,
        pt.depth + 1,
        CONCAT(p2.prereq_course_code, ' → ', pt.chain)
    FROM prereq_tree pt
    JOIN prerequisite p2 ON pt.prereq_course_code = p2.course_code
    WHERE pt.depth < 4           -- guard against runaway recursion
)
SELECT
    pt.course_code,
    c1.course_title                            AS course_title,
    pt.prereq_course_code,
    c2.course_title                            AS prereq_title,
    pt.depth,
    pt.chain                                   AS full_prerequisite_chain
FROM prereq_tree pt
JOIN course c1 ON pt.course_code       = c1.course_code
JOIN course c2 ON pt.prereq_course_code = c2.course_code;

-- Example: see the full dependency chain for Machine Learning (CS440)
SELECT *
FROM   vw_prerequisite_chain
WHERE  course_code = 'CS440'
ORDER  BY depth;
```

---

## Query 13 — Aggregation + Self-join Subquery: Students Who Applied to Multiple Programs and Were Selected in At Least One

```sql
SELECT
    ap.applicant_id,
    ap.full_name,
    ap.high_school_board,
    ap.best_test_score,
    COUNT(app.application_id)                        AS total_applications,
    SUM(app.status = 'Selected')                     AS selected_count,
    SUM(app.status = 'Rejected')                     AS rejected_count,
    SUM(app.status = 'Waitlisted')                   AS waitlisted_count,
    GROUP_CONCAT(
        CONCAT(app.program_id, ': ', app.status)
        ORDER BY app.program_id SEPARATOR ' | '
    )                                                AS application_summary
FROM applicant   ap
JOIN application app ON ap.applicant_id = app.applicant_id
GROUP BY ap.applicant_id, ap.full_name,
         ap.high_school_board, ap.best_test_score
HAVING COUNT(app.application_id) > 1
   AND SUM(app.status = 'Selected') >= 1
ORDER BY selected_count DESC, total_applications DESC;
```

---

## Summary of Concepts Demonstrated

| # | Concept |
|---|---------|
| 1 | 5-table JOIN, `GROUP_CONCAT` |
| 2 | Derived-table subquery, aggregate comparison |
| 3 | Aggregation, `HAVING` filter |
| 4 | `CREATE VIEW`, multi-table LEFT JOIN, conditional aggregation |
| 5 | Correlated subquery (double-nested) |
| 6 | `CREATE VIEW`, `GROUP BY` across term & faculty |
| 7 | `NOT EXISTS` anti-join subquery |
| 8 | `DENSE_RANK()` window function, `FIELD()` for grade ordering |
| 9 | CTE + `ROW_NUMBER()` + `GROUP_CONCAT` |
| 10 | Multi-level subquery, `HAVING` vs overall average |
| 11 | `CASE` expression, utilisation classification |
| 12 | Recursive CTE (`WITH RECURSIVE`), `CREATE VIEW` |
| 13 | Self-referencing aggregation, multi-program applicant analysis |
