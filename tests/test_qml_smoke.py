"""Load the real Main.qml against FakeApiClient and visit every page.

Every test here fails if QML logs any warning (see the qml_warnings fixture in
conftest.py), so this catches load errors, broken bindings, missing
properties on apiClient, unresolved types and missing required properties.
"""
import pytest

from qml_helpers import call_qml, find

NAV_PAGES = ["Containers", "Images", "Volumes", "Settings"]


def test_main_window_loads(main_window):
    assert main_window.window.title() == "Manzanillo"


def test_pages_ask_for_their_data_on_startup(main_window):
    called = {call[0] for call in main_window.fake.calls}
    assert {"fetchContainers", "fetchImages", "fetchVolumes"} <= called


@pytest.mark.parametrize("index", range(len(NAV_PAGES)), ids=NAV_PAGES)
def test_each_nav_page_shows(main_window, qtbot, index):
    nav = find(main_window.window, "navList")
    nav.setProperty("currentIndex", index)
    qtbot.wait(10)  # let bindings and polish settle so late warnings surface
    assert nav.property("currentIndex") == index


@pytest.mark.parametrize(
    "stack_name, open_function, argument, fetch_slot",
    [
        ("containerStack", "openContainerDetail", "abc123", "fetchContainerDetail"),
        ("imageStack", "openImageDetail", "sha256:abc", "fetchImageDetail"),
        ("volumeStack", "openVolumeDetail", "data", "fetchVolumeDetail"),
    ],
    ids=["container", "image", "volume"],
)
def test_each_detail_page_loads(main_window, qtbot, stack_name, open_function, argument, fetch_slot):
    stack = find(main_window.window, stack_name)
    page = stack.parentItem()  # each *Page.qml is the StackView's parent Item
    extra = {"openImageDetail": ["nginx:latest", False], "openVolumeDetail": [False]}
    call_qml(page, open_function, argument, *extra.get(open_function, []))
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    qtbot.wait(10)
    assert (fetch_slot, argument) in main_window.fake.calls
