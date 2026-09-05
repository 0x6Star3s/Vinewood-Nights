# Agent Guide

## Project Summary

This workspace is a local FiveM / Cfx.re FXServer setup managed by txAdmin. It is not a standard application repository. The main value in the project is the server profile, `server.cfg`, the FXServer artifact, and the FiveM resources under `txData/resources`.

The server appears to be a mostly default CFX/FiveM recipe with additional resources for vMenu, maps, vehicles, and utility scripts.

## Important Paths

- `start_8158_default.bat` starts FXServer with the `default` txAdmin profile.
- `artifact/` contains the downloaded FXServer artifact and bundled Cfx.re system resources. It was updated to the official `LATEST RECOMMENDED` Windows artifact build `25770`.
- `txData/server.cfg` is the main server configuration and resource startup list.
- `txData/default/config.json` is the txAdmin profile configuration.
- `txData/resources/` contains the editable FiveM resources used by the server.
- `txData/default/logs/`, `txData/cache/`, and database files under `txData/default/data/` are runtime data and should usually not be edited by an agent.

## Main Technologies

- FiveM / Cfx.re FXServer
- txAdmin server management
- Lua resource manifests and scripts
- JavaScript / TypeScript / Vue 2 / Webpack 4 for the default `chat` resource
- C#/.NET binary resources through `vMenu`
- GTA V/FiveM assets such as `.meta`, `.ymap`, `.ytyp`, `.rpf`, and related manifest declarations

## Server Startup

The visible startup command is:

```bat
start_8158_default.bat
```

That batch file launches `FXServer.exe` with:

```bat
+set serverProfile "default"
```

Startup paths should point to `D:/game/FiveM/local4Word6`.

## Resource Startup Order

Resources are started from `txData/server.cfg` using `ensure`, including:

- Default resources: `mapmanager`, `chat`, `spawnmanager`, `sessionmanager`, `basic-gamemode`, `hardcap`
- Utility resources: `wk_delveh`, `vMenu`
- Map resources: `vineryardH`, `vremastered`, `city_e2`, `e_49_beach_garage`
- Vehicle/addon resources: `Pojazdyv2`, `rs6+`, `rs615`, `18mh5`, `RS`, `amr_car`, `auta`, `auta2`, `dodgepd`, `dodgepol`, `ems_19ranger2`, `exploler`, `m422`, `m4f82`, `pd`, `polaventador`, `zl12017`

When adding or renaming a resource, keep the folder name, manifest name, and `ensure` line consistent.

## How To Work In This Project

- Prefer changing `txData/server.cfg` for server settings and resource ordering.
- Prefer changing individual folders under `txData/resources/` for gameplay, map, vehicle, or UI changes.
- Every custom resource should have a valid `fxmanifest.lua` or legacy `__resource.lua`.
- For map and vehicle resources, verify that required files are listed in `files` and connected with the right `data_file` entries.
- For Lua scripts, follow FiveM client/server separation: use `client_script`, `server_script`, or `shared_script` intentionally.
- For NUI resources, keep `ui_page`, `files`, and built frontend assets aligned.

## Things To Avoid

- Do not edit `artifact/` manually unless explicitly asked; update it by replacing it with an official Cfx.re artifact.
- Do not edit `txData/cache/`, logs, or generated database files unless the task is specifically about runtime data recovery.
- Do not remove default CFX resources without checking dependencies in `server.cfg`.
- Do not expose or copy secrets from `txData/server.cfg`; it contains `sv_licenseKey`.
- Do not assume there is a test suite. This setup does not expose normal test commands.

## Validation Checklist

After changes, check:

- The edited resource has a valid manifest.
- The resource name appears correctly in `txData/server.cfg` if it should start automatically.
- File paths in manifests match actual filenames and case.
- Startup paths point to the real workspace path.
- No secrets, logs, cache files, or generated txAdmin data were added unnecessarily.
