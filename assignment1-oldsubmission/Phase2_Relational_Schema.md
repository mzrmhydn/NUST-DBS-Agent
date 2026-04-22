# Phase 2 — Relational Schema Mapped from ER Diagram

The **relational schema** is the set of table definitions produced by formally mapping the ER diagram ([db/ERD.mmd](db/ERD.mmd)) to the relational model. This document shows the mapping *step by step* — every entity, every relationship, every constraint — so the reader can trace each line of the DDL in [db/NUST.sql](db/NUST.sql) back to the ER decision that produced it.

Notation:
- **relation_name**(<u>pk_col</u>, col2, col3, *fk_col*) — bold name, underlined PK attribute(s), `*` prefix for FK attributes.
- Composite PKs are shown as **{col1, col2}** with both underlined.
- `UNIQUE` columns are noted inline where relevant.

---

## 1. Mapping rules applied

This schema uses the six standard ER→Relational mapping rules:

| Rule | ER construct | Relational result |
| --- | --- | --- |
| R1 | Strong entity | One relation. PK = entity's key attribute. |
| R2 | 1:1 relationship | FK on one side, marked `UNIQUE NOT NULL`. |
| R3 | 1:N relationship | FK on the *many* side, referencing the *one* side's PK. |
| R4 | M:N relationship | New junction relation. PK = composite of both FKs (plus relationship attributes as non-key columns). |
| R5 | Multi-valued attribute | New relation with `(OwnerPK, Value)` as a composite PK. |
| R6 | Weak entity | Relation with composite PK `(OwnerFK, PartialKey)`. |

The NUST domain has **no weak entities** and **no multi-valued attributes** — every strong entity has its own natural PK. Rules R1, R2, R3, and R4 are all in play. One relation (`student`) carries a **deliberate BCNF violation** for query convenience — see §5.

---

## 2. Entities → relations (R1)

Eight strong entities map directly to their own relations.

**school**(<u>school_id</u>, school_name, abbreviation, established_year)

**faculty**(<u>faculty_id</u>, *school_id*, full_name, email, designation)
→ `*school_id` added by Rule R3: School 1→N Faculty.

**program**(<u>program_id</u>, *school_id*, program_name, total_semesters, total_credits, total_seats, degree_type)
→ `*school_id` added by Rule R3: School 1→N Program.

**course**(<u>course_code</u>, *school_id*, course_title, credit_hours, contact_hours, course_type)
→ `*school_id` added by Rule R3: School 1→N Course. `course_code` (e.g. `'CS220'`) is a natural human-readable key — no surrogate integer.

**term**(<u>term_id</u>, term_name, academic_year, start_date, end_date)

**classroom**(<u>classroom_id</u>, building, room_number, capacity)

**applicant**(<u>applicant_id</u>, full_name, cnic, email, high_school_board, high_school_score, best_test_score)
→ No `first_name`/`last_name` split — single `full_name` column. No `city` or `phone`.

**entry_test**(<u>test_id</u>, test_type, test_date, total_marks)

---

## 3. 1:N and 1:1 relationships (R2, R3)

### 3.1 Application — many-to-one from Applicant, Program, Term (R3, three times)

**application**(<u>application_id</u>, *applicant_id*, *program_id*, *term_id*, snapshot_hs_score, snapshot_best_test, aggregate_score, submission_date, status)

`status` ∈ {`Pending`, `Selected`, `Waitlisted`, `Rejected`, `Enrolled`, `Declined`}.
`snapshot_hs_score` and `snapshot_best_test` are point-in-time copies of the applicant's scores frozen at submission time.

### 3.2 Offer — 1:1 with Application (R2)

**offer**(<u>offer_id</u>, *application_id* UNIQUE, issue_date, expiry_date, status)

`application_id` carries a `UNIQUE NOT NULL` constraint: at most one offer per application; most applications have no offer. `status` ∈ {`Issued`, `Accepted`, `Declined`, `Expired`}.

### 3.3 Student — 1:1 with Applicant, many-to-one from Program (deliberate denormalization)

**student**(<u>student_id</u>, *program_id*, *applicant_id* UNIQUE, full_name, email, current_semester, enrollment_date)

`applicant_id` is `UNIQUE`: every student maps to exactly one applicant. `program_id` is stored **directly** rather than being reached via the chain `applicant → application → program`. This is a deliberate BCNF violation; see §5.

### 3.4 Section — many-to-one from Course, Term, Classroom, Faculty (R3, four times)

**section**(<u>section_id</u>, *course_code*, *term_id*, *classroom_id*, *faculty_id*, section_label)

All four foreign keys are mandatory. The composite `(course_code, term_id, section_label)` is `UNIQUE` — a given course cannot be offered twice under the same label in the same term.

---

## 4. M:N relationships → junction relations (R4)

### 4.1 Course self-referential prerequisite

**prerequisite**({<u>course_code</u>, <u>prereq_course_code</u>})

Both columns are FK references to `course`. The 2-column composite PK is the only key. There are no non-key attributes.

### 4.2 Program ↔ Course (via `program_course`)

**program_course**({<u>program_id</u>, <u>course_code</u>}, recommended_semester, is_core)

`is_core` is a BOOLEAN — there is no `'Core'`/`'Elective'` text column on this table. `recommended_semester` can differ across programs for the same course.

### 4.3 Applicant ↔ EntryTest (via `test_attempt`)

**test_attempt**({<u>applicant_id</u>, <u>test_id</u>}, score)

An applicant may sit many NET series; each series is attempted by many applicants. `score` is the sole relationship attribute. There is no `attempt_date` column.

### 4.4 Student ↔ Section (via `enrollment`)

**enrollment**({<u>student_id</u>, <u>section_id</u>}, attendance_percentage, grade)

`grade` ∈ {`A`, `A-`, `B+`, `B`, `B-`, `C+`, `C`, `C-`, `D+`, `D`, `F`} or `NULL`. `grade IS NULL` signals an in-progress enrollment — there is no separate `status` column.

---

## 5. Intentional BCNF violation — `student`

In a fully normalized schema, `student` would carry **only** `applicant_id` and reach the admitted program via the join chain:

```
student.applicant_id
  → application.applicant_id   (join on applicant_id)
  → application.program_id     (read program from the accepted application)
```

Storing `student.program_id` directly creates a cross-table transitive dependency:

```
student.applicant_id  →  application.program_id  =  student.program_id
```

This means `student.program_id` is a **denormalized copy** of `application.program_id`. If the application's program ever changed, `student.program_id` would need to be updated in lockstep — a classic update anomaly.

The schema accepts this risk because:

1. In practice, an admitted student's program does not change after enrollment.
2. The trigger `auto_update_application_status` (AFTER INSERT on `student`) synchronizes related status columns on insert and enforces consistency at the only write-time that matters.
3. Direct access to `student.program_id` eliminates a two-join navigation for the most common query pattern ("how many students are in program X?"), which runs on every dashboard load.

The violation is **deliberate and documented**. Every other relation in the schema is in BCNF.

---

## 6. Consolidated relational schema (final)

```text
R1.  school         (<u>school_id</u>, school_name, abbreviation, established_year)

R2.  faculty        (<u>faculty_id</u>, *school_id, full_name, email, designation)

R3.  program        (<u>program_id</u>, *school_id, program_name, total_semesters,
                      total_credits, total_seats, degree_type)

R4.  course         (<u>course_code</u>, *school_id, course_title, credit_hours,
                      contact_hours, course_type)

R5.  prerequisite   ({course_code, prereq_course_code})
                      -- both FK → course; no non-key attributes

R6.  program_course ({program_id, course_code}, recommended_semester, is_core)

R7.  term           (<u>term_id</u>, term_name, academic_year, start_date, end_date)

R8.  classroom      (<u>classroom_id</u>, building, room_number, capacity)

R9.  applicant      (<u>applicant_id</u>, full_name, cnic, email, high_school_board,
                      high_school_score, best_test_score)

R10. entry_test     (<u>test_id</u>, test_type, test_date, total_marks)

R11. test_attempt   ({applicant_id, test_id}, score)
                      -- composite PK; both FK → their parent tables

R12. application    (<u>application_id</u>, *applicant_id, *program_id, *term_id,
                      snapshot_hs_score, snapshot_best_test, aggregate_score,
                      submission_date, status)

R13. offer          (<u>offer_id</u>, *application_id UNIQUE, issue_date, expiry_date,
                      status)

R14. student        (<u>student_id</u>, *program_id, *applicant_id UNIQUE,
                      full_name, email, current_semester, enrollment_date)
                      -- ⚠ deliberate BCNF violation: program_id is denormalized

R15. section        (<u>section_id</u>, *course_code, *term_id, *classroom_id,
                      *faculty_id, section_label)

R16. enrollment     ({student_id, section_id}, attendance_percentage, grade)
                      -- composite PK; grade IS NULL = in progress
```

---

## 7. Foreign-key dependency graph

```
school ◄────────── faculty
  ▲
  ├──────────────► program ◄────── program_course ◄──── course ◄─ prerequisite (self-ref)
  │                   │
  │                   ▼
  │              application ◄──── applicant ──────► test_attempt ──► entry_test
  │                   │
  │                   ▼
  │                 offer
  │
  │            applicant ──► student ──► program   (denormalized direct FK)
  │
  ├──────────────► classroom ──┐
  │                            ├──► section
  ├──────────────► term ───────┘       │
  │                            ▲       ▼
  └──────────────► faculty ────┘   enrollment ◄── student
```

Every arrow represents a `FOREIGN KEY` clause in [db/NUST.sql](db/NUST.sql).

---

## 8. Correspondence to the DDL

Every relation above has a counterpart `CREATE TABLE` statement in [db/NUST.sql](db/NUST.sql). The mapping lets a reviewer answer *"why is this column here?"* for every column — the answer always traces back to one of the rules R1–R4 applied to one specific ER construct.
