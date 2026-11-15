"""Unit tests for the list models and Docker-JSON summarisers in api_client.py.

These read data back through the same role names QML delegates use, so a
renamed role breaks a test here as well as the UI.
"""
from api_client import (
    ContainerFilterProxyModel,
    ContainerListModel,
    ImageListModel,
    VolumeListModel,
    _format_ports,
    _group_compose_projects,
)


def rows(model):
    """Return every row of a list model as {roleName: value} dicts."""
    names = {role: bytes(name).decode() for role, name in model.roleNames().items()}
    return [
        {name: model.data(model.index(r, 0), role) for role, name in names.items()}
        for r in range(model.rowCount())
    ]


def test_image_model_exposes_short_id_tags_and_size():
    model = ImageListModel()
    model.set_images([
        {"Id": "sha256:0123456789abcdef", "RepoTags": ["nginx:latest", "web:1"],
         "Size": 2048, "Created": 0, "Containers": 1},
    ])
    [row] = rows(model)
    assert row["tags"] == "nginx:latest, web:1"
    assert row["size"] == "2.0 KB"
    assert row["inUse"] is True


def test_container_filter_matches_name_or_image_case_insensitively():
    source = ContainerListModel()
    source.set_containers([
        {"Id": "a" * 64, "Names": ["/web"], "Image": "nginx", "Status": "Up", "State": "running"},
        {"Id": "b" * 64, "Names": ["/db"], "Image": "postgres", "Status": "Exited", "State": "exited"},
    ])
    proxy = ContainerFilterProxyModel()
    proxy.setSourceModel(source)

    proxy.setFilterText("POST")
    assert [r["names"] for r in rows(proxy)] == ["db"]

    proxy.setFilterText("")
    assert len(rows(proxy)) == 2


def test_volume_model_rows():
    model = VolumeListModel()
    model.set_volumes([{"Name": "data", "Driver": "local", "Mountpoint": "/var/lib/x"}])
    [row] = rows(model)
    assert (row["name"], row["driver"], row["mountpoint"]) == ("data", "local", "/var/lib/x")


def test_format_ports_lists_published_and_unpublished():
    ports = {"Ports": {"80/tcp": [{"HostIp": "", "HostPort": "8080"}], "443/tcp": None}}
    assert _format_ports(ports) == ["443/tcp (not published)", "0.0.0.0:8080 -> 80/tcp"]


def test_group_compose_projects_groups_by_project_then_service_and_skips_loose_containers():
    def container(name, project=None, service=None):
        labels = {}
        if project:
            labels = {"com.docker.compose.project": project, "com.docker.compose.service": service}
        return {"Id": name * 12, "Names": ["/" + name], "Labels": labels}

    grouped = _group_compose_projects([
        container("b", "shop", "web"), container("a", "shop", "db"), container("loose"),
    ])

    assert [p["project"] for p in grouped] == ["shop"]
    assert [s["service"] for s in grouped[0]["services"]] == ["db", "web"]
    assert grouped[0]["services"][1]["containers"][0]["name"] == "b"
