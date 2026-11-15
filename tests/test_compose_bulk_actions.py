"""Compose project headers: running summary, whole-row toggle, Start all / Stop all (#15, O3)."""
from PySide6.QtCore import QPointF, Qt
from PySide6.QtGui import QAccessible, QAccessibleActionInterface
from PySide6.QtTest import QTest

from qml_helpers import call_qml, find, find_item

RUNNING_A, RUNNING_B, EXITED_C = "a" * 12, "b" * 12, "c" * 12


def container(container_id, state):
    return {"id": container_id, "name": "shop-" + container_id[:1], "image": "postgres",
            "status": state, "state": state}


def show_shop(main_window, qtbot):
    """A 'shop' project with 2 of 3 containers running, plus a fully stopped 'blog'."""
    fake = main_window.fake
    fake.set("composeProjects", [
        {"project": "shop", "services": [
            {"service": "db", "containers": [container(RUNNING_A, "running"), container(EXITED_C, "exited")]},
            {"service": "web", "containers": [container(RUNNING_B, "running")]},
        ]},
        {"project": "blog", "services": [
            {"service": "app", "containers": [container("d" * 12, "exited")]},
        ]},
    ])
    find(main_window.window, "containersTabBar").setProperty("currentIndex", 1)
    qtbot.wait(10)


def page(main_window):
    return find(main_window.window, "containerStack").parentItem()


def is_expanded(main_window, project):
    return call_qml(page(main_window), "isProjectExpanded", project)


def test_project_header_summarises_how_many_containers_are_running(main_window, qtbot):
    show_shop(main_window, qtbot)

    assert find_item(main_window.window, "projectSummary_shop").property("text") == "2/3 running"
    assert find_item(main_window.window, "projectSummary_blog").property("text") == "0/1 running"


def test_summary_counts_the_whole_project_even_when_search_hides_some_containers(main_window, qtbot):
    show_shop(main_window, qtbot)
    find(main_window.window, "containerSearchField").setProperty("text", "shop-c")
    qtbot.wait(10)

    assert find_item(main_window.window, "projectSummary_shop").property("text") == "2/3 running"


def test_clicking_anywhere_on_the_header_toggles_the_project(main_window, qtbot):
    show_shop(main_window, qtbot)
    summary = find_item(main_window.window, "projectSummary_shop")
    window = main_window.window
    point = summary.mapToScene(QPointF(summary.width() / 2, summary.height() / 2)).toPoint()

    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
    qtbot.waitUntil(lambda: is_expanded(main_window, "shop"))
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
    qtbot.waitUntil(lambda: not is_expanded(main_window, "shop"))


def test_enter_and_space_toggle_a_focused_header(main_window, qtbot):
    show_shop(main_window, qtbot)
    header = find_item(main_window.window, "projectHeader_shop")
    header.forceActiveFocus()
    qtbot.waitUntil(lambda: header.hasActiveFocus())
    window = main_window.window

    QTest.keyClick(window, Qt.Key_Return)
    qtbot.waitUntil(lambda: is_expanded(main_window, "shop"))
    QTest.keyClick(window, Qt.Key_Space)
    qtbot.waitUntil(lambda: not is_expanded(main_window, "shop"))


def test_header_is_announced_with_its_name_summary_and_state(main_window, qtbot):
    show_shop(main_window, qtbot)
    header = find_item(main_window.window, "projectHeader_shop")

    assert header.property("activeFocusOnTab") is True
    iface = QAccessible.queryAccessibleInterface(header)
    assert iface.role() == QAccessible.Role.Button
    assert iface.text(QAccessible.Text.Name) == "shop, 2/3 running, collapsed"

    iface.actionInterface().doAction(QAccessibleActionInterface.pressAction())
    qtbot.waitUntil(lambda: is_expanded(main_window, "shop"))
    assert iface.text(QAccessible.Text.Name) == "shop, 2/3 running, expanded"


def test_start_all_starts_only_the_projects_stopped_containers(main_window, qtbot):
    show_shop(main_window, qtbot)
    find(main_window.window, "containerSearchField").setProperty("text", "shop-a")
    qtbot.wait(10)

    find_item(main_window.window, "startAllButton_shop").clicked.emit()

    starts = [c for c in main_window.fake.calls if c[0] == "startContainer"]
    assert starts == [("startContainer", EXITED_C)]


def test_stop_all_stops_only_the_projects_running_containers(main_window, qtbot):
    show_shop(main_window, qtbot)

    find_item(main_window.window, "stopAllButton_shop").clicked.emit()

    stops = sorted(c for c in main_window.fake.calls if c[0] == "stopContainer")
    assert stops == [("stopContainer", RUNNING_A), ("stopContainer", RUNNING_B)]


def test_bulk_buttons_are_disabled_when_there_is_nothing_to_do(main_window, qtbot):
    show_shop(main_window, qtbot)

    assert find_item(main_window.window, "stopAllButton_blog").property("enabled") is False
    assert find_item(main_window.window, "startAllButton_blog").property("enabled") is True


def test_bulk_action_progress_shows_per_container_and_on_the_header(main_window, qtbot):
    show_shop(main_window, qtbot)
    call_qml(page(main_window), "toggleProjectExpanded", "shop")
    call_qml(page(main_window), "toggleServiceExpanded", "shop", "db")
    main_window.fake.set("busyContainerIds", [RUNNING_A])
    qtbot.wait(10)
    w = main_window.window

    assert find_item(w, "quickActionButton_" + RUNNING_A).property("text") == "Working..."
    assert find_item(w, "quickActionButton_" + EXITED_C).property("text") == "Start"
    assert find_item(w, "projectSummary_shop").property("text") == "2/3 running, 1 working"
    # Nothing to stop that isn't already being worked on except RUNNING_B.
    find_item(w, "stopAllButton_shop").clicked.emit()
    stops = [c for c in main_window.fake.calls if c[0] == "stopContainer"]
    assert stops == [("stopContainer", RUNNING_B)]


def test_bulk_action_errors_show_in_the_page_error_label(main_window, qtbot):
    show_shop(main_window, qtbot)
    find_item(main_window.window, "startAllButton_shop").clicked.emit()

    main_window.fake.containerActionErrorOccurred.emit("cannot start shop-c")
    qtbot.wait(10)

    label = find_item(main_window.window, "containersErrorLabel")
    assert label.property("visible") is True
    assert label.property("text") == "cannot start shop-c"


def test_clicking_the_arrow_or_a_bulk_button_does_not_also_toggle_via_the_header(main_window, qtbot):
    show_shop(main_window, qtbot)
    window = main_window.window

    def click(name):
        item = find_item(window, name)
        point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2)).toPoint()
        QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
        qtbot.wait(20)

    click("projectToggle_0")
    assert is_expanded(main_window, "shop")
    click("stopAllButton_shop")
    assert is_expanded(main_window, "shop")
    assert ("stopContainer", RUNNING_A) in main_window.fake.calls
