"""
Example: Simple Flash Separation with DWSIM Headless

Demonstrates:
  - Creating a flowsheet
  - Adding compounds and property package
  - Adding a material stream and a flash vessel
  - Solving and reading results
"""

import sys
from dwsim_client import DWSIMClient

# Path to DWSIM DLLs (in Docker, typically /output)
DLL_DIR = sys.argv[1] if len(sys.argv) > 1 else "/output"

with DWSIMClient(DLL_DIR) as client:
    print(f"DWSIM Version: {client.version}")
    print(f"Available compounds: {len(client.available_compounds)}")
    print(f"Available property packages: {len(client.available_property_packages)}")
    print()

    # Create flowsheet
    fs = client.create_flowsheet()

    # Add compounds
    fs.add_compound("Water")
    fs.add_compound("Ethanol")

    # Add property package
    fs.add_property_package("Peng-Robinson (PR)")

    # Add feed stream (350K, 1 atm, 1 kg/s, 50/50 Water/Ethanol)
    feed = fs.add_material_stream(
        "FEED",
        temperature=350.0,       # K
        pressure=101325.0,       # Pa
        mass_flow=1.0,           # kg/s
        composition={"Water": 0.5, "Ethanol": 0.5}
    )

    # Add flash vessel
    flash = fs.add_unit_operation("Vessel", "FLASH")

    # Add product streams
    vapor = fs.add_material_stream("VAPOR", x=300)
    liquid = fs.add_material_stream("LIQUID", x=300, y=100)

    # Connect: feed -> flash -> vapor + liquid
    fs.connect(feed, flash, 0, 0)        # feed into flash inlet
    fs.connect(flash, vapor, 0, 0)       # flash vapor out
    fs.connect(flash, liquid, 1, 0)      # flash liquid out

    # Solve
    print("Solving flowsheet...")
    errors = fs.solve()

    if errors:
        print("Errors during calculation:")
        for e in errors:
            print(f"  - {e}")
    else:
        print("Solved successfully!")

    print()
    print(f"Feed:   {feed}")
    print(f"Vapor:  {vapor}")
    print(f"Liquid: {liquid}")
    print()

    # Print detailed reports
    for obj_tag in ["FEED", "VAPOR", "LIQUID"]:
        obj = fs.get_object(obj_tag)
        print(f"--- {obj_tag} Report ---")
        print(obj.get_report())
        print()
