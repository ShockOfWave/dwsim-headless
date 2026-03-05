# Python API

## Обзор

Python-клиент (`dwsim_client.py`) — обёртка над .NET классом `DWSIM.Automation.Automation3` через [pythonnet](https://pythonnet.github.io/). Предоставляет Pythonic API для создания, расчёта и анализа технологических схем.

## DWSIMClient

Главная точка входа.

```python
from dwsim_client import DWSIMClient

# Создание (указать путь к DLL-файлам DWSIM)
client = DWSIMClient("/app/dwsim")

# Или через context manager (автоматически освобождает ресурсы)
with DWSIMClient("/app/dwsim") as client:
    ...
```

### Свойства

| Свойство | Тип | Описание |
|----------|-----|----------|
| `version` | `str` | Версия DWSIM (например, "DWSIM version 9.0.5.0 (...)") |
| `available_compounds` | `list[str]` | Список всех доступных веществ (1480 шт.) |
| `available_property_packages` | `list[str]` | Список пакетов свойств (29 шт.) |

### Методы

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `create_flowsheet()` | `FlowsheetWrapper` | Создать пустую технологическую схему |
| `load_flowsheet(filepath)` | `FlowsheetWrapper` | Загрузить схему из файла `.dwxml`/`.dwxmz` |
| `release()` | — | Освободить ресурсы DWSIM |

## FlowsheetWrapper

Обёртка над технологической схемой DWSIM.

### Настройка схемы

```python
fs = client.create_flowsheet()

# Добавить вещества (имена должны точно совпадать с available_compounds)
fs.add_compound("Water")
fs.add_compound("Ethanol")
fs.add_compound("Methanol")

# Добавить пакет свойств
fs.add_property_package("Peng-Robinson (PR)")
```

### Доступные пакеты свойств

| Пакет | Описание |
|-------|----------|
| `"Peng-Robinson (PR)"` | Кубическое уравнение состояния Пенга-Робинсона |
| `"Soave-Redlich-Kwong (SRK)"` | Кубическое уравнение состояния SRK |
| `"NRTL"` | Модель коэффициентов активности NRTL |
| `"UNIQUAC"` | Модель коэффициентов активности UNIQUAC |
| `"UNIFAC"` | Групповая модель UNIFAC |
| `"Modified UNIFAC (Dortmund)"` | Модифицированная UNIFAC |
| `"CoolProp"` | Высокоточные свойства (NIST) |
| `"Steam Tables (IAPWS-IF97)"` | Таблицы водяного пара |
| `"Raoult's Law"` | Закон Рауля (идеальные растворы) |
| `"GERG-2008"` | Уравнение состояния для газов |
| `"PC-SAFT"` | Статистически-ассоциативное уравнение |
| `"Peng-Robinson 1978 (PR78)"` | Модификация PR 1978 |
| `"Lee-Kesler-Plocker"` | Уравнение Ли-Кеслера-Плоккера |
| `"Black Oil"` | Модель чёрной нефти |
| ... | Полный список: `client.available_property_packages` |

### Добавление объектов

```python
# Материальный поток (с настройкой)
feed = fs.add_material_stream(
    "FEED",
    temperature=350.0,       # K
    pressure=101325.0,       # Pa
    mass_flow=1.0,           # kg/s
    composition={"Water": 0.5, "Ethanol": 0.5}  # мольные доли
)

# Материальный поток (без настройки — настроить позже)
product = fs.add_material_stream("PRODUCT")

# Энергетический поток
energy = fs.add_energy_stream("Q-001")

# Аппарат
mixer = fs.add_unit_operation("Mixer", "MIX-001")
heater = fs.add_unit_operation("Heater", "HTR-001")
flash = fs.add_unit_operation("Vessel", "FLASH")
valve = fs.add_unit_operation("Valve", "VLV-001")

# Произвольный объект по имени типа
obj = fs.add_object("DistillationColumn", "COL-001")
```

### Доступные типы аппаратов

| Тип | Описание |
|-----|----------|
| **Потоки** | |
| `MaterialStream` | Материальный поток |
| `EnergyStream` | Энергетический поток |
| **Смесители/Разделители** | |
| `Mixer` (или `NodeIn`) | Смеситель |
| `Splitter` (или `NodeOut`) | Разделитель |
| **Давление** | |
| `Pump` | Насос |
| `Compressor` | Компрессор |
| `Expander` | Детандер (турбина) |
| `Valve` | Клапан (дроссель) |
| **Теплообмен** | |
| `Heater` | Нагреватель |
| `Cooler` | Холодильник |
| `HeatExchanger` | Теплообменник |
| **Сепарация** | |
| `Vessel` | Флеш-сепаратор |
| `ComponentSeparator` | Компонентный разделитель |
| `Filter` | Фильтр |
| **Колонны** | |
| `ShortcutColumn` | Упрощённая ректификация (Fenske-Underwood) |
| `DistillationColumn` | Полная ректификационная колонна |
| `AbsorptionColumn` | Абсорбер |
| **Реакторы** | |
| `RCT_Conversion` | Реактор конверсии |
| `RCT_Equilibrium` | Равновесный реактор |
| `RCT_Gibbs` | Реактор Гиббса |
| `RCT_CSTR` | Реактор идеального смешения |
| `RCT_PFR` | Реактор идеального вытеснения |
| **Трубопровод** | |
| `Pipe` | Трубопровод |
| `Tank` | Резервуар |
| **Логические** | |
| `OT_Adjust` | Подбор (Adjust) |
| `OT_Spec` | Спецификация |
| `OT_Recycle` | Рецикл |

### Соединение объектов

```python
# connect(source, destination, from_port, to_port)
fs.connect(feed, mixer, 0, 0)       # feed → mixer inlet 0
fs.connect(mixer, product, 0, 0)    # mixer → product

# Для флеш-сепаратора: порт 0 = пар, порт 1 = жидкость
fs.connect(feed, flash, 0, 0)
fs.connect(flash, vapor, 0, 0)      # vapor out
fs.connect(flash, liquid, 1, 0)     # liquid out

# Разъединить
fs.disconnect(feed, mixer)
```

### Расчёт

```python
# Вариант 1: Простой расчёт
errors = fs.solve()
if errors:
    for e in errors:
        print(f"Ошибка: {e}")

# Вариант 2: С таймаутом (секунды)
errors = fs.solve(timeout_seconds=60)

# Вариант 3: Сохранить после расчёта
fs.save("/output/result.dwxmz", compressed=True)
```

### Навигация по объектам

```python
# Список всех объектов
print(fs.list_objects())  # ['FEED', 'MIX-001', 'PRODUCT']

# Получить объект по тегу
obj = fs.get_object("FEED")
```

## MaterialStreamWrapper

Обёртка над материальным потоком с удобными свойствами.

### Чтение результатов

```python
stream = fs.get_object("PRODUCT")

# Основные свойства (только для чтения после расчёта)
print(stream.temperature)  # K
print(stream.pressure)     # Pa
print(stream.mass_flow)    # kg/s
print(stream.molar_flow)   # mol/s

# Состав
comp = stream.get_composition()
# {'Water': 0.38, 'Ethanol': 0.62}

# Текстовый отчёт
print(stream.get_report())
```

### Установка параметров

```python
stream.set_temperature(350.0)    # K
stream.set_pressure(101325.0)    # Pa
stream.set_mass_flow(1.0)        # kg/s
stream.set_molar_flow(30.0)      # mol/s

# Мольный состав
stream.set_composition({
    "Water": 0.5,
    "Ethanol": 0.3,
    "Methanol": 0.2
})
```

### Красивый вывод

```python
print(feed)
# <MaterialStream: FEED T=350.0K P=101325Pa F=1.0000kg/s>
```

## SimulationObjectWrapper

Базовая обёртка для любого объекта (аппарат, поток).

```python
obj = fs.get_object("MIX-001")

# Тег объекта
print(obj.tag)  # "MIX-001"

# Произвольное свойство по коду
value = obj.get_property("PROP_MX_0")

# Установить свойство
obj.set_property("PROP_HT_0", 400.0)

# Текстовый отчёт
print(obj.get_report())

# Доступ к .NET объекту напрямую
net_obj = obj.native
```

## Коды свойств потоков

Основные коды для материальных потоков (`PROP_MS_*`):

| Код | Свойство | Единицы |
|-----|----------|---------|
| `PROP_MS_0` | Температура | K |
| `PROP_MS_1` | Давление | Pa |
| `PROP_MS_2` | Массовый расход | kg/s |
| `PROP_MS_3` | Мольный расход | mol/s |
| `PROP_MS_4` | Объёмный расход | m3/s |
| `PROP_MS_6` | Удельная энтальпия | kJ/kg |
| `PROP_MS_7` | Удельная энтропия | kJ/(kg*K) |

Полный список кодов: [DWSIM Wiki — Object Property Codes](https://dwsim.org/wiki/index.php?title=Object_Property_Codes)

## Полный пример: смешение и нагрев

```python
from dwsim_client import DWSIMClient

with DWSIMClient("/app/dwsim") as client:
    fs = client.create_flowsheet()

    # Вещества и термодинамика
    fs.add_compound("Water")
    fs.add_compound("Ethanol")
    fs.add_property_package("NRTL")

    # Два входных потока
    feed1 = fs.add_material_stream(
        "FEED-1", temperature=300.0, pressure=200000.0,
        mass_flow=0.5, composition={"Water": 0.8, "Ethanol": 0.2}
    )
    feed2 = fs.add_material_stream(
        "FEED-2", temperature=320.0, pressure=200000.0,
        mass_flow=0.3, composition={"Water": 0.3, "Ethanol": 0.7}
    )

    # Смеситель
    mixer = fs.add_unit_operation("Mixer", "MIX-001")
    mixed = fs.add_material_stream("MIXED")

    # Нагреватель
    heater = fs.add_unit_operation("Heater", "HTR-001")
    hot = fs.add_material_stream("HOT")
    energy = fs.add_energy_stream("Q-HTR")

    # Соединения
    fs.connect(feed1, mixer, 0, 0)
    fs.connect(feed2, mixer, 0, 1)
    fs.connect(mixer, mixed, 0, 0)
    fs.connect(mixed, heater, 0, 0)
    fs.connect(heater, hot, 0, 0)
    fs.connect(energy, heater, 0, 0)

    # Установить температуру нагрева
    heater.set_property("PROP_HT_0", 380.0)  # Target T = 380K
    heater.set_property("PROP_HT_1", 0.0)    # Delta P = 0

    # Расчёт
    errors = fs.solve()
    if errors:
        print("Ошибки:", errors)
    else:
        print(f"Смешанный поток: {mixed.temperature:.1f} K, {mixed.mass_flow:.4f} kg/s")
        print(f"Нагретый поток:  {hot.temperature:.1f} K, {hot.mass_flow:.4f} kg/s")
        print(f"Состав: {hot.get_composition()}")
```

## Работа с загруженными файлами

```python
with DWSIMClient("/app/dwsim") as client:
    # Загрузить существующую схему
    fs = client.load_flowsheet("/path/to/simulation.dwxmz")

    # Изменить параметры
    feed = fs.get_object("S-01")
    feed.set_property("PROP_MS_0", 400.0)  # Изменить температуру

    # Пересчитать
    errors = fs.solve()

    # Прочитать результаты
    product = fs.get_object("S-05")
    print(product.get_report())

    # Сохранить
    fs.save("/output/modified.dwxmz")
```

## Доступ к .NET объектам

Для продвинутого использования можно работать с .NET объектами напрямую через pythonnet:

```python
# Получить .NET flowsheet
net_fs = fs.native

# Вызвать любой .NET метод
for obj in net_fs.SimulationObjects.Values:
    print(f"{obj.GraphicObject.Tag}: {obj.GetType().Name}")

# Работа с перечислениями
from DWSIM.Interfaces.Enums.GraphicObjects import ObjectType
obj = net_fs.AddObject(ObjectType.Valve, 100, 100, "VLV-001")
```
