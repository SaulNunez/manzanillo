"""Search shortcuts, nav icons and the Reduce motion setting (issue #17)."""
import pytest
from PySide6.QtCore import QMetaObject, QSettings, Qt
from PySide6.QtQml import QQmlEngine, QQmlExpression
from PySide6.QtTest import QTest

from api_client import ApiClient
from qml_helpers import call_qml, find, find_item


def focus(main_window, item, qtbot):
    window = main_window.window
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    QMetaObject.invokeMethod(item, "forceActiveFocus")
    qtbot.waitUntil(lambda: item.property("activeFocus"))


def test_ctrl_f_focuses_the_container_search_field(main_window, qtbot):
    search = find(main_window.window, "containerSearchField")
    focus(main_window, find(main_window.window, "containersListView"), qtbot)
    assert not search.property("activeFocus")

    QTest.keyClick(main_window.window, Qt.Key_F, Qt.ControlModifier)
    qtbot.waitUntil(lambda: search.property("activeFocus"))


def test_escape_clears_the_container_search_field(main_window, qtbot):
    search = find(main_window.window, "containerSearchField")
    focus(main_window, search, qtbot)
    for key in (Qt.Key_W, Qt.Key_E, Qt.Key_B):
        QTest.keyClick(main_window.window, key)
    assert search.property("text") == "web"

    QTest.keyClick(main_window.window, Qt.Key_Escape)
    assert search.property("text") == ""



NAV_LABELS = ["Containers", "Images", "Volumes", "Settings"]


def qml_eval(item, expression):
    """Evaluate a QML expression in ``item``'s scope (for gadget/enum properties)."""
    value, _ = QQmlExpression(QQmlEngine.contextForObject(item), item, expression).evaluate()
    return value


def test_each_nav_item_shows_an_icon_beside_its_label(main_window):
    icon_names = set()
    for index, label in enumerate(NAV_LABELS):
        item = find_item(main_window.window, f"navItem_{index}")
        assert item.property("text") == label
        assert qml_eval(item, "display === AbstractButton.TextBesideIcon")
        icon_name = qml_eval(item, "icon.name")
        assert icon_name, label
        icon_names.add(icon_name)
    assert len(icon_names) == len(NAV_LABELS)


@pytest.fixture
def isolated_settings(tmp_path):
    """Point QSettings at an empty temp dir so tests never touch the user's config."""
    for fmt in (QSettings.Format.NativeFormat, QSettings.Format.IniFormat):
        QSettings.setPath(fmt, QSettings.Scope.UserScope, str(tmp_path))
    return tmp_path


def test_reduce_motion_is_off_by_default_and_persists_across_restarts(isolated_settings, qtbot):
    client = ApiClient("/var/run/docker.sock")
    assert client.reduceMotion is False

    with qtbot.waitSignal(client.reduceMotionChanged):
        client.setReduceMotion(True)
    assert client.reduceMotion is True

    restarted = ApiClient("/var/run/docker.sock")
    assert restarted.reduceMotion is True


def test_reduce_motion_switch_reflects_and_saves_the_setting(main_window, qtbot):
    find(main_window.window, "navList").setProperty("currentIndex", 3)
    qtbot.wait(10)
    switch = find(main_window.window, "reduceMotionSwitch")
    assert switch.property("checked") is False

    main_window.fake.set("reduceMotion", True)
    assert switch.property("checked") is True

    QMetaObject.invokeMethod(switch, "toggle")
    switch.toggled.emit()
    assert ("setReduceMotion", False) in main_window.fake.calls


@pytest.mark.parametrize(
    "stack_name, open_function, args",
    [
        ("containerStack", "openContainerDetail", ["abc123"]),
        ("imageStack", "openImageDetail", ["sha256:abc", "nginx:latest", False]),
        ("volumeStack", "openVolumeDetail", ["data", False]),
    ],
    ids=["container", "image", "volume"],
)
def test_with_reduce_motion_detail_pages_push_and_pop_instantly(main_window, qtbot, stack_name, open_function, args):
    main_window.fake.set("reduceMotion", True)
    stack = find(main_window.window, stack_name)
    call_qml(stack.parentItem(), open_function, *args)
    assert stack.property("depth") == 2
    assert stack.property("busy") is False

    qml_eval(stack, "pop()")
    assert stack.property("depth") == 1
    assert stack.property("busy") is False


def test_without_reduce_motion_pushing_animates(main_window):
    stack = find(main_window.window, "containerStack")
    call_qml(stack.parentItem(), "openContainerDetail", "abc123")
    assert stack.property("busy") is True
