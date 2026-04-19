# Prompt: Design a Complete MySQL Database for NUST University, Islamabad

## Your Role

You are an expert database architect. Design a **complete, production-ready MySQL database** for NUST (National University of Sciences and Technology), Islamabad. Produce the full DDL (CREATE TABLE statements), sample INSERT data, and useful queries — all in a single `.sql` file that can be executed top-to-bottom without errors.

---

## Important: Scope Restriction

This database is **strictly for undergraduate (Bachelor's) programs only**. All design decisions — semester counts, program structures, student records — apply to BS/BE/B.Arch/LLB bachelor-level students only. Do not design for postgraduate programs.

---

## Important: Attached Reference File — "UG-Student-Handbook"

An additional file titled **"UG-Student-Handbook"** is added to the directory test-sql-rag. Use it **only** as a reference for realistic sample data values when populating INSERT statements — for example:

- Actual NUST school names and abbreviations.
- Real program names and their credit-hour totals.
- Course codes, titles, and credit hours offered at NUST.
- Grading policies and GPA scales.

**Do NOT use the handbook to alter the database schema, add extra tables, or introduce additional business rules.** The handbook contains a lot of policy and procedural information that is irrelevant to the database design. Stick strictly to the schema and rules defined in this prompt. The handbook is a data source for INSERT values, nothing more.

If the handbook does not provide a specific value you need (e.g., exact credit hours for a course in a specific semester), use a **reasonable synthetic/dummy value** that fits NUST's context.

---

## System Overview

The database covers **two modules**:

1. **Academic Module** — Schools (constituent institutions), faculty, programs, courses, students, semester tracking, class scheduling, and grading.
2. **Admissions Module** — Applicants, entry tests, applications, merit ranking, and offer letters.

The two modules share the `program` and `term` tables. They connect at one point: when an applicant accepts an admission offer, a `student` record is created.

---

## Module 1: Academic Module

### Entities to Include

| Entity | Purpose |
|---|---|
| `school` | NUST constituent institutions (replaces generic "department"). E.g., SEECS, NBS, SADA, SMME, SCEE, SNS, S3H, NICE, NSTP, ASAP, etc. |
| `faculty` | Teaching staff, each belonging to one school |
| `program` | Bachelor's degree programs (e.g., BS Computer Science, BE Electrical Engineering, B.Arch, LLB). Each has a defined total credit hours and total semesters. |
| `course` | Individual subjects with credit hours and a course type (Theory, Lab, or Project) |
| `prerequisite` | Self-referencing junction table: which courses must be completed before which |
| `program_course` | Junction table: maps courses to programs (M:N), **also specifies which semester** the course is recommended for (1–8 or 1–10) |
| `student` | Enrolled bachelor's students, each registered in exactly one program, with a tracked current semester |
| `term` | Academic semesters (e.g., Fall 2024, Spring 2025). Each term maps to a calendar semester. |
| `classroom` | Physical rooms with capacity |
| `section` | A specific offering of a course: binds a course + term + classroom + faculty member |
| `enrollment` | Associative entity: a student enrolled in a section; carries the grade **and attendance percentage** |

---

### Semester Tracking System

The database must support answering: **"What semester is this student currently in?"**

Design this as follows:

1. **`program` table** includes a `total_semesters` column:
   - Most BS/BE programs → `8` semesters (4 years).
   - B.Arch (Architecture) → `10` semesters (5 years).
   - LLB (Law) → `10` semesters (5 years).

2. **`student` table** includes a `current_semester` column (`TINYINT`, range 1–10):
   - Set to `1` when the student is first created (upon admission).
   - Incremented at the start of each new term (this would be handled by application logic or a trigger — just ensure the column exists and sample data reflects realistic values).

3. **`program_course` table** includes a `recommended_semester` column (`TINYINT`):
   - Indicates which semester of the program the course is typically taken in (e.g., Calculus I → semester 1, Database Systems → semester 5).
   - This lets the system suggest courses for a student based on their `current_semester`.

4. **Derivation query** (include in the deliverables): A query that determines a student's semester based on how many distinct terms they have enrollment records in, as a cross-check against the stored `current_semester`.

---

### NUST Grading System

NUST uses the following **letter grades with fixed GPA points**. Implement this as an `ENUM` on the `enrollment.grade` column:

| Grade | GPA Points | Meaning |
|---|---|---|
| `A` | 4.0 | Excellent |
| `B+` | 3.5 | Very Good |
| `B` | 3.0 | Good |
| `C+` | 2.5 | Satisfactory |
| `C` | 2.0 | Adequate |
| `D+` | 1.5 | Below Average |
| `D` | 1.0 | Poor (minimum passing) |
| `F` | 0.0 | Fail |
| `XF` | 0.0 | Fail due to attendance below 75% |
| `I` | — | Incomplete (temporary, must be resolved) |
| `W` | — | Withdrawn |

**ENUM definition:**
```sql
ENUM('A','B+','B','C+','C','D+','D','F','XF','I','W')
```

Grade is **nullable** — NULL means the course is in progress and not yet graded.

---

### Attendance and XF Rule

The `enrollment` table must include an `attendance_percentage` column (`DECIMAL(5,2)`, nullable).

**Business Rule:** If a student's `attendance_percentage` drops below **75%**, the system must automatically assign grade `'XF'` (fail due to insufficient attendance). Implement this as a `BEFORE UPDATE` trigger on the `enrollment` table:

- When `attendance_percentage` is updated to a value < 75.00, set `grade = 'XF'` automatically.
- Include this trigger in the DDL.

---

### Course Types and Contact Hours

Each course has a **type** that determines how credit hours translate to weekly contact hours:

| Course Type | Credit-to-Contact-Hour Rule |
|---|---|
| `Theory` | 1 Credit Hour = **1** Contact Hour per week |
| `Lab` | 1 Credit Hour = **3** Contact Hours per week |
| `Project` | 1 Credit Hour = **3** Contact Hours per week |

Add to the `course` table:
- `course_type` — `ENUM('Theory', 'Lab', 'Project')`
- `credit_hours` — `TINYINT` (e.g., 3)
- `contact_hours` — `TINYINT` — **stored** (computed as `credit_hours * 1` for Theory, `credit_hours * 3` for Lab/Project). Store it explicitly; do not rely on a generated column, just ensure INSERT data is consistent with the rule.

---

### Academic Cardinalities

Define relationships with these **exact cardinalities** (use NOT NULL for mandatory FKs, nullable for optional):

| Relationship | Type | Rule |
|---|---|---|
| school → faculty | One-to-Many (mandatory parent) | Every faculty member **must** belong to exactly one school. A school can have zero or more faculty. |
| school → program | One-to-Many (mandatory parent) | Every program **must** belong to exactly one school. A school can offer zero or more programs. |
| program → student | One-to-Many (mandatory parent) | Every student **must** be registered in exactly one program. A program can have zero or more students. |
| course ↔ course | Many-to-Many (self-ref, via `prerequisite`) | A course can have zero or more prerequisites. A course can be a prerequisite for zero or more other courses. |
| program ↔ course | Many-to-Many (via `program_course`) | A program contains one or more courses. A course can belong to one or more programs. The junction row also carries `recommended_semester`. |
| course → section | One-to-Many | A course can have zero or more sections across terms. Each section is for exactly one course. |
| term → section | One-to-Many | A term contains zero or more sections. Each section belongs to exactly one term. |
| classroom → section | One-to-Many | A classroom can host zero or more sections (at different times). Each section meets in exactly one classroom. |
| faculty → section | One-to-Many | A faculty member can teach zero or more sections. Each section is taught by exactly one faculty member. |
| student ↔ section | Many-to-Many (via `enrollment`) | A student can enroll in many sections; a section can have many students. The `enrollment` row carries `grade` and `attendance_percentage`. |

### Academic Business Rules

- A student **cannot** enroll in a course section unless they have passed all prerequisite courses (passing = grade is NOT NULL, NOT `'F'`, NOT `'XF'`, NOT `'I'`, NOT `'W'`).
- Students typically take courses matching their `current_semester` against the `recommended_semester` in `program_course`, but this is advisory, not enforced by constraint.
- A student's `current_semester` must not exceed their program's `total_semesters`.

---

## Module 2: Admissions Module

### Entities to Include

| Entity | Purpose |
|---|---|
| `applicant` | A person applying for admission (not yet a student) |
| `entry_test` | A specific test event — has a type (NET-1 through NET-4) and a date |
| `test_attempt` | Associative entity: an applicant's score on a specific test event |
| `application` | One applicant applying to one program for one Fall intake; carries the aggregate score |
| `offer` | An offer letter issued to a shortlisted applicant for a specific application |

### Admissions Cardinalities

| Relationship | Type | Rule |
|---|---|---|
| applicant → application | One-to-Many | An applicant can submit multiple applications (one per program). Each application belongs to exactly one applicant. |
| program → application | One-to-Many | Each application targets exactly one program. |
| term → application | One-to-Many | Each application is for exactly one term (always a Fall term). |
| applicant ↔ entry_test | Many-to-Many (via `test_attempt`) | An applicant can attempt multiple tests; a test event can be taken by many applicants. Each `test_attempt` carries the `score`. |
| application → offer | One-to-One (optional) | An application may or may not receive an offer. Each offer is tied to exactly one application. |

### Admissions Business Rules

- **Fall intake only:** Admissions are conducted once per year for the Fall term.
- **Aggregate score** = `high_school_score + best_test_score`. Both component scores are **snapshotted** into the `application` row at submission time (so later test attempts don't retroactively change an existing application).
- **Best test score** is tracked on the `applicant` row as a denormalized field. Update it whenever a new `test_attempt` is inserted with a higher score.
- **Offer rules:**
  - Only applications whose aggregate score ranks within the program's `total_seats` limit should receive offers.
  - An applicant can receive **multiple offers** (one per program they qualified for) but can **accept at most one**.
  - Offer statuses: `'Pending'`, `'Accepted'`, `'Declined'`, `'Expired'`.
  - Accepting one offer should logically require declining all other pending offers for that applicant.
- **Application statuses:** `'Submitted'`, `'Offered'`, `'Accepted'`, `'Rejected'`, `'Withdrawn'`.

### Simplification — No Separate Merit List Tables

Do **NOT** create separate `merit_list` or `merit_list_entry` tables. Merit ranking is simply a **query** that orders applications by aggregate score within each program. A merit list is a report, not persistent data.

Instead, provide a **view or query** like:

```sql
-- Merit list: rank applications per program by aggregate score
SELECT program_id, application_id, applicant_id, aggregate_score,
       RANK() OVER (PARTITION BY program_id ORDER BY aggregate_score DESC) AS merit_rank
FROM application
WHERE term_id = ? AND status != 'Withdrawn';
```

---

## Cross-Module Link: Applicant → Student

When an applicant accepts an offer:

- A new `student` record is created with `current_semester = 1`.
- The `student` table should have an **optional** `applicant_id` FK back to `applicant` (nullable, because legacy or transfer students may not have an applicant record).
- The student's `program_id` comes from the accepted application.

---

## Technical Requirements

### Naming Conventions
- All table and column names in **lowercase snake_case**.
- Primary keys named `<table>_id` (e.g., `student_id`, `course_code`). Exception: `course` uses `course_code` as PK.
- Foreign keys named identically to the column they reference.

### Data Types
- IDs: `VARCHAR(20)` (NUST uses alphanumeric IDs like `'SEECS'`, `'STU-001'`).
- Names/emails: `VARCHAR(100)` or `VARCHAR(255)`.
- Scores: `DECIMAL(5,2)`.
- Dates: `DATE`.
- Descriptive text: `TEXT`.
- Semesters: `TINYINT` for `current_semester`, `total_semesters`, `recommended_semester`.
- Attendance: `DECIMAL(5,2)` for percentage (0.00–100.00).
- Enums: Use MySQL `ENUM(...)` for constrained value sets (grades, statuses, test types, semester names, course types).

### Constraints
- Define all `PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL`, `UNIQUE`, and `CHECK` constraints inline or as table-level constraints.
- Use `ON DELETE RESTRICT` for most foreign keys (prevent accidental cascading deletes).
- Use `ON DELETE CASCADE` only for junction/associative tables (`prerequisite`, `program_course`, `test_attempt`, `enrollment`).
- `CHECK (current_semester <= total_semesters)` — enforce at application level or document as a business rule (since MySQL CHECK can't easily cross-reference tables).

### Indexes
- Add indexes on all foreign key columns.
- Add a composite unique index on `(applicant_id, program_id, term_id)` in `application` to prevent duplicate applications.
- Add a unique index on `(course_code, prereq_course_code)` in `prerequisite`.

### Triggers
Include at minimum:
1. **XF attendance trigger** — `BEFORE UPDATE` on `enrollment`: if `attendance_percentage < 75.00`, set `grade = 'XF'`.
2. **Best test score trigger** — `AFTER INSERT` on `test_attempt`: if the new score exceeds `applicant.best_test_score`, update it.

### Other
- Begin the file with `DROP DATABASE IF EXISTS nust_university; CREATE DATABASE nust_university; USE nust_university;`.
- Use `InnoDB` engine for all tables.
- Include `AUTO_INCREMENT` nowhere — all IDs are manually assigned VARCHAR strings.

---

## Deliverables (All in One `.sql` File)

### 1. DDL — All CREATE TABLE Statements
Create tables in dependency order (parents before children). Include all constraints, indexes, foreign keys, and triggers.

### 2. Sample Data — INSERT Statements

Populate every table with **approximately 10 rows** of realistic, NUST-relevant data that tells a coherent story. Use actual NUST school names, realistic Pakistani names, NUST-style course codes, and so on.

| Table | Target Rows | Notes |
|---|---|---|
| `school` | 10 | Use real NUST constituent institutions: SEECS, NBS, SADA, SMME, SCEE, SNS, S3H, NICE, NSTP, ASAP |
| `faculty` | 10 | Realistic Pakistani names, spread across schools |
| `program` | 10 | Real NUST programs: BS CS, BE EE, BE ME, BBA, B.Arch, BS Math, BS SE, etc. Include `total_semesters` (8 or 10) and `total_credits` |
| `course` | 10 | Mix of Theory, Lab, and Project courses with correct `contact_hours` values. Use NUST-style course codes if possible (e.g., `CS110`, `EE201`, `MT101`). For exact credit hours, refer to the attached UG-Student-Handbook or use reasonable dummy values. |
| `prerequisite` | 10 | Logical chains (e.g., Calculus I → Calculus II, Programming Fundamentals → OOP → Data Structures) |
| `program_course` | 10 | Map courses to programs with `recommended_semester` values (1–8). Ensure each program has at least a couple of courses mapped. |
| `term` | 10 | Span across multiple years: Fall 2022, Spring 2023, Fall 2023, ... to show student progression |
| `classroom` | 10 | Use NUST building references if known, or realistic room numbers |
| `student` | 10 | Varying `current_semester` values (1 through 7/8) to show students at different stages. Some from 4-year programs, at least one from a 5-year program. |
| `section` | 10 | Spread across different terms, courses, classrooms, and faculty |
| `enrollment` | 10 | Mix of: completed with grades (A, B+, C, etc.), one with `XF` (attendance < 75%), one with `NULL` grade (in progress), one with `W`. Include `attendance_percentage` values. |
| `applicant` | 10 | Pakistani names, CNICs, different high school boards (FBISE, Punjab, Sindh, KPK, AKU-EB) |
| `entry_test` | 10 | Multiple NET types (NET-1 through NET-4) across different dates/years |
| `test_attempt` | 10 | Show some applicants attempting multiple tests |
| `application` | 10 | Various statuses. Aggregate scores computed correctly from snapshotted values. |
| `offer` | 10 | Mix of Pending, Accepted, Declined, Expired. Ensure at most one Accepted offer per applicant. |

**Data coherence requirements:**
- At least **2 students** should have enrollment histories spanning multiple terms, so the semester-tracking derivation query works meaningfully.
- At least **1 enrollment** should have `attendance_percentage < 75` with grade `'XF'` to demonstrate the attendance rule.
- At least **1 applicant** should have accepted an offer and appear as a student in the `student` table (with a matching `applicant_id`).
- Prerequisite chains should be reflected in the enrollment data — e.g., a student who took Calculus I in Fall 2023 and Calculus II in Spring 2024.

### 3. Useful Queries (8–10 queries)
Include commented SQL queries that demonstrate the schema's capabilities:

1. **Student transcript** — List all courses, grades, credit hours, and GPA points for a specific student, ordered by term.
2. **Semester GPA calculation** — Calculate a student's GPA for a specific term: `SUM(credit_hours × gpa_points) / SUM(credit_hours)` for graded courses only (exclude NULL, I, W).
3. **Cumulative GPA (CGPA)** — Calculate a student's CGPA across all completed terms.
4. **Current semester courses** — For a given student, show which courses are recommended for their `current_semester` in their program.
5. **Prerequisite check** — Given a student and a course, verify whether all prerequisites are satisfied (passed with grade not in F, XF, I, W, NULL).
6. **Merit list** — Rank all applicants for a specific program by aggregate score; show who falls within the seat limit.
7. **Faculty workload** — Show how many sections and total contact hours each faculty member is teaching in a given term.
8. **Section enrollment vs. capacity** — For each section in a term, show how many students are enrolled vs. classroom capacity.
9. **Applicant offer summary** — For a specific applicant, show all offers received and their statuses.
10. **Students at risk (attendance)** — List all enrollments in the current term where `attendance_percentage` is below 80% (early warning before the 75% XF cutoff).


### 4. Complete updated code for ERD (Entity Relationship Diagram) for the database.
ERD should be consistent with the cardinalities, and the ERD should be created using mermaid.


### 5. Create a separate .txt file with a concise summary of the database schema and its design decisions. 
Create a clear summarized section within the .txt file for the exact cardinalities between all the tables/entities.

---

## GPA Points Reference (for Queries)

Since GPA points are fixed per grade, queries should use a `CASE` expression to map grades to points:

```sql
CASE grade
    WHEN 'A'  THEN 4.0
    WHEN 'B+' THEN 3.5
    WHEN 'B'  THEN 3.0
    WHEN 'C+' THEN 2.5
    WHEN 'C'  THEN 2.0
    WHEN 'D+' THEN 1.5
    WHEN 'D'  THEN 1.0
    WHEN 'F'  THEN 0.0
    WHEN 'XF' THEN 0.0
    ELSE NULL  -- I, W, NULL are excluded from GPA calculation
END
```

Alternatively, create a small **`grade_point` lookup table** with columns `(grade VARCHAR PK, points DECIMAL)` if you prefer joins over CASE. Either approach is acceptable — just be consistent.

---

## Final Checklist

Before finalizing, verify:

- [ ] Every foreign key references an existing parent table and column.
- [ ] Tables are created in dependency order (no forward references).
- [ ] Sample data respects all constraints and foreign keys (no orphan records).
- [ ] All INSERT values are consistent (e.g., a student's `program_id` exists in `program`).
- [ ] `contact_hours` values are consistent with `course_type` and `credit_hours` (Theory: ×1, Lab/Project: ×3).
- [ ] At least one enrollment row demonstrates the XF attendance rule.
- [ ] Semester values are coherent: no student has `current_semester` exceeding their program's `total_semesters`.
- [ ] The file runs cleanly from top to bottom in a fresh MySQL 8.0+ instance.
- [ ] Triggers are syntactically correct (use `DELIMITER` properly).
- [ ] Junction tables have composite primary keys or unique constraints preventing duplicates.
- [ ] Cardinalities match the rules specified above — no more, no less.
- [ ] Data is NUST-relevant: Pakistani names, real school names, realistic course codes.
