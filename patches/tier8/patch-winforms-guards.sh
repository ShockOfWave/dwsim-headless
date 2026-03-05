#!/bin/bash
# ============================================================================
# patch-winforms-guards.sh
# Adds #If Not HEADLESS / #End If guards around WinForms-dependent code
# in DWSIM.UnitOperations VB.NET source files.
#
# Strategy:
#   1. Wrap single-line WinForms imports with #If Not HEADLESS guards
#   2. Wrap EditingForm field declarations with guards
#   3. Wrap DisplayEditForm/UpdateEditForm/GetEditingForm/CloseEditForm methods
#   4. Wrap MessageBox.Show calls
#   5. Special handling for Spreadsheet.vb (NetOffice) and other edge cases
# ============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: patch-winforms-guards.sh <dwsim-source-root>}"
UO_DIR="$DWSIM_ROOT/DWSIM.UnitOperations"

echo "=== Patching WinForms guards in DWSIM.UnitOperations ==="

# ============================================================================
# Helper function: wrap a single line matching a pattern with #If guards
# Usage: wrap_import_line <file> <pattern>
# ============================================================================
wrap_import_line() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        sed -i.bak "s|^\(${pattern}.*\)$|#If Not HEADLESS Then\n\1\n#End If|" "$file"
        rm -f "$file.bak"
    fi
}

# ============================================================================
# Helper: wrap a line containing a specific string
# ============================================================================
wrap_line_containing() {
    local file="$1"
    local search="$2"
    if grep -q "$search" "$file" 2>/dev/null; then
        # Use perl for reliable multiline handling
        perl -i -pe "
            if (/\Q${search}\E/ && !/^#If/) {
                \$_ = \"#If Not HEADLESS Then\n\" . \$_ . \"#End If\n\";
            }
        " "$file"
    fi
}

# ============================================================================
# Helper: Use Python to wrap methods (multi-line blocks)
# Wraps GetEditingForm, DisplayEditForm, UpdateEditForm, CloseEditForm
# ============================================================================
wrap_form_methods() {
    local file="$1"
    python3 -c "
import re, sys

# Try utf-8-sig first, fall back to latin-1 for files with special characters
try:
    with open('$file', 'r', encoding='utf-8-sig') as f:
        content = f.read()
    write_enc = 'utf-8'
except UnicodeDecodeError:
    with open('$file', 'r', encoding='latin-1') as f:
        content = f.read()
    write_enc = 'latin-1'

lines = content.split('\n')
result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Detect form method signatures
    is_form_method = False
    for sig in ['Sub DisplayEditForm()', 'Sub UpdateEditForm()',
                'Function GetEditingForm()', 'Sub CloseEditForm()',
                'Sub DisplayDynamicsEditForm()']:
        if sig in stripped:
            is_form_method = True
            break

    if is_form_method:
        # Find the end of this method (indentation-aware)
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        method_lines = [line]
        end_keyword = ''
        i += 1
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            method_lines.append(ml)
            i += 1
            if (ms == 'End Sub' or ms == 'End Function') and ml_indent <= indent:
                end_keyword = ms
                break

        # Insert #If Not HEADLESS before, add #Else stub, #End If after
        result.append(indent_str + '#If Not HEADLESS Then')
        result.extend(method_lines)
        result.append(indent_str + '#Else')
        # Generate stub based on method type
        if 'Function GetEditingForm' in stripped:
            result.append(indent_str + '    Public Overrides Function GetEditingForm() As Object')
            result.append(indent_str + '        Return Nothing')
            result.append(indent_str + '    End Function')
        elif 'Sub DisplayEditForm' in stripped:
            result.append(indent_str + '    Public Overrides Sub DisplayEditForm()')
            result.append(indent_str + '    End Sub')
        elif 'Sub UpdateEditForm' in stripped:
            result.append(indent_str + '    Public Overrides Sub UpdateEditForm()')
            result.append(indent_str + '    End Sub')
        elif 'Sub CloseEditForm' in stripped:
            result.append(indent_str + '    Public Overrides Sub CloseEditForm()')
            result.append(indent_str + '    End Sub')
        elif 'Sub DisplayDynamicsEditForm' in stripped:
            result.append(indent_str + '    Public Overrides Sub DisplayDynamicsEditForm()')
            result.append(indent_str + '    End Sub')
        result.append(indent_str + '#End If')
    else:
        result.append(line)
        i += 1

with open('$file', 'w', encoding=write_enc) as f:
    f.write('\n'.join(result))
" 2>&1 || echo "  WARNING: Python method wrapping failed for $file"
}

# ============================================================================
# Phase 1: Handle files with Imports System.Windows.Forms
# Replace the import line with a guarded version
# ============================================================================
echo ""
echo "--- Phase 1: Guarding 'Imports System.Windows.Forms' ---"

FILES_WITH_WINFORMS_IMPORT=(
    "BaseClasses/CapeOpen.vb"
    "CAPE-OPEN/CustomUO_CO.vb"
    "LogicalBlocks/Adjust.vb"
    "LogicalBlocks/EnergyRecycle.vb"
    "LogicalBlocks/Recycle.vb"
    "LogicalBlocks/Spec.vb"
    "UnitOperations/ComponentSeparator.vb"
    "UnitOperations/Cooler.vb"
    "UnitOperations/Expander.vb"
    "UnitOperations/Filter.vb"
    "UnitOperations/FlowsheetUO.vb"
    "UnitOperations/Heater.vb"
    "UnitOperations/HeatExchanger.vb"
    "UnitOperations/Mixer.vb"
    "UnitOperations/OrificePlate.vb"
    "UnitOperations/Pipe.vb"
    "UnitOperations/Pump.vb"
    "UnitOperations/PythonScriptUO.vb"
    "UnitOperations/RigorousColumn.vb"
    "UnitOperations/ShortcutColumn.vb"
    "UnitOperations/SolidsSeparator.vb"
    "UnitOperations/Spreadsheet.vb"
    "UnitOperations/Tank.vb"
)

for relpath in "${FILES_WITH_WINFORMS_IMPORT[@]}"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ]; then
        echo "  Guarding import in $relpath"
        perl -i -pe '
            if (/^Imports System\.Windows\.Forms\s*$/ && !/^#If/) {
                $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
            }
        ' "$file"
    fi
done

# ============================================================================
# Phase 2: Handle NetOffice imports (Spreadsheet.vb, Valve.vb)
# ============================================================================
echo ""
echo "--- Phase 2: Guarding NetOffice imports ---"

# Spreadsheet.vb: wrap both NetOffice import lines together
SPREADSHEET="$UO_DIR/UnitOperations/Spreadsheet.vb"
if [ -f "$SPREADSHEET" ]; then
    echo "  Guarding NetOffice imports in Spreadsheet.vb"
    perl -i -pe '
        if (/^Imports Excel = NetOffice/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_;
        }
        if (/^Imports NetOffice\.ExcelApi\.Enums/ && !/^#End If/) {
            $_ = $_ . "#End If\n";
        }
    ' "$SPREADSHEET"
fi

# Valve.vb: wrap single NetOffice import
VALVE="$UO_DIR/UnitOperations/Valve.vb"
if [ -f "$VALVE" ]; then
    echo "  Guarding NetOffice import in Valve.vb"
    perl -i -pe '
        if (/^Imports NetOffice\.ExcelApi\s*$/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$VALVE"
fi

# ============================================================================
# Phase 3: Guard EditingForm field declarations
# Pattern: <NonSerialized> <Xml.Serialization.XmlIgnore> Public f As EditingForm_*
# ============================================================================
echo ""
echo "--- Phase 3: Guarding EditingForm field declarations ---"

# Find all files with EditingForm field declarations (outside EditingForms/)
ALL_FORM_FIELD_FILES=(
    "Controllers/PIDController.vb"
    "Controllers/PythonController.vb"
    "EnergyStream/Streams.vb"
    "Indicators/AnalogGauge.vb"
    "Indicators/DigitalGauge.vb"
    "Indicators/LevelGauge.vb"
    "Inputs/Input.vb"
    "LogicalBlocks/Adjust.vb"
    "LogicalBlocks/EnergyRecycle.vb"
    "LogicalBlocks/Recycle.vb"
    "LogicalBlocks/Spec.vb"
    "Switches/Switch.vb"
    "Reactors/Conversion.vb"
    "Reactors/CSTR.vb"
    "Reactors/Equilibrium.vb"
    "Reactors/Gibbs.vb"
    "Reactors/PFR.vb"
    "Reactors/ReaktoroGibbs.vb"
    "UnitOperations/CapeOpenUO.vb"
    "UnitOperations/CleanEnergies/HydroelectricTurbine.vb"
    "UnitOperations/CleanEnergies/PEMFuelCellUnitOpBase.vb"
    "UnitOperations/CleanEnergies/SolarPanel.vb"
    "UnitOperations/CleanEnergies/WaterElectrolyzer.vb"
    "UnitOperations/CleanEnergies/WindTurbine.vb"
    "UnitOperations/ComponentSeparator.vb"
    "UnitOperations/Compressor.vb"
    "UnitOperations/Cooler.vb"
    "UnitOperations/Expander.vb"
    "UnitOperations/Filter.vb"
    "UnitOperations/FlowsheetUO.vb"
    "UnitOperations/Heater.vb"
    "UnitOperations/HeatExchanger.vb"
    "UnitOperations/Mixer.vb"
    "UnitOperations/OrificePlate.vb"
    "UnitOperations/Pipe.vb"
    "UnitOperations/Pump.vb"
    "UnitOperations/PythonScriptUO.vb"
    "UnitOperations/RigorousColumn.vb"
    "UnitOperations/ShortcutColumn.vb"
    "UnitOperations/SolidsSeparator.vb"
    "UnitOperations/Splitter.vb"
    "UnitOperations/Spreadsheet.vb"
    "UnitOperations/Tank.vb"
    "UnitOperations/Valve.vb"
    "UnitOperations/Vessel.vb"
)

for relpath in "${ALL_FORM_FIELD_FILES[@]}"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ]; then
        if grep -q 'Public f As EditingForm_\|Public fd As EditingForm_' "$file" 2>/dev/null; then
            echo "  Guarding form field in $relpath"
            perl -i -pe '
                if (/Public f As EditingForm_/ && !/^#If/) {
                    $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
                }
                if (/Public fd As EditingForm_/ && !/^#If/) {
                    $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
                }
            ' "$file"
        fi
    fi
done

# ============================================================================
# Phase 4: Guard form methods (DisplayEditForm, UpdateEditForm,
#           GetEditingForm, CloseEditForm)
# These are multi-line methods — use Python for reliable wrapping
# ============================================================================
echo ""
echo "--- Phase 4: Guarding form methods (multi-line) ---"

# All files that potentially have these methods
ALL_METHOD_FILES=(
    "Controllers/PIDController.vb"
    "Controllers/PythonController.vb"
    "EnergyStream/Streams.vb"
    "Indicators/AnalogGauge.vb"
    "Indicators/DigitalGauge.vb"
    "Indicators/LevelGauge.vb"
    "Inputs/Input.vb"
    "LogicalBlocks/Adjust.vb"
    "LogicalBlocks/EnergyRecycle.vb"
    "LogicalBlocks/Recycle.vb"
    "LogicalBlocks/Spec.vb"
    "Switches/Switch.vb"
    "Reactors/Conversion.vb"
    "Reactors/CSTR.vb"
    "Reactors/Equilibrium.vb"
    "Reactors/Gibbs.vb"
    "Reactors/PFR.vb"
    "Reactors/ReaktoroGibbs.vb"
    "UnitOperations/CapeOpenUO.vb"
    "UnitOperations/CleanEnergies/HydroelectricTurbine.vb"
    "UnitOperations/CleanEnergies/PEMFuelCellUnitOpBase.vb"
    "UnitOperations/CleanEnergies/SolarPanel.vb"
    "UnitOperations/CleanEnergies/WaterElectrolyzer.vb"
    "UnitOperations/CleanEnergies/WindTurbine.vb"
    "UnitOperations/ComponentSeparator.vb"
    "UnitOperations/Compressor.vb"
    "UnitOperations/Cooler.vb"
    "UnitOperations/Expander.vb"
    "UnitOperations/Filter.vb"
    "UnitOperations/FlowsheetUO.vb"
    "UnitOperations/Heater.vb"
    "UnitOperations/HeatExchanger.vb"
    "UnitOperations/Mixer.vb"
    "UnitOperations/OrificePlate.vb"
    "UnitOperations/Pipe.vb"
    "UnitOperations/Pump.vb"
    "UnitOperations/PythonScriptUO.vb"
    "UnitOperations/ReliefValve.vb"
    "UnitOperations/RigorousColumn.vb"
    "UnitOperations/ShortcutColumn.vb"
    "UnitOperations/SolidsSeparator.vb"
    "UnitOperations/Splitter.vb"
    "UnitOperations/Spreadsheet.vb"
    "UnitOperations/Tank.vb"
    "UnitOperations/Valve.vb"
    "UnitOperations/Vessel.vb"
)

for relpath in "${ALL_METHOD_FILES[@]}"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ]; then
        if grep -q 'Sub DisplayEditForm\|Sub UpdateEditForm\|Function GetEditingForm\|Sub CloseEditForm' "$file" 2>/dev/null; then
            echo "  Wrapping form methods in $relpath"
            wrap_form_methods "$file"
        fi
    fi
done

# ============================================================================
# Phase 5: Guard standalone MessageBox.Show calls
# (in files that have MessageBox outside of already-guarded methods)
# ============================================================================
echo ""
echo "--- Phase 5: Guarding standalone MessageBox.Show calls ---"

# BaseClasses/CapeOpen.vb has System.Windows.Forms.MessageBox.Show
CAPEOPENBASE="$UO_DIR/BaseClasses/CapeOpen.vb"
if [ -f "$CAPEOPENBASE" ]; then
    echo "  Guarding MessageBox in BaseClasses/CapeOpen.vb"
    perl -i -pe '
        if (/System\.Windows\.Forms\.MessageBox\.Show/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$CAPEOPENBASE"
fi

# CAPE-OPEN/CustomUO_CO.vb has MessageBox.Show calls
CUSTOMUO_CO="$UO_DIR/CAPE-OPEN/CustomUO_CO.vb"
if [ -f "$CUSTOMUO_CO" ]; then
    echo "  Guarding MessageBox in CAPE-OPEN/CustomUO_CO.vb"
    perl -i -pe '
        if (/MessageBox\.Show/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$CUSTOMUO_CO"
fi

# UnitOperations/CapeOpenUO.vb has MessageBox.Show calls
CAPEOPENUO="$UO_DIR/UnitOperations/CapeOpenUO.vb"
if [ -f "$CAPEOPENUO" ]; then
    echo "  Guarding MessageBox in UnitOperations/CapeOpenUO.vb"
    perl -i -pe '
        if (/MessageBox\.Show/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$CAPEOPENUO"
fi

# UnitOperations/Pipe.vb has MessageBox.Show calls
PIPE="$UO_DIR/UnitOperations/Pipe.vb"
if [ -f "$PIPE" ]; then
    echo "  Guarding MessageBox in UnitOperations/Pipe.vb"
    perl -i -pe '
        if (/MessageBox\.Show/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$PIPE"
fi

# LogicalBlocks/EnergyRecycle.vb has MessageBox.Show (multi-line with _ continuation)
# Need to wrap the entire block that depends on MessageBox result
ENERGYRECYCLE="$UO_DIR/LogicalBlocks/EnergyRecycle.vb"
if [ -f "$ENERGYRECYCLE" ]; then
    echo "  Guarding MessageBox block in LogicalBlocks/EnergyRecycle.vb"
    python3 -c "
import sys

filepath = '$ENERGYRECYCLE'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    # Find 'Dim msgres' line that starts the MessageBox block
    if 'MessageBox.Show' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        # Include this line and all continuation lines (ending with _)
        result.append(line)
        while line.rstrip().endswith('_') or (i + 1 < len(lines) and lines[i+1].strip().startswith('MessageBoxButtons')):
            i += 1
            if i < len(lines):
                line = lines[i]
                result.append(line)
            else:
                break
        # Now include the if-block that uses msgres
        i += 1
        while i < len(lines):
            nextline = lines[i]
            ns = nextline.strip()
            result.append(nextline)
            if ns == 'End If' and len(nextline) - len(nextline.lstrip()) <= indent:
                break
            i += 1
        result.append(indent_str + '#End If\n')
        i += 1
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
print('  [OK] Wrapped MessageBox block in EnergyRecycle.vb')
"
fi

# UnitOperations/Spreadsheet.vb has MessageBox.Show calls
if [ -f "$SPREADSHEET" ]; then
    echo "  Guarding MessageBox in UnitOperations/Spreadsheet.vb"
    perl -i -pe '
        if (/MessageBox\.Show/ && !/^#If/) {
            $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
        }
    ' "$SPREADSHEET"
fi

# ============================================================================
# Phase 6: Special handling - Spreadsheet.vb NetOffice code blocks
# The entire Excel COM automation path is Windows-only and uses NetOffice.
# Wrap the relevant code sections with #If Not HEADLESS.
# ============================================================================
echo ""
echo "--- Phase 6: Wrapping NetOffice code blocks in Spreadsheet.vb ---"

if [ -f "$SPREADSHEET" ]; then
    echo "  Wrapping NetOffice Excel COM paths in Spreadsheet.vb"
    python3 -c "
import sys

try:
    with open('$SPREADSHEET', 'r', encoding='utf-8-sig') as f:
        content = f.read()
    write_enc = 'utf-8'
except UnicodeDecodeError:
    with open('$SPREADSHEET', 'r', encoding='latin-1') as f:
        content = f.read()
    write_enc = 'latin-1'

lines = content.split('\n')
result = []
in_netoffice_block = False
block_indent = ''
i = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Detect start of NetOffice block: 'If Not Calculator.IsRunningOnMono Then excelType'
    # or 'If Not Calculator.IsRunningOnMono And Not excelType Is Nothing Then'
    if ('Calculator.IsRunningOnMono' in stripped and 'excelType' in stripped and
        'Then' in stripped and not in_netoffice_block):
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]

        # Check if this is a single-line If (has code after 'Then')
        then_pos = stripped.rfind(' Then ')
        is_single_line = then_pos >= 0 and then_pos + 6 < len(stripped)

        if is_single_line:
            # Single-line If: just wrap this one line
            result.append(indent_str + '#If Not HEADLESS Then')
            result.append(line)
            result.append(indent_str + '#End If')
            i += 1
        else:
            # Multi-line If with Else (NetOffice Then / GemBox Else):
            # Wrap the If...Else part with #If Not HEADLESS, keep Else branch visible,
            # wrap the final End If with #If Not HEADLESS.
            result.append(indent_str + '#If Not HEADLESS Then')
            result.append(line)
            i += 1
            depth = 1
            found_else = False
            while i < len(lines) and depth > 0:
                ml = lines[i]
                ms = ml.strip()
                if ms.startswith('If ') and ms.endswith('Then') and not ms.startswith('If Not HEADLESS'):
                    depth += 1
                # Detect Else at top level of our If block
                if ms == 'Else' and depth == 1 and not found_else:
                    result.append(ml)  # Else
                    result.append(indent_str + '#End If')  # Close first #If Not HEADLESS guard
                    found_else = True
                    i += 1
                    continue
                if ms == 'End If':
                    depth -= 1
                if depth == 0:
                    # Final End If - wrap it too
                    result.append(indent_str + '#If Not HEADLESS Then')
                    result.append(ml)
                    result.append(indent_str + '#End If')
                    break
                result.append(ml)
                i += 1
            if not found_else:
                # No Else branch - just close normally
                result.append(indent_str + '#End If')
            i += 1
    # Also detect: 'Using xcl As New Excel.Application'
    elif 'Using xcl As New Excel.Application' in stripped and not in_netoffice_block:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then')
        result.append(line)
        i += 1
        # Find End Using at same level
        depth = 1
        while i < len(lines) and depth > 0:
            ml = lines[i]
            ms = ml.strip()
            if ms.startswith('Using '):
                depth += 1
            elif ms == 'End Using':
                depth -= 1
            result.append(ml)
            if depth == 0:
                break
            i += 1
        result.append(indent_str + '#End If')
        i += 1
    # Wrap TerminateExcelProcess: method declarations wrap whole method, calls wrap single line
    elif 'TerminateExcelProcess' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        if 'Sub TerminateExcelProcess' in stripped or 'Function TerminateExcelProcess' in stripped:
            # Method declaration - wrap through End Sub/Function
            result.append(indent_str + '#If Not HEADLESS Then')
            result.append(line)
            i += 1
            while i < len(lines):
                ml = lines[i]
                ms = ml.strip()
                result.append(ml)
                if ms == 'End Sub' or ms == 'End Function':
                    break
                i += 1
            result.append(indent_str + '#End If')
            i += 1
        else:
            # Simple call - wrap single line
            result.append(indent_str + '#If Not HEADLESS Then')
            result.append(line)
            result.append(indent_str + '#End If')
            i += 1
    else:
        result.append(line)
        i += 1

with open('$SPREADSHEET', 'w', encoding=write_enc) as f:
    f.write('\n'.join(result))
" 2>&1 || echo "  WARNING: Python NetOffice wrapping failed for Spreadsheet.vb"
fi

# ============================================================================
# Phase 7: Tank.vb and Vessel.vb have additional fd (thermal editor) fields
# and WeifenLuo references in their DisplayEditForm / special methods
# ============================================================================
echo ""
echo "--- Phase 7: Additional WeifenLuo/DockPanel guards ---"

for relpath in "UnitOperations/Tank.vb" "UnitOperations/Vessel.vb"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ]; then
        if grep -q 'WeifenLuo' "$file" 2>/dev/null; then
            echo "  Guarding WeifenLuo references in $relpath"
            perl -i -pe '
                if (/WeifenLuo/ && !/^#If/) {
                    $_ = "#If Not HEADLESS Then\n" . $_ . "#End If\n";
                }
            ' "$file"
        fi
    fi
done

# ============================================================================
# Phase 8: Guard remaining WinForms type references
# TableLayoutPanel, Form_CapeOpenSelector, My.Computer
# ============================================================================
echo ""
echo "--- Phase 8: Guarding remaining WinForms type references ---"

# Guard TableLayoutPanel references (System.Windows.Forms type)
# These appear as method parameters — need to wrap entire method, not just the line
for relpath in "Reactors/Conversion.vb" "Reactors/Equilibrium.vb" "Reactors/Gibbs.vb" \
               "UnitOperations/Tank.vb" "UnitOperations/Vessel.vb" "UnitOperations/Pipe.vb"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ] && grep -q 'TableLayoutPanel' "$file" 2>/dev/null; then
        echo "  Guarding TableLayoutPanel methods in $relpath"
        python3 -c "
import sys
filepath = '$file'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    if 'TableLayoutPanel' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        # Check if this is a method declaration
        if 'Sub ' in stripped or 'Function ' in stripped:
            # Wrap entire method through End Sub/Function
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                ml = lines[i]
                ms = ml.strip()
                ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
                result.append(ml)
                i += 1
                if (ms == 'End Sub' or ms == 'End Function') and ml_indent <= indent:
                    break
            result.append(indent_str + '#End If\n')
        else:
            # Just a reference — wrap single line
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            result.append(indent_str + '#End If\n')
            i += 1
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
    fi
done

# Guard Form_CapeOpenSelector in CapeOpenUO.vb
CAPEOPEN_UO="$UO_DIR/UnitOperations/CapeOpenUO.vb"
if [ -f "$CAPEOPEN_UO" ] && grep -q 'Form_CapeOpenSelector' "$CAPEOPEN_UO" 2>/dev/null; then
    echo "  Guarding Form_CapeOpenSelector in CapeOpenUO.vb"
    python3 -c "
import sys
filepath = '$CAPEOPEN_UO'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
for line in lines:
    stripped = line.strip()
    if 'Form_CapeOpenSelector' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
    else:
        result.append(line)

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
fi

# Guard EditingForm type references outside of already-wrapped methods
for relpath in "UnitOperations/PythonScriptUO.vb" "UnitOperations/ReliefValve.vb"; do
    file="$UO_DIR/$relpath"
    if [ -f "$file" ]; then
        python3 -c "
import sys
filepath = '$file'
relpath = '$relpath'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
changed = False
for line in lines:
    stripped = line.strip()
    if 'EditingForm_' in stripped and '#If' not in stripped and 'As ' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        changed = True
    else:
        result.append(line)

if changed:
    with open(filepath, 'w', encoding=enc) as f:
        f.writelines(result)
    print(f'  [OK] Guarded EditingForm refs in {relpath}')
"
    fi
done

# Comprehensive My.* and other .NET 8 compatibility fixes
echo "  Fixing My.Computer, My.Application, My.Resources, Application.StartupPath..."

# Fix My.Computer.FileSystem → System.IO.File/Directory
find "$UO_DIR" -name "*.vb" -exec grep -l 'My\.Computer' {} \; 2>/dev/null | while read file; do
    sed -i 's/My\.Computer\.FileSystem\.FileExists(\([^)]*\))/System.IO.File.Exists(\1)/g' "$file"
    sed -i 's/My\.Computer\.FileSystem\.ReadAllText(\([^)]*\))/System.IO.File.ReadAllText(\1)/g' "$file"
    sed -i 's/My\.Computer\.FileSystem\.CopyFile(\([^)]*\))/System.IO.File.Copy(\1)/g' "$file"
    sed -i 's/My\.Computer\.FileSystem\.DeleteFile(\([^)]*\))/System.IO.File.Delete(\1)/g' "$file"
    sed -i 's/My\.Computer\.FileSystem\.GetTempFileName()/System.IO.Path.GetTempFileName()/g' "$file"
    sed -i 's/My\.Computer\.FileSystem\.DirectoryExists(\([^)]*\))/System.IO.Directory.Exists(\1)/g' "$file"
done

# Fix Application.StartupPath → AppDomain.CurrentDomain.BaseDirectory
find "$UO_DIR" -name "*.vb" -exec grep -l 'Application\.StartupPath' {} \; 2>/dev/null | while read file; do
    sed -i 's/Application\.StartupPath/AppDomain.CurrentDomain.BaseDirectory/g' "$file"
done

# Fix My.Application.Info.DirectoryPath → AppDomain.CurrentDomain.BaseDirectory
find "$UO_DIR" -name "*.vb" -exec grep -l 'My\.Application' {} \; 2>/dev/null | while read file; do
    sed -i 's/My\.Application\.Info\.DirectoryPath/AppDomain.CurrentDomain.BaseDirectory/g' "$file"
done

# Guard My.Resources.* references (wrap methods containing them)
# Block-aware: if My.Resources is inside a Using statement, wrap the entire Using...End Using block
echo "  Guarding My.Resources references..."
find "$UO_DIR" -name "*.vb" -exec grep -l 'My\.Resources\.' {} \; 2>/dev/null | while read file; do
    python3 -c "
import sys
filepath = '$file'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    if 'My.Resources.' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        # Check if this is inside a Using statement
        if stripped.startswith('Using ') and 'My.Resources.' in stripped:
            # Wrap entire Using...End Using block
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            # Find matching End Using
            depth = 1
            while i < len(lines) and depth > 0:
                ml = lines[i]
                ms = ml.strip()
                if ms.startswith('Using '):
                    depth += 1
                elif ms == 'End Using':
                    depth -= 1
                result.append(ml)
                i += 1
                if depth == 0:
                    break
            result.append(indent_str + '#End If\n')
        else:
            # Simple line wrap
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            result.append(indent_str + '#End If\n')
            i += 1
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
done

# Guard InitializePythonEnvironment calls
echo "  Guarding InitializePythonEnvironment calls..."
find "$UO_DIR" -name "*.vb" -exec grep -l 'InitializePythonEnvironment' {} \; 2>/dev/null | while read file; do
    python3 -c "
import sys
filepath = '$file'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
for line in lines:
    stripped = line.strip()
    if 'InitializePythonEnvironment' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
    else:
        result.append(line)

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
done

# Guard DynamicsPropertyEditor references outside wrapped methods
echo "  Guarding DynamicsPropertyEditor references..."
find "$UO_DIR" -name "*.vb" -exec grep -l 'DynamicsPropertyEditor' {} \; 2>/dev/null | while read file; do
    python3 -c "
import sys
filepath = '$file'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
for line in lines:
    stripped = line.strip()
    if 'DynamicsPropertyEditor' in stripped and '#If' not in stripped and 'As ' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
    else:
        result.append(line)

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
done

# ============================================================================
# Phase 9: Deep WinForms contamination cleanup
# Strategy: wrap ENTIRE METHODS, not individual lines.
# This avoids breaking VB.NET block structure (If/Else/End If, Using, With).
# ============================================================================
echo ""
echo "--- Phase 9: Deep WinForms cleanup (method-level wrapping) ---"

# 9a: CapeOpen.vb — wrap Initialize() BODY (not signature, it implements interface)
# + wrap UnhandledException methods entirely (private, not overridden)
CAPEOPENBASE="$UO_DIR/BaseClasses/CapeOpen.vb"
if [ -f "$CAPEOPENBASE" ]; then
    echo "  Wrapping CapeOpen.vb Initialize body + UnhandledException methods"
    python3 -c "
import sys
filepath = '$CAPEOPENBASE'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

# Methods to wrap entirely (Private, not overridden by subclasses)
wrap_entirely = ['Sub UnhandledException(', 'Sub UnhandledException2(']
# Methods to wrap only the body (keep signature+End Sub visible)
wrap_body = ['Sub Initialize()']

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Check if entirely wrapping
    do_entire = False
    for m in wrap_entirely:
        if m in stripped and '#If' not in stripped:
            do_entire = True
            break
    if do_entire:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        i += 1
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            result.append(ml)
            i += 1
            if ms == 'End Sub' and ml_indent <= indent:
                break
        result.append(indent_str + '#End If\n')
        continue

    # Check if body-only wrapping (keep Sub ... End Sub visible)
    do_body = False
    for m in wrap_body:
        if m in stripped and '#If' not in stripped:
            do_body = True
            break
    if do_body:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        body_indent = indent_str + '    '
        result.append(line)  # Keep method signature
        i += 1
        # Collect body lines until End Sub
        body_lines = []
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            if ms == 'End Sub' and ml_indent <= indent:
                break
            body_lines.append(ml)
            i += 1
        # Wrap body with guards
        result.append(body_indent + '#If Not HEADLESS Then\n')
        result.extend(body_lines)
        result.append(body_indent + '#End If\n')
        # Keep End Sub
        if i < len(lines):
            result.append(lines[i])
            i += 1
        continue

    result.append(line)
    i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
fi

# 9b: CapeOpenUO.vb — wrap ShowForm method + entire constructor block (lines 108-149)
# + field declarations for _form and Form_CapeOpenSelector
CAPEOPEN_UO="$UO_DIR/UnitOperations/CapeOpenUO.vb"
if [ -f "$CAPEOPEN_UO" ]; then
    echo "  Wrapping CapeOpenUO.vb ShowForm + constructor Windows block + fields"
    python3 -c "
import sys
filepath = '$CAPEOPEN_UO'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Wrap Sub ShowForm method entirely
    if 'Sub ShowForm()' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        i += 1
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            result.append(ml)
            i += 1
            if ms == 'End Sub' and ml_indent <= indent:
                break
        result.append(indent_str + '#End If\n')
    # Wrap the Windows platform If block in the constructor
    # Pattern: If GlobalSettings.Settings.RunningPlatform() = Settings.Platform.Windows Then
    elif 'RunningPlatform()' in stripped and 'Platform.Windows' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        i += 1
        # Find matching End If at same indent level
        depth = 1
        while i < len(lines) and depth > 0:
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            if ml_indent == indent:
                if ms.startswith('If ') and (ms.endswith(' Then') or ms.endswith(' Then_')):
                    depth += 1
                elif ms == 'End If':
                    depth -= 1
            result.append(ml)
            i += 1
            if depth == 0:
                break
        result.append(indent_str + '#End If\n')
    # Guard field declarations with _form or Form_CapeOpenSelector
    elif '#If' not in stripped and ('Private _form As Form_CapeOpenSelector' in stripped
          or 'Public f As EditingForm_' in stripped):
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        i += 1
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
fi

# 9c: FlowsheetUO.vb — replace remaining My.Computer and My.Application references
FLOWSHEET_UO="$UO_DIR/UnitOperations/FlowsheetUO.vb"
if [ -f "$FLOWSHEET_UO" ]; then
    echo "  Fixing FlowsheetUO.vb My.Computer/My.Application references"
    sed -i 's/My\.Computer\.FileSystem\.SpecialDirectories\.Temp/System.IO.Path.GetTempPath()/g' "$FLOWSHEET_UO"
    sed -i 's/My\.Application\.Info\.LoadedAssemblies/AppDomain.CurrentDomain.GetAssemblies()/g' "$FLOWSHEET_UO"
    sed -i 's/My\.Application\.Info\.Version/System.Reflection.Assembly.GetExecutingAssembly().GetName().Version/g' "$FLOWSHEET_UO"
    sed -i 's/My\.Computer\.Info\.OSFullName/System.Runtime.InteropServices.RuntimeInformation.OSDescription/g' "$FLOWSHEET_UO"
    sed -i 's/My\.Computer\.Info\.OSVersion/Environment.OSVersion.Version.ToString()/g' "$FLOWSHEET_UO"
    sed -i 's/My\.Computer\.Info\.OSPlatform/Environment.OSVersion.Platform.ToString()/g' "$FLOWSHEET_UO"
fi

# 9d: PythonScriptUO.vb — wrap entire DisplayScriptEditorForm method
# and guard field declarations for fs/fsmono
PYSCRIPT="$UO_DIR/UnitOperations/PythonScriptUO.vb"
if [ -f "$PYSCRIPT" ]; then
    echo "  Wrapping PythonScriptUO.vb DisplayScriptEditorForm method + fields"
    python3 -c "
import sys
filepath = '$PYSCRIPT'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Wrap DisplayScriptEditorForm method entirely
    if 'Sub DisplayScriptEditorForm' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        i += 1
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            result.append(ml)
            i += 1
            if ms == 'End Sub' and ml_indent <= indent:
                break
        result.append(indent_str + '#End If\n')
    # Guard field declarations for fs/fsmono (EditingForm_CustomUO_ScriptEditor types)
    elif 'EditingForm_CustomUO_ScriptEditor' in stripped and '#If' not in stripped and 'As ' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        i += 1
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
fi

# 9e: CustomUO_CO.vb — wrap entire Edit() method
CUSTOMUO_CO="$UO_DIR/CAPE-OPEN/CustomUO_CO.vb"
if [ -f "$CUSTOMUO_CO" ]; then
    echo "  Wrapping Edit() method in CustomUO_CO.vb"
    python3 -c "
import sys
filepath = '$CUSTOMUO_CO'
try:
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    enc = 'utf-8'
except UnicodeDecodeError:
    with open(filepath, 'r', encoding='latin-1') as f:
        lines = f.readlines()
    enc = 'latin-1'

result = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    if 'Sub Edit()' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        i += 1
        while i < len(lines):
            ml = lines[i]
            ms = ml.strip()
            ml_indent = len(ml) - len(ml.lstrip()) if ml.strip() else indent + 1
            result.append(ml)
            i += 1
            if ms == 'End Sub' and ml_indent <= indent:
                break
        result.append(indent_str + '#End If\n')
    else:
        result.append(line)
        i += 1

with open(filepath, 'w', encoding=enc) as f:
    f.writelines(result)
"
fi

# 9f: Mapack.Matrix — add instance Multiply(double) method
# The project source only has static Multiply(Matrix, double), but code calls mypot.Multiply(-1)
MAPACK_MATRIX="$DWSIM_ROOT/DWSIM.MathOps.Mapack/Matrix.cs"
if [ -f "$MAPACK_MATRIX" ]; then
    if ! grep -q 'public Matrix Multiply(double right)' "$MAPACK_MATRIX"; then
        echo "  Adding instance Multiply(double) to Mapack.Matrix"
        sed -i '/public static Matrix Multiply(Matrix left, double right)/i\
        /// <summary>Instance matrix-scalar multiplication.</summary>\
        public Matrix Multiply(double right)\
        {\
            return Multiply(this, right);\
        }\
' "$MAPACK_MATRIX"
    fi
fi

echo ""
echo "=== WinForms guards patching complete ==="
