"""Layout for narrow windows (audit W10, issue #12).

The window has a minimum size; every list page and Settings uses the shared
PageToolBar, whose actions move into a keyboard-reachable overflow menu when they
don't fit; dialogs never grow wider/taller than the window.
"""
import pytest
from PySide6.QtCore import QPointF, Qt

from qml_helpers import call_qml, find, find_item, focus, show_page

ACTIONS_BY_PAGE = {
    0: ["refreshContainersButton"],
    1: ["pullImageToolButton", "buildImageToolButton", "refreshImagesButton"],
    2: ["refreshVolumesButton"],
    3: [],
}

TOOLBARS = [
    (0, "containersPageToolBar"),
    (1, "imagesPageToolBar"),
    (2, "volumesPageToolBar"),
    (3, "settingsPageToolBar"),
]


def resize_to_minimum(main_window, qtbot):
    window = main_window.window
    window.setWidth(window.minimumWidth())
    window.setHeight(window.minimumHeight())
    qtbot.wait(20)
    return window


IMAGE_ACTIONS = ACTIONS_BY_PAGE[1]


def translate_long(main_window, qtbot, names):
    """Lengthen action labels well past English, as long translations do."""
    for name in names:
        button = find(main_window.window, name)
        button.setProperty("text", button.property("text") + " " + "x" * 12)
    qtbot.wait(20)


def scene_rect(item):
    top_left = item.mapToScene(QPointF(0, 0))
    return top_left.x(), top_left.y(), item.width(), item.height()


def test_window_declares_a_minimum_size(main_window):
    # The window manager enforces minimumWidth/Height; the offscreen test platform
    # doesn't, so check the declared hint (the other tests run at exactly this size).
    window = main_window.window
    assert 0 < window.minimumWidth() <= 400
    assert 0 < window.minimumHeight() <= 500
    assert window.width() >= window.minimumWidth()
    assert window.height() >= window.minimumHeight()


@pytest.mark.parametrize("index, toolbar_name", TOOLBARS)
def test_every_list_page_and_settings_uses_the_shared_toolbar(main_window, qtbot, index, toolbar_name):
    show_page(main_window, qtbot, index)
    toolbar = find(main_window.window, toolbar_name)
    assert toolbar.metaObject().className().startswith("PageToolBar")


@pytest.mark.parametrize("index, toolbar_name", TOOLBARS)
def test_nothing_in_the_toolbar_is_clipped_at_minimum_width(main_window, qtbot, index, toolbar_name):
    window = resize_to_minimum(main_window, qtbot)
    show_page(main_window, qtbot, index)
    translate_long(main_window, qtbot, ACTIONS_BY_PAGE[index])
    toolbar = find(main_window.window, toolbar_name)
    tx, _, tw, _ = scene_rect(toolbar)
    assert tx >= 0 and tx + tw <= window.width() + 0.5

    title = find(toolbar, "pageToolBarTitle")
    # Actions overflow into the menu before the title has to elide.
    assert title.property("width") >= title.property("implicitWidth") - 0.5
    for item in visible_toolbar_controls(toolbar):
        x, _, w, _ = scene_rect(item)
        assert x >= tx - 0.5 and x + w <= tx + tw + 0.5, item.objectName()


def visible_toolbar_controls(toolbar):
    from PySide6.QtQuick import QQuickItem
    pending = list(toolbar.childItems())
    found = []
    while pending:
        item = pending.pop()
        if not item.isVisible():
            continue
        if item.metaObject().className().startswith(("QQuickToolButton", "QQuickLabel")):
            found.append(item)
        pending.extend(item.childItems())
    return found


def test_wide_window_shows_actions_inline(main_window, qtbot):
    window = main_window.window
    window.setWidth(1400)
    qtbot.wait(20)
    show_page(main_window, qtbot, 1)
    assert find(window, "pullImageToolButton").isVisible()
    assert not find(window, "imagesPageToolBarOverflowButton").isVisible()


def test_overflowed_actions_are_reachable_from_menu_by_mouse(main_window, qtbot):
    window = resize_to_minimum(main_window, qtbot)
    show_page(main_window, qtbot, 1)
    translate_long(main_window, qtbot, IMAGE_ACTIONS)
    overflow = find(window, "imagesPageToolBarOverflowButton")
    assert overflow.isVisible()
    assert not find(window, "pullImageToolButton").isVisible()

    center = overflow.mapToScene(QPointF(overflow.width() / 2, overflow.height() / 2)).toPoint()
    qtbot.mouseClick(window, Qt.LeftButton, pos=center)
    menu = find(window, "imagesPageToolBarOverflowMenu")
    qtbot.waitUntil(lambda: menu.property("opened"))

    for name in IMAGE_ACTIONS:
        item = find_item(window, name + "MenuItem")
        assert item.isVisible()
        assert item.property("text") == find(window, name).property("text")
    refresh = find_item(window, "refreshImagesButtonMenuItem")
    center = refresh.mapToScene(QPointF(refresh.width() / 2, refresh.height() / 2)).toPoint()
    calls_before = main_window.fake.calls.count(("fetchImages",))
    qtbot.mouseClick(window, Qt.LeftButton, pos=center)
    qtbot.waitUntil(lambda: main_window.fake.calls.count(("fetchImages",)) > calls_before)


def test_overflowed_actions_are_reachable_from_menu_by_keyboard(main_window, qtbot):
    window = resize_to_minimum(main_window, qtbot)
    show_page(main_window, qtbot, 1)
    translate_long(main_window, qtbot, IMAGE_ACTIONS)
    overflow = find(window, "imagesPageToolBarOverflowButton")
    focus(main_window, overflow, qtbot)

    qtbot.keyClick(window, Qt.Key_Space)
    menu = find(window, "imagesPageToolBarOverflowMenu")
    qtbot.waitUntil(lambda: menu.property("opened"))
    qtbot.keyClick(window, Qt.Key_Down)  # first item: Pull Image
    qtbot.keyClick(window, Qt.Key_Return)
    dialog = find(window, "pullImageDialog")
    qtbot.waitUntil(lambda: dialog.property("opened"))


def test_overflow_menu_items_follow_action_enabled_state(main_window, qtbot):
    window = resize_to_minimum(main_window, qtbot)
    show_page(main_window, qtbot, 1)
    translate_long(main_window, qtbot, IMAGE_ACTIONS)
    main_window.fake.set("imageActionBusy", True)
    qtbot.wait(10)
    enabled = [find_item(window, n + "MenuItem").property("enabled") for n in IMAGE_ACTIONS]
    assert enabled == [False, False, True]


def images_page(main_window):
    return find(main_window.window, "imageStack").parentItem()


def volumes_page(main_window):
    return find(main_window.window, "volumeStack").parentItem()


def open_detail(main_window, qtbot, stack_name, page, opener, *args):
    stack = find(main_window.window, stack_name)
    call_qml(page, opener, *args)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)


def open_image_detail_dialog(button):
    def opener(mw, qtbot):
        open_detail(mw, qtbot, "imageStack", images_page(mw), "openImageDetail",
                    "sha256:x", "a-very-long-image-name:with-a-long-tag", False)
        find(mw.window, button).clicked.emit()
    return opener


def open_volume_detail_delete(mw, qtbot):
    open_detail(mw, qtbot, "volumeStack", volumes_page(mw), "openVolumeDetail", "data", False)
    find(mw.window, "volumeDetailDeleteButton").clicked.emit()


def open_build_with_log(mw, qtbot):
    mw.fake.set("buildLog", "step\n" * 50)
    call_qml(images_page(mw), "openBuildImageDialog")


DIALOGS = [
    ("deleteImageDialog", 1, lambda mw, qtbot: call_qml(
        images_page(mw), "confirmDeleteImage", "sha256:x", "a-very-long-image-name:with-a-long-tag")),
    ("pullImageDialog", 1, lambda mw, qtbot: call_qml(images_page(mw), "openPullImageDialog")),
    ("buildImageDialog", 1, open_build_with_log),
    ("tagImageDialog", 1, lambda mw, qtbot: call_qml(images_page(mw), "openTagImageDialog", "sha256:x")),
    ("imageDetailDeleteDialog", 1, open_image_detail_dialog("imageDetailDeleteButton")),
    ("imageDetailTagDialog", 1, open_image_detail_dialog("imageDetailTagButton")),
    ("deleteVolumeDialog", 2, lambda mw, qtbot: call_qml(volumes_page(mw), "confirmDeleteVolume", "data")),
    ("volumeDetailDeleteDialog", 2, open_volume_detail_delete),
]


@pytest.mark.parametrize("name, nav_index, opener", DIALOGS, ids=[d[0] for d in DIALOGS])
def test_dialogs_fit_inside_the_window_at_minimum_size(main_window, qtbot, name, nav_index, opener):
    window = resize_to_minimum(main_window, qtbot)
    show_page(main_window, qtbot, nav_index)
    opener(main_window, qtbot)
    dialog = find(window, name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    assert_popup_inside(window, dialog)


def assert_popup_inside(window, dialog):
    x, y = dialog.property("x"), dialog.property("y")
    w, h = dialog.property("width"), dialog.property("height")
    # Popup x/y are relative to its parent item; map to the scene.
    origin = dialog.property("parent").mapToScene(QPointF(x, y))
    assert origin.x() >= 0 and origin.y() >= 0, (origin, w, h)
    assert origin.x() + w <= window.width() + 0.5, (origin, w, window.width())
    assert origin.y() + h <= window.height() + 0.5, (origin, h, window.height())
