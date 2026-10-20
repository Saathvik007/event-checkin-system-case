-- 03. Duplicate registrations in the legacy registration sheet.
-- Confirmed means two or more rows for the same student and event. Likely means a row with
-- no matched student that has the same name as a matched registration for that event
-- (usually a second sign-up with a personal email). Names are not unique (see
-- 00_headline_metrics.csv), so a likely pair can be two people and staff check it first.
-- Students are matched the same way as in the migration: school email first, then student ID.
-- stage has one row per legacy row (3,258). The name join in likely can match one row to
-- several, so it is grouped back to one row per duplicate group.

-- Temp view, so uat_tests.sql can use the same logic.
DROP VIEW IF EXISTS temp.duplicate_registrations;
CREATE TEMP VIEW duplicate_registrations AS
WITH stage AS (
    SELECT
        r.row_id,
        r.event_code AS event_id,
        TRIM(r.email) AS email_raw,
        LOWER(TRIM(r.email)) AS email,
        TRIM(r.full_name) AS full_name,
        LOWER(TRIM(r.full_name)) AS name_key,
        r.registered_on,
        COALESCE(
            (SELECT s.student_id FROM students s WHERE s.school_email = LOWER(TRIM(r.email))),
            (SELECT s.student_id FROM students s WHERE s.student_id = NULLIF(UPPER(TRIM(r.student_id)), ''))
        ) AS student_id
    FROM legacy_registrations r
),
confirmed AS (
    SELECT
        'Confirmed' AS duplicate_type,
        event_id,
        student_id,
        MIN(full_name) AS full_name,
        COUNT(*) AS legacy_rows,
        CASE
            WHEN COUNT(DISTINCT email_raw) = 1 THEN 'Same details submitted twice'
            WHEN COUNT(DISTINCT email) = 1 THEN 'Same email, different capitalization'
            ELSE 'Different email addresses'
        END AS pattern,
        MIN(registered_on) AS first_registered_on,
        MAX(registered_on) AS last_registered_on
    FROM stage
    WHERE student_id IS NOT NULL
    GROUP BY event_id, student_id
    HAVING COUNT(*) > 1
),
likely AS (
    SELECT
        'Likely' AS duplicate_type,
        u.event_id,
        MIN(i.student_id) AS student_id,
        MIN(u.full_name) AS full_name,
        COUNT(DISTINCT u.row_id) + 1 AS legacy_rows,
        'Same name, second row not identified' AS pattern,
        MIN(MIN(u.registered_on), MIN(i.registered_on)) AS first_registered_on,
        MAX(MAX(u.registered_on), MAX(i.registered_on)) AS last_registered_on
    FROM stage u
    JOIN stage i ON i.event_id = u.event_id AND i.name_key = u.name_key AND i.student_id IS NOT NULL
    WHERE u.student_id IS NULL
    GROUP BY u.event_id, u.name_key
)
SELECT c.duplicate_type, c.event_id, e.event_name, c.student_id, c.full_name, c.legacy_rows, c.pattern,
       c.first_registered_on, c.last_registered_on
FROM (SELECT * FROM confirmed UNION ALL SELECT * FROM likely) c
JOIN events e ON e.event_id = c.event_id
ORDER BY c.duplicate_type, c.event_id, c.full_name;

SELECT * FROM duplicate_registrations;
