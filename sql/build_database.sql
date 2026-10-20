-- Builds data/checkin_synthetic.db: creates the schema, loads the synthetic CSVs from
-- data/synthetic/, then runs the legacy migration.
-- Run from the project folder:  sqlite3 data/checkin_synthetic.db < sql/build_database.sql
-- Running it again rebuilds everything from scratch.

.bail on

-- Start clean. Foreign keys are switched off while dropping so the order does not matter.
PRAGMA foreign_keys = OFF;
DROP TABLE IF EXISTS checkins;
DROP TABLE IF EXISTS registrations;
DROP TABLE IF EXISTS follow_ups;
DROP TABLE IF EXISTS event_employers;
DROP TABLE IF EXISTS load_exceptions;
DROP TABLE IF EXISTS report_settings;
DROP TABLE IF EXISTS legacy_registrations;
DROP TABLE IF EXISTS legacy_signins;
DROP TABLE IF EXISTS legacy_followups;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS employers;
DROP TABLE IF EXISTS students;
PRAGMA foreign_keys = ON;

.read sql/schema.sql

-- Each CSV goes into a staging table first (.import names its columns from the header row),
-- then into the real table by column name, so the CSV column order does not matter.
-- Reference data goes into the core tables. The legacy sheets go into legacy_* tables as text.

DROP TABLE IF EXISTS stage;
.import --csv data/synthetic/students.csv stage
INSERT INTO students (student_id, first_name, last_name, school_email, class_year, major_group)
SELECT student_id, first_name, last_name, school_email, class_year, major_group FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/employers.csv stage
INSERT INTO employers (employer_id, employer_name, sector, recruiter_email)
SELECT employer_id, employer_name, sector, recruiter_email FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/events.csv stage
INSERT INTO events (event_id, event_name, event_type, starts_at, ends_at, location, capacity)
SELECT event_id, event_name, event_type, starts_at, ends_at, location, capacity FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/event_employers.csv stage
INSERT INTO event_employers (event_id, employer_id)
SELECT event_id, employer_id FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/legacy_registrations.csv stage
INSERT INTO legacy_registrations (row_id, event_code, student_id, full_name, email, registered_on, status)
SELECT row_id, event_code, student_id, full_name, email, registered_on, status FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/legacy_signins.csv stage
INSERT INTO legacy_signins (row_id, event_code, student_id, full_name, email, signed_in_at, sheet_type)
SELECT row_id, event_code, student_id, full_name, email, signed_in_at, sheet_type FROM stage;
DROP TABLE stage;

.import --csv data/synthetic/legacy_followups.csv stage
INSERT INTO legacy_followups (row_id, event_code, employer_name, sent_on, notes)
SELECT row_id, event_code, employer_name, sent_on, notes FROM stage;
DROP TABLE stage;

-- Move the legacy sheets into the core tables and log every change.
.read sql/migrate_legacy.sql

-- Stop with an error if any row points to something that does not exist.
CREATE TEMP TABLE build_guard (
    bad_references INTEGER CONSTRAINT no_foreign_key_violations CHECK (bad_references = 0));
INSERT INTO build_guard SELECT COUNT(*) FROM pragma_foreign_key_check;
DROP TABLE build_guard;

VACUUM;

.mode list
.headers off
SELECT 'students        ' || (SELECT COUNT(*) FROM students);
SELECT 'events          ' || (SELECT COUNT(*) FROM events);
SELECT 'registrations   ' || (SELECT COUNT(*) FROM registrations);
SELECT 'checkins        ' || (SELECT COUNT(*) FROM checkins);
SELECT 'follow_ups      ' || (SELECT COUNT(*) FROM follow_ups);
SELECT 'load_exceptions ' || (SELECT COUNT(*) FROM load_exceptions);
