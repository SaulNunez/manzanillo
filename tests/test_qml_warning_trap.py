"""Proves the qml_warnings fixture really catches problems, so a green smoke test means something."""
import pytest


def write_qml(tmp_path, body):
    path = tmp_path / "Probe.qml"
    path.write_text("import QtQuick\nimport QtQuick.Window\nWindow {\n" + body + "\n}\n")
    return path


def test_runtime_binding_error_is_caught(load_qml, qml_warnings, tmp_path):
    load_qml(write_qml(tmp_path, "property int n: undefinedThing.length"))
    assert any("undefinedThing" in m for m in qml_warnings.unexpected())
    qml_warnings.messages.clear()  # expected here; don't fail this test on teardown


def test_unknown_api_client_member_is_caught(load_qml, qml_warnings, tmp_path):
    load_qml(write_qml(tmp_path, "property int n: apiClient.noSuchProperty.length"))
    assert qml_warnings.unexpected()
    qml_warnings.messages.clear()


def test_allow_tolerates_a_known_warning(load_qml, qml_warnings, tmp_path):
    qml_warnings.allow(r"undefinedThing")
    load_qml(write_qml(tmp_path, "property int n: undefinedThing.length"))
    assert qml_warnings.messages and not qml_warnings.unexpected()


def test_load_error_fails_the_test(load_qml, qml_warnings, tmp_path):
    with pytest.raises(AssertionError, match="QML failed to load"):
        load_qml(write_qml(tmp_path, "NoSuchType {}"))
    qml_warnings.messages.clear()
