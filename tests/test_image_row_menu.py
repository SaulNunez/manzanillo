"""Image rows keep secondary actions in a ⋯ menu (audit O9, issue #16).

Opening the image is the row's primary action; Tag and Delete live in one
keyboard-reachable, named menu button instead of two stacked buttons.
"""
from PySide6.QtCore import Qt

from qml_helpers import accessible_name, find, find_item, visible_texts

IMAGE_ID = "sha256:abc"
REASON = "In use by a container — remove the container first"


def show_images(main_window, qtbot, containers=0):
    main_window.fake.images_model.set_images(
        [{"Id": IMAGE_ID, "RepoTags": ["nginx:latest"], "Size": 1024, "Containers": containers}])
    find(main_window.window, "navList").setProperty("currentIndex", 1)
    qtbot.wait(10)
    return find_item(main_window.window, "imageRow_" + IMAGE_ID)


def menu_of(main_window):
    return find_item(main_window.window, "imageActionsMenu_" + IMAGE_ID)


def test_row_shows_one_named_menu_button_instead_of_tag_and_delete(main_window, qtbot):
    row = show_images(main_window, qtbot)
    button = find_item(row, "imageActionsButton_" + IMAGE_ID)

    assert button.property("visible")
    assert "nginx:latest" in accessible_name(button)
    assert "Tag" not in visible_texts(row)
    assert "Delete" not in visible_texts(row)


def test_menu_button_opens_menu_with_tag_and_delete(main_window, qtbot):
    show_images(main_window, qtbot)
    button = find_item(main_window.window, "imageActionsButton_" + IMAGE_ID)

    button.clicked.emit()
    qtbot.waitUntil(lambda: menu_of(main_window).property("opened"))

    tag = find_item(main_window.window, "tagImageButton_" + IMAGE_ID)
    delete = find_item(main_window.window, "deleteImageButton_" + IMAGE_ID)
    assert tag.property("visible") and tag.property("text") == "Tag"
    assert delete.property("visible") and delete.property("enabled")


def test_tag_menu_item_opens_tag_dialog(main_window, qtbot):
    show_images(main_window, qtbot)
    find_item(main_window.window, "imageActionsButton_" + IMAGE_ID).clicked.emit()
    qtbot.waitUntil(lambda: menu_of(main_window).property("opened"))

    find_item(main_window.window, "tagImageButton_" + IMAGE_ID).triggered.emit()

    qtbot.waitUntil(lambda: find(main_window.window, "tagImageDialog").property("opened"))


def test_menu_is_reachable_with_tab_and_opens_with_keyboard(main_window, qtbot):
    show_images(main_window, qtbot)
    button = find_item(main_window.window, "imageActionsButton_" + IMAGE_ID)

    assert button.property("focusPolicy") & Qt.FocusPolicy.TabFocus.value
    button.forceActiveFocus()
    qtbot.waitUntil(lambda: button.property("activeFocus"))
    qtbot.keyClick(main_window.window, Qt.Key.Key_Space)

    qtbot.waitUntil(lambda: menu_of(main_window).property("opened"))


def test_menu_key_on_list_opens_current_rows_menu(main_window, qtbot):
    show_images(main_window, qtbot)
    listview = find(main_window.window, "imagesListView")
    listview.forceActiveFocus()
    qtbot.waitUntil(lambda: listview.property("activeFocus"))
    qtbot.keyClick(main_window.window, Qt.Key.Key_Down)  # select the first row
    assert listview.property("currentIndex") == 0

    qtbot.keyClick(main_window.window, Qt.Key.Key_Menu)

    qtbot.waitUntil(lambda: menu_of(main_window).property("opened"))


def test_disabled_delete_in_menu_shows_reason(main_window, qtbot):
    show_images(main_window, qtbot, containers=1)
    find_item(main_window.window, "imageActionsButton_" + IMAGE_ID).clicked.emit()
    menu = menu_of(main_window)
    qtbot.waitUntil(lambda: menu.property("opened"))

    delete = find_item(main_window.window, "deleteImageButton_" + IMAGE_ID)
    assert not delete.property("enabled")
    assert REASON in visible_texts(menu.property("contentItem"))


def test_busy_row_shows_working_indicator_outside_the_menu(main_window, qtbot):
    # Delete's "Working..." text is hidden inside the closed menu, so the row
    # itself has to show that this image is busy (per-item busy, #6).
    fake = main_window.fake
    fake.images_model.set_images([
        {"Id": IMAGE_ID, "RepoTags": ["nginx:latest"], "Containers": 0},
        {"Id": "sha256:def", "RepoTags": ["redis:latest"], "Containers": 0},
    ])
    fake.set("busyImageIds", [IMAGE_ID])
    find(main_window.window, "navList").setProperty("currentIndex", 1)
    qtbot.wait(10)

    assert find_item(main_window.window, "imageBusyIndicator_" + IMAGE_ID).property("visible")
    assert not find_item(main_window.window, "imageBusyIndicator_sha256:def").property("visible")
