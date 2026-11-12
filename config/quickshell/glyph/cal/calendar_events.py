"""Read event instances from the user's enabled Google calendars in EDS."""
import json
import sys
from datetime import date, datetime, time, timedelta


def group_events(first, end, instances):
    days = {}
    one_day = timedelta(days=1)
    for start, finish, title, all_day in instances:
        start_day = start.date()
        end_day = finish.date()
        if not all_day and finish.time() != time.min:
            end_day += one_day
        end_day = min(end, max(end_day, start_day + one_day))
        day = max(first, start_day)
        while day < end_day:
            label = "All day" if all_day else "Continues" if day != start_day else start.strftime("%H:%M")
            days.setdefault(day.isoformat(), []).append({"time": label, "title": title})
            day += one_day
    for events in days.values():
        events.sort(key=lambda event: (event["time"][0].isdigit(), event["time"], event["title"].casefold()))
    return days


def google_events(first, end):
    try:
        import gi

        gi.require_version("ECal", "2.0")
        gi.require_version("EDataServer", "1.2")
        gi.require_version("Goa", "1.0")
        gi.require_version("ICalGLib", "3.0")
        from gi.repository import ECal, EDataServer, Goa, ICalGLib
    except (ImportError, ValueError):
        return []

    goa = Goa.Client.new_sync()
    google_ids = set()
    for account in goa.get_accounts():
        if account.get_calendar():
            props = account.get_account()
            if props.get_cached_property("ProviderType").unpack() == "google":
                google_ids.add(props.get_cached_property("Id").unpack())
    if not google_ids:
        return []

    registry = EDataServer.SourceRegistry.new_sync()
    zone = ICalGLib.Timezone.get_builtin_timezone(ECal.system_timezone_get_location())
    zone = zone or ICalGLib.Timezone.get_utc_timezone()
    instances = []

    def local_time(value, all_day):
        if all_day:
            return datetime(value.get_year(), value.get_month(), value.get_day())
        return datetime.fromtimestamp(value.as_timet_with_zone(value.get_timezone() or zone))

    def collect(component, start, finish, _data):
        if component.get_status() != ICalGLib.PropertyStatus.CANCELLED:
            all_day = start.is_date()
            title = (component.get_summary() or "").strip() or "Untitled event"
            instances.append((local_time(start, all_day), local_time(finish, all_day), title, all_day))
        return True

    begin_seconds = int(datetime.combine(first, time.min).timestamp())
    end_seconds = int(datetime.combine(end, time.min).timestamp())
    for source in registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR):
        account_source = registry.find_extension(source, EDataServer.SOURCE_EXTENSION_GOA)
        if not account_source:
            continue
        account_id = account_source.get_extension(EDataServer.SOURCE_EXTENSION_GOA).get_account_id()
        if account_id in google_ids:
            client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 1, None)
            client.set_default_timezone(zone)
            client.generate_instances_sync(begin_seconds, end_seconds, None, collect)
    return instances


if __name__ == "__main__":
    first = date.fromisoformat(sys.argv[1])
    end = first + timedelta(days=42)
    print(json.dumps(group_events(first, end, google_events(first, end))))
