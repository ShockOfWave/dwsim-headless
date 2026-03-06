# Python API

## Overview

The Python client (`dwsim_client.py`) is a wrapper around the .NET class `DWSIM.Automation.Automation3` via [pythonnet](https://pythonnet.github.io/). It provides a Pythonic API for creating, solving, and analyzing flowsheets.

## DWSIMClient

The main entry point.

```python
from dwsim_client import DWSIMClient

# Create (specify path to DWSIM DLL files)
client = DWSIMClient("/app/dwsim")

# Or via context manager (automatically releases resources)
with DWSIMClient("/app/dwsim") as client:
    ...
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `version` | `str` | DWSIM version (e.g., "DWSIM version 9.0.5.0 (...)") |
| `available_compounds` | `list[str]` | List of all available compounds (1480 total) |
| `available_property_packages` | `list[str]` | List of property packages (29 total) |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `create_flowsheet()` | `FlowsheetWrapper` | Create an empty flowsheet |
| `load_flowsheet(filepath)` | `FlowsheetWrapper` | Load a flowsheet from a `.dwxml`/`.dwxmz` file |
| `release()` | -- | Release DWSIM resources |

## FlowsheetWrapper

Wrapper around a DWSIM flowsheet.

### Setting Up the Flowsheet

```python
fs = client.create_flowsheet()

# Add compounds (names must exactly match available_compounds)
fs.add_compound("Water")
fs.add_compound("Ethanol")
fs.add_compound("Methanol")

# Add a property package
fs.add_property_package("Peng-Robinson (PR)")
```

### Available Property Packages

| Package | Description |
|---------|-------------|
| `"Peng-Robinson (PR)"` | Peng-Robinson cubic equation of state |
| `"Soave-Redlich-Kwong (SRK)"` | SRK cubic equation of state |
| `"NRTL"` | NRTL activity coefficient model |
| `"UNIQUAC"` | UNIQUAC activity coefficient model |
| `"UNIFAC"` | UNIFAC group contribution model |
| `"Modified UNIFAC (Dortmund)"` | Modified UNIFAC |
| `"CoolProp"` | High-accuracy properties (NIST) |
| `"Steam Tables (IAPWS-IF97)"` | Steam tables |
| `"Raoult's Law"` | Raoult's Law (ideal solutions) |
| `"GERG-2008"` | Equation of state for gases |
| `"PC-SAFT"` | Statistical associating equation |
| `"Peng-Robinson 1978 (PR78)"` | PR 1978 modification |
| `"Lee-Kesler-Plocker"` | Lee-Kesler-Plocker equation |
| `"Black Oil"` | Black oil model |
| ... | Full list: `client.available_property_packages` |

### Adding Objects

```python
# Material stream (with configuration)
feed = fs.add_material_stream(
    "FEED",
    temperature=350.0,       # K
    pressure=101325.0,       # Pa
    mass_flow=1.0,           # kg/s
    composition={"Water": 0.5, "Ethanol": 0.5}  # mole fractions
)

# Material stream (without configuration -- configure later)
product = fs.add_material_stream("PRODUCT")

# Energy stream
energy = fs.add_energy_stream("Q-001")

# Unit operation
mixer = fs.add_unit_operation("Mixer", "MIX-001")
heater = fs.add_unit_operation("Heater", "HTR-001")
flash = fs.add_unit_operation("Vessel", "FLASH")
valve = fs.add_unit_operation("Valve", "VLV-001")

# Arbitrary object by type name
obj = fs.add_object("DistillationColumn", "COL-001")
```

### Available Unit Operation Types

| Type | Description |
|------|-------------|
| **Streams** | |
| `MaterialStream` | Material stream |
| `EnergyStream` | Energy stream |
| **Mixers/Splitters** | |
| `Mixer` (or `NodeIn`) | Mixer |
| `Splitter` (or `NodeOut`) | Splitter |
| **Pressure** | |
| `Pump` | Pump |
| `Compressor` | Compressor |
| `Expander` | Expander (turbine) |
| `Valve` | Valve (throttle) |
| **Heat Exchange** | |
| `Heater` | Heater |
| `Cooler` | Cooler |
| `HeatExchanger` | Heat exchanger |
| **Separation** | |
| `Vessel` | Flash separator |
| `ComponentSeparator` | Component separator |
| `Filter` | Filter |
| **Columns** | |
| `ShortcutColumn` | Shortcut distillation (Fenske-Underwood) |
| `DistillationColumn` | Rigorous distillation column |
| `AbsorptionColumn` | Absorber |
| **Reactors** | |
| `RCT_Conversion` | Conversion reactor |
| `RCT_Equilibrium` | Equilibrium reactor |
| `RCT_Gibbs` | Gibbs reactor |
| `RCT_CSTR` | Continuous stirred-tank reactor |
| `RCT_PFR` | Plug flow reactor |
| **Piping** | |
| `Pipe` | Pipe segment |
| `Tank` | Tank |
| **Logical** | |
| `OT_Adjust` | Adjust |
| `OT_Spec` | Specification |
| `OT_Recycle` | Recycle |

### Connecting Objects

```python
# connect(source, destination, from_port, to_port)
fs.connect(feed, mixer, 0, 0)       # feed -> mixer inlet 0
fs.connect(mixer, product, 0, 0)    # mixer -> product

# For flash separator: port 0 = vapor, port 1 = liquid
fs.connect(feed, flash, 0, 0)
fs.connect(flash, vapor, 0, 0)      # vapor out
fs.connect(flash, liquid, 1, 0)     # liquid out

# Disconnect
fs.disconnect(feed, mixer)
```

### Solving

```python
# Option 1: Simple solve
errors = fs.solve()
if errors:
    for e in errors:
        print(f"Error: {e}")

# Option 2: With timeout (seconds)
errors = fs.solve(timeout_seconds=60)

# Option 3: Save after solving
fs.save("/output/result.dwxmz", compressed=True)
```

### Navigating Objects

```python
# List all objects
print(fs.list_objects())  # ['FEED', 'MIX-001', 'PRODUCT']

# Get an object by tag
obj = fs.get_object("FEED")
```

## MaterialStreamWrapper

Wrapper around a DWSIM material stream with convenient properties.

### Reading Results

```python
stream = fs.get_object("PRODUCT")

# Main properties (read-only after solving)
print(stream.temperature)  # K
print(stream.pressure)     # Pa
print(stream.mass_flow)    # kg/s
print(stream.molar_flow)   # mol/s

# Composition
comp = stream.get_composition()
# {'Water': 0.38, 'Ethanol': 0.62}

# Text report
print(stream.get_report())
```

### Setting Parameters

```python
stream.set_temperature(350.0)    # K
stream.set_pressure(101325.0)    # Pa
stream.set_mass_flow(1.0)        # kg/s
stream.set_molar_flow(30.0)      # mol/s

# Molar composition
stream.set_composition({
    "Water": 0.5,
    "Ethanol": 0.3,
    "Methanol": 0.2
})
```

### String Representation

```python
print(feed)
# <MaterialStream: FEED T=350.0K P=101325Pa F=1.0000kg/s>
```

## SimulationObjectWrapper

Base wrapper for any object (unit operation, stream).

```python
obj = fs.get_object("MIX-001")

# Object tag
print(obj.tag)  # "MIX-001"

# Arbitrary property by code
value = obj.get_property("PROP_MX_0")

# Set property
obj.set_property("PROP_HT_0", 400.0)

# Text report
print(obj.get_report())

# Access the .NET object directly
net_obj = obj.native
```

## Stream Property Codes

Main codes for material streams (`PROP_MS_*`):

| Code | Property | Units |
|------|----------|-------|
| `PROP_MS_0` | Temperature | K |
| `PROP_MS_1` | Pressure | Pa |
| `PROP_MS_2` | Mass flow rate | kg/s |
| `PROP_MS_3` | Molar flow rate | mol/s |
| `PROP_MS_4` | Volumetric flow rate | m3/s |
| `PROP_MS_6` | Specific enthalpy | kJ/kg |
| `PROP_MS_7` | Specific entropy | kJ/(kg*K) |

Full list of property codes: [DWSIM Wiki -- Object Property Codes](https://dwsim.org/wiki/index.php?title=Object_Property_Codes)

## Complete Example: Mixing and Heating

```python
from dwsim_client import DWSIMClient

with DWSIMClient("/app/dwsim") as client:
    fs = client.create_flowsheet()

    # Compounds and thermodynamics
    fs.add_compound("Water")
    fs.add_compound("Ethanol")
    fs.add_property_package("NRTL")

    # Two inlet streams
    feed1 = fs.add_material_stream(
        "FEED-1", temperature=300.0, pressure=200000.0,
        mass_flow=0.5, composition={"Water": 0.8, "Ethanol": 0.2}
    )
    feed2 = fs.add_material_stream(
        "FEED-2", temperature=320.0, pressure=200000.0,
        mass_flow=0.3, composition={"Water": 0.3, "Ethanol": 0.7}
    )

    # Mixer
    mixer = fs.add_unit_operation("Mixer", "MIX-001")
    mixed = fs.add_material_stream("MIXED")

    # Heater
    heater = fs.add_unit_operation("Heater", "HTR-001")
    hot = fs.add_material_stream("HOT")
    energy = fs.add_energy_stream("Q-HTR")

    # Connections
    fs.connect(feed1, mixer, 0, 0)
    fs.connect(feed2, mixer, 0, 1)
    fs.connect(mixer, mixed, 0, 0)
    fs.connect(mixed, heater, 0, 0)
    fs.connect(heater, hot, 0, 0)
    fs.connect(energy, heater, 0, 0)

    # Set heating temperature
    heater.set_property("PROP_HT_0", 380.0)  # Target T = 380K
    heater.set_property("PROP_HT_1", 0.0)    # Delta P = 0

    # Solve
    errors = fs.solve()
    if errors:
        print("Errors:", errors)
    else:
        print(f"Mixed stream: {mixed.temperature:.1f} K, {mixed.mass_flow:.4f} kg/s")
        print(f"Heated stream: {hot.temperature:.1f} K, {hot.mass_flow:.4f} kg/s")
        print(f"Composition: {hot.get_composition()}")
```

## Working with Loaded Files

```python
with DWSIMClient("/app/dwsim") as client:
    # Load an existing flowsheet
    fs = client.load_flowsheet("/path/to/simulation.dwxmz")

    # Modify parameters
    feed = fs.get_object("S-01")
    feed.set_property("PROP_MS_0", 400.0)  # Change temperature

    # Recalculate
    errors = fs.solve()

    # Read results
    product = fs.get_object("S-05")
    print(product.get_report())

    # Save
    fs.save("/output/modified.dwxmz")
```

## Accessing .NET Objects

For advanced usage, you can work with .NET objects directly via pythonnet:

```python
# Get the .NET flowsheet
net_fs = fs.native

# Call any .NET method
for obj in net_fs.SimulationObjects.Values:
    print(f"{obj.GraphicObject.Tag}: {obj.GetType().Name}")

# Working with enumerations
from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
obj = net_fs.AddObject(ObjectType.Valve, 100, 100, "VLV-001")
```
