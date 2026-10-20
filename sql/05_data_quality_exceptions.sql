-- 05. Problems found while loading the legacy sheets, plus a live check for events where
-- check-ins went over capacity. One row can have several issues, so these counts don't add
-- up to a row total (00_headline_metrics.sql has that).

-- uat_tests.sql checks this view too.
DROP VIEW IF EXISTS temp.data_quality_exceptions;
CREATE TEMP VIEW data_quality_exceptions AS
WITH source_rows AS (
    SELECT 'legacy_registrations' AS source_table, COUNT(*) AS n FROM legacy_registrations
    UNION ALL SELECT 'legacy_signins', COUNT(*) FROM legacy_signins
    UNION ALL SELECT 'legacy_followups', COUNT(*) FROM legacy_followups
    UNION ALL SELECT 'event_employers', COUNT(*) FROM event_employers
    UNION ALL SELECT 'events', COUNT(*) FROM events
),
issues AS (
    SELECT source_table, issue, action_taken, COUNT(*) AS affected_rows
    FROM load_exceptions
    GROUP BY source_table, issue, action_taken
    UNION ALL
    SELECT 'events', 'Check-ins exceeded capacity', 'Flag for room planning', COUNT(*)
    FROM (SELECT e.event_id FROM events e JOIN checkins c ON c.event_id = e.event_id
          GROUP BY e.event_id, e.capacity HAVING COUNT(*) > e.capacity)
)
SELECT
    i.source_table,
    i.issue,
    i.action_taken,
    i.affected_rows,
    ROUND(100.0 * i.affected_rows / s.n, 1) AS share_of_source_rows_pct,
    CASE WHEN i.source_table = 'events' THEN 'Monitor'
         WHEN i.action_taken LIKE 'Held%' THEN 'Staff review'
         WHEN i.action_taken LIKE '%flagged%' THEN 'Loaded, flagged'
         ELSE 'Fixed in load' END AS resolution
FROM issues i
JOIN source_rows s ON s.source_table = i.source_table
ORDER BY i.source_table, i.affected_rows DESC;

SELECT * FROM data_quality_exceptions;
