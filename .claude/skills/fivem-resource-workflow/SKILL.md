---
name: fivem-resource-workflow
description: Work on this local FiveM FXServer project without restarting the whole server unnecessarily. Use when editing FiveM resources, HUD, chat, keybinds, Lua scripts, NUI files, vehicle/map resources, server.cfg resource lists, or when the user asks to fix something while the server is running.
---

# FiveM Resource Workflow

## Core Rule

When the FXServer is already running, do not restart or stop the whole server unless the change truly requires it.

Prefer the smallest reload that applies the current change:

```text
restart <resource-name>
```

Examples:

```text
restart chat
restart qb-hud
restart wk_wars2x
restart qb-vehiclekeys
restart pma-voice
```

## Before Editing

1. Identify the owning resource from the file path.
   - `txData/resources/[gameplay]/chat/...` -> `chat`
   - `txData/resources/[hud]/qb-hud/...` -> `qb-hud`
   - `txData/resources/[standalone]/wk_wars2x/...` -> `wk_wars2x`
   - `txData/resources/[qb]/qb-vehiclekeys/...` -> `qb-vehiclekeys`
2. Check whether FXServer is running before deciding how to apply the change.
3. Tell the user which resource will need reloading.

## Applying Changes

For normal resource edits, reload only that resource:

- Lua client/server scripts: `restart <resource>`
- NUI HTML/CSS/JS changes: `restart <resource>`; the player may also need to reconnect or run the in-game reset command if the browser cache keeps old UI.
- `fxmanifest.lua` changes inside an existing resource: `restart <resource>` first.
- New resource folders or renamed resources: run `refresh`, then `ensure <resource>` or `restart <resource>`.
- Generated vehicle resource lists: regenerate the list, then restart the affected vehicle resource or run `refresh` if resource names changed.

Use full server restart only for:

- FXServer startup arguments, OneSync, ports, license key, or endpoint changes.
- Database container/service lifecycle changes.
- `server.cfg` changes that affect global startup behavior and cannot be applied with `exec`, `ensure`, `stop`, or `restart`.
- Broken state where targeted resource restart fails and the reason is documented.

## Console Access Preference

Use the available live server control path in this order:

1. Active FXServer console: run `restart <resource>` in the console.
2. txAdmin console or web console: run the same resource command there.
3. RCON if configured: send `restart <resource>`.
4. If no live control path is available, explain the limitation and ask before doing a full server restart.

Do not kill `FXServer.exe` just to apply a small resource edit.

## Starting FXServer

When the user asks to start the server, start `FXServer.exe` as a detached Windows process with `Start-Process`.

Do not run `FXServer.exe` as the foreground command in the agent shell, because the tool-managed terminal can send `Ctrl-C` or close the process when the command session ends.

Use this startup flow:

1. Check whether `FXServer.exe` is already running and whether port `30120` is in use.
2. Confirm the MariaDB container is running and healthy.
3. Regenerate vehicle resource lists before startup if vehicle folders were moved or changed:
   ```powershell
   python "d:\game\FiveM\local4Word6\txData\resources\[addon]\generate_vehicle_resources.py"
   ```
4. Start FXServer detached:
   ```powershell
   Start-Process -FilePath "d:\game\FiveM\local4Word6\artifact\FXServer.exe" -WorkingDirectory "d:\game\FiveM\local4Word6\txData" -ArgumentList "+set onesync on +exec server.cfg" -PassThru
   ```
5. Validate with `http://127.0.0.1:30120/info.json` and `players.json`.

Only use a foreground FXServer command for short diagnostic experiments, and expect it may be interrupted by the tool session.

## Validation

After reloading a resource:

1. Confirm the server process is still running.
2. Check `http://127.0.0.1:30120/info.json` or `players.json` if available.
3. Search the fresh output/logs for:
   - `SCRIPT ERROR`
   - `Couldn't start resource`
   - `Could not start dependency`
   - `No such export`
4. If a player is connected, ask them to verify the feature in-game.

## User Communication

Be explicit and brief:

- Say which resource was changed.
- Say whether only that resource was restarted.
- Mention if the player must reconnect, clear client keybinds, or run an in-game reset command.
- If a full restart is necessary, explain why before doing it.
