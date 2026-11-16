"""Unit tests for the pure (no Docker, no event loop) helpers in api_client.py."""
import time

from api_client import ImageListModel, _format_timestamp


def test_format_timestamp_uses_locale_short_date_time(user_locale):
    user_locale("en_US")
    assert _format_timestamp("2024-03-05T14:07:59.123456Z") == "3/5/24 2:07 PM"
    user_locale("de_DE")
    assert _format_timestamp("2024-03-05T14:07:59.123456Z") == "05.03.24 14:07"


def test_format_timestamp_shows_local_time(user_locale, monkeypatch):
    user_locale("de_DE")
    monkeypatch.setenv("TZ", "America/Mexico_City")
    time.tzset()
    assert _format_timestamp("2024-03-05T14:07:59Z") == "05.03.24 08:07"


def test_format_timestamp_accepts_unix_seconds(user_locale):
    user_locale("de_DE")
    assert _format_timestamp(1709647679) == "05.03.24 14:07"


def test_format_timestamp_empty_and_unparseable():
    assert _format_timestamp(None) == ""
    assert _format_timestamp("") == ""
    assert _format_timestamp("yesterday") == "yesterday"


def test_format_size_uses_locale_and_decimal_units(user_locale):
    user_locale("en_US")
    assert ImageListModel._format_size(512) == "512 bytes"
    assert ImageListModel._format_size(1_500) == "1.5 kB"
    assert ImageListModel._format_size(5_000_000_000) == "5.0 GB"
    user_locale("de_DE")
    assert ImageListModel._format_size(1_500) == "1,5 kB"
