"""python tools/test_handling_fix.py - szablon klasy nie moze ruszac sprezyny/tlumienia autora (sprzezone z limitami)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from handling_fix import fix_item, getv

ITEM = """<Item type="CHandlingData">
<handlingName>test</handlingName>
    <fMass value="1435.000000"/>
    <fInitialDragCoeff value="2.300000"/>
    <fInitialDriveForce value="0.340000"/>
    <fInitialDriveMaxFlatVel value="304.000000"/>
    <fTractionCurveMax value="3.000000"/>
    <fTractionCurveMin value="2.900000"/>
    <fSuspensionForce value="5.000000"/>
    <fSuspensionCompDamp value="1.500000"/>
    <fSuspensionReboundDamp value="2.200000"/>
    <fSuspensionUpperLimit value="0.080000"/>
    <fSuspensionLowerLimit value="-0.100000"/>
    <vecCentreOfMassOffset x="0.000000" y="0.000000" z="0.000000"/>
    <vecInertiaMultiplier x="1.000000" y="1.300000" z="1.500000"/>
</Item>
"""
for mode in ("clamp", "template"):
    out, _ = fix_item(ITEM, "SPORT", mode, [])
    assert getv(out, "fSuspensionForce") == 5.0, mode
    assert getv(out, "fSuspensionCompDamp") == 1.5 and getv(out, "fSuspensionReboundDamp") == 2.2, mode
    assert getv(out, "fInitialDragCoeff") >= 6.0, mode          # reszta szablonu/clampa dalej dziala
assert getv(fix_item(ITEM, "SPORT", "template", [])[0], "fTractionCurveMax") == 2.45
print("OK")
