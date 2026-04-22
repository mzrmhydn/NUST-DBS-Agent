# NUST University Database — Full Schema Explanation

## Overview

This is a university management database for NUST (National University of Sciences and Technology). It covers the complete lifecycle from **applicant → student**, and manages schools, programs, courses, faculty, sections, classrooms, terms, enrollments, and admissions. There are **16 entities** in total.

---

## Entities & Their Attributes

### 1. `school`
The top-level organizational unit. Every program, course, and faculty member belongs to a school.

| Column | Type | Role |
|---|---|---|
| `school_id` | VARCHAR | Primary Key |
| `school_name` | VARCHAR | Full name of the school |
| `abbreviation` | VARCHAR | Short form (e.g., SEECS, SCME) |
| `established_year` | SMALLINT | Year the school was founded |

---

### 2. `faculty`
Represents teaching staff employed by a school.

| Column | Type | Role |
|---|---|---|
| `faculty_id` | VARCHAR | Primary Key |
| `school_id` | VARCHAR | FK → `school` |
| `full_name` | VARCHAR | Faculty member's name |
| `email` | VARCHAR | Institutional email |
| `designation` | VARCHAR | Title (e.g., Lecturer, Professor) |

---

### 3. `program`
An academic program (e.g., BS Computer Science) offered by a school.

| Column | Type | Role |
|---|---|---|
| `program_id` | VARCHAR | Primary Key |
| `school_id` | VARCHAR | FK → `school` |
| `program_name` | VARCHAR | Full program title |
| `degree_type` | ENUM | Type of degree (e.g., BS, MS, PhD) |
| `total_semesters` | TINYINT | Number of semesters in the program |
| `total_credits` | SMALLINT | Total credit hours required to graduate |
| `total_seats` | SMALLINT | Number of seats available per intake |

---

### 4. `course`
An individual course/subject owned by a school.

| Column | Type | Role |
|---|---|---|
| `course_code` | VARCHAR | Primary Key |
| `school_id` | VARCHAR | FK → `school` |
| `course_title` | VARCHAR | Name of the course |
| `course_type` | ENUM | Category (e.g., Theory, Lab, Project) |
| `credit_hours` | TINYINT | Credit weight |
| `contact_hours` | TINYINT | Weekly contact/teaching hours |

---

### 5. `prerequisite`
A **junction/bridge table** that maps prerequisite relationships between courses. It is a **composite primary key** table — both columns together form the PK, meaning the same pair cannot repeat.

| Column | Type | Role |
|---|---|---|
| `course_code` | VARCHAR | PK — the course that has a prerequisite |
| `prereq_course_code` | VARCHAR | PK — the course that must be done first |

> A course can have multiple prerequisites, and a course can be a prerequisite of multiple others — this is modeled as a self-referencing many-to-many on the `course` table.

---

### 6. `program_course`
A **junction table** that maps which courses are part of which program (the curriculum mapping). Composite PK on `(program_id, course_code)`.

| Column | Type | Role |
|---|---|---|
| `program_id` | VARCHAR | PK — FK → `program` |
| `course_code` | VARCHAR | PK — FK → `course` |
| `recommended_semester` | TINYINT | Suggested semester to take the course |
| `is_core` | BOOLEAN | Whether the course is core (true) or elective (false) |

---

### 7. `term`
An academic term/semester period (e.g., Fall 2024).

| Column | Type | Role |
|---|---|---|
| `term_id` | VARCHAR | Primary Key |
| `term_name` | ENUM | Season/type (e.g., Fall, Spring, Summer) |
| `academic_year` | SMALLINT | The year it belongs to |
| `start_date` | DATE | Term start date |
| `end_date` | DATE | Term end date |

---

### 8. `classroom`
A physical room available for scheduling sections.

| Column | Type | Role |
|---|---|---|
| `classroom_id` | VARCHAR | Primary Key |
| `building` | VARCHAR | Building name/code |
| `room_number` | VARCHAR | Room identifier within the building |
| `capacity` | SMALLINT | Maximum seating capacity |

---

### 9. `section`
A specific offering/instance of a course in a particular term — taught by a faculty member in a classroom. This is the schedulable unit students enroll in.

| Column | Type | Role |
|---|---|---|
| `section_id` | VARCHAR | Primary Key |
| `course_code` | VARCHAR | FK → `course` |
| `term_id` | VARCHAR | FK → `term` |
| `classroom_id` | VARCHAR | FK → `classroom` |
| `faculty_id` | VARCHAR | FK → `faculty` |
| `section_label` | VARCHAR | Label to distinguish sections (e.g., A, B, C) |

---

### 10. `enrollment`
Records a student's enrollment in a specific section. Composite PK on `(student_id, section_id)` — a student can only be enrolled once in any given section.

| Column | Type | Role |
|---|---|---|
| `student_id` | VARCHAR | PK — FK → `student` |
| `section_id` | VARCHAR | PK — FK → `section` |
| `attendance_percentage` | DECIMAL | Student's attendance in that section |
| `grade` | ENUM | Final grade awarded (e.g., A, B+, F) |

---

### 11. `student`
A currently enrolled student at the university. A student is always tied to a program and always originates from an applicant.

| Column | Type | Role |
|---|---|---|
| `student_id` | VARCHAR | Primary Key |
| `program_id` | VARCHAR | FK → `program` |
| `applicant_id` | VARCHAR | FK → `applicant` |
| `full_name` | VARCHAR | Student's full name |
| `email` | VARCHAR | University-assigned email |
| `current_semester` | TINYINT | Which semester the student is currently in |
| `enrollment_date` | DATE | Date of first enrollment |
| `gpa` | DECIMAL | Grade point average |

---

### 12. `applicant`
A person who applies for admission. They exist before becoming a student, and may or may not ever become one.

| Column | Type | Role |
|---|---|---|
| `applicant_id` | VARCHAR | Primary Key |
| `full_name` | VARCHAR | Applicant's full name |
| `cnic` | VARCHAR | National ID number (unique identifier) |
| `email` | VARCHAR | Personal email |
| `high_school_board` | ENUM | Board of education (e.g., Federal, Punjab, Sindh) |
| `high_school_score` | DECIMAL | Matric/FSc percentage |
| `best_test_score` | DECIMAL | Best score across all entry test attempts |

---

### 13. `entry_test`
Represents a scheduled entry test event (e.g., NET, SAT).

| Column | Type | Role |
|---|---|---|
| `test_id` | VARCHAR | Primary Key |
| `test_type` | ENUM | Type of test (e.g., NET, SAT, GAT) |
| `test_date` | DATE | Date the test was held |
| `total_marks` | SMALLINT | Maximum possible marks for this test |

---

### 14. `test_attempt`
Records a specific applicant's attempt at a specific entry test. Composite PK on `(applicant_id, test_id)` — one record per applicant per test.

| Column | Type | Role |
|---|---|---|
| `applicant_id` | VARCHAR | PK — FK → `applicant` |
| `test_id` | VARCHAR | PK — FK → `entry_test` |
| `score` | DECIMAL | Score achieved in this attempt |

---

### 15. `application`
A formal admission application submitted by an applicant to a specific program in a specific intake term.

| Column | Type | Role |
|---|---|---|
| `application_id` | VARCHAR | Primary Key |
| `applicant_id` | VARCHAR | FK → `applicant` |
| `program_id` | VARCHAR | FK → `program` |
| `term_id` | VARCHAR | FK → `term` (the intake term) |
| `snapshot_hs_score` | DECIMAL | High school score at time of application (frozen snapshot) |
| `snapshot_best_test` | DECIMAL | Best test score at time of application (frozen snapshot) |
| `aggregate_score` | DECIMAL | Computed merit/aggregate score used for ranking |
| `submission_date` | DATE | When the application was submitted |
| `status` | ENUM | Current state (e.g., Pending, Accepted, Rejected) |

> The two snapshot fields are important — they freeze the applicant's scores at the time of submission so future changes to the applicant record don't alter historical applications.

---

### 16. `offer`
An admission offer issued to a successful application.

| Column | Type | Role |
|---|---|---|
| `offer_id` | VARCHAR | Primary Key |
| `application_id` | VARCHAR | FK → `application` |
| `issue_date` | DATE | Date the offer was issued |
| `expiry_date` | DATE | Deadline for the applicant to accept |
| `status` | ENUM | State of the offer (e.g., Issued, Accepted, Expired, Declined) |

---

## Relationships

### School-Level Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `school` → `faculty` | One-to-Many (1 to 1+) | A school employs one or more faculty members; each faculty belongs to exactly one school |
| `school` → `program` | One-to-Many (1 to 1+) | A school offers one or more programs |
| `school` → `course` | One-to-Many (1 to 1+) | A school owns one or more courses |

### Program Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `program` → `student` | One-to-Many (1 to 0+) | A program can have zero or more students registered in it |
| `program` → `application` | One-to-Many (1 to 1+) | A program receives one or more applications |
| `program` → `program_course` | One-to-Many (1 to 1+) | A program requires one or more course mappings (its curriculum) |

### Course Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `course` → `program_course` | One-to-Many (1 to 1+) | A course can be mapped to one or more programs |
| `course` → `section` | One-to-Many (1 to 0+) | A course can be offered as zero or more sections across terms |
| `course` → `prerequisite` (as dependent) | One-to-Many (1 to 0+) | A course can have zero or more prerequisites |
| `course` → `prerequisite` (as prereq) | One-to-Many (1 to 0+) | A course can be a prerequisite of zero or more other courses |

> The double relationship between `course` and `prerequisite` is a **self-referencing many-to-many**, split into two labeled roles in the ERD: `"has_prereq"` and `"is_prereq_of"`.

### Scheduling Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `term` → `section` | One-to-Many (1 to 1+) | A term contains one or more sections |
| `term` → `application` | One-to-Many (1 to 1+) | A term serves as an intake for one or more applications |
| `classroom` → `section` | One-to-Many (1 to 0+) | A classroom can host zero or more sections |
| `faculty` → `section` | One-to-Many (1 to 0+) | A faculty member can teach zero or more sections |

### Enrollment Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `student` → `enrollment` | One-to-Many (1 to 1+) | A student must have one or more enrollment records |
| `section` → `enrollment` | One-to-Many (1 to 1+) | A section must have one or more enrolled students |

### Admissions Pipeline Relationships
| Relationship | Cardinality | Meaning |
|---|---|---|
| `applicant` → `application` | One-to-Many (1 to 1+) | An applicant can submit one or more applications (e.g., to different programs) |
| `applicant` → `test_attempt` | One-to-Many (1 to 1+) | An applicant can attempt one or more entry tests |
| `entry_test` → `test_attempt` | One-to-Many (1 to 1+) | An entry test can be taken by one or more applicants |
| `applicant` → `student` | One-to-Zero-or-One (1 to 0\|1) | An applicant may or may not become a student — at most one student record per applicant |
| `application` → `offer` | One-to-Zero-or-One (1 to 0\|1) | An application may or may not yield an offer — at most one offer per application |

---

## Key Design Observations

1. **Snapshot Fields in `application`** — `snapshot_hs_score` and `snapshot_best_test` intentionally duplicate data from `applicant` to preserve the state of scores at submission time, protecting historical integrity if the applicant's record is later updated.

2. **Self-referencing Many-to-Many on `course`** — The `prerequisite` table handles a course depending on another course, using a composite PK of `(course_code, prereq_course_code)` so the same dependency can't be recorded twice.

3. **`applicant` → `student` is a one-to-zero-or-one** — Not every applicant gets admitted; the FK `applicant_id` on `student` links back so you can always trace a student's origin application history.

4. **`offer` is separate from `application`** — An application going through the review process and an offer being formally issued are modeled as distinct events, allowing the `application.status` and `offer.status` to evolve independently.

5. **`section` is the central scheduling entity** — It ties together `course`, `term`, `classroom`, and `faculty` into a single schedulable unit, which `enrollment` then references for student-course tracking.

6. **All Primary Keys are VARCHAR** — Meaningful string-based IDs (e.g., `"SEECS"`, `"CS-101"`, `"FA2024"`) rather than auto-incremented integers, which aids readability and portability.

7. **Grade Letters as ENUM** — Allowed values on enrollment.grade:
'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F'
Grade is an ENUM that is NULL while the enrollment is still in progress or a grade has not yet been reported (no separate status column).