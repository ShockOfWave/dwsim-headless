#!/bin/bash
# ============================================================================
# patch-headless-guards.sh (Tier 10)
# Adds #if !HEADLESS / #endif guards around desktop-UI-dependent code in
# DWSIM.Automation sources:
#
# Automation.cs:
#   1. Guard 'using DWSIM.UI.Desktop.Shared;' with #if !HEADLESS
#   2. Guard 'using DWSIM.SharedClassesCSharp.FilePicker.Windows;' with #if !HEADLESS
#   3. Wrap entire 'Automation' class (class 1: uses WinForms FormMain)
#   4. Wrap entire 'Automation2' class (class 2: uses Eto.Forms Application)
#   (Automation3 class kept intact -- headless-compatible)
#
# Flowsheet2.cs:
#   1. Guard 'using unvell.ReoGrid;' imports with #if !HEADLESS
#   2. Replace ReoGrid-dependent IWorkbook field with #if !HEADLESS conditional
#   3. Replace ReoGrid-dependent Init() body with conditional
#   4. Replace all ReoGrid-dependent lambdas/methods with conditional stubs
# ============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: patch-headless-guards.sh <dwsim-source-root>}"
AUTO_DIR="$DWSIM_ROOT/DWSIM.Automation"
export AUTO_CS="$AUTO_DIR/Automation.cs"
export FS2_CS="$AUTO_DIR/Flowsheet2.cs"

echo "=== Patching DWSIM.Automation sources for HEADLESS mode ==="

if [ ! -f "$AUTO_CS" ]; then
    echo "ERROR: Automation.cs not found at $AUTO_CS"
    exit 1
fi
if [ ! -f "$FS2_CS" ]; then
    echo "ERROR: Flowsheet2.cs not found at $FS2_CS"
    exit 1
fi

# ============================================================================
# PART 1: Patch Automation.cs
# ============================================================================
echo ""
echo "--- Patching Automation.cs ---"

python3 << 'PYEOF'
import sys
import os

auto_path = os.environ.get('AUTO_CS', '')
if not auto_path:
    print("ERROR: AUTO_CS not set", file=sys.stderr)
    sys.exit(1)

with open(auto_path, 'r', encoding='utf-8-sig') as f:
    content = f.read()

lines = content.split('\n')
result = []
i = 0
changes = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # ----------------------------------------------------------------
    # 1. Guard 'using DWSIM.UI.Desktop.Shared;'
    # ----------------------------------------------------------------
    if stripped == 'using DWSIM.UI.Desktop.Shared;':
        result.append('#if !HEADLESS')
        result.append(line)
        result.append('#endif')
        changes += 1
        i += 1
        continue

    # ----------------------------------------------------------------
    # 2. Guard 'using DWSIM.SharedClassesCSharp.FilePicker.Windows;'
    # ----------------------------------------------------------------
    if stripped == 'using DWSIM.SharedClassesCSharp.FilePicker.Windows;':
        result.append('#if !HEADLESS')
        result.append(line)
        result.append('#endif')
        changes += 1
        i += 1
        continue

    # ----------------------------------------------------------------
    # 3. Wrap entire Automation class (class 1)
    #    Starts at: [Guid("37437090-...")]  (line before class declaration)
    #    The class declaration is: public class Automation : AutomationInterface
    #    Ends at the closing brace of the class
    #    We look for the [Guid] attribute before "public class Automation :"
    # ----------------------------------------------------------------
    if stripped.startswith('[Guid("37437090'):
        indent = line[:len(line) - len(line.lstrip())]
        result.append(indent + '#if !HEADLESS')
        result.append(line)
        # Now find the end of this class -- track brace depth
        # The class opening { comes after the class declaration line
        i += 1
        brace_depth = 0
        found_class_open = False
        while i < len(lines):
            cur = lines[i]
            cur_stripped = cur.strip()

            # Count braces
            for ch in cur_stripped:
                if ch == '{':
                    brace_depth += 1
                    found_class_open = True
                elif ch == '}':
                    brace_depth -= 1

            result.append(cur)

            # Class ends when we reach brace_depth == 0 after having opened
            if found_class_open and brace_depth == 0:
                result.append(indent + '#endif')
                changes += 1
                i += 1
                break
            i += 1
        continue

    # ----------------------------------------------------------------
    # 4. Wrap entire Automation2 class (class 2)
    #    Starts at: [Guid("22694b87-...")]
    #    Ends at closing brace of class
    # ----------------------------------------------------------------
    if stripped.startswith('[Guid("22694b87'):
        indent = line[:len(line) - len(line.lstrip())]
        result.append(indent + '#if !HEADLESS')
        result.append(line)
        i += 1
        brace_depth = 0
        found_class_open = False
        while i < len(lines):
            cur = lines[i]
            cur_stripped = cur.strip()

            for ch in cur_stripped:
                if ch == '{':
                    brace_depth += 1
                    found_class_open = True
                elif ch == '}':
                    brace_depth -= 1

            result.append(cur)

            if found_class_open and brace_depth == 0:
                result.append(indent + '#endif')
                changes += 1
                i += 1
                break
            i += 1
        continue

    # No match -- pass through
    result.append(line)
    i += 1

output = '\n'.join(result)
with open(auto_path, 'w', encoding='utf-8') as f:
    f.write(output)

print(f"  Applied {changes} HEADLESS guards to Automation.cs")
if changes < 4:
    print(f"  WARNING: Expected 4 guards, only applied {changes}", file=sys.stderr)
PYEOF

# ============================================================================
# PART 2: Patch Flowsheet2.cs
# ============================================================================
echo ""
echo "--- Patching Flowsheet2.cs ---"

python3 << 'PYEOF'
import sys
import os
import re

fs2_path = os.environ.get('FS2_CS', '')
if not fs2_path:
    print("ERROR: FS2_CS not set", file=sys.stderr)
    sys.exit(1)

with open(fs2_path, 'r', encoding='utf-8-sig') as f:
    content = f.read()

changes = 0

# ----------------------------------------------------------------
# 1. Guard ReoGrid using statements
#    Replace:
#      using unvell.ReoGrid;
#      using unvell.ReoGrid.DataFormat;
#      using unvell.ReoGrid.Formula;
#    With:
#      #if !HEADLESS
#      using unvell.ReoGrid;
#      using unvell.ReoGrid.DataFormat;
#      using unvell.ReoGrid.Formula;
#      #endif
# ----------------------------------------------------------------
old_usings = """using unvell.ReoGrid;
using unvell.ReoGrid.DataFormat;
using unvell.ReoGrid.Formula;"""

new_usings = """#if !HEADLESS
using unvell.ReoGrid;
using unvell.ReoGrid.DataFormat;
using unvell.ReoGrid.Formula;
#endif"""

if old_usings in content:
    content = content.replace(old_usings, new_usings)
    changes += 1
    print("  [1] Guarded ReoGrid using statements")
else:
    print("  WARNING: ReoGrid using block not found as expected", file=sys.stderr)

# ----------------------------------------------------------------
# 2. Replace IWorkbook field with conditional
#    Old: private IWorkbook Spreadsheet;
#    New: #if !HEADLESS ... #else object Spreadsheet; #endif
# ----------------------------------------------------------------
old_field = "        private IWorkbook Spreadsheet;"
new_field = """#if !HEADLESS
        private IWorkbook Spreadsheet;
#else
        private object Spreadsheet;
#endif"""

if old_field in content:
    content = content.replace(old_field, new_field)
    changes += 1
    print("  [2] Guarded IWorkbook Spreadsheet field")
else:
    print("  WARNING: IWorkbook Spreadsheet field not found", file=sys.stderr)

# ----------------------------------------------------------------
# 3. Replace the constructor body -- wrap all ReoGrid-dependent
#    lambda/delegate assignments with #if !HEADLESS and provide
#    headless stubs.
#
#    The constructor sets:
#      GetSpreadsheetObjectFunc = ...
#      LoadSpreadsheetData = ...
#      SaveSpreadsheetData = ...
#      RetrieveSpreadsheetData = ...
#      RetrieveSpreadsheetFormat = ...
#
#    All of these use Spreadsheet (IWorkbook) and ReoGrid types.
#    In headless mode, provide no-op stubs.
# ----------------------------------------------------------------

# Find the constructor and its ReoGrid-dependent block
# The constructor starts after the opening brace
# We need to wrap from GetSpreadsheetObjectFunc through RetrieveSpreadsheetFormat

old_ctor_block = """            GetSpreadsheetObjectFunc = () => Spreadsheet;

            LoadSpreadsheetData = new Action<XDocument>((xdoc) =>
            {
                if (xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet") != null)
                {
                    var rgfdataelement = xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData");
                    if (rgfdataelement != null)
                    {
                        string rgfdata = xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData").Value;
                        rgfdata = rgfdata.Replace("Calibri", "Arial").Replace("10.25", "10");
                        Dictionary<string, string> sdict = new Dictionary<string, string>();
                        sdict = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, string>>(rgfdata);
                        Spreadsheet.RemoveWorksheet(0);
                        foreach (var item in sdict)
                        {
                            var tmpfile = SharedClasses.Utility.GetTempFileName();
                            var sheet = Spreadsheet.CreateWorksheet(item.Key);
                            Spreadsheet.Worksheets.Add(sheet);
                            var xmldoc = Newtonsoft.Json.JsonConvert.DeserializeXmlNode(item.Value);
                            xmldoc.Save(tmpfile);
                            sheet.LoadRGF(tmpfile);
                            File.Delete(tmpfile);
                        }
                    }
                }
            });

            SaveSpreadsheetData = new Action<XDocument>((xdoc) =>
            {
                xdoc.Element("DWSIM_Simulation_Data").Add(new XElement("Spreadsheet"));
                xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Add(new XElement("RGFData"));
                var tmpfile = SharedClasses.Utility.GetTempFileName();
                Dictionary<string, string> sdict = new Dictionary<string, string>();
                foreach (var sheet in Spreadsheet.Worksheets)
                {
                    var tmpfile2 = SharedClasses.Utility.GetTempFileName();
                    sheet.SaveRGF(tmpfile2);
                    var xmldoc = new XmlDocument();
                    xmldoc.Load(tmpfile2);
                    sdict.Add(sheet.Name, Newtonsoft.Json.JsonConvert.SerializeXmlNode(xmldoc));
                    File.Delete(tmpfile2);
                }
                xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData").Value = Newtonsoft.Json.JsonConvert.SerializeObject(sdict);
            });

            RetrieveSpreadsheetData = new Func<string, List<string[]>>((range) =>
            {
                return GetSpreadsheetDataFromRange(range);
            });

            RetrieveSpreadsheetFormat = new Func<string, List<string[]>>((range) =>
            {
                return GetSpreadsheetFormatFromRange(range);
            });"""

new_ctor_block = """#if !HEADLESS
            GetSpreadsheetObjectFunc = () => Spreadsheet;

            LoadSpreadsheetData = new Action<XDocument>((xdoc) =>
            {
                if (xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet") != null)
                {
                    var rgfdataelement = xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData");
                    if (rgfdataelement != null)
                    {
                        string rgfdata = xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData").Value;
                        rgfdata = rgfdata.Replace("Calibri", "Arial").Replace("10.25", "10");
                        Dictionary<string, string> sdict = new Dictionary<string, string>();
                        sdict = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, string>>(rgfdata);
                        Spreadsheet.RemoveWorksheet(0);
                        foreach (var item in sdict)
                        {
                            var tmpfile = SharedClasses.Utility.GetTempFileName();
                            var sheet = Spreadsheet.CreateWorksheet(item.Key);
                            Spreadsheet.Worksheets.Add(sheet);
                            var xmldoc = Newtonsoft.Json.JsonConvert.DeserializeXmlNode(item.Value);
                            xmldoc.Save(tmpfile);
                            sheet.LoadRGF(tmpfile);
                            File.Delete(tmpfile);
                        }
                    }
                }
            });

            SaveSpreadsheetData = new Action<XDocument>((xdoc) =>
            {
                xdoc.Element("DWSIM_Simulation_Data").Add(new XElement("Spreadsheet"));
                xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Add(new XElement("RGFData"));
                var tmpfile = SharedClasses.Utility.GetTempFileName();
                Dictionary<string, string> sdict = new Dictionary<string, string>();
                foreach (var sheet in Spreadsheet.Worksheets)
                {
                    var tmpfile2 = SharedClasses.Utility.GetTempFileName();
                    sheet.SaveRGF(tmpfile2);
                    var xmldoc = new XmlDocument();
                    xmldoc.Load(tmpfile2);
                    sdict.Add(sheet.Name, Newtonsoft.Json.JsonConvert.SerializeXmlNode(xmldoc));
                    File.Delete(tmpfile2);
                }
                xdoc.Element("DWSIM_Simulation_Data").Element("Spreadsheet").Element("RGFData").Value = Newtonsoft.Json.JsonConvert.SerializeObject(sdict);
            });

            RetrieveSpreadsheetData = new Func<string, List<string[]>>((range) =>
            {
                return GetSpreadsheetDataFromRange(range);
            });

            RetrieveSpreadsheetFormat = new Func<string, List<string[]>>((range) =>
            {
                return GetSpreadsheetFormatFromRange(range);
            });
#else
            // Headless mode: spreadsheet functionality disabled (ReoGrid requires WinForms)
            GetSpreadsheetObjectFunc = () => null;

            LoadSpreadsheetData = new Action<XDocument>((xdoc) => { });

            SaveSpreadsheetData = new Action<XDocument>((xdoc) => { });

            RetrieveSpreadsheetData = new Func<string, List<string[]>>((range) =>
            {
                return new List<string[]>();
            });

            RetrieveSpreadsheetFormat = new Func<string, List<string[]>>((range) =>
            {
                return new List<string[]>();
            });
#endif"""

if old_ctor_block in content:
    content = content.replace(old_ctor_block, new_ctor_block)
    changes += 1
    print("  [3] Guarded constructor spreadsheet lambdas with headless stubs")
else:
    print("  WARNING: Constructor spreadsheet block not found as expected", file=sys.stderr)

# ----------------------------------------------------------------
# 4. Guard the two ReoGrid-dependent helper methods:
#    GetSpreadsheetDataFromRange and GetSpreadsheetFormatFromRange
#    These use Spreadsheet as IWorkbook, RangePosition, CellDataFormatFlag, etc.
# ----------------------------------------------------------------

old_helpers = """        private List<string[]> GetSpreadsheetDataFromRange(string range)
        {

            var list = new List<string[]>();
            var slist = new List<string>();

            var rdata = Spreadsheet.Worksheets[0].GetRangeData(new RangePosition(range));

            for (var i = 0; i < rdata.GetLength(0); i++)
            {
                slist = new List<string>();
                for (var j = 0; j < rdata.GetLength(1); j++)
                {
                    slist.Add(rdata[i, j] != null ? rdata[i, j].ToString() : "");
                }
                list.Add(slist.ToArray());
            }

            return list;
        }

        private List<string[]> GetSpreadsheetFormatFromRange(string range)
        {

            var list = new List<string[]>();
            var slist = new List<string>();

            var rdata = Spreadsheet.Worksheets[0].GetRangeData(new RangePosition(range));

            for (var i = 0; i < rdata.GetLength(0); i++)
            {
                slist = new List<string>();
                for (var j = 0; j < rdata.GetLength(1); j++)
                {
                    var format = Spreadsheet.Worksheets[0].Cells[i, j].DataFormat;
                    if (format == CellDataFormatFlag.Number)
                    {
                        var args = (NumberDataFormatter.NumberFormatArgs)(Spreadsheet.Worksheets[0].Cells[i, j].DataFormatArgs);
                        slist.Add("N" + args.DecimalPlaces);
                    }
                    else
                    {
                        slist.Add("");
                    }
                }
                list.Add(slist.ToArray());
            }

            return list;
        }"""

new_helpers = """#if !HEADLESS
        private List<string[]> GetSpreadsheetDataFromRange(string range)
        {

            var list = new List<string[]>();
            var slist = new List<string>();

            var rdata = Spreadsheet.Worksheets[0].GetRangeData(new RangePosition(range));

            for (var i = 0; i < rdata.GetLength(0); i++)
            {
                slist = new List<string>();
                for (var j = 0; j < rdata.GetLength(1); j++)
                {
                    slist.Add(rdata[i, j] != null ? rdata[i, j].ToString() : "");
                }
                list.Add(slist.ToArray());
            }

            return list;
        }

        private List<string[]> GetSpreadsheetFormatFromRange(string range)
        {

            var list = new List<string[]>();
            var slist = new List<string>();

            var rdata = Spreadsheet.Worksheets[0].GetRangeData(new RangePosition(range));

            for (var i = 0; i < rdata.GetLength(0); i++)
            {
                slist = new List<string>();
                for (var j = 0; j < rdata.GetLength(1); j++)
                {
                    var format = Spreadsheet.Worksheets[0].Cells[i, j].DataFormat;
                    if (format == CellDataFormatFlag.Number)
                    {
                        var args = (NumberDataFormatter.NumberFormatArgs)(Spreadsheet.Worksheets[0].Cells[i, j].DataFormatArgs);
                        slist.Add("N" + args.DecimalPlaces);
                    }
                    else
                    {
                        slist.Add("");
                    }
                }
                list.Add(slist.ToArray());
            }

            return list;
        }
#endif"""

if old_helpers in content:
    content = content.replace(old_helpers, new_helpers)
    changes += 1
    print("  [4] Guarded GetSpreadsheetDataFromRange and GetSpreadsheetFormatFromRange")
else:
    print("  WARNING: Helper methods block not found as expected", file=sys.stderr)

# ----------------------------------------------------------------
# 5. Guard SetCustomSpreadsheetFunctions method
#    Uses FormulaExtension, Evaluator, and cell/worksheet ReoGrid types
# ----------------------------------------------------------------

old_custom_funcs = """        private void SetCustomSpreadsheetFunctions()
        {

            FormulaExtension.CustomFunctions["GETNAME"] = (cell, args) =>
            {
                try
                {
                    return SimulationObjects[args[0].ToString()].GraphicObject.Tag;
                }
                catch (Exception ex)
                {
                    return "ERROR: " + ex.Message;
                }
            };

            FormulaExtension.CustomFunctions["GETPROPVAL"] = (cell, args) =>
            {
                if (args.Length == 2)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GetPropertyValue(args[1].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else if (args.Length == 3)
                {
                    try
                    {
                        var obj = SimulationObjects[args[0].ToString()];
                        var val = obj.GetPropertyValue(args[1].ToString());
                        return General.ConvertUnits(double.Parse(val.ToString()), obj.GetPropertyUnit(args[1].ToString()), args[2].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["SETPROPVAL"] = (cell, args) =>
            {
                if (args.Length == 3)
                {
                    try
                    {
                        var ws = cell.Worksheet;
                        var wcell = ws.Cells[ws.RowCount - 1, ws.ColumnCount - 1];
                        wcell.Data = null;
                        wcell.Formula = args[2].ToString().Trim('"');
                        Evaluator.Evaluate(wcell);
                        var val = wcell.Data;
                        if (wcell.Data == null)
                        {
                            val = wcell.Formula;
                        }
                        SimulationObjects[args[0].ToString()].SetPropertyValue(args[1].ToString(), val);
                        wcell.Formula = null;
                        wcell.Data = null;
                        return string.Format("EXPORT OK [{0}, {1} = {2}]", SimulationObjects[args[0].ToString()].GraphicObject.Tag, args[1].ToString(), val);
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else if (args.Length == 4)
                {
                    try
                    {
                        var obj = SimulationObjects[args[0].ToString()];
                        var prop = args[1].ToString();
                        var ws = cell.Worksheet;
                        var wcell = ws.Cells[ws.RowCount - 1, ws.ColumnCount - 1];
                        wcell.Formula = args[2].ToString().Trim('"');
                        Evaluator.Evaluate(wcell);
                        var val = wcell.Data;
                        wcell.Formula = "";
                        wcell.Data = "";
                        var units = args[3].ToString();
                        var newval = General.ConvertUnits(double.Parse(val.ToString()), units, obj.GetPropertyUnit(prop));
                        obj.SetPropertyValue(prop, newval);
                        return string.Format("EXPORT OK [{0}, {1} = {2} {3}]", obj.GraphicObject.Tag, prop, val, units);
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETPROPUNITS"] = (cell, args) =>
            {
                if (args.Length == 2)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GetPropertyUnit(args[1].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETOBJID"] = (cell, args) =>
            {
                if (args.Length == 1)
                {
                    try
                    {
                        return GetFlowsheetSimulationObject(args[0].ToString()).Name;
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETOBJNAME"] = (cell, args) =>
            {
                if (args.Length == 1)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GraphicObject.Tag;
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };
        }"""

new_custom_funcs = """#if !HEADLESS
        private void SetCustomSpreadsheetFunctions()
        {

            FormulaExtension.CustomFunctions["GETNAME"] = (cell, args) =>
            {
                try
                {
                    return SimulationObjects[args[0].ToString()].GraphicObject.Tag;
                }
                catch (Exception ex)
                {
                    return "ERROR: " + ex.Message;
                }
            };

            FormulaExtension.CustomFunctions["GETPROPVAL"] = (cell, args) =>
            {
                if (args.Length == 2)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GetPropertyValue(args[1].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else if (args.Length == 3)
                {
                    try
                    {
                        var obj = SimulationObjects[args[0].ToString()];
                        var val = obj.GetPropertyValue(args[1].ToString());
                        return General.ConvertUnits(double.Parse(val.ToString()), obj.GetPropertyUnit(args[1].ToString()), args[2].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["SETPROPVAL"] = (cell, args) =>
            {
                if (args.Length == 3)
                {
                    try
                    {
                        var ws = cell.Worksheet;
                        var wcell = ws.Cells[ws.RowCount - 1, ws.ColumnCount - 1];
                        wcell.Data = null;
                        wcell.Formula = args[2].ToString().Trim('"');
                        Evaluator.Evaluate(wcell);
                        var val = wcell.Data;
                        if (wcell.Data == null)
                        {
                            val = wcell.Formula;
                        }
                        SimulationObjects[args[0].ToString()].SetPropertyValue(args[1].ToString(), val);
                        wcell.Formula = null;
                        wcell.Data = null;
                        return string.Format("EXPORT OK [{0}, {1} = {2}]", SimulationObjects[args[0].ToString()].GraphicObject.Tag, args[1].ToString(), val);
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else if (args.Length == 4)
                {
                    try
                    {
                        var obj = SimulationObjects[args[0].ToString()];
                        var prop = args[1].ToString();
                        var ws = cell.Worksheet;
                        var wcell = ws.Cells[ws.RowCount - 1, ws.ColumnCount - 1];
                        wcell.Formula = args[2].ToString().Trim('"');
                        Evaluator.Evaluate(wcell);
                        var val = wcell.Data;
                        wcell.Formula = "";
                        wcell.Data = "";
                        var units = args[3].ToString();
                        var newval = General.ConvertUnits(double.Parse(val.ToString()), units, obj.GetPropertyUnit(prop));
                        obj.SetPropertyValue(prop, newval);
                        return string.Format("EXPORT OK [{0}, {1} = {2} {3}]", obj.GraphicObject.Tag, prop, val, units);
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETPROPUNITS"] = (cell, args) =>
            {
                if (args.Length == 2)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GetPropertyUnit(args[1].ToString());
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETOBJID"] = (cell, args) =>
            {
                if (args.Length == 1)
                {
                    try
                    {
                        return GetFlowsheetSimulationObject(args[0].ToString()).Name;
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };

            FormulaExtension.CustomFunctions["GETOBJNAME"] = (cell, args) =>
            {
                if (args.Length == 1)
                {
                    try
                    {
                        return SimulationObjects[args[0].ToString()].GraphicObject.Tag;
                    }
                    catch (Exception ex)
                    {
                        return "ERROR: " + ex.Message;
                    }
                }
                else
                    return "INVALID ARGS";
            };
        }
#else
        private void SetCustomSpreadsheetFunctions()
        {
            // Headless mode: spreadsheet custom functions not available (ReoGrid requires WinForms)
        }
#endif"""

if old_custom_funcs in content:
    content = content.replace(old_custom_funcs, new_custom_funcs)
    changes += 1
    print("  [5] Guarded SetCustomSpreadsheetFunctions method")
else:
    print("  WARNING: SetCustomSpreadsheetFunctions block not found as expected", file=sys.stderr)

# ----------------------------------------------------------------
# 6. Guard Init() method -- replace ReoGrid initialization
#    Old:
#        Spreadsheet = unvell.ReoGrid.ReoGridControl.CreateMemoryWorkbook();
#        SetCustomSpreadsheetFunctions();
#    New: conditional
# ----------------------------------------------------------------

old_init = """        public void Init()
        {

            Initialize();

            Spreadsheet = unvell.ReoGrid.ReoGridControl.CreateMemoryWorkbook();

            SetCustomSpreadsheetFunctions();

        }"""

new_init = """        public void Init()
        {

            Initialize();

#if !HEADLESS
            Spreadsheet = unvell.ReoGrid.ReoGridControl.CreateMemoryWorkbook();
#endif

            SetCustomSpreadsheetFunctions();

        }"""

if old_init in content:
    content = content.replace(old_init, new_init)
    changes += 1
    print("  [6] Guarded Init() ReoGrid initialization")
else:
    print("  WARNING: Init() block not found as expected", file=sys.stderr)

# Write result
with open(fs2_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n  Applied {changes} HEADLESS guards to Flowsheet2.cs")
if changes < 6:
    print(f"  WARNING: Expected 6 guards, only applied {changes}", file=sys.stderr)
PYEOF

echo ""
echo "=== DWSIM.Automation source patching complete ==="
