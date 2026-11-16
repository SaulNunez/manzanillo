"""Keeps tests/fake_api_client.py honest.

If one of these fails you added something to ApiClient or to the QML: add the
same property/signal/slot to FakeApiClient so the QML tests keep loading.
"""
import re
from pathlib import Path

from api_client import ApiClient
from fake_api_client import FakeApiClient

QML_DIR = Path(__file__).resolve().parent.parent / "manzanillo"


def members(meta_object):
    """Names of every property, signal and slot declared on a QObject class."""
    names = {meta_object.property(i).name() for i in range(meta_object.propertyCount())}
    for i in range(meta_object.methodCount()):
        names.add(bytes(meta_object.method(i).name()).decode())
    return names


def qml_api_client_usage():
    """Everything the QML reads/calls as apiClient.X or handles as onX in Connections."""
    used = set()
    for qml in QML_DIR.glob("*.qml"):
        text = qml.read_text()
        used.update(re.findall(r"\bapiClient\.(\w+)", text))
        if "target: apiClient" in text:
            for handler in re.findall(r"function on([A-Z]\w*)\s*\(", text):
                used.add(handler[0].lower() + handler[1:])
    return used


def test_fake_covers_everything_the_qml_uses():
    used = qml_api_client_usage()
    assert used, "regex found no apiClient usage - did the QML layout change?"
    assert used - members(FakeApiClient.staticMetaObject) == set()


def test_fake_mirrors_the_real_api_client_interface():
    assert members(ApiClient.staticMetaObject) - members(FakeApiClient.staticMetaObject) == set()


def test_slots_are_recorded_and_state_setters_notify(qtbot):
    fake = FakeApiClient()
    fake.startContainer("abc")
    assert fake.calls == [("startContainer", "abc")]

    with qtbot.waitSignal(fake.containerDetailBusyChanged):
        fake.set("containerDetailBusy", True)
    assert fake.containerDetailBusy is True
