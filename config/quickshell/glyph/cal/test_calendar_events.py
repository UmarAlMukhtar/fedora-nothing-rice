import unittest
from datetime import date, datetime

from calendar_events import group_events


class CalendarEventsTest(unittest.TestCase):
    def test_all_day_range_uses_an_exclusive_end(self):
        event = (datetime(2026, 11, 11), datetime(2026, 11, 13), "Conference", True)
        events = group_events(date(2026, 11, 12), date(2026, 11, 15), [event])
        self.assertEqual(events, {"2026-11-12": [{"time": "All day", "title": "Conference"}]})

    def test_timed_event_marks_both_days_and_keeps_its_start_time(self):
        event = (datetime(2026, 11, 12, 23, 30), datetime(2026, 11, 13, 1), "Overnight", False)
        events = group_events(date(2026, 11, 12), date(2026, 11, 14), [event])
        self.assertEqual(events["2026-11-12"], [{"time": "23:30", "title": "Overnight"}])
        self.assertEqual(events["2026-11-13"], [{"time": "Continues", "title": "Overnight"}])

    def test_events_are_sorted_and_midnight_end_does_not_mark_the_next_day(self):
        noon = datetime(2026, 11, 12, 12)
        events = group_events(date(2026, 11, 12), date(2026, 11, 14), [
            (noon, datetime(2026, 11, 13), "Later", False),
            (noon.replace(hour=9), noon.replace(hour=9), "Reminder", False),
        ])
        self.assertEqual(events, {"2026-11-12": [
            {"time": "09:00", "title": "Reminder"},
            {"time": "12:00", "title": "Later"},
        ]})


if __name__ == "__main__":
    unittest.main()
