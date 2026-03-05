# Архитектура и описание изменений

## Проблема

DWSIM — open-source симулятор химических процессов, содержащий ~82 проекта на VB.NET и C#. Все проекты целятся в .NET Framework 4.6.1/4.6.2 и активно используют `System.Windows.Forms` — библиотеку десктопного UI Windows. На Linux `System.Windows.Forms` **недоступна**, поэтому проекты не компилируются в .NET 8 на Linux.

WinForms-зависимости пронизывают даже "ядро" симулятора:

| Проект | Проблема |
|--------|----------|
| DWSIM.Interfaces | `System.Windows.Forms.Form` в сигнатурах интерфейсов |
| DWSIM.SharedClasses | 20+ файлов с формами, зависимость от DockPanel |
| DWSIM.Thermodynamics | Ссылки на DockPanel, TabStrip, формы редактирования |
| DWSIM.UnitOperations | DockPanel, TabStrip, ZedGraph, 60+ форм редактирования |
| DWSIM.FlowsheetBase | FormPIDCPEditor, FormTextBoxInput, FormCustomCalcOrder |
| DWSIM.Automation | Классы Automation/Automation2 зависят от UI |

## Решение: патч-система

Вместо форка DWSIM используется **патч-подход**: исходный код DWSIM клонируется из GitHub, после чего 12 скриптов последовательно применяют изменения. Это позволяет легко обновляться до новых версий DWSIM.

### Целевой класс: Automation3

В `DWSIM.Automation` есть три класса автоматизации:
- **Automation** — зависит от FormMain (WinForms), непригоден для headless
- **Automation2** — зависит от Eto.Forms UI
- **Automation3** — использует `Flowsheet2`, **не требует UI**, полностью подходит для headless

### Из 82 проектов собираются 31

Остальные ~51 проект — это десктопные UI (WinForms Classic, Eto.Forms Cross-Platform), тестовые проекты, серверные приложения и вспомогательные контролы.

## Три вида изменений

### 1. Конвертация в SDK-стиль + .NET 8

Все 31 проект были старого формата (`.csproj`/`.vbproj` с `<Project ToolsVersion=...>`). Каждый был заменён на SDK-стиль (`<Project Sdk="Microsoft.NET.Sdk">`) с `<TargetFramework>net8.0</TargetFramework>`.

Что это даёт:
- Компиляция на Linux через `dotnet build`
- Автоматическое включение всех `*.cs`/`*.vb` файлов (не нужно перечислять каждый)
- Современное управление NuGet-зависимостями через `<PackageReference>`

Пример конвертации (DWSIM.Logging):
```xml
<!-- Было: 50+ строк с перечислением каждого файла -->
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

<!-- Стало: 10 строк -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>DWSIM.Logging</RootNamespace>
  </PropertyGroup>
</Project>
```

### 2. Исключение WinForms-файлов

Файлы, которые целиком являются WinForms-формами (редакторы свойств, диалоги конфигурации), исключаются из компиляции:

```xml
<ItemGroup>
  <!-- Исключить все формы редактирования -->
  <Compile Remove="EditingForms\**" />
  <EmbeddedResource Remove="EditingForms\**" />

  <!-- Исключить отдельные файлы -->
  <Compile Remove="ControlPanelMode\FormPIDCPEditor.vb" />
  <Compile Remove="ControlPanelMode\FormTextBoxInput.vb" />
  <Compile Remove="SupportClasses\ComboBoxColumnTemplates.vb" />
</ItemGroup>
```

По тирам:
- **Tier 3** (SharedClasses): исключены `Editors/`, `ComboBoxColumnTemplates.vb`, `ConnectionsEditor.cs`
- **Tier 4** (Inspector): исключены `Window.vb`, `Loading.vb`
- **Tier 5** (Thermodynamics): исключены `EditingForms/` (все пакеты свойств), `Excel.vb`, `ExcelNoAttr.vb`
- **Tier 8** (UnitOperations): исключены `EditingForms/` (~60 форм), `ScintillaExtender.vb`, `ComboBoxColumnTemplates.vb`, PEMFC файлы
- **Tier 9** (FlowsheetBase): исключены `FormPIDCPEditor`, `FormTextBoxInput`, `GraphicObjectControlPanelModeEditors`

### 3. Условная компиляция (#If Not HEADLESS)

Код, который нельзя просто исключить (потому что он в том же файле с нужным кодом), оборачивается в условные блоки:

```vb
' VB.NET:
#If Not HEADLESS Then
    Imports Python.Runtime
#End If

' Метод, использующий WinForms-формы:
#If Not HEADLESS Then
    Private Sub RunScript_PythonNET(script As String)
        ' ... код с Python.Runtime ...
    End Sub
#End If
```

```csharp
// C#:
#if !HEADLESS
    public class Automation : AutomationInterface
    {
        // Зависит от FormMain — недоступна в headless
    }
#endif
```

Символ `HEADLESS` определяется в каждом проекте:
```xml
<DefineConstants>HEADLESS</DefineConstants>
```
И дополнительно передаётся при сборке: `dotnet build -p:DefineConstants=HEADLESS`

#### Важное правило: обёртка на уровне методов

В VB.NET `#If` директивы **не могут** разрывать блоки `If/Else/End If`, `Using/End Using`, `With/End With`. Поэтому обёртка делается на уровне целых методов:

```vb
' ПРАВИЛЬНО — весь метод обёрнут:
#If Not HEADLESS Then
    Private Sub ShowForm()
        Dim f As New EditingForm()
        f.Show()
    End Sub
#End If

' НЕПРАВИЛЬНО — разрывает If/Else:
If condition Then
    #If Not HEADLESS Then
    DoSomethingUI()
    #End If
Else            ' ← Ошибка: "Else без If"
    DoSomethingElse()
End If
```

Для методов, которые реализуют интерфейс (и сигнатура должна остаться видимой), оборачивается только тело:

```vb
Public Sub Initialize() Implements ICapeUtilities.Initialize
    #If Not HEADLESS Then
        ' ... тело с UI-кодом ...
    #End If
End Sub
```

## Tier-by-tier описание

### Tier 0: Базовые библиотеки (4 проекта)

**DWSIM.Logging** — логирование, чистый проект без WinForms.

**DWSIM.Interfaces** — корневые интерфейсы, от которых зависит всё остальное.
- Изменение: `System.Windows.Forms.Form` → `Object` в сигнатурах интерфейсов (`ISimulationObject`, `ISplashScreen`, `IWelcomeScreen`, `IExtender`)
- Изменение: `System.Drawing.Bitmap` → `Object` в `IGraphicObject`, `IExtender`
- Удалён `Imports System.Windows.Forms` из нескольких файлов

**DWSIM.DrawingTools.Point** — структура данных Point, без зависимостей.

**DWSIM.Thermodynamics.CoolPropInterface** — обёртка CoolProp, чистый проект.

### Tier 1: Инфраструктура (2 проекта)

**DWSIM.GlobalSettings** — глобальные настройки симулятора.
- Обёрнуты: `Imports Cudafy` и `Imports Python.Runtime` в `#If Not HEADLESS`
- Замена: `My.Application.Info.DirectoryPath` → `AppDomain.CurrentDomain.BaseDirectory`

**DWSIM.Serializers.XML** — XML-сериализатор.
- Добавлены: `SYSLIB0011`, `SYSLIB0050` в NoWarn (BinaryFormatter/FormatterServices obsolete в .NET 8)

### Tier 2: Математика (6 проектов)

**DWSIM.MathOps, DotNumerics, RandomOps, SwarmOps, SimpsonIntegrator** — чистые математические библиотеки, без WinForms.

**DWSIM.MathOps.Mapack** — линейная алгебра.
- Добавлен instance-метод `Multiply(double scalar)` (в оригинальном `Mapack.dll` он был, в исходниках — только статический)
- Важно: в UnitOperations заменена ссылка на `Mapack.dll` → `ProjectReference` на этот проект (устранение неоднозначности типов)

### Tier 3: SharedClasses (2 проекта)

**DWSIM.SharedClasses** — самый "заражённый" WinForms проект.
- Исключены: `Editors/` (все формы редактирования), `ComboBoxColumnTemplates.vb`
- Удалены ссылки: Controls.DockPanel, WeifenLuo.WinFormsUI
- Обёрнуты `#If Not HEADLESS`: `TextBoxStreamWriter` (использует TextBox), методы `GetEditingForm`/`DisplayEditingForm` в 18+ файлах
- `MyType=Empty` — отключает VB.NET My.Computer/My.Application/My.Resources

**DWSIM.SharedClassesCSharp** — C# часть.
- Исключён: `ConnectionsEditor.cs` (UserControl)

### Tier 4: Расширения (3 проекта)

**DWSIM.ExtensionMethods** — вспомогательные методы включая `ToArrayString()`.
- Файл `Extenders/ExtensionMethods.vb` **не исключён** (содержит нужные перегрузки ToArrayString, без WinForms кода)

**DWSIM.ExtensionMethods.Eto** — расширения для Eto.Forms, чистый проект.

**DWSIM.Inspector** — инспектор объектов.
- Исключены: `Window.vb`, `Loading.vb` (формы)

### Tier 5: Термодинамика (6 проектов)

**DWSIM.Thermodynamics** — главный пакет, самый большой.
- Исключены: `EditingForms/` (все визуальные редакторы пакетов свойств)
- Исключены: `Interfaces/Excel.vb`, `ExcelNoAttr.vb` (ExcelDna)
- Удалены ссылки: ExcelDna, RichTextBoxExtended, Scintilla.Eto, IronPython.Wpf, WindowsBase, PresentationCore, unvell.ReoGrid, DockPanel, TabStrip
- Обёрнуты: `GetEditingForm()`, `DisplayEditingForm()`, `DisplayGroupedEditingForm()`, `DisplayFlashConfigForm()` в 18+ файлах пакетов свойств

**Остальные 5 sub-пакетов** (GERG2008, PCSAFT2, PRSRKTDep, ThermoC, Reaktoro):
- Исключены формы конфигурации (`FormConfig.vb`)
- Удалены ненужные UI-ссылки

### Tier 6: Рисование (3 проекта)

**DWSIM.DrawingTools.SkiaSharp** и **Extended** — рисование технологических схем через SkiaSharp.
- SkiaSharp оставлен на версии 2.88.9 (совместимость с кодом DWSIM)
- Добавлен `SkiaSharp.NativeAssets.Linux` для native-библиотек на Linux

**DWSIM.SkiaSharp.Views.Desktop** — desktop-специфичные расширения SkiaSharp.

### Tier 7: Решатель (2 проекта)

**DWSIM.FlowsheetSolver** — ядро решателя.
- Удалён: `Cudafy.NET` (GPU-вычисления, не нужны)
- Обёрнуты: ссылки на CudafyHost в `#If Not HEADLESS`

**DWSIM.DynamicsManager** — управление динамическими расчётами, чистый проект.

### Tier 8: Аппараты (1 проект)

**DWSIM.UnitOperations** — самый тяжёлый по WinForms.
- Исключены: `EditingForms/` (~60 форм для каждого аппарата)
- Исключены: `ScintillaExtender.vb`, `ComboBoxColumnTemplates.vb`
- Обёрнуты целыми методами:
  - `CapeOpen.vb`: тело `Initialize()`, методы `UnhandledException`
  - `CapeOpenUO.vb`: `ShowForm()`, конструкторный блок Windows-проверки, поля форм
  - `PythonScriptUO.vb`: весь метод `DisplayScriptEditorForm`, поля fs/fsmono
  - `CustomUO_CO.vb`: весь метод `Edit()`
  - `FlowsheetUO.vb`: замены `My.Computer` → `System.Environment`, `My.Application` → `AppDomain`
- Обёрнуты: `MessageBox.Show`, `NetOffice` Excel COM, `WeifenLuo.DockPanel`, `TableLayoutPanel`, `My.Resources` (с поддержкой Using-блоков)
- Замена: `Mapack.dll` → ProjectReference на `DWSIM.MathOps.Mapack`

### Tier 9: Flowsheet (2 проекта)

**DWSIM.FileStorage** — чтение/запись файлов, чистый проект.

**DWSIM.FlowsheetBase** — ядро flowsheet.
- Исключены: `FormPIDCPEditor`, `FormTextBoxInput`, `GraphicObjectControlPanelModeEditors`
- Обёрнуты: `Imports Python.Runtime`, вызовы `RunScript_PythonNET`, метод целиком `RunScript_PythonNET`
- `ChangeCalculationOrder()` — тело обёрнуто `#If Not HEADLESS`, в headless просто возвращает список без изменений
- Добавлен: `<Import Include="System.Data" />` для типа `DataTable`

### Tier 10: Автоматизация (1 проект)

**DWSIM.Automation** — точка входа.
- Классы `Automation` и `Automation2` обёрнуты в `#if !HEADLESS` (зависят от UI)
- Класс `Automation3` и `Flowsheet2` **оставлены** (headless-совместимы)
- Добавлен: `CopyLocalLockFileAssemblies=true` (все транзитивные DLL копируются в output)
- Добавлен: `SkiaSharp.NativeAssets.Linux` для native-зависимостей

## Как работают патч-скрипты

Каждый скрипт `patches/XX-tierN-*.sh` принимает путь к корню DWSIM (`/src`) и:

1. **Копирует SDK-стиль .csproj/.vbproj** из `patches/tierN/` поверх оригинальных
2. **Удаляет ненужные файлы** (`packages.config`, `My Project/` auto-generated)
3. **Запускает вложенные патч-скрипты** (например, `patch-winforms-guards.sh`) для модификации исходного кода
4. **Применяет .diff файлы** (для точечных изменений)

Патч-скрипты для исходного кода используют:
- **sed** — для простых замен строк
- **Python3** — для сложных многострочных патчей (обёртка методов, блочная обработка)
- **diff/patch** — для точечных изменений

### Обработка кодировок

Некоторые VB.NET файлы содержат не-UTF-8 символы (Latin-1). Все Python-скрипты патчей используют двойную попытку:
```python
try:
    with open(path, 'r', encoding='utf-8-sig') as f:
        content = f.read()
except UnicodeDecodeError:
    with open(path, 'r', encoding='latin-1') as f:
        content = f.read()
```

## Фазы сборки (scripts/build.sh)

| Фаза | Действие | Время |
|------|----------|-------|
| 1 | Применение 12 патч-скриптов | ~10 сек |
| 2 | `dotnet restore` (NuGet) | ~30 сек |
| 3 | `dotnet build` (31 проект) | ~2 мин |
| 4 | Копирование артефактов | ~1 сек |
| 5 | Smoke-тест (6 проверок) | ~15 сек |

## Диаграмма зависимостей

```
Tier 0: Logging  Interfaces  Point  CoolProp
            ↓
Tier 1: GlobalSettings  XMLSerializer
            ↓
Tier 2: MathOps + 5 sub-packages
            ↓
Tier 3: SharedClasses  SharedClassesCSharp
            ↓
Tier 4: ExtensionMethods  ExtensionMethods.Eto  Inspector
            ↓
Tier 5: Thermodynamics + 5 sub-packages
            ↓
Tier 6: DrawingTools.SkiaSharp + Extended + Views.Desktop
            ↓
Tier 7: FlowsheetSolver  DynamicsManager
            ↓
Tier 8: UnitOperations
            ↓
Tier 9: FileStorage  FlowsheetBase
            ↓
Tier 10: Automation (Automation3 + Flowsheet2)
```
