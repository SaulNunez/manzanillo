"""Back navigation from detail pages: keyboard shortcuts and right-to-left (#11)."""
import pytest
from PySide6.QtCore import QObject, QPoint, QPointF, Qt
from PySide6.QtTest import QTest

from qml_helpers import accessible_name, call_qml, find, find_item, open_detail

DETAIL_PAGES = [
    # nav index, stack, open function + args, back button
    (0, "containerStack", "openContainerDetail", ["abc123"], "containerDetailBackButton"),
    (1, "imageStack", "openImageDetail", ["sha256:abc", "nginx:latest", False], "imageDetailBackButton"),
    (2, "volumeStack", "openVolumeDetail", ["data", False], "volumeDetailBackButton"),
]
IDS = ["container", "image", "volume"]

LEFT_ARROW = "←"
RIGHT_ARROW = "→"
COLLAPSED_LTR = "▶"
COLLAPSED_RTL = "◀"
EXPANDED = "▼"


def tooltip_shown_on_hover(main_window, qtbot, item):
    """Hover ``item`` and return the text of the tool tip that appears."""
    window = main_window.window
    center = item.mapToScene(QPointF(item.width() / 2, item.height() / 2)).toPoint()
    item.setProperty("hoverEnabled", True)  # off by default on the offscreen platform
    QTest.mouseMove(window, center + QPoint(200, 200))  # start elsewhere so the move is a real one
    QTest.mouseMove(window, center)
    qtbot.waitUntil(lambda: item.property("hovered"))
    tips = []

    def visible_tip():
        tips[:] = [t for t in window.findChildren(QObject)
                   if t.metaObject().className().startswith("QQuickToolTip") and t.property("visible")]
        return bool(tips)

    qtbot.waitUntil(visible_tip, timeout=3000)
    return tips[0].property("text")


@pytest.mark.parametrize("nav_index, stack_name, open_function, args, button", DETAIL_PAGES, ids=IDS)
@pytest.mark.parametrize(
    "key, modifier", [(Qt.Key_Escape, Qt.NoModifier), (Qt.Key_Left, Qt.AltModifier)], ids=["esc", "alt-left"]
)
def test_back_shortcut_returns_to_list(main_window, qtbot, nav_index, stack_name, open_function, args, button, key, modifier):
    stack = open_detail(main_window, qtbot, nav_index, stack_name, open_function, args)
    QTest.keyClick(main_window.window, key, modifier)
    qtbot.waitUntil(lambda: stack.property("depth") == 1)


def test_back_shortcut_only_affects_visible_page(main_window, qtbot):
    window = main_window.window
    container_stack = open_detail(main_window, qtbot, 0, "containerStack", "openContainerDetail", ["abc123"])
    volume_stack = open_detail(main_window, qtbot, 2, "volumeStack", "openVolumeDetail", ["data", False])
    QTest.keyClick(window, Qt.Key_Escape)
    qtbot.waitUntil(lambda: volume_stack.property("depth") == 1)
    qtbot.wait(20)
    assert container_stack.property("depth") == 2


def test_escape_closes_open_dialog_before_leaving_page(main_window, qtbot):
    window = main_window.window
    stack = open_detail(main_window, qtbot, 2, "volumeStack", "openVolumeDetail", ["data", False])
    dialog = find(window, "volumeDetailDeleteDialog")
    dialog.setProperty("visible", True)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    QTest.keyClick(window, Qt.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    qtbot.wait(20)
    assert stack.property("depth") == 2


@pytest.mark.parametrize("nav_index, stack_name, open_function, args, button", DETAIL_PAGES, ids=IDS)
def test_back_button_has_accessible_name_and_tooltip(main_window, qtbot, nav_index, stack_name, open_function, args, button):
    open_detail(main_window, qtbot, nav_index, stack_name, open_function, args)
    back = find(main_window.window, button)
    assert back.property("text") == LEFT_ARROW
    assert accessible_name(back) == "Back"
    assert tooltip_shown_on_hover(main_window, qtbot, back) == "Back"


@pytest.mark.parametrize("nav_index, stack_name, open_function, args, button", DETAIL_PAGES, ids=IDS)
def test_back_icon_points_right_in_rtl(rtl, main_window, qtbot, nav_index, stack_name, open_function, args, button):
    open_detail(main_window, qtbot, nav_index, stack_name, open_function, args)
    assert find(main_window.window, button).property("text") == RIGHT_ARROW


def show_compose(main_window, qtbot):
    window = main_window.window
    main_window.fake.set("composeProjects", [{
        "project": "proj",
        "services": [{"service": "web", "containers": [
            {"id": "c" * 64, "name": "proj-web-1", "image": "nginx", "state": "running", "status": "Up"},
        ]}],
    }])
    qtbot.wait(10)
    return find_item(window, "projectToggle_0")


def test_collapsed_arrow_points_forward_in_ltr(main_window, qtbot):
    toggle = show_compose(main_window, qtbot)
    assert toggle.property("text") == COLLAPSED_LTR
    containers_page = find(main_window.window, "containerStack").parentItem()
    call_qml(containers_page, "toggleProjectExpanded", "proj")
    qtbot.waitUntil(lambda: toggle.property("text") == EXPANDED)
    service = find_item(main_window.window, "serviceToggle_0")
    assert service.property("text") == COLLAPSED_LTR


def test_collapsed_arrows_point_left_in_rtl(rtl, main_window, qtbot):
    toggle = show_compose(main_window, qtbot)
    assert toggle.property("text") == COLLAPSED_RTL
    containers_page = find(main_window.window, "containerStack").parentItem()
    call_qml(containers_page, "toggleProjectExpanded", "proj")
    qtbot.waitUntil(lambda: toggle.property("text") == EXPANDED)
    assert find_item(main_window.window, "serviceToggle_0").property("text") == COLLAPSED_RTL
