"""Row actions are busy per item, not globally (audit W1, issue #6).

Starting one container, or deleting one image/volume, must mark only that item as
busy: its row (and its detail page) reads "Working..." and the other rows stay usable.
"""
import asyncio

import httpx
import pytest

from api_client import ApiClient
from qml_helpers import call_qml, find, find_item

CONTAINER_A = "a" * 64
CONTAINER_B = "b" * 64


def api_client_with_gated_docker(gate):
    """A real ApiClient whose Docker API answers every request once ``gate`` is set."""
    async def handler(request):
        await gate.wait()
        path = request.url.path
        if path == "/system/df":
            return httpx.Response(200, json={"Volumes": []})
        if path in ("/containers/json", "/images/json"):
            return httpx.Response(200, json=[])
        if path.endswith("/json"):  # a single container's detail
            return httpx.Response(200, json={})
        return httpx.Response(204)

    client = ApiClient("/nonexistent.sock")
    client._client = httpx.AsyncClient(
        transport=httpx.MockTransport(handler), base_url="http://localhost")
    return client


@pytest.mark.parametrize("action, busy_property, argument, busy_key", [
    ("startContainer", "busyContainerIds", CONTAINER_A, CONTAINER_A[:12]),
    ("stopContainer", "busyContainerIds", CONTAINER_A[:12], CONTAINER_A[:12]),
    ("deleteImage", "busyImageIds", "sha256:" + "c" * 64, "sha256:" + "c" * 64),
    ("deleteVolume", "busyVolumeNames", "data", "data"),
])
def test_an_action_marks_only_its_own_item_busy_until_it_finishes(
        qapp, action, busy_property, argument, busy_key):
    async def scenario():
        gate = asyncio.Event()
        client = api_client_with_gated_docker(gate)
        assert getattr(client, busy_property) == []

        getattr(client, action)(argument)
        await asyncio.sleep(0)
        assert getattr(client, busy_property) == [busy_key]

        gate.set()
        for _ in range(50):
            await asyncio.sleep(0)
        assert getattr(client, busy_property) == []
        await client.close()

    asyncio.run(scenario())


# --- QML: only the busy item's row / detail page shows progress -------------------

IMAGE_A, IMAGE_B = "sha256:" + "a" * 8, "sha256:" + "b" * 8


def button_state(window, object_name):
    button = find_item(window, object_name)
    return button.property("text"), button.property("enabled")


def show_page(main_window, qtbot, index):
    find(main_window.window, "navList").setProperty("currentIndex", index)
    qtbot.wait(10)


def test_container_rows_show_working_only_on_the_busy_container(main_window, qtbot):
    fake = main_window.fake
    fake.containers_model.set_containers([
        {"Id": CONTAINER_A, "Names": ["/web"], "State": "exited"},
        {"Id": CONTAINER_B, "Names": ["/db"], "State": "running"},
    ])
    fake.set("busyContainerIds", [CONTAINER_A[:12]])
    qtbot.wait(10)

    w = main_window.window
    assert button_state(w, "quickActionButton_" + CONTAINER_A[:12]) == ("Working...", False)
    assert button_state(w, "quickActionButton_" + CONTAINER_B[:12]) == ("Stop", True)


def test_compose_rows_show_working_only_on_the_busy_container(main_window, qtbot):
    fake = main_window.fake
    fake.set("composeProjects", [{"project": "shop", "services": [{"service": "db", "containers": [
        {"id": "a" * 12, "name": "shop-db-1", "image": "postgres", "status": "Up", "state": "running"},
        {"id": "b" * 12, "name": "shop-db-2", "image": "postgres", "status": "Exited", "state": "exited"},
    ]}]}])
    find(main_window.window, "containersTabBar").setProperty("currentIndex", 1)
    page = find(main_window.window, "containerStack").parentItem()
    call_qml(page, "toggleProjectExpanded", "shop")
    call_qml(page, "toggleServiceExpanded", "shop", "db")
    fake.set("busyContainerIds", ["b" * 12])
    qtbot.wait(10)

    w = main_window.window
    assert button_state(w, "quickActionButton_" + "a" * 12) == ("Stop", True)
    assert button_state(w, "quickActionButton_" + "b" * 12) == ("Working...", False)


def open_container_detail(main_window, qtbot, container_id):
    stack = find(main_window.window, "containerStack")
    call_qml(stack.parentItem(), "openContainerDetail", container_id[:12])
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    main_window.fake.set("containerDetail", {"id": container_id, "name": "web", "state": "exited"})
    qtbot.wait(10)


@pytest.mark.parametrize("busy, expected", [
    ([CONTAINER_A[:12]], ("Working...", False)),
    ([CONTAINER_B[:12]], ("Start", True)),
], ids=["own-container-busy", "other-container-busy"])
def test_container_detail_reflects_only_its_own_busy_state(main_window, qtbot, busy, expected):
    open_container_detail(main_window, qtbot, CONTAINER_A)
    main_window.fake.set("busyContainerIds", busy)
    qtbot.wait(10)
    assert button_state(main_window.window, "startContainerButton") == expected


def test_image_rows_show_working_only_on_the_image_being_deleted(main_window, qtbot):
    fake = main_window.fake
    fake.images_model.set_images([
        {"Id": IMAGE_A, "RepoTags": ["a:latest"], "Containers": 0},
        {"Id": IMAGE_B, "RepoTags": ["b:latest"], "Containers": 0},
    ])
    fake.set("busyImageIds", [IMAGE_A])
    show_page(main_window, qtbot, 1)

    w = main_window.window
    assert button_state(w, "deleteImageButton_" + IMAGE_A) == ("Working...", False)
    assert find_item(w, "tagImageButton_" + IMAGE_A).property("enabled") is False
    assert button_state(w, "deleteImageButton_" + IMAGE_B) == ("Delete", True)
    assert find_item(w, "tagImageButton_" + IMAGE_B).property("enabled") is True


@pytest.mark.parametrize("busy, expected", [
    ([IMAGE_A], ("Working...", False)),
    ([IMAGE_B], ("Delete", True)),
], ids=["own-image-busy", "other-image-busy"])
def test_image_detail_reflects_only_its_own_busy_state(main_window, qtbot, busy, expected):
    stack = find(main_window.window, "imageStack")
    call_qml(stack.parentItem(), "openImageDetail", IMAGE_A, "a:latest", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    main_window.fake.set("busyImageIds", busy)
    qtbot.wait(10)
    assert button_state(main_window.window, "imageDetailDeleteButton") == expected
    assert find_item(main_window.window, "imageDetailTagButton").property("enabled") is expected[1]


def test_volume_rows_show_working_only_on_the_volume_being_deleted(main_window, qtbot):
    fake = main_window.fake
    fake.volumes_model.set_volumes([{"Name": "a"}, {"Name": "b"}])
    fake.set("busyVolumeNames", ["a"])
    show_page(main_window, qtbot, 2)

    w = main_window.window
    assert button_state(w, "deleteVolumeButton_a") == ("Working...", False)
    assert button_state(w, "deleteVolumeButton_b") == ("Delete", True)


@pytest.mark.parametrize("busy, expected", [
    (["a"], ("Working...", False)),
    (["b"], ("Delete", True)),
], ids=["own-volume-busy", "other-volume-busy"])
def test_volume_detail_reflects_only_its_own_busy_state(main_window, qtbot, busy, expected):
    stack = find(main_window.window, "volumeStack")
    call_qml(stack.parentItem(), "openVolumeDetail", "a", False)
    qtbot.waitUntil(lambda: stack.property("depth") == 2)
    main_window.fake.set("busyVolumeNames", busy)
    qtbot.wait(10)
    assert button_state(main_window.window, "volumeDetailDeleteButton") == expected
