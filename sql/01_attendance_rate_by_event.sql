-- 01. Attendance rate by event = registered students who checked in / active registrations.
-- Walk-ins get their own column and do not raise the rate.

-- Saved as a temporary view so the acceptance tests (uat_tests.sql) can reuse this exact logic.
DROP VIEW IF EXISTS temp.attendance_rate_by_event;
CREATE TEMP VIEW attendance_rate_by_event AS
WITH reg AS (
    SELECT event_id,
           SUM(status = 'Registered') AS registered,
           SUM(status = 'Cancelled')  AS cancelled
    FROM registrations
    GROUP BY event_id
),
ci AS (
    SELECT event_id,
           SUM(registration_id IS NOT NULL) AS attended,
           SUM(registration_id IS NULL)     AS walk_ins,
           COUNT(*)                         AS total_checkins
    FROM checkins
    GROUP BY event_id
)
SELECT
    e.event_id,
    e.event_name,
    e.event_type,
    date(e.starts_at) AS event_date,
    e.capacity,
    COALESCE(reg.registered, 0) AS registered,
    COALESCE(reg.cancelled, 0)  AS cancelled,
    COALESCE(ci.attended, 0)    AS attended,
    COALESCE(ci.walk_ins, 0)    AS walk_ins,
    COALESCE(ci.total_checkins, 0) AS total_checkins,
    ROUND(100.0 * COALESCE(ci.attended, 0) / reg.registered, 1) AS attendance_rate_pct,
    ROUND(100.0 * (reg.registered - COALESCE(ci.attended, 0)) / reg.registered, 1) AS no_show_rate_pct,
    ROUND(100.0 * COALESCE(ci.total_checkins, 0) / e.capacity, 1) AS capacity_used_pct
FROM events e
LEFT JOIN reg ON reg.event_id = e.event_id
LEFT JOIN ci  ON ci.event_id  = e.event_id
ORDER BY e.starts_at;

SELECT * FROM attendance_rate_by_event;
