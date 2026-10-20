-- Writes deliverables/data_dictionary.md and deliverables/data_dictionary.csv from the live
-- database plus the descriptions below.
-- Run from the project folder, after build_database.sql:
--   sqlite3 data/checkin_synthetic.db < sql/data_dictionary.sql
-- It stops with an error if a column in the database has no description, or a description
-- names a column that no longer exists, so the dictionary always matches the database.

.bail on

-- What each table is for, in the order the dictionary lists them.
CREATE TEMP TABLE dd_tables (ord INTEGER, table_name TEXT, purpose TEXT);
INSERT INTO dd_tables VALUES
    (1, 'students', 'Student roster from the registrar. One row per enrolled student. This is the official list of who is a student.'),
    (2, 'employers', 'Employers that recruit through the office. One row per employer.'),
    (3, 'events', 'Recruiting events. One row per event.'),
    (4, 'event_employers', 'Which employers take part in each event. One row per event and employer.'),
    (5, 'registrations', 'Student sign-ups. A student can only have one row per event.'),
    (6, 'checkins', 'Students who arrived at events. A student can only be checked in once per event.'),
    (7, 'follow_ups', 'Attendee lists owed to employers. One row per event and employer.'),
    (8, 'report_settings', 'Holds the reporting date. It has just one row.'),
    (9, 'load_exceptions', 'Log of every legacy row the migration changed or held back.'),
    (10, 'legacy_registrations', 'The registration spreadsheet as staff keep it today, loaded as text with no changes.'),
    (11, 'legacy_signins', 'The paper and tablet sign-in sheets after they were typed up, loaded as text with no changes.'),
    (12, 'legacy_followups', 'The follow-up tracker staff keep by hand, loaded as text with no changes.');

-- One description per column.
CREATE TEMP TABLE dd_notes (table_name TEXT, column_name TEXT, description TEXT);
INSERT INTO dd_notes VALUES
    ('students', 'student_id', 'Student ID, ''S'' plus six digits. Primary key.'),
    ('students', 'first_name', 'First name from the roster.'),
    ('students', 'last_name', 'Last name from the roster.'),
    ('students', 'school_email', 'University email address. No two students have the same one.'),
    ('students', 'class_year', 'Expected graduation year (2025-2032).'),
    ('students', 'major_group', 'Broad field of study.'),
    ('employers', 'employer_id', 'Employer code, like EMP07. Primary key.'),
    ('employers', 'employer_name', 'Name shown for the employer. No two employers have the same one.'),
    ('employers', 'sector', 'Industry group.'),
    ('employers', 'recruiter_email', 'Where attendee lists are sent.'),
    ('events', 'event_id', 'Event code, like E005. Primary key.'),
    ('events', 'event_name', 'Title shown to students.'),
    ('events', 'event_type', 'Career fair, Info session, Employer panel, Workshop or Networking night.'),
    ('events', 'starts_at', 'Start time, ''YYYY-MM-DD HH:MM'' in local time.'),
    ('events', 'ends_at', 'End time in the same format. It has to be after starts_at.'),
    ('events', 'location', 'Room or venue.'),
    ('events', 'capacity', 'How many people the room holds. Online registrations past this number go on the waitlist.'),
    ('event_employers', 'event_id', 'Event, from the events table. Part of the primary key.'),
    ('event_employers', 'employer_id', 'Employer, from the employers table. Part of the primary key.'),
    ('registrations', 'registration_id', 'ID the database assigns automatically.'),
    ('registrations', 'event_id', 'Event the student registered for (from events).'),
    ('registrations', 'student_id', 'Student who registered (from students). Required.'),
    ('registrations', 'contact_email', 'Email for confirmations. It has to look like an address (one @ and no spaces).'),
    ('registrations', 'registered_at', 'When the registration was made, ''YYYY-MM-DD HH:MM''.'),
    ('registrations', 'channel', 'Online form, Staff entry or Legacy import.'),
    ('registrations', 'status', 'Registered, Waitlisted or Cancelled. Only Registered counts toward attendance and no-shows.'),
    ('checkins', 'checkin_id', 'ID the database assigns automatically.'),
    ('checkins', 'event_id', 'Event the student came to (from events).'),
    ('checkins', 'student_id', 'Student who checked in (from students). Required.'),
    ('checkins', 'registration_id', 'The student''s active registration for this event. Empty (NULL) for a walk-in.'),
    ('checkins', 'checked_in_at', 'Check-in time. It has to be between 60 minutes before the start and the end of the event.'),
    ('checkins', 'method', 'QR scan, ID card, Manual lookup or Legacy import.'),
    ('follow_ups', 'event_id', 'Event. Together with employer_id it has to match a row in event_employers.'),
    ('follow_ups', 'employer_id', 'Employer who should get the attendee list.'),
    ('follow_ups', 'due_date', 'Three business days after the event.'),
    ('follow_ups', 'sent_date', 'Date the list was sent. Empty (NULL) until then.'),
    ('report_settings', 'as_of_date', 'The date the reports use as today, so running them again gives the same results.'),
    ('load_exceptions', 'exception_id', 'ID the database assigns automatically.'),
    ('load_exceptions', 'source_table', 'Legacy sheet (or reference table) the problem came from.'),
    ('load_exceptions', 'source_row_id', 'row_id in that sheet. Empty (NULL) when the problem is a missing row.'),
    ('load_exceptions', 'record_key', 'Event plus student, email or employer, so staff can follow up.'),
    ('load_exceptions', 'issue', 'What was wrong, for example Missing student ID or Duplicate registration.'),
    ('load_exceptions', 'action_taken', 'What the migration did. Rows marked ''Held for review'' were not loaded.'),
    ('legacy_registrations', 'row_id', 'Row number in the sheet.'),
    ('legacy_registrations', 'event_code', 'Event code typed by staff.'),
    ('legacy_registrations', 'student_id', 'As typed. Can be blank or wrong.'),
    ('legacy_registrations', 'full_name', 'As typed.'),
    ('legacy_registrations', 'email', 'As typed. Can be a personal address or badly formatted.'),
    ('legacy_registrations', 'registered_on', 'Time stamp from the form.'),
    ('legacy_registrations', 'status', 'Free text, with several spellings of Registered and Cancelled.'),
    ('legacy_signins', 'row_id', 'Row number in the sheet.'),
    ('legacy_signins', 'event_code', 'Event code.'),
    ('legacy_signins', 'student_id', 'As written. Can be blank.'),
    ('legacy_signins', 'full_name', 'As written.'),
    ('legacy_signins', 'email', 'As written. Can be a personal address or mistyped.'),
    ('legacy_signins', 'signed_in_at', 'Time as typed. Some have the date the sheet was typed up instead of the event date.'),
    ('legacy_signins', 'sheet_type', 'Paper sheet or Tablet.'),
    ('legacy_followups', 'row_id', 'Row number in the sheet.'),
    ('legacy_followups', 'event_code', 'Event code.'),
    ('legacy_followups', 'employer_name', 'As typed. The spelling varies.'),
    ('legacy_followups', 'sent_on', 'Date sent. Blank if it was not sent.'),
    ('legacy_followups', 'notes', 'Free text.');

-- Every column in the database, read from the schema itself.
CREATE TEMP TABLE dd_columns AS
SELECT d.ord, d.table_name, p.cid, p.name AS column_name, COALESCE(NULLIF(p.type, ''), 'TEXT') AS col_type,
       CASE WHEN p."notnull" OR p.pk THEN 'Yes' ELSE 'No' END AS required, p.pk
FROM dd_tables d, pragma_table_info(d.table_name) p;

-- Stop if the tables or columns are out of sync with the descriptions.
CREATE TEMP TABLE dd_guard (
    mismatches INTEGER CONSTRAINT dictionary_must_match_schema CHECK (mismatches = 0));
INSERT INTO dd_guard SELECT
    (SELECT COUNT(*) FROM sqlite_schema
     WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT IN (SELECT table_name FROM dd_tables))
  + (SELECT COUNT(*) FROM dd_tables WHERE table_name NOT IN
        (SELECT name FROM sqlite_schema WHERE type = 'table'))
  + (SELECT COUNT(*) FROM dd_columns c WHERE NOT EXISTS
        (SELECT 1 FROM dd_notes n WHERE n.table_name = c.table_name AND n.column_name = c.column_name))
  + (SELECT COUNT(*) FROM dd_notes n WHERE NOT EXISTS
        (SELECT 1 FROM dd_columns c WHERE c.table_name = n.table_name AND c.column_name = n.column_name));

-- Row counts for the table descriptions.
CREATE TEMP TABLE dd_counts AS
SELECT 'students' AS table_name, COUNT(*) AS n FROM students
UNION ALL SELECT 'employers' AS table_name, COUNT(*) AS n FROM employers
UNION ALL SELECT 'events' AS table_name, COUNT(*) AS n FROM events
UNION ALL SELECT 'event_employers' AS table_name, COUNT(*) AS n FROM event_employers
UNION ALL SELECT 'registrations' AS table_name, COUNT(*) AS n FROM registrations
UNION ALL SELECT 'checkins' AS table_name, COUNT(*) AS n FROM checkins
UNION ALL SELECT 'follow_ups' AS table_name, COUNT(*) AS n FROM follow_ups
UNION ALL SELECT 'report_settings' AS table_name, COUNT(*) AS n FROM report_settings
UNION ALL SELECT 'load_exceptions' AS table_name, COUNT(*) AS n FROM load_exceptions
UNION ALL SELECT 'legacy_registrations' AS table_name, COUNT(*) AS n FROM legacy_registrations
UNION ALL SELECT 'legacy_signins' AS table_name, COUNT(*) AS n FROM legacy_signins
UNION ALL SELECT 'legacy_followups' AS table_name, COUNT(*) AS n FROM legacy_followups;

-- Foreign keys, one line per table. A key made of two columns reads as one reference:
-- (a, b) -> table(x, y). A single column reads as a -> table.x.
CREATE TEMP TABLE dd_fk AS
WITH k AS (
    SELECT d.ord, d.table_name, f.id, f."table" AS ref_table,
           group_concat(f."from", ', ') AS from_cols, group_concat(f."to", ', ') AS to_cols, COUNT(*) AS n
    FROM dd_tables d, pragma_foreign_key_list(d.table_name) f
    GROUP BY d.ord, d.table_name, f.id
),
r AS (
    SELECT ord, table_name,
           CASE WHEN n > 1 THEN '(' || from_cols || ') -> ' || ref_table || '(' || to_cols || ')'
                ELSE from_cols || ' -> ' || ref_table || '.' || to_cols END AS ref
    FROM k
)
SELECT ord, table_name,
       (SELECT group_concat(ref, '; ') FROM (SELECT ref FROM r r2 WHERE r2.table_name = r.table_name ORDER BY ref)) AS refs
FROM r GROUP BY ord, table_name;

-- The Markdown file, built line by line in order.
.headers off
.mode list
.output deliverables/data_dictionary.md
WITH lines (t, l, line) AS (
    SELECT 0, 0, '# Data dictionary'
    UNION ALL SELECT 0, 1, ''
    UNION ALL SELECT 0, 2, 'This is the SQLite database for the event check-in prototype, and all the data in it is synthetic. The core tables follow the rules of the new process. The legacy_* tables keep the old spreadsheets exactly as they were, so they can be checked later. sql/data_dictionary.sql makes this file from the database itself.'
    UNION ALL SELECT 0, 3, ''
    UNION ALL SELECT ord, 0, '## ' || table_name FROM dd_tables
    UNION ALL SELECT ord, 1, '' FROM dd_tables
    UNION ALL SELECT d.ord, 2, d.purpose || ' Rows in the synthetic database: ' || printf('%,d', c.n) || '.'
              FROM dd_tables d JOIN dd_counts c ON c.table_name = d.table_name
    UNION ALL SELECT ord, 3, '' FROM dd_tables
    UNION ALL SELECT ord, 4, '| Column | Type | Required | Key | Description |' FROM dd_tables
    UNION ALL SELECT ord, 5, '|---|---|---|---|---|' FROM dd_tables
    UNION ALL SELECT c.ord, 10 + c.cid,
              '| ' || c.column_name || ' | ' || c.col_type || ' | ' || c.required || ' | '
              || CASE WHEN c.pk THEN 'PK' ELSE '' END || ' | ' || n.description || ' |'
              FROM dd_columns c JOIN dd_notes n ON n.table_name = c.table_name AND n.column_name = c.column_name
    UNION ALL SELECT ord, 1000, '' FROM dd_fk
    UNION ALL SELECT ord, 1001, 'Foreign keys: ' || refs || '.' FROM dd_fk
    UNION ALL SELECT ord, 2000, '' FROM dd_tables WHERE ord < (SELECT MAX(ord) FROM dd_tables)
)
SELECT line FROM lines ORDER BY t, l;

-- The same columns as a CSV.
.headers on
.mode csv
.output deliverables/data_dictionary.csv
SELECT c.table_name AS "table", c.column_name AS "column", c.col_type AS type, c.required,
       CASE WHEN c.pk THEN 'Yes' ELSE 'No' END AS primary_key, n.description
FROM dd_columns c JOIN dd_notes n ON n.table_name = c.table_name AND n.column_name = c.column_name
ORDER BY c.ord, c.cid;
.output stdout

.headers off
.mode list
SELECT 'Data dictionary: ' || (SELECT COUNT(*) FROM dd_tables) || ' tables, ' || (SELECT COUNT(*) FROM dd_columns) || ' columns';
