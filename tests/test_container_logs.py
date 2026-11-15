"""Container log viewer: follows new output only while the user wants it to (#10)."""
import pytest
from PySide6.QtCore import QMetaObject, Qt
from PySide6.QtTest import QTest

from qml_helpers import call_qml, find


def lines(start, count):
    return "".join(f"line {i}\n" for i in range(start, start + count))


@pytest.fixture
def logs_view(main_window, qtbot):
    """Open a container's detail page on the Logs tab with a screenful+ of output."""
    stack = find(main_window.window, "containerStack")
    call_qml(stack.parentItem(), "openContainerDetail", "abc123")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    find(main_window.window, "containerDetailTabBar").setProperty("currentIndex", 1)
    main_window.fake.set("containerLogsStreaming", True)
    main_window.fake.set("containerLogs", lines(0, 200))
    flick = find(main_window.window, "containerLogsFlickable")
    qtbot.waitUntil(lambda: flick.property("contentHeight") > flick.property("height") > 0)
    qtbot.waitUntil(lambda: at_bottom(flick))
    return main_window, flick


def max_y(flick):
    return flick.property("contentHeight") - flick.property("height")


def at_bottom(flick):
    return flick.property("contentY") >= max_y(flick) - 1


def focus(main_window, item, qtbot):
    window = main_window.window
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    QMetaObject.invokeMethod(item, "forceActiveFocus")
    qtbot.waitUntil(lambda: item.property("activeFocus"))


def append(main_window, count):
    fake = main_window.fake
    current = fake.property("containerLogs")
    fake.set("containerLogs", current + lines(10_000, count))


def test_new_lines_keep_view_at_bottom_while_following(logs_view, qtbot):
    main_window, flick = logs_view
    append(main_window, 50)
    qtbot.waitUntil(lambda: at_bottom(flick))


def test_scrolling_up_stops_auto_scroll(logs_view, qtbot):
    main_window, flick = logs_view
    flick.setProperty("contentY", 100)
    qtbot.wait(10)
    append(main_window, 50)
    qtbot.wait(50)
    assert flick.property("contentY") == 100
    assert find(main_window.window, "logFollowButton").property("checked") is False


def test_scrolling_back_to_bottom_resumes_following(logs_view, qtbot):
    main_window, flick = logs_view
    flick.setProperty("contentY", 100)
    qtbot.wait(10)
    flick.setProperty("contentY", max_y(flick))
    qtbot.wait(10)
    append(main_window, 50)
    qtbot.waitUntil(lambda: at_bottom(flick))
    assert find(main_window.window, "logFollowButton").property("checked") is True


def test_follow_state_is_shown_as_text(logs_view, qtbot):
    main_window, flick = logs_view
    button = find(main_window.window, "logFollowButton")
    assert button.property("text") == "Following"
    flick.setProperty("contentY", 100)
    qtbot.wait(10)
    assert button.property("text") == "Paused"


def test_follow_button_jumps_to_bottom_and_resumes(logs_view, qtbot):
    main_window, flick = logs_view
    flick.setProperty("contentY", 100)
    qtbot.wait(10)
    button = find(main_window.window, "logFollowButton")
    focus(main_window, button, qtbot)
    QTest.keyClick(main_window.window, Qt.Key_Space)
    qtbot.waitUntil(lambda: at_bottom(flick))
    assert button.property("checked") is True
    append(main_window, 50)
    qtbot.waitUntil(lambda: at_bottom(flick))


def test_follow_button_pauses_from_keyboard(logs_view, qtbot):
    main_window, flick = logs_view
    button = find(main_window.window, "logFollowButton")
    focus(main_window, button, qtbot)
    QTest.keyClick(main_window.window, Qt.Key_Space)
    qtbot.waitUntil(lambda: button.property("checked") is False)
    y = flick.property("contentY")
    append(main_window, 50)
    qtbot.wait(50)
    assert flick.property("contentY") == y


def test_button_tracks_scrolling_after_being_pressed(logs_view, qtbot):
    main_window, flick = logs_view
    button = find(main_window.window, "logFollowButton")
    focus(main_window, button, qtbot)
    QTest.keyClick(main_window.window, Qt.Key_Space)  # pause
    QTest.keyClick(main_window.window, Qt.Key_Space)  # follow again
    qtbot.waitUntil(lambda: button.property("checked") is True)
    flick.setProperty("contentY", 100)
    qtbot.wait(10)
    assert button.property("checked") is False
    assert button.property("text") == "Paused"
