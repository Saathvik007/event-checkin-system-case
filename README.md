# Event check-in business systems case

Author: Saathvik Maheshuni

This is a business analysis case about a made-up university career office. The office keeps track of employer event registrations, door sign-ins and follow-ups with employers in three separate spreadsheets. I designed a system to replace them. The project includes a requirements document, process maps, a SQLite database that migrates the old spreadsheets, six SQL reports, acceptance tests, and a one-page summary for the office director.

All of the data in this project is synthetic (made up). I made it once and saved it as CSV files in data/synthetic/, and every table and number in the project comes from those files. The students and employers are not real either. Employers are named "Employer 01" to "Employer 30", and emails use the reserved .example domain.

Tableau dashboard: [Event check-in attendance and follow-ups (synthetic)](https://public.tableau.com/app/profile/saathvik.maheshuni/viz/Eventcheck-insystemcase/Eventcheck-inattendanceandfollow-upssynthetic)

## What I found

When I loaded one term of the old spreadsheets (40 events, 1,800 students) into the new database, 15.6% of the rows needed a fix or a manual check. 127 registration rows and 19 sign-in rows could not be matched to a student on the roster, and 18 more sign-ins had times outside the event. All of these are held for review, which means the current process undercounts attendance. 41 of the 159 walk-ins have the same name as a held registration at the same event. Some of them are probably registered students whose sign-up was held. The duplicate report found 89 confirmed duplicate registrations and 50 likely ones. The likely ones only match on name, and 330 names on the roster belong to more than one student, so staff should check them before merging.

43.9% of active registrations were no-shows. Students who registered 15 or more days early missed 59.6% of the time. For students who registered 1 to 3 days before, the rate was 38.9%. I put this gap into the data on purpose (more on that under Limitations).

49 of the 71 employer follow-ups (69.0%) were sent within 3 business days. The rest were late (9) or never sent (13). At the door, 39.6% of check-ins happened in the first 10 minutes after the start, so that is when the most staff are needed.

All 18 acceptance tests pass on the prototype database.

![New process map](deliverables/process_map_future_state.png)

## How I did it

The data has two parts: clean reference data (the student roster, employers and events) and three messy legacy spreadsheets. The spreadsheets have the kinds of mistakes a manual process makes: blank or swapped student IDs, personal and mistyped emails, duplicate sign-ups, statuses typed as free text, sign-in times typed with the wrong date, and employer names spelled different ways.

sql/schema.sql sets up the new tables. Constraints and triggers enforce the rules from the requirements: one registration and one check-in per student per event, only students on the roster, a valid email format, a check-in time window, and automatic waitlisting when an event is full.

sql/migrate_legacy.sql loads the old spreadsheets. It matches each row to a student by school email first and then by student ID, merges duplicates and cleans up values. Every change or held row goes into a load_exceptions table, so I can trace what happened to each old row. The six reports run on the result. sql/uat_tests.sql runs each acceptance test on a fresh copy of the database and saves the actual result, including the database's own error message when it refuses something. Everything is in SQL and runs with the sqlite3 command-line tool. I made the charts and the test log workbook in Excel.

## Files

- deliverables/ has the requirements document, the two process maps (current and new), the data dictionary, the 18 test cases with expected and actual results, and the one-page director summary. The .xlsx copy of the test cases counts the passes with formulas.
- sql/ has the schema, the migration, the headline numbers and six reports (00 to 06), the Tableau extract, the tests and the file that writes the data dictionary. build_database.sql builds the database, and run_reports.sql saves each report to outputs/.
- outputs/ has the saved report CSVs, plus charts.xlsx (the Excel charts with the data behind each one) and pictures of the charts.
- data/ has the synthetic CSV files and the SQLite database built from them.

## How to run it

To rebuild everything, open a terminal in the project folder and run these four commands. They only need sqlite3, which macOS already has (on Windows you can download it from sqlite.org).

```bash
sqlite3 data/checkin_synthetic.db < sql/build_database.sql
sqlite3 data/checkin_synthetic.db < sql/run_reports.sql
sqlite3 < sql/uat_tests.sql
sqlite3 data/checkin_synthetic.db < sql/data_dictionary.sql
```

The test run prints a few "constraint failed" errors. Those come from the tests where the database is supposed to refuse something, and the results file records them. The charts in outputs/charts.xlsx use data copied from the report CSVs.

## Limitations

Since the data is made up, the size of each problem is only an example. The lead-time effect is there because I built it into the data on purpose, so it says nothing about how real students behave. The prototype covers the data model, business rules, migration and reports. It does not have screens for students, email reminders, offline check-in or tracking of employer consent, which the requirements leave to a vendor or a campus system. Business days in the follow-up rule skip weekends but not holidays.
