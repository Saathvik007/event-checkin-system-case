-- Load the three legacy spreadsheets into the core tables.
-- Rules: match each row to a student by school email first (it is unique and usually
-- copied from the roster), then by student ID; merge duplicates; standardize values; and
-- log every change or rejected row in load_exceptions. If a row can't be matched to a
-- student on the roster, it is held for staff to review instead of being loaded.
PRAGMA foreign_keys = ON;

INSERT INTO report_settings (as_of_date) VALUES ('2025-12-12');

-- Registrations ---------------------------------------------------------------------------

CREATE TEMP TABLE reg_stage AS
SELECT
    r.row_id,
    r.event_code                               AS event_id,
    NULLIF(UPPER(TRIM(r.student_id)), '')      AS raw_student_id,
    LOWER(TRIM(r.email))                       AS email,
    r.registered_on                            AS registered_at,
    TRIM(COALESCE(r.status, ''))               AS raw_status,
    -- Anything that is not a form of "cancel" (including blank and "Yes") counts as active;
    -- non-standard values are logged below.
    CASE WHEN LOWER(TRIM(r.status)) LIKE 'cancel%' THEN 'Cancelled' ELSE 'Registered' END AS status,
    CASE WHEN TRIM(r.email) LIKE '%_@_%._%' AND TRIM(r.email) NOT LIKE '% %'
              AND r.email NOT LIKE '%@%@%' THEN 1 ELSE 0 END AS email_valid,
    CAST(NULL AS TEXT)                         AS student_id,
    CAST(NULL AS TEXT)                         AS match_method
FROM legacy_registrations r;

UPDATE reg_stage
SET student_id = (SELECT s.student_id FROM students s WHERE s.school_email = reg_stage.email),
    match_method = 'School email'
WHERE email IN (SELECT school_email FROM students);

UPDATE reg_stage
SET student_id = raw_student_id, match_method = 'Student ID'
WHERE student_id IS NULL AND raw_student_id IN (SELECT student_id FROM students);

INSERT INTO load_exceptions (source_table, source_row_id, record_key, issue, action_taken)
SELECT 'legacy_registrations', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Missing student ID',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Matched by school email' END
FROM reg_stage WHERE raw_student_id IS NULL
UNION ALL
SELECT 'legacy_registrations', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Student ID not in roster',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Matched by school email' END
FROM reg_stage WHERE raw_student_id IS NOT NULL AND raw_student_id NOT IN (SELECT student_id FROM students)
UNION ALL
SELECT 'legacy_registrations', row_id, event_id || ' / ' || student_id,
       'Student ID belongs to a different student than the email',
       'Used the student matched by school email'
FROM reg_stage WHERE match_method = 'School email' AND raw_student_id IN (SELECT student_id FROM students)
                 AND raw_student_id <> student_id
UNION ALL
SELECT 'legacy_registrations', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Invalid email format',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Replaced with school email from roster' END
FROM reg_stage WHERE email_valid = 0
UNION ALL
SELECT 'legacy_registrations', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'School email not in roster',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Replaced with school email from roster' END
FROM reg_stage WHERE email_valid = 1 AND email LIKE '%@university.%'
                 AND email NOT IN (SELECT school_email FROM students)
UNION ALL
SELECT 'legacy_registrations', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Non-standard status value',
       'Standardized to ' || status
FROM reg_stage WHERE raw_status NOT IN ('Registered', 'Cancelled')
UNION ALL
SELECT 'legacy_registrations', rs.row_id, rs.event_id || ' / ' || COALESCE(rs.student_id, rs.email),
       'Registered after event start',
       'Loaded and flagged'
FROM reg_stage rs JOIN events e ON e.event_id = rs.event_id
WHERE datetime(rs.registered_at) > datetime(e.starts_at)
UNION ALL
-- Every row after the earliest one for the same event and student.
SELECT 'legacy_registrations', row_id, event_id || ' / ' || student_id,
       'Duplicate registration',
       'Merged into one registration'
FROM (SELECT row_id, event_id, student_id,
             ROW_NUMBER() OVER (PARTITION BY event_id, student_id ORDER BY registered_at, row_id) AS n
      FROM reg_stage WHERE student_id IS NOT NULL)
WHERE n > 1;

-- One registration per event and student. Active beats cancelled; earliest time wins.
-- Legacy imports carry the roster email, since many legacy emails are personal or mistyped.
INSERT INTO registrations (event_id, student_id, contact_email, registered_at, channel, status)
SELECT rs.event_id, rs.student_id, s.school_email, MIN(rs.registered_at), 'Legacy import',
       CASE WHEN SUM(rs.status = 'Registered') > 0 THEN 'Registered' ELSE 'Cancelled' END
FROM reg_stage rs
JOIN students s ON s.student_id = rs.student_id
GROUP BY rs.event_id, rs.student_id;

-- Sign-ins ----------------------------------------------------------------------------------

CREATE TEMP TABLE sign_stage AS
SELECT
    g.row_id,
    g.event_code                               AS event_id,
    NULLIF(UPPER(TRIM(g.student_id)), '')      AS raw_student_id,
    LOWER(TRIM(g.email))                       AS email,
    g.signed_in_at,
    CASE WHEN TRIM(g.email) LIKE '%_@_%._%' AND TRIM(g.email) NOT LIKE '% %'
              AND g.email NOT LIKE '%@%@%' THEN 1 ELSE 0 END AS email_valid,
    CASE WHEN datetime(g.signed_in_at) >= datetime(e.starts_at, '-60 minutes')
              AND datetime(g.signed_in_at) <= datetime(e.ends_at) THEN 1 ELSE 0 END AS in_window,
    CAST(NULL AS TEXT)                         AS student_id
FROM legacy_signins g
JOIN events e ON e.event_id = g.event_code;

UPDATE sign_stage
SET student_id = (SELECT s.student_id FROM students s WHERE s.school_email = sign_stage.email)
WHERE email IN (SELECT school_email FROM students);

UPDATE sign_stage
SET student_id = raw_student_id
WHERE student_id IS NULL AND raw_student_id IN (SELECT student_id FROM students);

INSERT INTO load_exceptions (source_table, source_row_id, record_key, issue, action_taken)
SELECT 'legacy_signins', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Missing student ID',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Matched by school email' END
FROM sign_stage WHERE raw_student_id IS NULL
UNION ALL
SELECT 'legacy_signins', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Invalid email format',
       CASE WHEN student_id IS NULL THEN 'Held for review: student not identified'
            ELSE 'Matched by student ID' END
FROM sign_stage WHERE email_valid = 0
UNION ALL
SELECT 'legacy_signins', row_id, event_id || ' / ' || COALESCE(student_id, email),
       'Sign-in time outside event window',
       'Held for review: time needs confirming'
FROM sign_stage WHERE in_window = 0
UNION ALL
SELECT 'legacy_signins', row_id, event_id || ' / ' || student_id,
       'Duplicate sign-in',
       'Merged into one check-in'
FROM (SELECT row_id, event_id, student_id,
             ROW_NUMBER() OVER (PARTITION BY event_id, student_id ORDER BY signed_in_at, row_id) AS n
      FROM sign_stage WHERE student_id IS NOT NULL AND in_window = 1)
WHERE n > 1;

-- One check-in per event and student, linked to an active registration when there is one.
-- No active registration means a walk-in (registration_id stays NULL).
INSERT INTO checkins (event_id, student_id, registration_id, checked_in_at, method)
SELECT ss.event_id, ss.student_id,
       (SELECT r.registration_id FROM registrations r
        WHERE r.event_id = ss.event_id AND r.student_id = ss.student_id AND r.status = 'Registered'),
       MIN(ss.signed_in_at), 'Legacy import'
FROM sign_stage ss
WHERE ss.student_id IS NOT NULL AND ss.in_window = 1
GROUP BY ss.event_id, ss.student_id;

-- Employer follow-ups ---------------------------------------------------------------------

-- Employer names match ignoring case and spaces, or when the typed name is the employer's
-- name followed by extra words (for example "Employer 27 Recruiting"). The match must be an
-- employer that took part in that event. Anything else is held for a manual match.
CREATE TEMP TABLE fu_stage AS
SELECT f.row_id, f.event_code AS event_id, f.employer_name AS raw_name,
       (SELECT em.employer_id FROM employers em
        JOIN event_employers ee ON ee.employer_id = em.employer_id AND ee.event_id = f.event_code
        WHERE LOWER(TRIM(f.employer_name)) = LOWER(em.employer_name)
           OR LOWER(TRIM(f.employer_name)) LIKE LOWER(em.employer_name) || ' %') AS employer_id,
       NULLIF(TRIM(f.sent_on), '') AS sent_on
FROM legacy_followups f;

INSERT INTO load_exceptions (source_table, source_row_id, record_key, issue, action_taken)
SELECT 'legacy_followups', row_id, event_id || ' / ' || raw_name,
       'Employer name not matched', 'Held for review: match the employer by hand'
FROM fu_stage WHERE employer_id IS NULL
UNION ALL
SELECT 'legacy_followups', fs.row_id, fs.event_id || ' / ' || fs.employer_id,
       'Non-standard employer name', 'Standardized'
FROM fu_stage fs JOIN employers em ON em.employer_id = fs.employer_id
WHERE fs.raw_name <> em.employer_name
UNION ALL
SELECT 'event_employers', NULL, ee.event_id || ' / ' || ee.employer_id,
       'Follow-up missing from tracker', 'Created as not sent'
FROM event_employers ee
WHERE NOT EXISTS (SELECT 1 FROM fu_stage fs
                  WHERE fs.event_id = ee.event_id AND fs.employer_id = ee.employer_id);

-- Every event-employer pair gets a follow-up due 3 business days after the event
-- (strftime %w: 0 = Sunday ... 6 = Saturday).
INSERT INTO follow_ups (event_id, employer_id, due_date, sent_date)
SELECT ee.event_id, ee.employer_id,
       date(e.starts_at, CASE strftime('%w', e.starts_at)
                             WHEN '3' THEN '+5 days' WHEN '4' THEN '+5 days' WHEN '5' THEN '+5 days'
                             WHEN '6' THEN '+4 days' ELSE '+3 days' END),
       (SELECT MIN(date(fs.sent_on)) FROM fu_stage fs
        WHERE fs.event_id = ee.event_id AND fs.employer_id = ee.employer_id)
FROM event_employers ee
JOIN events e ON e.event_id = ee.event_id;
