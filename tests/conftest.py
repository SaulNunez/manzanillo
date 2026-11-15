"""Shared pytest fixtures for the manzanillo test suite.

- Runs Qt headless (``QT_QPA_PLATFORM=offscreen``) with the Fusion style, like main.py.
- ``fake_api_client``: a fresh FakeApiClient (see fake_api_client.py).
- ``qml_warnings``: autouse; fails any test during which QML logged a warning.
- ``load_qml``: load any QML file/component with the fake as ``apiClient``.
- ``main_window``: the full app (Main.qml) loaded with the fake.
- ``user_locale``: pins the default QLocale and TZ (UTC) for formatting tests.
"""
import os
import time

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import pytest  # noqa: E402
from PySide6.QtCore import QLocale, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402

from fake_api_client import FakeApiClient  # noqa: E402
from qml_helpers import REPO_ROOT, LoadedQml, QmlWarnings  # noqa: E402

QQuickStyle.setStyle("Fusion")


@pytest.fixture(autouse=True)
def qml_warnings():
    """Fail the test if QML emitted any warning while it ran.

    Autouse, so every test gets it. To tolerate a known warning, request the
    fixture and call ``qml_warnings.allow(r"regex")``.
    """
    collector = QmlWarnings()
    previous = qInstallMessageHandler(collector.handle)
    try:
        yield collector
    finally:
        qInstallMessageHandler(previous)
    unexpected = collector.unexpected()
    if unexpected:
        pytest.fail("QML warnings:\n" + "\n".join(unexpected), pytrace=False)


@pytest.fixture
def fake_api_client():
    return FakeApiClient()


@pytest.fixture
def load_qml(qapp, qtbot, fake_api_client):
    """Return ``load(source)`` that loads QML with ``fake_api_client`` as ``apiClient``.

    ``source`` is either ``"manzanillo/Foo.qml"`` (a path relative to the repo
    root) or a ``(module, type)`` tuple such as ``("manzanillo", "Main")``.
    Fill the fake (models, ``fake.set(...)``) *before* calling ``load`` if the
    page reads state at startup. Load errors fail the test immediately.
    """
    engines = []

    def load(source):
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(REPO_ROOT))
        engine.rootContext().setContextProperty("apiClient", fake_api_client)
        if isinstance(source, tuple):
            engine.loadFromModule(*source)
        else:
            engine.load(QUrl.fromLocalFile(str(REPO_ROOT / source)))
        engines.append(engine)
        roots = engine.rootObjects()
        assert roots, f"QML failed to load: {source}"
        qtbot.wait(10)  # let Component.onCompleted handlers and first layout run
        return LoadedQml(engine=engine, window=roots[0], fake=fake_api_client)

    yield load
    for engine in engines:
        for root in engine.rootObjects():
            root.deleteLater()
        engine.deleteLater()
    qtbot.wait(1)


@pytest.fixture
def main_window(load_qml):
    """The whole app: manzanillo/Main.qml loaded with a FakeApiClient."""
    return load_qml(("manzanillo", "Main"))


@pytest.fixture
def user_locale(monkeypatch):
    """Pin the "system" locale and time zone; returns ``use(locale_name)``."""
    previous = QLocale()
    monkeypatch.setenv("TZ", "UTC")
    time.tzset()

    def use(name):
        QLocale.setDefault(QLocale(name))

    yield use
    QLocale.setDefault(previous)
    monkeypatch.undo()
    time.tzset()
