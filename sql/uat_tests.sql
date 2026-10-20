-- Runs the 18 user acceptance tests against the prototype database and saves the actual
-- results to deliverables/uat_test_cases.csv.
-- Run from the project folder, after build_database.sql:
--   sqlite3 < sql/uat_tests.sql
-- Every test runs on a fresh in-memory copy of data/checkin_synthetic.db (schema "t"), so the
-- tests cannot affect each other or the saved database.
-- Several tests try something the database should refuse. The shell prints those errors
-- ("Runtime error ... constraint failed") and keeps going; that is expected. The exact error
-- text is caught with .log and read back from data/uat_error.log.

.bail off
.headers off
.mode list
PRAGMA foreign_keys = ON;

-- The test plan: what each test does and what should happen ---------------------------------
CREATE TABLE uat_cases (test_id TEXT PRIMARY KEY, requirement TEXT, test TEXT, steps TEXT, expected_result TEXT);
INSERT INTO uat_cases VALUES
    ('UAT-01', 'FR-03', 'Check in a registered student', 'Register a student online for an info session, then scan their QR code 2 minutes after start.', 'Check-in saved and linked to the registration; attended count for the event rises by 1.'),
    ('UAT-02', 'FR-04', 'Check in a walk-in', 'Look up a rostered student with no registration and check them in.', 'Check-in saved with no registration; walk-in count for the event rises by 1.'),
    ('UAT-03', 'FR-05', 'Block a second check-in', 'Check in a student who is already checked in to the event.', 'Rejected as a duplicate (unique constraint).'),
    ('UAT-04', 'FR-02', 'Block a duplicate registration', 'Register a student again for an event they are already registered for.', 'Rejected as a duplicate (unique constraint).'),
    ('UAT-05', 'FR-01', 'Reject a malformed email', 'Submit a registration with the email ''student.university.example''.', 'Rejected by the email format check.'),
    ('UAT-06', 'FR-11', 'Reject an unknown student', 'Check in student ID S999999, which is not on the roster.', 'Rejected (student must exist on the roster).'),
    ('UAT-07', 'FR-06', 'Reject a check-in outside the event window', 'Check in a student 3 hours before the event starts.', 'Rejected with ''Check-in time is outside the event window''.'),
    ('UAT-08', 'FR-07', 'Waitlist when full', 'Fill an event to capacity with online registrations, then add one more.', 'Registrations up to capacity are Registered; the next one is Waitlisted.'),
    ('UAT-09', 'FR-08', 'Cancellation is not a no-show', 'Cancel an active registration that has no check-in.', 'Event no-show count falls by 1.'),
    ('UAT-10', 'FR-10', 'Flag a late follow-up', 'Record a follow-up as sent 2 days after its due date.', 'Follow-up report shows Sent late, 2 days past due.'),
    ('UAT-11', 'FR-10', 'Flag an overdue follow-up', 'Clear the sent date on a follow-up that is past due.', 'Follow-up report shows Overdue.'),
    ('UAT-12', 'FR-09', 'Attendance rate calculation', 'Create a test event with 4 registrations, check in 2 of them and 1 walk-in.', 'Report shows 4 registered, 2 attended, 1 walk-in, 50.0% attendance, 50.0% no-show.'),
    ('UAT-13', 'FR-12', 'Detect a duplicate in imported data', 'Add two legacy rows for one student and event, the second with the email in capitals.', 'Duplicate report lists a Confirmed group: ''Same email, different capitalization''.'),
    ('UAT-14', 'FR-13', 'No silent drops in migration', 'Compare blank student IDs in the legacy registration sheet with the exceptions log and the data-quality report.', 'All three counts match.'),
    ('UAT-15', 'NFR-01', 'Door lookup speed', 'Look up 200 students (every ninth on the roster) for an event''s check-in screen, on an in-memory copy of the database.', 'Each lookup returns in under 2 seconds.'),
    ('UAT-16', 'FR-01', 'Reject a registration for an unknown student', 'Register student ID S999999, which is not on the roster.', 'Rejected (student must exist on the roster).'),
    ('UAT-17', 'FR-06', 'Block editing a check-in time outside the window', 'Change an existing check-in time to two days after the event started.', 'Rejected with ''Check-in time is outside the event window''.'),
    ('UAT-18', 'FR-08', 'Cancelled registration cannot be checked in against', 'Check in a student against their cancelled registration, then as a walk-in.', 'Link to the cancelled registration is rejected; the walk-in check-in is accepted.');

-- What actually happened, filled in test by test.
CREATE TABLE uat_actual (test_id TEXT PRIMARY KEY, actual_result TEXT, passed INTEGER);

-- Scratch values for the test that is running (cleared at the start of each test).
CREATE TABLE v (k TEXT PRIMARY KEY, val);

-- Load a first copy so the report views below can be created.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db

-- The reports the tests check, saved as temporary views by their own .sql files.
.output off
.read sql/01_attendance_rate_by_event.sql
.read sql/03_duplicate_registrations.sql
.read sql/04_employer_follow_up_status.sql
.read sql/05_data_quality_exceptions.sql
.output stdout
DETACH t;

-- The last error the database raised, read from the log file. A log line looks like
-- "(2067) abort at 12: UNIQUE constraint failed: checkins.event_id, checkins.student_id; [INSERT ...]".
-- Only "abort" lines count (SQLite also logs harmless notes). Line breaks and runs of spaces in
-- the message are squeezed to single spaces. NULL means no error was raised.
CREATE TEMP VIEW last_error AS
WITH f AS (SELECT CAST(readfile('data/uat_error.log') AS TEXT) AS s),
     a AS (SELECT CASE WHEN instr(s, 'abort at') > 0 THEN substr(s, instr(s, 'abort at')) END AS s FROM f),
     m AS (SELECT substr(s, instr(s, ': ') + 2, instr(s, '; [') - instr(s, ': ') - 2) AS s FROM a WHERE s IS NOT NULL)
SELECT trim(replace(replace(replace(replace(replace(replace(
           replace(replace(s, char(10), ' '), char(13), ' '),
           '  ', ' '), '  ', ' '), '  ', ' '), '  ', ' '), '  ', ' '), '  ', ' ')) AS msg
FROM m;

-- UAT-01 (FR-03): check in a registered student ------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'before', attended FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO v SELECT 'sid', student_id FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E010')
  AND student_id NOT IN (SELECT student_id FROM checkins WHERE event_id = 'E010')
ORDER BY student_id LIMIT 1;
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
SELECT 'E010', student_id, school_email, '2025-09-25 10:00', 'Online form', 'Registered'
FROM students WHERE student_id = (SELECT val FROM v WHERE k = 'sid');
INSERT INTO v SELECT 'rid', registration_id FROM registrations
WHERE event_id = 'E010' AND student_id = (SELECT val FROM v WHERE k = 'sid');
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E010', (SELECT val FROM v WHERE k = 'sid'), (SELECT val FROM v WHERE k = 'rid'),
       datetime(starts_at, '+2 minutes'), 'QR scan'
FROM events WHERE event_id = 'E010';
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE event_id = 'E010' AND student_id = (SELECT val FROM v WHERE k = 'sid'))
        THEN 'Accepted'
    ELSE 'Rejected: no check-in was saved' END;
INSERT INTO v SELECT 'after', attended FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO uat_actual
SELECT 'UAT-01',
       res.val || '; linked to registration ' || rid.val || '; event attended count ' || b.val || ' -> ' || a.val,
       res.val = 'Accepted' AND a.val = b.val + 1
FROM v res, v rid, v b, v a
WHERE res.k = 'res' AND rid.k = 'rid' AND b.k = 'before' AND a.k = 'after';
DETACH t;

-- UAT-02 (FR-04): check in a walk-in ------------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'before', walk_ins FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO v SELECT 'sid', student_id FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E010')
  AND student_id NOT IN (SELECT student_id FROM checkins WHERE event_id = 'E010')
ORDER BY student_id LIMIT 1;
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E010', (SELECT val FROM v WHERE k = 'sid'), NULL, datetime(starts_at, '+5 minutes'), 'Manual lookup'
FROM events WHERE event_id = 'E010';
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE event_id = 'E010' AND student_id = (SELECT val FROM v WHERE k = 'sid'))
        THEN 'Accepted'
    ELSE 'Rejected: no check-in was saved' END;
INSERT INTO v SELECT 'after', walk_ins FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO uat_actual
SELECT 'UAT-02', res.val || '; walk-ins ' || b.val || ' -> ' || a.val,
       res.val = 'Accepted' AND a.val = b.val + 1
FROM v res, v b, v a WHERE res.k = 'res' AND b.k = 'before' AND a.k = 'after';
DETACH t;

-- UAT-03 (FR-05): block a second check-in -------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'ev', event_id FROM checkins WHERE registration_id IS NOT NULL ORDER BY checkin_id LIMIT 1;
INSERT INTO v SELECT 'sid', student_id FROM checkins WHERE registration_id IS NOT NULL ORDER BY checkin_id LIMIT 1;
INSERT INTO v SELECT 'rid', registration_id FROM checkins WHERE registration_id IS NOT NULL ORDER BY checkin_id LIMIT 1;
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT event_id, (SELECT val FROM v WHERE k = 'sid'), (SELECT val FROM v WHERE k = 'rid'),
       datetime(starts_at, '+15 minutes'), 'QR scan'
FROM events WHERE event_id = (SELECT val FROM v WHERE k = 'ev');
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN (SELECT COUNT(*) FROM checkins WHERE event_id = (SELECT val FROM v WHERE k = 'ev')
          AND student_id = (SELECT val FROM v WHERE k = 'sid')) > 1 THEN 'Accepted'
    ELSE 'Rejected: no second check-in was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-03', val, val LIKE 'Rejected%' AND instr(val, 'UNIQUE') > 0 FROM v WHERE k = 'res';
DETACH t;

-- UAT-04 (FR-02): block a duplicate registration ------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'rid', MIN(registration_id) FROM registrations;
.log data/uat_error.log
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
SELECT event_id, student_id, contact_email, '2025-09-01 09:00', 'Online form', 'Registered'
FROM registrations WHERE registration_id = (SELECT val FROM v WHERE k = 'rid');
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN (SELECT COUNT(*) FROM registrations r JOIN registrations f
          ON f.event_id = r.event_id AND f.student_id = r.student_id
          WHERE f.registration_id = (SELECT val FROM v WHERE k = 'rid')) > 1 THEN 'Accepted'
    ELSE 'Rejected: no second registration was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-04', val, val LIKE 'Rejected%' AND instr(val, 'UNIQUE') > 0 FROM v WHERE k = 'res';
DETACH t;

-- UAT-05 (FR-01): reject a malformed email ------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'sid', student_id FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E010')
  AND student_id NOT IN (SELECT student_id FROM checkins WHERE event_id = 'E010')
ORDER BY student_id LIMIT 1;
.log data/uat_error.log
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
VALUES ('E010', (SELECT val FROM v WHERE k = 'sid'), 'student.university.example', '2025-09-25 10:00',
        'Online form', 'Registered');
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM registrations WHERE event_id = 'E010' AND student_id = (SELECT val FROM v WHERE k = 'sid'))
        THEN 'Accepted'
    ELSE 'Rejected: no registration was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-05', val, val LIKE 'Rejected%' AND instr(val, 'CHECK') > 0 FROM v WHERE k = 'res';
DETACH t;

-- UAT-06 (FR-11): reject an unknown student at check-in -----------------------------------
-- A foreign key failure is not written to the log, so this test records what it can see:
-- whether a row was saved, and whether S999999 is on the roster.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E010', 'S999999', NULL, datetime(starts_at, '+1 minutes'), 'ID card'
FROM events WHERE event_id = 'E010';
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE student_id = 'S999999') THEN 'Accepted'
    WHEN NOT EXISTS (SELECT 1 FROM students WHERE student_id = 'S999999')
        THEN 'Rejected: no check-in was saved, and S999999 is not on the roster'
    ELSE 'Rejected: no check-in was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-06', val, val LIKE 'Rejected%'
       AND NOT EXISTS (SELECT 1 FROM students WHERE student_id = 'S999999')
FROM v WHERE k = 'res';
DETACH t;

-- UAT-07 (FR-06): reject a check-in outside the event window ------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'sid', student_id FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E010')
  AND student_id NOT IN (SELECT student_id FROM checkins WHERE event_id = 'E010')
ORDER BY student_id LIMIT 1;
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E010', (SELECT val FROM v WHERE k = 'sid'), NULL, datetime(starts_at, '-3 hours'), 'Manual lookup'
FROM events WHERE event_id = 'E010';
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE event_id = 'E010' AND student_id = (SELECT val FROM v WHERE k = 'sid'))
        THEN 'Accepted'
    ELSE 'Rejected: no check-in was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-07', val, val LIKE 'Rejected%' AND instr(val, 'outside the event window') > 0 FROM v WHERE k = 'res';
DETACH t;

-- UAT-08 (FR-07): waitlist when full -------------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'cap', capacity FROM events WHERE event_id = 'E003';
INSERT INTO v SELECT 'registered', COUNT(*) FROM registrations WHERE event_id = 'E003' AND status = 'Registered';
-- Enough new students to fill the room, plus one more.
CREATE TABLE added AS
SELECT student_id, school_email FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E003')
ORDER BY student_id
LIMIT (SELECT val FROM v WHERE k = 'cap') - (SELECT val FROM v WHERE k = 'registered') + 1;
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
SELECT 'E003', student_id, school_email, '2025-09-10 09:00', 'Online form', 'Registered'
FROM added ORDER BY student_id;
CREATE TABLE added_status AS
SELECT a.student_id, r.status, a.student_id = (SELECT MAX(student_id) FROM added) AS is_last
FROM added a JOIN registrations r ON r.event_id = 'E003' AND r.student_id = a.student_id;
INSERT INTO uat_actual
SELECT 'UAT-08',
       'Capacity ' || (SELECT val FROM v WHERE k = 'cap') || ', ' || (SELECT val FROM v WHERE k = 'registered')
       || ' already registered; added ' || (SELECT COUNT(*) FROM added_status)
       || ': last one is ' || (SELECT status FROM added_status WHERE is_last)
       || ', others [''' || (SELECT group_concat(status, ''', ''')
                             FROM (SELECT DISTINCT status FROM added_status WHERE NOT is_last ORDER BY status)) || ''']',
       (SELECT status FROM added_status WHERE is_last) = 'Waitlisted'
       AND (SELECT COUNT(DISTINCT status) FROM added_status WHERE NOT is_last) = 1
       AND (SELECT MIN(status) FROM added_status WHERE NOT is_last) = 'Registered';
DROP TABLE added;
DROP TABLE added_status;
DETACH t;

-- UAT-09 (FR-08): a cancellation is not a no-show ------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'reg_before', registered FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO v SELECT 'ns_before', registered - attended FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO v SELECT 'rid', r.registration_id FROM registrations r
LEFT JOIN checkins ch ON ch.registration_id = r.registration_id
WHERE r.event_id = 'E010' AND r.status = 'Registered' AND ch.checkin_id IS NULL
ORDER BY r.registration_id LIMIT 1;
UPDATE registrations SET status = 'Cancelled' WHERE registration_id = (SELECT val FROM v WHERE k = 'rid');
INSERT INTO v SELECT 'reg_after', registered FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO v SELECT 'ns_after', registered - attended FROM attendance_rate_by_event WHERE event_id = 'E010';
INSERT INTO uat_actual
SELECT 'UAT-09',
       'No-shows ' || nb.val || ' -> ' || na.val || '; registered ' || rb.val || ' -> ' || ra.val,
       na.val = nb.val - 1
FROM v nb, v na, v rb, v ra
WHERE nb.k = 'ns_before' AND na.k = 'ns_after' AND rb.k = 'reg_before' AND ra.k = 'reg_after';
DETACH t;

-- UAT-10 (FR-10): flag a late follow-up ----------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'ev', event_id FROM follow_ups ORDER BY event_id, employer_id LIMIT 1;
INSERT INTO v SELECT 'emp', employer_id FROM follow_ups ORDER BY event_id, employer_id LIMIT 1;
UPDATE follow_ups SET sent_date = date(due_date, '+2 days')
WHERE event_id = (SELECT val FROM v WHERE k = 'ev') AND employer_id = (SELECT val FROM v WHERE k = 'emp');
INSERT INTO uat_actual
SELECT 'UAT-10', 'Status ' || status || ', ' || days_past_due || ' days past due',
       status = 'Sent late' AND days_past_due = 2
FROM employer_follow_up_status
WHERE event_id = (SELECT val FROM v WHERE k = 'ev') AND employer_id = (SELECT val FROM v WHERE k = 'emp');
DETACH t;

-- UAT-11 (FR-10): flag an overdue follow-up ------------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'ev', event_id FROM follow_ups WHERE sent_date IS NOT NULL ORDER BY event_id, employer_id LIMIT 1;
INSERT INTO v SELECT 'emp', employer_id FROM follow_ups WHERE sent_date IS NOT NULL ORDER BY event_id, employer_id LIMIT 1;
UPDATE follow_ups SET sent_date = NULL
WHERE event_id = (SELECT val FROM v WHERE k = 'ev') AND employer_id = (SELECT val FROM v WHERE k = 'emp');
INSERT INTO uat_actual
SELECT 'UAT-11', 'Status ' || status || ', ' || days_past_due || ' days past due', status = 'Overdue'
FROM employer_follow_up_status
WHERE event_id = (SELECT val FROM v WHERE k = 'ev') AND employer_id = (SELECT val FROM v WHERE k = 'emp');
DETACH t;

-- UAT-12 (FR-09): attendance rate calculation ----------------------------------------------
-- A test event with 4 registrations, 2 of them checked in, and 1 walk-in.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO events VALUES ('E900', 'UAT test session', 'Workshop', '2025-11-03 12:00', '2025-11-03 13:00',
                           'Career Office Studio', 10);
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
SELECT 'E900', student_id, school_email, '2025-10-30 09:00', 'Online form', 'Registered'
FROM students ORDER BY student_id LIMIT 4;
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E900', r.student_id, r.registration_id, '2025-11-03 11:58', 'QR scan'
FROM registrations r
WHERE r.event_id = 'E900' AND r.student_id IN (SELECT student_id FROM students ORDER BY student_id LIMIT 2)
ORDER BY r.student_id;
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT 'E900', student_id, NULL, '2025-11-03 12:04', 'Manual lookup'
FROM students ORDER BY student_id LIMIT 1 OFFSET 4;
INSERT INTO uat_actual
SELECT 'UAT-12',
       'Registered ' || registered || ', attended ' || attended || ', walk-ins ' || walk_ins
       || ', attendance rate ' || attendance_rate_pct || '%, no-show rate ' || no_show_rate_pct || '%',
       registered = 4 AND attended = 2 AND walk_ins = 1 AND attendance_rate_pct = 50.0 AND no_show_rate_pct = 50.0
FROM attendance_rate_by_event WHERE event_id = 'E900';
DETACH t;

-- UAT-13 (FR-12): detect a duplicate in imported data ---------------------------------------
-- Two legacy rows for one student and event, the second with the email in capitals.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'sid', student_id FROM students
WHERE student_id NOT IN (SELECT student_id FROM registrations WHERE event_id = 'E001')
ORDER BY student_id LIMIT 1;
INSERT INTO legacy_registrations (event_code, student_id, full_name, email, registered_on, status)
SELECT 'E001', student_id, first_name || ' ' || last_name, school_email, '2025-09-05 10:00', 'Registered'
FROM students WHERE student_id = (SELECT val FROM v WHERE k = 'sid');
INSERT INTO legacy_registrations (event_code, student_id, full_name, email, registered_on, status)
SELECT 'E001', student_id, first_name || ' ' || last_name, UPPER(school_email), '2025-09-05 15:00', 'Registered'
FROM students WHERE student_id = (SELECT val FROM v WHERE k = 'sid');
CREATE TABLE found AS
SELECT duplicate_type, legacy_rows, pattern FROM duplicate_registrations
WHERE event_id = 'E001' AND student_id = (SELECT val FROM v WHERE k = 'sid')
ORDER BY duplicate_type, full_name LIMIT 1;
INSERT INTO uat_actual
SELECT 'UAT-13',
       COALESCE((SELECT duplicate_type || ', ' || legacy_rows || ' rows, ' || pattern FROM found), 'Not listed'),
       COALESCE((SELECT pattern = 'Same email, different capitalization' FROM found), 0);
DROP TABLE found;
DETACH t;

-- UAT-14 (FR-13): no silent drops in the migration -------------------------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'blank', COUNT(*) FROM legacy_registrations WHERE NULLIF(TRIM(student_id), '') IS NULL;
INSERT INTO v SELECT 'logged', COUNT(*) FROM load_exceptions
WHERE source_table = 'legacy_registrations' AND issue = 'Missing student ID';
INSERT INTO v SELECT 'in_report', COALESCE(SUM(affected_rows), 0) FROM data_quality_exceptions
WHERE source_table = 'legacy_registrations' AND issue = 'Missing student ID';
INSERT INTO uat_actual
SELECT 'UAT-14',
       'Blank IDs in sheet ' || b.val || '; logged ' || l.val || '; in report ' || r.val,
       b.val = l.val AND l.val = r.val
FROM v b, v l, v r WHERE b.k = 'blank' AND l.k = 'logged' AND r.k = 'in_report';
DETACH t;

-- UAT-15 (NFR-01): door lookup speed ---------------------------------------------------------
-- Every ninth student on the roster (200 students), looked up the way the check-in screen
-- would. julianday('now') is read before and after; the difference is in days.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
CREATE TABLE sample AS SELECT student_id FROM students WHERE rowid % 9 = 0 LIMIT 200;
INSERT INTO v VALUES ('n', (SELECT COUNT(*) FROM sample));
INSERT INTO v VALUES ('t0', julianday('now'));
CREATE TABLE lookups AS
SELECT s.student_id, s.first_name, s.last_name, r.registration_id, r.status
FROM sample x
JOIN students s ON s.student_id = x.student_id
LEFT JOIN registrations r ON r.student_id = s.student_id AND r.event_id = 'E010';
INSERT INTO v VALUES ('t1', julianday('now'));
INSERT INTO uat_actual
SELECT 'UAT-15',
       -- SQLite's clock counts whole milliseconds, so a very fast run can read as zero.
       CASE WHEN (t1.val - t0.val) * 86400000.0 < 1
            THEN n.val || ' lookups took less than 1 ms in total (the clock counts whole milliseconds)'
            ELSE 'Average lookup ' || printf('%.3f', (t1.val - t0.val) * 86400000.0 / n.val) || ' ms over '
                 || n.val || ' lookups' END,
       (t1.val - t0.val) * 86400000.0 / n.val < 2000
FROM v n, v t0, v t1 WHERE n.k = 'n' AND t0.k = 't0' AND t1.k = 't1';
DROP TABLE sample;
DROP TABLE lookups;
DETACH t;

-- UAT-16 (FR-01): reject a registration for an unknown student -------------------------------
-- As in UAT-06, a foreign key failure is not logged, so the result records what is visible.
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
.log data/uat_error.log
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
VALUES ('E010', 'S999999', 'someone@university.example', '2025-09-25 10:00', 'Online form', 'Registered');
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM registrations WHERE student_id = 'S999999') THEN 'Accepted'
    WHEN NOT EXISTS (SELECT 1 FROM students WHERE student_id = 'S999999')
        THEN 'Rejected: no registration was saved, and S999999 is not on the roster'
    ELSE 'Rejected: no registration was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-16', val, val LIKE 'Rejected%'
       AND NOT EXISTS (SELECT 1 FROM students WHERE student_id = 'S999999')
FROM v WHERE k = 'res';
DETACH t;

-- UAT-17 (FR-06): block editing a check-in time outside the window ---------------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'cid', MIN(checkin_id) FROM checkins;
INSERT INTO v SELECT 'new_time', datetime(e.starts_at, '+2 days')
FROM checkins c JOIN events e ON e.event_id = c.event_id WHERE c.checkin_id = (SELECT val FROM v WHERE k = 'cid');
.log data/uat_error.log
UPDATE checkins SET checked_in_at = (SELECT val FROM v WHERE k = 'new_time')
WHERE checkin_id = (SELECT val FROM v WHERE k = 'cid');
.log off
INSERT INTO v SELECT 'res', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN (SELECT checked_in_at FROM checkins WHERE checkin_id = (SELECT val FROM v WHERE k = 'cid'))
         = (SELECT val FROM v WHERE k = 'new_time') THEN 'Accepted'
    ELSE 'Rejected: the time was not changed' END;
INSERT INTO uat_actual
SELECT 'UAT-17', val, val LIKE 'Rejected%' AND instr(val, 'outside the event window') > 0 FROM v WHERE k = 'res';
DETACH t;

-- UAT-18 (FR-08): a cancelled registration cannot be checked in against ----------------------
ATTACH ':memory:' AS t;
.restore t data/checkin_synthetic.db
DELETE FROM v;
INSERT INTO v SELECT 'rid', MIN(r.registration_id) FROM registrations r
WHERE r.status = 'Cancelled'
  AND NOT EXISTS (SELECT 1 FROM checkins ch WHERE ch.event_id = r.event_id AND ch.student_id = r.student_id);
INSERT INTO v SELECT 'ev', event_id FROM registrations WHERE registration_id = (SELECT val FROM v WHERE k = 'rid');
INSERT INTO v SELECT 'sid', student_id FROM registrations WHERE registration_id = (SELECT val FROM v WHERE k = 'rid');
-- First try: link the check-in to the cancelled registration.
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT event_id, (SELECT val FROM v WHERE k = 'sid'), (SELECT val FROM v WHERE k = 'rid'),
       datetime(starts_at, '+3 minutes'), 'QR scan'
FROM events WHERE event_id = (SELECT val FROM v WHERE k = 'ev');
.log off
INSERT INTO v SELECT 'linked', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE registration_id = (SELECT val FROM v WHERE k = 'rid')) THEN 'Accepted'
    ELSE 'Rejected: no check-in was saved' END;
-- Second try: check the same student in as a walk-in.
.log data/uat_error.log
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT event_id, (SELECT val FROM v WHERE k = 'sid'), NULL, datetime(starts_at, '+3 minutes'), 'Manual lookup'
FROM events WHERE event_id = (SELECT val FROM v WHERE k = 'ev');
.log off
INSERT INTO v SELECT 'walk_in', CASE
    WHEN (SELECT msg FROM last_error) IS NOT NULL THEN 'Rejected: ' || (SELECT msg FROM last_error)
    WHEN EXISTS (SELECT 1 FROM checkins WHERE event_id = (SELECT val FROM v WHERE k = 'ev')
                 AND student_id = (SELECT val FROM v WHERE k = 'sid') AND registration_id IS NULL) THEN 'Accepted'
    ELSE 'Rejected: no check-in was saved' END;
INSERT INTO uat_actual
SELECT 'UAT-18', 'Linked to cancelled registration: ' || l.val || '. As walk-in: ' || w.val,
       l.val LIKE 'Rejected%' AND w.val = 'Accepted'
FROM v l, v w WHERE l.k = 'linked' AND w.k = 'walk_in';
DETACH t;

-- Clear the error log so it does not hold the last test's message.
.log data/uat_error.log
.log off

-- Save the results ---------------------------------------------------------------------------
.headers on
.mode csv
.output deliverables/uat_test_cases.csv
SELECT c.test_id, c.requirement, c.test, c.steps, c.expected_result, a.actual_result,
       CASE WHEN a.passed THEN 'Pass' ELSE 'Fail' END AS status
FROM uat_cases c
LEFT JOIN uat_actual a ON a.test_id = c.test_id
ORDER BY c.test_id;
.output stdout

.headers off
.mode list
SELECT (SELECT COUNT(*) FROM uat_actual WHERE passed) || ' of ' || (SELECT COUNT(*) FROM uat_cases)
       || ' tests passed. Results saved to deliverables/uat_test_cases.csv.';
