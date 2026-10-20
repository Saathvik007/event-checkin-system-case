-- Tableau extract: one row per event with attendance, follow-up and exception counts.
-- Rates in the dashboard are recomputed from the counts (for example
-- SUM(attended) / SUM(registered)), so filters by event type stay correct.
-- Grain: each CTE is rolled up to one row per event before the joins (40 rows).

WITH settings AS (SELECT as_of_date FROM report_settings),
reg AS (
    SELECT event_id, SUM(status = 'Registered') AS registered, SUM(status = 'Cancelled') AS cancelled
    FROM registrations GROUP BY event_id
),
ci AS (
    SELECT event_id, SUM(registration_id IS NOT NULL) AS attended, SUM(registration_id IS NULL) AS walk_ins
    FROM checkins GROUP BY event_id
),
fu AS (
    SELECT event_id,
           COUNT(*) AS follow_ups,
           SUM(sent_date IS NOT NULL AND sent_date <= due_date) AS follow_ups_on_time,
           SUM(sent_date IS NOT NULL AND sent_date > due_date) AS follow_ups_late,
           SUM(sent_date IS NULL AND due_date < (SELECT as_of_date FROM settings)) AS follow_ups_overdue
    FROM follow_ups GROUP BY event_id
),
ex AS (
    -- record_key is "<event_id> / <student or email>". A legacy row can carry several
    -- issues, so rows are counted once with COUNT(DISTINCT ...).
    SELECT substr(record_key, 1, instr(record_key, ' / ') - 1) AS event_id,
           COUNT(DISTINCT CASE WHEN source_table = 'legacy_registrations' THEN source_row_id END)
               AS registration_rows_with_issues,
           COUNT(DISTINCT CASE WHEN source_table = 'legacy_signins' THEN source_row_id END)
               AS signin_rows_with_issues,
           COUNT(DISTINCT CASE WHEN action_taken LIKE 'Held%' THEN source_table || source_row_id END)
               AS rows_held_for_review
    FROM load_exceptions
    WHERE source_table IN ('legacy_registrations', 'legacy_signins')
    GROUP BY 1
),
term AS (
    -- Monday on or before the first event, so week 1 is the first week of the term.
    SELECT date(MIN(starts_at), '-6 days', 'weekday 1') AS first_monday FROM events
)
SELECT
    e.event_id,
    e.event_name,
    e.event_type,
    date(e.starts_at) AS event_date,
    CAST((julianday(date(e.starts_at)) - julianday((SELECT first_monday FROM term))) / 7 AS INTEGER) + 1 AS term_week,
    e.capacity,
    COALESCE(reg.registered, 0) AS registered,
    COALESCE(reg.cancelled, 0) AS cancelled,
    COALESCE(ci.attended, 0) AS attended,
    COALESCE(reg.registered, 0) - COALESCE(ci.attended, 0) AS no_shows,
    COALESCE(ci.walk_ins, 0) AS walk_ins,
    COALESCE(fu.follow_ups, 0) AS follow_ups,
    COALESCE(fu.follow_ups_on_time, 0) AS follow_ups_on_time,
    COALESCE(fu.follow_ups_late, 0) AS follow_ups_late,
    COALESCE(fu.follow_ups_overdue, 0) AS follow_ups_overdue,
    COALESCE(ex.registration_rows_with_issues, 0) AS registration_rows_with_issues,
    COALESCE(ex.signin_rows_with_issues, 0) AS signin_rows_with_issues,
    COALESCE(ex.rows_held_for_review, 0) AS rows_held_for_review
FROM events e
LEFT JOIN reg ON reg.event_id = e.event_id
LEFT JOIN ci  ON ci.event_id  = e.event_id
LEFT JOIN fu  ON fu.event_id  = e.event_id
LEFT JOIN ex  ON ex.event_id  = e.event_id
ORDER BY e.starts_at;
