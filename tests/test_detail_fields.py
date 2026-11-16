"""Detail pages: aligned label/value columns and copyable values (#14, audit O1/O2)."""
import re

import pytest
from PySide6.QtCore import QPointF, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtTest import QTest

from qml_helpers import REPO_ROOT, find, find_item, open_detail, scene_x, settle

CONTAINER = {
    "id": "f" * 64, "name": "web", "image": "nginx:latest", "state": "running",
    "created": "2024-01-01", "startedAt": "2024-01-02", "command": "nginx -g daemon off;",
    "workingDir": "/srv", "restartPolicy": "always", "ports": ["80/tcp"], "networks": ["bridge"],
    "mounts": ["/data -> /var/lib/docker/volumes/data/_data"], "env": ["PATH=/usr/bin", "DEBUG=1"],
}
IMAGE = {
    "id": "sha256:" + "e" * 64, "created": "2024-01-01", "size": "1 MB", "architecture": "amd64",
    "os": "linux", "author": "me", "command": "sh", "workingDir": "/app", "tags": ["nginx:latest"],
    "digests": ["nginx@sha256:" + "d" * 64], "exposedPorts": ["80/tcp"], "env": ["A=1"],
    "labels": ["maintainer=me"], "layers": ["sha256:" + "1" * 64],
}
VOLUME = {
    "driver": "local", "scope": "local", "created": "2024-01-01",
    "mountpoint": "/var/lib/docker/volumes/data/_data", "labels": ["com.example=1"], "options": ["type=tmpfs"],
}


def open_container(main_window, qtbot):
    main_window.fake.set("containerDetail", CONTAINER)
    settle(open_detail(main_window, qtbot, 0, "containerStack", "openContainerDetail", [CONTAINER["id"]]), qtbot)


def open_image(main_window, qtbot):
    main_window.fake.set("imageDetail", IMAGE)
    settle(open_detail(main_window, qtbot, 1, "imageStack", "openImageDetail", [IMAGE["id"], "nginx:latest", False]), qtbot)


def open_volume(main_window, qtbot):
    main_window.fake.set("volumeDetail", VOLUME)
    settle(open_detail(main_window, qtbot, 2, "volumeStack", "openVolumeDetail", ["data", False]), qtbot)


def value_text(field):
    return find(field, "valueText")


def click(window, item):
    center = item.mapToScene(QPointF(item.width() / 2, item.height() / 2)).toPoint()
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, center)


@pytest.fixture
def clipboard(qapp):
    board = QGuiApplication.clipboard()
    board.clear()
    yield board
    board.clear()


def test_copy_button_copies_container_id(main_window, qtbot, clipboard):
    open_container(main_window, qtbot)
    field = find(main_window.window, "containerDetailIdValue")
    assert value_text(field).property("text") == CONTAINER["id"]
    button = find(field, "copyButton")
    assert button.property("visible")
    click(main_window.window, button)
    qtbot.waitUntil(lambda: clipboard.text() == CONTAINER["id"])


def keyboard_copy(window, text_item, qtbot):
    text_item.forceActiveFocus()
    qtbot.waitUntil(lambda: text_item.hasActiveFocus())
    QTest.keyClick(window, Qt.Key_A, Qt.ControlModifier)
    QTest.keyClick(window, Qt.Key_C, Qt.ControlModifier)


def test_environment_variable_can_be_selected_and_copied_with_the_keyboard(main_window, qtbot, clipboard):
    open_container(main_window, qtbot)
    field = find_item(main_window.window, "containerEnvValue_1")  # keep the wrapper alive
    env = value_text(field)
    assert env.property("activeFocusOnTab")
    keyboard_copy(main_window.window, env, qtbot)
    qtbot.waitUntil(lambda: clipboard.text() == "DEBUG=1")


def test_mountpoint_can_be_selected_with_the_mouse(main_window, qtbot):
    open_volume(main_window, qtbot)
    field = find(main_window.window, "volumeDetailMountpointValue")
    text = value_text(field)
    start = text.mapToScene(QPointF(1, text.height() / 2)).toPoint()
    end = text.mapToScene(QPointF(text.property("contentWidth") - 1, text.height() / 2)).toPoint()
    window = main_window.window
    QTest.mousePress(window, Qt.LeftButton, Qt.NoModifier, start)
    QTest.mouseMove(window, end)
    QTest.mouseRelease(window, Qt.LeftButton, Qt.NoModifier, end)
    qtbot.waitUntil(lambda: len(text.property("selectedText")) > len(VOLUME["mountpoint"]) // 2)


def test_copy_button_copies_image_digest(main_window, qtbot, clipboard):
    open_image(main_window, qtbot)
    field = find_item(main_window.window, "imageDigestValue_0")
    click(main_window.window, find(field, "copyButton"))
    qtbot.waitUntil(lambda: clipboard.text() == IMAGE["digests"][0])


def test_copy_button_copies_image_id(main_window, qtbot, clipboard):
    open_image(main_window, qtbot)
    field = find(main_window.window, "imageDetailIdValue")
    click(main_window.window, find(field, "copyButton"))
    qtbot.waitUntil(lambda: clipboard.text() == IMAGE["id"])


ALIGNED_FIELDS = [
    (open_container, "containerDetailFields",
     ["containerDetailIdValue", "containerDetailImageValue", "containerDetailCreatedValue",
      "containerDetailCommandValue", "containerDetailRestartPolicyValue"]),
    (open_image, "imageDetailFields",
     ["imageDetailIdValue", "imageDetailCreatedValue", "imageDetailSizeValue",
      "imageDetailArchitectureValue", "imageDetailOsValue", "imageDetailWorkingDirValue"]),
    (open_volume, "volumeDetailFields",
     ["volumeDetailDriverValue", "volumeDetailScopeValue", "volumeDetailCreatedValue",
      "volumeDetailMountpointValue"]),
]


@pytest.mark.parametrize("open_page, grid_name, value_names", ALIGNED_FIELDS, ids=["container", "image", "volume"])
def test_fields_are_laid_out_in_aligned_label_and_value_columns(main_window, qtbot, open_page, grid_name, value_names):
    open_page(main_window, qtbot)
    grid = find(main_window.window, grid_name)
    fields = [find(grid, name) for name in value_names]
    # Every value starts at the same x, right of a label column that starts at the grid's edge.
    value_xs = {round(scene_x(field)) for field in fields}
    assert len(value_xs) == 1, value_xs
    labels = [item for item in grid.childItems()
              if item.isVisible() and item not in fields and item.property("text")
              and item.metaObject().className().startswith("FieldLabel")]
    assert len(labels) >= len(fields)
    assert {round(scene_x(label)) for label in labels} == {round(scene_x(grid))}
    assert value_xs.pop() > scene_x(grid) + max(label.width() for label in labels)
    # Labels are caption-sized, values body-sized.
    caption = labels[0].property("font").pointSizeF()
    body = value_text(fields[0]).property("font").pointSizeF()
    assert caption < body
    # Labels are plain names, not "Key:" strings with the value baked in.
    for label in labels:
        assert not label.property("text").endswith(":")


def test_translatable_strings_do_not_use_spaces_for_layout():
    qsTr = re.compile(r'qsTr\("((?:[^"\\]|\\.)*)"')
    offenders = [
        f"{path.name}: {text!r}"
        for path in sorted((REPO_ROOT / "manzanillo").glob("*.qml"))
        for text in qsTr.findall(path.read_text())
        if "  " in text or "\\t" in text or text != text.strip()
    ]
    assert offenders == []
