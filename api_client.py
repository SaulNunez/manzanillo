# This Python file uses the following encoding: utf-8
import asyncio
from datetime import datetime

import httpx
from PySide6.QtCore import (
    Property,
    QAbstractListModel,
    QModelIndex,
    QObject,
    QSettings,
    Qt,
    Signal,
    Slot,
)

SETTINGS_ORG = "manzanillo"
SETTINGS_APP = "manzanillo"
SOCKET_PATH_SETTING_KEY = "socketPath"


def _format_timestamp(value) -> str:
    if not value:
        return ""
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return str(value)


class ImageListModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    TagsRole = Qt.UserRole + 2
    SizeRole = Qt.UserRole + 3
    CreatedRole = Qt.UserRole + 4

    def __init__(self, parent=None):
        super().__init__(parent)
        self._images = []

    def roleNames(self):
        return {
            self.IdRole: b"imageId",
            self.TagsRole: b"tags",
            self.SizeRole: b"size",
            self.CreatedRole: b"created",
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._images)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._images)):
            return None

        image = self._images[index.row()]
        if role == self.IdRole:
            return image.get("Id", "")
        if role == self.TagsRole:
            tags = image.get("RepoTags") or []
            return ", ".join(tags) if tags else "<none>"
        if role == self.SizeRole:
            return self._format_size(image.get("Size", 0))
        if role == self.CreatedRole:
            created = image.get("Created")
            return datetime.fromtimestamp(created).strftime("%Y-%m-%d %H:%M") if created else ""
        return None

    def set_images(self, images: list[dict]):
        self.beginResetModel()
        self._images = images
        self.endResetModel()

    @staticmethod
    def _format_size(num_bytes) -> str:
        size = float(num_bytes)
        for unit in ("B", "KB", "MB", "GB", "TB"):
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} PB"


class ContainerListModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    NamesRole = Qt.UserRole + 2
    ImageRole = Qt.UserRole + 3
    StatusRole = Qt.UserRole + 4
    StateRole = Qt.UserRole + 5

    def __init__(self, parent=None):
        super().__init__(parent)
        self._containers = []

    def roleNames(self):
        return {
            self.IdRole: b"containerId",
            self.NamesRole: b"names",
            self.ImageRole: b"image",
            self.StatusRole: b"status",
            self.StateRole: b"state",
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._containers)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._containers)):
            return None

        container = self._containers[index.row()]
        if role == self.IdRole:
            return container.get("Id", "")[:12]
        if role == self.NamesRole:
            return _container_display_name(container)
        if role == self.ImageRole:
            return container.get("Image", "")
        if role == self.StatusRole:
            return container.get("Status", "")
        if role == self.StateRole:
            return container.get("State", "")
        return None

    def set_containers(self, containers: list[dict]):
        self.beginResetModel()
        self._containers = containers
        self.endResetModel()


COMPOSE_PROJECT_LABEL = "com.docker.compose.project"
COMPOSE_SERVICE_LABEL = "com.docker.compose.service"


def _container_display_name(container: dict) -> str:
    names = container.get("Names") or []
    return ", ".join(name.lstrip("/") for name in names) or container.get("Id", "")[:12]


def _container_summary(container: dict) -> dict:
    return {
        "id": container.get("Id", "")[:12],
        "name": _container_display_name(container),
        "image": container.get("Image", ""),
        "status": container.get("Status", ""),
        "state": container.get("State", ""),
    }


def _format_ports(network_settings: dict) -> list[str]:
    ports = network_settings.get("Ports") or {}
    result = []
    for container_port, bindings in sorted(ports.items()):
        if not bindings:
            result.append(f"{container_port} (not published)")
            continue
        for binding in bindings:
            host_ip = binding.get("HostIp") or "0.0.0.0"
            host_port = binding.get("HostPort", "")
            result.append(f"{host_ip}:{host_port} -> {container_port}")
    return result


def _format_mounts(mounts: list[dict]) -> list[str]:
    result = []
    for mount in mounts or []:
        mode = mount.get("Mode") or ("rw" if mount.get("RW", True) else "ro")
        result.append(f"{mount.get('Source', '')} -> {mount.get('Destination', '')} ({mode})")
    return result


def _summarize_container_detail(data: dict) -> dict:
    config = data.get("Config") or {}
    state = data.get("State") or {}
    host_config = data.get("HostConfig") or {}
    network_settings = data.get("NetworkSettings") or {}
    networks = network_settings.get("Networks") or {}

    command_parts = (config.get("Entrypoint") or []) + (config.get("Cmd") or [])

    return {
        "id": data.get("Id", ""),
        "name": (data.get("Name") or "").lstrip("/"),
        "image": config.get("Image", ""),
        "state": state.get("Status", ""),
        "startedAt": _format_timestamp(state.get("StartedAt")),
        "created": _format_timestamp(data.get("Created")),
        "command": " ".join(command_parts),
        "workingDir": config.get("WorkingDir", ""),
        "restartPolicy": (host_config.get("RestartPolicy") or {}).get("Name", ""),
        "ports": _format_ports(network_settings),
        "mounts": _format_mounts(data.get("Mounts")),
        "env": config.get("Env") or [],
        "networks": [
            f"{name}: {info.get('IPAddress') or '(no IP)'}" for name, info in sorted(networks.items())
        ],
    }


def _group_compose_projects(containers: list[dict]) -> list[dict]:
    projects: dict[str, dict[str, list[dict]]] = {}
    for container in containers:
        labels = container.get("Labels") or {}
        project = labels.get(COMPOSE_PROJECT_LABEL)
        service = labels.get(COMPOSE_SERVICE_LABEL)
        if not project or not service:
            continue
        projects.setdefault(project, {}).setdefault(service, []).append(container)

    return [
        {
            "project": project_name,
            "services": [
                {
                    "service": service_name,
                    "containers": [_container_summary(c) for c in services[service_name]],
                }
                for service_name in sorted(services)
            ],
        }
        for project_name, services in sorted(projects.items())
    ]


class VolumeListModel(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    DriverRole = Qt.UserRole + 2
    MountpointRole = Qt.UserRole + 3
    CreatedRole = Qt.UserRole + 4

    def __init__(self, parent=None):
        super().__init__(parent)
        self._volumes = []

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.DriverRole: b"driver",
            self.MountpointRole: b"mountpoint",
            self.CreatedRole: b"created",
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._volumes)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._volumes)):
            return None

        volume = self._volumes[index.row()]
        if role == self.NameRole:
            return volume.get("Name", "")
        if role == self.DriverRole:
            return volume.get("Driver", "")
        if role == self.MountpointRole:
            return volume.get("Mountpoint", "")
        if role == self.CreatedRole:
            return _format_timestamp(volume.get("CreatedAt"))
        return None

    def set_volumes(self, volumes: list[dict]):
        self.beginResetModel()
        self._volumes = volumes
        self.endResetModel()


class ApiClient(QObject):
    containersErrorOccurred = Signal(str)
    containersBusyChanged = Signal()
    composeProjectsChanged = Signal()

    containerDetailChanged = Signal()
    containerDetailBusyChanged = Signal()
    containerDetailErrorOccurred = Signal(str)

    imagesErrorOccurred = Signal(str)
    imagesBusyChanged = Signal()

    volumesErrorOccurred = Signal(str)
    volumesBusyChanged = Signal()

    socketPathChanged = Signal(str)
    connectionTestBusyChanged = Signal()
    connectionTestSucceeded = Signal(str)
    connectionTestFailed = Signal(str)

    def __init__(self, socket_path: str, base_url: str = "http://localhost", parent=None):
        super().__init__(parent)
        self._base_url = base_url
        self._socket_path = socket_path
        self._client = self._build_client(socket_path)
        self._containers_busy = False
        self._images_busy = False
        self._volumes_busy = False
        self._connection_test_busy = False
        self._container_detail_busy = False
        self._containers_model = ContainerListModel(self)
        self._images_model = ImageListModel(self)
        self._volumes_model = VolumeListModel(self)
        self._compose_projects = []
        self._container_detail = {}

    def _build_client(self, socket_path: str) -> httpx.AsyncClient:
        transport = httpx.AsyncHTTPTransport(uds=socket_path)
        return httpx.AsyncClient(transport=transport, base_url=self._base_url, timeout=5.0)

    @Property(str, notify=socketPathChanged)
    def socketPath(self):
        return self._socket_path

    @Slot(str)
    def setSocketPath(self, path: str):
        asyncio.ensure_future(self._set_socket_path(path))

    async def _set_socket_path(self, path: str):
        path = path.strip()
        if not path or path == self._socket_path:
            return

        old_client = self._client
        self._client = self._build_client(path)
        self._socket_path = path

        settings = QSettings(SETTINGS_ORG, SETTINGS_APP)
        settings.setValue(SOCKET_PATH_SETTING_KEY, path)

        self.socketPathChanged.emit(path)
        asyncio.ensure_future(self._fetch_containers())
        asyncio.ensure_future(self._fetch_images())
        asyncio.ensure_future(self._fetch_volumes())

        await old_client.aclose()

    @Property(bool, notify=connectionTestBusyChanged)
    def connectionTestBusy(self):
        return self._connection_test_busy

    def _set_connection_test_busy(self, value: bool):
        if self._connection_test_busy != value:
            self._connection_test_busy = value
            self.connectionTestBusyChanged.emit()

    @Slot()
    def testConnection(self):
        asyncio.ensure_future(self._test_connection())

    async def _test_connection(self):
        self._set_connection_test_busy(True)
        try:
            response = await self._client.get("/version")
            response.raise_for_status()
            self.connectionTestSucceeded.emit(response.json().get("Version", "unknown"))
        except (httpx.HTTPError, OSError) as error:
            self.connectionTestFailed.emit(str(error))
        finally:
            self._set_connection_test_busy(False)

    @Property(bool, notify=containersBusyChanged)
    def containersBusy(self):
        return self._containers_busy

    def _set_containers_busy(self, value: bool):
        if self._containers_busy != value:
            self._containers_busy = value
            self.containersBusyChanged.emit()

    @Property(bool, notify=imagesBusyChanged)
    def imagesBusy(self):
        return self._images_busy

    def _set_images_busy(self, value: bool):
        if self._images_busy != value:
            self._images_busy = value
            self.imagesBusyChanged.emit()

    @Property(bool, notify=volumesBusyChanged)
    def volumesBusy(self):
        return self._volumes_busy

    def _set_volumes_busy(self, value: bool):
        if self._volumes_busy != value:
            self._volumes_busy = value
            self.volumesBusyChanged.emit()

    @Property(QObject, constant=True)
    def containersModel(self):
        return self._containers_model

    @Property(QObject, constant=True)
    def imagesModel(self):
        return self._images_model

    @Property(QObject, constant=True)
    def volumesModel(self):
        return self._volumes_model

    @Property("QVariant", notify=composeProjectsChanged)
    def composeProjects(self):
        return self._compose_projects

    @Slot()
    def fetchContainers(self):
        asyncio.ensure_future(self._fetch_containers())

    async def _fetch_containers(self):
        self._set_containers_busy(True)
        try:
            response = await self._client.get("/containers/json", params={"all": "true"})
            response.raise_for_status()
            containers = response.json()
            self._containers_model.set_containers(containers)
            self._compose_projects = _group_compose_projects(containers)
            self.composeProjectsChanged.emit()
        except (httpx.HTTPError, OSError) as error:
            self.containersErrorOccurred.emit(str(error))
        finally:
            self._set_containers_busy(False)

    @Property(bool, notify=containerDetailBusyChanged)
    def containerDetailBusy(self):
        return self._container_detail_busy

    def _set_container_detail_busy(self, value: bool):
        if self._container_detail_busy != value:
            self._container_detail_busy = value
            self.containerDetailBusyChanged.emit()

    @Property("QVariant", notify=containerDetailChanged)
    def containerDetail(self):
        return self._container_detail

    @Slot(str)
    def fetchContainerDetail(self, container_id: str):
        asyncio.ensure_future(self._fetch_container_detail(container_id))

    async def _fetch_container_detail(self, container_id: str):
        self._set_container_detail_busy(True)
        try:
            response = await self._client.get(f"/containers/{container_id}/json")
            response.raise_for_status()
            self._container_detail = _summarize_container_detail(response.json())
            self.containerDetailChanged.emit()
        except (httpx.HTTPError, OSError) as error:
            self.containerDetailErrorOccurred.emit(str(error))
        finally:
            self._set_container_detail_busy(False)

    @Slot()
    def fetchImages(self):
        asyncio.ensure_future(self._fetch_images())

    async def _fetch_images(self):
        self._set_images_busy(True)
        try:
            response = await self._client.get("/images/json")
            response.raise_for_status()
            self._images_model.set_images(response.json())
        except (httpx.HTTPError, OSError) as error:
            self.imagesErrorOccurred.emit(str(error))
        finally:
            self._set_images_busy(False)

    @Slot()
    def fetchVolumes(self):
        asyncio.ensure_future(self._fetch_volumes())

    async def _fetch_volumes(self):
        self._set_volumes_busy(True)
        try:
            response = await self._client.get("/volumes")
            response.raise_for_status()
            self._volumes_model.set_volumes(response.json().get("Volumes") or [])
        except (httpx.HTTPError, OSError) as error:
            self.volumesErrorOccurred.emit(str(error))
        finally:
            self._set_volumes_busy(False)

    async def close(self):
        await self._client.aclose()
