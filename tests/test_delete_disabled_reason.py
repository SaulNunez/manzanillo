"""A disabled Delete explains why (audit C4, issue #7).

Images and volumes that are in use can't be deleted. The reason is shown as a
visible caption (no hover needed, so keyboard users see it) and is exposed to
screen readers both on the row and on the disabled Delete button itself.
"""
from PySide6.QtGui import QAccessible

from qml_helpers import call_qml, find, find_item

REASON = "In use by a container — remove the container first"


def accessible_description(item):
    iface = QAccessible.queryAccessibleInterface(item)
    assert iface is not None
    return iface.text(QAccessible.Text.Description)


def show_page(main_window, qtbot, index):
    find(main_window.window, "navList").setProperty("currentIndex", index)
    qtbot.wait(10)


def visible_texts(item):
    """Texts of all visible text items under ``item`` (as a sighted user sees them)."""
    texts = []
    pending = [item]
    while pending:
        obj = pending.pop()
        if not obj.property("visible"):
            continue
        text = obj.property("text")
        if isinstance(text, str) and obj.metaObject().indexOfProperty("font") >= 0:
            texts.append(text)
        pending.extend(obj.childItems())
    return texts


def show_images(main_window, qtbot, containers):
    main_window.fake.images_model.set_images(
        [{"Id": "sha256:abc", "RepoTags": ["nginx:latest"], "Size": 1024, "Containers": containers}])
    show_page(main_window, qtbot, 1)
    return find_item(main_window.window, "imageRow_sha256:abc")


def show_volumes(main_window, qtbot, ref_count):
    main_window.fake.volumes_model.set_volumes(
        [{"Name": "data", "Driver": "local", "UsageData": {"RefCount": ref_count}}])
    show_page(main_window, qtbot, 2)
    return find_item(main_window.window, "volumeRow_data")


def test_in_use_image_row_explains_disabled_delete(main_window, qtbot):
    row = show_images(main_window, qtbot, containers=1)
    button = find_item(main_window.window, "deleteImageButton_sha256:abc")

    assert not button.property("enabled")
    assert REASON in visible_texts(row)
    assert REASON in accessible_description(row)
    assert REASON in accessible_description(button)


def test_unused_image_row_shows_no_reason(main_window, qtbot):
    row = show_images(main_window, qtbot, containers=0)
    button = find_item(main_window.window, "deleteImageButton_sha256:abc")

    assert button.property("enabled")
    assert REASON not in visible_texts(row)
    assert REASON not in accessible_description(row)
    assert REASON not in accessible_description(button)


def test_in_use_volume_row_explains_disabled_delete(main_window, qtbot):
    row = show_volumes(main_window, qtbot, ref_count=1)
    button = find_item(main_window.window, "deleteVolumeButton_data")

    assert not button.property("enabled")
    assert REASON in visible_texts(row)
    assert REASON in accessible_description(row)
    assert REASON in accessible_description(button)


def test_unused_volume_row_shows_no_reason(main_window, qtbot):
    row = show_volumes(main_window, qtbot, ref_count=0)
    button = find_item(main_window.window, "deleteVolumeButton_data")

    assert button.property("enabled")
    assert REASON not in visible_texts(row)
    assert REASON not in accessible_description(row)
    assert REASON not in accessible_description(button)


def show_volume_detail(main_window, qtbot, in_use):
    show_page(main_window, qtbot, 2)
    stack = find(main_window.window, "volumeStack")
    call_qml(stack.parentItem(), "openVolumeDetail", "data", in_use)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    return stack.property("currentItem")


def test_in_use_volume_detail_explains_disabled_delete(main_window, qtbot):
    page = show_volume_detail(main_window, qtbot, in_use=True)
    button = find(main_window.window, "volumeDetailDeleteButton")

    assert not button.property("enabled")
    assert REASON in visible_texts(page)
    assert REASON in accessible_description(button)


def test_unused_volume_detail_shows_no_reason(main_window, qtbot):
    page = show_volume_detail(main_window, qtbot, in_use=False)
    button = find(main_window.window, "volumeDetailDeleteButton")

    assert button.property("enabled")
    assert REASON not in visible_texts(page)
    assert REASON not in accessible_description(button)


def show_image_detail(main_window, qtbot, in_use):
    show_page(main_window, qtbot, 1)
    stack = find(main_window.window, "imageStack")
    call_qml(stack.parentItem(), "openImageDetail", "sha256:abc", "nginx:latest", in_use)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    return stack.property("currentItem")


def test_in_use_image_detail_explains_disabled_delete(main_window, qtbot):
    page = show_image_detail(main_window, qtbot, in_use=True)
    button = find(main_window.window, "imageDetailDeleteButton")

    assert not button.property("enabled")
    assert REASON in visible_texts(page)
    assert REASON in accessible_description(button)


def test_unused_image_detail_shows_no_reason(main_window, qtbot):
    page = show_image_detail(main_window, qtbot, in_use=False)
    button = find(main_window.window, "imageDetailDeleteButton")

    assert button.property("enabled")
    assert REASON not in visible_texts(page)
    assert REASON not in accessible_description(button)
