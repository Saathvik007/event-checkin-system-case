-- 04. Employer follow-up status as of the report date.
-- Policy: the attendee list goes to each employer within 3 business days of the event
-- (due_date). Statuses: Sent on time, Sent late, Overdue (not sent and past due),
-- Not yet due.
-- Grain: follow_ups has one row per event and employer (primary key), so the joins to
-- events and employers keep one row per follow-up (71).

-- Saved as a temporary view so the acceptance tests (uat_tests.sql) can reuse this exact logic.
DROP VIEW IF EXISTS temp.employer_follow_up_status;
CREATE TEMP VIEW employer_follow_up_status AS
WITH settings AS (SELECT as_of_date FROM report_settings)
SELECT
    f.event_id,
    e.event_name,
    e.event_type,
    date(e.starts_at) AS event_date,
    f.employer_id,
    em.employer_name,
    f.due_date,
    f.sent_date,
    CASE
        WHEN f.sent_date IS NOT NULL AND f.sent_date <= f.due_date THEN 'Sent on time'
        WHEN f.sent_date IS NOT NULL THEN 'Sent late'
        WHEN f.due_date < (SELECT as_of_date FROM settings) THEN 'Overdue'
        ELSE 'Not yet due'
    END AS status,
    CASE
        WHEN f.sent_date > f.due_date THEN CAST(julianday(f.sent_date) - julianday(f.due_date) AS INTEGER)
        WHEN f.sent_date IS NULL AND f.due_date < (SELECT as_of_date FROM settings)
            THEN CAST(julianday((SELECT as_of_date FROM settings)) - julianday(f.due_date) AS INTEGER)
    END AS days_past_due
FROM follow_ups f
JOIN events e     ON e.event_id = f.event_id
JOIN employers em ON em.employer_id = f.employer_id
ORDER BY
    CASE WHEN f.sent_date IS NULL AND f.due_date < (SELECT as_of_date FROM settings) THEN 0 ELSE 1 END,
    f.due_date, em.employer_name;

SELECT * FROM employer_follow_up_status;
