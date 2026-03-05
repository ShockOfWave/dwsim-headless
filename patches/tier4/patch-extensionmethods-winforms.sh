#!/usr/bin/env bash
# =============================================================================
# Source patches for DWSIM.ExtensionMethods General.vb
# Wraps WinForms-dependent methods with #If Not HEADLESS guards
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
GENERAL_VB="${DWSIM_ROOT}/DWSIM.ExtensionMethods/General.vb"

if [ ! -f "${GENERAL_VB}" ]; then
    echo "ERROR: ${GENERAL_VB} not found"
    exit 1
fi

echo "[ExtensionMethods] Patching General.vb - adding HEADLESS guards..."

# Use Python for reliable multi-line text manipulation
export GENERAL_VB
python3 << 'PYEOF'
import sys, os

filepath = os.environ["GENERAL_VB"]

with open(filepath, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# 1. Guard the System.Windows.Forms import
content = content.replace(
    "Imports System.Windows.Forms\n",
    "#If Not HEADLESS Then\nImports System.Windows.Forms\n#End If\n"
)

# 2. Guard ValidateCellForDouble (uses DataGridView, Drawing.Color, SystemSounds)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub ValidateCellForDouble(dgv As DataGridView, e As DataGridViewCellValidatingEventArgs)

        Dim cell As DataGridViewCell = dgv.Rows(e.RowIndex).Cells(e.ColumnIndex)

        If cell.FormattedValue = e.FormattedValue Then Exit Sub

        e.Cancel = Not e.FormattedValue.ToString.IsValidDouble

        If e.Cancel Then
            If Not dgv.EditingControl Is Nothing Then dgv.EditingControl.ForeColor = Drawing.Color.Red
            My.Computer.Audio.PlaySystemSound(Media.SystemSounds.Exclamation)
        Else
            cell.Style.ForeColor = Drawing.Color.Blue
        End If

    End Sub""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Sub ValidateCellForDouble(dgv As DataGridView, e As DataGridViewCellValidatingEventArgs)

        Dim cell As DataGridViewCell = dgv.Rows(e.RowIndex).Cells(e.ColumnIndex)

        If cell.FormattedValue = e.FormattedValue Then Exit Sub

        e.Cancel = Not e.FormattedValue.ToString.IsValidDouble

        If e.Cancel Then
            If Not dgv.EditingControl Is Nothing Then dgv.EditingControl.ForeColor = Drawing.Color.Red
            My.Computer.Audio.PlaySystemSound(Media.SystemSounds.Exclamation)
        Else
            cell.Style.ForeColor = Drawing.Color.Blue
        End If

    End Sub
#End If"""
)

# 3. Guard UIThread (uses Control)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub UIThread(control As Control, code As Action)
        If control.InvokeRequired Then
            control.BeginInvoke(code)
        Else
            code.Invoke()
        End If
    End Sub""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Sub UIThread(control As Control, code As Action)
        If control.InvokeRequired Then
            control.BeginInvoke(code)
        Else
            code.Invoke()
        End If
    End Sub
#End If"""
)

# 4. Guard UIThreadInvoke (uses Control)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub UIThreadInvoke(control As Control, code As Action)
        If control.InvokeRequired Then
            control.BeginInvoke(code)
        Else
            code.Invoke()
        End If
    End Sub""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Sub UIThreadInvoke(control As Control, code As Action)
        If control.InvokeRequired Then
            control.BeginInvoke(code)
        Else
            code.Invoke()
        End If
    End Sub
#End If"""
)

# 5. Guard GetUnits (uses System.Windows.Forms.GridItem)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Function GetUnits(control As System.Windows.Forms.GridItem) As String
        If control.Value.ToString().Split(" ").Length > 1 Then
            Return control.Value.ToString.Substring(control.Value.ToString.IndexOf(" "c) + 1, control.Value.ToString.Length - control.Value.ToString.IndexOf(" "c) - 1)
        Else
            Return ""
        End If
    End Function""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Function GetUnits(control As System.Windows.Forms.GridItem) As String
        If control.Value.ToString().Split(" ").Length > 1 Then
            Return control.Value.ToString.Substring(control.Value.ToString.IndexOf(" "c) + 1, control.Value.ToString.Length - control.Value.ToString.IndexOf(" "c) - 1)
        Else
            Return ""
        End If
    End Function
#End If"""
)

# 6. Guard GetValue (uses System.Windows.Forms.GridItem)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
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
    End Function""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
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
#End If"""
)

# 7. Guard DropDownWidth (uses ListView, TextRenderer)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Function DropDownWidth(control As ListView) As Integer
        Dim maxWidth As Integer = 0, temp As Integer = 0
        For Each obj As Object In control.Items
            temp = TextRenderer.MeasureText(obj.ToString(), control.Font).Width
            If temp > maxWidth Then
                maxWidth = temp
            End If
        Next
        Return maxWidth
    End Function""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Function DropDownWidth(control As ListView) As Integer
        Dim maxWidth As Integer = 0, temp As Integer = 0
        For Each obj As Object In control.Items
            temp = TextRenderer.MeasureText(obj.ToString(), control.Font).Width
            If temp > maxWidth Then
                maxWidth = temp
            End If
        Next
        Return maxWidth
    End Function
#End If"""
)

# 8. Guard DropDownHeight (uses ListView, TextRenderer)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Function DropDownHeight(control As ListView) As Integer
        Dim Height As Integer = 0, temp As Integer = 0
        For Each obj As Object In control.Items
            temp = TextRenderer.MeasureText(obj.ToString(), control.Font).Height
            Height += temp
        Next
        Return Height
    End Function""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Function DropDownHeight(control As ListView) As Integer
        Dim Height As Integer = 0, temp As Integer = 0
        For Each obj As Object In control.Items
            temp = TextRenderer.MeasureText(obj.ToString(), control.Font).Height
            Height += temp
        Next
        Return Height
    End Function
#End If"""
)

# 9. Guard PasteData (uses DataGridView, Clipboard)
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub PasteData(dgv As DataGridView, Optional ByVal addnewline As Boolean = True)

        PasteData2(dgv, Clipboard.GetText(), addnewline)

    End Sub""",
    """#If Not HEADLESS Then
    <System.Runtime.CompilerServices.Extension()>
    Public Sub PasteData(dgv As DataGridView, Optional ByVal addnewline As Boolean = True)

        PasteData2(dgv, Clipboard.GetText(), addnewline)

    End Sub"""
)

# 10. Guard PasteData2 + GetNextVisibleCol (uses DataGridView, Clipboard)
# These are contiguous, ending just before the IsValid function
content = content.replace(
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub PasteData2(dgv As DataGridView, data As String, Optional ByVal addnewline As Boolean = True)

        Dim tArr() As String
        Dim arT() As String
        Dim i, ii As Integer
        Dim c, cc, r As Integer

        Dim sep = New String() {Environment.NewLine}

        tArr = Clipboard.GetText().Split(sep, StringSplitOptions.RemoveEmptyEntries)

        If dgv.SelectedCells.Count > 0 Then
            r = dgv.SelectedCells(0).RowIndex
            c = dgv.SelectedCells(0).ColumnIndex
        Else
            r = 0
            c = 0
        End If
        For i = 0 To tArr.Length - 1
            If tArr(i) <> "" Then
                arT = tArr(i).Split(vbTab)
                For ii = 0 To arT.Length - 1
                    If r > dgv.Rows.Count - 1 Then
                        If addnewline Then dgv.Rows.Add()
                        dgv.Rows(0).Cells(0).Selected = True
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
                arT = tArr(i).Split(New Char() {vbTab, ";"})
                cc = c
                For ii = 0 To arT.Length - 1
                    Try
                        cc = GetNextVisibleCol(dgv, cc)
                        If cc > dgv.ColumnCount - 1 Then Exit For
                        If Not dgv.Item(cc, r).ReadOnly Then
                            dgv.Item(cc, r).Value = arT(ii).TrimStart
                        End If
                        cc = cc + 1
                    Catch ex As Exception
                    End Try
                Next
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

    End Function""",
    """    <System.Runtime.CompilerServices.Extension()>
    Public Sub PasteData2(dgv As DataGridView, data As String, Optional ByVal addnewline As Boolean = True)

        Dim tArr() As String
        Dim arT() As String
        Dim i, ii As Integer
        Dim c, cc, r As Integer

        Dim sep = New String() {Environment.NewLine}

        tArr = Clipboard.GetText().Split(sep, StringSplitOptions.RemoveEmptyEntries)

        If dgv.SelectedCells.Count > 0 Then
            r = dgv.SelectedCells(0).RowIndex
            c = dgv.SelectedCells(0).ColumnIndex
        Else
            r = 0
            c = 0
        End If
        For i = 0 To tArr.Length - 1
            If tArr(i) <> "" Then
                arT = tArr(i).Split(vbTab)
                For ii = 0 To arT.Length - 1
                    If r > dgv.Rows.Count - 1 Then
                        If addnewline Then dgv.Rows.Add()
                        dgv.Rows(0).Cells(0).Selected = True
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
                arT = tArr(i).Split(New Char() {vbTab, ";"})
                cc = c
                For ii = 0 To arT.Length - 1
                    Try
                        cc = GetNextVisibleCol(dgv, cc)
                        If cc > dgv.ColumnCount - 1 Then Exit For
                        If Not dgv.Item(cc, r).ReadOnly Then
                            dgv.Item(cc, r).Value = arT(ii).TrimStart
                        End If
                        cc = cc + 1
                    Catch ex As Exception
                    End Try
                Next
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
#End If"""
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"Patched {filepath}")
PYEOF

# Fix .NET 8 VB.NET: Double.Parse(Object)/Single.Parse(Object) not available
# Replace with Convert.ToDouble/Convert.ToSingle which accept Object
if [ "$(uname)" = "Darwin" ]; then
    sed -i '' 's/Double\.Parse(obj)/Convert.ToDouble(obj)/g' "${GENERAL_VB}"
    sed -i '' 's/Single\.Parse(obj)/Convert.ToSingle(obj)/g' "${GENERAL_VB}"
else
    sed -i 's/Double\.Parse(obj)/Convert.ToDouble(obj)/g' "${GENERAL_VB}"
    sed -i 's/Single\.Parse(obj)/Convert.ToSingle(obj)/g' "${GENERAL_VB}"
fi

# Fix .NET 8 VB.NET type resolution: NumberStyles enum arithmetic returns Integer
# Replace "NumberStyles.Any - NumberStyles.AllowThousands" with bitwise And Not
if [ "$(uname)" = "Darwin" ]; then
    sed -i '' 's/NumberStyles\.Any - NumberStyles\.AllowThousands/NumberStyles.Any And Not NumberStyles.AllowThousands/g' "${GENERAL_VB}"
else
    sed -i 's/NumberStyles\.Any - NumberStyles\.AllowThousands/NumberStyles.Any And Not NumberStyles.AllowThousands/g' "${GENERAL_VB}"
fi

# Fix .NET 8 VB.NET: Double.TryParse(s, style, provider, New Double) -
# "New Double" is not a valid ByRef argument in .NET 8. Use a variable instead.
python3 -c "
import os
filepath = os.environ.get('GENERAL_VB', '${GENERAL_VB}')
with open(filepath, 'r') as f:
    content = f.read()

# Replace 'New Double)' in TryParse calls with a proper variable
# Pattern: Double.TryParse(expr, ..., New Double) Then
content = content.replace(
    'Double.TryParse(nstring, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, New Double)',
    'Double.TryParse(nstring, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, 0.0#)'
)
content = content.replace(
    'Double.TryParse(s, NumberStyles.Any And Not NumberStyles.AllowThousands, ci, New Double)',
    'Double.TryParse(s, NumberStyles.Any And Not NumberStyles.AllowThousands, ci, 0.0#)'
)

with open(filepath, 'w') as f:
    f.write(content)
print('  Fixed NumberStyles and TryParse patterns')
"

echo "[ExtensionMethods] General.vb patched successfully."
