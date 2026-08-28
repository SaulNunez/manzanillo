# This Python file uses the following encoding: utf-8
import asyncio
import sys
from pathlib import Path

import qasync
from PySide6.QtCore import QSettings
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from api_client import SETTINGS_APP, SETTINGS_ORG, SOCKET_PATH_SETTING_KEY, ApiClient

DEFAULT_SOCKET_PATH = "/var/run/docker.sock"


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    engine = QQmlApplicationEngine()
    engine.addImportPath(Path(__file__).parent)

    settings = QSettings(SETTINGS_ORG, SETTINGS_APP)
    socket_path = settings.value(SOCKET_PATH_SETTING_KEY, DEFAULT_SOCKET_PATH)

    api_client = ApiClient(socket_path)
    engine.rootContext().setContextProperty("apiClient", api_client)

    engine.loadFromModule("manzanillo", "Main")
    if not engine.rootObjects():
        sys.exit(-1)

    app.aboutToQuit.connect(lambda: asyncio.ensure_future(api_client.close()))

    with loop:
        loop.run_forever()
