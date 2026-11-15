"""Shared error banner on list and detail pages (audit W2, issue #4).

An error shows a banner with an icon and the message. It clears as soon as the
next fetch or action for that page starts, and the user can dismiss it from the
keyboard.
"""
import pytest
from PySide6.QtCore import Qt
from PySide6.QtTest import QTest

from qml_helpers import call_qml, find
from test_search_nav_motion import qml_eval

CONTAINER_ID = "a" * 64
IMAGE_ID = "sha256:" + "b" * 64

# name: (nav index, banner, error signal, "work started" property + value, detail opener)
PAGES = {
    "containers": (0, "containersErrorBanner", "containersErrorOccurred", ("containersBusy", True), None),
    "containers-action": (0, "containersErrorBanner", "containerActionErrorOccurred",
                          ("busyContainerIds", [CONTAINER_ID[:12]]), None),
    "images": (1, "imagesErrorBanner", "imagesErrorOccurred", ("imagesBusy", True), None),
    "images-action": (1, "imagesErrorBanner", "imageActionErrorOccurred", ("busyImageIds", [IMAGE_ID]), None),
    "images-pull": (1, "imagesErrorBanner", "imageActionErrorOccurred", ("imageActionBusy", True), None),
    "volumes": (2, "volumesErrorBanner", "volumesErrorOccurred", ("volumesBusy", True), None),
    "volumes-action": (2, "volumesErrorBanner", "volumeActionErrorOccurred", ("busyVolumeNames", ["data"]), None),
    "container-detail": (0, "containerDetailErrorBanner", "containerDetailErrorOccurred",
                         ("containerDetailBusy", True), ("containerStack", "openContainerDetail", [CONTAINER_ID])),
    "container-detail-action": (0, "containerDetailErrorBanner", "containerActionErrorOccurred",
                                ("busyContainerIds", [CONTAINER_ID[:12]]),
                                ("containerStack", "openContainerDetail", [CONTAINER_ID])),
    "container-logs": (0, "containerDetailErrorBanner", "containerLogsErrorOccurred",
                       ("containerLogsStreaming", True),
                       ("containerStack", "openContainerDetail", [CONTAINER_ID])),
    "image-detail": (1, "imageDetailErrorBanner", "imageDetailErrorOccurred", ("imageDetailBusy", True),
                     ("imageStack", "openImageDetail", [IMAGE_ID, "nginx:latest", False])),
    "image-detail-action": (1, "imageDetailErrorBanner", "imageActionErrorOccurred", ("busyImageIds", [IMAGE_ID]),
                            ("imageStack", "openImageDetail", [IMAGE_ID, "nginx:latest", False])),
    "volume-detail": (2, "volumeDetailErrorBanner", "volumeDetailErrorOccurred", ("volumeDetailBusy", True),
                      ("volumeStack", "openVolumeDetail", ["data", False])),
    "volume-detail-action": (2, "volumeDetailErrorBanner", "volumeActionErrorOccurred",
                             ("busyVolumeNames", ["data"]), ("volumeStack", "openVolumeDetail", ["data", False])),
}


def show(main_window, qtbot, page):
    nav_index, banner_name, _, _, detail = PAGES[page]
    window = main_window.window
    find(window, "navList").setProperty("currentIndex", nav_index)
    if detail:
        stack_name, open_function, args = detail
        stack = find(window, stack_name)
        call_qml(stack.parentItem(), open_function, *args)
        qtbot.waitUntil(lambda: stack.property("depth") == 2)
    qtbot.wait(10)
    return find(window, banner_name)


def fail(main_window, qtbot, page, message="boom"):
    getattr(main_window.fake, PAGES[page][2]).emit(message)
    qtbot.wait(10)


@pytest.mark.parametrize("page", PAGES)
def test_error_shows_banner_with_message(main_window, qtbot, page):
    banner = show(main_window, qtbot, page)
    assert banner.property("visible") is False

    fail(main_window, qtbot, page, "socket unreachable")

    assert banner.property("visible") is True
    assert banner.property("text") == "socket unreachable"


@pytest.mark.parametrize("page", PAGES)
def test_next_fetch_or_action_clears_banner(main_window, qtbot, page):
    banner = show(main_window, qtbot, page)
    fail(main_window, qtbot, page)
    prop, started = PAGES[page][3]

    main_window.fake.set(prop, started)
    qtbot.wait(10)

    assert banner.property("visible") is False


def test_successful_refresh_leaves_banner_cleared(main_window, qtbot):
    banner = show(main_window, qtbot, "containers")
    fail(main_window, qtbot, "containers")

    main_window.fake.set("containersBusy", True)
    main_window.fake.set("containersBusy", False)
    qtbot.wait(10)

    assert banner.property("visible") is False


def test_error_while_work_in_flight_stays_until_next_start(main_window, qtbot):
    banner = show(main_window, qtbot, "containers")
    main_window.fake.set("containersBusy", True)
    fail(main_window, qtbot, "containers")

    main_window.fake.set("containersBusy", False)
    qtbot.wait(10)

    assert banner.property("visible") is True


@pytest.mark.parametrize("page", ["containers", "image-detail"])
def test_banner_has_icon_and_uses_danger_token(main_window, qtbot, page):
    banner = show(main_window, qtbot, page)
    fail(main_window, qtbot, page)

    icon = find(banner, "errorBannerIcon")
    assert icon.property("visible") is True
    assert icon.property("width") > 0
    assert qml_eval(banner, "accentColor === Colors.danger")


@pytest.mark.parametrize("page", ["volumes", "volume-detail"])
def test_dismiss_button_is_keyboard_reachable(main_window, qtbot, page):
    banner = show(main_window, qtbot, page)
    fail(main_window, qtbot, page)
    dismiss = find(banner, "errorBannerDismissButton")

    assert dismiss.property("activeFocusOnTab") is True
    assert dismiss.property("Accessible.name") or dismiss.property("text")
    dismiss.forceActiveFocus(Qt.TabFocusReason)
    qtbot.waitUntil(lambda: dismiss.property("activeFocus"))
    QTest.keyClick(main_window.window, Qt.Key_Space)
    qtbot.wait(10)

    assert banner.property("visible") is False
