# Event check-in business systems case

Author: Saathvik Maheshuni

This is a business analysis case about a made-up university career office. The office keeps track of employer event registrations, door sign-ins and follow-ups with employers in three separate spreadsheets. I designed a system to replace them. The project includes a requirements document, process maps, a SQLite database that migrates the old spreadsheets, six SQL reports, acceptance tests, and a one-page summary for the office director.

All of the data in this project is synthetic (made up). I generated it once with a fixed random seed and saved it as CSV files in data/synthetic/, and every table and number in the project comes from those files. The office, students and employers are not real. Employers are named "Employer 01" to "Employer 30", and emails use the reserved .example domain.

Tableau dashboard: [Event check-in attendance and follow-ups (synthetic)](https://public.tableau.com/app/profile/saathvik.maheshuni/viz/Eventcheck-insystemcase/Eventcheck-inattendanceandfollow-upssynthetic)

## What I found in the synthetic term

When I loaded one term of the old spreadsheets (40 events, 1,800 students) into the new database, 15.6% of the rows needed a fix or a manual check. 127 registration rows and 19 sign-in rows could not be matched to a student on the roster, and 18 more sign-ins had times outside the event. All of these are held for review, which means the current process undercounts attendance. 41 of the 159 walk-ins have the same name as a held registration at the same event, so some of them are probably registered students whose sign-up was held. The duplicate report found 89 confirmed duplicate registrations and 50 likely ones. The likely duplicates only match on name, and 330 names on the roster belong to more than one student, so staff should check them before merging.

43.9% of active registrations were no-shows. Students who registered 15 or more days early missed 59.6% of the time, compared with 38.9% for students who registered 1 to 3 days before. I built that gap into the synthetic data on purpose, so it shows what the report can find, not how real students behave.

Only 49 of 71 employer follow-ups (69.0%) went out within 3 business days. 9 were late and 13 were never sent. 39.6% of check-ins happened in the first 10 minutes after the start, so that is when the door needs the most staff.

All 18 acceptance tests pass on the prototype database.

![Future-state process map](deliverables/process_map_future_state.png)

## How I did it

The synthetic data has clean reference data (the student roster, employers and events) and three messy legacy spreadsheets. The spreadsheets have the kinds of mistakes a manual process makes: blank or swapped student IDs, personal and mistyped emails, duplicate sign-ups, statuses typed as free text, sign-in times typed with the wrong date, and employer names spelled different ways.

sql/schema.sql sets up the new tables. Constraints and triggers enforce the rules from the requirements: one registration and one check-in per student per event, only students on the roster, a valid email format, a check-in time window, and automatic waitlisting when an event is full. sql/migrate_legacy.sql loads the old spreadsheets. It matches each row to a student by school email first and then by student ID, merges duplicates, cleans up values, and writes every change or held row to a load_exceptions table, so no row disappears without a record. The six reports run on the result. sql/uat_tests.sql runs each acceptance test on a fresh copy of the database and saves the actual result, including the database's own error message when it refuses something. All of it is SQL, run with the sqlite3 command-line tool, and I made the charts and the test log workbook in Excel.

## Files

| Path | What it is |
|---|---|
| deliverables/business_requirements.md, .pdf | Goals, stakeholders, functional and non-functional requirements, and user stories with acceptance criteria |
| deliverables/process_map_current_state.png, process_map_future_state.png | Swimlane process maps of the old and new process |
| deliverables/data_dictionary.md, .csv | Every table and column in the database, written from the database by sql/data_dictionary.sql |
| deliverables/uat_test_cases.csv, .xlsx | 18 test cases with expected and actual results (the .xlsx counts the passes with formulas) |
| deliverables/director_summary.md, .pdf | One-page summary for the office director |
| sql/build_database.sql | Builds the database: runs schema.sql, loads the CSVs and runs migrate_legacy.sql |
| sql/schema.sql, sql/migrate_legacy.sql | Database schema and the migration of the old spreadsheets |
| sql/00-06_*.sql | Headline numbers and the six reports: attendance by event, no-show rate, duplicates, follow-up status, data-quality problems, arrival times |
| sql/03_duplicate_summary.sql | The duplicate report rolled up to one row per type and pattern |
| sql/tableau_extract.sql | One row per event for the dashboard |
| sql/run_reports.sql | Runs all the reports and saves each one to outputs/ |
| sql/uat_tests.sql | Runs the 18 acceptance tests and saves the results |
| sql/data_dictionary.sql | Writes the data dictionary from the live database |
| outputs/*.csv | Saved report results |
| outputs/charts.xlsx, *.png | The Excel charts, with the data behind each one, and pictures of them |
| data/synthetic/*.csv | Synthetic reference data and legacy spreadsheets |
| data/checkin_synthetic.db | The SQLite database built from them (synthetic) |

## How to run it

You only need the sqlite3 command-line tool, which comes with macOS (on Windows, download it from sqlite.org). Run these from the project folder:

```bash
sqlite3 data/checkin_synthetic.db < sql/build_database.sql
sqlite3 data/checkin_synthetic.db < sql/run_reports.sql
sqlite3 < sql/uat_tests.sql
sqlite3 data/checkin_synthetic.db < sql/data_dictionary.sql
```

The test run prints a few "constraint failed" errors. Those come from the tests where the database is supposed to refuse something, and the results file records them. The charts are in outputs/charts.xlsx, with their data copied from the report CSVs.

## Limitations

The data is synthetic, so the size of each problem is only an example, and patterns like the lead-time effect come from how I made the synthetic data. The prototype covers the data model, business rules, migration and reports. It does not have screens for students, email reminders, offline check-in or tracking of employer consent, which the requirements leave to a vendor or a campus system. Business days in the follow-up rule skip weekends but not holidays.
