# Phase 1: Requirements & ER Design

## 1. Problem Statement and Domain Description
The National University of Sciences and Technology (NUST) handles a massive influx of candidates attempting the NUST Entry Test (NET) to secure admissions into top-tier programs like BSCS, BESE, and BBA. The workflow spans candidate applications, multi-series entry-test scores, waitlists, per-application processing fees, and the subsequent academic registration in program curricula.

This project designs a unified, normalized Relational Database System. The schema treats the transition from **applicant** to **student** as a strict 1:1 relationship anchored at the `Application` level: every `Student` row points at exactly one accepted `Application`, and the applicant's identity and admitted program are reached *through* that application — the admissions record is the single source of truth.

This gives a holistic, queryable view of a student's journey from their first NET attempt to their final transcript grade, without denormalized duplicates.

## 2. Functional Requirements
The database system must support:
- Tracking a candidate's high-school parameters and their attempts across multiple NET series.
- Storing multi-program applications for a single candidate, each with its own `Status` (e.g., *Selected, Waitlisted, Rejected, Enrolled*) and `Preference` ranking.
- Recording every payment in a single unified `Fee` ledger: per-application processing fees (`FeeType = 'Application'`, keyed to `Application`) and per-student tuition / hostel / library fees (`FeeType IN ('Tuition','Hostel','Library')`, keyed to `Student`). An XOR `CHECK` guarantees exactly one of (`ApplicationID`, `StudentID`) is non-NULL per row, so the table remains strictly typed — not a loose polymorphic dumping ground.
- Promoting a "Selected" applicant into an enrolled `Student` via a trigger-driven handoff — preserving the full audit trail back to the accepted `Application`.
- Expressing a program's curriculum as a **many-to-many** relationship between `Program` and `Course` (the `ProgramCourse` junction), so shared courses like *Programming Fundamentals* appear in multiple programs without duplication.
- Managing physical infrastructure (Schools, Classrooms) and the schedule (Instructor, Term, Section).
- Recording class enrollments with separate `Grade` and `Status` fields so an in-progress registration is a first-class state, not a grade sentinel.

## 3. Complete ER Design and Entities

The database contains **15 entities** cleanly separated across two contextual pipelines, joined by a strict 1:1 bridge (`Student` ↔ accepted `Application`). Of those, four are pure junction tables (`TestScore`, `Application`, `ProgramCourse`, `Enrollment`).

### Administrative Structure
1. **School** — NUST constituent colleges (SEECS, SMME, NBS, …).
2. **Program** — Degrees offered by a school (BSCS, BESE, BBA, …).

### Admissions Pipeline
3. **Applicant** — Prospective candidate profile.
4. **EntryTest** — NET test instances (NET-1, NET-2, NBS NET, …).
5. **TestScore** — Junction between `Applicant` and `EntryTest` with the numeric score.
6. **Application** — Junction between `Applicant` and `Program` with `Status` and `Preference`.
7. **Student** — Academic record, 1:1 with exactly one accepted `Application`. Holds **only** `ApplicationID` (applicant/program reached via `Application`).

### Financials
8. **Fee** — Unified payment ledger. `FeeType ∈ {Application, Tuition, Hostel, Library}` discriminates the row; exactly one of (`ApplicationID`, `StudentID`) is non-NULL, enforced by an XOR `CHECK`. A partial unique index guarantees at most one `Application`-type fee per `Application`.

### Academic Pipeline
9. **Instructor** — Faculty employed by a `School`.
10. **Course** — A teaching unit **owned by a School** (not a program), with a unique `CourseCode`.
11. **ProgramCourse** — M:N junction binding `Course` to each `Program` that includes it, with `CourseType` ∈ {Core, Elective} and target `Semester`.
12. **Term** — Academic semester with a start/end date.
13. **Classroom** — Physical rooms inside a `School`, with typed capacity (Lecture / Lab / Studio / Hall).
14. **Section** — A scheduled offering of a `Course` in a `Term`, taught by an `Instructor` in a `Classroom`.
15. **Enrollment** — Junction between `Student` and `Section`, with separate `Grade` (nullable letter) and `Status` ∈ {InProgress, Completed, Withdrawn}.

### Cardinalities & Constraints

| Relationship | Cardinality | Notes |
| --- | --- | --- |
| School → Program | 1 : 1..M | A school offers *at least one* program; a program belongs to exactly one school (mandatory many). |
| School → Instructor | 1 : 0..M | Optional many. |
| School → Classroom | 1 : 0..M | Optional many. |
| School → Course | 1 : 0..M | A course is owned by the teaching school (not a program). |
| Applicant → TestScore | 1 : 0..M | A candidate may have taken 0+ NET series. |
| Applicant → Application | 1 : 0..M | A candidate can apply to multiple programs. |
| EntryTest → TestScore | 1 : 0..M | Each NET instance collects many scores. |
| Program → Application | 1 : 0..M | A program receives many applications. |
| **Program ↔ Course** | **M : N** (via `ProgramCourse`) | A course can belong to several programs; a program has many courses. |
| **Application ↔ Student** | **1 : 0..1** | Every Student row is produced by exactly one accepted Application; most applications produce no student. |
| **Application → Fee** (`FeeType='Application'`) | **1 : 0..1** | An application has at most one processing-fee row; enforced by a partial unique index on `Fee(ApplicationID) WHERE FeeType='Application'`. |
| **Student → Fee** (`FeeType ∈ {Tuition, Hostel, Library}`) | **1 : 0..M** | Many tuition / hostel / library payments per student. |
| Student → Enrollment | 1 : 0..M | Students register in many sections across terms. |
| Section → Enrollment | 1 : 0..M | A section has many enrolled students (bounded by classroom capacity). |
| Course → Section | 1 : 0..M | A course is offered as multiple sections. |
| Term → Section | 1 : 0..M | A term hosts many sections. |
| Instructor → Section | 1 : 0..M | An instructor teaches many sections. |
| Classroom → Section | 1 : 0..M | A classroom hosts many sections. |

## 4. Justification of Design Decisions
- **Single source of truth for admissions identity.** The previous iteration denormalized `ApplicantID` and `ProgramID` onto `Student`. We now carry **only** `ApplicationID` on `Student` (UNIQUE, NOT NULL) — the applicant and admitted program are reached deterministically via `Application`. This eliminates the possibility of drift between `Student.ProgramID` and `Application.ProgramID`.
- **One `Fee` ledger, typed by FeeType.** The earlier design had one `Payment` table with three nullable foreign keys (`ApplicantID`, `StudentID`, `ApplicationID`) and no invariants — every payment query had to branch on "which FK is valid this time?". We keep the table-count win of a single ledger but remove its looseness: `Fee` has exactly two payer FKs (`ApplicationID`, `StudentID`), a `FeeType` discriminator, and an XOR `CHECK` that hard-wires `FeeType='Application'` to `ApplicationID` and every other `FeeType` to `StudentID`. A partial unique index also enforces the old "one application fee per application" invariant. The cardinality is thus enforced in the schema, not in application code.
- **Course is a teaching unit, not a program-owned artefact.** A course like *Programming Fundamentals* is genuinely shared across BSCS, BESE, and BEE. Making `Course` a child of `Program` misrepresents this and forces duplicate rows. We move `Course` under `School` and introduce a true **M:N** relationship via `ProgramCourse` (carrying `CourseType` and `Semester`) — a textbook junction table.
- **Enrollment state is factored.** `Grade` is nullable and holds only real letter grades ('A' through 'F'). In-progress and withdrawn states live on a separate `Status` column, guarded by a `CHECK` constraint that enforces the invariant (`Completed` ⇒ `Grade IS NOT NULL`; `InProgress`/`Withdrawn` ⇒ `Grade IS NULL`).
- **Waitlist via status, not via a separate table.** Waitlisted applicants sit in `Application` with `Status = 'Waitlisted'`. No auxiliary table is needed; the state machine (`Pending → Selected → Enrolled`, or `Waitlisted` / `Rejected` / `Declined`) flows naturally on a single row.

---

# Phase 2: Schema & Normalization

## 1. Normalization Analysis (Proving 3NF)

**Unnormalized Form (UNF)** — a flat spreadsheet with `ApplicantName`, `NET_Series1_Score`, `NET_Series2_Score`, `AppliedProgram_1`, `AppliedProgram_2`, `AcceptedProgram`, `CourseEnrolled`, `InstructorName`, `InstructorTitle`, `RoomNumber`, `TermName`, …

**1NF** — eliminate repeating groups. `NET_Series{i}` and `AppliedProgram_{i}` become the `TestScore`, `Application`, and `Enrollment` tables.

**2NF** — remove partial dependencies. In `Section`, attributes like `InstructorTitle` depended on only part of a composite key. They move into the `Instructor` table.

**3NF** — remove transitive dependencies. If `Program` stored `SchoolName` alongside `SchoolID`, `SchoolName` would depend on `SchoolID`, which depends on the PK — a transitive chain. We keep only the foreign key.

The new schema has **no justified denormalizations**. The prior version kept `Student.ProgramID` for query-hot-path reasons; we removed it because one extra `JOIN Application` is cheap and the schema becomes more honest (and cannot drift).

## 2. MySQL DDL Scripts

The full schema is implemented in [db/NUST.sql](db/NUST.sql). Core definitions:

```sql
PRAGMA foreign_keys = ON;

-- 1. School
CREATE TABLE School (
    SchoolID        INTEGER PRIMARY KEY AUTOINCREMENT,
    Name            VARCHAR(100) NOT NULL UNIQUE,
    Location        VARCHAR(100),
    EstablishedYear INTEGER
);

-- 2. Program (mandatory School)
CREATE TABLE Program (
    ProgramID     INTEGER PRIMARY KEY AUTOINCREMENT,
    SchoolID      INTEGER NOT NULL,
    ProgramName   VARCHAR(100) NOT NULL,
    DegreeType    VARCHAR(20)  NOT NULL,
    DurationYears INTEGER DEFAULT 4 CHECK (DurationYears BETWEEN 1 AND 7),
    TotalSeats    INTEGER CHECK (TotalSeats > 0),
    FOREIGN KEY (SchoolID) REFERENCES School(SchoolID) ON DELETE CASCADE,
    UNIQUE (SchoolID, ProgramName)
);

-- 3. Applicant
CREATE TABLE Applicant (
    ApplicantID     INTEGER PRIMARY KEY AUTOINCREMENT,
    FirstName       VARCHAR(50)  NOT NULL,
    LastName        VARCHAR(50)  NOT NULL,
    Email           VARCHAR(100) NOT NULL UNIQUE,
    Phone           VARCHAR(20),
    DOB             DATE,
    HighSchoolMarks INTEGER CHECK (HighSchoolMarks BETWEEN 0 AND 1100),
    City            VARCHAR(50)
);

-- 4. EntryTest
CREATE TABLE EntryTest (
    TestID     INTEGER PRIMARY KEY AUTOINCREMENT,
    SeriesName VARCHAR(80) NOT NULL UNIQUE,
    TestDate   DATE NOT NULL,
    TestType   VARCHAR(30) NOT NULL
        CHECK (TestType IN ('Engineering','Business','Architecture','Biosciences','Chemical'))
);

-- 5. TestScore (M:N junction Applicant <-> EntryTest)
CREATE TABLE TestScore (
    TestScoreID INTEGER PRIMARY KEY AUTOINCREMENT,
    ApplicantID INTEGER NOT NULL,
    TestID      INTEGER NOT NULL,
    Score       INTEGER NOT NULL CHECK (Score BETWEEN 0 AND 200),
    FOREIGN KEY (ApplicantID) REFERENCES Applicant(ApplicantID) ON DELETE CASCADE,
    FOREIGN KEY (TestID)      REFERENCES EntryTest(TestID)      ON DELETE CASCADE,
    UNIQUE (ApplicantID, TestID)
);

-- 6. Application (M:N junction Applicant <-> Program, with attrs)
CREATE TABLE Application (
    ApplicationID   INTEGER PRIMARY KEY AUTOINCREMENT,
    ApplicantID     INTEGER NOT NULL,
    ProgramID       INTEGER NOT NULL,
    ApplicationDate DATE NOT NULL,
    Preference      INTEGER DEFAULT 1 CHECK (Preference BETWEEN 1 AND 5),
    Status          VARCHAR(20) DEFAULT 'Pending'
        CHECK (Status IN ('Pending','Selected','Waitlisted','Rejected','Enrolled','Declined')),
    FOREIGN KEY (ApplicantID) REFERENCES Applicant(ApplicantID) ON DELETE CASCADE,
    FOREIGN KEY (ProgramID)   REFERENCES Program(ProgramID)     ON DELETE CASCADE,
    UNIQUE (ApplicantID, ProgramID)
);

-- 7. Student (1:1 with accepted Application)
CREATE TABLE Student (
    StudentID      INTEGER PRIMARY KEY AUTOINCREMENT,
    ApplicationID  INTEGER NOT NULL UNIQUE,
    EnrollmentDate DATE NOT NULL,
    CGPA           REAL DEFAULT 0.00 CHECK (CGPA BETWEEN 0.00 AND 4.00),
    Status         VARCHAR(20) DEFAULT 'Active'
        CHECK (Status IN ('Active','Graduated','Suspended','Withdrawn')),
    FOREIGN KEY (ApplicationID) REFERENCES Application(ApplicationID)
);

-- 8. Fee (unified ledger; XOR-constrained payer FK)
CREATE TABLE Fee (
    FeeID         INTEGER PRIMARY KEY AUTOINCREMENT,
    ApplicationID INTEGER,
    StudentID     INTEGER,
    FeeType       VARCHAR(20) NOT NULL
        CHECK (FeeType IN ('Application','Tuition','Hostel','Library')),
    Amount        NUMERIC(10,2) NOT NULL CHECK (Amount >= 0),
    PaymentDate   DATE NOT NULL,
    Method        VARCHAR(20) NOT NULL
        CHECK (Method IN ('Bank','Online','Cheque','Cash')),
    FOREIGN KEY (ApplicationID) REFERENCES Application(ApplicationID) ON DELETE CASCADE,
    FOREIGN KEY (StudentID)     REFERENCES Student(StudentID)         ON DELETE CASCADE,
    CHECK (
        (FeeType = 'Application'
            AND ApplicationID IS NOT NULL AND StudentID IS NULL)
     OR (FeeType IN ('Tuition','Hostel','Library')
            AND StudentID IS NOT NULL AND ApplicationID IS NULL)
    )
);
CREATE UNIQUE INDEX IDX_Fee_OneAppFeePerApp
    ON Fee(ApplicationID) WHERE FeeType = 'Application';

-- 9. Instructor
CREATE TABLE Instructor (
    InstructorID INTEGER PRIMARY KEY AUTOINCREMENT,
    SchoolID     INTEGER NOT NULL,
    FirstName    VARCHAR(50) NOT NULL,
    LastName     VARCHAR(50) NOT NULL,
    Title        VARCHAR(50) NOT NULL
        CHECK (Title IN ('Lecturer','Assistant Professor','Associate Professor','Professor')),
    Email        VARCHAR(100) UNIQUE,
    HireDate     DATE,
    FOREIGN KEY (SchoolID) REFERENCES School(SchoolID)
);

-- 10. Course (owned by School, not Program)
CREATE TABLE Course (
    CourseID   INTEGER PRIMARY KEY AUTOINCREMENT,
    SchoolID   INTEGER NOT NULL,
    CourseCode VARCHAR(10) NOT NULL UNIQUE,
    CourseName VARCHAR(100) NOT NULL,
    Credits    INTEGER NOT NULL CHECK (Credits BETWEEN 1 AND 6),
    FOREIGN KEY (SchoolID) REFERENCES School(SchoolID)
);

-- 11. ProgramCourse (M:N junction Program <-> Course)
CREATE TABLE ProgramCourse (
    ProgramID  INTEGER NOT NULL,
    CourseID   INTEGER NOT NULL,
    CourseType VARCHAR(10) NOT NULL DEFAULT 'Core'
        CHECK (CourseType IN ('Core','Elective')),
    Semester   INTEGER NOT NULL CHECK (Semester BETWEEN 1 AND 10),
    PRIMARY KEY (ProgramID, CourseID),
    FOREIGN KEY (ProgramID) REFERENCES Program(ProgramID) ON DELETE CASCADE,
    FOREIGN KEY (CourseID)  REFERENCES Course(CourseID)   ON DELETE CASCADE
);

-- 12. Term, 13. Classroom, 14. Section, 15. Enrollment  (see db/NUST.sql)
CREATE TABLE Enrollment (
    EnrollmentID INTEGER PRIMARY KEY AUTOINCREMENT,
    StudentID    INTEGER NOT NULL,
    SectionID    INTEGER NOT NULL,
    Grade        VARCHAR(2) CHECK (Grade IS NULL OR
                 Grade IN ('A','A-','B+','B','B-','C+','C','C-','D+','D','F')),
    Status       VARCHAR(15) NOT NULL DEFAULT 'InProgress'
        CHECK (Status IN ('InProgress','Completed','Withdrawn')),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (SectionID) REFERENCES Section(SectionID),
    UNIQUE (StudentID, SectionID),
    CHECK ((Status = 'Completed' AND Grade IS NOT NULL)
        OR (Status IN ('InProgress','Withdrawn') AND Grade IS NULL))
);
```

## 3. Sample Data Insertion Scripts

The full seed data lives in [db/NUST.sql](db/NUST.sql). The dataset simulates two full admission cycles:

- **2025 intake**: 5 students now in their 2nd/3rd semester with completed grades (A / A- / B+ / B).
- **2026 intake**: 5 freshmen with in-progress Fall 2026 enrollments, plus Cohort 1 students simultaneously taking upper-level CS330/CS440 sections — producing realistic cross-term enrollment patterns.

Total seeded: **10 Schools, 12 Programs, 15 Applicants, 10 Entry Tests, 23 Test Scores, 20 Applications, 10 Students, 30 Fees (15 Application + 10 Tuition + 3 Hostel + 2 Library), 12 Instructors, 15 Courses, 25 ProgramCourse rows, 10 Terms, 12 Classrooms, 17 Sections, 30 Enrollments.**

The ERD (mermaid.js source) is in [db/ERD.mmd](db/ERD.mmd).

Example of the admissions chain (School → Program → Application → Student) for Ali Khan:

```sql
INSERT INTO School   (Name, Location) VALUES ('SEECS','H-12 Islamabad');
INSERT INTO Program  (SchoolID, ProgramName, DegreeType) VALUES (1,'Computer Science','BSCS');
INSERT INTO Applicant (FirstName, LastName, Email, HighSchoolMarks, City)
    VALUES ('Ali','Khan','ali.khan@test.com',980,'Islamabad');
INSERT INTO Application (ApplicantID, ProgramID, ApplicationDate, Status)
    VALUES (1, 2, '2025-07-01', 'Selected');
INSERT INTO Fee (ApplicationID, StudentID, FeeType, Amount, PaymentDate, Method)
    VALUES (1, NULL, 'Application', 4000.00, '2025-05-01', 'Online');
-- Trigger promotes Application.Status 'Selected' -> 'Enrolled' upon Student insert
INSERT INTO Student (ApplicationID, EnrollmentDate, CGPA)
    VALUES (1, '2025-09-01', 3.58);
```
