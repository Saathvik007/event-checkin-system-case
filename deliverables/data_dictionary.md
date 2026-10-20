# Data dictionary

This is the SQLite database for the event check-in prototype, and all the data in it is synthetic. The core tables follow the rules of the new process. The legacy_* tables keep the old spreadsheets exactly as they were, so they can be checked later. sql/data_dictionary.sql makes this file from the database itself.

## students

Student roster from the registrar. One row per enrolled student. This is the official list of who is a student. Rows in the synthetic database: 1,800.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| student_id | TEXT | Yes | PK | Student ID, 'S' plus six digits. Primary key. |
| first_name | TEXT | Yes |  | First name from the roster. |
| last_name | TEXT | Yes |  | Last name from the roster. |
| school_email | TEXT | Yes |  | University email address. No two students have the same one. |
| class_year | INTEGER | Yes |  | Expected graduation year (2025-2032). |
| major_group | TEXT | Yes |  | Broad field of study. |

## employers

Employers that recruit through the office. One row per employer. Rows in the synthetic database: 30.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| employer_id | TEXT | Yes | PK | Employer code, like EMP07. Primary key. |
| employer_name | TEXT | Yes |  | Name shown for the employer. No two employers have the same one. |
| sector | TEXT | Yes |  | Industry group. |
| recruiter_email | TEXT | Yes |  | Where attendee lists are sent. |

## events

Recruiting events. One row per event. Rows in the synthetic database: 40.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event code, like E005. Primary key. |
| event_name | TEXT | Yes |  | Title shown to students. |
| event_type | TEXT | Yes |  | Career fair, Info session, Employer panel, Workshop or Networking night. |
| starts_at | TEXT | Yes |  | Start time, 'YYYY-MM-DD HH:MM' in local time. |
| ends_at | TEXT | Yes |  | End time in the same format. It has to be after starts_at. |
| location | TEXT | Yes |  | Room or venue. |
| capacity | INTEGER | Yes |  | How many people the room holds. Online registrations past this number go on the waitlist. |

## event_employers

Which employers take part in each event. One row per event and employer. Rows in the synthetic database: 71.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event, from the events table. Part of the primary key. |
| employer_id | TEXT | Yes | PK | Employer, from the employers table. Part of the primary key. |

Foreign keys: employer_id -> employers.employer_id; event_id -> events.event_id.

## registrations

Student sign-ups. A student can only have one row per event. Rows in the synthetic database: 3,042.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| registration_id | INTEGER | Yes | PK | ID the database assigns automatically. |
| event_id | TEXT | Yes |  | Event the student registered for (from events). |
| student_id | TEXT | Yes |  | Student who registered (from students). Required. |
| contact_email | TEXT | Yes |  | Email for confirmations. It has to look like an address (one @ and no spaces). |
| registered_at | TEXT | Yes |  | When the registration was made, 'YYYY-MM-DD HH:MM'. |
| channel | TEXT | Yes |  | Online form, Staff entry or Legacy import. |
| status | TEXT | Yes |  | Registered, Waitlisted or Cancelled. Only Registered counts toward attendance and no-shows. |

Foreign keys: event_id -> events.event_id; student_id -> students.student_id.

## checkins

Students who arrived at events. A student can only be checked in once per event. Rows in the synthetic database: 1,766.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| checkin_id | INTEGER | Yes | PK | ID the database assigns automatically. |
| event_id | TEXT | Yes |  | Event the student came to (from events). |
| student_id | TEXT | Yes |  | Student who checked in (from students). Required. |
| registration_id | INTEGER | No |  | The student's active registration for this event. Empty (NULL) for a walk-in. |
| checked_in_at | TEXT | Yes |  | Check-in time. It has to be between 60 minutes before the start and the end of the event. |
| method | TEXT | Yes |  | QR scan, ID card, Manual lookup or Legacy import. |

Foreign keys: event_id -> events.event_id; registration_id -> registrations.registration_id; student_id -> students.student_id.

## follow_ups

Attendee lists owed to employers. One row per event and employer. Rows in the synthetic database: 71.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| event_id | TEXT | Yes | PK | Event. Together with employer_id it has to match a row in event_employers. |
| employer_id | TEXT | Yes | PK | Employer who should get the attendee list. |
| due_date | TEXT | Yes |  | Three business days after the event. |
| sent_date | TEXT | No |  | Date the list was sent. Empty (NULL) until then. |

Foreign keys: (event_id, employer_id) -> event_employers(event_id, employer_id).

## report_settings

Holds the reporting date. It has just one row. Rows in the synthetic database: 1.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| as_of_date | TEXT | Yes |  | The date the reports use as today, so running them again gives the same results. |

## load_exceptions

Log of every legacy row the migration changed or held back. Rows in the synthetic database: 863.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| exception_id | INTEGER | Yes | PK | ID the database assigns automatically. |
| source_table | TEXT | Yes |  | Legacy sheet (or reference table) the problem came from. |
| source_row_id | INTEGER | No |  | row_id in that sheet. Empty (NULL) when the problem is a missing row. |
| record_key | TEXT | No |  | Event plus student, email or employer, so staff can follow up. |
| issue | TEXT | Yes |  | What was wrong, for example Missing student ID or Duplicate registration. |
| action_taken | TEXT | Yes |  | What the migration did. Rows marked 'Held for review' were not loaded. |

## legacy_registrations

The registration spreadsheet as staff keep it today, loaded as text with no changes. Rows in the synthetic database: 3,258.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code typed by staff. |
| student_id | TEXT | No |  | As typed. Can be blank or wrong. |
| full_name | TEXT | No |  | As typed. |
| email | TEXT | No |  | As typed. Can be a personal address or badly formatted. |
| registered_on | TEXT | No |  | Time stamp from the form. |
| status | TEXT | No |  | Free text, with several spellings of Registered and Cancelled. |

## legacy_signins

The paper and tablet sign-in sheets after they were typed up, loaded as text with no changes. Rows in the synthetic database: 1,836.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code. |
| student_id | TEXT | No |  | As written. Can be blank. |
| full_name | TEXT | No |  | As written. |
| email | TEXT | No |  | As written. Can be a personal address or mistyped. |
| signed_in_at | TEXT | No |  | Time as typed. Some have the date the sheet was typed up instead of the event date. |
| sheet_type | TEXT | No |  | Paper sheet or Tablet. |

## legacy_followups

The follow-up tracker staff keep by hand, loaded as text with no changes. Rows in the synthetic database: 68.

| Column | Type | Required | Key | Description |
|---|---|---|---|---|
| row_id | INTEGER | Yes | PK | Row number in the sheet. |
| event_code | TEXT | No |  | Event code. |
| employer_name | TEXT | No |  | As typed. The spelling varies. |
| sent_on | TEXT | No |  | Date sent. Blank if it was not sent. |
| notes | TEXT | No |  | Free text. |
