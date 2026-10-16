# STEP 01: Preproject Contract (API + SignalR + Rules + DoR)

## 1. Scope and Source of Truth
- Scope: freeze Flutter migration contract for `account/*`, `files/*`, `series/*`, `playlists/*`, `marks/*`, plus SignalR `/player`.
- Source code references:
  - `src/BookStore.API/Controllers/AccountController.cs`
  - `src/BookStore.API/Controllers/AudioFilesController.cs`
  - `src/BookStore.API/Controllers/FilesController.cs`
  - `src/BookStore.API/Controllers/SeriesController.cs`
  - `src/BookStore.API/Controllers/PlaylistsController.cs`
  - `src/BookStore.API/Controllers/MarksController.cs`
  - `src/BookStore.API/SignalR/PlayHub.cs`
  - `src/BookStore.Domain/Dtos/*.cs`
  - `src/BookStore.Domain/Services/FileServiceBase.cs`

## 2. Transport Basics
- Base server URL: `https://api.example.invalid:9999`
- REST prefix: `/api/`
- SignalR hub: `/player`
- Auth header: `Authorization: Bearer <accessToken>`
- REST serialization: ASP.NET Core default JSON (camelCase), with explicit overrides in `LoginDTO.cs`.

## 3. API Contract

### 3.1 `account/*`

1. `POST /api/account/login`
- Request (`LoginRequest`):
```json
{
  "username": "string",
  "password": "string"
}
```
- Response `200` (`LoginResult`):
```json
{
  "username": "string",
  "role": "string",
  "originalUserName": "string",
  "accessToken": "string",
  "refreshToken": "string"
}
```
- Errors: `400` bad credentials, `401` unauthorized.

2. `POST /api/account/refresh-token` (authorized)
- Request (`RefreshTokenRequest`):
```json
{
  "refreshToken": "string",
  "userName": "string"
}
```
- Response `200`: `LoginResult` with rotated tokens.
- Errors: `401` on invalid/expired refresh.

3. `POST /api/account/logout` (authorized)
- Response `200`.

4. `GET /api/account/user` (authorized)
- Response `200`: `LoginResult` subset (`username`, `role`, `originalUserName`).

### 3.2 `files/*`

Primary endpoints for Flutter:

1. `GET /api/files/getImage?fileId={id}&isMobile=true|false`
- Response: binary image stream.

2. `GET /api/files/getFileById?fileId={id}`
- Response: binary media stream with range support.

3. `GET /api/files/getLatest?count={n}`
- Response `200`: `VideoFileResultDto[]`.

4. `GET /api/files/getNew?count={n}`
- Response `200`: `VideoFileResultDto[]`.

5. `GET /api/files/getFilesBySeason?id={seasonId}&count={n}&isRandom={bool}&startId={id}&reverseOrder={bool}`
- Response `200`: `VideoFileResultDto[]`.

6. `PUT /api/files/setPositionMaui/{id}`
- Request (`PositionDTO`):
```json
{
  "position": 123.45,
  "updatedDate": "2026-02-11T10:15:30Z"
}
```
- Response `200`: `bool`
  - `true` position accepted.
  - `false` stale update rejected (incoming `updatedDate` is older than server state).

7. `GET /api/files/getPositionMaui/{fileId}`
- Response `200` (`PositionDTO`):
```json
{
  "position": 123.45,
  "updatedDate": "2026-02-11T10:15:30Z"
}
```

8. `DELETE /api/files/{id}`
- Response `200`.

### 3.3 `series/*`

1. `GET /api/series/getAllByOrigin?origin={optional}`
- Response: `SeriesResultDto[]`.

2. `GET /api/series/getFreshSeasons?number={n}`
- Response: `SeriesResultDto[]` (first element contains `seasons` list).

Additional server endpoints exist (move/search/delete/etc.) and remain valid for admin/service flows.

### 3.4 `playlists/*`

1. `GET /api/playlists/getAll`
- Response:
```json
[
  { "id": 1, "name": "Favorites" }
]
```

2. `GET /api/playlists/getFiles?id={playlistId}&count={n}`
- Response: `VideoFileResultDto[]`.

3. `POST /api/playlists/add`
- Request:
```json
{
  "name": "string"
}
```
- Response `200`: new playlist id.

4. `POST /api/playlists/addToPlaylist`
- Request (`AddToPlaylistDTO`):
```json
{
  "fileId": 123,
  "playlistId": 10
}
```
- Response `200`.

### 3.5 `marks/*`

1. `GET /api/marks/getAllMarks?fileId={id}`
- Response: `FileMark[]`.

2. `POST /api/marks/add`
- Request (`MarkAddDto`):
```json
{
  "id": 0,
  "dbFileId": 123,
  "position": 45.6,
  "caption": "string"
}
```
- Response `200`: created mark id.

3. `POST /api/marks/update`
- Request: `MarkAddDto`.
- Response `200`.

4. `DELETE /api/marks/{id}`
- Response `200`.

## 4. Core DTO Baseline for Flutter

### 4.1 `VideoFileResultDto`
```json
{
  "id": 123,
  "name": "string",
  "seriesId": 1,
  "seasonId": 2,
  "seriesName": "string",
  "author": "string",
  "description": "string",
  "director": "string",
  "year": 2024,
  "duration": "01:23:45",
  "previousFilesDurationSeconds": 0.0,
  "genres": "string",
  "value": 0.0,
  "currentPosition": 120.0,
  "publishDate": "2026-02-11T10:00:00Z",
  "isFinished": false,
  "isSupportedWebPlayer": true,
  "number": 1,
  "displayName": "string",
  "coverURL": "string"
}
```

### 4.2 `SeriesResultDto`
```json
{
  "id": 1,
  "name": "Series",
  "isOrderMatter": false,
  "type": 0,
  "seasons": [
    { "id": 10, "name": "Season 1", "isOrderMatter": false }
  ]
}
```

## 5. SignalR Contract (`/player`)

### 5.1 Client -> Server
- Method: `Play(connectionId: string, videoId: int, position: TimeSpan)`
- Invocation example (semantic):
```text
Play("conn-target-id", 12345, "00:12:30.0000000")
```

### 5.2 Server -> Client events
1. `Connected(connectionId: string, userLabel: string)`
- Fired when a client becomes visible to current user.

2. `Disconnected(connectionId: string, userLabel: string)`
- Fired when a client disconnects.

3. `PlayOnClient(videoId: int, position: TimeSpan)`
- Command to start playback on target client.

### 5.3 TimeSpan format
- Contract baseline: `.NET TimeSpan "c"` string, example: `00:12:30.0000000`.
- Flutter adapter must convert this value to/from `Duration`.

## 6. Mandatory Business Rules

1. Resume position rule:
- Save progress locally immediately.
- Sync remotely via `setPositionMaui`.
- On open, merge local + remote using freshest `updatedDate`.

2. Source priority rule (`local/remote`):
- If downloaded local file exists on disk, play local file.
- Otherwise play remote stream URL (`files/getFileById`).

3. Conflict rule by `updatedAt` (`updatedDate`):
- Server rejects stale updates (`false` from `setPositionMaui`).
- Winner is the newest `updatedDate`.
- If timestamps are equal, keep larger position as tie-breaker (Flutter-side deterministic merge).

## 7. Definition of Ready (DoR) by Feature

| Feature | Inputs | Outputs | API/Integrations | Edge Cases |
|---|---|---|---|---|
| Auth | login/password, stored refresh token | auth state, access token | `account/login`, `account/refresh-token`, secure storage | wrong credentials, expired refresh, missing token |
| Catalog | section type, count, optional filters | list of `VideoFileResultDto` | `files/getNew`, `files/getLatest`, `series/getAllByOrigin`, `series/getFreshSeasons` | empty list, partial network, duplicates |
| Player | `videoId`, local path, saved positions | playable source + start position | `files/getFileById`, `files/getPositionMaui`, `files/setPositionMaui` | stale remote position, missing local file, seek out of range |
| Playlists | playlist id/name, file id | updated playlist state | `playlists/getAll`, `playlists/add`, `playlists/addToPlaylist`, `playlists/getFiles` | duplicate names, unknown playlist/file |
| Bookmarks | file id, position, caption | bookmarks list/status | `marks/getAllMarks`, `marks/add`, `marks/update`, `marks/{id}` | offline add/update, duplicate marks |
| Downloads | file metadata, destination path | queued/downloading/completed status | local FS, future download adapter | no disk space, interrupted download |
| Sync | selected target client, current playback state | remote play command/status | SignalR `/player` (`Play`, `PlayOnClient`) | reconnect, unknown client id, malformed position |
| Logs | log level, app events | readable logs in UI/file | logger service + local storage | PII/token masking, file growth limits |

## 8. Step Artifact

### 8.1 Tests (contract-level checklist)
- `account/login` returns tokens on valid credentials.
- `account/refresh-token` rotates token pair.
- `files/setPositionMaui` returns `false` for stale `updatedDate`.
- `player` hub delivers `PlayOnClient(videoId, position)` to target connection.

### 8.2 Short changelog
- Fixed API and SignalR contract baseline from actual backend controllers and DTOs.
- Locked mandatory sync/playback business rules for Flutter implementation.
- Added DoR table for all core Flutter features.

### 8.3 Demo scenario
1. Login via `account/login`.
2. Open latest list (`files/getLatest`), pick video, start playback.
3. Save position via `files/setPositionMaui`.
4. Send playback to another client via SignalR `Play`.
5. Add bookmark and playlist entry (`marks/add`, `playlists/addToPlaylist`).
