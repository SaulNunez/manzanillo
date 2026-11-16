"""Clickable list rows are exposed to assistive technology (audit C3, issue #3).

Each row (container list, Compose container cards, image list, volume list) must be
announced with its name and status, be activatable through the accessibility press
action, and each list must have an accessible name. Checked through the same
QAccessible interface a screen reader (e.g. Orca via AT-SPI) uses.
"""
import pytest
from PySide6.QtCore import QPointF, Qt
from PySide6.QtGui import QAccessible, QAccessibleActionInterface

from qml_helpers import call_qml, find, find_item, show_page

CONTAINER_ID = "a" * 64


def accessible(item):
    iface = QAccessible.queryAccessibleInterface(item)
    assert iface is not None, f"{item.objectName()} has no accessible interface"
    return iface


def press(item):
    actions = accessible(item).actionInterface()
    assert actions is not None, f"{item.objectName()} exposes no accessible actions"
    assert QAccessibleActionInterface.pressAction() in actions.actionNames()
    actions.doAction(QAccessibleActionInterface.pressAction())


@pytest.mark.parametrize("list_name, expected", [
    ("containersListView", "Containers"),
    ("composeProjectsList", "Compose projects"),
    ("imagesListView", "Images"),
    ("volumesListView", "Volumes"),
])
def test_each_list_has_an_accessible_name(main_window, list_name, expected):
    iface = accessible(find(main_window.window, list_name))
    assert iface.role() == QAccessible.Role.List
    assert iface.text(QAccessible.Text.Name) == expected


def test_container_row_is_announced_and_opens_detail(main_window, qtbot):
    fake = main_window.fake
    fake.containers_model.set_containers(
        [{"Id": CONTAINER_ID, "Names": ["/web"], "State": "running", "Image": "nginx"}])
    qtbot.wait(10)
    row = find_item(main_window.window, "containerRow_" + CONTAINER_ID[:12])

    iface = accessible(row)
    assert iface.role() == QAccessible.Role.Button
    name = iface.text(QAccessible.Text.Name)
    assert "web" in name and "Running" in name

    press(row)
    stack = find(main_window.window, "containerStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchContainerDetail", CONTAINER_ID[:12]) in fake.calls


def show_compose_container(main_window, qtbot):
    fake = main_window.fake
    fake.set("composeProjects", [{"project": "shop", "services": [{"service": "db", "containers": [
        {"id": "b" * 12, "name": "shop-db-1", "image": "postgres", "status": "Up", "state": "exited"}]}]}])
    find(main_window.window, "containersTabBar").setProperty("currentIndex", 1)
    page = find(main_window.window, "containerStack").parentItem()
    call_qml(page, "toggleProjectExpanded", "shop")
    call_qml(page, "toggleServiceExpanded", "shop", "db")
    qtbot.wait(10)
    return find_item(main_window.window, "composeContainerRow_" + "b" * 12)


def test_compose_container_card_is_announced_and_opens_detail(main_window, qtbot):
    row = show_compose_container(main_window, qtbot)

    iface = accessible(row)
    assert iface.role() == QAccessible.Role.Button
    name = iface.text(QAccessible.Text.Name)
    assert "shop-db-1" in name and "Exited" in name

    press(row)
    stack = find(main_window.window, "containerStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchContainerDetail", "b" * 12) in main_window.fake.calls


def test_image_row_is_announced_and_opens_detail(main_window, qtbot):
    main_window.fake.images_model.set_images(
        [{"Id": "sha256:abc", "RepoTags": ["nginx:latest"], "Size": 1024, "Containers": 1}])
    show_page(main_window, qtbot, 1)
    row = find_item(main_window.window, "imageRow_sha256:abc")

    iface = accessible(row)
    assert iface.role() == QAccessible.Role.Button
    name = iface.text(QAccessible.Text.Name)
    assert "nginx:latest" in name and "In use" in name

    press(row)
    stack = find(main_window.window, "imageStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchImageDetail", "sha256:abc") in main_window.fake.calls


def test_volume_row_is_announced_and_opens_detail(main_window, qtbot):
    main_window.fake.volumes_model.set_volumes(
        [{"Name": "data", "Driver": "local", "Mountpoint": "/var/lib/docker/volumes/data"}])
    show_page(main_window, qtbot, 2)
    row = find_item(main_window.window, "volumeRow_data")

    iface = accessible(row)
    assert iface.role() == QAccessible.Role.Button
    name = iface.text(QAccessible.Text.Name)
    assert "data" in name and "Not in use" in name

    press(row)
    stack = find(main_window.window, "volumeStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchVolumeDetail", "data") in main_window.fake.calls


def test_tapping_a_row_selects_it_and_opens_detail(main_window, qtbot):
    main_window.fake.volumes_model.set_volumes([{"Name": "a"}, {"Name": "b"}])
    show_page(main_window, qtbot, 2)
    row = find_item(main_window.window, "volumeRow_b")
    center = row.mapToScene(QPointF(row.width() / 4, row.height() / 2)).toPoint()
    qtbot.mouseClick(main_window.window, Qt.MouseButton.LeftButton, pos=center)

    stack = find(main_window.window, "volumeStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchVolumeDetail", "b") in main_window.fake.calls
    assert find(main_window.window, "volumesListView").property("currentIndex") == 1


def test_compose_container_card_opens_on_enter(main_window, qtbot):
    row = show_compose_container(main_window, qtbot)
    row.forceActiveFocus()
    qtbot.keyClick(main_window.window, Qt.Key.Key_Return)
    stack = find(main_window.window, "containerStack")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    assert ("fetchContainerDetail", "b" * 12) in main_window.fake.calls
