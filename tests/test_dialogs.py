"""Dialogs: required fields gate OK, Enter submits, Esc cancels, deletes say "Delete" (#8)."""
import pytest
from PySide6.QtCore import Qt

from qml_helpers import call_qml, find, scene_x


def images_page(main_window):
    return find(main_window.window, "imageStack").parentItem()


def open_pull_dialog(main_window, qtbot):
    call_qml(images_page(main_window), "openPullImageDialog")
    dialog = find(main_window.window, "pullImageDialog")
    qtbot.waitUntil(lambda: dialog.property("opened"))
    return dialog


def test_pull_ok_is_disabled_until_a_reference_is_typed(main_window, qtbot):
    open_pull_dialog(main_window, qtbot)
    ok = find(main_window.window, "pullImageOkButton")
    assert not ok.property("enabled")

    find(main_window.window, "pullReferenceField").setProperty("text", "   ")
    assert not ok.property("enabled")

    find(main_window.window, "pullReferenceField").setProperty("text", "redis:8")
    assert ok.property("enabled")


def test_enter_in_pull_field_pulls_when_valid(main_window, qtbot):
    dialog = open_pull_dialog(main_window, qtbot)
    field = find(main_window.window, "pullReferenceField")
    qtbot.waitUntil(lambda: field.property("activeFocus"))

    qtbot.keyClick(main_window.window, Qt.Key_Return)
    qtbot.wait(10)
    assert dialog.property("visible"), "Enter on an empty reference must not submit"
    assert not any(c[0] == "pullImage" for c in main_window.fake.calls)

    field.setProperty("text", " redis:8 ")
    qtbot.keyClick(main_window.window, Qt.Key_Return)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert ("pullImage", "redis:8") in main_window.fake.calls


def test_escape_cancels_pull(main_window, qtbot):
    dialog = open_pull_dialog(main_window, qtbot)
    find(main_window.window, "pullReferenceField").setProperty("text", "redis:8")
    qtbot.keyClick(main_window.window, Qt.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert not any(c[0] == "pullImage" for c in main_window.fake.calls)


IMAGE_ID = "sha256:abc"


def open_list_tag_dialog(main_window, qtbot):
    call_qml(images_page(main_window), "openTagImageDialog", IMAGE_ID)
    return "tagImageDialog", "tagImageOkButton", "tagRepositoryField", "tagTagField"


def open_detail_tag_dialog(main_window, qtbot):
    stack = find(main_window.window, "imageStack")
    call_qml(images_page(main_window), "openImageDetail", IMAGE_ID, "nginx:latest", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    button = find(main_window.window, "imageDetailTagButton")
    button.clicked.emit()
    return ("imageDetailTagDialog", "imageDetailTagOkButton",
            "imageDetailTagRepositoryField", "imageDetailTagTagField")


TAG_DIALOGS = pytest.mark.parametrize(
    "opener", [open_list_tag_dialog, open_detail_tag_dialog], ids=["list", "detail"])


@TAG_DIALOGS
def test_tag_ok_is_disabled_until_a_repository_is_typed(main_window, qtbot, opener):
    dialog_name, ok_name, repo_name, _ = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    ok = find(main_window.window, ok_name)
    assert not ok.property("enabled")
    find(main_window.window, repo_name).setProperty("text", "  ")
    assert not ok.property("enabled")
    find(main_window.window, repo_name).setProperty("text", "me/app")
    assert ok.property("enabled")


@TAG_DIALOGS
def test_enter_submits_tag_from_either_field(main_window, qtbot, opener):
    dialog_name, _, repo_name, tag_name = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    repo = find(main_window.window, repo_name)
    qtbot.waitUntil(lambda: repo.property("activeFocus"))

    qtbot.keyClick(main_window.window, Qt.Key_Return)
    qtbot.wait(10)
    assert dialog.property("visible"), "Enter with no repository must not submit"

    repo.setProperty("text", "me/app")
    tag = find(main_window.window, tag_name)
    tag.setProperty("text", "v1")
    tag.forceActiveFocus()
    qtbot.keyClick(main_window.window, Qt.Key_Return)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert ("tagImage", IMAGE_ID, "me/app", "v1") in main_window.fake.calls


@TAG_DIALOGS
def test_escape_cancels_tag(main_window, qtbot, opener):
    dialog_name, _, repo_name, _ = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    find(main_window.window, repo_name).setProperty("text", "me/app")
    qtbot.keyClick(main_window.window, Qt.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert not any(c[0] == "tagImage" for c in main_window.fake.calls)


def open_list_image_delete(main_window, qtbot):
    call_qml(images_page(main_window), "confirmDeleteImage", IMAGE_ID, "nginx:latest")
    return "deleteImageDialog", ("deleteImage", IMAGE_ID)


def open_detail_image_delete(main_window, qtbot):
    stack = find(main_window.window, "imageStack")
    call_qml(images_page(main_window), "openImageDetail", IMAGE_ID, "nginx:latest", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    find(main_window.window, "imageDetailDeleteButton").clicked.emit()
    return "imageDetailDeleteDialog", ("deleteImage", IMAGE_ID)


def volumes_page(main_window):
    return find(main_window.window, "volumeStack").parentItem()


def open_list_volume_delete(main_window, qtbot):
    call_qml(volumes_page(main_window), "confirmDeleteVolume", "data")
    return "deleteVolumeDialog", ("deleteVolume", "data")


def open_detail_volume_delete(main_window, qtbot):
    stack = find(main_window.window, "volumeStack")
    call_qml(volumes_page(main_window), "openVolumeDetail", "data", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    find(main_window.window, "volumeDetailDeleteButton").clicked.emit()
    return "volumeDetailDeleteDialog", ("deleteVolume", "data")


DELETE_DIALOGS = pytest.mark.parametrize(
    "opener",
    [open_list_image_delete, open_detail_image_delete,
     open_list_volume_delete, open_detail_volume_delete],
    ids=["image-list", "image-detail", "volume-list", "volume-detail"],
)


@DELETE_DIALOGS
def test_delete_confirmation_names_its_buttons(main_window, qtbot, opener):
    dialog_name, _ = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    assert find(dialog, dialog_name + "ConfirmButton").property("text") == "Delete"
    assert find(dialog, dialog_name + "CancelButton").property("text") == "Cancel"


@DELETE_DIALOGS
def test_delete_confirm_button_deletes(main_window, qtbot, opener):
    dialog_name, expected_call = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    find(dialog, dialog_name + "ConfirmButton").clicked.emit()
    qtbot.waitUntil(lambda: expected_call in main_window.fake.calls)


@DELETE_DIALOGS
def test_delete_cancel_button_does_not_delete(main_window, qtbot, opener):
    dialog_name, expected_call = opener(main_window, qtbot)
    dialog = find(main_window.window, dialog_name)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    find(dialog, dialog_name + "CancelButton").clicked.emit()
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert expected_call not in main_window.fake.calls


def text_colour(button):
    return button.property("contentItem").property("color").name()


def is_danger_red(button):
    colour = button.property("contentItem").property("color")
    return colour.red() > colour.green() and colour.red() > colour.blue()


def test_image_detail_delete_is_set_apart_from_tag(main_window, qtbot):
    find(main_window.window, "navList").setProperty("currentIndex", 1)  # Images
    stack = find(main_window.window, "imageStack")
    call_qml(images_page(main_window), "openImageDetail", IMAGE_ID, "nginx:latest", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    qtbot.wait(20)
    tag = find(main_window.window, "imageDetailTagButton")
    delete = find(main_window.window, "imageDetailDeleteButton")

    gap = scene_x(delete) - (scene_x(tag) + tag.width())
    assert gap >= 48, f"Delete sits only {gap}px from Tag"
    assert text_colour(delete) != text_colour(tag)
    assert is_danger_red(delete)  # Colors.danger


def test_volume_detail_delete_is_destructive_coloured(main_window, qtbot):
    stack = find(main_window.window, "volumeStack")
    call_qml(volumes_page(main_window), "openVolumeDetail", "data", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    qtbot.wait(20)
    delete = find(main_window.window, "volumeDetailDeleteButton")
    back = find(main_window.window, "volumeDetailBackButton")
    assert is_danger_red(delete)  # Colors.danger
    assert text_colour(delete) != text_colour(back)
