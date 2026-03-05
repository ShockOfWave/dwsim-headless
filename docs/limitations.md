# Ограничения и известные проблемы

## Функциональные ограничения

### Отключённый функционал (обёрнут в #If Not HEADLESS)

| Функционал | Причина | Влияние |
|------------|---------|---------|
| **Формы редактирования** (EditingForms) | Зависят от System.Windows.Forms | Нельзя визуально редактировать свойства аппаратов. Все свойства доступны программно через `SetPropertyValue()` |
| **Python.NET скрипты** (PythonScriptUO) | Зависит от Python.Runtime.dll для Windows | `PythonScriptUO` нельзя использовать для выполнения пользовательских Python-скриптов внутри DWSIM. Обходной путь: вычисляйте в Python и передавайте результаты через API |
| **CapeOpen UI** (CustomUO_CO.Edit) | Зависит от WinForms форм | CapeOpen unit operations работают, но метод `Edit()` недоступен. Конфигурация — через программный API |
| **ChangeCalculationOrder** | Использует FormCustomCalcOrder | В headless просто возвращает текущий порядок без изменений. Порядок расчёта определяется автоматически решателем |
| **NetOffice Excel COM** (Spreadsheet.vb) | COM Automation для Excel на Windows | Чтение/запись Excel через COM недоступно. Данные можно передавать через Python |
| **DynamicsPropertyEditor** | WinForms редактор | Динамические свойства доступны программно |

### IronPython скрипты

IronPython (`RunScript_IronPython`) **работает**. Только Python.NET (`RunScript_PythonNET`) отключён. Если ваши скрипты написаны для IronPython, они будут работать.

### SkiaSharp рисование

Рисование технологических схем через SkiaSharp **работает** — `CreateFlowsheet()` создаёт полноценный `Flowsheet2` с поддержкой рисования. Но для корректной работы SkiaSharp на Linux необходимы:
- `libfontconfig1` и `fonts-dejavu-core` (установлены в Docker-образе)
- Нативная библиотека `libSkiaSharp.so` правильной архитектуры (копируется автоматически)

## Совместимость

### NuGet-зависимости

Некоторые NuGet-пакеты не имеют нативной поддержки .NET 8 и используются в режиме совместимости:

| Пакет | Предупреждение | Влияние |
|-------|---------------|---------|
| GemBox.Spreadsheet 39.3.30.1215 | NU1701: restored using .NET Framework | Может не работать полностью. Используется для экспорта результатов в таблицы |
| iTextSharp-LGPL 4.1.6 | NU1701: restored using .NET Framework | Может не работать полностью. Используется для экспорта PDF |

### Архитектура процессора

Docker-образ собирается для архитектуры хост-машины:
- **x86_64** (Intel/AMD) — полностью поддерживается
- **aarch64** (Apple Silicon, ARM) — полностью поддерживается

Нативная библиотека SkiaSharp автоматически выбирается под текущую архитектуру в `scripts/build.sh`.

### Предупреждения при сборке

Сборка завершается с **362 предупреждениями** (0 ошибок). Основные категории:

| Категория | Количество | Описание |
|-----------|-----------|----------|
| CA1416 | ~100 | Platform-specific API (System.Drawing, FontConverter) — эти API вызываются только на Windows-пути кода |
| BC42016/BC42020 | ~150 | VB.NET implicit conversions — стиль оригинального кода |
| SYSLIB0011 | ~20 | BinaryFormatter obsolete — используется для совместимости со старыми файлами |
| CS0618 | ~10 | SkiaSharp deprecated API — GRBackendRenderTargetDesc |
| NU1701 | ~5 | .NET Framework package compatibility |

Эти предупреждения **не влияют** на работоспособность для headless-использования.

## Что делать, если...

### Нужен аппарат, для которого нет формы редактирования

Все аппараты **работают**. Формы нужны только для визуального редактирования. Программно:

```python
# Создать аппарат
heater = fs.add_unit_operation("Heater", "HTR-001")

# Установить свойства через коды
heater.set_property("PROP_HT_0", 400.0)  # Outlet temperature
heater.set_property("PROP_HT_1", 0.0)    # Pressure drop
```

Коды свойств для каждого аппарата документированы на [DWSIM Wiki](https://dwsim.org/wiki/index.php?title=Object_Property_Codes).

### Нужен порядок расчёта отличный от автоматического

Решатель DWSIM автоматически определяет порядок расчёта аппаратов. В headless-режиме `ChangeCalculationOrder()` возвращает текущий порядок без изменений (нет UI-диалога для ручного изменения). Обычно автоматический порядок работает корректно.

### Ошибка загрузки libSkiaSharp.so

Если при вызове `CreateFlowsheet()` возникает `DllNotFoundException: libSkiaSharp`:
1. Проверьте, что нативная библиотека скопирована: `ls /app/dwsim/libSkiaSharp.so`
2. Проверьте архитектуру: `file /app/dwsim/libSkiaSharp.so` должна совпадать с `uname -m`
3. Проверьте зависимости: `apt-get install libfontconfig1 fonts-dejavu-core`

### Нужна новая версия DWSIM

Патчи разработаны для текущей версии DWSIM (ветка `windows`). При обновлении DWSIM патчи могут потребовать корректировки, если:
- Добавлены новые файлы с WinForms
- Изменились сигнатуры обёрнутых методов
- Добавлены новые зависимости

Рекомендуется после обновления запускать полную сборку и проверять smoke-тест.
