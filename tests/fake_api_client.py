"""A Docker-free stand-in for api_client.ApiClient, for QML tests.

It has the same properties, signals and slots as ApiClient (test_fake_api_client.py
enforces that), but:

- Slots do nothing except record the call in ``fake.calls`` as ``(slotName, *args)``.
  Assert on that to check the QML called the backend.
- Scalar/QVariant properties are read-only from QML, as in the real client. Drive
  them from a test with ``fake.set("containerDetail", {...})``, which stores the
  value and emits the matching notify signal.
- The list models are the real models from api_client.py; fill them with
  ``fake.containers_model.set_containers([...])``, ``fake.images_model.set_images``,
  ``fake.volumes_model.set_volumes`` using Docker-API-shaped dicts.
- Error signals (``containersErrorOccurred`` etc.) are plain signals: call
  ``fake.containersErrorOccurred.emit("boom")`` to simulate a failure.
"""
from PySide6.QtCore import Property, QObject, Signal, Slot

from api_client import (
    ContainerFilterProxyModel,
    ContainerListModel,
    ImageListModel,
    VolumeListModel,
)


def _state(name, type_, notify):
    """A read-only Qt property backed by self._state[name]."""
    return Property(type_, lambda self: self._state[name], notify=notify)


class FakeApiClient(QObject):
    # --- signals (same names/signatures as ApiClient) ---
    containersErrorOccurred = Signal(str)
    containersBusyChanged = Signal()
    composeProjectsChanged = Signal()

    containerDetailChanged = Signal()
    containerDetailBusyChanged = Signal()
    containerDetailErrorOccurred = Signal(str)

    containerActionBusyChanged = Signal()
    containerActionErrorOccurred = Signal(str)

    containerLogsChanged = Signal()
    containerLogsStreamingChanged = Signal()
    containerLogsErrorOccurred = Signal(str)

    imagesErrorOccurred = Signal(str)
    imagesBusyChanged = Signal()

    imageDetailChanged = Signal()
    imageDetailBusyChanged = Signal()
    imageDetailErrorOccurred = Signal(str)

    imageActionBusyChanged = Signal()
    imageActionErrorOccurred = Signal(str)
    buildLogChanged = Signal()

    volumesErrorOccurred = Signal(str)
    volumesBusyChanged = Signal()

    volumeDetailChanged = Signal()
    volumeDetailBusyChanged = Signal()
    volumeDetailErrorOccurred = Signal(str)

    volumeActionBusyChanged = Signal()
    volumeActionErrorOccurred = Signal(str)

    socketPathChanged = Signal(str)
    connectionTestBusyChanged = Signal()
    connectionTestSucceeded = Signal(str)
    connectionTestFailed = Signal(str)

    # --- state properties: name -> (Qt type, notify signal, default) ---
    _STATE = {
        "socketPath": (str, socketPathChanged, "/var/run/docker.sock"),
        "connectionTestBusy": (bool, connectionTestBusyChanged, False),
        "containersBusy": (bool, containersBusyChanged, False),
        "imagesBusy": (bool, imagesBusyChanged, False),
        "volumesBusy": (bool, volumesBusyChanged, False),
        "composeProjects": ("QVariant", composeProjectsChanged, []),
        "containerDetail": ("QVariant", containerDetailChanged, {}),
        "containerDetailBusy": (bool, containerDetailBusyChanged, False),
        "containerActionBusy": (bool, containerActionBusyChanged, False),
        "containerLogs": (str, containerLogsChanged, ""),
        "containerLogsStreaming": (bool, containerLogsStreamingChanged, False),
        "imageDetail": ("QVariant", imageDetailChanged, {}),
        "imageDetailBusy": (bool, imageDetailBusyChanged, False),
        "imageActionBusy": (bool, imageActionBusyChanged, False),
        "buildLog": (str, buildLogChanged, ""),
        "volumeDetail": ("QVariant", volumeDetailChanged, {}),
        "volumeDetailBusy": (bool, volumeDetailBusyChanged, False),
        "volumeActionBusy": (bool, volumeActionBusyChanged, False),
    }
    for _name, (_type, _notify, _default) in _STATE.items():
        locals()[_name] = _state(_name, _type, _notify)
    del _name, _type, _notify, _default

    def __init__(self, parent=None):
        super().__init__(parent)
        self._state = {name: default for name, (_, _, default) in self._STATE.items()}
        self.calls = []
        self.containers_model = ContainerListModel(self)
        self.filtered_containers_model = ContainerFilterProxyModel(self)
        self.filtered_containers_model.setSourceModel(self.containers_model)
        self.images_model = ImageListModel(self)
        self.volumes_model = VolumeListModel(self)

    def set(self, name, value):
        """Set a state property from a test and emit its notify signal."""
        self._state[name] = value
        notify = self._STATE[name][1].__get__(self)
        if name == "socketPath":
            notify.emit(value)
        else:
            notify.emit()

    def _record(self, name, *args):
        self.calls.append((name, *args))

    # --- list models (constant, as in ApiClient) ---
    @Property(QObject, constant=True)
    def containersModel(self):
        return self.containers_model

    @Property(QObject, constant=True)
    def filteredContainersModel(self):
        return self.filtered_containers_model

    @Property(QObject, constant=True)
    def imagesModel(self):
        return self.images_model

    @Property(QObject, constant=True)
    def volumesModel(self):
        return self.volumes_model

    # --- slots: record only ---
    @Slot(str)
    def setSocketPath(self, path):
        self._record("setSocketPath", path)

    @Slot()
    def testConnection(self):
        self._record("testConnection")

    @Slot()
    def fetchContainers(self):
        self._record("fetchContainers")

    @Slot(str)
    def fetchContainerDetail(self, container_id):
        self._record("fetchContainerDetail", container_id)

    @Slot(str)
    def startContainer(self, container_id):
        self._record("startContainer", container_id)

    @Slot(str)
    def stopContainer(self, container_id):
        self._record("stopContainer", container_id)

    @Slot(str)
    def startContainerLogs(self, container_id):
        self._record("startContainerLogs", container_id)

    @Slot()
    def stopContainerLogs(self):
        self._record("stopContainerLogs")

    @Slot()
    def fetchImages(self):
        self._record("fetchImages")

    @Slot(str)
    def fetchImageDetail(self, image_id):
        self._record("fetchImageDetail", image_id)

    @Slot(str)
    def deleteImage(self, image_id):
        self._record("deleteImage", image_id)

    @Slot(str)
    def pullImage(self, reference):
        self._record("pullImage", reference)

    @Slot(str, str, str)
    def tagImage(self, image_id, repository, tag):
        self._record("tagImage", image_id, repository, tag)

    @Slot(str, str, str)
    def buildImage(self, context_path, dockerfile, tag):
        self._record("buildImage", context_path, dockerfile, tag)

    @Slot()
    def fetchVolumes(self):
        self._record("fetchVolumes")

    @Slot(str)
    def fetchVolumeDetail(self, name):
        self._record("fetchVolumeDetail", name)

    @Slot(str)
    def deleteVolume(self, name):
        self._record("deleteVolume", name)
