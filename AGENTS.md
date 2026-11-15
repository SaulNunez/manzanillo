# Agents

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for SaulNunez/manzanillo, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Tests

Run the whole suite (headless; no Docker daemon needed) from the repo root:

```sh
/home/saul/Projects/manzanillo/.venv/bin/pytest
```

The venv lives only in the main checkout (git-ignored, `--system-site-packages` with
pytest + pytest-qt), so call it by absolute path from worktrees. pytest config is in
`pyproject.toml`; `conftest.py` forces `QT_QPA_PLATFORM=offscreen` and the Fusion style.

Layout of `tests/`:

- `fake_api_client.py` - `FakeApiClient`, a Docker-free stand-in for `ApiClient` with the
  same properties, signals and slots. `test_fake_api_client.py` fails if the QML or the real
  `ApiClient` uses something the fake lacks; when you add to `ApiClient`, add it to the fake.
- `conftest.py` - fixtures: `fake_api_client`, `load_qml`, `main_window`, `user_locale`
  (pins locale + TZ for formatted dates/sizes), `rtl` (right-to-left layout), and the autouse
  `qml_warnings`, which **fails any test during which QML logged a warning**.
- `qml_helpers.py` - the shared helpers; put new reusable ones here, never import helpers
  from another `test_*.py` module:
  - `find(root, objectName)` - QObject children; `find_item(root, objectName)` - also reaches
    ListView/Repeater delegates and popups.
  - `call_qml(obj, "jsFunction", *args)`; `qml_eval(item, "expr")` for gadget/enum
    properties (e.g. `"icon.name"`, `"display === AbstractButton.IconOnly"`).
  - Navigation: `show_page(main_window, qtbot, navIndex)`,
    `open_detail(main_window, qtbot, navIndex, stackName, openFunction, args)` (returns the
    StackView), `settle(stack, qtbot)` (wait out the push transition).
  - `focus(main_window, item, qtbot)` for keyboard tests; `scene_x(item)`.
  - Accessibility/visible text: `accessible_name(item)`, `accessible_description(item)`,
    `visible_texts(item)`.
- `test_formatting.py`, `test_models.py` - unit tests for pure helpers/models in `api_client.py`.
- `test_qml_smoke.py` - loads `Main.qml`, visits each page and each detail page.

### Writing a QML test with the fake client

```python
from qml_helpers import call_qml, find

def test_start_button_starts_container(main_window, qtbot):
    fake = main_window.fake
    fake.containers_model.set_containers([{"Id": "a" * 64, "Names": ["/web"], "State": "exited"}])
    fake.set("containerDetail", {"id": "aaa", "state": "exited"})   # emits the notify signal
    fake.containersErrorOccurred.emit("boom")                         # simulate a failure
    button = find(main_window.window, "startContainerButton")         # objectName hooks
    ...
    assert ("startContainer", "aaa") in fake.calls                    # slots only record calls
```

- `main_window` loads the whole app; `load_qml("manzanillo/SomePage.qml")` or
  `load_qml(("manzanillo", "Main"))` loads something specific. To set fake state *before*
  load, request `fake_api_client` (same object as `.fake`) and fill it before calling `load_qml`.
- Find items via their `objectName` (keep existing ones stable; add new ones as hooks).
  Call page JS functions with `call_qml`. Use `qtbot.waitUntil`/`qtbot.wait` for async UI.
- An expected warning can be tolerated with `qml_warnings.allow(r"regex")`.
