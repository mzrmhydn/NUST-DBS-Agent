# Phase 2 — Relational Schema Mapped from ER Diagram

The **relational schema** is the set of table definitions produced by formally mapping the ER diagram ([db/ERD.mmd](db/ERD.mmd)) to the relational model. This document shows the mapping *step by step* — every entity, every relationship, every constraint — so the reader can trace each line of the DDL in [db/NUST.sql](db/NUST.sql) back to the ER decision that produced it.

Notation:
- `R(A, B, C)` — relation (table) `R` with attributes `A`, `B`, `C`.
- `__X__` — primary-key attribute (underlined in the ER diagram).
- `*X` — foreign-key attribute (FK).
- `{A, B}` — composite primary key.

---

## 1. Mapping rules applied

This schema uses the six standard ER→Relational mapping rules:

| Rule | ER construct | Relational result |
| --- | --- | --- |
| R1 | Strong entity | One relation. PK = entity's key attribute. |
| R2 | 1:1 relationship | FK on one side, marked `UNIQUE NOT NULL`. |
| R3 | 1:N relationship | FK on the *many* side, referencing the *one* side's PK. |
| R4 | M:N relationship | New junction relation. PK = composite of both FKs (plus relationship attributes, if any, as non-key columns). |
| R5 | Multi-valued attribute | New relation with `(OwnerPK, Value)` as a composite PK. |
| R6 | Weak entity | Relation with composite PK `(OwnerFK, PartialKey)`. |

The NUST domain has **no weak entities** and **no multi-valued attributes** — every entity has its own surrogate key (`AUTO_INCREMENT INT`), so only rules R1 / R3 / R4 and one application of R2 (Student ↔ Application) are in play.

---

## 2. Entities → relations (R1)

Each of the 11 strong entities becomes one relation with an `AUTO_INCREMENT` surrogate PK.

```text
School       (__SchoolID__,      Name UNIQUE, Location, EstablishedYear)
Program      (__ProgramID__,     *SchoolID,   ProgramName, DegreeType,
                                  DurationYears ∈ [1,7], TotalSeats > 0)           -- SchoolID from R3
Applicant    (__ApplicantID__,   FirstName, LastName, Email UNIQUE, Phone, DOB,
                                  HighSchoolMarks ∈ [0,1100], City)
EntryTest    (__TestID__,        SeriesName UNIQUE, TestDate,
                                  TestType ∈ {Engineering, Business, Architecture,
                                              Biosciences, Chemical})
Instructor   (__InstructorID__,  *SchoolID, FirstName, LastName,
                                  Title ∈ {Lecturer, Assistant Professor,
                                           Associate Professor, Professor},
                                  Email UNIQUE, HireDate)
Course       (__CourseID__,      *SchoolID, CourseCode UNIQUE, CourseName,
                                  Credits ∈ [1,6])
Term         (__TermID__,        TermName UNIQUE, StartDate, EndDate > StartDate)
Classroom    (__ClassroomID__,   *SchoolID, RoomNumber, Capacity > 0,
                                  RoomType ∈ {Lecture, Lab, Studio, Hall},
                                  UNIQUE (SchoolID, RoomNumber))
```

The remaining four "entities" (`TestScore`, `Application`, `ProgramCourse`, `Enrollment`) are **junction tables** produced by rule R4 — see §4. `Student` is produced by rule R2 — see §3. `Section` and `Fee` are produced by rule R3 with multiple contributing relationships — see §3.

---

## 3. 1:N and 1:1 relationships (R2, R3)

Each 1:N relationship becomes an FK column on the *many* side, referencing the PK on the *one* side. The 1:1 relationship `Application ↔ Student` becomes a `UNIQUE NOT NULL` FK on the `Student` side.

| Relationship | Mapping rule | Column added | Cardinality note |
| --- | --- | --- | --- |
| School → Program | R3 | `Program.SchoolID` NOT NULL | Mandatory-many (`1 : 1..N`). |
| School → Instructor | R3 | `Instructor.SchoolID` NOT NULL | Optional-many. |
| School → Classroom | R3 | `Classroom.SchoolID` NOT NULL | Optional-many. |
| School → Course | R3 | `Course.SchoolID` NOT NULL | Course is owned by the *teaching* school, not by any program. |
| Applicant → Application | R3 | `Application.ApplicantID` NOT NULL | See §4 (junction). |
| Program → Application | R3 | `Application.ProgramID` NOT NULL | See §4 (junction). |
| **Application ↔ Student** | **R2** | `Student.ApplicationID` UNIQUE NOT NULL | Every Student row points at exactly one accepted Application; most applications have no Student. |
| Course → Section | R3 | `Section.CourseID` NOT NULL | |
| Term → Section | R3 | `Section.TermID` NOT NULL | |
| Instructor → Section | R3 | `Section.InstructorID` NOT NULL | |
| Classroom → Section | R3 | `Section.ClassroomID` NOT NULL | A Section sits at the intersection of *four* 1:N relationships — all four FKs are mandatory. |
| Application → Fee (processing) | R3 | `Fee.ApplicationID` NULLABLE | XOR-constrained. See §5. |
| Student → Fee (tuition/hostel/library) | R3 | `Fee.StudentID` NULLABLE | XOR-constrained. See §5. |

Resulting relations:

```text
Student   (__StudentID__, *ApplicationID UNIQUE NOT NULL, EnrollmentDate,
                           CGPA ∈ [0.00,4.00], Status ∈ {Active, Graduated,
                                                         Suspended, Withdrawn})
Section   (__SectionID__, *CourseID, *TermID, *InstructorID, *ClassroomID,
                           SectionName,
                           UNIQUE (CourseID, TermID, SectionName))
```

---

## 4. M:N relationships → junction relations (R4)

Four M:N relationships are mapped to their own relations. Two of them (`TestScore`, `Enrollment`) are "pure" junctions with a surrogate PK plus a `UNIQUE` composite; two of them (`Application`, `ProgramCourse`) carry relationship attributes.

### 4.1 Applicant ⟷ EntryTest (via `TestScore`)

```text
TestScore (__TestScoreID__, *ApplicantID NOT NULL, *TestID NOT NULL,
                             Score ∈ [0, 200],
                             UNIQUE (ApplicantID, TestID))
```

A candidate may sit many NET series; each series is attempted by many candidates. `Score` is the relationship attribute.

### 4.2 Applicant ⟷ Program (via `Application`, with attributes)

```text
Application (__ApplicationID__, *ApplicantID NOT NULL, *ProgramID NOT NULL,
                                 ApplicationDate, Preference ∈ [1, 5],
                                 Status ∈ {Pending, Selected, Waitlisted,
                                           Rejected, Enrolled, Declined},
                                 UNIQUE (ApplicantID, ProgramID))
```

`Preference` and `Status` are relationship attributes — they describe the *act* of applying, not the applicant or the program. `UNIQUE (ApplicantID, ProgramID)` prevents a candidate from applying twice to the same program.

### 4.3 Program ⟷ Course (via `ProgramCourse`, with attributes)

```text
ProgramCourse ({ProgramID, CourseID},
                *ProgramID NOT NULL, *CourseID NOT NULL,
                CourseType ∈ {Core, Elective} DEFAULT 'Core',
                Semester ∈ [1, 10])
```

The canonical M:N case: `Programming Fundamentals` (CS118) is a single `Course` row that maps to BSCS, BESE, and BEE via three `ProgramCourse` rows. The same course can be `Core` for BSCS and `Elective` for BESE — that's why `CourseType` lives on the junction, not on `Course`.

### 4.4 Student ⟷ Section (via `Enrollment`)

```text
Enrollment (__EnrollmentID__, *StudentID NOT NULL, *SectionID NOT NULL,
                               Grade ∈ {A, A-, B+, B, B-, C+, C, C-, D+, D, F}
                                      OR NULL,
                               Status ∈ {InProgress, Completed, Withdrawn},
                               UNIQUE (StudentID, SectionID),
                               CHECK ((Status='Completed'  AND Grade IS NOT NULL)
                                   OR (Status<>'Completed' AND Grade IS NULL)))
```

Grade and status are factored into *two* columns rather than a single overloaded grade column.

---

## 5. The unified Fee ledger (R3, twice, with an XOR guard)

`Fee` sits at the intersection of **two** 1:N relationships — `Application → Fee` for processing fees and `Student → Fee` for tuition / hostel / library — instead of being split into two tables. This is unusual enough to be worth calling out.

```text
Fee (__FeeID__, *ApplicationID NULLABLE, *StudentID NULLABLE,
                 FeeType ∈ {Application, Tuition, Hostel, Library},
                 Amount ≥ 0, PaymentDate,
                 Method ∈ {Bank, Online, Cheque, Cash},
                 CHECK ((FeeType='Application'
                          AND ApplicationID IS NOT NULL
                          AND StudentID IS NULL)
                     OR (FeeType IN ('Tuition','Hostel','Library')
                          AND StudentID IS NOT NULL
                          AND ApplicationID IS NULL)),
                 UNIQUE (ApplicationID))        -- at most one Application fee per Application
                                                -- (MySQL allows multiple NULLs in a UNIQUE index,
                                                --  so Student-fee rows are unaffected)
```

The XOR `CHECK` enforces the invariant that a fee row has *exactly one* payer. Without it, this single-ledger design would degenerate into a loose polymorphic table.

---

## 6. Consolidated relational schema (final)

```text
R1.  School        (__SchoolID__, Name, Location, EstablishedYear)
R2.  Program       (__ProgramID__, *SchoolID, ProgramName, DegreeType,
                     DurationYears, TotalSeats)
R3.  Applicant     (__ApplicantID__, FirstName, LastName, Email, Phone,
                     DOB, HighSchoolMarks, City)
R4.  EntryTest     (__TestID__, SeriesName, TestDate, TestType)
R5.  TestScore     (__TestScoreID__, *ApplicantID, *TestID, Score)
R6.  Application   (__ApplicationID__, *ApplicantID, *ProgramID,
                     ApplicationDate, Preference, Status)
R7.  Student       (__StudentID__, *ApplicationID, EnrollmentDate, CGPA, Status)
R8.  Fee           (__FeeID__, *ApplicationID, *StudentID, FeeType, Amount,
                     PaymentDate, Method)
R9.  Instructor    (__InstructorID__, *SchoolID, FirstName, LastName, Title,
                     Email, HireDate)
R10. Course        (__CourseID__, *SchoolID, CourseCode, CourseName, Credits)
R11. ProgramCourse ({ProgramID, CourseID}, CourseType, Semester)
R12. Term          (__TermID__, TermName, StartDate, EndDate)
R13. Classroom     (__ClassroomID__, *SchoolID, RoomNumber, Capacity, RoomType)
R14. Section       (__SectionID__, *CourseID, *TermID, *InstructorID,
                     *ClassroomID, SectionName)
R15. Enrollment    (__EnrollmentID__, *StudentID, *SectionID, Grade, Status)
```

---

## 7. Foreign-key dependency graph

```text
School <──────── Program
   ▲      ▲          │
   │      │          ▼
   │      │       Application <──── Applicant
   │      │          │                 │
   │      │          │                 ▼
   │      │          ▼              TestScore ───> EntryTest
   │      │        Student
   │      │          │
   │      │          ▼
   │      │         Fee ◄─── Application
   │      │
   │      ├──> Course ───> ProgramCourse <─── Program
   │      │         │
   │      │         ▼
   │      │       Section ───> Term
   │      ├────────> │
   │      │          │
   │      │          ▼
   │      ├──> Classroom ─> Section
   │      │
   │      └──> Instructor ──> Section
   │                              │
   │                              ▼
   │                          Enrollment <── Student
```

Every arrow in the graph is a `FOREIGN KEY` clause in [db/NUST.sql](db/NUST.sql). `ON DELETE CASCADE` is used on junction tables only (`Application`, `TestScore`, `ProgramCourse`, `Fee`); all other FKs use the default `RESTRICT` so that historical academic records cannot be silently orphaned.

---

## 8. Correspondence to the DDL

Every line of the mapping above has a one-to-one counterpart in [db/NUST.sql](db/NUST.sql):

| Relation | DDL location | Lines in `NUST.sql` (approx.) |
| --- | --- | --- |
| School        | `CREATE TABLE School`        | 55–62 |
| Program       | `CREATE TABLE Program`       | 65–77 |
| Applicant     | `CREATE TABLE Applicant`     | 83–95 |
| EntryTest     | `CREATE TABLE EntryTest`     | 97–105 |
| TestScore     | `CREATE TABLE TestScore`     | 108–118 |
| Application   | `CREATE TABLE Application`   | 121–134 |
| Student       | `CREATE TABLE Student`       | 139–150 |
| Fee           | `CREATE TABLE Fee`           | 161–182 |
| Instructor    | `CREATE TABLE Instructor`    | 188–200 |
| Course        | `CREATE TABLE Course`        | 204–214 |
| ProgramCourse | `CREATE TABLE ProgramCourse` | 217–227 |
| Term          | `CREATE TABLE Term`          | 229–237 |
| Classroom     | `CREATE TABLE Classroom`     | 239–250 |
| Section       | `CREATE TABLE Section`       | 254–267 |
| Enrollment    | `CREATE TABLE Enrollment`    | 270–287 |

The mapping is what lets a reviewer answer the question *"why is this column here?"* for every column in the physical schema — the answer is always *"it comes from this rule applied to this ER construct."*
