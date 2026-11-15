"""Settings page: saving and testing the Docker socket path (issue #9)."""
import pytest
from PySide6.QtCore import QPointF

from qml_helpers import find

NEW_PATH = "/run/user/1000/docker.sock"


@pytest.fixture
def settings(main_window, qtbot):
    nav = find(main_window.window, "navList")
    nav.setProperty("currentIndex", 3)
    qtbot.wait(10)
    return main_window


def click(button):
    button.clicked.emit()


def test_save_is_disabled_until_the_path_is_edited(settings):
    save = find(settings.window, "saveSocketPathButton")
    field = find(settings.window, "socketField")
    assert save.property("enabled") is False

    field.setProperty("text", NEW_PATH)
    assert save.property("enabled") is True

    field.setProperty("text", "/var/run/docker.sock")
    assert save.property("enabled") is False


def test_saving_confirms_with_text_and_disables_save_again(settings, qtbot):
    save = find(settings.window, "saveSocketPathButton")
    field = find(settings.window, "socketField")
    status = find(settings.window, "saveStatusLabel")
    assert status.property("text") == ""

    field.setProperty("text", NEW_PATH)
    click(save)
    assert ("setSocketPath", NEW_PATH) in settings.fake.calls

    settings.fake.set("socketPath", NEW_PATH)  # the real client emits this once saved
    qtbot.wait(10)
    assert save.property("enabled") is False
    assert "Saved" in status.property("text")
    assert status.property("visible") is True


def test_editing_again_clears_the_saved_confirmation(settings, qtbot):
    field = find(settings.window, "socketField")
    status = find(settings.window, "saveStatusLabel")
    field.setProperty("text", NEW_PATH)
    click(find(settings.window, "saveSocketPathButton"))
    settings.fake.set("socketPath", NEW_PATH)
    qtbot.wait(10)

    field.setProperty("text", NEW_PATH + "x")
    assert status.property("text") == ""


def ancestors(item):
    while item is not None:
        yield item
        item = item.parentItem()


def test_save_and_test_sit_beside_the_field_not_in_the_toolbar(settings):
    field = find(settings.window, "socketField")
    field_top = field.mapToScene(QPointF(0, 0)).y()
    field_bottom = field_top + field.height()
    for name in ("saveSocketPathButton", "testConnectionButton"):
        button = find(settings.window, name)
        # Grouped with the field: in the field's own row or the column holding it.
        assert field.parentItem() in list(ancestors(button)), name
        top = button.mapToScene(QPointF(0, 0)).y()
        # On the field's row or directly below it -- never above it in the toolbar.
        assert top + button.height() > field_top, name
        assert top < field_bottom + 3 * field.height(), name


def test_connection_result_is_reported_in_text(settings, qtbot):
    label = find(settings.window, "testResultLabel")
    settings.fake.connectionTestSucceeded.emit("27.0.1")
    qtbot.wait(10)
    assert "Connected" in label.property("text")
    settings.fake.connectionTestFailed.emit("no such file")
    qtbot.wait(10)
    assert "Connection failed" in label.property("text")
