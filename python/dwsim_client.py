"""
DWSIM Headless Python Client

Thin wrapper around DWSIM's Automation3 API using pythonnet.
Provides Pythonic access to flowsheet creation, simulation, and results.

Usage:
    from dwsim_client import DWSIMClient

    client = DWSIMClient("/path/to/dwsim/dlls")
    fs = client.create_flowsheet()
    fs.add_compound("Water")
    fs.add_compound("Ethanol")
    fs.add_property_package("Peng-Robinson (PR)")
    feed = fs.add_material_stream("FEED", temperature=350, pressure=101325, mass_flow=1.0,
                                   composition={"Water": 0.5, "Ethanol": 0.5})
    mixer = fs.add_unit_operation("Mixer", "MIX-001")
    product = fs.add_material_stream("PRODUCT")
    fs.connect(feed, mixer, 0)
    fs.connect(mixer, product, 0)
    errors = fs.solve()
    print(product.temperature, product.pressure)
"""

import os
import sys
from pathlib import Path
from typing import Optional

# Global flag: CLR loaded?
_clr_loaded = False
_clr = None


def _init_clr(dll_dir: str):
    """Initialize pythonnet CLR runtime and load DWSIM assemblies."""
    global _clr_loaded, _clr

    if _clr_loaded:
        return

    from pythonnet import load

    # Use coreclr runtime (net8.0)
    load("coreclr")

    import clr
    _clr = clr

    dll_path = Path(dll_dir)

    # Add the DLL directory to the assembly search path
    import System
    from System.Runtime.Loader import AssemblyLoadContext
    from System.IO import Path as SysPath
    from System.Reflection import Assembly

    # Register a resolving handler for transitive dependencies
    def _resolve(ctx, name):
        p = str(dll_path / (str(name.Name) + ".dll"))
        if os.path.isfile(p):
            return Assembly.LoadFrom(p)
        return None

    AssemblyLoadContext.Default.Resolving += _resolve

    # Load core DWSIM assemblies
    for asm_name in [
        "DWSIM.Automation",
        "DWSIM.GlobalSettings",
        "DWSIM.Interfaces",
        "DWSIM.Thermodynamics",
        "DWSIM.UnitOperations",
        "DWSIM.FlowsheetBase",
        "DWSIM.FlowsheetSolver",
        "DWSIM.SharedClasses",
    ]:
        asm_path = str(dll_path / f"{asm_name}.dll")
        if os.path.isfile(asm_path):
            Assembly.LoadFrom(asm_path)

    _clr_loaded = True


class FlowsheetWrapper:
    """Pythonic wrapper around DWSIM IFlowsheet."""

    def __init__(self, flowsheet, automation):
        self._fs = flowsheet
        self._auto = automation
        self._compounds = []  # Track added compound names in order

    @property
    def native(self):
        """Access the underlying .NET IFlowsheet object."""
        return self._fs

    def add_compound(self, name: str):
        """Add a compound to the flowsheet by name (e.g. 'Water', 'Ethanol')."""
        self._fs.AddCompound(name)
        self._compounds.append(name)

    def add_property_package(self, name: str):
        """Add a property package (e.g. 'Peng-Robinson (PR)')."""
        return self._fs.CreateAndAddPropertyPackage(name)

    def get_available_compounds(self) -> list:
        """List all available compound names."""
        compounds = self._auto.AvailableCompounds
        return [str(k) for k in compounds.Keys]

    def get_available_property_packages(self) -> list:
        """List all available property package names."""
        packs = self._auto.AvailablePropertyPackages
        return [str(k) for k in packs.Keys]

    def get_available_unit_operations(self) -> list:
        """List all available unit operation type names."""
        from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
        return [str(f.Name) for f in type(ObjectType).GetFields()
                if f.IsStatic and f.IsPublic]

    def add_object(self, object_type_name: str, tag: str, x: int = 0, y: int = 0):
        """
        Add a simulation object by type name string.

        Args:
            object_type_name: e.g. "MaterialStream", "Mixer", "Heater", "Valve"
            tag: Unique tag/name for the object
            x, y: Position coordinates (for drawing, can be 0 for headless)

        Returns:
            SimulationObjectWrapper
        """
        from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
        obj_type = getattr(ObjectType, object_type_name)
        sim_obj = self._fs.AddObject(obj_type, x, y, tag)
        return SimulationObjectWrapper(sim_obj, self)

    def add_material_stream(self, tag: str, temperature: float = None,
                            pressure: float = None, mass_flow: float = None,
                            molar_flow: float = None,
                            composition: dict = None,
                            x: int = 0, y: int = 0):
        """
        Add and configure a material stream.

        Args:
            tag: Stream name
            temperature: Temperature in K
            pressure: Pressure in Pa
            mass_flow: Mass flow in kg/s
            molar_flow: Molar flow in mol/s
            composition: Dict of {compound_name: mole_fraction}
            x, y: Position

        Returns:
            MaterialStreamWrapper
        """
        from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
        obj = self._fs.AddObject(ObjectType.MaterialStream, x, y, tag)
        wrapper = MaterialStreamWrapper(obj, self)

        if temperature is not None:
            wrapper.set_temperature(temperature)
        if pressure is not None:
            wrapper.set_pressure(pressure)
        if mass_flow is not None:
            wrapper.set_mass_flow(mass_flow)
        if molar_flow is not None:
            wrapper.set_molar_flow(molar_flow)
        if composition is not None:
            wrapper.set_composition(composition)

        return wrapper

    def add_energy_stream(self, tag: str, x: int = 0, y: int = 0):
        """Add an energy stream."""
        from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
        obj = self._fs.AddObject(ObjectType.EnergyStream, x, y, tag)
        return SimulationObjectWrapper(obj, self)

    def add_unit_operation(self, type_name: str, tag: str, x: int = 0, y: int = 0):
        """
        Add a unit operation.

        Common type_names: Mixer, Splitter, Valve, Pump, Compressor,
        Heater, Cooler, HeatExchanger, Vessel, Pipe,
        ShortcutColumn, DistillationColumn,
        RCT_Conversion, RCT_Equilibrium, RCT_Gibbs
        """
        return self.add_object(type_name, tag, x, y)

    def connect(self, source, destination, from_port: int = 0, to_port: int = 0):
        """
        Connect two simulation objects.

        Args:
            source: SimulationObjectWrapper or native object
            destination: SimulationObjectWrapper or native object
            from_port: Output port index on source
            to_port: Input port index on destination
        """
        src = source.native if hasattr(source, 'native') else source
        dst = destination.native if hasattr(destination, 'native') else destination
        self._fs.ConnectObjects(src.GraphicObject, dst.GraphicObject, from_port, to_port)

    def disconnect(self, source, destination):
        """Disconnect two simulation objects."""
        src = source.native if hasattr(source, 'native') else source
        dst = destination.native if hasattr(destination, 'native') else destination
        self._fs.DisconnectObjects(src.GraphicObject, dst.GraphicObject)

    def solve(self, timeout_seconds: int = None) -> list:
        """
        Solve the flowsheet.

        Args:
            timeout_seconds: Optional timeout

        Returns:
            List of error message strings (empty if successful)
        """
        from DWSIM.Automation import Automation3

        if timeout_seconds is not None:
            exceptions = self._auto.CalculateFlowsheet3(self._fs, timeout_seconds)
        else:
            exceptions = self._auto.CalculateFlowsheet4(self._fs)

        errors = []
        if exceptions is not None:
            for ex in exceptions:
                errors.append(str(ex.Message))
        return errors

    def save(self, filepath: str, compressed: bool = True):
        """Save the flowsheet to a file."""
        self._auto.SaveFlowsheet(self._fs, filepath, compressed)

    def get_object(self, tag: str):
        """Get a simulation object by its tag name."""
        for obj in self._fs.SimulationObjects.Values:
            if str(obj.GraphicObject.Tag) == tag:
                return SimulationObjectWrapper(obj, self)
        raise KeyError(f"Object '{tag}' not found in flowsheet")

    def list_objects(self) -> list:
        """List all simulation object tags."""
        return [str(obj.GraphicObject.Tag) for obj in self._fs.SimulationObjects.Values]

    def add_reaction_conversion(self, name: str, description: str,
                                compounds_and_stoich: dict,
                                base_compound: str,
                                reaction_phase: str,
                                conversion_expression: str):
        """
        Create and add a conversion reaction.

        Args:
            name: Reaction name
            description: Description
            compounds_and_stoich: Dict of {compound_name: stoichiometric_coefficient}
            base_compound: Base compound name
            reaction_phase: "Vapor", "Liquid", or "Mixture"
            conversion_expression: Expression for conversion (e.g. "0.8")
        """
        from System.Collections.Generic import Dictionary
        from System import String, Double

        d = Dictionary[String, Double]()
        for k, v in compounds_and_stoich.items():
            d.Add(k, float(v))

        rxn = self._fs.CreateConversionReaction(name, description, d,
                                                 base_compound, reaction_phase,
                                                 conversion_expression)
        self._fs.AddReaction(rxn)
        return rxn


class SimulationObjectWrapper:
    """Wrapper around DWSIM ISimulationObject."""

    def __init__(self, sim_obj, flowsheet_wrapper):
        self._obj = sim_obj
        self._fw = flowsheet_wrapper

    @property
    def native(self):
        """Access the underlying .NET ISimulationObject."""
        return self._obj

    @property
    def tag(self) -> str:
        return str(self._obj.GraphicObject.Tag)

    def get_property(self, prop_code: str):
        """Get a property value by property code (e.g. 'PROP_MS_0' for temperature)."""
        return self._obj.GetPropertyValue(prop_code)

    def set_property(self, prop_code: str, value):
        """Set a property value by property code."""
        from DWSIM.Interfaces.Enums import PropertyType
        self._obj.SetPropertyValue(prop_code, value)

    def get_report(self, format_spec: str = "N4") -> str:
        """Get a text report for this object."""
        return str(self._obj.GetReport(None, None, format_spec))

    def __repr__(self):
        return f"<SimObject: {self.tag} ({self._obj.GetType().Name})>"


class MaterialStreamWrapper(SimulationObjectWrapper):
    """Extended wrapper for material streams with convenience methods.

    Uses property codes because pythonnet returns ISimulationObject,
    not IMaterialStream. Property codes:
        PROP_MS_0  = Temperature (K)
        PROP_MS_1  = Pressure (Pa)
        PROP_MS_2  = Mass Flow (kg/s)
        PROP_MS_3  = Molar Flow (mol/s)
        PROP_MS_4  = Volumetric Flow (m3/s)
        PROP_MS_6  = Specific Enthalpy (kJ/kg)
        PROP_MS_7  = Specific Entropy (kJ/[kg.K])
    """

    def _get_ms(self):
        """Get the object cast to IMaterialStream if possible."""
        try:
            from DWSIM.Interfaces import IMaterialStream
            return IMaterialStream(self._obj)
        except Exception:
            return self._obj

    @property
    def temperature(self) -> float:
        """Temperature in K."""
        return float(self._obj.GetPropertyValue("PROP_MS_0"))

    @property
    def pressure(self) -> float:
        """Pressure in Pa."""
        return float(self._obj.GetPropertyValue("PROP_MS_1"))

    @property
    def mass_flow(self) -> float:
        """Mass flow in kg/s."""
        return float(self._obj.GetPropertyValue("PROP_MS_2"))

    @property
    def molar_flow(self) -> float:
        """Molar flow in mol/s."""
        return float(self._obj.GetPropertyValue("PROP_MS_3"))

    def set_temperature(self, value: float):
        """Set temperature in K."""
        self._obj.SetPropertyValue("PROP_MS_0", float(value))

    def set_pressure(self, value: float):
        """Set pressure in Pa."""
        self._obj.SetPropertyValue("PROP_MS_1", float(value))

    def set_mass_flow(self, value: float):
        """Set mass flow in kg/s."""
        self._obj.SetPropertyValue("PROP_MS_2", float(value))

    def set_molar_flow(self, value: float):
        """Set molar flow in mol/s."""
        self._obj.SetPropertyValue("PROP_MS_3", float(value))

    def set_composition(self, composition: dict):
        """
        Set molar composition.

        Args:
            composition: Dict of {compound_name: mole_fraction}
                         Keys must match compounds added to the flowsheet.
        """
        from System import Array, Double

        # Build composition array in the order compounds were added
        comp_array = []
        for name in self._fw._compounds:
            comp_array.append(float(composition.get(name, 0.0)))

        arr = Array[Double](comp_array)
        ms = self._get_ms()
        try:
            ms.SetOverallComposition(arr)
        except AttributeError:
            # Fallback: set individual compound fractions via property codes
            for i, name in enumerate(self._fw._compounds):
                frac = composition.get(name, 0.0)
                self._obj.SetPropertyValue(f"PROP_MS_45_{i}", float(frac))

    def get_composition(self) -> dict:
        """Get molar composition as {compound_name: fraction}."""
        result = {}
        ms = self._get_ms()
        try:
            comp = ms.GetOverallComposition()
            for i, name in enumerate(self._fw._compounds):
                if i < len(comp):
                    result[name] = float(comp[i])
        except (AttributeError, Exception):
            for i, name in enumerate(self._fw._compounds):
                try:
                    result[name] = float(self._obj.GetPropertyValue(f"PROP_MS_45_{i}"))
                except Exception:
                    result[name] = 0.0
        return result

    def __repr__(self):
        try:
            return (f"<MaterialStream: {self.tag} "
                    f"T={self.temperature:.1f}K "
                    f"P={self.pressure:.0f}Pa "
                    f"F={self.mass_flow:.4f}kg/s>")
        except Exception:
            return f"<MaterialStream: {self.tag}>"


class DWSIMClient:
    """
    Main DWSIM headless client.

    Args:
        dll_dir: Path to directory containing DWSIM .NET assemblies.
                 In Docker, this is typically /output or /src/DWSIM.Automation/bin/Debug/net8.0
    """

    def __init__(self, dll_dir: str):
        self._dll_dir = str(dll_dir)
        _init_clr(self._dll_dir)

        from DWSIM.Automation import Automation3
        self._auto = Automation3()

    @property
    def version(self) -> str:
        """Get DWSIM version string."""
        return str(self._auto.GetVersion())

    @property
    def available_compounds(self) -> list:
        """List all available compound names."""
        return [str(k) for k in self._auto.AvailableCompounds.Keys]

    @property
    def available_property_packages(self) -> list:
        """List all available property package names."""
        return [str(k) for k in self._auto.AvailablePropertyPackages.Keys]

    def create_flowsheet(self) -> FlowsheetWrapper:
        """Create a new empty flowsheet."""
        fs = self._auto.CreateFlowsheet()
        return FlowsheetWrapper(fs, self._auto)

    def load_flowsheet(self, filepath: str) -> FlowsheetWrapper:
        """Load a flowsheet from a .dwxml or .dwxmz file."""
        fs = self._auto.LoadFlowsheet2(filepath)
        return FlowsheetWrapper(fs, self._auto)

    def release(self):
        """Release DWSIM resources."""
        self._auto.ReleaseResources()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.release()
