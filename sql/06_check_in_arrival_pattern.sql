-- 06. Check-ins by minutes from the event start, to plan door staffing. The career fair is
-- left out because it runs as a four-hour open house and arrivals are spread out.

WITH arrivals AS (
    -- Rounded to whole minutes: julianday arithmetic leaves tiny float errors that would
    -- push a check-in exactly on a bucket edge into the wrong bucket.
    SELECT CAST(ROUND((julianday(c.checked_in_at) - julianday(e.starts_at)) * 1440) AS INTEGER)
           AS minutes_from_start
    FROM checkins c
    JOIN events e ON e.event_id = c.event_id
    WHERE e.event_type <> 'Career fair'
),
bucketed AS (
    SELECT
        CASE
            WHEN minutes_from_start < -30 THEN 1
            WHEN minutes_from_start < -15 THEN 2
            WHEN minutes_from_start < 0   THEN 3
            WHEN minutes_from_start < 10  THEN 4
            WHEN minutes_from_start < 20  THEN 5
            ELSE 6
        END AS bucket_order
    FROM arrivals
),
buckets AS (
    -- All six windows, so an empty one shows as zero instead of disappearing.
    SELECT 1 AS bucket_order UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
),
counts AS (
    SELECT b.bucket_order, COUNT(x.bucket_order) AS checkins
    FROM buckets b LEFT JOIN bucketed x ON x.bucket_order = b.bucket_order
    GROUP BY b.bucket_order
)
SELECT
    bucket_order,
    CASE bucket_order
        WHEN 1 THEN '30-60 min early'
        WHEN 2 THEN '15-30 min early'
        WHEN 3 THEN '0-15 min early'
        WHEN 4 THEN '0-10 min after start'
        WHEN 5 THEN '10-20 min after start'
        ELSE '20+ min after start'
    END AS arrival_window,
    checkins,
    ROUND(100.0 * checkins / SUM(checkins) OVER (), 1) AS share_pct,
    ROUND(100.0 * SUM(checkins) OVER (ORDER BY bucket_order) / SUM(checkins) OVER (), 1) AS cumulative_share_pct
FROM counts
ORDER BY bucket_order;
