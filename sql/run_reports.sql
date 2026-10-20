-- Runs the headline metrics, the six reports and the Tableau extract, and saves each
-- result to outputs/ as a CSV with the same name.
-- Run from the project folder, after build_database.sql:
--   sqlite3 data/checkin_synthetic.db < sql/run_reports.sql

.bail on
.headers on
.mode csv

.output outputs/00_headline_metrics.csv
.read sql/00_headline_metrics.sql
.output outputs/01_attendance_rate_by_event.csv
.read sql/01_attendance_rate_by_event.sql
.output outputs/02_no_show_rate.csv
.read sql/02_no_show_rate.sql
.output outputs/03_duplicate_registrations.csv
.read sql/03_duplicate_registrations.sql
.output outputs/03_duplicate_summary.csv
.read sql/03_duplicate_summary.sql
.output outputs/04_employer_follow_up_status.csv
.read sql/04_employer_follow_up_status.sql
.output outputs/05_data_quality_exceptions.csv
.read sql/05_data_quality_exceptions.sql
.output outputs/06_check_in_arrival_pattern.csv
.read sql/06_check_in_arrival_pattern.sql
.output outputs/tableau_extract.csv
.read sql/tableau_extract.sql
.output stdout

.headers off
.mode list
SELECT 'Saved the headline metrics, six reports, the duplicate summary and the Tableau extract to outputs/.';
