"""Helpers for driving loaded QML from Python tests.

QML fixtures live in conftest.py; plain functions live here so test modules can
import them (``from qml_helpers import find``).
"""
import re
from dataclasses import dataclass, field
from pathlib import Path

from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QtMsgType
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow

REPO_ROOT = Path(__file__).resolve().parent.parent


def find(root, object_name):
    """Find a QML object by objectName anywhere under ``root``; fail loudly if missing.

    Use the objectNames already in the QML as test hooks (and keep them stable).
    """
    obj = root.findChild(QObject, object_name)
    assert obj is not None, f"no QML object with objectName {object_name!r}"
    return obj


def call_qml(obj, function_name, *args):
    """Call a JavaScript ``function`` declared on a QML object and return its result.

    Untyped QML function parameters are QVariant, so every argument is passed as one.
    """
    result = QMetaObject.invokeMethod(
        obj, function_name, Q_RETURN_ARG("QVariant"),
        *[Q_ARG("QVariant", a) for a in args],
    )
    return result


def find_item(root, object_name):
    """Like ``find``, but also reaches view delegates (ListView/Repeater rows).

    Delegates are only parented visually (``parentItem``), so ``findChild`` misses
    them; this walks QObject children and visual child items alike.
    """
    pending = [root.contentItem() if isinstance(root, QQuickWindow) else root]
    while pending:
        obj = pending.pop()
        if obj.objectName() == object_name:
            return obj
        pending.extend(obj.children())
        if isinstance(obj, QQuickItem):
            pending.extend(obj.childItems())
    raise AssertionError(f"no QML item with objectName {object_name!r}")


@dataclass
class LoadedQml:
    """What the ``main_window`` / ``load_qml`` fixtures return."""
    engine: QQmlApplicationEngine
    window: QObject  # the root object (a QQuickWindow for Main.qml)
    fake: QObject  # the FakeApiClient exposed to QML as ``apiClient``


@dataclass
class QmlWarnings:
    """Collects Qt warnings that come from QML; the conftest fixture fails the test on any.

    Call ``allow(regex)`` in a test to tolerate an expected warning.
    """
    messages: list = field(default_factory=list)
    allowed: list = field(default_factory=list)

    def allow(self, pattern):
        self.allowed.append(re.compile(pattern))

    def handle(self, msg_type, context, message):
        if msg_type == QtMsgType.QtDebugMsg or msg_type == QtMsgType.QtInfoMsg:
            return
        if not is_qml_message(context, message):
            return
        self.messages.append(message)

    def unexpected(self):
        return [m for m in self.messages if not any(p.search(m) for p in self.allowed)]


def is_qml_message(context, message):
    """True for warnings raised by the QML engine/JS or about one of our .qml files."""
    category = context.category or ""
    return (
        category in ("qml", "js")
        or category.startswith("qt.qml")
        or ".qml" in message
        or ".qml" in (context.file or "")
    )
