# This Python file uses the following encoding: utf-8
import asyncio
import sys
from pathlib import Path

import qasync
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from api_client import ApiClient

SOCKET_PATH = "/var/run/docker.sock"


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    engine = QQmlApplicationEngine()
    engine.addImportPath(Path(__file__).parent)

    api_client = ApiClient(SOCKET_PATH)
    engine.rootContext().setContextProperty("apiClient", api_client)

    engine.loadFromModule("manzanillo", "Main")
    if not engine.rootObjects():
        sys.exit(-1)

    app.aboutToQuit.connect(lambda: asyncio.ensure_future(api_client.close()))

    with loop:
        loop.run_forever()
