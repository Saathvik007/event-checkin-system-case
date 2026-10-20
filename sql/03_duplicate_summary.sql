-- 03 summary. Duplicate registrations rolled up to one row per type and pattern.
-- Uses the duplicate_registrations view, so 03_duplicate_registrations.sql has to run
-- first in the same session (run_reports.sql does this).
-- extra_rows = legacy rows beyond the one row each group should have had.

SELECT duplicate_type,
       pattern,
       COUNT(*)                     AS groups,
       SUM(legacy_rows)             AS legacy_rows,
       SUM(legacy_rows) - COUNT(*)  AS extra_rows
FROM duplicate_registrations
GROUP BY duplicate_type, pattern
ORDER BY duplicate_type, pattern;
