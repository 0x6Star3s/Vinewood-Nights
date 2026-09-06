# ts_esx-CarKeys

Source: https://github.com/Trusted-Studios/ts_esx-CarKeys

This resource adds a simple ESX vehicle key system. Players can lock or unlock vehicles they own by pressing the configured key.

## How It Works

- The default key is `I`, configured in `config.lua` as `Config.DefaultLockKey`.
- The client finds the closest vehicle within `Config.LockDistance`.
- The server checks the vehicle plate against the ESX `owned_vehicles` table.
- If the player owns the vehicle, the script toggles the door lock state and plays the key-fob animation/lights.

## Requirements

This server currently does not include these dependencies, so the resource is installed but not enabled in `server.cfg`.

- `es_extended`
- `oxmysql`
- Database table: `owned_vehicles`

Enable it only after the ESX stack and database are installed:

```cfg
ensure oxmysql
ensure es_extended
ensure ts_esx-CarKeys
```
