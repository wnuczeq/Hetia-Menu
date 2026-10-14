# Hetia Menu

Custom NUI menu for FiveM executors, styled after the Pearl menu. Distributed via GitHub + a loader snippet, with a dynamically-created temporary NUI resource.

## Repo layout

```
Hetia/
├─ loader.lua        # executor entry point — downloads + runs client.lua
├─ client.lua        # NUI controller, keybind, spawn helpers
├─ server.lua        # server-side dynamic resource creator
├─ fxmanifest.lua    # manifest for the temporary NUI resource
└─ html/
   ├─ index.html     # menu markup
   ├─ style.css      # pearl-style theme
   └─ script.js      # tab logic + NUI callbacks
```

## Config

| Setting | Value |
|---|---|
| Repo | `wnuczeq/Hetia-Menu` |
| Branch | `main` |
| Keybind | `F5` |
| Temp resource | `hetia_nui_temp` |

Raw URLs in `loader.lua` and `server.lua` must match the repo name and branch
**exactly** — raw.githubusercontent.com is case-sensitive and returns `404`
if either is off, or if the repo is private.

## Use

Paste into the executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wnuczeq/Hetia-Menu/main/loader.lua"))()
```

If the executor lacks `game:HttpGet`, run `loader.lua` directly — it uses
`PerformHttpRequest` internally.

## Requirements

The NUI half (`SendNUIMessage`, `SetNuiFocus`) and the dynamic-resource creator
(`SaveResourceFile`, `StartResource`, `RegisterKeyMapping`) are **server/resource
context functions**. They exist in a real FiveM server, not in a client-side
executor. Deploy the menu as a resource on a server you control, or swap the
render layer for the executor's own NUI/overlay API.