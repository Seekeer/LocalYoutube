# Архитектура Flutter-приложения LocalTube (проектная схема)

## 1. Цели архитектуры
- Повторить функциональность текущего MAUI-клиента: авторизация, каталоги, плеер, закладки, офлайн, синхронизация клиентов.
- Обеспечить устойчивую работу при нестабильной сети (offline-first подход).
- Сохранить расширяемость (новые источники данных, новые платформы, новые типы каталогов).
- Поддерживать высокую тестируемость (unit/widget/integration).
- Ключевая платформа: Android (приоритизация UX, производительности и фоновых сценариев именно для Android).
- Воспроизведение аудио должно продолжаться при заблокированном экране телефона (background audio).

## 2. Технологический стек (рекомендуемый)
- `Flutter` + `Dart` (stable channel).
- Архитектурный стиль: `Clean Architecture` + `Feature-first` модульность.
- State management: `Riverpod` (code generation через `riverpod_generator`).
- Навигация: `go_router` (declarative routing, deep links).
- HTTP: `Dio` + интерсепторы авторизации/обновления токенов.
- Локальная БД: `Drift` (SQLite) для офлайн-данных, позиции, очередей синхронизации.
- Secure storage: `flutter_secure_storage` для токенов и чувствительных данных.
- Видео: `media_kit` (или `video_player`, если достаточно по платформам/форматам).
- Фоновые загрузки: платформенные адаптеры через единый `DownloadService` интерфейс.
- Real-time: `signalr_netcore` для `/player` хаба.
- Логи и аналитика: `logger` + опционально `Sentry`/Crashlytics.
- DI: Riverpod providers (без отдельного DI-контейнера).

## 3. Высокоуровневая схема
```text
Presentation (UI + ViewModels/Controllers)
        |
        v
Domain (UseCases + Entities + Repository contracts)
        |
        v
Data (Repository impl + Remote DS + Local DS + Mappers)
        |
        +--> Remote: REST API + SignalR
        |
        +--> Local: SQLite(Drift) + SecureStorage + FileStorage
```

Принцип: UI работает только с use case/provider API, не знает о Dio/SQLite напрямую.

## 4. Структура проекта (feature-first)
```text
lib/
  app/
    app.dart
    router/
      app_router.dart
    bootstrap/
      app_bootstrap.dart
  core/
    network/
      dio_client.dart
      auth_interceptor.dart
      retry_policy.dart
    storage/
      secure_storage_service.dart
      file_storage_service.dart
    db/
      app_database.dart
      tables/
      daos/
    logging/
      log_service.dart
    errors/
      app_exception.dart
      failure.dart
    utils/
      connectivity_service.dart
      time_provider.dart
  features/
    auth/
      domain/
      data/
      presentation/
    catalog/
      domain/
      data/
      presentation/
    player/
      domain/
      data/
      presentation/
    bookmarks/
      domain/
      data/
      presentation/
    downloads/
      domain/
      data/
      presentation/
    playlists/
      domain/
      data/
      presentation/
    sync/
      domain/
      data/
      presentation/
    logs/
      presentation/
  shared/
    widgets/
    theme/
    l10n/
```

## 5. Доменные модули и ответственность
- `auth`: login, refresh-token, logout, auto-login, хранение сессии.
- `catalog`: новинки, последнее, история, сериалы/сезоны, плейлисты.
- `player`: запуск видео (онлайн/офлайн), резюмирование, таймкоды, next-timestamp.
- `bookmarks`: CRUD закладок, автозакладки при паузе/возобновлении, очередь повторной отправки.
- `downloads`: очередь скачиваний, статус/прогресс, остановка, проверка локального наличия.
- `sync`: SignalR подключение, список клиентов, отправка/получение `PlayOnClient`.
- `logs`: просмотр локальных логов и диагностик.

## 6. Data flow (на примере плеера)
1. UI вызывает `PlayVideoUseCase(videoId)`.
2. Use case запрашивает в репозитории:
   - локальный путь файла,
   - последнюю локальную позицию,
   - серверную позицию (если сеть доступна).
3. Репозиторий объединяет данные по приоритету (offline-first с merge-стратегией).
4. UI получает `PlayableSource` (`localFile` или `remoteUrl`) и `startPosition`.
5. Во время воспроизведения `SyncPlaybackPositionUseCase` периодически пишет позицию:
   - в локальную БД сразу,
   - в API с ретраем,
   - при ошибке — в outbox-очередь на последующую отправку.

## 7. Offline-first стратегия
- Источник правды для сессии и состояния UI: локальная БД + кэш.
- При наличии сети выполняется фоновая синхронизация.
- Для конфликтов позиций просмотра: брать максимальную timestamp-позицию с более свежим `updatedAt`.
- Для неотправленных операций (закладки/позиции): таблица `sync_outbox` с retry/backoff.
- Каталоги кэшируются с TTL, чтобы открываться без сети.

## 8. Сетевой слой и авторизация
- `Dio` интерсептор добавляет `Bearer accessToken`.
- При `401` запускается атомарный refresh (single-flight, чтобы не дублировать запросы).
- Если refresh неуспешен: очистка сессии, перевод роутера на экран логина.
- Все API-ответы маппятся в typed-модели DTO -> domain entities.
- Ошибки нормализуются в `Failure` (NetworkFailure, AuthFailure, ValidationFailure, UnknownFailure).

## 9. Плеер и таймкоды
- `PlayerController` держит только UI-состояние и команды (play/pause/seek).
- Для Android обязательно использовать фоновую аудио-сессию (`audio_service`/`just_audio_background` или эквивалент), чтобы звук продолжал играть при блокировке экрана.
- Use case `ExtractTimestampsUseCase` парсит описание и строит список таймкодов.
- `JumpToNearestTimestampUseCase` выбирает следующий таймкод относительно текущей позиции.
- Позиция сохраняется по таймеру (например, каждые 5-10 секунд) и на lifecycle-событиях (`paused`, `detached`).

## 10. Загрузки и файловая система
- Единый интерфейс `DownloadService` в domain.
- Реализации по платформам в data:
  - Android: background downloader / WorkManager backend.
  - Windows: нативная реализация через HTTP + file stream + resume.
- Метаданные загрузок: таблица `downloads` (status, progress, localPath, checksum).
- Перед открытием видео всегда проверять фактическое существование файла, а не только запись в БД.

## 11. SignalR синхронизация клиентов
- `SyncHubService` управляет connect/reconnect и подписками.
- События хаба транслируются в stream/provider.
- Команда `PlayOnClient(videoId, position)` валидируется и маршрутизируется в `PlayVideoUseCase`.
- При потере соединения включается auto-reconnect с экспоненциальной задержкой.

## 12. Навигация
- Корневой graph:
  - `/login`
  - `/home` (shell route с табами/секциями)
  - `/player/:videoId`
  - `/downloads`
  - `/logs`
- Guard на основе auth-state provider.
- Deep-link на конкретное видео: `/player/:videoId?position=123`.

## 13. Безопасность
- Токены и секреты только в `flutter_secure_storage`.
- Не логировать токены, пароли, полные URL с чувствительными query.
- TLS pinning (опционально, если инфраструктура позволяет).
- Очистка локальных чувствительных данных при logout.

## 14. Наблюдаемость и диагностика
- Структурированные логи с correlationId запроса.
- Отдельные уровни логирования для debug/release.
- Экран логов читает локальный ring-buffer/файл логов.
- Критические ошибки отправляются в crash-reporting сервис.

## 15. Тестовая стратегия
- Unit:
  - use cases,
  - мапперы,
  - retry/outbox логика,
  - auth refresh flow.
- Widget:
  - экраны логина, каталога, плеера, загрузок.
- Integration:
  - happy path: login -> catalog -> play -> resume -> download -> offline play.
  - сценарии с обрывом сети и восстановлением.
- Contract tests для API-клиента по OpenAPI/фиксированным JSON fixtures.

## 16. Конфигурации окружений
- flavors: `dev`, `stage`, `prod`.
- Конфиги: baseUrl API, SignalR URL, log level, feature flags.
- Секреты не хранятся в git, подставляются через CI/CD variables.

## 17. Этапы реализации
1. Базовый каркас: router, core, auth flow, DI providers.
2. Каталоги + просмотр карточек + кэш списков.
3. Плеер + восстановление позиции + таймкоды.
4. Загрузки + офлайн-проигрывание.
5. Закладки + outbox sync.
6. SignalR межклиентская синхронизация.
7. Полировка UX, логи, метрики, тесты, hardening.

## 18. Минимальный Definition of Done
- Все ключевые сценарии из спецификации проходят без критических дефектов.
- Приложение работает offline для скачанных видео и локальных закладок.
- Покрытие unit-тестами критичных use cases не ниже 70%.
- Реализованы централизованные обработка ошибок, логирование и авто-refresh токена.
- Есть CI-пайплайн с `flutter analyze`, `flutter test`, сборкой Android/Windows.
