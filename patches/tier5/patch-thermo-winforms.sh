#!/usr/bin/env bash
# =============================================================================
# Tier 5 Thermodynamics: WinForms source patches
#
# Applies #If Not HEADLESS Then ... #End If guards around WinForms-dependent
# code that lives in files we KEEP (not in excluded EditingForms/).
#
# Key patterns:
#   1. DisplayEditingForm() / GetEditingForm() methods in PropertyPackage files
#      - These create/return WinForms Form instances from excluded EditingForms
#      - Wrap entire method bodies with HEADLESS guard
#   2. DisplayGroupedEditingForm() / DisplayFlashConfigForm() in PropertyPackage.vb
#      - Creates WinForms controls directly
#   3. ConsoleRedirection.vb TextBoxStreamWriter class (uses WinForms TextBox)
#   4. Remove unused "Imports System.Windows.Forms" from MaterialStream.vb
#   5. Sub-projects: PCSAFT2, PRSRKTDep, Reaktoro have same GetEditingForm pattern
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"

echo "--- Applying Tier 5 WinForms source patches ---"
echo ""

# =========================================================================
# Helper: Wrap a VB method (Sub or Function) with #If Not HEADLESS guard
# Usage: wrap_vb_method <file> <method_signature_pattern>
#
# This wraps from the line matching the pattern through the matching
# "End Sub" or "End Function" with #If Not HEADLESS / #End If.
#
# For VB.NET, we insert:
#   #If Not HEADLESS Then
#   before the method signature, and
#   #End If
#   after the End Sub/End Function
# =========================================================================
wrap_vb_method() {
    local file="$1"
    local pattern="$2"
    local method_type="$3"  # "Sub" or "Function"

    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo "  [SKIP] Pattern not found in $(basename "$file"): $pattern"
        return 0
    fi

    # Use Python for reliable multi-line editing
    python3 -c "
import re, sys

with open('$file', 'r') as f:
    lines = f.readlines()

pattern = '''$pattern'''
method_type = '''$method_type'''
end_marker = 'End ' + method_type

result = []
i = 0
patched = False
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    if pattern in stripped and not patched:
        # Find the indentation of this line
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        # Insert #If Not HEADLESS before the method
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        # Find matching End Sub/Function
        depth = 1
        i += 1
        while i < len(lines):
            current = lines[i]
            current_stripped = current.strip()
            # Count nested method starts (Sub or Function with same type)
            if re.match(r'\s*(Public|Private|Protected|Friend).*\s' + method_type + r'\s', current) and not current_stripped.startswith(\"'\"):
                depth += 1
            if current_stripped == end_marker:
                depth -= 1
                if depth == 0:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
            result.append(current)
            i += 1
    else:
        result.append(line)
        i += 1

if not patched:
    print(f'  [WARN] Could not wrap method in $file', file=sys.stderr)
    sys.exit(0)

with open('$file', 'w') as f:
    f.writelines(result)
print(f'  [OK] Wrapped {method_type} matching \"{pattern}\" in $(basename $file)')
"
}

# =========================================================================
# Helper: Remove a specific import line from a VB file
# =========================================================================
remove_import() {
    local file="$1"
    local import_line="$2"

    if grep -q "$import_line" "$file" 2>/dev/null; then
        # Use sed to remove the line (macOS/Linux compatible)
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "/$import_line/d" "$file"
        else
            sed -i "/$import_line/d" "$file"
        fi
        echo "  [OK] Removed '$import_line' from $(basename "$file")"
    else
        echo "  [SKIP] '$import_line' not found in $(basename "$file")"
    fi
}

# =========================================================================
# 1. DWSIM.Thermodynamics main project
# =========================================================================
THERMO_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics"
echo "=== Patching DWSIM.Thermodynamics ==="
echo ""

# 1a. MaterialStream.vb - remove unused WinForms import
echo "[MaterialStream.vb]"
remove_import "${THERMO_DIR}/MaterialStream/MaterialStream.vb" "Imports System.Windows.Forms"
echo ""

# 1b. ConsoleRedirection.vb - wrap TextBoxStreamWriter class
echo "[ConsoleRedirection.vb]"
python3 -c "
with open('${THERMO_DIR}/HelperClasses/ConsoleRedirection.vb', 'r') as f:
    content = f.read()

# Wrap the entire TextBoxStreamWriter class and its WinForms import
old = '''Imports System.Windows.Forms

Namespace ConsoleRedirection

    Public Class TextBoxStreamWriter

        Inherits TextWriter

        Private _tbox As TextBox

        Public Sub New(ByVal tbox As TextBox)
            _tbox = tbox
        End Sub

        Public Overrides Sub Write(value As String)
            MyBase.Write(value)
            _tbox.UIThread(Sub()
                               If Not _tbox Is Nothing Then
                                   _tbox.AppendText(value)
                               End If
                           End Sub)
        End Sub

        Public Overrides Sub Write(ByVal value As Char)
            MyBase.Write(value)
            _tbox.UIThread(Sub()
                               If Not _tbox Is Nothing Then
                                   _tbox.AppendText(value.ToString())
                               End If
                           End Sub)
        End Sub

        Public Overrides ReadOnly Property Encoding() As Encoding
            Get
                Return System.Text.Encoding.UTF8
            End Get
        End Property

    End Class'''

new = '''#If Not HEADLESS Then
Imports System.Windows.Forms
#End If

Namespace ConsoleRedirection

#If Not HEADLESS Then
    Public Class TextBoxStreamWriter

        Inherits TextWriter

        Private _tbox As TextBox

        Public Sub New(ByVal tbox As TextBox)
            _tbox = tbox
        End Sub

        Public Overrides Sub Write(value As String)
            MyBase.Write(value)
            _tbox.UIThread(Sub()
                               If Not _tbox Is Nothing Then
                                   _tbox.AppendText(value)
                               End If
                           End Sub)
        End Sub

        Public Overrides Sub Write(ByVal value As Char)
            MyBase.Write(value)
            _tbox.UIThread(Sub()
                               If Not _tbox Is Nothing Then
                                   _tbox.AppendText(value.ToString())
                               End If
                           End Sub)
        End Sub

        Public Overrides ReadOnly Property Encoding() As Encoding
            Get
                Return System.Text.Encoding.UTF8
            End Get
        End Property

    End Class
#End If'''

if old in content:
    content = content.replace(old, new)
    with open('${THERMO_DIR}/HelperClasses/ConsoleRedirection.vb', 'w') as f:
        f.write(content)
    print('  [OK] Wrapped TextBoxStreamWriter with #If Not HEADLESS')
else:
    print('  [WARN] Could not find TextBoxStreamWriter pattern')
"
echo ""

# 1c. PropertyPackage.vb - wrap GetEditingForm, DisplayGroupedEditingForm, DisplayFlashConfigForm
echo "[PropertyPackage.vb]"
# This file is massive (~13500+ lines). We use Python for precise patching.
# Uses indentation-aware End Sub/Function matching to avoid matching lambda End Sub.
python3 << PYEOF
import re, sys

def wrap_method_block(lines, start_pattern, end_keyword, method_name):
    """Wrap a method from start_pattern line through matching End Sub/Function.
    Uses indentation-aware matching: the End keyword must be at the same or lesser
    indentation level as the method signature to count as the method's end."""
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if start_pattern in stripped and not patched:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                # Match End Sub/Function only at same indentation as method
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    if patched:
        print(f'  [OK] Wrapped {method_name} in PropertyPackage.vb')
    else:
        print(f'  [WARN] Could not wrap {method_name} in PropertyPackage.vb')
    return result

file_path = "${THERMO_DIR}/PropertyPackages/PropertyPackage.vb"
with open(file_path, 'r') as f:
    lines = f.readlines()

# Wrap GetEditingForm (returns System.Windows.Forms.Form)
lines = wrap_method_block(lines,
    'Public Overridable Function GetEditingForm() As System.Windows.Forms.Form',
    'End Function',
    'GetEditingForm()')

# Wrap DisplayFlashConfigForm (contains ShowDialog calls)
lines = wrap_method_block(lines,
    'Public Sub DisplayFlashConfigForm()',
    'End Sub',
    'DisplayFlashConfigForm()')

# Wrap DisplayGroupedEditingForm (contains lambdas with nested End Sub)
lines = wrap_method_block(lines,
    'Public Overridable Sub DisplayGroupedEditingForm() Implements IPropertyPackage.DisplayGroupedEditingForm',
    'End Sub',
    'DisplayGroupedEditingForm()')

with open(file_path, 'w') as f:
    f.writelines(lines)
PYEOF
echo ""

# 1d. Wrap DisplayEditingForm/GetEditingForm in all PropertyPackage subclasses
echo "[PropertyPackage subclasses - DisplayEditingForm/GetEditingForm]"

PP_DIR="${THERMO_DIR}/PropertyPackages"

# List of files that have DisplayEditingForm and/or GetEditingForm overrides
PP_FILES=(
    "ActivityCoefficientBase.vb"
    "CAPEOPENSocket.vb"
    "CoolPropIncompressibleMixture.vb"
    "CoolPropIncompressiblePure.vb"
    "ElectrolyteIdeal.vb"
    "Ideal.vb"
    "LeeKeslerPlocker.vb"
    "LIQUAC2PropertyPackage.vb"
    "NRTL.vb"
    "PengRobinson.vb"
    "PengRobinson78.vb"
    "PengRobinsonLeeKesler.vb"
    "PengRobinsonStryjekVera2.vb"
    "PengRobinsonStryjekVera2VL.vb"
    "SeaWater.vb"
    "SoaveRedlichKwong.vb"
    "UNIQUAC.vb"
    "WilsonPropertyPackage.vb"
)

for ppfile in "${PP_FILES[@]}"; do
    filepath="${PP_DIR}/${ppfile}"
    if [ ! -f "$filepath" ]; then
        echo "  [SKIP] File not found: $ppfile"
        continue
    fi

    python3 -c "
import re, sys

filepath = '$filepath'
ppfile = '$ppfile'

with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword):
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    return result, patched

# Wrap DisplayEditingForm
lines, p1 = wrap_method(lines, 'Overrides Sub DisplayEditingForm()', 'End Sub')
# Wrap GetEditingForm
lines, p2 = wrap_method(lines, 'Overrides Function GetEditingForm()', 'End Function')
# Wrap Edit override (CAPEOPENSocket has Overrides Sub Edit())
lines, p3 = wrap_method(lines, 'Overrides Sub Edit()', 'End Sub')

status = []
if p1: status.append('DisplayEditingForm')
if p2: status.append('GetEditingForm')
if p3: status.append('Edit')

if status:
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print(f'  [OK] Wrapped {\" + \".join(status)} in {ppfile}')
else:
    print(f'  [SKIP] No methods to wrap in {ppfile}')
"
done
echo ""

# =========================================================================
# 2. DWSIM.Thermodynamics.AdvancedEOS.PCSAFT (PCSAFT2PropertyPackage.vb)
# =========================================================================
PCSAFT_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.AdvancedEOS.PCSAFT"
echo "=== Patching DWSIM.Thermodynamics.AdvancedEOS.PCSAFT ==="
echo ""

python3 -c "
import sys

filepath = '${PCSAFT_DIR}/PCSAFT2PropertyPackage.vb'

with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword):
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    return result, patched

lines, p1 = wrap_method(lines, 'Overrides Sub DisplayEditingForm()', 'End Sub')
lines, p2 = wrap_method(lines, 'Overrides Function GetEditingForm()', 'End Function')

status = []
if p1: status.append('DisplayEditingForm')
if p2: status.append('GetEditingForm')

if status:
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print(f'  [OK] Wrapped {\" + \".join(status)} in PCSAFT2PropertyPackage.vb')
"

# Remove unused WinForms import
remove_import "${PCSAFT_DIR}/PCSAFT2PropertyPackage.vb" "Imports System.Windows.Forms"
echo ""

# =========================================================================
# 3. DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep
# =========================================================================
PRSRK_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep"
echo "=== Patching DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep ==="
echo ""

for vbfile in "PengRobinsonAdvanced.vb" "SRKAdvanced.vb"; do
    filepath="${PRSRK_DIR}/${vbfile}"
    python3 -c "
import sys

filepath = '${filepath}'
vbfile = '${vbfile}'

with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword):
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    return result, patched

lines, p1 = wrap_method(lines, 'Overrides Sub DisplayEditingForm()', 'End Sub')
lines, p2 = wrap_method(lines, 'Overrides Function GetEditingForm()', 'End Function')

status = []
if p1: status.append('DisplayEditingForm')
if p2: status.append('GetEditingForm')

if status:
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print(f'  [OK] Wrapped {\" + \".join(status)} in {vbfile}')
"
    remove_import "${filepath}" "Imports System.Windows.Forms"
done
echo ""

# =========================================================================
# 4. DWSIM.Thermodynamics.ReaktoroPropertyPackage
# =========================================================================
REAKTORO_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.ReaktoroPropertyPackage"
echo "=== Patching DWSIM.Thermodynamics.ReaktoroPropertyPackage ==="
echo ""

python3 -c "
import sys

filepath = '${REAKTORO_DIR}/ReaktoroPP.vb'

with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword):
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    return result, patched

lines, p1 = wrap_method(lines, 'Overrides Sub DisplayEditingForm()', 'End Sub')
lines, p2 = wrap_method(lines, 'Overrides Function GetEditingForm()', 'End Function')

status = []
if p1: status.append('DisplayEditingForm')
if p2: status.append('GetEditingForm')

if status:
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print(f'  [OK] Wrapped {\" + \".join(status)} in ReaktoroPP.vb')
"

remove_import "${REAKTORO_DIR}/ReaktoroPP.vb" "Imports System.Windows.Forms"

# Wrap InitializePythonEnvironment calls (removed from Settings in headless mode)
# and any other Python.NET-dependent code
echo "[Reaktoro] Wrapping Python.NET-dependent code with HEADLESS guards"
for rfile in "${REAKTORO_DIR}"/*.vb; do
    [ -f "$rfile" ] || continue
    rbasename="$(basename "$rfile")"
    python3 -c "
import sys

filepath = '$rfile'
basename = '$rbasename'
with open(filepath, 'r') as f:
    lines = f.readlines()

result = []
changed = False
for line in lines:
    stripped = line.strip()
    # Guard InitializePythonEnvironment calls
    if 'InitializePythonEnvironment' in stripped and '#If' not in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        changed = True
        print(f'  [OK] Guarded InitializePythonEnvironment in {basename}')
    else:
        result.append(line)

if changed:
    with open(filepath, 'w') as f:
        f.writelines(result)
"
done
echo ""

# =========================================================================
# 5. Fix additional WinForms type references in Thermodynamics
# =========================================================================
echo "=== Fixing additional WinForms references ==="

# 5a. Calculator.vb — LogForm reference (WinForms form we excluded)
CALC_VB="${THERMO_DIR}/Main/Calculator.vb"
if [ -f "${CALC_VB}" ]; then
    echo "[Calculator.vb]"
    python3 -c "
import sys

filepath = '${CALC_VB}'
with open(filepath, 'r') as f:
    lines = f.readlines()

result = []
for line in lines:
    stripped = line.strip()
    # Guard field declarations referencing LogForm type
    if 'LogForm' in stripped and ('Public ' in stripped or 'Private ' in stripped or 'Dim ' in stripped) and 'As ' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        print(f'  [OK] Guarded LogForm field: {stripped}')
    else:
        result.append(line)

with open(filepath, 'w') as f:
    f.writelines(result)
"
fi

# 5b. MaterialStream.vb — MaterialStreamEditor references and My.Resources
MS_VB="${THERMO_DIR}/MaterialStream/MaterialStream.vb"
if [ -f "${MS_VB}" ]; then
    echo "[MaterialStream.vb]"
    # Replace 'As MaterialStreamEditor' type annotations
    sed -i 's/As MaterialStreamEditor/As Object/g' "${MS_VB}"
    # Wrap methods that use MaterialStreamEditor or My.Resources, add #Else stubs
    python3 -c "
import re, sys

filepath = '${MS_VB}'
with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method_with_stub(lines, sig_pattern, end_keyword, stub_lines):
    \"\"\"Wrap a method with #If Not HEADLESS Then ... #Else ... stub ... #End If\"\"\"
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched and '#If Not HEADLESS' not in stripped:
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    result.append(indent_str + '#Else\n')
                    for sl in stub_lines:
                        result.append(indent_str + sl + '\n')
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    return result, patched

# Wrap DisplayEditForm with empty stub (note: DisplayEditForm, not DisplayEditingForm)
lines, p1 = wrap_method_with_stub(lines,
    'Overrides Sub DisplayEditForm()', 'End Sub',
    ['    Public Overrides Sub DisplayEditForm()', '    End Sub'])

# Wrap GetEditingForm with stub returning Nothing
lines, p2 = wrap_method_with_stub(lines,
    'Overrides Function GetEditingForm()', 'End Function',
    ['    Public Overrides Function GetEditingForm() As Object', '        Return Nothing', '    End Function'])

# Wrap GetIconBitmap with stub returning Nothing
lines, p3 = wrap_method_with_stub(lines,
    'Function GetIconBitmap()', 'End Function',
    ['    Public Overrides Function GetIconBitmap() As Object', '        Return Nothing', '    End Function'])

status = [x for x, p in [('DisplayEditForm', p1), ('GetEditingForm', p2), ('GetIconBitmap', p3)] if p]
if status:
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print(f'  [OK] Wrapped with stubs: {\" + \".join(status)} in MaterialStream.vb')
else:
    print('  [WARN] No methods wrapped in MaterialStream.vb')
"
fi

# 5c. CAPE-OPEN.vb — Wrap specific WinForms-dependent methods (keep CAPEOPENManager class visible)
CO_VB="${THERMO_DIR}/Interfaces/CAPE-OPEN.vb"
if [ -f "${CO_VB}" ]; then
    echo "[CAPE-OPEN.vb]"
    python3 -c "
import sys

filepath = '${CO_VB}'
with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword, method_name, stub_lines=None):
    \"\"\"Wrap a method with #If Not HEADLESS, including preceding attribute lines.
    If stub_lines is provided, adds #Else stub for interface compliance.\"\"\"
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched and '#If Not HEADLESS' not in (lines[i-1].strip() if i > 0 else ''):
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            # Check if previous lines are attributes (start with < and end with _ continuation)
            attr_start = len(result)
            while attr_start > 0 and result[attr_start-1].strip().endswith('_') and '<' in result[attr_start-1]:
                attr_start -= 1
            # Insert #If before the attribute(s)
            result.insert(attr_start, indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    if stub_lines:
                        result.append(indent_str + '#Else\n')
                        for sl in stub_lines:
                            result.append(indent_str + sl + '\n')
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    if patched:
        print(f'  [OK] Wrapped {method_name} in CAPE-OPEN.vb')
    return result

# Initialize() uses Application, My.Application, My.Computer, UnhandledExceptionMode
# Needs stub because it implements ICapeUtilities.Initialize
lines = wrap_method(lines, 'Sub Initialize() Implements ICapeUtilities.Initialize', 'End Sub', 'Initialize',
    stub_lines=['    Public Sub Initialize() Implements ICapeUtilities.Initialize', '    End Sub'])
# UnhandledException uses FormUnhandledException (private, no stub needed)
lines = wrap_method(lines, 'Private Sub UnhandledException(', 'End Sub', 'UnhandledException')
lines = wrap_method(lines, 'Private Sub UnhandledException2(', 'End Sub', 'UnhandledException2')
# RegisterFunction uses My.Application, Registry (has <ComRegisterFunction()> _ attribute)
lines = wrap_method(lines, 'Private Shared Sub RegisterFunction(', 'End Sub', 'RegisterFunction')
lines = wrap_method(lines, 'Private Shared Sub UnregisterFunction(', 'End Sub', 'UnregisterFunction')

with open(filepath, 'w') as f:
    f.writelines(lines)
"
fi

# 5d. ExcelAddIn references in PropertyPackage subclasses
echo "[ExcelAddIn references]"
for vbfile in "NRTL.vb" "UNIQUAC.vb" "WilsonPropertyPackage.vb"; do
    filepath="${THERMO_DIR}/PropertyPackages/${vbfile}"
    if [ -f "$filepath" ]; then
        python3 -c "
import sys

filepath = '${filepath}'
vbfile = '${vbfile}'
with open(filepath, 'r') as f:
    lines = f.readlines()

result = []
for line in lines:
    stripped = line.strip()
    if 'ExcelAddIn' in stripped:
        indent = len(line) - len(line.lstrip())
        indent_str = line[:indent]
        result.append(indent_str + '#If Not HEADLESS Then\n')
        result.append(line)
        result.append(indent_str + '#End If\n')
        print(f'  [OK] Guarded ExcelAddIn reference in {vbfile}')
    else:
        result.append(line)

with open(filepath, 'w') as f:
    f.writelines(result)
"
    fi
done

# 5e. PropertyPackage.vb — Additional WinForms-dependent methods
PP_VB="${THERMO_DIR}/PropertyPackages/PropertyPackage.vb"
if [ -f "${PP_VB}" ]; then
    echo "[PropertyPackage.vb] Wrapping additional WinForms methods"
    python3 -c "
import re, sys

filepath = '${PP_VB}'
with open(filepath, 'r') as f:
    lines = f.readlines()

def wrap_method(lines, sig_pattern, end_keyword, method_name, stub_lines=None):
    result = []
    i = 0
    patched = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if sig_pattern in stripped and not patched and '#If Not HEADLESS' not in (lines[i-1].strip() if i > 0 else ''):
            method_indent = len(line) - len(line.lstrip())
            indent_str = line[:method_indent]
            result.append(indent_str + '#If Not HEADLESS Then\n')
            result.append(line)
            i += 1
            while i < len(lines):
                current = lines[i]
                cs = current.strip()
                current_indent = len(current) - len(current.lstrip())
                if cs == end_keyword and current_indent <= method_indent:
                    result.append(current)
                    if stub_lines:
                        result.append(indent_str + '#Else\n')
                        for sl in stub_lines:
                            result.append(indent_str + sl + '\n')
                    result.append(indent_str + '#End If\n')
                    patched = True
                    i += 1
                    break
                result.append(current)
                i += 1
        else:
            result.append(line)
            i += 1
    if patched:
        print(f'  [OK] Wrapped {method_name}')
    return result

# Wrap Edit() (references FormConfigCAPEOPENPPackage) — needs stub for ICapeUtilities
lines = wrap_method(lines, 'Sub Edit() Implements CapeOpen.ICapeUtilities.Edit', 'End Sub', 'Edit/CapeOpen',
    stub_lines=['    Public Overridable Sub Edit() Implements CapeOpen.ICapeUtilities.Edit', '    End Sub'])

# Wrap DisplayAdvancedEditingForm (refs Scintilla) — needs stub for IPropertyPackage
lines = wrap_method(lines, 'Function DisplayAdvancedEditingForm()', 'End Function', 'DisplayAdvancedEditingForm',
    stub_lines=['    Public Function DisplayAdvancedEditingForm() As Object Implements IPropertyPackage.DisplayAdvancedEditingForm',
                '        Return Nothing', '    End Function'])

# Wrap GetAdvancedEditingForm (references Eto.Forms.Form)
lines = wrap_method(lines, 'Function GetAdvancedEditingForm()', 'End Function', 'GetAdvancedEditingForm')

# Wrap GetAdvancedEditingContainers (references Scintilla, Eto.Forms)
lines = wrap_method(lines, 'Function GetAdvancedEditingContainers()', 'End Function', 'GetAdvancedEditingContainers')

# Wrap GetDisplayIcon (references My.Resources)
lines = wrap_method(lines, 'Function GetDisplayIcon()', 'End Function', 'GetDisplayIcon')

with open(filepath, 'w') as f:
    f.writelines(lines)
"
    # Also add #Else stubs for interface methods
    echo "[PropertyPackage.vb] Adding #Else stubs for interface methods"
    python3 -c "
import sys

filepath = '${PP_VB}'
with open(filepath, 'r') as f:
    content = f.read()

lines = content.split('\n')
result = []
i = 0
while i < len(lines):
    line = lines[i]
    # Look for #End If that follows wrapped methods needing interface stubs
    if i > 0 and '#End If' in line.strip():
        j = i - 1
        while j >= 0 and lines[j].strip() == '':
            j -= 1
        if j >= 0 and (lines[j].strip() == 'End Sub' or lines[j].strip() == 'End Function'):
            # Look back for the method signature
            k = j - 1
            found_method = None
            while k >= 0:
                ls = lines[k].strip()
                if '#If Not HEADLESS Then' in ls:
                    break
                if 'DisplayGroupedEditingForm' in ls and 'Implements' in ls:
                    found_method = 'DisplayGroupedEditingForm'
                    break
                if 'GetEditingForm' in ls and 'Overridable Function' in ls and 'System.Windows.Forms' in ls:
                    found_method = 'GetEditingForm'
                    break
                k -= 1

            if found_method == 'DisplayGroupedEditingForm':
                indent = len(line) - len(line.lstrip())
                indent_str = line[:indent]
                result.append(indent_str + '#Else')
                result.append(indent_str + '    Public Overridable Sub DisplayGroupedEditingForm() Implements IPropertyPackage.DisplayGroupedEditingForm')
                result.append(indent_str + '    End Sub')
                result.append(line)
                print(f'  [OK] Added #Else stub for DisplayGroupedEditingForm')
                i += 1
                continue
            elif found_method == 'GetEditingForm':
                indent = len(line) - len(line.lstrip())
                indent_str = line[:indent]
                result.append(indent_str + '#Else')
                result.append(indent_str + '    Public Overridable Function GetEditingForm() As Object')
                result.append(indent_str + '        Return Nothing')
                result.append(indent_str + '    End Function')
                result.append(line)
                print(f'  [OK] Added #Else stub for GetEditingForm')
                i += 1
                continue

    result.append(line)
    i += 1

with open(filepath, 'w') as f:
    f.write('\n'.join(result))
"
fi

# 5f. ThermodynamicsBase.vb — Fix Double.Parse(Object) pattern
TB_VB="${THERMO_DIR}/BaseClasses/ThermodynamicsBase.vb"
if [ -f "${TB_VB}" ]; then
    echo "[ThermodynamicsBase.vb] Fixing Double.Parse(Object) patterns"
    python3 -c "
import re

filepath = '${TB_VB}'
with open(filepath, 'r') as f:
    content = f.read()

# The pattern: Double.Parse(Me.GetType.GetProperty(fi.Name).GetValue(Me, Nothing))
# This passes Object to Double.Parse which doesn't work in .NET 8
# Replace with Convert.ToDouble(...)
# Use regex to catch Double.Parse(any_expression) and replace with Convert.ToDouble(any_expression)
# But be careful not to replace Double.Parse(string_expr) — only the ones that cause errors
# The specific pattern is on line 212: Double.Parse(Me.GetType.GetProperty(fi.Name).GetValue(Me, Nothing))
content = content.replace(
    'Double.Parse(Me.GetType.GetProperty(fi.Name).GetValue(Me, Nothing))',
    'Convert.ToDouble(Me.GetType.GetProperty(fi.Name).GetValue(Me, Nothing))'
)

# Also handle any other Double.Parse(obj) or Single.Parse(obj) patterns
content = content.replace('Double.Parse(obj)', 'Convert.ToDouble(obj)')
content = content.replace('Single.Parse(obj)', 'Convert.ToSingle(obj)')

with open(filepath, 'w') as f:
    f.write(content)
print('  [OK] Fixed Parse(Object) calls')
"
fi

echo "--- Tier 5 WinForms source patches complete ---"
