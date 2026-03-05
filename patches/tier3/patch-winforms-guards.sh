#!/bin/bash
# ============================================================================
# patch-winforms-guards.sh
# Adds #If Not HEADLESS / #End If guards around WinForms-dependent code
# in DWSIM.SharedClasses (VB.NET) and DWSIM.SharedClassesCSharp (C#)
# ============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: patch-winforms-guards.sh <dwsim-source-root>}"

echo "=== Patching WinForms guards in SharedClasses ==="

# ============================================================================
# 1. DWSIM.SharedClasses/Misc/ExtensionMethods.vb
#    Complete rewrite with #If Not HEADLESS guards around WinForms extension methods
# ============================================================================
EXTFILE="$DWSIM_ROOT/DWSIM.SharedClasses/Misc/ExtensionMethods.vb"

if [ -f "$EXTFILE" ]; then
    echo "  Patching ExtensionMethods.vb..."
    cat > "$EXTFILE" << 'VBEOF'
#If Not HEADLESS Then
Imports System.Windows.Forms
#End If

Module Extensions

#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()> _
    Public Sub UIThread(control As Control, code As Action)
        If control.InvokeRequired Then
            control.BeginInvoke(code)
        Else
            code.Invoke()
        End If
    End Sub

    <System.Runtime.CompilerServices.Extension()> _
    Public Sub UIThreadInvoke(control As Control, code As Action)
        If control.InvokeRequired Then
            control.Invoke(code)
        Else
            code.Invoke()
        End If
    End Sub

    <System.Runtime.CompilerServices.Extension()> _
    Public Function GetUnits(control As System.Windows.Forms.GridItem) As String
        If control.Value.ToString().Split(" ").Length > 1 Then
            Return control.Value.ToString.Substring(control.Value.ToString.IndexOf(" "c) + 1, control.Value.ToString.Length - control.Value.ToString.IndexOf(" "c) - 1)
        Else
            Return ""
        End If
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function GetValue(control As System.Windows.Forms.GridItem) As Double
        Dim istring As Object
        If control.Value.ToString().Split(" ").Length > 1 Then
            istring = control.Value.ToString().Split(" ")(0)
            If Double.TryParse(istring.ToString, New Double) Then
                Return Convert.ToDouble(istring)
            Else
                Return Double.NaN
            End If
        ElseIf control.Value.ToString().Split(" ").Length = 1 Then
            istring = control.Value
            If Double.TryParse(istring.ToString, New Double) Then
                Return Convert.ToDouble(control.Value)
            Else
                Return Double.NaN
            End If
        Else
            Return Double.NaN
        End If
    End Function
#End If

    <System.Runtime.CompilerServices.Extension()> _
    Public Function ToArrayString(vector As Double()) As String

        Dim retstr As String = "{ "
        For Each d In vector
            retstr += d.ToString + ", "
        Next
        retstr.TrimEnd(",")
        retstr += "}"

        Return retstr

    End Function

    <System.Runtime.CompilerServices.Extension()>
    Public Function ToArrayString(vector As Double(), ByVal ci As System.Globalization.CultureInfo) As String

        If vector.Length > 1 Then

            Dim retstr As String = "{"
            For Each d As Double In vector
                retstr += d.ToString(ci) + "; "
            Next
            retstr = retstr.TrimEnd(New Char() {";"c, " "c})
            retstr += "}"

            Return retstr

        ElseIf vector.Length > 0 Then

            Return vector(0).ToString(ci)

        Else

            Return ""

        End If

    End Function

    <System.Runtime.CompilerServices.Extension()>
    Public Function ToDoubleArray(text As String, ByVal ci As System.Globalization.CultureInfo) As Double()

        Dim numbers As String() = text.Trim(New Char() {"{"c, "}"c}).Split(";"c)

        Dim doubles As New List(Of Double)

        For Each n As String In numbers
            If n <> "" Then doubles.Add(Convert.ToDouble(n, ci))
        Next

        Return doubles.ToArray

    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function ToArrayString(vector As String()) As String

        Dim retstr As String = "{ "
        For Each s In vector
            retstr += s + ", "
        Next
        retstr.TrimEnd(",")
        retstr += "}"

        Return retstr

    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function ToArrayString(vector As Object()) As String

        Dim retstr As String = "{ "
        For Each d In vector
            retstr += d.ToString + ", "
        Next
        retstr.TrimEnd(",")
        retstr += "}"

        Return retstr

    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function ToArrayString(vector As Array) As String

        Dim retstr As String = "{ "
        For Each d In vector
            retstr += d.ToString + ", "
        Next
        retstr.TrimEnd(",")
        retstr += "}"

        Return retstr

    End Function

#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()> _
    Public Sub PasteData(dgv As DataGridView)

        PasteData2(dgv, Clipboard.GetText())

    End Sub

    <System.Runtime.CompilerServices.Extension()> _
    Public Sub PasteData2(dgv As DataGridView, data As String)

        Dim tArr() As String
        Dim arT() As String
        Dim i, ii As Integer
        Dim c, cc, r As Integer

        tArr = data.Split(New Char() {vbLf, vbCr, vbCrLf})

        If dgv.SelectedCells.Count > 0 Then
            r = dgv.SelectedCells(0).RowIndex
            c = dgv.SelectedCells(0).ColumnIndex
        Else
            r = 0
            c = 0
        End If
        For i = 0 To tArr.Length - 1
            If tArr(i) <> "" Then
                arT = tArr(i).Split(Char.ConvertFromUtf32(9))
                For ii = 0 To arT.Length - 1
                    If r > dgv.Rows.Count - 1 Then
                        dgv.Rows.Add()
                    End If
                Next
                r = r + 1
            End If
        Next
        If dgv.SelectedCells.Count > 0 Then
            r = dgv.SelectedCells(0).RowIndex
            c = dgv.SelectedCells(0).ColumnIndex
        Else
            r = 0
            c = 0
        End If
        For i = 0 To tArr.Length - 1
            If tArr(i) <> "" Then
                arT = tArr(i).Split(Char.ConvertFromUtf32(9))
                cc = c
                If r <= dgv.Rows.Count - 1 Then
                    For ii = 0 To arT.Length - 1
                        cc = GetNextVisibleCol(dgv, cc)
                        If cc > dgv.ColumnCount - 1 Then Exit For
                        dgv.Item(cc, r).Value = arT(ii).TrimStart
                        cc = cc + 1
                    Next
                End If
                r = r + 1
            End If
        Next

    End Sub

    Function GetNextVisibleCol(dgv As DataGridView, stidx As Integer) As Integer

        Dim i As Integer

        For i = stidx To dgv.ColumnCount - 1
            If dgv.Columns(i).Visible Then Return i
        Next

        Return Nothing

    End Function
#End If

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsValid(d As Double) As Boolean
        If Double.IsNaN(d) Or Double.IsInfinity(d) Then Return False Else Return True
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsValid(d As Nullable(Of Double)) As Boolean
        If Double.IsNaN(d.GetValueOrDefault) Or Double.IsInfinity(d.GetValueOrDefault) Then Return False Else Return True
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsPositive(d As Double) As Boolean
        If d.IsValid() Then
            If d > 0.0# Then Return True Else Return False
        Else
            Throw New ArgumentException("invalid double")
        End If
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsPositive(d As Nullable(Of Double)) As Boolean
        If d.GetValueOrDefault.IsValid() Then
            If d.GetValueOrDefault > 0.0# Then Return True Else Return False
        Else
            Throw New ArgumentException("invalid double")
        End If
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsNegative(d As Double) As Boolean
        If d.IsValid() Then
            If d < 0.0# Then Return True Else Return False
        Else
            Throw New ArgumentException("invalid double")
        End If
    End Function

    <System.Runtime.CompilerServices.Extension()> _
    Public Function IsNegative(d As Nullable(Of Double)) As Boolean
        If d.GetValueOrDefault.IsValid() Then
            If d.GetValueOrDefault < 0.0# Then Return True Else Return False
        Else
            Throw New ArgumentException("invalid double")
        End If
    End Function

    ''' <summary>
    ''' Alternative implementation for the Exponential (Exp) function.
    ''' </summary>
    ''' <param name="val"></param>
    ''' <returns></returns>
    ''' <remarks></remarks>
    <System.Runtime.CompilerServices.Extension()> Public Function ExpY(val As Double) As Double
        Dim tmp As Long = CLng(1512775 * val + 1072632447)
        Return BitConverter.Int64BitsToDouble(tmp << 32)
    End Function


    ''' <summary>
    ''' Converts a two-dimensional array to a jagged array.
    ''' </summary>
    ''' <typeparam name="T"></typeparam>
    ''' <param name="twoDimensionalArray"></param>
    ''' <returns></returns>
    ''' <remarks></remarks>
    <System.Runtime.CompilerServices.Extension> Public Function ToJaggedArray(Of T)(twoDimensionalArray As T(,)) As T()()

        Dim rowsFirstIndex As Integer = twoDimensionalArray.GetLowerBound(0)
        Dim rowsLastIndex As Integer = twoDimensionalArray.GetUpperBound(0)
        Dim numberOfRows As Integer = rowsLastIndex + 1

        Dim columnsFirstIndex As Integer = twoDimensionalArray.GetLowerBound(1)
        Dim columnsLastIndex As Integer = twoDimensionalArray.GetUpperBound(1)
        Dim numberOfColumns As Integer = columnsLastIndex + 1

        Dim jaggedArray As T()() = New T(numberOfRows - 1)() {}
        For i As Integer = rowsFirstIndex To rowsLastIndex
            jaggedArray(i) = New T(numberOfColumns - 1) {}

            For j As Integer = columnsFirstIndex To columnsLastIndex
                jaggedArray(i)(j) = twoDimensionalArray(i, j)
            Next
        Next
        Return jaggedArray

    End Function

    ''' <summary>
    ''' Converts a jagged array to a two-dimensional array.
    ''' </summary>
    ''' <typeparam name="T"></typeparam>
    ''' <param name="jaggedArray"></param>
    ''' <returns></returns>
    ''' <remarks></remarks>
    <System.Runtime.CompilerServices.Extension> Public Function FromJaggedArray(Of T)(jaggedArray As T()()) As T(,)

        Dim rowsFirstIndex As Integer = jaggedArray.GetLowerBound(0)
        Dim rowsLastIndex As Integer = jaggedArray.GetUpperBound(0)
        Dim numberOfRows As Integer = rowsLastIndex + 1

        Dim columnsFirstIndex As Integer = jaggedArray(0).GetLowerBound(0)
        Dim columnsLastIndex As Integer = jaggedArray(0).GetUpperBound(0)
        Dim numberOfColumns As Integer = columnsLastIndex + 1

        Dim twoDimensionalArray As T(,) = New T(numberOfRows - 1, numberOfColumns - 1) {}
        For i As Integer = rowsFirstIndex To rowsLastIndex
            For j As Integer = columnsFirstIndex To columnsLastIndex
                twoDimensionalArray(i, j) = jaggedArray(i)(j)
            Next
        Next
        Return twoDimensionalArray

    End Function

End Module
VBEOF
    echo "    Done."
fi


# ============================================================================
# 2. DWSIM.SharedClasses/Misc/FOSSEEFlowsheets.vb
#    Wrap the MessageBox.Show block inside LoadFlowsheet with #If Not HEADLESS
# ============================================================================
FOSSEE="$DWSIM_ROOT/DWSIM.SharedClasses/Misc/FOSSEEFlowsheets.vb"

if [ -f "$FOSSEE" ]; then
    echo "  Patching FOSSEEFlowsheets.vb..."

    export PATCH_FILE="$FOSSEE"
    python3 -c "
import os
filepath = os.environ['PATCH_FILE']
with open(filepath, 'r') as f:
    content = f.read()

old = '''        If abstractfile <> \"\" Then
            Task.Factory.StartNew(Sub()
                                      Dim p = Process.Start(abstractfile)
                                      p?.WaitForExit()
                                      If MessageBox.Show(String.Format(\"Delete Abstract File '{0}'?\", abstractfile), \"Delete Abstract File\", MessageBoxButtons.YesNo, MessageBoxIcon.Question) = DialogResult.Yes Then
                                          Try
                                              File.Delete(abstractfile)
                                              MessageBox.Show(\"Abstract File deleted successfully.\", \"DWSIM\")
                                          Catch ex As Exception
                                              MessageBox.Show(ex.Message, \"Error deleting Abstract File\")
                                          End Try
                                      End If
                                  End Sub)
        End If'''

new = '''#If Not HEADLESS Then
        If abstractfile <> \"\" Then
            Task.Factory.StartNew(Sub()
                                      Dim p = Process.Start(abstractfile)
                                      p?.WaitForExit()
                                      If MessageBox.Show(String.Format(\"Delete Abstract File '{0}'?\", abstractfile), \"Delete Abstract File\", MessageBoxButtons.YesNo, MessageBoxIcon.Question) = DialogResult.Yes Then
                                          Try
                                              File.Delete(abstractfile)
                                              MessageBox.Show(\"Abstract File deleted successfully.\", \"DWSIM\")
                                          Catch ex As Exception
                                              MessageBox.Show(ex.Message, \"Error deleting Abstract File\")
                                          End Try
                                      End If
                                  End Sub)
        End If
#End If'''

if old in content:
    content = content.replace(old, new)
    with open(filepath, 'w') as f:
        f.write(content)
    print('    Done.')
else:
    print('    WARNING: Could not find exact match for FOSSEEFlowsheets MessageBox block')
"
fi


# ============================================================================
# 3. DWSIM.SharedClasses/Misc/MAPI.vb
#    The entire file is Windows-only (MAPI32.DLL P/Invoke + MessageBox)
#    Wrap the entire content in #If Not HEADLESS
# ============================================================================
MAPIFILE="$DWSIM_ROOT/DWSIM.SharedClasses/Misc/MAPI.vb"

if [ -f "$MAPIFILE" ]; then
    echo "  Patching MAPI.vb (wrap entire file)..."

    export PATCH_FILE="$MAPIFILE"
    python3 -c "
import os
filepath = os.environ['PATCH_FILE']
with open(filepath, 'r') as f:
    content = f.read()

new_content = '#If Not HEADLESS Then\n' + content + '\n#End If\n'
with open(filepath, 'w') as f:
    f.write(new_content)
print('    Done.')
"
fi


# ============================================================================
# 4. DWSIM.SharedClasses/BaseClass/SimulationObjectBaseClasses.vb
#    a) DynamicsPropertyEditor field + Display/Update/Close methods -> wrap
#    b) GetEditingForm() As Form -> wrap (Form is WinForms type)
#    c) Clipboard.SetText -> wrap
# ============================================================================
BASEFILE="$DWSIM_ROOT/DWSIM.SharedClasses/BaseClass/SimulationObjectBaseClasses.vb"

if [ -f "$BASEFILE" ]; then
    echo "  Patching SimulationObjectBaseClasses.vb..."

    export PATCH_FILE="$BASEFILE"
    python3 << 'PYEOF'
import os
filepath = os.environ['PATCH_FILE']
with open(filepath, 'r') as f:
    content = f.read()

patches_applied = 0

# 4a: Wrap DynamicsPropertyEditor field + Display/Update/Close methods
old_dynamics = '''        <NonSerialized> <Xml.Serialization.XmlIgnore> Public fd As DynamicsPropertyEditor

        Public Overridable Sub DisplayDynamicsEditForm() Implements ISimulationObject.DisplayDynamicsEditForm

            If fd Is Nothing Then
                fd = New DynamicsPropertyEditor With {.SimObject = Me}
                fd.ShowHint = WeifenLuo.WinFormsUI.Docking.DockState.DockRight
                fd.Tag = "ObjectEditor"
                Me.FlowSheet.DisplayForm(fd)
            Else
                If fd.IsDisposed Then
                    fd = New DynamicsPropertyEditor With {.SimObject = Me}
                    fd.ShowHint = WeifenLuo.WinFormsUI.Docking.DockState.DockRight
                    fd.Tag = "ObjectEditor"
                    Me.FlowSheet.DisplayForm(fd)
                Else
                    fd.Activate()
                End If
            End If

        End Sub

        Public Sub UpdateDynamicsEditForm() Implements ISimulationObject.UpdateDynamicsEditForm

            If fd IsNot Nothing Then
                If Not fd.IsDisposed Then
                    fd.UIThread(Sub() fd.UpdateInfo())
                End If
            End If

        End Sub

        Public Sub CloseDynamicsEditForm() Implements ISimulationObject.CloseDynamicsEditForm

            If fd IsNot Nothing Then
                If Not fd.IsDisposed Then
                    fd.Close()
                    fd = Nothing
                End If
            End If

        End Sub'''

new_dynamics = '''#If Not HEADLESS Then
        <NonSerialized> <Xml.Serialization.XmlIgnore> Public fd As DynamicsPropertyEditor

        Public Overridable Sub DisplayDynamicsEditForm() Implements ISimulationObject.DisplayDynamicsEditForm

            If fd Is Nothing Then
                fd = New DynamicsPropertyEditor With {.SimObject = Me}
                fd.ShowHint = WeifenLuo.WinFormsUI.Docking.DockState.DockRight
                fd.Tag = "ObjectEditor"
                Me.FlowSheet.DisplayForm(fd)
            Else
                If fd.IsDisposed Then
                    fd = New DynamicsPropertyEditor With {.SimObject = Me}
                    fd.ShowHint = WeifenLuo.WinFormsUI.Docking.DockState.DockRight
                    fd.Tag = "ObjectEditor"
                    Me.FlowSheet.DisplayForm(fd)
                Else
                    fd.Activate()
                End If
            End If

        End Sub

        Public Sub UpdateDynamicsEditForm() Implements ISimulationObject.UpdateDynamicsEditForm

            If fd IsNot Nothing Then
                If Not fd.IsDisposed Then
                    fd.UIThread(Sub() fd.UpdateInfo())
                End If
            End If

        End Sub

        Public Sub CloseDynamicsEditForm() Implements ISimulationObject.CloseDynamicsEditForm

            If fd IsNot Nothing Then
                If Not fd.IsDisposed Then
                    fd.Close()
                    fd = Nothing
                End If
            End If

        End Sub
#Else
        Public Overridable Sub DisplayDynamicsEditForm() Implements ISimulationObject.DisplayDynamicsEditForm
            ' Not available in headless mode
        End Sub

        Public Sub UpdateDynamicsEditForm() Implements ISimulationObject.UpdateDynamicsEditForm
            ' Not available in headless mode
        End Sub

        Public Sub CloseDynamicsEditForm() Implements ISimulationObject.CloseDynamicsEditForm
            ' Not available in headless mode
        End Sub
#End If'''

if old_dynamics in content:
    content = content.replace(old_dynamics, new_dynamics)
    patches_applied += 1
else:
    print("    WARNING: Could not find DynamicsPropertyEditor block")

# 4a2: Wrap ExtraPropertiesEditor As Form
old_extra = '        <NonSerialized()> <Xml.Serialization.XmlIgnore> Public ExtraPropertiesEditor As Form'
new_extra = '''#If Not HEADLESS Then
        <NonSerialized()> <Xml.Serialization.XmlIgnore> Public ExtraPropertiesEditor As Form
#Else
        <NonSerialized()> <Xml.Serialization.XmlIgnore> Public ExtraPropertiesEditor As Object
#End If'''

if old_extra in content:
    content = content.replace(old_extra, new_extra)
    patches_applied += 1
else:
    print("    WARNING: Could not find ExtraPropertiesEditor As Form")

# 4b: Wrap GetEditingForm() As Form
old_editing = '''        Public Overridable Function GetEditingForm() As Form Implements ISimulationObject.GetEditingForm

            Return Nothing

        End Function'''

new_editing = '''#If Not HEADLESS Then
        Public Overridable Function GetEditingForm() As Form Implements ISimulationObject.GetEditingForm
            Return Nothing
        End Function
#Else
        Public Overridable Function GetEditingForm() As Object Implements ISimulationObject.GetEditingForm
            Return Nothing
        End Function
#End If'''

if old_editing in content:
    content = content.replace(old_editing, new_editing)
    patches_applied += 1
else:
    print("    WARNING: Could not find GetEditingForm block")

# 4b2: Wrap DisplayExtraPropertiesEditForm (references FormExtraProperties)
old_display_extra = '''        Public Sub DisplayExtraPropertiesEditForm() Implements ISimulationObject.DisplayExtraPropertiesEditForm'''
if old_display_extra in content:
    # Find the method and wrap it through End Sub
    idx = content.index(old_display_extra)
    # Find next End Sub after idx
    end_idx = content.index('\n        End Sub\n', idx)
    end_idx += len('\n        End Sub\n')
    method_block = content[idx:end_idx]
    wrapped = '#If Not HEADLESS Then\n' + method_block + '#Else\n        Public Sub DisplayExtraPropertiesEditForm() Implements ISimulationObject.DisplayExtraPropertiesEditForm\n        End Sub\n#End If\n'
    content = content[:idx] + wrapped + content[end_idx:]
    patches_applied += 1
else:
    print("    WARNING: Could not find DisplayExtraPropertiesEditForm")

# 4b3: Wrap UpdateExtraPropertiesEditForm (references FormExtraProperties)
old_update_extra = '''        Public Sub UpdateExtraPropertiesEditForm() Implements ISimulationObject.UpdateExtraPropertiesEditForm'''
if old_update_extra in content:
    idx = content.index(old_update_extra)
    end_idx = content.index('\n        End Sub\n', idx)
    end_idx += len('\n        End Sub\n')
    method_block = content[idx:end_idx]
    wrapped = '#If Not HEADLESS Then\n' + method_block + '#Else\n        Public Sub UpdateExtraPropertiesEditForm() Implements ISimulationObject.UpdateExtraPropertiesEditForm\n        End Sub\n#End If\n'
    content = content[:idx] + wrapped + content[end_idx:]
    patches_applied += 1
else:
    print("    WARNING: Could not find UpdateExtraPropertiesEditForm")

# 4c: Wrap Clipboard.SetText
old_clipboard = '            Clipboard.SetText(st.ToString())'
new_clipboard = '''#If Not HEADLESS Then
            Clipboard.SetText(st.ToString())
#End If'''

if old_clipboard in content:
    content = content.replace(old_clipboard, new_clipboard)
    patches_applied += 1
else:
    print("    WARNING: Could not find Clipboard.SetText")

with open(filepath, 'w') as f:
    f.write(content)
print(f"    Applied {patches_applied} patches.")
PYEOF
fi


# ============================================================================
# 5. DWSIM.SharedClassesCSharp/Solids/Solids.cs
#    Remove unused 'using System.Windows.Forms;'
# ============================================================================
SOLIDS="$DWSIM_ROOT/DWSIM.SharedClassesCSharp/Solids/Solids.cs"

if [ -f "$SOLIDS" ]; then
    echo "  Patching Solids.cs (remove unused WinForms using)..."
    sed -i.bak '/^using System\.Windows\.Forms;$/d' "$SOLIDS" && rm -f "${SOLIDS}.bak"
    echo "    Done."
fi


# ============================================================================
# 6. DWSIM.SharedClassesCSharp/FilePicker/FilePickerService.cs
#    Remove WindowsFilePicker reference; use null factory for headless
# ============================================================================
FPSERVICE="$DWSIM_ROOT/DWSIM.SharedClassesCSharp/FilePicker/FilePickerService.cs"

if [ -f "$FPSERVICE" ]; then
    echo "  Patching FilePickerService.cs..."

    export PATCH_FILE="$FPSERVICE"
    python3 -c "
import os
filepath = os.environ['PATCH_FILE']
with open(filepath, 'r') as f:
    content = f.read()

# Remove the Windows FilePicker import
content = content.replace('using DWSIM.SharedClassesCSharp.FilePicker.Windows;\n', '')

# Replace the default factory that references WindowsFilePicker
content = content.replace(
    'private Func<IFilePicker> _filePickerFactory = () => new WindowsFilePicker();',
    'private Func<IFilePicker> _filePickerFactory = () => null; // WindowsFilePicker excluded in headless mode'
)

with open(filepath, 'w') as f:
    f.write(content)
print('    Done.')
"
fi


echo "=== WinForms guard patching complete ==="
