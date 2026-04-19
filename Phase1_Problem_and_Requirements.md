# Phase 1 — Problem Statement & Functional Requirements

**Project:** NUST Admissions & Academic Records Database
**Domain:** Higher-education admissions and undergraduate academic lifecycle
**DBMS:** MySQL 8.0+ (InnoDB)

---

## 1. Problem Statement and Domain Description

### 1.1 The domain

The National University of Sciences and Technology (NUST) is one of Pakistan's largest federally chartered universities, operating a dozen constituent schools (SEECS, SMME, NBS, SADA, NICE, S3H, ASAB, SCME, CAMP, MCS, …) that between them offer more than sixty undergraduate and graduate programs. Every admissions cycle NUST receives **tens of thousands** of candidates competing through a staged **NUST Entry Test (NET)**: most applicants sit multiple series (NET-1, NET-2, NET-3, NBS NET, SADA NET, ASAB NET), each tailored to a broad stream (Engineering, Business, Architecture, Biosciences, Chemical). An applicant does not apply to a school — they apply to a **program** (e.g. BSCS at SEECS, BBA at NBS), may list several programs in order of preference, and each application carries its own *status* through a lifecycle of `Pending → Selected → Enrolled` (with `Waitlisted`, `Rejected`, and `Declined` as terminal branches).

A payment ledger runs in parallel. Every application incurs a **non-refundable processing fee**; every enrolled student incurs recurring **tuition, hostel, and library** charges each semester. Historically these two payment streams have been tracked on separate spreadsheets and in different applications — a split that is cheap to maintain on day one but expensive on day one-thousand, when finance wants a single answer to *"what has this human paid us, ever?"* and the answer requires merging two incompatible systems.

Once an applicant is selected and pays tuition, they become a **Student** with a unique registration number, an assigned program, and an academic record. Students then register into **Sections** — specific offerings of a **Course** in a given **Term**, taught by a specific **Instructor** in a specific **Classroom**. The academic record accumulates letter grades as sections complete, and in-progress registrations must be distinguishable from withdrawn ones and from graded ones, because each drives a different downstream workflow (re-registration windows, withdrawal refunds, CGPA computation).

### 1.2 The problem

Existing university-facing software stacks at NUST treat admissions and academics as two distinct universes held together only by a spreadsheet export. The result is a series of well-known operational pains:

1. **Identity drift.** An applicant who becomes a student is often represented by two unrelated rows in two unrelated systems. When the student later applies for a scholarship that requires their entry-test score, the finance office has to manually reconcile names, CNICs, and dates of birth.
2. **Payment fragmentation.** Processing fees live in the admissions database; tuition and hostel fees live in the finance database. Generating a single "lifetime ledger" for a student — the kind of report an auditor or a tax authority expects — requires a custom export and merge each time.
3. **Curriculum duplication.** A shared foundational course like *Programming Fundamentals* (CS118) is delivered to BSCS, BESE, and BEE students together in the same classroom. Systems that model courses as belonging to a program instead of to a teaching school (a *school* owns the instructor and the classroom) end up storing CS118 three times — and when its credit hours change, three rows need to be updated in lockstep.
4. **State collapse.** Common systems overload the `Grade` column with sentinel values like `'IP'` (in progress) or `'W'` (withdrawn) to avoid adding a second column. This breaks every average and every sort, and forces the application layer to re-encode the business state on every read.
5. **Implicit invariants.** Rules like *"an application gets at most one processing fee"* or *"an enrolled application cannot also be a rejected one"* are usually enforced in application code that a different team maintains. The database itself is indifferent — which is how an applicant ends up with two 4,000-rupee charges when two admissions officers click `Submit` at the same moment.

### 1.3 Our solution

This project designs and implements a **single normalized MySQL database** — `nust_university` — that treats the admissions pipeline and the academic pipeline as one domain connected by a strict **1:1 bridge between `Student` and an accepted `Application`**. The admissions record is the *single source of truth* for a student's identity and admitted program: `Student` carries **only** `ApplicationID`, and the applicant and program are reached through that one join. Fees live in a **unified ledger** whose rows are typed by a `FeeType` discriminator and constrained by an `XOR CHECK` that hard-wires the payer (`Application` for processing fees, `Student` for tuition/hostel/library). Course ownership is moved from program to school, and a true many-to-many `ProgramCourse` junction carries the `CourseType` (Core/Elective) and recommended `Semester`. In-progress and withdrawn enrollments get a first-class `Status` column rather than a sentinel grade. Every invariant the business cares about is expressed as a declarative constraint, not inferred from application code.

The schema is intentionally **narrow in scope and deep in correctness** — 15 entities, four of which are junction tables — covering the complete journey from a candidate's first NET attempt through their final term's letter grade. A FastAPI backend (`api.py`) and a React frontend expose the database through a natural-language interface backed by a local Ollama LLM, so non-technical staff can ask questions like *"Show the tuition revenue per school for the 2026 intake"* without writing SQL.

---

## 2. Functional Requirements

### 2.1 Administrative structure

| # | Requirement |
| --- | --- |
| FR-1 | The system shall maintain a catalogue of **Schools** (constituent colleges), each with a unique name, a physical location, and an establishment year. |
| FR-2 | The system shall maintain a catalogue of **Programs** (degrees), each belonging to exactly one School, with a unique `(School, ProgramName)` pair, a typed degree (BSCS, BESE, BBA, MSIS, …), a duration in years (1–7), and a total-seats quota. |
| FR-3 | The system shall reject any Program whose `DurationYears` is outside `[1, 7]` or whose `TotalSeats` is `<= 0`. |

### 2.2 Admissions pipeline

| # | Requirement |
| --- | --- |
| FR-4 | The system shall record each **Applicant** exactly once, keyed by a unique email address, with optional phone, DOB, city, and high-school marks. |
| FR-5 | The system shall reject any high-school-marks value outside `[0, 1100]` (the SSC/HSSC combined ceiling). |
| FR-6 | The system shall maintain a catalogue of **Entry Tests** (NET-1, NET-2, NBS NET, SADA NET, …), each with a unique series name, a test date, and a typed stream. |
| FR-7 | The system shall record each **TestScore** as a row in the M:N junction between Applicant and EntryTest, with a unique `(ApplicantID, TestID)` pair and a score in `[0, 200]`. |
| FR-8 | The system shall allow an Applicant to submit multiple **Applications** (one per Program), each with a `Preference` rank in `[1, 5]` and a `Status` drawn from the state machine `{Pending, Selected, Waitlisted, Rejected, Enrolled, Declined}`. |
| FR-9 | The system shall prevent the same Applicant from applying twice to the same Program (unique `(ApplicantID, ProgramID)`). |
| FR-10 | The system shall record every **Student** as exactly one accepted Application, with a unique `ApplicationID`, an enrollment date, a CGPA in `[0.00, 4.00]`, and a typed status `{Active, Graduated, Suspended, Withdrawn}`. |
| FR-11 | The system shall **automatically promote** an Application from `Selected` to `Enrolled` when a matching Student row is inserted, leaving any sibling Applications of the same Applicant (Waitlisted / Rejected / Declined) untouched. |

### 2.3 Financial pipeline

| # | Requirement |
| --- | --- |
| FR-12 | The system shall maintain a **unified Fee ledger** that records every payment in a single table. |
| FR-13 | The system shall classify each Fee by `FeeType ∈ {Application, Tuition, Hostel, Library}` and reject any other value. |
| FR-14 | The system shall enforce an XOR invariant on every Fee row: `FeeType='Application'` rows must have `ApplicationID IS NOT NULL AND StudentID IS NULL`; all other fee types must have `StudentID IS NOT NULL AND ApplicationID IS NULL`. |
| FR-15 | The system shall accept at most one `Application`-type Fee per Application (unique partial index on `Fee(ApplicationID)`). |
| FR-16 | The system shall reject any Fee whose `Amount` is negative or whose `Method` is not in `{Bank, Online, Cheque, Cash}`. |

### 2.4 Academic pipeline

| # | Requirement |
| --- | --- |
| FR-17 | The system shall maintain **Instructors** employed by exactly one School, with a unique email and a typed title `{Lecturer, Assistant Professor, Associate Professor, Professor}`. |
| FR-18 | The system shall maintain **Courses** owned by a School (not a Program), with a globally unique `CourseCode` and credit hours in `[1, 6]`. |
| FR-19 | The system shall express a Program's curriculum as a **many-to-many** relationship via `ProgramCourse`, so a course can belong to many programs without duplication. Each row shall carry `CourseType ∈ {Core, Elective}` and a recommended `Semester ∈ [1, 10]`. |
| FR-20 | The system shall maintain **Terms** (Fall 2025, Spring 2026, …) with non-overlapping start/end dates and a unique term name, and reject any term whose `EndDate <= StartDate`. |
| FR-21 | The system shall maintain **Classrooms** owned by a School, each with a unique `(School, RoomNumber)` pair, a positive capacity, and a typed `RoomType ∈ {Lecture, Lab, Studio, Hall}`. |
| FR-22 | The system shall model every **Section** as a scheduled offering of one Course, in one Term, taught by one Instructor, in one Classroom — with `(CourseID, TermID, SectionName)` unique. All four foreign keys are mandatory. |
| FR-23 | The system shall record each **Enrollment** as a row in the M:N junction between Student and Section, unique on `(StudentID, SectionID)`, with a nullable `Grade` drawn from the letter-grade alphabet and a `Status ∈ {InProgress, Completed, Withdrawn}`. |
| FR-24 | The system shall enforce the invariant that `Status='Completed' ⇒ Grade IS NOT NULL` and `Status IN ('InProgress', 'Withdrawn') ⇒ Grade IS NULL`. |
| FR-25 | The system shall **reject any Enrollment** that would cause the hosting Section's total enrollment to exceed the hosting Classroom's capacity (trigger `EnforceClassCapacity`). |

### 2.5 Reporting & analytics

| # | Requirement |
| --- | --- |
| FR-26 | The system shall expose a **StudentTranscript** view that joins Student → Application → Applicant / Program → Enrollment → Section → Course / Term to produce a complete academic record. |
| FR-27 | The system shall expose a **ClassroomUtilization** view that reports how many sections each classroom hosts. |
| FR-28 | The system shall support reporting of application-fee revenue per NET series, per-school conversion rate from Applicant to Student, per-Program average NET score of selected applicants, and per-school tuition revenue — without any denormalized cache columns. |
| FR-29 | The system shall expose at least one **stored procedure** (`GenerateTuitionChallan`) for recording a tuition payment for a given student, and at least one **function** (`IsEligibleForEngineering`) that returns whether an applicant has cleared the Engineering NET threshold. |
| FR-30 | The system shall support atomic **transactions** over multi-table admission workflows (create `Student` + record `Tuition` Fee) with `ROLLBACK` on any failure. |

### 2.6 Non-functional expectations

| # | Requirement |
| --- | --- |
| NFR-1 | Every invariant the business cares about shall be enforced by a declarative database constraint (PK / FK / UNIQUE / CHECK / trigger), not by application code. |
| NFR-2 | The schema shall be in **3NF** with no justified denormalizations. |
| NFR-3 | The seed script shall populate at least 10 meaningful rows per table and exercise every state in every enumerated `Status` column. |
| NFR-4 | Rebuilding the database from `db/NUST.sql` shall be idempotent: the script shall start with `DROP DATABASE IF EXISTS` and end with a fully populated, fully constrained database in under five seconds on commodity hardware. |

---

## 3. RAG-Based Natural Language Interface

### 3.1 Motivation

Non-technical stakeholders — admissions officers, program coordinators, finance staff, and department heads — need quick answers from the database but cannot write SQL. Even technically literate users find it friction-heavy to mentally map a business question ("Which school had the highest conversion rate this intake?") onto the multi-join queries the normalized schema requires. A natural-language interface removes this barrier without sacrificing the integrity of the underlying relational model.

### 3.2 What RAG adds to a SQL system

Standard text-to-SQL approaches send the user's question and the raw schema directly to an LLM and ask it to produce a query. This works for simple schemas but fails in four recurring ways for a schema of our complexity:

1. **Schema size.** Fifteen entities, dozens of columns, and a handful of views overload the context window if stuffed in verbatim.
2. **Semantic gap.** Column names like `ApplicationID` or `FeeType` are concise for a DBA but ambiguous for a language model without surrounding business context.
3. **Invariant blindness.** The LLM has no way to know that `Status='Completed' ⇒ Grade IS NOT NULL` or that the `XOR CHECK` on `Fee` splits payment rows into two logically distinct populations.
4. **Hallucinated syntax.** Without grounding, the model may invent table or column names that do not exist.

**Retrieval-Augmented Generation (RAG)** solves these by inserting a retrieval step between the user's question and the LLM. A vector store indexes rich, human-written descriptions of every table, column, view, stored procedure, trigger, and business rule. At query time the system embeds the question, retrieves the top-k most relevant chunks, and injects only those chunks into the prompt — giving the LLM precisely the context it needs, no more, no less.

### 3.3 System architecture

```
User question
      │
      ▼
 Embedding model (nomic-embed-text via Ollama)
      │  produces query vector
      ▼
 FAISS vector store  ──retrieves top-k chunks──►  Schema + rule context
      │
      ▼
 Prompt assembly
 ┌──────────────────────────────────────────────┐
 │  System: "You are a MySQL expert…"           │
 │  Retrieved context: table/column docs        │
 │  User question                               │
 └──────────────────────────────────────────────┘
      │
      ▼
 LLM (llama3.2 via Ollama)  ──generates──►  SQL query
      │
      ▼
 MySQL 8.0 execution engine
      │
      ▼
 Result rows  ──formatted──►  React frontend (table + chart)
```

The complete pipeline runs **locally**: both the embedding model and the LLM are served by Ollama on the user's machine, so no query text or database content leaves the institution's network.

### 3.4 Knowledge base construction

The vector store is built from a structured document corpus stored in `prompts/`. Each document chunk covers one coherent unit of schema knowledge:

| Chunk type | Example content |
| --- | --- |
| Table overview | Entity name, purpose, primary key, cardinality with neighbours |
| Column dictionary | Column name, data type, allowed values, business meaning |
| Constraint annotation | Which CHECK/UNIQUE/trigger enforces which business rule |
| View description | What each view joins and what questions it is designed to answer |
| Procedure / function doc | Inputs, outputs, side-effects, and the workflow it automates |
| Business-rule gloss | Plain-English statement of every invariant (XOR fee rule, capacity trigger, grade–status coupling) |
| Sample Q&A pairs | Representative questions and the SQL they should produce |

Chunks are embedded with `nomic-embed-text` (768-dimensional) and indexed in a FAISS flat-L2 store. The index is rebuilt whenever the schema or documentation changes.

### 3.5 Retrieval strategy

At query time:

1. The user question is embedded with the same model used at index time.
2. The top **5** nearest-neighbor chunks are retrieved (empirically sufficient; raising `k` improves coverage of multi-table questions at the cost of prompt length).
3. Retrieved chunks are prepended to the prompt in descending similarity order so the LLM sees the most relevant context first.
4. A fixed **system prompt** constrains the LLM to return only valid MySQL 8.0 syntax, to alias ambiguous column names, and to refuse questions that would require data not present in the schema.

### 3.6 Functional requirements — RAG layer

| # | Requirement |
| --- | --- |
| FR-31 | The system shall accept a free-text question from the user and return the SQL query, the raw result set, and a plain-English summary in a single API response. |
| FR-32 | The system shall embed user questions using the same model (`nomic-embed-text`) used to build the index, so that distance metrics are comparable. |
| FR-33 | The system shall retrieve the top-5 schema chunks most relevant to the user's question before generating SQL. |
| FR-34 | The system shall pass retrieved context plus user question to a locally-hosted LLM (`llama3.2` via Ollama) and must not transmit any query content to external services. |
| FR-35 | The system shall execute the generated SQL against the live `nust_university` database and return the result rows as JSON. |
| FR-36 | The system shall display query results in the React frontend as a sortable table and, where the result is numeric, as a bar or pie chart. |
| FR-37 | The system shall surface a clear error message when the LLM generates syntactically invalid SQL or when the query references a non-existent table or column, rather than silently returning an empty result. |
| FR-38 | The system shall allow the knowledge base to be rebuilt by running a single script (`prompts/build_index.py`) without restarting the API server. |

### 3.7 Non-functional requirements — RAG layer

| # | Requirement |
| --- | --- |
| NFR-5 | End-to-end latency from question submission to displayed results shall be **under 30 seconds** on the reference hardware (8 GB RAM, no GPU) for queries requiring at most three joins. |
| NFR-6 | The system shall run entirely **offline**: Ollama, the embedding model, the vector store, the API, and the frontend shall all operate without internet access after initial model download. |
| NFR-7 | The FAISS index shall be **persisted to disk** so the retrieval store survives API server restarts without requiring re-embedding. |
| NFR-8 | The system shall log each query, the retrieved chunk IDs, the generated SQL, and the row count returned, to support debugging and iterative improvement of the knowledge base. |
