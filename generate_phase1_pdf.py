from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUTPUT = "Phase1_Problem_and_Requirements.pdf"

doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=A4,
    leftMargin=2.5*cm, rightMargin=2.5*cm,
    topMargin=2.5*cm, bottomMargin=2.5*cm,
)

styles = getSampleStyleSheet()

title_style = ParagraphStyle("Title2", parent=styles["Title"],
    fontSize=18, spaceAfter=6, textColor=colors.HexColor("#1a1a2e"))

h1 = ParagraphStyle("H1", parent=styles["Heading1"],
    fontSize=13, spaceAfter=4, spaceBefore=14,
    textColor=colors.HexColor("#16213e"))

h2 = ParagraphStyle("H2", parent=styles["Heading2"],
    fontSize=11, spaceAfter=3, spaceBefore=10,
    textColor=colors.HexColor("#0f3460"))

body = ParagraphStyle("Body2", parent=styles["Normal"],
    fontSize=10, spaceAfter=4, leading=15)

meta = ParagraphStyle("Meta", parent=styles["Normal"],
    fontSize=9, textColor=colors.grey, spaceAfter=2)

bullet = ParagraphStyle("Bullet", parent=styles["Normal"],
    fontSize=10, leftIndent=18, spaceAfter=3, leading=14,
    bulletIndent=6)

TABLE_HEADER = colors.HexColor("#16213e")
TABLE_ALT    = colors.HexColor("#f0f4ff")

def req_table(rows):
    data = [["#", "Requirement"]] + rows
    t = Table(data, colWidths=[1.6*cm, 13.8*cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), TABLE_HEADER),
        ("TEXTCOLOR",  (0,0), (-1,0), colors.white),
        ("FONTNAME",   (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE",   (0,0), (-1,-1), 9),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, TABLE_ALT]),
        ("GRID",       (0,0), (-1,-1), 0.4, colors.HexColor("#cccccc")),
        ("VALIGN",     (0,0), (-1,-1), "TOP"),
        ("LEFTPADDING",(0,0),(-1,-1), 5),
        ("RIGHTPADDING",(0,0),(-1,-1), 5),
        ("TOPPADDING", (0,0),(-1,-1), 4),
        ("BOTTOMPADDING",(0,0),(-1,-1), 4),
    ]))
    return t

story = []

# ── Title ─────────────────────────────────────────────────────────────────────
story.append(Paragraph("Phase 1 — Problem Statement &amp; Requirements", title_style))
story.append(Paragraph("NUST Admissions &amp; Academic Records Database", meta))
story.append(Paragraph("Domain: Higher-Education Admissions | DBMS: MySQL 8.0+ (InnoDB)", meta))
story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#16213e"), spaceAfter=12))

# ── 1. Problem Statement ──────────────────────────────────────────────────────
story.append(Paragraph("1. Problem Statement", h1))

story.append(Paragraph("1.1 Domain Overview", h2))
story.append(Paragraph(
    "NUST operates over a dozen constituent schools (SEECS, NBS, SMME, SADA, …) offering 60+ undergraduate "
    "and graduate programs. Each admissions cycle processes tens of thousands of applicants through staged "
    "<b>NUST Entry Tests (NET)</b> — NET-1, NET-2, NBS NET, SADA NET, etc. Applicants apply to specific "
    "<i>programs</i> (e.g. BSCS at SEECS), rank their preferences, and each application moves through a "
    "lifecycle: <b>Pending → Selected → Enrolled</b> (with Waitlisted, Rejected, Declined as branches).",
    body))

story.append(Paragraph(
    "A payment ledger runs alongside: processing fees are charged per application; tuition, hostel, and "
    "library fees recur each semester. Historically these streams live in separate spreadsheets, making a "
    "unified \"lifetime ledger\" per student impossible without manual merging.",
    body))

story.append(Paragraph("1.2 Key Problems with Existing Systems", h2))
problems = [
    ("<b>Identity drift</b> — an applicant who becomes a student is often two unrelated rows in two unrelated "
     "systems, requiring manual reconciliation for scholarships or audits."),
    ("<b>Payment fragmentation</b> — processing fees and tuition fees live in separate databases; producing a "
     "single audit-ready ledger requires a custom export every time."),
    ("<b>Curriculum duplication</b> — courses shared across programs (e.g. CS118) are stored once per program "
     "instead of once per school, causing update anomalies when credit hours change."),
    ("<b>State collapse</b> — grade columns are overloaded with sentinels like 'IP' or 'W' to avoid adding a "
     "status column, breaking aggregates and sorts."),
    ("<b>Implicit invariants</b> — rules like 'one processing fee per application' live only in application "
     "code, not in the database, allowing duplicate charges under race conditions."),
]
for p in problems:
    story.append(Paragraph(f"• {p}", bullet))

story.append(Spacer(1, 4))
story.append(Paragraph("1.3 Our Solution", h2))
story.append(Paragraph(
    "A single normalized MySQL database — <b>nust_university</b> — connects admissions and academics through "
    "a strict 1:1 bridge: every <b>Student</b> row is linked to exactly one accepted <b>Application</b>, "
    "making the application record the single source of truth for identity and program. Fees are unified in "
    "one ledger table discriminated by <b>FeeType</b>. Course ownership moves to the school level, eliminating "
    "duplication. Enrollment status gets a dedicated column instead of sentinel grades. Every business "
    "invariant is a declarative database constraint.",
    body))
story.append(Paragraph(
    "A FastAPI backend and React frontend expose the database through a <b>natural-language interface</b> "
    "backed by a local Ollama LLM — so non-technical staff can query the database in plain English.",
    body))

story.append(HRFlowable(width="100%", thickness=0.5, color=colors.lightgrey, spaceAfter=8))

# ── 2. Functional Requirements ────────────────────────────────────────────────
story.append(Paragraph("2. Functional Requirements", h1))

story.append(Paragraph("2.1 Administrative Structure", h2))
story.append(req_table([
    ["FR-1", "Maintain a catalogue of Schools with unique name, location, and establishment year."],
    ["FR-2", "Maintain Programs (degrees) each belonging to one School, with degree type, duration (1–7 years), and seat quota."],
    ["FR-3", "Reject Programs with DurationYears outside [1, 7] or TotalSeats ≤ 0."],
]))
story.append(Spacer(1, 8))

story.append(Paragraph("2.2 Admissions Pipeline", h2))
story.append(req_table([
    ["FR-4",  "Record each Applicant once, keyed by unique email, with optional phone, DOB, city, and school marks."],
    ["FR-5",  "Reject high-school marks outside [0, 1100]."],
    ["FR-6",  "Maintain Entry Tests (NET series) with unique name, date, and stream type."],
    ["FR-7",  "Record TestScores as Applicant × EntryTest pairs; score must be in [0, 200]."],
    ["FR-8",  "Allow multiple Applications per Applicant (one per Program), with preference rank [1–5] and a status from {Pending, Selected, Waitlisted, Rejected, Enrolled, Declined}."],
    ["FR-9",  "Prevent duplicate applications: (ApplicantID, ProgramID) must be unique."],
    ["FR-10", "Record every Student as exactly one accepted Application, with CGPA in [0.00, 4.00] and status in {Active, Graduated, Suspended, Withdrawn}."],
    ["FR-11", "Auto-promote an Application to Enrolled when a matching Student row is inserted."],
]))
story.append(Spacer(1, 8))

story.append(Paragraph("2.3 Financial Pipeline", h2))
story.append(req_table([
    ["FR-12", "Maintain a unified Fee ledger recording all payments in a single table."],
    ["FR-13", "Classify each Fee by FeeType ∈ {Application, Tuition, Hostel, Library}."],
    ["FR-14", "Enforce XOR invariant: Application fees must reference an ApplicationID (not StudentID); all others must reference a StudentID (not ApplicationID)."],
    ["FR-15", "Allow at most one Application-type fee per Application."],
    ["FR-16", "Reject negative amounts or payment methods outside {Bank, Online, Cheque, Cash}."],
]))
story.append(Spacer(1, 8))

story.append(Paragraph("2.4 Academic Pipeline", h2))
story.append(req_table([
    ["FR-17", "Maintain Instructors employed by one School, with unique email and title from {Lecturer, Assistant Professor, Associate Professor, Professor}."],
    ["FR-18", "Maintain Courses owned by a School (not a Program), with unique CourseCode and credit hours in [1, 6]."],
    ["FR-19", "Express curricula via a ProgramCourse junction (M:N) carrying CourseType ∈ {Core, Elective} and recommended Semester [1–10]."],
    ["FR-20", "Maintain Terms (e.g. Fall 2025) with non-overlapping dates; reject terms where EndDate ≤ StartDate."],
    ["FR-21", "Maintain Classrooms owned by a School, with unique (School, RoomNumber), positive capacity, and RoomType ∈ {Lecture, Lab, Studio, Hall}."],
    ["FR-22", "Model each Section as one Course × one Term × one Instructor × one Classroom, unique on (CourseID, TermID, SectionName)."],
    ["FR-23", "Record Enrollments as Student × Section pairs, unique on (StudentID, SectionID), with nullable Grade and Status ∈ {InProgress, Completed, Withdrawn}."],
    ["FR-24", "Enforce: Completed status requires a non-null Grade; InProgress/Withdrawn require null Grade."],
    ["FR-25", "Reject enrollments that would exceed the hosting Classroom's capacity (trigger EnforceClassCapacity)."],
]))
story.append(Spacer(1, 8))

story.append(Paragraph("2.5 Reporting &amp; Analytics", h2))
story.append(req_table([
    ["FR-26", "Expose a StudentTranscript view joining Student → Application → Applicant / Program → Enrollment → Course / Term."],
    ["FR-27", "Expose a ClassroomUtilization view reporting sections hosted per classroom."],
    ["FR-28", "Support reports: application-fee revenue per NET series, school conversion rates, average NET score per program, tuition revenue per school — with no denormalized cache columns."],
    ["FR-29", "Provide stored procedure GenerateTuitionChallan and function IsEligibleForEngineering."],
    ["FR-30", "Support atomic transactions over multi-table workflows (e.g. create Student + record Tuition fee) with ROLLBACK on failure."],
]))
story.append(Spacer(1, 8))

story.append(Paragraph("2.6 Non-Functional Requirements", h2))
story.append(req_table([
    ["NFR-1", "Every business invariant must be enforced by a declarative DB constraint (PK/FK/UNIQUE/CHECK/trigger), not application code."],
    ["NFR-2", "Schema shall be in 3NF with no unjustified denormalization."],
    ["NFR-3", "Seed data shall populate at least 10 rows per table and exercise every status value."],
    ["NFR-4", "Rebuilding from db/NUST.sql must be idempotent (DROP DATABASE IF EXISTS) and complete in under 5 seconds on commodity hardware."],
]))

story.append(HRFlowable(width="100%", thickness=0.5, color=colors.lightgrey, spaceAfter=8))

# ── 3. RAG Natural-Language Interface ─────────────────────────────────────────
story.append(Paragraph("3. RAG-Based Natural Language Interface", h1))

story.append(Paragraph("3.1 Why a Natural-Language Layer?", h2))
story.append(Paragraph(
    "Non-technical staff (admissions officers, finance team, program coordinators) need quick answers but "
    "cannot write SQL. Mapping a business question like 'Which school had the highest conversion rate?' onto "
    "multi-join queries is too error-prone for casual users. A RAG interface removes this friction without "
    "changing the underlying relational model.",
    body))

story.append(Paragraph("3.2 How RAG Improves on Plain Text-to-SQL", h2))
problems2 = [
    "<b>Schema size</b> — 15 entities and dozens of columns overload an LLM's context window if sent verbatim.",
    "<b>Semantic gap</b> — column names like ApplicationID are ambiguous without business context.",
    "<b>Invariant blindness</b> — the LLM cannot infer XOR fee rules or capacity triggers from DDL alone.",
    "<b>Hallucinated syntax</b> — without grounding, the model may invent table or column names.",
]
for p in problems2:
    story.append(Paragraph(f"• {p}", bullet))
story.append(Paragraph(
    "RAG inserts a retrieval step: a vector store indexes rich descriptions of every table, column, view, "
    "trigger, and business rule. At query time the system fetches only the most relevant chunks and injects "
    "them into the prompt — giving the LLM precise context without bloat.",
    body))

story.append(Paragraph("3.3 System Architecture (Summary)", h2))
arch_data = [
    ["Step", "Component", "Detail"],
    ["1", "User question", "Free-text input in React frontend"],
    ["2", "Embedding", "nomic-embed-text (768-dim) via Ollama"],
    ["3", "Retrieval", "FAISS flat-L2, top-5 nearest chunks"],
    ["4", "Prompt assembly", "System prompt + retrieved context + question"],
    ["5", "LLM generation", "llama3.2 via Ollama → MySQL 8.0 query"],
    ["6", "Execution", "Live nust_university database"],
    ["7", "Display", "Sortable table + bar/pie chart in React"],
]
arch_t = Table(arch_data, colWidths=[1.2*cm, 3.5*cm, 10.7*cm])
arch_t.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (-1,0), TABLE_HEADER),
    ("TEXTCOLOR",  (0,0), (-1,0), colors.white),
    ("FONTNAME",   (0,0), (-1,0), "Helvetica-Bold"),
    ("FONTSIZE",   (0,0), (-1,-1), 9),
    ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, TABLE_ALT]),
    ("GRID",       (0,0), (-1,-1), 0.4, colors.HexColor("#cccccc")),
    ("VALIGN",     (0,0), (-1,-1), "TOP"),
    ("LEFTPADDING",(0,0),(-1,-1), 5),
    ("RIGHTPADDING",(0,0),(-1,-1), 5),
    ("TOPPADDING", (0,0),(-1,-1), 4),
    ("BOTTOMPADDING",(0,0),(-1,-1), 4),
]))
story.append(arch_t)
story.append(Spacer(1, 6))
story.append(Paragraph(
    "<i>The full pipeline runs locally — Ollama, the vector store, the API, and the frontend all operate "
    "offline after the initial model download.</i>",
    ParagraphStyle("italic", parent=body, textColor=colors.grey, fontSize=9)))

story.append(Spacer(1, 8))
story.append(Paragraph("3.4 Functional Requirements — RAG Layer", h2))
story.append(req_table([
    ["FR-31", "Accept a free-text question and return the SQL query, raw results, and a plain-English summary in one API response."],
    ["FR-32", "Embed questions using nomic-embed-text (same model as index-build time) for comparable distances."],
    ["FR-33", "Retrieve top-5 schema chunks most relevant to the question before generating SQL."],
    ["FR-34", "Pass context + question to a locally-hosted LLM (llama3.2 via Ollama); no query content leaves the network."],
    ["FR-35", "Execute generated SQL against the live database and return result rows as JSON."],
    ["FR-36", "Display results as a sortable table and, for numeric data, as a bar or pie chart."],
    ["FR-37", "Surface a clear error message for invalid SQL or non-existent table/column references."],
    ["FR-38", "Allow knowledge base rebuild via a single script (prompts/build_index.py) without restarting the API."],
]))

story.append(Spacer(1, 8))
story.append(Paragraph("3.5 Non-Functional Requirements — RAG Layer", h2))
story.append(req_table([
    ["NFR-5", "End-to-end latency from question to displayed results shall be under 30 seconds on 8 GB RAM / no GPU for ≤ 3-join queries."],
    ["NFR-6", "System shall run entirely offline after initial model download (Ollama, vector store, API, frontend)."],
    ["NFR-7", "FAISS index shall be persisted to disk so it survives API restarts without re-embedding."],
    ["NFR-8", "Each query, retrieved chunk IDs, generated SQL, and row count shall be logged for debugging and knowledge-base improvement."],
]))

doc.build(story)
print(f"PDF written to {OUTPUT}")
