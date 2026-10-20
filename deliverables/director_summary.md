# Event check-in system: summary for the director

To: Office director
From: Saathvik Maheshuni
Data: One fall term of synthetic data (40 events, 1,800 students). The numbers show what the new reports can find, not results from a real office.

My recommendation: replace the three spreadsheets (registrations, sign-in sheets and the follow-up tracker) with one system for registration and check-in. Try it first on information sessions before using it at the career fair.

## What one term of records shows

Attendance records are incomplete and late. When I loaded the term's spreadsheets into a database, 15.6% of rows needed a fix or a manual check. 127 registration rows and 19 sign-in rows could not be matched to a student, so those students are missing from the attendance counts, and 41 walk-ins may be registered students whose sign-up was never matched. 89 registrations were duplicates, and 50 more look like second sign-ups.

No-shows are high, and they follow a pattern. 43.9% of active registrations did not show up. Students who registered 15 or more days early missed 59.6% of the time, compared with 38.9% for students who registered 1 to 3 days before. This suggests sending a reminder close to the event. I built this pattern into the synthetic data, so the pilot should check it with real check-ins.

Employer follow-ups are often late or missed. 49 of 71 attendee lists went out within 3 business days (69.0%). 9 were late and 13 were never sent.

## What changes

Students register with a student ID that is checked against the roster, so duplicates are blocked and full events put students on a waitlist automatically. Staff scan a QR code or ID card at the door and look up walk-ins on the roster, so attendance is ready as soon as the event ends. Each employer gets a follow-up task due 3 business days after the event, and overdue tasks show up on the coordinator's list. Four reports replace the matching by hand: attendance, no-shows, follow-up status and data quality.

I built a working prototype (database schema, migration of the old spreadsheets and six reports), and it passes all 18 acceptance tests. Door staffing can follow the arrival pattern: 39.6% of check-ins came in the first 10 minutes after the start, and 74.4% of students had arrived by then.

## Decisions needed

1. Approve a one-term pilot on information sessions.
2. Name an owner for the employer list and for the daily roster file.
3. Choose when reminders go out: one day or two days before the event.
4. Confirm the on-time follow-up target proposed in the requirements document.

Limitations: the data is synthetic, so the size of each problem is only an example and some patterns come from how the data was generated. The prototype covers the data rules and reports, not the screens for students, email reminders or offline check-in, which a vendor or campus system would provide. I did not look at costs or vendor options.
