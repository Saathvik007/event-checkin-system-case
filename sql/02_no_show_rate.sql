-- 02. No-show rate overall, by event type and by how far ahead students registered.
-- A no-show is an active registration with no check-in, so cancelled ones are left out.

WITH active AS (
    SELECT
        r.registration_id,
        e.event_type,
        julianday(e.starts_at) - julianday(r.registered_at) AS lead_days,
        CASE WHEN c.checkin_id IS NULL THEN 1 ELSE 0 END AS no_show
    FROM registrations r
    JOIN events e ON e.event_id = r.event_id
    LEFT JOIN checkins c ON c.registration_id = r.registration_id
    WHERE r.status = 'Registered'
),
banded AS (
    SELECT *,
        CASE
            WHEN lead_days < 0  THEN '6. After the event started'
            WHEN lead_days < 1  THEN '1. Under 1 day'
            WHEN lead_days < 4  THEN '2. 1-3 days'
            WHEN lead_days < 8  THEN '3. 4-7 days'
            WHEN lead_days < 15 THEN '4. 8-14 days'
            ELSE '5. 15+ days'
        END AS lead_band
    FROM active
)
SELECT 'All events' AS dimension, 'All' AS segment,
       COUNT(*) AS registered, COUNT(*) - SUM(no_show) AS attended, SUM(no_show) AS no_shows,
       ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_rate_pct
FROM banded
UNION ALL
SELECT 'Event type', event_type,
       COUNT(*), COUNT(*) - SUM(no_show), SUM(no_show), ROUND(100.0 * SUM(no_show) / COUNT(*), 1)
FROM banded GROUP BY event_type
UNION ALL
SELECT 'Registration lead time', lead_band,
       COUNT(*), COUNT(*) - SUM(no_show), SUM(no_show), ROUND(100.0 * SUM(no_show) / COUNT(*), 1)
FROM banded GROUP BY lead_band
ORDER BY 1, 2;
