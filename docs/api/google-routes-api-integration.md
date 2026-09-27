# Google Routes API Integration

## Overview

`endpoint-service` calls Google's [Routes API](https://developers.google.com/maps/documentation/routes)
(`computeRoutes`) to get real, road-based driving distance and duration between two
subdistricts (ตำบล), instead of the straight-line (Haversine)
estimates the rest of the `SubdistrictDistance` group uses. It backs a single endpoint,
`GET /endpoint-master-service/api/subdistrict-distances/google-distance`, exposed under
its own `GoogleRoutes` Swagger tag because — unlike its sibling endpoints — it makes a
real outbound network call that costs money and requires an API key.

## Architecture & Data Flow

```
Client
  -> GoogleRouteDistanceController (com.master.controller)
       -> GoogleRoutesService (com.master.service)
            -> SubdistrictRepository (lookup lat/lng for origin & destination)
            -> Google Routes API  POST https://routes.googleapis.com/directions/v2:computeRoutes
       <- GoogleRouteDistanceResponse
  <- ApiResponse<GoogleRouteDistanceResponse>
```

- **Upstream caller**: any client of `endpoint-master-service` (e.g. `endpoint-webapp`
  job-planning screens) that needs actual road distance/time between two ตำบล.
- **Internal dependency**: `SubdistrictRepository.findByCode` — origin/destination are
  resolved from our own `subdistrict` table (must already have `lat`/`lng` populated by
  the `sync-subdistricts` job) before calling Google.
- **External dependency**: Google Routes API (`routes.googleapis.com`), called directly
  via a Spring `RestClient` — no Google client SDK is used.

## Configuration

Defined in [application.yml](../../endpoint-service/src/main/resources/application.yml):

```yaml
google:
  maps:
    api-key: ${GOOGLE_MAPS_API_KEY:}
    routes-base-url: https://routes.googleapis.com
```

| Property | Env var | Required | Notes |
|---|---|---|---|
| `google.maps.api-key` | `GOOGLE_MAPS_API_KEY` | Yes | Google Cloud API key with **Routes API** enabled. If blank, every call fails with `ExternalApiException` before any HTTP request is made. |
| `google.maps.routes-base-url` | — | No | Defaults to `https://routes.googleapis.com`; overridable for testing (e.g. pointing at a mock server). |

A literal key was committed to `application.yml` in earlier revisions; it has been replaced by the
placeholder above, but it is still in git history — that key must be rotated in Google Cloud.
Local dev now needs `export GOOGLE_MAPS_API_KEY=...` for uncached Google calls; on the VPS it goes in
`/etc/endpoint/endpoint.env` (see [deploy/README.md](../../deploy/README.md)).

## API Endpoint / Contract

| Method | Path | Auth |
|---|---|---|
| `GET` | `/endpoint-master-service/api/subdistrict-distances/google-distance` | Same as other `master` endpoints — gated by the `security.filter` config (`endpoint-service/src/main/resources/application.yml`); disabled (`security.filter.enabled: false`) in the default local profile. |

### Query parameters

| Param | Type | Required | Description |
|---|---|---|---|
| `originCode` | string | Yes | Subdistrict code of the origin (looked up via `SubdistrictRepository.findByCode`). |
| `destinationCode` | string | Yes | Subdistrict code of the destination. |

### Success response — `200 OK`

Body is the standard `ApiResponse<T>` envelope with `data` set to `GoogleRouteDistanceResponse`:

```json
{
  "success": true,
  "status": 200,
  "message": "Success",
  "data": {
    "origin": {
      "provinceId": 1,
      "districtId": 1,
      "districtName": "เมืองสกลนคร",
      "subdistrictId": 12,
      "subdistrictName": "ธาตุเชิงชุม",
      "provinceName": "สกลนคร"
    },
    "destination": { "...": "same shape as origin" },
    "distanceMeters": 112340,
    "distanceKm": 112.34,
    "durationSeconds": 6300
  },
  "timestamp": "2024-01-15T10:30:00"
}
```

| Field | Type | Description |
|---|---|---|
| `data.origin` / `data.destination` | `LocationPointDto` | Resolved location (province/district/subdistrict id+name) for the code passed in. |
| `data.distanceMeters` | integer | Road distance in meters, as returned by Google. |
| `data.distanceKm` | decimal (2dp) | `distanceMeters / 1000`, rounded half-up. |
| `data.durationSeconds` | long | Estimated driving duration in seconds. **Traffic-unaware** — see [Business Logic](#business-logic). |

### Error responses

| Status | Condition | Trigger |
|---|---|---|
| `400 Bad Request` | `originCode`/`destinationCode` blank, or the resolved subdistrict has no `lat`/`lng` yet | `IllegalArgumentException` |
| `404 Not Found` | `originCode` or `destinationCode` doesn't match any subdistrict | `ResourceNotFoundException` |
| `429 Too Many Requests` | The pair is not stored yet and today's Google request budget (`google.maps.daily-request-limit`) is already used up — Google was **not** called | `GoogleRoutesQuotaExceededException` |
| `502 Bad Gateway` | API key not configured, network failure reaching Google, non-2xx response from Google, or Google returns zero routes | `ExternalApiException` |

All error responses use the standard error envelope (`ApiResponse.error(message)`),
mapped by `com.master.exception.GlobalExceptionHandler`.

### Underlying Google call

```
POST https://routes.googleapis.com/directions/v2:computeRoutes
Content-Type: application/json
X-Goog-Api-Key: <GOOGLE_MAPS_API_KEY>
X-Goog-FieldMask: routes.distanceMeters,routes.duration

{
  "origin": { "location": { "latLng": { "latitude": <origin.lat>, "longitude": <origin.lng> } } },
  "destination": { "location": { "latLng": { "latitude": <dest.lat>, "longitude": <dest.lng> } } },
  "travelMode": "DRIVE",
  "routingPreference": "TRAFFIC_UNAWARE"
}
```

Only `routes.distanceMeters` and `routes.duration` are requested via the field mask —
this is a hard Google requirement (all Routes API calls must set `X-Goog-FieldMask`) and
also keeps the response minimal. Only the first entry in `routes[]` is used.

## Business Logic

- **Why `TRAFFIC_UNAWARE`**: Google prices Routes API in two tiers — requesting
  traffic-aware duration/`routingPreference: TRAFFIC_AWARE*` bumps a request into the
  more expensive **Pro** tier. This integration deliberately stays on
  `TRAFFIC_UNAWARE` to stay in the cheaper **Essentials** tier, at the cost of the
  returned `durationSeconds` not reflecting current traffic.
- **Lat/lng precondition**: origin and destination subdistricts must already have
  `lat`/`lng` populated (via the `sync-subdistricts` job) — this endpoint does not
  geocode addresses itself, it only computes a route between two known points.
- **Stored and reused (`google_fetched` flag)**: every successful Google call is written to
  `subdistrict_distances` in **both directions** (`distance_km`, `duration_seconds`,
  `calc_method = 'google'`, `google_fetched = true`). Before calling Google, `findRoute` looks
  the pair up; if the row has `google_fetched = true` it is returned straight from the DB
  (`fromCache: true` in the response) — no Google call, no billing, and no API key needed.
  - An existing `haversine` row for the pair (`google_fetched = false`) does **not** count as
    fetched: Google is called once and the row is **overwritten** with the road distance.
  - A row with `google_fetched = true` is never overwritten. The batch script's
    `compute-subdistrict-distances` upsert skips such rows too.
  - Cached responses derive `distanceMeters` from `distance_km` (10 m precision), and
    `durationSeconds` is `null` for rows cached before the `duration_seconds` column existed.
  - If storing fails (DB error, concurrent insert) the Google result is still returned; the
    pair is simply fetched again next time.
  - `JobService.getCandidateOrders` goes through the same `findRoute`, so both callers share
    one store.
- **Daily limit on real Google calls (default 100, adjustable at runtime in the DB)**:
  right before an actual request to Google, `GoogleRoutesUsageService.tryAcquire()` reserves one
  unit of today's budget with an atomic upsert on `google_routes_usage`
  (`call_count < limit`). If the budget is full the call is refused with `429` and Google is
  never contacted; the refusal is counted in `rejected_count`.
  - Only real Google requests count. Pairs served from `subdistrict_distances`
    (`google_fetched = true`) and requests that fail validation (blank code, unknown
    subdistrict, missing `lat/lng`, missing API key) do not use any budget.
  - The unit is reserved when the request is about to be sent, whether or not Google then
    answers successfully (Google may bill either way), and is not given back.
  - A "day" is the Asia/Bangkok calendar day (`ClockConfig`), so the budget resets at Thai
    midnight. Limit `0` blocks every real call.
  - **The limit lives in the `configuration` table**, row `code = 'GR_DAILY'`
    (`group_code = 'google_routes'`), `value_1` = max calls per day. It is read fresh on every
    call, so changing it takes effect immediately — no restart, no cache:
    `UPDATE configuration SET value_1 = '300', updated_at = now() WHERE code = 'GR_DAILY';`
    The row is created by `db/configuration-data.sql`. If the row is missing, has
    `status <> 'A'`, or `value_1` is not an integer `>= 0`, the default
    `google.maps.daily-request-limit` from `application.yml` (100) is used instead (an invalid
    value also logs a WARN). The existing `/configuration` API is read-only, so edit the row
    with SQL.
  - The limit is enforced in the database, so it holds across concurrent requests and multiple
    app instances. It is shared by `/google-distance` and `JobService.getCandidateOrders`
    (a leg that hits the limit there keeps its straight-line estimate).
- **Usage log**: `google_routes_usage` has one row per day (`usage_date`, `call_count`,
  `rejected_count`); each reserved call also writes an INFO log line. Read it with
  `GET /endpoint-master-service/api/subdistrict-distances/google-distance/usage?days=30`
  (returns `dailyLimit`, `todayCallCount`, `todayRemaining` and per-day `history`; `days`
  defaults to 30, clamped to 1–366). Schema: `db/schema-db.sql`.
- **Single-route assumption**: `computeRoutes` can return multiple route alternatives;
  this integration always takes `routes[0]` and does not request alternatives.
- **Cross-province supported**: origin and destination can be in different provinces.
