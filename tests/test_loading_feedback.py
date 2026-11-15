"""Loading feedback on list pages and toolbars (audit W3, O6, issue #5).

While a list is empty and its fetch is in flight, the page shows a centred busy
indicator instead of a blank area; the empty-state message only appears once loading
has finished with no results. Toolbar buttons keep a fixed label (and width) while
busy and signal it by being disabled.
"""
import pytest

from qml_helpers import find

CONTAINER_ID = "a" * 64

# (nav index, busy property, busy indicator, empty-state label, filler)
PAGES = {
    "containers": (0, "containersBusy", "containersBusyIndicator", "containersEmptyLabel",
                   lambda f: f.containers_model.set_containers(
                       [{"Id": CONTAINER_ID, "Names": ["/web"], "State": "running"}])),
    "compose": (0, "containersBusy", "composeBusyIndicator", "composeEmptyLabel",
                lambda f: f.set("composeProjects", [{
                    "project": "shop", "services": [{"service": "web", "containers": [{
                        "id": CONTAINER_ID, "name": "web", "image": "nginx",
                        "state": "running", "status": "Up"}]}]}])),
    "images": (1, "imagesBusy", "imagesBusyIndicator", "imagesEmptyLabel",
               lambda f: f.images_model.set_images(
                   [{"Id": "sha256:" + "b" * 64, "RepoTags": ["nginx:latest"], "Size": 1}])),
    "volumes": (2, "volumesBusy", "volumesBusyIndicator", "volumesEmptyLabel",
                lambda f: f.volumes_model.set_volumes(
                    [{"Name": "data", "Driver": "local", "Mountpoint": "/x"}])),
}


def show(main_window, qtbot, page):
    index = PAGES[page][0]
    find(main_window.window, "navList").setProperty("currentIndex", index)
    if page == "compose":
        find(main_window.window, "containersTabBar").setProperty("currentIndex", 1)
    qtbot.wait(10)


@pytest.mark.parametrize("page", PAGES)
def test_empty_list_while_loading_shows_busy_indicator_not_empty_message(main_window, qtbot, page):
    _, busy, indicator_name, empty_name, _ = PAGES[page]
    show(main_window, qtbot, page)
    main_window.fake.set(busy, True)
    qtbot.wait(10)

    indicator = find(main_window.window, indicator_name)
    assert indicator.property("visible") is True
    assert indicator.property("running") is True
    assert find(main_window.window, empty_name).property("visible") is False


@pytest.mark.parametrize("page", PAGES)
def test_empty_message_appears_only_after_loading_finishes_empty(main_window, qtbot, page):
    _, busy, indicator_name, empty_name, _ = PAGES[page]
    show(main_window, qtbot, page)
    main_window.fake.set(busy, True)
    qtbot.wait(10)
    main_window.fake.set(busy, False)
    qtbot.wait(10)

    assert find(main_window.window, indicator_name).property("visible") is False
    assert find(main_window.window, empty_name).property("visible") is True


@pytest.mark.parametrize("page", PAGES)
def test_refreshing_a_populated_list_keeps_rows_without_busy_overlay(main_window, qtbot, page):
    _, busy, indicator_name, empty_name, fill = PAGES[page]
    fill(main_window.fake)
    show(main_window, qtbot, page)
    main_window.fake.set(busy, True)
    qtbot.wait(10)

    assert find(main_window.window, indicator_name).property("visible") is False
    assert find(main_window.window, empty_name).property("visible") is False


TOOLBAR_BUTTONS = [
    (0, "refreshContainersButton", "containersBusy"),
    (1, "refreshImagesButton", "imagesBusy"),
    (1, "pullImageToolButton", "imageActionBusy"),
    (1, "buildImageToolButton", "imageActionBusy"),
    (2, "refreshVolumesButton", "volumesBusy"),
]


@pytest.mark.parametrize("index, button_name, busy", TOOLBAR_BUTTONS)
def test_toolbar_button_keeps_label_and_width_while_busy(main_window, qtbot, index, button_name, busy):
    find(main_window.window, "navList").setProperty("currentIndex", index)
    qtbot.wait(10)
    button = find(main_window.window, button_name)
    idle_text, idle_width = button.property("text"), button.property("width")
    assert button.property("enabled") is True

    main_window.fake.set(busy, True)
    qtbot.wait(10)

    assert button.property("enabled") is False
    assert button.property("text") == idle_text
    assert button.property("width") == idle_width
