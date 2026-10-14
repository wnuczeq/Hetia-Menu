# Hetia Menu

A cheat menu for FiveM. Two builds live here:

- **`hetia_menu.lua`** — a single-file **native overlay** menu. No NUI page, no
  resource, no server, no HTTP. Paste it into a client-side executor and it draws
  itself with the game's own primitives. **This is the working build.**
- **`client.lua` / `server.lua` / `html/`** — the original **NUI build**. It is a
  real FiveM resource and requires a server; see [NUI build](#nui-build) below.

## Repo layout

```
Hetia/
├─ hetia_menu.lua    # native overlay menu — paste this into an executor
├─ loader.lua        # HTTP loader + fallback chain for runtimes that have HTTP
├─ probe.lua         # prints which executor globals exist (diagnostic)
├─ client.lua        # NUI build: controller, keybind, spawn helpers
├─ server.lua        # NUI build: server-side dynamic resource creator
├─ fxmanifest.lua    # NUI build: manifest for the temp resource
└─ html/
   ├─ index.html     # NUI build: menu markup
   ├─ style.css      # NUI build: pearl-style theme
   └─ script.js      # NUI build: tab logic + NUI callbacks
```

## Config

| Setting | Value |
|---|---|
| Repo | `wnuczeq/Hetia-Menu` |
| Branch | `main` |
| Keybind | `F5` (plus `/hetia` in chat) |
| Temp resource (NUI build) | `hetia_nui_temp` |

Raw URLs must match repo name and branch **exactly** — raw.githubusercontent.com
is case-sensitive and returns `404` if either is off, or if the repo is private.

## Native build — how to run it

Open `hetia_menu.lua` raw, copy the whole file, paste it into the executor. The
menu opens by itself; `F5` or `/hetia` toggles it. Arrow keys navigate, Enter
activates, Esc closes; the mouse also works.

Key settings at the top of the file:

| Setting | Meaning |
|---|---|
| `OPEN_ON_LOAD` | `true` = menu opens as soon as the script runs. Set `false` for F5-only. |
| `LAYOUT.cursorSens` | Mouse speed (`0.0015`). Raise if the cursor crawls, lower if it flies. |
| `TOGGLE_VK` | Virtual key of the toggle key (`0x74` = F5), used by the raw-key fallback. |

Features: God Mode, Infinite Ammo, Heal, Armor, Repair Vehicle, Max Mods, Delete
Vehicle, Teleport to Waypoint, Noclip, Super Jump, and eight weapon/vehicle spawns
across four tabs (Main / Weapons / Vehicles / Misc).

## Running from a URL

`loader.lua` probes every HTTP entry point a runtime might expose
(`PerformHttpRequest`, the `httprequest-client` export, `httpGet`, `HttpGet`,
`http_request`, `fetch`) in order, and compiles whatever `hetia_menu.lua` it gets
back. If none exist it prints step-by-step paste instructions instead of failing
obscurely.

```
load https://raw.githubusercontent.com/wnuczeq/Hetia-Menu/main/loader.lua
```

**Do NOT use `game:HttpGet(...)`** — that is Roblox syntax. `game` does not exist
in FiveM, so it throws `attempt to index a nil value (global 'game')` before
anything downloads.

## Executor notes

Verified with `probe.lua` on Keyser:

| Available | Missing |
|---|---|
| `Citizen`, `TriggerEvent/ServerEvent`, `RegisterCommand`, `RegisterKeyMapping` | **every HTTP function** — `PerformHttpRequest`, `httpGet`, `fetch`, `HttpGet` |
| `PlayerPedId`, `PlayerId`, and the ped/vehicle native set | `imgui`, `drawText` (lowercase), `loadstring`, `game` |
| `DrawRect`, `DrawText`, `DrawLine`, `SetCursorLocation`, `IsControlPressed`, `SetNuiFocus`, `SendNUIMessage` | `drawRect`, `ui`, `menu`, `GUI` |

Two consequences:

1. **There is no download path in Keyser.** No HTTP function exists, so no loader
   can fetch the menu. Paste `hetia_menu.lua` directly.
2. **The NUI build cannot render there.** `SetNuiFocus` and `SendNUIMessage` are
   present but do nothing without a resource hosting a NUI page — they return
   `false` silently, no error. The native build avoids NUI entirely.

## NUI build

The original design: `html/` is a NUI page, `client.lua` drives it, and
`server.lua` creates a temporary resource at runtime and downloads it from GitHub.

It only works on a **real FiveM server**:

- `SaveResourceFile`, `StartResource`, `StopResource`, `GetResourceState` are
  server-side; `server.lua` needs them to build `hetia_nui_temp` on the fly.
- `SendNUIMessage` / `SetNuiFocus` need a resource with a `ui_page`.

Deploy it as an ordinary resource instead of the dynamic-creator path if you
control the server — far fewer moving parts. Folder name must match
`fxmanifest.lua`'s expectations, then `ensure <folder>` in `server.cfg`.