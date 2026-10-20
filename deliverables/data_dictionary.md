# Data dictionary

This is the SQLite database for the event check-in prototype, and all the data in it is synthetic. The core tables follow the rules of the new process. The legacy_* tables keep the old spreadsheets exactly as they were, so they can be checked later. sql/data_dictionary.sql makes this file from the database itself.

## students

Registrar roster. One row per enrolled student; the system of record for identity. Rows in the synthetic database: 1,800.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| student_id | TEXT | Yes | PK | Student ID, 'S' plus six digits. Primary key. |
| first_name | TEXT | Yes |  | Given name from the roster. |
| last_name | TEXT | Yes |  | Family name from the roster. |
| school_email | TEXT | Yes |  | University email address. Unique. |
| class_year | INTEGER | Yes |  | Expected graduation year (2025-2032). |
| major_group | TEXT | Yes |  | Broad field of study. |

## employers

Employers that recruit through the office. One row per employer. Rows in the synthetic database: 30.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| employer_id | TEXT | Yes | PK | Employer code, e.g. EMP07. Primary key. |
| employer_name | TEXT | Yes |  | Display name. Unique. |
| sector | TEXT | Yes |  | Industry group. |
| recruiter_email | TEXT | Yes |  | Where attendee lists are sent. |

## events

Recruiting events. One row per event. Rows in the synthetic database: 40.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event code, e.g. E005. Primary key. |
| event_name | TEXT | Yes |  | Title shown to students. |
| event_type | TEXT | Yes |  | Career fair, Info session, Employer panel, Workshop or Networking night. |
| starts_at | TEXT | Yes |  | Start, 'YYYY-MM-DD HH:MM' local time. |
| ends_at | TEXT | Yes |  | End, same format; must be after starts_at. |
| location | TEXT | Yes |  | Room or venue. |
| capacity | INTEGER | Yes |  | Room capacity; online registrations beyond it are waitlisted. |

## event_employers

Which employers take part in each event. One row per event and employer. Rows in the synthetic database: 71.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event. Part of the primary key; references events. |
| employer_id | TEXT | Yes | PK | Employer. Part of the primary key; references employers. |

Foreign keys: employer_id -> employers.employer_id; event_id -> events.event_id.

## registrations

Student sign-ups. One row per student per event (unique). Rows in the synthetic database: 3,042.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| registration_id | INTEGER | Yes | PK | System-generated key. |
| event_id | TEXT | Yes |  | Event registered for; references events. |
| student_id | TEXT | Yes |  | Registering student; references students. Required. |
| contact_email | TEXT | Yes |  | Email for confirmations; must look like an address (one @, no spaces). |
| registered_at | TEXT | Yes |  | When the registration was made, 'YYYY-MM-DD HH:MM'. |
| channel | TEXT | Yes |  | Online form, Staff entry or Legacy import. |
| status | TEXT | Yes |  | Registered, Waitlisted or Cancelled. Only Registered counts toward attendance and no-shows. |

Foreign keys: event_id -> events.event_id; student_id -> students.student_id.

## checkins

Arrivals at events. One row per student per event (unique). Rows in the synthetic database: 1,766.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| checkin_id | INTEGER | Yes | PK | System-generated key. |
| event_id | TEXT | Yes |  | Event attended; references events. |
| student_id | TEXT | Yes |  | Student checked in; references students. Required. |
| registration_id | INTEGER | No |  | Matching active registration; NULL means a walk-in. |
| checked_in_at | TEXT | Yes |  | Check-in time; must fall between 60 minutes before start and the end. |
| method | TEXT | Yes |  | QR scan, ID card, Manual lookup or Legacy import. |

Foreign keys: event_id -> events.event_id; registration_id -> registrations.registration_id; student_id -> students.student_id.

## follow_ups

Attendee lists owed to employers. One row per event and employer. Rows in the synthetic database: 71.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event; with employer_id, references event_employers. |
| employer_id | TEXT | Yes | PK | Employer owed the list. |
| due_date | TEXT | Yes |  | Three business days after the event. |
| sent_date | TEXT | No |  | Date the list was sent; NULL until sent. |

Foreign keys: (event_id, employer_id) -> event_employers(event_id, employer_id).

## report_settings

Single-row table holding the reporting date. Rows in the synthetic database: 1.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| as_of_date | TEXT | Yes |  | Date reports treat as today, so results are repeatable. |

## load_exceptions

Log of every legacy row the migration changed or held back. Rows in the synthetic database: 863.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| exception_id | INTEGER | Yes | PK | System-generated key. |
| source_table | TEXT | Yes |  | Legacy sheet (or reference table) the problem came from. |
| source_row_id | INTEGER | No |  | row_id in that sheet; NULL when the problem is a missing row. |
| record_key | TEXT | No |  | Event plus student, email or employer, for staff follow-up. |
| issue | TEXT | Yes |  | What was wrong, e.g. Missing student ID, Duplicate registration. |
| action_taken | TEXT | Yes |  | What the migration did; 'Held for review' rows were not loaded. |

## legacy_registrations

Registration spreadsheet as kept today, loaded as text without changes. Rows in the synthetic database: 3,258.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code typed by staff. |
| student_id | TEXT | No |  | As typed; may be blank or wrong. |
| full_name | TEXT | No |  | As typed. |
| email | TEXT | No |  | As typed; may be personal or malformed. |
| registered_on | TEXT | No |  | Form timestamp. |
| status | TEXT | No |  | Free text; several spellings of Registered and Cancelled. |

## legacy_signins

Typed-up paper and tablet sign-in sheets, loaded as text without changes. Rows in the synthetic database: 1,836.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code. |
| student_id | TEXT | No |  | As written; may be blank. |
| full_name | TEXT | No |  | As written. |
| email | TEXT | No |  | As written; may be personal or mistyped. |
| signed_in_at | TEXT | No |  | Time as typed; some carry the data-entry date. |
| sheet_type | TEXT | No |  | Paper sheet or Tablet. |

## legacy_followups

Hand-kept follow-up tracker, loaded as text without changes. Rows in the synthetic database: 68.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code. |
| employer_name | TEXT | No |  | As typed; spelling varies. |
| sent_on | TEXT | No |  | Date sent; blank if not sent. |
| notes | TEXT | No |  | Free text. |
