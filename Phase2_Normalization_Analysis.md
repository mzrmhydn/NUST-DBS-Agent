# Phase 2 — Normalization Analysis

This document proves that every relation in the NUST schema ([db/NUST.sql](db/NUST.sql)) is in **Third Normal Form (3NF)** and, with one surfaceable exception, in **Boyce–Codd Normal Form (BCNF)**. The analysis proceeds in the usual three steps: list the functional dependencies (FDs), identify the candidate keys, then check each FD against the 3NF / BCNF definitions.

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
ApplicantName | DOB | NET1_Score | NET2_Score | Applied_Prog_1 | Applied_Prog_2
| Accepted_Prog | CourseCode_1 | CourseName_1 | Grade_1 | InstructorName_1
| InstructorTitle_1 | RoomNumber_1 | RoomCapacity_1 | TermName_1 | …
```

This violates 1NF in three distinct ways — repeating groups (`NET*_Score`, `Applied_Prog_*`, `CourseCode_*`), composite attributes (`InstructorName` = `FirstName + LastName`), and multi-valued attributes (several grades per student).

**1NF fix** — extract repeating groups into their own relations:
- `NET1_Score`, `NET2_Score`, `NET3_Score` → `TestScore(ApplicantID, TestID, Score)`
- `Applied_Prog_1`, `Applied_Prog_2` → `Application(ApplicantID, ProgramID, …)`
- `CourseCode_*`, `Grade_*` → `Enrollment(StudentID, SectionID, Grade)`

---

## 2. Per-relation FD analysis and 3NF / BCNF proof

For each relation we list all non-trivial FDs, identify the candidate key(s), and check the 3NF / BCNF definition.

### 2.1 `School(SchoolID, Name, Location, EstablishedYear)`

**FDs.**
- `SchoolID → Name, Location, EstablishedYear`
- `Name → SchoolID, Location, EstablishedYear` (because `Name` is `UNIQUE`)

**Candidate keys:** `{SchoolID}`, `{Name}`.

Both determinants are superkeys. **BCNF ✓** (and therefore 3NF ✓).

### 2.2 `Program(ProgramID, SchoolID, ProgramName, DegreeType, DurationYears, TotalSeats)`

**FDs.**
- `ProgramID → SchoolID, ProgramName, DegreeType, DurationYears, TotalSeats`
- `{SchoolID, ProgramName} → ProgramID, DegreeType, DurationYears, TotalSeats` (the `UNIQUE (SchoolID, ProgramName)` constraint)

**Candidate keys:** `{ProgramID}`, `{SchoolID, ProgramName}`.

Both determinants are superkeys. **BCNF ✓**.

Note: we do **not** have `SchoolID → Name` on this relation — `SchoolID` is a foreign key, and `Program` does not store `SchoolName`. If it did, we would have `SchoolID → SchoolName`, a transitive dependency (`ProgramID → SchoolID → SchoolName`) that would break 3NF. Keeping only the FK is deliberate.

### 2.3 `Applicant(ApplicantID, FirstName, LastName, Email, Phone, DOB, HighSchoolMarks, City)`

**FDs.**
- `ApplicantID → FirstName, LastName, Email, Phone, DOB, HighSchoolMarks, City`
- `Email → ApplicantID, FirstName, LastName, Phone, DOB, HighSchoolMarks, City` (from `UNIQUE Email`)

**Candidate keys:** `{ApplicantID}`, `{Email}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.4 `EntryTest(TestID, SeriesName, TestDate, TestType)`

**FDs.**
- `TestID → SeriesName, TestDate, TestType`
- `SeriesName → TestID, TestDate, TestType` (from `UNIQUE SeriesName`)

**Candidate keys:** `{TestID}`, `{SeriesName}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.5 `TestScore(TestScoreID, ApplicantID, TestID, Score)`

**FDs.**
- `TestScoreID → ApplicantID, TestID, Score`
- `{ApplicantID, TestID} → TestScoreID, Score` (from `UNIQUE (ApplicantID, TestID)`)

**Candidate keys:** `{TestScoreID}`, `{ApplicantID, TestID}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.6 `Application(ApplicationID, ApplicantID, ProgramID, ApplicationDate, Preference, Status)`

**FDs.**
- `ApplicationID → ApplicantID, ProgramID, ApplicationDate, Preference, Status`
- `{ApplicantID, ProgramID} → ApplicationID, ApplicationDate, Preference, Status` (from `UNIQUE (ApplicantID, ProgramID)`)

**Candidate keys:** `{ApplicationID}`, `{ApplicantID, ProgramID}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.7 `Student(StudentID, ApplicationID, EnrollmentDate, CGPA, Status)`

**FDs.**
- `StudentID → ApplicationID, EnrollmentDate, CGPA, Status`
- `ApplicationID → StudentID, EnrollmentDate, CGPA, Status` (from `UNIQUE ApplicationID`)

**Candidate keys:** `{StudentID}`, `{ApplicationID}`.

Both determinants are superkeys. **BCNF ✓**.

Note that `Student` does **not** carry `ApplicantID` or `ProgramID`. If it did, we would have `ApplicationID → ApplicantID` (from the FK-target), creating the transitive chain `StudentID → ApplicationID → ApplicantID` with `ApplicantID` non-prime and `ApplicationID` non-superkey — a **3NF violation**. The design explicitly refuses to denormalize here, which is what keeps the relation in BCNF.

### 2.8 `Fee(FeeID, ApplicationID, StudentID, FeeType, Amount, PaymentDate, Method)`

**FDs.**
- `FeeID → ApplicationID, StudentID, FeeType, Amount, PaymentDate, Method`
- `ApplicationID → FeeID, StudentID, FeeType, Amount, PaymentDate, Method` — **only for rows where `FeeType='Application'`**, because of the partial `UNIQUE (ApplicationID)` index. For rows where `FeeType` is not `'Application'`, `ApplicationID IS NULL` and this FD does not apply. We model this as a **conditional FD** that holds on the restriction `σ[FeeType='Application'](Fee)`.

**Candidate key (full relation):** `{FeeID}`.

For the full relation, `FeeID` is the only determinant of all attributes, and `FeeID → everything`. **BCNF ✓**.

Note: the conditional FD `ApplicationID → …` on `σ[FeeType='Application']` does not cause a BCNF violation on the full relation because it does not hold universally. It is, however, still *enforced* by the partial unique index — this is the schema leveraging MySQL's tolerance of multiple NULLs in a UNIQUE index to encode a conditional constraint declaratively.

### 2.9 `Instructor(InstructorID, SchoolID, FirstName, LastName, Title, Email, HireDate)`

**FDs.**
- `InstructorID → SchoolID, FirstName, LastName, Title, Email, HireDate`
- `Email → InstructorID, SchoolID, FirstName, LastName, Title, HireDate` (from `UNIQUE Email`)

**Candidate keys:** `{InstructorID}`, `{Email}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.10 `Course(CourseID, SchoolID, CourseCode, CourseName, Credits)`

**FDs.**
- `CourseID → SchoolID, CourseCode, CourseName, Credits`
- `CourseCode → CourseID, SchoolID, CourseName, Credits` (from `UNIQUE CourseCode`)

**Candidate keys:** `{CourseID}`, `{CourseCode}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.11 `ProgramCourse(ProgramID, CourseID, CourseType, Semester)`

**FDs.**
- `{ProgramID, CourseID} → CourseType, Semester`

**Candidate keys:** `{ProgramID, CourseID}`.

The only non-trivial FD has a superkey on the left-hand side. **BCNF ✓**.

Note that we do **not** claim `CourseID → Semester` — the same course can map to different semesters in different programs (e.g. CS220 might be recommended in semester 4 of BSCS but semester 3 of BESE). That asymmetry is exactly what forces `Semester` onto the junction, not onto `Course`.

### 2.12 `Term(TermID, TermName, StartDate, EndDate)`

**FDs.**
- `TermID → TermName, StartDate, EndDate`
- `TermName → TermID, StartDate, EndDate` (from `UNIQUE TermName`)

**Candidate keys:** `{TermID}`, `{TermName}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.13 `Classroom(ClassroomID, SchoolID, RoomNumber, Capacity, RoomType)`

**FDs.**
- `ClassroomID → SchoolID, RoomNumber, Capacity, RoomType`
- `{SchoolID, RoomNumber} → ClassroomID, Capacity, RoomType` (from `UNIQUE (SchoolID, RoomNumber)`)

**Candidate keys:** `{ClassroomID}`, `{SchoolID, RoomNumber}`.

Both determinants are superkeys. **BCNF ✓**.

### 2.14 `Section(SectionID, CourseID, TermID, InstructorID, ClassroomID, SectionName)`

**FDs.**
- `SectionID → CourseID, TermID, InstructorID, ClassroomID, SectionName`
- `{CourseID, TermID, SectionName} → SectionID, InstructorID, ClassroomID` (from `UNIQUE (CourseID, TermID, SectionName)`)

**Candidate keys:** `{SectionID}`, `{CourseID, TermID, SectionName}`.

Both determinants are superkeys. **BCNF ✓**.

We do **not** claim `ClassroomID → SchoolID` on this relation, even though that FD holds transitively through `Classroom.SchoolID`. It would only be an FD *within* `Section` if `Section` stored `SchoolID` — which it doesn't. So no transitive dependency exists on this relation.

### 2.15 `Enrollment(EnrollmentID, StudentID, SectionID, Grade, Status)`

**FDs.**
- `EnrollmentID → StudentID, SectionID, Grade, Status`
- `{StudentID, SectionID} → EnrollmentID, Grade, Status` (from `UNIQUE (StudentID, SectionID)`)

**Candidate keys:** `{EnrollmentID}`, `{StudentID, SectionID}`.

Both determinants are superkeys. **BCNF ✓**.

Note: there is a `CHECK` constraint tying `Grade` to `Status` (`Status='Completed' ⇔ Grade IS NOT NULL`), but this is a **tuple constraint**, not a functional dependency between columns — `Status='Completed'` does not determine a specific grade, it just determines that grade *is not null*. 3NF/BCNF analysis is unaffected.

---

## 3. Summary table

| # | Relation | Candidate Keys | Highest NF | Notes |
| --- | --- | --- | --- | --- |
| 1 | School        | `{SchoolID}`, `{Name}`                        | BCNF | |
| 2 | Program       | `{ProgramID}`, `{SchoolID, ProgramName}`      | BCNF | No denormalization of `SchoolName`. |
| 3 | Applicant     | `{ApplicantID}`, `{Email}`                    | BCNF | |
| 4 | EntryTest     | `{TestID}`, `{SeriesName}`                    | BCNF | |
| 5 | TestScore     | `{TestScoreID}`, `{ApplicantID, TestID}`      | BCNF | |
| 6 | Application   | `{ApplicationID}`, `{ApplicantID, ProgramID}` | BCNF | |
| 7 | Student       | `{StudentID}`, `{ApplicationID}`              | BCNF | `ApplicantID`/`ProgramID` deliberately not denormalized. |
| 8 | Fee           | `{FeeID}`                                     | BCNF | Conditional FD on `ApplicationID` holds only on the `Application`-fee subset and is enforced by a partial UNIQUE index. |
| 9 | Instructor    | `{InstructorID}`, `{Email}`                   | BCNF | |
| 10 | Course       | `{CourseID}`, `{CourseCode}`                  | BCNF | |
| 11 | ProgramCourse | `{ProgramID, CourseID}`                       | BCNF | |
| 12 | Term         | `{TermID}`, `{TermName}`                      | BCNF | |
| 13 | Classroom    | `{ClassroomID}`, `{SchoolID, RoomNumber}`     | BCNF | |
| 14 | Section      | `{SectionID}`, `{CourseID, TermID, SectionName}` | BCNF | |
| 15 | Enrollment   | `{EnrollmentID}`, `{StudentID, SectionID}`    | BCNF | Grade/Status interlock is a tuple constraint, not an FD. |

Every relation is in **BCNF**, and therefore in **3NF**. There are **no justified denormalizations** — the schema does not trade correctness for query-path speed anywhere.

---

## 4. What we consciously did *not* do

A few denormalizations are tempting and common in real-world databases. We rejected each for a concrete reason:

| Tempting denormalization | Why it would break BCNF | What we did instead |
| --- | --- | --- |
| `Student.ProgramID` | Creates `ApplicationID → ProgramID` — a non-superkey determinant on a non-prime attribute (3NF violation, transitive through `Application`). | Reach the program through `Student → Application → Program`. One extra join, zero drift risk. |
| `Student.ApplicantID` | Same shape of violation as above. | Reach the applicant through `Student → Application → Applicant`. |
| `Program.SchoolName` | `SchoolID → SchoolName` would live inside `Program`, giving a transitive chain `ProgramID → SchoolID → SchoolName`. | Store only `SchoolID`; join `School` when the name is needed. |
| Overloading `Grade` with `'IP'` / `'W'` sentinel values | Doesn't break BCNF, but collapses a valid state machine into one column and breaks every `AVG(Grade)` query. | Separate `Grade` (nullable letter) from `Status` (InProgress/Completed/Withdrawn). |
| Splitting `Fee` into `ApplicationFee` + `StudentFee` | Doesn't violate any NF by itself, but every "lifetime ledger" report would need a `UNION`. | Keep one `Fee` relation with an XOR `CHECK`; a partial UNIQUE index enforces "at most one Application fee per Application". |

---

## 5. Closing note

The payoff of being in BCNF here is not abstract. Each of the rejected denormalizations would have created a concrete class of drift bug — `Student.ProgramID` diverging from `Application.ProgramID`, `Program.SchoolName` diverging from `School.Name`, a student listed twice in two fee tables — that the database could not prevent. BCNF is what lets us enforce every business invariant with declarative constraints and stop worrying about drift.
