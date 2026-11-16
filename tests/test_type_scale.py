"""Type scale based on the system font (#2, audit C2/W12).

Body text equals the system font size and the other steps are ratios of it, in
points, so changing the OS font size (simulated here with QGuiApplication.setFont,
which is what the platform theme does) rescales every piece of text live.
Headings use DemiBold; row titles use Medium.
"""
import pytest
from PySide6.QtGui import QFont, QGuiApplication

from qml_helpers import find, find_item, qml_eval

LARGE = 14.0  # a "Large" desktop font setting, in points


@pytest.fixture
def system_font(qapp):
    """Return ``use(point_size)``, which sets the application font; restored afterwards."""
    previous = QGuiApplication.font()

    def use(point_size):
        font = QFont(previous)
        font.setPointSizeF(point_size)
        QGuiApplication.setFont(font)

    yield use
    QGuiApplication.setFont(previous)


@pytest.fixture
def scale(load_qml, tmp_path):
    probe = tmp_path / "ScaleProbe.qml"
    probe.write_text(
        "import QtQuick\nimport manzanillo\nQtObject {\n"
        + "".join(f"    property real {s}: TypeScale.{s}\n"
                  for s in ("title", "heading", "body", "caption", "monospace"))
        + "}\n")
    return load_qml(str(probe)).window


def test_body_is_the_system_font_size(system_font, scale, qtbot):
    system_font(10.0)
    qtbot.waitUntil(lambda: scale.property("body") == pytest.approx(10.0))
    system_font(LARGE)
    qtbot.waitUntil(lambda: scale.property("body") == pytest.approx(LARGE))


def test_steps_are_ordered_ratios_of_body(system_font, scale, qtbot):
    system_font(LARGE)
    qtbot.waitUntil(lambda: scale.property("body") == pytest.approx(LARGE))
    p = scale.property
    assert p("title") > p("heading") > p("body") > p("caption")
    # Log text is at least the caption size.
    assert p("monospace") >= p("caption")
    # The ratios hold at any base size (old scale: 20/16/14/12 px).
    assert p("title") == pytest.approx(LARGE * 20 / 14)
    assert p("caption") == pytest.approx(LARGE * 12 / 14)


def text_items(root):
    """Every visible Text/Label-like item under ``root`` (anything with a font + text)."""
    pending = [root.contentItem() if hasattr(root, "contentItem") else root]
    found = []
    while pending:
        item = pending.pop()
        pending.extend(item.childItems())
        meta = item.metaObject()
        if (meta.indexOfProperty("font") >= 0 and meta.indexOfProperty("text") >= 0
                and meta.indexOfProperty("contentHeight") >= 0 and item.isVisible()
                and item.property("text")):
            found.append(item)
    return found


def visit_every_page(window, qtbot):
    nav = find(window, "navList")
    for index in range(nav.property("count")):
        nav.setProperty("currentIndex", index)
        qtbot.wait(10)


def test_changing_the_system_font_rescales_all_text(system_font, load_qml, qtbot):
    system_font(10.0)
    app = load_qml(("manzanillo", "Main"))
    app.fake.containers_model.set_containers(
        [{"Id": "a" * 64, "Names": ["/web"], "State": "running", "Image": "nginx"}])
    nav = find(app.window, "navList")
    before = {}
    for index in range(nav.property("count")):
        nav.setProperty("currentIndex", index)
        qtbot.wait(10)
        for item in text_items(app.window):
            before[id(item)] = (item, item.property("font").pointSizeF())

    system_font(20.0)
    qtbot.wait(10)
    for item, size in before.values():
        assert size > 0, f"{item.property('text')!r} uses a fixed pixel size"
        after = item.property("font").pointSizeF()
        assert after == pytest.approx(size * 2), (
            f"{item.property('text')!r} did not follow the system font ({size} -> {after})")


def clipped_text(window):
    """Visible text items squeezed smaller than their text (that don't elide or wrap)."""
    bad = []
    for item in text_items(window):
        if item.property("height") + 0.5 < item.property("contentHeight"):
            bad.append((item.property("text"), "height", item.property("height"),
                        item.property("contentHeight")))
        # Enum properties aren't readable from Python; ask QML (3 == Text.ElideNone).
        elided = bool(qml_eval(item, "elide !== undefined && elide !== 3"))
        wraps = bool(qml_eval(item, "wrapMode !== undefined && wrapMode !== 0"))
        if not (elided or wraps) and item.property("width") + 0.5 < item.property("contentWidth"):
            bad.append((item.property("text"), "width", item.property("width"),
                        item.property("contentWidth")))
    return bad


def test_large_font_does_not_clip_list_detail_or_settings_text(system_font, load_qml, qtbot):
    system_font(LARGE)
    app = load_qml(("manzanillo", "Main"))
    fake = app.fake
    fake.containers_model.set_containers(
        [{"Id": "a" * 64, "Names": ["/web"], "State": "running", "Image": "nginx",
          "Status": "Up 2 hours"}])
    fake.images_model.set_images([{"Id": "sha256:" + "c" * 64, "RepoTags": ["nginx:latest"],
                                   "Size": 1000000, "Created": 1700000000}])
    fake.volumes_model.set_volumes([{"Name": "data", "Driver": "local", "Mountpoint": "/x"}])
    nav = find(app.window, "navList")
    for index in range(nav.property("count")):
        nav.setProperty("currentIndex", index)
        qtbot.wait(20)
        assert clipped_text(app.window) == [], f"page {index}"

    nav.setProperty("currentIndex", 0)
    fake.set("containerDetail", {"id": "a" * 12, "name": "web", "image": "nginx",
                                 "state": "running", "created": "2024-01-01", "ports": ["80/tcp"]})
    find_item(app.window, "containerRow_" + "a" * 12).activated.emit()
    qtbot.waitUntil(lambda: find(app.window, "containerStack").property("depth") == 2)
    qtbot.wait(400)
    assert clipped_text(app.window) == [], "container detail"


def label_with_text(root, text):
    for item in text_items(root):
        if item.property("text") == text:
            return item
    raise AssertionError(f"no visible text {text!r}")


def weight(item):
    return item.property("font").weight()


def test_row_titles_are_medium_weight(main_window, qtbot):
    main_window.fake.containers_model.set_containers(
        [{"Id": "a" * 64, "Names": ["/web"], "State": "running", "Image": "nginx"}])
    qtbot.wait(10)
    row = find_item(main_window.window, "containerRow_" + "a" * 12)
    assert weight(label_with_text(row, "web")) == QFont.Weight.Medium


def test_headings_are_demibold(main_window, qtbot):
    fake = main_window.fake
    fake.set("composeProjects", [{"project": "shop", "services": [{"service": "db", "containers": [
        {"id": "b" * 12, "name": "shop-db-1", "image": "postgres", "status": "Up", "state": "exited"}]}]}])
    find(main_window.window, "containersTabBar").setProperty("currentIndex", 1)
    qtbot.wait(10)
    project = label_with_text(find(main_window.window, "composeProjectsList"), "shop")
    assert weight(project) == QFont.Weight.DemiBold
    assert project.property("font").pointSizeF() == pytest.approx(
        QGuiApplication.font().pointSizeF() * 16 / 14)

    find(main_window.window, "navList").setProperty("currentIndex", 3)  # Settings
    qtbot.wait(10)
    for heading in ("Docker socket path", "Accessibility"):
        assert weight(label_with_text(main_window.window, heading)) == QFont.Weight.DemiBold
