# DWSIM Headless Build

Сборка [DWSIM](https://github.com/DanWBR/dwsim) (open-source симулятор химических процессов) из исходников как headless-движок для Linux Docker с .NET 8. Предоставляет Python API для программного создания и расчёта технологических схем.

**DWSIM версия:** 9.0.5.0 | **1480 веществ** | **29 пакетов свойств** | **31 проект из ~82**

## Быстрый старт

```bash
# Клонировать репозиторий с субмодулем DWSIM
git clone --recursive https://github.com/ShockOfWave/dwsim-headless.git
cd dwsim-headless

# Собрать Docker-образ (~10 мин, нужно ~10 ГБ диска)
docker build -t dwsim-headless .

# Проверить, что всё работает
docker run --rm dwsim-headless
# Вывод:
# DWSIM Version: DWSIM version 9.0.5.0 (...)
# Compounds: 1480
# Property Packages: 29
```

> **Важно:** флаг `--recursive` обязателен — он скачивает исходники DWSIM как git-субмодуль. Если вы уже клонировали без этого флага:
> ```bash
> git submodule update --init
> ```

## Пример: Flash-разделение

```bash
docker run --rm dwsim-headless python3 /app/python/example_flash.py /app/dwsim
```

Или через интерактивный Python:

```bash
docker run --rm -it dwsim-headless python3
```

```python
from dwsim_client import DWSIMClient

with DWSIMClient("/app/dwsim") as client:
    fs = client.create_flowsheet()

    # Добавить вещества и пакет свойств
    fs.add_compound("Water")
    fs.add_compound("Ethanol")
    fs.add_property_package("Peng-Robinson (PR)")

    # Создать поток питания: 350K, 1 атм, 1 кг/с, 50/50 Water/Ethanol
    feed = fs.add_material_stream(
        "FEED", temperature=350.0, pressure=101325.0,
        mass_flow=1.0, composition={"Water": 0.5, "Ethanol": 0.5}
    )

    # Добавить флеш-сосуд и выходные потоки
    flash = fs.add_unit_operation("Vessel", "FLASH")
    vapor = fs.add_material_stream("VAPOR")
    liquid = fs.add_material_stream("LIQUID")

    # Соединить: питание → флеш → пар + жидкость
    fs.connect(feed, flash, 0, 0)
    fs.connect(flash, vapor, 0, 0)
    fs.connect(flash, liquid, 1, 0)

    # Рассчитать
    errors = fs.solve()
    if not errors:
        print(f"Пар:      {vapor.mass_flow:.4f} кг/с, {vapor.temperature:.1f} K")
        print(f"Жидкость: {liquid.mass_flow:.4f} кг/с, {liquid.temperature:.1f} K")
```

Результат:
```
Пар:      0.8909 кг/с, 350.0 K
Жидкость: 0.1091 кг/с, 350.0 K
```

## Требования

- **Docker** (Docker Desktop или Docker Engine)
- **Git** с поддержкой субмодулей
- **~10 ГБ** свободного места на диске
- Интернет-соединение (для скачивания NuGet-пакетов при сборке)

## Структура проекта

```
├── Dockerfile                  # Многоступенчатая сборка (build → runtime)
├── docker-compose.yml          # Docker Compose сервисы
├── LICENSE                     # GPL-3.0
├── dwsim/                      # Git-субмодуль: исходники DWSIM (ветка windows)
├── patches/                    # Патчи для конвертации DWSIM проектов
│   ├── 00-create-solution-filter.sh
│   ├── 01-tier0-sdk-conversion.sh    # Tier 0: Logging, Interfaces, Point, CoolProp
│   ├── 02-tier1-sdk-conversion.sh    # Tier 1: GlobalSettings, XMLSerializer
│   ├── 03-tier2-math.sh              # Tier 2: Математические библиотеки (6 проектов)
│   ├── 04-tier3-shared.sh            # Tier 3: SharedClasses (WinForms очистка)
│   ├── 05-tier4-extensions.sh        # Tier 4: ExtensionMethods, Inspector
│   ├── 06-tier5-thermo.sh            # Tier 5: Термодинамика (6 проектов)
│   ├── 07-tier6-drawing.sh           # Tier 6: SkiaSharp рисование
│   ├── 08-tier7-solver.sh            # Tier 7: FlowsheetSolver, DynamicsManager
│   ├── 09-tier8-unitops.sh           # Tier 8: UnitOperations (тяжёлая очистка)
│   ├── 10-tier9-flowsheet.sh         # Tier 9: FileStorage, FlowsheetBase
│   ├── 11-tier10-automation.sh       # Tier 10: Automation3
│   ├── DWSIM.Headless.slnf           # Solution filter (31 проект)
│   └── tier0/ ... tier10/            # SDK-стиль проекты + исходные патчи
├── scripts/
│   ├── build.sh                # Главный скрипт сборки (5 фаз)
│   └── test-docker.sh          # Быстрый тест Docker-окружения
├── smoke-test/                 # C# smoke-тесты (6 проверок)
├── python/
│   ├── dwsim_client.py         # Python клиент (обёртка над Automation3)
│   ├── example_flash.py        # Пример flash-разделения
│   └── requirements.txt        # pythonnet>=3.0.3
├── output/                     # Артефакты сборки (DLL файлы)
└── docs/
    ├── architecture.md         # Архитектура и описание изменений
    ├── limitations.md          # Ограничения и известные проблемы
    └── python-api.md           # Справочник Python API
```

## Как устроена сборка

1. **Исходники DWSIM** — подключены как git-субмодуль (ветка `windows`, коммит `ff374e3a0`)
2. **Патчи** — 12 скриптов последовательно применяют изменения:
   - Конвертация проектов из старого формата в SDK-стиль (.NET 8)
   - Исключение WinForms файлов (`<Compile Remove="...">`)
   - Условная компиляция (`#If Not HEADLESS Then`)
   - Замена NuGet-зависимостей
3. **NuGet restore** — скачивание всех зависимостей
4. **Компиляция** — `dotnet build` с символом `HEADLESS`
5. **Smoke-тест** — автоматическая проверка работоспособности

Подробнее: [docs/architecture.md](docs/architecture.md)

## Документация

- [Архитектура и описание изменений](docs/architecture.md) — что именно было изменено и почему это работает
- [Ограничения](docs/limitations.md) — что не работает и почему
- [Python API](docs/python-api.md) — справочник по Python-клиенту

## Docker Compose

```bash
# Только сборка (для отладки)
docker compose run --rm dwsim-build

# Runtime с Python
docker compose run --rm dwsim-runtime python3
```

## Обновление DWSIM

Исходники DWSIM подключены как git-субмодуль, запиненный на конкретный коммит. Это гарантирует, что патчи не сломаются при обновлении upstream. Для обновления до новой версии:

```bash
cd dwsim
git fetch origin windows
git checkout <новый-коммит>
cd ..

# Пересобрать и проверить, что патчи применяются корректно
docker build -t dwsim-headless .
```

При обновлении некоторые патчи могут потребовать правки, если в DWSIM изменились затронутые файлы.

## Благодарности

- [DWSIM](https://github.com/DanWBR/dwsim) — open-source симулятор химических процессов, автор **Daniel Wagner Oliveira de Medeiros** ([@DanWBR](https://github.com/DanWBR))

## Лицензия

Проект распространяется под лицензией [GPL-3.0](LICENSE), аналогично оригинальному DWSIM.

Copyright (C) 2026 Timur Aliev ([@ShockOfWave](https://github.com/ShockOfWave))
