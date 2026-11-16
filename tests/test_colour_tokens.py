"""Role-based colour tokens that follow the system colour scheme (#1, audit C1/W4).

Status text, badges and destructive buttons must reach WCAG AA (4.5:1) against what
they are drawn on, in light and dark themes, and must follow a theme switch live.
A theme switch is simulated by changing the application palette, which is what the
platform theme does when the desktop flips between light and dark.
"""
import re

import pytest
from PySide6.QtGui import QColor, QGuiApplication, QPalette

from qml_helpers import REPO_ROOT, call_qml, find, find_item

MIN_CONTRAST = 4.5

# Window colours to check against: Fusion's default light, plus two typical dark ones.
THEMES = {
    "light": None,
    "dark": "#353535",
    "darker": "#1e1e1e",
}


def luminance(colour):
    def channel(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (0.2126 * channel(colour.redF()) + 0.7152 * channel(colour.greenF())
            + 0.0722 * channel(colour.blueF()))


def contrast(a, b):
    la, lb = sorted((luminance(QColor(a)), luminance(QColor(b))), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def over(top, bottom):
    """Composite a translucent colour over an opaque one."""
    top, bottom = QColor(top), QColor(bottom)
    a = top.alphaF()
    return QColor.fromRgbF(*(a * t + (1 - a) * b for t, b in zip(
        (top.redF(), top.greenF(), top.blueF()),
        (bottom.redF(), bottom.greenF(), bottom.blueF()))))


def apply_theme(name):
    window = THEMES[name]
    QGuiApplication.setPalette(QPalette() if window is None else QPalette(QColor(window)))


@pytest.fixture
def restore_palette(qapp):
    previous = QGuiApplication.palette()
    yield
    QGuiApplication.setPalette(previous)


@pytest.fixture(params=list(THEMES))
def theme(request, restore_palette):
    apply_theme(request.param)
    return request.param


TOKENS = ("danger", "success", "warning", "neutral")


@pytest.fixture
def tokens(load_qml, tmp_path):
    probe = tmp_path / "TokenProbe.qml"
    probe.write_text(
        "import QtQuick\nimport manzanillo\nQtObject {\n"
        + "".join(f"    property color {t}: Colors.{t}\n" for t in TOKENS)
        + "    property SystemPalette pal: SystemPalette {}\n"
        "    property color window: pal.window\n"
        "    property color button: pal.button\n}\n")
    return load_qml(str(probe)).window


@pytest.mark.parametrize("token", TOKENS)
def test_each_token_is_readable_on_window_and_button(tokens, theme, token):
    colour = tokens.property(token)
    for surface in ("window", "button"):
        ratio = contrast(colour, tokens.property(surface))
        assert ratio >= MIN_CONTRAST, f"{token} on {surface} in {theme}: {ratio:.2f}:1"


def test_tokens_differ_between_light_and_dark(tokens, qtbot, restore_palette):
    light = {t: tokens.property(t).name() for t in TOKENS}
    apply_theme("dark")
    qtbot.wait(10)
    dark = {t: tokens.property(t).name() for t in TOKENS}
    for t in TOKENS:
        assert light[t] != dark[t], f"{t} does not change with the colour scheme"


# --- Container status badges ---------------------------------------------------------

STATES = {
    # Docker state: (badge label, tone group)
    "running": ("Running", "success"),
    "restarting": ("Restarting", "warning"),
    "paused": ("Paused", "warning"),
    "dead": ("Dead", "danger"),
    "exited": ("Exited", "neutral"),
    "created": ("Created", "neutral"),
}


def container_id(state):
    return str(list(STATES).index(state)) * 64


def load_containers(main_window, qtbot):
    main_window.fake.containers_model.set_containers([
        {"Id": container_id(s), "Names": ["/" + s], "State": s, "Image": "img"}
        for s in STATES])
    qtbot.wait(10)


def badge_for(main_window, state):
    row = find_item(main_window.window, "containerRow_" + container_id(state)[:12])
    return find_item(row, "statusBadge")


def badge_text_colour(badge):
    return badge.childItems()[0].property("color")


def assert_badge_readable(main_window, badge, label):
    window = main_window.window.property("color")
    fill = over(badge.property("color"), window)
    text = badge_text_colour(badge)
    for name, surface in (("badge fill", fill), ("window", window)):
        ratio = contrast(text, surface)
        assert ratio >= MIN_CONTRAST, f"{label} badge text on {name}: {ratio:.2f}:1"


def test_container_badges_show_a_readable_label_for_every_state(main_window, qtbot, theme):
    load_containers(main_window, qtbot)
    for state, (label, _) in STATES.items():
        badge = badge_for(main_window, state)
        assert badge.property("text") == label
        assert_badge_readable(main_window, badge, label)


def test_container_badges_colour_each_tone_differently(main_window, qtbot):
    load_containers(main_window, qtbot)
    by_tone = {}
    for state, (_, tone) in STATES.items():
        by_tone.setdefault(tone, set()).add(badge_text_colour(badge_for(main_window, state)).name())
    for tone, colours in by_tone.items():
        assert len(colours) == 1, f"{tone} states use different colours: {colours}"
    assert len({next(iter(c)) for c in by_tone.values()}) == len(by_tone)


def test_badges_follow_a_live_theme_switch(main_window, qtbot, restore_palette):
    load_containers(main_window, qtbot)
    before = badge_text_colour(badge_for(main_window, "running")).name()
    apply_theme("dark")
    qtbot.wait(10)
    badge = badge_for(main_window, "running")
    assert badge_text_colour(badge).name() != before
    assert_badge_readable(main_window, badge, "Running")


def test_container_detail_badge_uses_the_readable_label(main_window, qtbot):
    stack = find(main_window.window, "containerStack")
    call_qml(stack.parentItem(), "openContainerDetail", "abc")
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    main_window.fake.set("containerDetail", {"id": "abc", "state": "paused"})
    qtbot.wait(10)
    badge = find(main_window.window, "containerDetailStateBadge")
    assert badge.property("text") == "Paused"
    assert_badge_readable(main_window, badge, "Paused")


# --- Status text and destructive buttons ---------------------------------------------

def test_settings_status_text_is_readable(main_window, qtbot, theme):
    window = main_window.window.property("color")
    label = find(main_window.window, "testResultLabel")
    for emit in (lambda: main_window.fake.connectionTestSucceeded.emit("27"),
                 lambda: main_window.fake.connectionTestFailed.emit("nope")):
        emit()
        qtbot.wait(10)
        ratio = contrast(label.property("color"), window)
        assert ratio >= MIN_CONTRAST, f"{label.property('text')}: {ratio:.2f}:1"
    saved = find(main_window.window, "saveStatusLabel")
    assert contrast(saved.property("color"), window) >= MIN_CONTRAST


def images_page(main_window):
    return find(main_window.window, "imageStack").parentItem()


def volumes_page(main_window):
    return find(main_window.window, "volumeStack").parentItem()


def test_delete_buttons_are_danger_coloured_and_readable(main_window, qtbot, theme):
    call_qml(images_page(main_window), "openImageDetail", "sha256:" + "c" * 64, "nginx", False)
    call_qml(volumes_page(main_window), "openVolumeDetail", "data", False)
    qtbot.wait(20)
    names = ["imageDetailDeleteButton", "volumeDetailDeleteButton",
             "deleteImageDialogConfirmButton", "deleteVolumeDialogConfirmButton",
             "imageDetailDeleteDialogConfirmButton", "volumeDetailDeleteDialogConfirmButton"]
    for name in names:
        button = find(main_window.window, name)
        text = button.property("contentItem").property("color")
        ratio = contrast(text, main_window.window.property("color"))
        assert ratio >= MIN_CONTRAST, f"{name} in {theme}: {ratio:.2f}:1"
        assert text.red() > text.green() and text.red() > text.blue(), f"{name} is not red"


# --- No raw colours left -------------------------------------------------------------

def test_no_qml_uses_the_old_raw_colour_tokens():
    offenders = []
    for path in sorted((REPO_ROOT / "manzanillo").glob("*.qml")):
        for n, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r'Colors\.(error|disabled)\b|"(red|green|grey|gray)"', line):
                offenders.append(f"{path.name}:{n}: {line.strip()}")
    assert not offenders, "\n".join(offenders)
