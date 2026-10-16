# Disk Cleaner

Нативное macOS-приложение (Swift + SwiftUI + AppKit) для безопасной очистки диска.
Сканирует файловую систему **только на чтение**, классифицирует находки по трём корзинам
(мусор / данные пользователя / истории-конфиги) и **ничего не удаляет без явного
подтверждения пользователем** через UI.

## Безопасность

- Ничего не удаляется без нажатия кнопки «Подтвердить удаление».
- Каждый путь перед удалением повторно проверяется `SafetyGuard` (запрещённые паттерны:
  keychains, `~/.ssh`, `~/.gnupg`, `~/.config`, `~/Library/Preferences`, `*.key`, `*.pem`,
  `*.p12`, `license`, `token`, `secret`, `credentials`, swap-файлы, снапшоты Time Machine,
  истории AI-ассистентов и т.д.).
- `~/Library/CloudStorage/*` никогда не удаляется через `FileManager.removeItem` —
  только `brctl evict` (выгрузка локальной копии).
- Стораджи пакетных менеджеров (`npm`, `pnpm`, `yarn`, `cargo`) чистятся только родными
  командами (`npm cache clean --force`, `pnpm store prune`, ...).
- Перед каждым удалением в лог пишется «снимок действия»: путь, размер, дата, SHA-256,
  кто и когда одобрил.
- Приложение полностью офлайн, без сторонних зависимостей, без App Sandbox
  (нужен доступ ко всей файловой системе), работает без root.
- `Operation not permitted` (SIP/TCC) — это норма, не баг: операция помечается
  «требует прав» и пропускается.

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
  Info.plist                   — NSAppleEventsUsageDescription, NSSystemAdministrationUsageDescription и др.
  DiskCleaner.entitlements     — песочница ВЫКЛЮЧЕНА
  Assets.xcassets              — иконка (генерируется Tools/generate_icon.swift)
DiskCleanerTests/              — unit-тесты (SafetyGuard, Analyzer, Cleaner)
DiskCleanerUITests/            — UI-тесты (полный сценарий + «ничего без подтверждения»)
Tools/generate_icon.swift      — генератор иконки (SF Symbol → PNG)
```

## Требования

- macOS 26+ (Apple Silicon, arm64)
- Xcode 26 (или Xcode 15+ с SDK macOS 26)
- Swift 5.9+

## Сборка и запуск

### Из Xcode

1. Откройте `DiskCleaner.xcodeproj`.
2. Выберите схему `DiskCleaner` и destination «My Mac».
3. `Cmd+R` — запуск.

### Из командной строки

```bash
xcodebuild -project DiskCleaner.xcodeproj -scheme DiskCleaner -configuration Release -derivedDataPath build build
```

Готовый бандл: `build/Build/Products/Release/DiskCleaner.app`.

### Подпись

- Локальная сборка: **ad-hoc** (`CODE_SIGN_IDENTITY = "-"`, уже настроено в проекте) —
  macOS запустит приложение без блокировки.
- Для распространения: подпишите Developer ID Application и отправьте на нотаризацию
  (`xcrun notarytool submit`).

## Тесты

```bash
# Unit-тесты
xcodebuild test -project DiskCleaner.xcodeproj -scheme DiskCleaner -destination 'platform=macOS' -only-testing:DiskCleanerTests

# UI-тесты (используют UITEST_FAST_SCAN для скорости)
xcodebuild test -project DiskCleaner.xcodeproj -scheme DiskCleaner -destination 'platform=macOS' -only-testing:DiskCleanerUITests
```

## Первый запуск

1. При первом запуске приложение предложит открыть
   «Системные настройки → Конфиденциальность и безопасность → Полный доступ к диску».
2. Добавьте Disk Cleaner в список и перезапустите приложение.
   Без Full Disk Access приложение работает, но часть путей будет помечена
   «требует прав» (это не баг).

## Горячие клавиши

- `Cmd+R` — пересканировать
- `Cmd+E` — экспорт отчёта в Markdown
- `Cmd+Delete` — очистить выбранное (с подтверждением)

## Логи

- Действия: `~/Library/Application Support/DiskCleaner/logs/YYYY-MM-DD_HH-mm-ss.log`
- Ошибки: `~/Library/Application Support/DiskCleaner/errors.log`