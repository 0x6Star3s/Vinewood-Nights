# Vehicle Addons

Add vehicles using this layout:

```text
[addon]/
  [bmw]/
    m2/
      data/
        vehicles.meta
        carvariations.meta
        handling.meta
        carcols.meta
      stream/
        m2.yft
        m2_hi.yft
        m2.ytd
```

After adding or removing a vehicle, run:

```bat
python txData\resources\[addon]\generate_vehicle_resources.py
```

The generator updates `vehicles.cfg`, which is imported by `txData/server.cfg`, and syncs the same vehicles to `vMenu/config/addons.json`.
Brand folders use square brackets because FiveM treats them as categories, not resources.
If all detected vehicles are configured correctly, it prints `status=200`.
Vehicle model folder names are FiveM resource names, so they must be unique across all brands.
