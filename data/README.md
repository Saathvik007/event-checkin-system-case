# Data (synthetic)

Everything in this folder is synthetic. It was generated once with a fixed random seed and saved here, and no real students, employers or schools are in it.

- `synthetic/` has the generated CSVs: reference data (students, employers, events, event_employers) and the three old spreadsheets (legacy_registrations, legacy_signins, legacy_followups).
- `checkin_synthetic.db` is the SQLite database that `sql/build_database.sql` builds from those CSVs. It has the schema, the reference data, the old spreadsheets as loaded, and the new tables after the migration.

See `deliverables/data_dictionary.md` for every table and column.
