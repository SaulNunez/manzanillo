"""Unit tests for the pure (no Docker, no event loop) helpers in api_client.py."""
from api_client import ImageListModel, _format_timestamp


def test_format_timestamp_converts_docker_iso_to_minutes():
    assert _format_timestamp("2024-03-05T14:07:59.123456Z") == "2024-03-05 14:07"


def test_format_timestamp_empty_and_unparseable():
    assert _format_timestamp(None) == ""
    assert _format_timestamp("") == ""
    assert _format_timestamp("yesterday") == "yesterday"


def test_format_size_picks_human_unit():
    assert ImageListModel._format_size(512) == "512.0 B"
    assert ImageListModel._format_size(1536) == "1.5 KB"
    assert ImageListModel._format_size(5 * 1024**3) == "5.0 GB"
