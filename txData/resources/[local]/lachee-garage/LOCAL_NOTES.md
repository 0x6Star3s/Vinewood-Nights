# lachee-garage

Source: [Lachee/fivem-garage](https://github.com/Lachee/fivem-garage)

This is an ESX garage resource for storing and recovering owned vehicles at garage locations.

## Current Status

The resource is installed but not enabled in `txData/server.cfg`.

It is not safe to enable yet because this server does not currently have:

- ESX / `es_extended`
- MySQL or MariaDB
- A configured database connection string
- The required `owned_vehicles` table and garage migration columns
- `mysql-async`, which this resource references in `fxmanifest.lua`

## SQL Files

The resource includes:

- `sql/1.initial.sql`
- `sql/2.migration.sql`

The migration adds these columns to `owned_vehicles`:

- `garage`
- `state`

## Important Note

The rest of the server plan prefers `oxmysql`, but this resource currently depends on `mysql-async`.
Before enabling it, choose one direction:

- install and use `mysql-async` for this older garage resource, or
- adapt/replace the garage resource with one that supports `oxmysql`.

## Enable Later

After ESX and the database are working:

```cfg
ensure mysql-async
ensure es_extended
ensure lachee-garage
```
