# Architecture and Description of Changes

## Problem

DWSIM is an open-source chemical process simulator containing ~82 projects in VB.NET and C#. All projects target .NET Framework 4.6.1/4.6.2 and heavily use `System.Windows.Forms` -- a Windows desktop UI library. On Linux, `System.Windows.Forms` is **unavailable**, so the projects cannot be compiled with .NET 8 on Linux.

WinForms dependencies permeate even the simulator "core":

| Project | Problem |
|---------|---------|
| DWSIM.Interfaces | `System.Windows.Forms.Form` in interface signatures |
| DWSIM.SharedClasses | 20+ files with forms, DockPanel dependency |
| DWSIM.Thermodynamics | References to DockPanel, TabStrip, editing forms |
| DWSIM.UnitOperations | DockPanel, TabStrip, ZedGraph, 60+ editing forms |
| DWSIM.FlowsheetBase | FormPIDCPEditor, FormTextBoxInput, FormCustomCalcOrder |
| DWSIM.Automation | Automation/Automation2 classes depend on UI |

## Solution: Fork with a Headless Branch

We maintain a fork of [DanWBR/dwsim](https://github.com/DanWBR/dwsim) with a dedicated `headless` branch. All changes required for headless compilation are applied directly to the source code in this branch. This allows us to track upstream changes by rebasing the `headless` branch onto newer upstream commits.

### Target Class: Automation3

`DWSIM.Automation` contains three automation classes:
- **Automation** -- depends on FormMain (WinForms), unusable in headless mode
- **Automation2** -- depends on Eto.Forms UI
- **Automation3** -- uses `Flowsheet2`, **does not require UI**, fully suitable for headless operation

### 31 out of 82 Projects Are Built

The remaining ~51 projects are desktop UI (WinForms Classic, Eto.Forms Cross-Platform), test projects, server applications, and auxiliary controls.

## Three Types of Changes

### 1. Conversion to SDK-Style + .NET 8

All 31 projects used the old format (`.csproj`/`.vbproj` with `<Project ToolsVersion=...>`). Each was replaced with SDK-style (`<Project Sdk="Microsoft.NET.Sdk">`) targeting `<TargetFramework>net8.0</TargetFramework>`.

What this provides:
- Compilation on Linux via `dotnet build`
- Automatic inclusion of all `*.cs`/`*.vb` files (no need to list each one)
- Modern NuGet dependency management via `<PackageReference>`

Conversion example (DWSIM.Logging):
```xml
<!-- Before: 50+ lines listing every file -->
<Project ToolsVersion="15.0">
  <Import Project="$(MSBuildExtensionsPath)\..." />
  <PropertyGroup>
    <TargetFrameworkVersion>v4.6.1</TargetFrameworkVersion>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="Logger.vb" />
    <!-- ... -->
  </ItemGroup>
</Project>

<!-- After: 10 lines -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>DWSIM.Logging</RootNamespace>
  </PropertyGroup>
</Project>
```

### 2. Excluding WinForms Files

Files that are entirely WinForms forms (property editors, configuration dialogs) are excluded from compilation:

```xml
<ItemGroup>
  <!-- Exclude all editing forms -->
  <Compile Remove="EditingForms\**" />
  <EmbeddedResource Remove="EditingForms\**" />

  <!-- Exclude individual files -->
  <Compile Remove="ControlPanelMode\FormPIDCPEditor.vb" />
  <Compile Remove="ControlPanelMode\FormTextBoxInput.vb" />
  <Compile Remove="SupportClasses\ComboBoxColumnTemplates.vb" />
</ItemGroup>
```

By tier:
- **Tier 3** (SharedClasses): excluded `Editors/`, `ComboBoxColumnTemplates.vb`, `ConnectionsEditor.cs`
- **Tier 4** (Inspector): excluded `Window.vb`, `Loading.vb`
- **Tier 5** (Thermodynamics): excluded `EditingForms/` (all property package editors), `Excel.vb`, `ExcelNoAttr.vb`
- **Tier 8** (UnitOperations): excluded `EditingForms/` (~60 forms), `ScintillaExtender.vb`, `ComboBoxColumnTemplates.vb`, PEMFC files
- **Tier 9** (FlowsheetBase): excluded `FormPIDCPEditor`, `FormTextBoxInput`, `GraphicObjectControlPanelModeEditors`

### 3. Conditional Compilation (#If Not HEADLESS)

Code that cannot simply be excluded (because it resides in the same file as required code) is wrapped in conditional blocks:

```vb
' VB.NET:
#If Not HEADLESS Then
    Imports Python.Runtime
#End If

' Method that uses WinForms forms:
#If Not HEADLESS Then
    Private Sub RunScript_PythonNET(script As String)
        ' ... Python.Runtime code ...
    End Sub
#End If
```

```csharp
// C#:
#if !HEADLESS
    public class Automation : AutomationInterface
    {
        // Depends on FormMain -- unavailable in headless mode
    }
#endif
```

The `HEADLESS` symbol is defined in each project:
```xml
<DefineConstants>HEADLESS</DefineConstants>
```
And additionally passed at build time: `dotnet build -p:DefineConstants=HEADLESS`

#### Important Rule: Wrapping at Method Level

In VB.NET, `#If` directives **cannot** break `If/Else/End If`, `Using/End Using`, or `With/End With` blocks. Therefore, wrapping is done at the level of entire methods:

```vb
' CORRECT -- entire method is wrapped:
#If Not HEADLESS Then
    Private Sub ShowForm()
        Dim f As New EditingForm()
        f.Show()
    End Sub
#End If

' INCORRECT -- breaks If/Else:
If condition Then
    #If Not HEADLESS Then
    DoSomethingUI()
    #End If
Else            ' <-- Error: "Else without If"
    DoSomethingElse()
End If
```

For methods that implement an interface (where the signature must remain visible), only the body is wrapped:

```vb
Public Sub Initialize() Implements ICapeUtilities.Initialize
    #If Not HEADLESS Then
        ' ... body with UI code ...
    #End If
End Sub
```

## Tier-by-Tier Description

### Tier 0: Base Libraries (4 projects)

**DWSIM.Logging** -- logging, a clean project with no WinForms dependencies.

**DWSIM.Interfaces** -- root interfaces that everything else depends on.
- Change: `System.Windows.Forms.Form` -> `Object` in interface signatures (`ISimulationObject`, `ISplashScreen`, `IWelcomeScreen`, `IExtender`)
- Change: `System.Drawing.Bitmap` -> `Object` in `IGraphicObject`, `IExtender`
- Removed `Imports System.Windows.Forms` from several files

**DWSIM.DrawingTools.Point** -- Point data structure, no dependencies.

**DWSIM.Thermodynamics.CoolPropInterface** -- CoolProp wrapper, a clean project.

### Tier 1: Infrastructure (2 projects)

**DWSIM.GlobalSettings** -- global simulator settings.
- Wrapped: `Imports Cudafy` and `Imports Python.Runtime` in `#If Not HEADLESS`
- Replaced: `My.Application.Info.DirectoryPath` -> `AppDomain.CurrentDomain.BaseDirectory`

**DWSIM.Serializers.XML** -- XML serializer.
- Added: `SYSLIB0011`, `SYSLIB0050` to NoWarn (BinaryFormatter/FormatterServices obsolete in .NET 8)

### Tier 2: Mathematics (6 projects)

**DWSIM.MathOps, DotNumerics, RandomOps, SwarmOps, SimpsonIntegrator** -- pure math libraries, no WinForms.

**DWSIM.MathOps.Mapack** -- linear algebra.
- Added instance method `Multiply(double scalar)` (present in the original `Mapack.dll` but only as static in the source code)
- Important: in UnitOperations, the reference to `Mapack.dll` was replaced with a `ProjectReference` to this project (resolving type ambiguity)

### Tier 3: SharedClasses (2 projects)

**DWSIM.SharedClasses** -- the most "infected" WinForms project.
- Excluded: `Editors/` (all editing forms), `ComboBoxColumnTemplates.vb`
- Removed references: Controls.DockPanel, WeifenLuo.WinFormsUI
- Wrapped with `#If Not HEADLESS`: `TextBoxStreamWriter` (uses TextBox), `GetEditingForm`/`DisplayEditingForm` methods in 18+ files
- `MyType=Empty` -- disables VB.NET My.Computer/My.Application/My.Resources

**DWSIM.SharedClassesCSharp** -- C# portion.
- Excluded: `ConnectionsEditor.cs` (UserControl)

### Tier 4: Extensions (3 projects)

**DWSIM.ExtensionMethods** -- utility methods including `ToArrayString()`.
- File `Extenders/ExtensionMethods.vb` is **not excluded** (contains required ToArrayString overloads, no WinForms code)

**DWSIM.ExtensionMethods.Eto** -- extensions for Eto.Forms, a clean project.

**DWSIM.Inspector** -- object inspector.
- Excluded: `Window.vb`, `Loading.vb` (forms)

### Tier 5: Thermodynamics (6 projects)

**DWSIM.Thermodynamics** -- the main package, the largest.
- Excluded: `EditingForms/` (all visual property package editors)
- Excluded: `Interfaces/Excel.vb`, `ExcelNoAttr.vb` (ExcelDna)
- Removed references: ExcelDna, RichTextBoxExtended, Scintilla.Eto, IronPython.Wpf, WindowsBase, PresentationCore, unvell.ReoGrid, DockPanel, TabStrip
- Wrapped: `GetEditingForm()`, `DisplayEditingForm()`, `DisplayGroupedEditingForm()`, `DisplayFlashConfigForm()` in 18+ property package files

**Other 5 sub-packages** (GERG2008, PCSAFT2, PRSRKTDep, ThermoC, Reaktoro):
- Excluded configuration forms (`FormConfig.vb`)
- Removed unnecessary UI references

### Tier 6: Drawing (3 projects)

**DWSIM.DrawingTools.SkiaSharp** and **Extended** -- flowsheet drawing via SkiaSharp.
- SkiaSharp kept at version 2.88.9 (compatibility with DWSIM code)
- Added `SkiaSharp.NativeAssets.Linux` for native libraries on Linux

**DWSIM.SkiaSharp.Views.Desktop** -- desktop-specific SkiaSharp extensions.

### Tier 7: Solver (2 projects)

**DWSIM.FlowsheetSolver** -- solver core.
- Removed: `Cudafy.NET` (GPU computing, not needed)
- Wrapped: references to CudafyHost in `#If Not HEADLESS`

**DWSIM.DynamicsManager** -- dynamic simulation management, a clean project.

### Tier 8: Unit Operations (1 project)

**DWSIM.UnitOperations** -- the heaviest WinForms offender.
- Excluded: `EditingForms/` (~60 forms for each unit operation)
- Excluded: `ScintillaExtender.vb`, `ComboBoxColumnTemplates.vb`
- Wrapped as entire methods:
  - `CapeOpen.vb`: body of `Initialize()`, `UnhandledException` methods
  - `CapeOpenUO.vb`: `ShowForm()`, constructor block with Windows check, form fields
  - `PythonScriptUO.vb`: entire `DisplayScriptEditorForm` method, fs/fsmono fields
  - `CustomUO_CO.vb`: entire `Edit()` method
  - `FlowsheetUO.vb`: replaced `My.Computer` -> `System.Environment`, `My.Application` -> `AppDomain`
- Wrapped: `MessageBox.Show`, `NetOffice` Excel COM, `WeifenLuo.DockPanel`, `TableLayoutPanel`, `My.Resources` (with Using block support)
- Replaced: `Mapack.dll` -> ProjectReference to `DWSIM.MathOps.Mapack`

### Tier 9: Flowsheet (2 projects)

**DWSIM.FileStorage** -- file reading/writing, a clean project.

**DWSIM.FlowsheetBase** -- flowsheet core.
- Excluded: `FormPIDCPEditor`, `FormTextBoxInput`, `GraphicObjectControlPanelModeEditors`
- Wrapped: `Imports Python.Runtime`, calls to `RunScript_PythonNET`, entire `RunScript_PythonNET` method
- `ChangeCalculationOrder()` -- body wrapped with `#If Not HEADLESS`, in headless mode simply returns the list unchanged
- Added: `<Import Include="System.Data" />` for `DataTable` type

### Tier 10: Automation (1 project)

**DWSIM.Automation** -- entry point.
- Classes `Automation` and `Automation2` wrapped in `#if !HEADLESS` (depend on UI)
- Class `Automation3` and `Flowsheet2` are **kept** (headless-compatible)
- Added: `CopyLocalLockFileAssemblies=true` (all transitive DLLs are copied to output)
- Added: `SkiaSharp.NativeAssets.Linux` for native dependencies

## Encoding Handling

Some VB.NET files contain non-UTF-8 characters (Latin-1). Build scripts use a dual-attempt approach:
```python
try:
    with open(path, 'r', encoding='utf-8-sig') as f:
        content = f.read()
except UnicodeDecodeError:
    with open(path, 'r', encoding='latin-1') as f:
        content = f.read()
```

## Build Phases (scripts/build.sh)

| Phase | Action | Time |
|-------|--------|------|
| 1 | `dotnet restore` (NuGet) | ~30 sec |
| 2 | `dotnet build` (31 projects) | ~2 min |
| 3 | Copy artifacts | ~1 sec |
| 4 | Smoke test (6 checks) | ~15 sec |

## Dependency Diagram

```
Tier 0: Logging  Interfaces  Point  CoolProp
            |
Tier 1: GlobalSettings  XMLSerializer
            |
Tier 2: MathOps + 5 sub-packages
            |
Tier 3: SharedClasses  SharedClassesCSharp
            |
Tier 4: ExtensionMethods  ExtensionMethods.Eto  Inspector
            |
Tier 5: Thermodynamics + 5 sub-packages
            |
Tier 6: DrawingTools.SkiaSharp + Extended + Views.Desktop
            |
Tier 7: FlowsheetSolver  DynamicsManager
            |
Tier 8: UnitOperations
            |
Tier 9: FileStorage  FlowsheetBase
            |
Tier 10: Automation (Automation3 + Flowsheet2)
```
