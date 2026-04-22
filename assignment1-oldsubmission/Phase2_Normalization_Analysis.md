# Phase 2 — Normalization Analysis

This document proves that every relation in the NUST schema ([db/NUST.sql](db/NUST.sql)) is in **Third Normal Form (3NF)** and, with one deliberate exception, in **Boyce–Codd Normal Form (BCNF)**. The analysis proceeds in the usual three steps: list the functional dependencies (FDs), identify the candidate keys, then check each FD against the 3NF / BCNF definitions.

Definitions used below:

- An **FD** `X → Y` holds on relation `R` iff every pair of `R`-tuples that agree on `X` also agree on `Y`.
- A **superkey** is any attribute set `X` such that `X → R`.
- A **candidate key** is a minimal superkey.
- A **prime attribute** is an attribute that belongs to at least one candidate key.
- **3NF.** For every non-trivial FD `X → A`, either `X` is a superkey, or `A` is prime.
- **BCNF.** For every non-trivial FD `X → A`, `X` is a superkey.

BCNF is strictly stronger than 3NF. A relation in BCNF is automatically in 3NF.

---

## 1. Starting point — unnormalized form (UNF)

A naive flat spreadsheet of a student's record looks like:

```text
ApplicantName | CNIC | NET1_Score | NET2_Score | Applied_Prog_1 | Applied_Prog_2
| Accepted_Prog | CourseCode_1 | CourseName_1 | Grade_1 | FacultyName_1
| FacultyTitle_1 | RoomNumber_1 | RoomCapacity_1 | TermName_1 | …
```

This violates 1NF in three distinct ways — repeating groups (`NET*_Score`, `Applied_Prog_*`, `CourseCode_*`), composite attributes (`FacultyName` = first + last), and multi-valued attributes (several grades per student).

**1NF fix** — extract repeating groups into their own relations:
- `NET1_Score`, `NET2_Score`, `NET3_Score` → `test_attempt(applicant_id, test_id, score)`
- `Applied_Prog_1`, `Applied_Prog_2` → `application(applicant_id, program_id, …)`
- `CourseCode_*`, `Grade_*` → `enrollment(student_id, section_id, grade)`

---

## 2. Per-relation FD analysis and 3NF / BCNF proof

### 2.1 `school(school_id, school_name, abbreviation, established_year)`

**FDs.**
- `school_id → school_name, abbreviation, established_year`
- `school_name → school_id, abbreviation, established_year` (UNIQUE)
- `abbreviation → school_id, school_name, established_year` (UNIQUE)

**Candidate keys:** `{school_id}`, `{school_name}`, `{abbreviation}`.

All determinants are superkeys. **BCNF ✓**.

---

### 2.2 `faculty(faculty_id, school_id, full_name, email, designation)`

**FDs.**
- `faculty_id → school_id, full_name, email, designation`
- `email → faculty_id, school_id, full_name, designation` (UNIQUE)

**Candidate keys:** `{faculty_id}`, `{email}`.

Both determinants are superkeys. **BCNF ✓**.

---

### 2.3 `program(program_id, school_id, program_name, total_semesters, total_credits, total_seats, degree_type)`

**FDs.**
- `program_id → school_id, program_name, total_semesters, total_credits, total_seats, degree_type`

**Candidate key:** `{program_id}`.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

Note: `school_id` is a foreign key; `program` does not store `school_name`. If it did, `school_id → school_name` would create the transitive chain `program_id → school_id → school_name` and break 3NF.

---

### 2.4 `course(course_code, school_id, course_title, credit_hours, contact_hours, course_type)`

**FDs.**
- `course_code → school_id, course_title, credit_hours, contact_hours, course_type`

**Candidate key:** `{course_code}` — the natural key; no surrogate integer.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

---

### 2.5 `prerequisite(course_code, prereq_course_code)`

**FDs.**
- No non-trivial FDs beyond the trivial identity. Neither column alone determines the other.

**Candidate key:** `{course_code, prereq_course_code}`.

A pure 2-column junction: both attributes together form the composite PK and represent the entire relation. There are no non-key attributes, so every possible non-trivial FD would trivially have a superkey on the left. **BCNF ✓**.

---

### 2.6 `program_course(program_id, course_code, recommended_semester, is_core)`

**FDs.**
- `{program_id, course_code} → recommended_semester, is_core`

**Candidate key:** `{program_id, course_code}`.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

Note: `course_code → recommended_semester` does **not** hold — the same course can be recommended in a different semester across different programs. That asymmetry forces `recommended_semester` onto the junction rather than onto `course`.

---

### 2.7 `term(term_id, term_name, academic_year, start_date, end_date)`

**FDs.**
- `term_id → term_name, academic_year, start_date, end_date`
- `{term_name, academic_year} → term_id, start_date, end_date` (UNIQUE composite)

**Candidate keys:** `{term_id}`, `{term_name, academic_year}`.

Both determinants are superkeys. **BCNF ✓**.

---

### 2.8 `classroom(classroom_id, building, room_number, capacity)`

**FDs.**
- `classroom_id → building, room_number, capacity`
- `{building, room_number} → classroom_id, capacity` (UNIQUE composite)

**Candidate keys:** `{classroom_id}`, `{building, room_number}`.

Both determinants are superkeys. **BCNF ✓**.

---

### 2.9 `applicant(applicant_id, full_name, cnic, email, high_school_board, high_school_score, best_test_score)`

**FDs.**
- `applicant_id → full_name, cnic, email, high_school_board, high_school_score, best_test_score`
- `cnic → applicant_id, full_name, email, high_school_board, high_school_score, best_test_score` (UNIQUE)
- `email → applicant_id, full_name, cnic, high_school_board, high_school_score, best_test_score` (UNIQUE)

**Candidate keys:** `{applicant_id}`, `{cnic}`, `{email}`.

All determinants are superkeys. **BCNF ✓**.

---

### 2.10 `entry_test(test_id, test_type, test_date, total_marks)`

**FDs.**
- `test_id → test_type, test_date, total_marks`

**Candidate key:** `{test_id}`.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

---

### 2.11 `test_attempt(applicant_id, test_id, score)`

**FDs.**
- `{applicant_id, test_id} → score`

**Candidate key:** `{applicant_id, test_id}`.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

---

### 2.12 `application(application_id, applicant_id, program_id, term_id, snapshot_hs_score, snapshot_best_test, aggregate_score, submission_date, status)`

**FDs.**
- `application_id → applicant_id, program_id, term_id, snapshot_hs_score, snapshot_best_test, aggregate_score, submission_date, status`
- `{applicant_id, program_id, term_id} → application_id, snapshot_hs_score, snapshot_best_test, aggregate_score, submission_date, status` (UNIQUE composite)

**Candidate keys:** `{application_id}`, `{applicant_id, program_id, term_id}`.

Both determinants are superkeys. **BCNF ✓**.

Note: `snapshot_hs_score` and `snapshot_best_test` are point-in-time copies of the applicant's scores frozen at submission time, not live FK-derived values — this is intentional and does not create a normalization issue.

---

### 2.13 `offer(offer_id, application_id, issue_date, expiry_date, status)`

**FDs.**
- `offer_id → application_id, issue_date, expiry_date, status`
- `application_id → offer_id, issue_date, expiry_date, status` (UNIQUE)

**Candidate keys:** `{offer_id}`, `{application_id}`.

Both determinants are superkeys. **BCNF ✓**.

---

### 2.14 `student(student_id, program_id, applicant_id, full_name, email, current_semester, enrollment_date)` ⚠ intentional BCNF violation

**FDs (within the table).**
- `student_id → program_id, applicant_id, full_name, email, current_semester, enrollment_date`
- `applicant_id → student_id, program_id, full_name, email, current_semester, enrollment_date` (UNIQUE)

**Candidate keys (within the table):** `{student_id}`, `{applicant_id}`.

Considered *in isolation*, both determinants are superkeys and the table is in BCNF.

**However**, `program_id` is also transitively determinable *cross-table*:

```
student.applicant_id
  → application.applicant_id   (join)
  → application.program_id
```

This means `student.program_id` is a **denormalized copy** of `application.program_id`. In a fully normalized design, `student` would not carry `program_id` at all — the program would be reached via a two-table join. Storing it directly creates an **update anomaly**: if `application.program_id` ever changed, `student.program_id` would need to be updated in lockstep to avoid drift.

**Why we accept it.** An admitted student's program does not change post-enrollment. The trigger `auto_update_application_status` (AFTER INSERT on `student`) synchronizes status columns on insert. Direct access to `student.program_id` eliminates a two-join navigation for the most frequent query pattern ("how many students are in program X?"), which runs on every dashboard load.

**Verdict:** `student` is in **3NF** (no partial or transitive dependencies among *non-prime* attributes within the table), but breaks BCNF under the cross-table transitive chain. The violation is **deliberate and documented**.

---

### 2.15 `section(section_id, course_code, term_id, classroom_id, faculty_id, section_label)`

**FDs.**
- `section_id → course_code, term_id, classroom_id, faculty_id, section_label`
- `{course_code, term_id, section_label} → section_id, classroom_id, faculty_id` (UNIQUE composite)

**Candidate keys:** `{section_id}`, `{course_code, term_id, section_label}`.

Both determinants are superkeys. **BCNF ✓**.

Note: `classroom_id → capacity` holds cross-table through `classroom`, but `section` does not store `capacity` — so no transitive dependency exists within `section`.

---

### 2.16 `enrollment(student_id, section_id, attendance_percentage, grade)`

**FDs.**
- `{student_id, section_id} → attendance_percentage, grade`

**Candidate key:** `{student_id, section_id}`.

The only non-trivial FD has a superkey determinant. **BCNF ✓**.

Note: `grade IS NULL` signals an in-progress enrollment rather than a separate status column. This avoids the sentinel-value anti-pattern (`'IP'`, `'W'`) while keeping the schema narrow.

---

## 3. Summary table

| # | Relation | Candidate Keys | Highest NF | Notes |
| --- | --- | --- | --- | --- |
| 1 | school | `{school_id}`, `{school_name}`, `{abbreviation}` | BCNF | Three candidate keys. |
| 2 | faculty | `{faculty_id}`, `{email}` | BCNF | |
| 3 | program | `{program_id}` | BCNF | No denormalization of `school_name`. |
| 4 | course | `{course_code}` | BCNF | Natural key — no surrogate. |
| 5 | prerequisite | `{course_code, prereq_course_code}` | BCNF | 2-column junction; trivially BCNF. |
| 6 | program_course | `{program_id, course_code}` | BCNF | `recommended_semester` on junction, not on `course`. |
| 7 | term | `{term_id}`, `{term_name, academic_year}` | BCNF | |
| 8 | classroom | `{classroom_id}`, `{building, room_number}` | BCNF | |
| 9 | applicant | `{applicant_id}`, `{cnic}`, `{email}` | BCNF | Three candidate keys. |
| 10 | entry_test | `{test_id}` | BCNF | |
| 11 | test_attempt | `{applicant_id, test_id}` | BCNF | |
| 12 | application | `{application_id}`, `{applicant_id, program_id, term_id}` | BCNF | Snapshot scores are not live FK-derived values — intentional. |
| 13 | offer | `{offer_id}`, `{application_id}` | BCNF | |
| 14 | **student** | `{student_id}`, `{applicant_id}` | **3NF** | **Deliberate BCNF violation** — `program_id` is a denormalized cross-table transitive copy. |
| 15 | section | `{section_id}`, `{course_code, term_id, section_label}` | BCNF | |
| 16 | enrollment | `{student_id, section_id}` | BCNF | `grade IS NULL` = in progress; no status column. |

Fifteen of sixteen relations are in **BCNF**. The one exception (`student`) is deliberately in **3NF** with a documented and bounded cross-table denormalization.

---

## 4. What we consciously did *not* do

A few denormalizations are tempting and common in real-world databases. We rejected each for a concrete reason:

| Tempting denormalization | Why it would break BCNF | What we did instead |
| --- | --- | --- |
| `program.school_name` | `school_id → school_name` would live inside `program`, giving the transitive chain `program_id → school_id → school_name`. | Store only `school_id`; join `school` when the name is needed. |
| `section.capacity` | `classroom_id → capacity` would live inside `section`, giving `section_id → classroom_id → capacity`. | Store `capacity` on `classroom`; join when needed. Trigger checks it directly. |
| `enrollment.status` sentinel | Doesn't break BCNF, but collapses a valid two-state machine and invites `'IP'`/`'W'` sentinel values that break every `AVG(grade)`. | Use `grade IS NULL` to signal in progress — no second column needed. |
| `student.application_id` | Would introduce a third candidate key without benefit; program and applicant are already reachable directly. | Reach program via `student.program_id` (denormalized) and applicant via `student.applicant_id`. |

And one denormalization we **did** accept: `student.program_id` (see §2.14).

---

## 5. Closing note

The payoff of being in BCNF here is not abstract. Each rejected denormalization would have created a concrete class of drift bug — `program.school_name` diverging from `school.school_name`, `section.capacity` diverging from `classroom.capacity` — that the database could not prevent. BCNF is what lets us enforce every business invariant with declarative constraints and stop worrying about drift.

The one documented exception (`student.program_id`) was accepted with full awareness of the trade-off: a narrow real-world update window makes the anomaly risk negligible, and the query-convenience gain is large. Every other relation is clean.
