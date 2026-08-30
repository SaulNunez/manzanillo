# This Python file uses the following encoding: utf-8
import asyncio
import io
import json
import os
import tarfile
from datetime import datetime

import httpx
from PySide6.QtCore import (
    Property,
    QAbstractListModel,
    QModelIndex,
    QObject,
    QSettings,
    QSortFilterProxyModel,
    Qt,
    Signal,
    Slot,
)

SETTINGS_ORG = "manzanillo"
SETTINGS_APP = "manzanillo"
SOCKET_PATH_SETTING_KEY = "socketPath"


def _error_message(error: Exception) -> str:
    if isinstance(error, httpx.HTTPStatusError):
        try:
            detail = error.response.json().get("message")
            if detail:
                return detail
        except ValueError:
            pass
    return str(error) or type(error).__name__


def _format_timestamp(value) -> str:
    if not value:
        return ""
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return str(value)


def _build_context_tar(context_dir: str) -> bytes:
    # Builds the whole context into memory rather than streaming it, which is
    # simple but means very large build contexts will use proportional memory.
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        tar.add(context_dir, arcname=".")
    return buffer.getvalue()


class ImageListModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    TagsRole = Qt.UserRole + 2
    SizeRole = Qt.UserRole + 3
    CreatedRole = Qt.UserRole + 4
    InUseRole = Qt.UserRole + 5

    def __init__(self, parent=None):
        super().__init__(parent)
        self._images = []

    def roleNames(self):
        return {
            self.IdRole: b"imageId",
            self.TagsRole: b"tags",
            self.SizeRole: b"size",
            self.CreatedRole: b"created",
            self.InUseRole: b"inUse",
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
        if role == self.InUseRole:
            return image.get("Containers", 0) > 0
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


class ContainerFilterProxyModel(QSortFilterProxyModel):
    filterTextChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._filter_text = ""

    @Property(str, notify=filterTextChanged)
    def filterText(self):
        return self._filter_text

    @Slot(str)
    def setFilterText(self, value: str):
        value = value or ""
        if value != self._filter_text:
            self._filter_text = value
            self.filterTextChanged.emit(value)
            self.invalidateFilter()

    def filterAcceptsRow(self, source_row, source_parent):
        if not self._filter_text:
            return True
        text = self._filter_text.lower()
        model = self.sourceModel()
        index = model.index(source_row, 0, source_parent)
        names = (model.data(index, ContainerListModel.NamesRole) or "").lower()
        image = (model.data(index, ContainerListModel.ImageRole) or "").lower()
        return text in names or text in image


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
    InUseRole = Qt.UserRole + 5

    def __init__(self, parent=None):
        super().__init__(parent)
        self._volumes = []

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.DriverRole: b"driver",
            self.MountpointRole: b"mountpoint",
            self.CreatedRole: b"created",
            self.InUseRole: b"inUse",
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
        if role == self.InUseRole:
            return (volume.get("UsageData") or {}).get("RefCount", 0) > 0
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

    containerActionBusyChanged = Signal()
    containerActionErrorOccurred = Signal(str)

    imagesErrorOccurred = Signal(str)
    imagesBusyChanged = Signal()

    imageActionBusyChanged = Signal()
    imageActionErrorOccurred = Signal(str)

    volumesErrorOccurred = Signal(str)
    volumesBusyChanged = Signal()

    volumeActionBusyChanged = Signal()
    volumeActionErrorOccurred = Signal(str)

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
        self._container_action_busy = False
        self._volume_action_busy = False
        self._image_action_busy = False
        self._containers_model = ContainerListModel(self)
        self._containers_filter_model = ContainerFilterProxyModel(self)
        self._containers_filter_model.setSourceModel(self._containers_model)
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
    def filteredContainersModel(self):
        return self._containers_filter_model

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

    @Property(bool, notify=containerActionBusyChanged)
    def containerActionBusy(self):
        return self._container_action_busy

    def _set_container_action_busy(self, value: bool):
        if self._container_action_busy != value:
            self._container_action_busy = value
            self.containerActionBusyChanged.emit()

    @Slot(str)
    def startContainer(self, container_id: str):
        asyncio.ensure_future(self._container_action(container_id, "start"))

    @Slot(str)
    def stopContainer(self, container_id: str):
        asyncio.ensure_future(self._container_action(container_id, "stop"))

    async def _container_action(self, container_id: str, action: str):
        self._set_container_action_busy(True)
        try:
            # Docker's default stop grace period (SIGTERM, then SIGKILL after 10s)
            # can exceed the client's normal 5s timeout, so allow more time here.
            response = await self._client.post(f"/containers/{container_id}/{action}", timeout=20.0)
            response.raise_for_status()
            await self._fetch_container_detail(container_id)
            await self._fetch_containers()
        except (httpx.HTTPError, OSError) as error:
            self.containerActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_container_action_busy(False)

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

    @Property(bool, notify=imageActionBusyChanged)
    def imageActionBusy(self):
        return self._image_action_busy

    def _set_image_action_busy(self, value: bool):
        if self._image_action_busy != value:
            self._image_action_busy = value
            self.imageActionBusyChanged.emit()

    @Slot(str)
    def deleteImage(self, image_id: str):
        asyncio.ensure_future(self._delete_image(image_id))

    async def _delete_image(self, image_id: str):
        self._set_image_action_busy(True)
        try:
            response = await self._client.delete(f"/images/{image_id}")
            response.raise_for_status()
            await self._fetch_images()
        except (httpx.HTTPError, OSError) as error:
            self.imageActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_image_action_busy(False)

    @Slot(str)
    def pullImage(self, reference: str):
        asyncio.ensure_future(self._pull_image(reference))

    async def _pull_image(self, reference: str):
        self._set_image_action_busy(True)
        try:
            # Pulling has no fixed time budget - it depends on image size and network
            # speed - so the request timeout is disabled rather than reusing the
            # client's normal 5s default.
            async with self._client.stream(
                "POST", "/images/create", params={"fromImage": reference}, timeout=None
            ) as response:
                response.raise_for_status()
                pull_error = None
                async for line in response.aiter_lines():
                    if not line:
                        continue
                    try:
                        payload = json.loads(line)
                    except ValueError:
                        continue
                    if "error" in payload:
                        pull_error = payload["error"]
                if pull_error:
                    raise RuntimeError(pull_error)
            await self._fetch_images()
        except (httpx.HTTPError, OSError, RuntimeError) as error:
            self.imageActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_image_action_busy(False)

    @Slot(str, str, str)
    def tagImage(self, image_id: str, repository: str, tag: str):
        asyncio.ensure_future(self._tag_image(image_id, repository, tag))

    async def _tag_image(self, image_id: str, repository: str, tag: str):
        self._set_image_action_busy(True)
        try:
            params = {"repo": repository}
            if tag:
                params["tag"] = tag
            response = await self._client.post(f"/images/{image_id}/tag", params=params)
            response.raise_for_status()
            await self._fetch_images()
        except (httpx.HTTPError, OSError) as error:
            self.imageActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_image_action_busy(False)

    @Slot(str, str, str)
    def buildImage(self, context_path: str, dockerfile: str, tag: str):
        asyncio.ensure_future(self._build_image(context_path, dockerfile, tag))

    async def _build_image(self, context_path: str, dockerfile: str, tag: str):
        self._set_image_action_busy(True)
        try:
            context_path = context_path.strip()
            dockerfile = dockerfile.strip() or "Dockerfile"
            if not os.path.isdir(context_path):
                raise RuntimeError(f"Not a directory: {context_path}")
            if not os.path.isfile(os.path.join(context_path, dockerfile)):
                raise RuntimeError(f"Dockerfile not found: {os.path.join(context_path, dockerfile)}")

            # Tarring the context directory is blocking I/O, so it runs off the Qt
            # event loop thread to avoid freezing the UI while it's built.
            loop = asyncio.get_event_loop()
            context_tar = await loop.run_in_executor(None, _build_context_tar, context_path)

            params = {"dockerfile": dockerfile}
            if tag:
                params["t"] = tag

            # As with pulling, a build has no fixed time budget, so its timeout is
            # disabled rather than reusing the client's normal 5s default.
            async with self._client.stream(
                "POST",
                "/build",
                params=params,
                content=context_tar,
                headers={"Content-Type": "application/x-tar"},
                timeout=None,
            ) as response:
                response.raise_for_status()
                build_error = None
                async for line in response.aiter_lines():
                    if not line:
                        continue
                    try:
                        payload = json.loads(line)
                    except ValueError:
                        continue
                    if "error" in payload:
                        build_error = payload["error"]
                if build_error:
                    raise RuntimeError(build_error)
            await self._fetch_images()
        except (httpx.HTTPError, OSError, RuntimeError) as error:
            self.imageActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_image_action_busy(False)

    @Slot()
    def fetchVolumes(self):
        asyncio.ensure_future(self._fetch_volumes())

    async def _fetch_volumes(self):
        self._set_volumes_busy(True)
        try:
            # /system/df (rather than /volumes) is used because it's the only Docker
            # Engine endpoint that reports UsageData.RefCount, which is how we know
            # whether a volume is currently attached to any container.
            response = await self._client.get("/system/df", params={"type": "volume"})
            response.raise_for_status()
            self._volumes_model.set_volumes(response.json().get("Volumes") or [])
        except (httpx.HTTPError, OSError) as error:
            self.volumesErrorOccurred.emit(str(error))
        finally:
            self._set_volumes_busy(False)

    @Property(bool, notify=volumeActionBusyChanged)
    def volumeActionBusy(self):
        return self._volume_action_busy

    def _set_volume_action_busy(self, value: bool):
        if self._volume_action_busy != value:
            self._volume_action_busy = value
            self.volumeActionBusyChanged.emit()

    @Slot(str)
    def deleteVolume(self, name: str):
        asyncio.ensure_future(self._delete_volume(name))

    async def _delete_volume(self, name: str):
        self._set_volume_action_busy(True)
        try:
            response = await self._client.delete(f"/volumes/{name}")
            response.raise_for_status()
            await self._fetch_volumes()
        except (httpx.HTTPError, OSError) as error:
            self.volumeActionErrorOccurred.emit(_error_message(error))
        finally:
            self._set_volume_action_busy(False)

    async def close(self):
        await self._client.aclose()
