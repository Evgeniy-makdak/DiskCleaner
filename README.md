# Disk Cleaner

**Безопасный чистильщик диска для macOS** — нативное приложение на Swift + SwiftUI + AppKit.

Автор: **Евгений Ацтек** · 2026

Disk Cleaner сканирует файловую систему **только на чтение**, классифицирует находки по трём
корзинам (мусор / данные пользователя / истории-конфиги) и **ничего не удаляет без явного
подтверждения пользователем** через UI. Каждое действие прозрачно: вы видите полный путь,
размер, что это за файл и что будет, если его удалить.

---

## Возможности

- 🔍 **Двухфазное сканирование**: сначала `SystemProbe` собирает информацию о системе
  (`df`, `diskutil apfs list`, `tmutil listlocalsnapshots`, `sw_vers`), затем `Scanner`
  последовательно обходит домашнюю папку, `~/Library`, Application Support, Caches,
  CloudStorage, Containers, системные папки, ищет `code_sign_clone`, файлы больше 200 МБ,
  кэши пакетных менеджеров, DerivedData и CoreSimulator.
- 📊 **Три корзины в отчёте**:
  - **Мусор** (зелёная) — безопасно вернуть: кэши, `code_sign_clone`, CachedData, логи,
    Crashpad, кэши npm/pnpm/yarn/cargo, DerivedData и т.д.
  - **Данные пользователя** (жёлтая) — приложения, проекты, документы, iCloud-кэши.
    Удаление необратимо, решение за вами.
  - **Истории/Конфиги** (красная) — только просмотр: `state.vscdb`, `~/.ssh`, `~/.gnupg`,
    keychains, лицензии, токены. Удаление через приложение невозможно.
- 🛡️ **SafetyGuard** — финальный рубеж: каждый путь повторно проверяется перед удалением.
  Запрещены keychains, `~/.ssh`, `~/.gnupg`, `~/.config`, `~/Library/Preferences`,
  `*.key/pem/p12`, файлы с именами `license/token/secret/credentials`, swap-файлы,
  снапшоты Time Machine, истории AI-ассистентов (Cursor, Code, Claude, Codex, Continue,
  Cline, Koda — чистится только регенерируемое: CachedData, logs, Crashpad и т.п.).
- ☁️ **Облачные файлы** (`~/Library/CloudStorage/*`) никогда не удаляются через
  `FileManager.removeItem` — только `brctl evict` (выгрузка локальной копии, в облаке
  файл остаётся).
- 📦 **Пакетные менеджеры** чистятся только родными командами:
  `npm cache clean --force`, `pnpm store prune`, `yarn cache clean`, `cargo cache --autoclean`.
- 📝 **Логирование**: перед каждым удалением в лог пишется «снимок действия» — путь, размер,
  дата, SHA-256, кто и когда одобрил.
- 🗑️ **Безопасный режим**: по умолчанию файлы перемещаются в Корзину, а не удаляются навсегда.
- 📤 **Экспорт отчёта** в Markdown (кнопка или Cmd+E).
- 🖱️ **Drag-and-drop**: перетащите любую папку в окно — будет просканирована только она.
- 🌐 **Локализация**: русский и английский (определяется автоматически).
- 🔒 **Полностью офлайн**, без сторонних зависимостей, без App Sandbox, работает без root.

---

## Безопасность — главный принцип

1. Приложение **никогда не удаляет ничего без нажатия кнопки** «Подтвердить удаление».
2. Кнопка подтверждения заблокирована, пока вы не отметите чекбокс
   «Я понимаю, что удаление необратимо».
3. Перед удалением `SafetyGuard` повторно проверяет каждый путь — даже одобренный в UI.
4. `Operation not permitted` (SIP/TCC) — это норма, не баг: операция помечается
   «требует прав» и пропускается, приложение продолжает работу.
5. `sudo` никогда не запускается автоматически — только через явный запрос
   (`osascript` с `administrator privileges`, пароль запрашивается системой один раз).

---

## Требования

- macOS 26 или новее (Apple Silicon, arm64)
- Xcode 26+ (для сборки из исходников)
- Swift 5.9+

## Установка

### Вариант 1 — готовый `.app` (если приложили к релизу)

1. Скачайте `DiskCleaner.app`
2. Перетащите в папку **Программы** (`/Applications`)
3. Запустите. При первом запуске macOS может спросить подтверждение —
   нажмите правой кнопкой на приложение → «Открыть», если появится предупреждение Gatekeeper.

### Вариант 2 — сборка из исходников

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/Evgeniy-makdak/DiskCleaner.git
cd DiskCleaner

# 2. Соберите (нужен Xcode)
xcodebuild -project DiskCleaner.xcodeproj -scheme DiskCleaner -configuration Release -derivedDataPath build build

# 3. Запустите
open build/Build/Products/Release/DiskCleaner.app
```

Или откройте `DiskCleaner.xcodeproj` в Xcode, выберите схему **DiskCleaner**,
destination **My Mac** и нажмите **Cmd+R**.

### Первый запуск

1. Приложение предложит открыть **Системные настройки → Конфиденциальность и безопасность →
   Полный доступ к диску**.
2. Добавьте Disk Cleaner в список (кнопка «+» → `/Applications/DiskCleaner.app`) и включите
   переключатель.
3. Полностью перезапустите приложение (Cmd+Q → запуск).
4. Без Full Disk Access приложение работает, но часть путей будет помечена «требует прав».

---

## Как пользоваться

1. **«Начать сканирование»** — приложение просканирует диск (только чтение) с прогресс-баром:
   текущий шаг, процент, найденные гигабайты.
2. **Отчёт** — три вкладки:
   - **Мусор** — отметьте нужное (или «Выбрать всё») → «Очистить выбранное (X ГБ)»
   - **Данные пользователя** — с предупреждением об опасности
   - **Истории/Конфиги** — только просмотр
   Вверху сводка: занято / свободно / найдено мусора / самый большой сюрприз.
   Внизу — «Что выросло недавно» (топ-5 файлов за 7 дней).
3. **Подтверждение** — модальное окно со списком того, что будет удалено (полные пути,
   размеры), предупреждениями о запущенных приложениях и операциях с правами администратора.
   По умолчанию включён безопасный режим «Переместить в Корзину».
4. **Очистка** — прогресс по каждому файлу, пересчёт свободного места, финальный отчёт
   с предложением перезагрузиться (после перезагрузки освободится место APFS-снапшотов).

### Горячие клавиши

| Клавиши | Действие |
|---|---|
| `Cmd+R` | Пересканировать |
| `Cmd+E` | Экспорт отчёта в Markdown |
| `Cmd+Delete` | Очистить выбранное (с подтверждением) |

---

## Тесты

```bash
# Unit-тесты (SafetyGuard, Analyzer, Cleaner)
xcodebuild test -project DiskCleaner.xcodeproj -scheme DiskCleaner -destination 'platform=macOS' -only-testing:DiskCleanerTests

# UI-тесты (полный сценарий + «без подтверждения ничего не удаляется»)
xcodebuild test -project DiskCleaner.xcodeproj -scheme DiskCleaner -destination 'platform=macOS' -only-testing:DiskCleanerUITests
```

## Логи

- Действия: `~/Library/Application Support/DiskCleaner/logs/YYYY-MM-DD_HH-mm-ss.log`
- Ошибки: `~/Library/Application Support/DiskCleaner/errors.log`

---

## Структура проекта

```
DiskCleaner.xcodeproj          — проект Xcode (схема DiskCleaner)
DiskCleaner/
  App/                         — точка входа, AppDelegate, AppState
  Models/                      — ScanItem, ScanResult, ScanProgress, CleaningReport
  Core/                        — SystemProbe, Scanner, Analyzer, SafetyGuard, Cleaner, Reporter, Logger
  Services/                    — CommandRunner, DiskSpace, PackageManagerCleaner, PrivilegedHelper
  UI/                          — SwiftUI-экраны (приветствие, сканирование, отчёт, подтверждение, очистка)
  Support/                     — локализация (ru/en), форматтеры
  Info.plist                   — описания использования прав
  DiskCleaner.entitlements     — песочница выключена
  Assets.xcassets              — иконка (генерируется Tools/generate_icon.swift)
DiskCleanerTests/              — unit-тесты
DiskCleanerUITests/            — UI-тесты
Tools/generate_icon.swift      — генератор иконки (SF Symbol → PNG)
```

---

© 2026 **Евгений Ацтек**. Приложение распространяется как есть, без гарантий.
Используйте на свой страх и риск — всегда проверяйте, что именно вы удаляете.