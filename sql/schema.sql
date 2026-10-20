-- Schema for the proposed check-in and attendance system (SQLite).
-- Core tables enforce the future-state rules. legacy_* tables hold the three spreadsheets
-- as they exist today, unchanged, so the migration and its exceptions can be audited.
PRAGMA foreign_keys = ON;

-- Reference data -----------------------------------------------------------------------

CREATE TABLE students (
    student_id   TEXT NOT NULL PRIMARY KEY CHECK (student_id GLOB 'S[0-9][0-9][0-9][0-9][0-9][0-9]'),
    first_name   TEXT NOT NULL,
    last_name    TEXT NOT NULL,
    school_email TEXT NOT NULL UNIQUE,
    class_year   INTEGER NOT NULL CHECK (class_year BETWEEN 2025 AND 2032),
    major_group  TEXT NOT NULL
);

CREATE TABLE employers (
    employer_id     TEXT NOT NULL PRIMARY KEY,
    employer_name   TEXT NOT NULL UNIQUE,
    sector          TEXT NOT NULL,
    recruiter_email TEXT NOT NULL
);

CREATE TABLE events (
    event_id   TEXT NOT NULL PRIMARY KEY,
    event_name TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN
                   ('Career fair', 'Info session', 'Employer panel', 'Workshop', 'Networking night')),
    starts_at  TEXT NOT NULL,              -- 'YYYY-MM-DD HH:MM', local time
    ends_at    TEXT NOT NULL,
    location   TEXT NOT NULL,
    capacity   INTEGER NOT NULL CHECK (capacity > 0),
    CHECK (ends_at > starts_at)
);

CREATE TABLE event_employers (
    event_id    TEXT NOT NULL REFERENCES events (event_id),
    employer_id TEXT NOT NULL REFERENCES employers (employer_id),
    PRIMARY KEY (event_id, employer_id)
);

-- Transactions -------------------------------------------------------------------------

CREATE TABLE registrations (
    registration_id INTEGER PRIMARY KEY,
    event_id        TEXT NOT NULL REFERENCES events (event_id),
    student_id      TEXT NOT NULL REFERENCES students (student_id),
    contact_email   TEXT NOT NULL CHECK (contact_email LIKE '%_@_%._%'
                                         AND contact_email NOT LIKE '% %'
                                         AND contact_email NOT LIKE '%@%@%'),
    registered_at   TEXT NOT NULL,
    channel         TEXT NOT NULL CHECK (channel IN ('Online form', 'Staff entry', 'Legacy import')),
    status          TEXT NOT NULL CHECK (status IN ('Registered', 'Waitlisted', 'Cancelled')),
    UNIQUE (event_id, student_id)           -- one registration per student per event
);

CREATE TABLE checkins (
    checkin_id      INTEGER PRIMARY KEY,
    event_id        TEXT NOT NULL REFERENCES events (event_id),
    student_id      TEXT NOT NULL REFERENCES students (student_id),
    registration_id INTEGER REFERENCES registrations (registration_id),  -- NULL = walk-in
    checked_in_at   TEXT NOT NULL,
    method          TEXT NOT NULL CHECK (method IN ('QR scan', 'ID card', 'Manual lookup', 'Legacy import')),
    UNIQUE (event_id, student_id)           -- one check-in per student per event
);

CREATE TABLE follow_ups (
    event_id    TEXT NOT NULL,
    employer_id TEXT NOT NULL,
    due_date    TEXT NOT NULL,              -- 3 business days after the event
    sent_date   TEXT,                       -- NULL until the attendee list is sent
    PRIMARY KEY (event_id, employer_id),
    FOREIGN KEY (event_id, employer_id) REFERENCES event_employers (event_id, employer_id)
);

-- Fixed "as of" date for reports, so results do not change with the day they are run.
CREATE TABLE report_settings (
    as_of_date TEXT NOT NULL
);

-- Every row the migration changed or could not load, with the reason.
CREATE TABLE load_exceptions (
    exception_id  INTEGER PRIMARY KEY,
    source_table  TEXT NOT NULL,
    source_row_id INTEGER,                  -- NULL when the problem is a missing row
    record_key    TEXT,                     -- event and student or employer, for staff follow-up
    issue         TEXT NOT NULL,
    action_taken  TEXT NOT NULL
);

-- Business rules the CHECK constraints cannot express ------------------------------------

-- Check-ins are accepted from 60 minutes before start until the event ends. SQLite
-- triggers fire on one operation each, so the same rule has an INSERT and an UPDATE version.
CREATE TRIGGER trg_checkin_window
BEFORE INSERT ON checkins
WHEN NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.event_id = NEW.event_id
      AND datetime(NEW.checked_in_at) >= datetime(e.starts_at, '-60 minutes')
      AND datetime(NEW.checked_in_at) <= datetime(e.ends_at)
)
BEGIN
    SELECT RAISE(ABORT, 'Check-in time is outside the event window');
END;

CREATE TRIGGER trg_checkin_window_update
BEFORE UPDATE OF checked_in_at, event_id ON checkins
WHEN NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.event_id = NEW.event_id
      AND datetime(NEW.checked_in_at) >= datetime(e.starts_at, '-60 minutes')
      AND datetime(NEW.checked_in_at) <= datetime(e.ends_at)
)
BEGIN
    SELECT RAISE(ABORT, 'Check-in time is outside the event window');
END;

-- A check-in that points to a registration must match its event and student, and the
-- registration must be active (a cancelled or waitlisted student checks in as a walk-in).
CREATE TRIGGER trg_checkin_registration_match
BEFORE INSERT ON checkins
WHEN NEW.registration_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM registrations r
    WHERE r.registration_id = NEW.registration_id
      AND r.event_id = NEW.event_id
      AND r.student_id = NEW.student_id
      AND r.status = 'Registered'
)
BEGIN
    SELECT RAISE(ABORT, 'Registration does not match this event and student, or is not active');
END;

CREATE TRIGGER trg_checkin_registration_match_update
BEFORE UPDATE OF registration_id, event_id, student_id ON checkins
WHEN NEW.registration_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM registrations r
    WHERE r.registration_id = NEW.registration_id
      AND r.event_id = NEW.event_id
      AND r.student_id = NEW.student_id
      AND r.status = 'Registered'
)
BEGIN
    SELECT RAISE(ABORT, 'Registration does not match this event and student, or is not active');
END;

-- New online registrations beyond capacity go to the waitlist. Imported legacy rows are
-- left as they were, since those students already attended or not.
CREATE TRIGGER trg_registration_waitlist
AFTER INSERT ON registrations
WHEN NEW.status = 'Registered' AND NEW.channel <> 'Legacy import'
 AND (SELECT COUNT(*) FROM registrations r
      WHERE r.event_id = NEW.event_id AND r.status = 'Registered')
   > (SELECT capacity FROM events WHERE event_id = NEW.event_id)
BEGIN
    UPDATE registrations SET status = 'Waitlisted' WHERE registration_id = NEW.registration_id;
END;

-- Legacy spreadsheets, loaded as text exactly as found ------------------------------------

CREATE TABLE legacy_registrations (
    row_id        INTEGER PRIMARY KEY,
    event_code    TEXT,
    student_id    TEXT,
    full_name     TEXT,
    email         TEXT,
    registered_on TEXT,
    status        TEXT
);

CREATE TABLE legacy_signins (
    row_id       INTEGER PRIMARY KEY,
    event_code   TEXT,
    student_id   TEXT,
    full_name    TEXT,
    email        TEXT,
    signed_in_at TEXT,
    sheet_type   TEXT
);

CREATE TABLE legacy_followups (
    row_id        INTEGER PRIMARY KEY,
    event_code    TEXT,
    employer_name TEXT,
    sent_on       TEXT,
    notes         TEXT
);

CREATE INDEX idx_registrations_event ON registrations (event_id);
CREATE INDEX idx_checkins_event ON checkins (event_id);
CREATE INDEX idx_checkins_registration ON checkins (registration_id);
