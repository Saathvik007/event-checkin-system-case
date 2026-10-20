-- 00. Headline numbers for the term. The numbers in the README and the two documents in
-- deliverables/ come from here or from the numbered reports.

WITH settings AS (SELECT as_of_date FROM report_settings),
fu AS (
    SELECT CASE
               WHEN sent_date IS NOT NULL AND sent_date <= due_date THEN 'Sent on time'
               WHEN sent_date IS NOT NULL THEN 'Sent late'
               WHEN due_date < (SELECT as_of_date FROM settings) THEN 'Overdue'
               ELSE 'Not yet due'
           END AS status
    FROM follow_ups
),
attendance AS (
    SELECT e.event_id, e.capacity, COUNT(c.checkin_id) AS checkins
    FROM events e LEFT JOIN checkins c ON c.event_id = e.event_id
    GROUP BY e.event_id, e.capacity
)
SELECT 'Report as-of date' AS metric, (SELECT as_of_date FROM settings) AS value
UNION ALL SELECT 'Events', COUNT(*) FROM events
UNION ALL SELECT 'Students on roster', COUNT(*) FROM students
UNION ALL SELECT 'Legacy registration rows', COUNT(*) FROM legacy_registrations
UNION ALL SELECT 'Registrations loaded (one per student per event)', COUNT(*) FROM registrations
UNION ALL SELECT 'Active registrations', COUNT(*) FROM registrations WHERE status = 'Registered'
UNION ALL SELECT 'Cancelled registrations', COUNT(*) FROM registrations WHERE status = 'Cancelled'
UNION ALL SELECT 'Legacy registration rows with no student ID',
    COUNT(*) FROM legacy_registrations WHERE NULLIF(TRIM(student_id), '') IS NULL
UNION ALL SELECT 'Legacy registration rows with a non-standard status',
    COUNT(*) FROM legacy_registrations WHERE TRIM(COALESCE(status, '')) NOT IN ('Registered', 'Cancelled')
UNION ALL SELECT 'Legacy registration rows held for review',
    COUNT(DISTINCT source_row_id) FROM load_exceptions
    WHERE source_table = 'legacy_registrations' AND action_taken LIKE 'Held%'
UNION ALL SELECT 'Legacy sign-in rows', COUNT(*) FROM legacy_signins
UNION ALL SELECT 'Check-ins loaded', COUNT(*) FROM checkins
UNION ALL SELECT 'Walk-in check-ins (no registration)', COUNT(*) FROM checkins WHERE registration_id IS NULL
UNION ALL SELECT 'Legacy sign-in rows held for review',
    COUNT(DISTINCT source_row_id) FROM load_exceptions
    WHERE source_table = 'legacy_signins' AND action_taken LIKE 'Held%'
UNION ALL SELECT 'Legacy sign-in rows held: student not identified',
    COUNT(DISTINCT source_row_id) FROM load_exceptions
    WHERE source_table = 'legacy_signins' AND action_taken = 'Held for review: student not identified'
UNION ALL SELECT 'Legacy sign-in rows held: time outside event window only',
    COUNT(DISTINCT source_row_id) FROM load_exceptions
    WHERE source_table = 'legacy_signins' AND action_taken = 'Held for review: time needs confirming'
      AND source_row_id NOT IN (SELECT source_row_id FROM load_exceptions
                                WHERE source_table = 'legacy_signins'
                                  AND action_taken = 'Held for review: student not identified')
UNION ALL SELECT 'Walk-ins whose name matches a held registration row at the same event',
    COUNT(*) FROM checkins c
    JOIN students s ON s.student_id = c.student_id
    WHERE c.registration_id IS NULL
      AND EXISTS (SELECT 1 FROM legacy_registrations lr
                  JOIN load_exceptions x ON x.source_table = 'legacy_registrations'
                                        AND x.source_row_id = lr.row_id
                                        AND x.action_taken = 'Held for review: student not identified'
                  WHERE lr.event_code = c.event_id
                    AND LOWER(TRIM(lr.full_name)) = LOWER(s.first_name || ' ' || s.last_name))
UNION ALL SELECT 'Roster names shared by two or more students',
    COUNT(*) FROM (SELECT first_name, last_name FROM students
                   GROUP BY first_name, last_name HAVING COUNT(*) > 1)
UNION ALL SELECT 'Attendance rate of active registrations (%)',
    ROUND(100.0 * (SELECT COUNT(*) FROM checkins WHERE registration_id IS NOT NULL)
          / (SELECT COUNT(*) FROM registrations WHERE status = 'Registered'), 1)
UNION ALL SELECT 'No-show rate of active registrations (%)',
    ROUND(100.0 - 100.0 * (SELECT COUNT(*) FROM checkins WHERE registration_id IS NOT NULL)
          / (SELECT COUNT(*) FROM registrations WHERE status = 'Registered'), 1)
UNION ALL SELECT 'Legacy rows with at least one exception',
    COUNT(DISTINCT source_table || source_row_id) FROM load_exceptions WHERE source_row_id IS NOT NULL
UNION ALL SELECT 'Share of legacy rows with at least one exception (%)',
    ROUND(100.0 * (SELECT COUNT(DISTINCT source_table || source_row_id) FROM load_exceptions
                   WHERE source_row_id IS NOT NULL)
          / ((SELECT COUNT(*) FROM legacy_registrations) + (SELECT COUNT(*) FROM legacy_signins)
             + (SELECT COUNT(*) FROM legacy_followups)), 1)
UNION ALL SELECT 'Employer follow-ups', COUNT(*) FROM fu
UNION ALL SELECT 'Follow-ups sent on time', SUM(status = 'Sent on time') FROM fu
UNION ALL SELECT 'Follow-ups sent late', SUM(status = 'Sent late') FROM fu
UNION ALL SELECT 'Follow-ups overdue (not sent, past due)', SUM(status = 'Overdue') FROM fu
UNION ALL SELECT 'Follow-ups not yet due', SUM(status = 'Not yet due') FROM fu
UNION ALL SELECT 'Follow-ups sent on time (% of those due)',
    ROUND(100.0 * SUM(status = 'Sent on time') / SUM(status <> 'Not yet due'), 1) FROM fu
UNION ALL SELECT 'Events where check-ins exceeded capacity', SUM(checkins > capacity) FROM attendance;
