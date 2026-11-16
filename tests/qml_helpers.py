"""Helpers for driving loaded QML from Python tests.

QML fixtures live in conftest.py; plain functions live here so test modules can
import them (``from qml_helpers import find``).
"""
import re
from dataclasses import dataclass, field
from pathlib import Path

from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QPointF, QtMsgType
from PySide6.QtGui import QAccessible
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem, QQuickWindow
from shiboken6 import getCppPointer

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
    them; this walks QObject children and visual child items alike, visiting each
    object once (most items are both, so without that a miss would crawl).
    """
    pending = [root.contentItem() if isinstance(root, QQuickWindow) else root]
    seen = set()
    while pending:
        obj = pending.pop()
        key = getCppPointer(obj)[0]  # id() of a transient Python wrapper gets reused
        if key in seen:
            continue
        seen.add(key)
        if obj.objectName() == object_name:
            return obj
        pending.extend(obj.children())
        if isinstance(obj, QQuickItem):
            pending.extend(obj.childItems())
    raise AssertionError(f"no QML item with objectName {object_name!r}")


def qml_eval(item, expression):
    """Evaluate a QML expression in ``item``'s scope (for gadget/enum properties
    like ``icon.name`` or ``display === AbstractButton.IconOnly``)."""
    context = None
    owner = item
    while context is None and owner is not None:  # control internals have no context of their own
        context = QQmlEngine.contextForObject(owner)
        owner = owner.parent()
    value, _ = QQmlExpression(context, item, expression).evaluate()
    return value


def show_page(main_window, qtbot, index):
    """Switch the main window to nav page ``index`` (0 containers, 1 images, 2 volumes, 3 settings)."""
    find(main_window.window, "navList").setProperty("currentIndex", index)
    qtbot.wait(20)


def open_detail(main_window, qtbot, nav_index, stack_name, open_function, args):
    """Show nav page ``nav_index`` and push a detail page with ``open_function(*args)``;
    returns the page's StackView once the detail page is on it and the window is active."""
    window = main_window.window
    find(window, "navList").setProperty("currentIndex", nav_index)
    stack = find(window, stack_name)
    call_qml(stack.parentItem(), open_function, *args)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    return stack


def settle(stack, qtbot):
    """Wait for a StackView push transition and layout to finish so items are where they'll stay."""
    qtbot.waitUntil(lambda: not stack.property("busy"))
    qtbot.wait(50)


def focus(main_window, item, qtbot):
    """Activate the window and give ``item`` active focus (for keyboard tests)."""
    window = main_window.window
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    QMetaObject.invokeMethod(item, "forceActiveFocus")
    qtbot.waitUntil(lambda: item.property("activeFocus"))


def scene_x(item):
    """``item``'s left edge in scene coordinates."""
    return item.mapToScene(QPointF(0, 0)).x()


def accessible_name(item):
    """The name screen readers announce for ``item``."""
    iface = QAccessible.queryAccessibleInterface(item)
    assert iface is not None, f"{item.objectName()} has no accessible interface"
    return iface.text(QAccessible.Text.Name)


def accessible_description(item):
    """The accessible description screen readers announce for ``item``."""
    iface = QAccessible.queryAccessibleInterface(item)
    assert iface is not None, f"{item.objectName()} has no accessible interface"
    return iface.text(QAccessible.Text.Description)


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
