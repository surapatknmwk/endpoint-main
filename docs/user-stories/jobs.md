# Epic: Job & Delivery Route Management (งาน / การจัดส่ง)

Source of truth generated from current code, not aspirational design. Known
inconsistencies in the code are called out under **Known gaps** on each story rather
than smoothed over.

**Key term (see root `CLAUDE.md`):** a `job` (งาน) is a single delivery run from an
origin to one or more destinations, covering one or more `order`s picked up along the
route. See [orders.md](orders.md) for the Order epic.

## Actor
Same single operator and the same authentication model as the Order epic — see
[orders.md → Actor](orders.md#actor-authentication-and-permissions). In short: with the
default profile nothing is enforced; in the `prod` profile every job endpoint needs a valid
token **and** a `permissions` → `providers` row for the token's role matching the method and
mapping pattern, otherwise the call returns `401` and the webapp logs the operator out.

### Job permissions
`db/permissions-jobs-data.sql` grants all eight job endpoints (list, create, edit, delete,
candidate-orders, route-preview, complete stop, skip stop — all under
`/endpoint-core-service/api/jobs`) to **every** role. It is safe to re-run (existing provider
and permission rows are reused) and must be run on any database the `prod` profile uses;
without a row the call returns `401` and the webapp logs the operator out.

## Job status reference

Two independent, unconstrained status fields exist — **neither has a DB `CHECK`
constraint**, unlike `orders.order_status`:

**`delivery_jobs.delivery_status`** (job-level, default `"NEW"`, uppercase — all rows
backfilled from the old lowercase `"new"` default):
- Set to uppercase `"COMPLETED"` by `JobService.completeStop` / `skipStop` when every stop
  on the job is `COMPLETED` or `SKIPPED` (US-JOB-07). No other code path changes it — a job stays `"NEW"` for its entire active
  lifetime otherwise. The frontend job list splits jobs into two tabs by this value
  ("กำลังส่ง" = anything but `COMPLETED`, "ส่งครบแล้ว" = `COMPLETED`); there is no
  job-level status badge.

**`delivery_routing.routing_status`** (per-stop, default `"NEW"`, uppercase — all rows
backfilled from the old lowercase `"new"` default). Labeled by
`components/ui/StatusBadge.jsx` (`kind="stop"`) — deliberately distinct from the order
labels (`kind="order"`):

| Value | Thai label | Badge tone (`theme.css`) | Meaning |
| --- | --- | --- | --- |
| `NEW` / `PENDING` | รอจัดส่ง | `--ep-neutral` | Stop not yet started |
| `IN_TRANSIT` | กำลังจัดส่ง | `--ep-transit` | Job carrying this stop is underway |
| `COMPLETED` | ส่งแล้ว | `--ep-success` | Delivered |
| `SKIPPED` | ข้าม | `--ep-warning` | Driver skipped this stop (US-JOB-06a); still completable while the job is open |
| `CANCELLED` | ยกเลิก | `--ep-danger` | Stop cancelled |

### Schema note: `IN_TRANSIT` and the `orders.order_status` CHECK constraint
`JobService.createJob`/`updateJob` sets an order's `orderStatus` to `"IN_TRANSIT"` when
it's added to a job. `db/schema-db.sql` allows it; on a database created from an older copy
(which omitted `IN_TRANSIT`) creating or extending a job fails with `500`. See
[orders.md](orders.md#schema-note-the-ordersorder_status-check-constraint).

---

## US-JOB-01 — View active jobs

**As an** operator, **I want to** see a list of all active delivery jobs with their
stops, **so that** I know what's in progress and can act on any of them.

**Entry point:** `ManageDeliveryPage` (route `/manageDeliveryPage`, design
`docs/design/Jobs.dc.html`), loaded on mount. Tapping a job card opens `JobDetailPage`
(route `/manageDeliveryPage/job`, design `docs/design/JobDetail.dc.html`); the job is
handed over via `JobEditContext.viewingJob` (no URL param). Opening/refreshing the
detail route directly with no job in context redirects back to the list.

**API:** `GET /endpoint-core-service/api/jobs` · the controller does not read the
`Authorization` header (the `prod` security filter still requires it) · returns
`List<JobResponse>`.

### Acceptance criteria
- Only jobs with `status = 'A'` (soft-delete flag, not `delivery_status`) are returned,
  newest-created first.
- Tabs: "กำลังส่ง N" (`deliveryStatus !== "COMPLETED"`) and "ส่งครบแล้ว"
  (`deliveryStatus === "COMPLETED"`), filtered client-side.
- Each job card shows: title (`jobName`, else `jobCode`), meta line (`jobCode` when a name
  exists · "นัดส่ง <d MMM>" from `scheduledDate`), origin subdistrict → **last** stop's
  subdistrict, "ส่งแล้ว X จาก N จุด", a segmented progress bar (one segment per stop), and
  a status text: "ส่งครบแล้ว" (job completed) · "ยังไม่เริ่ม" (0 delivered) ·
  "เหลือ 1 จุด" (one open stop left) · otherwise "ถัดไป: <next stop's customer>".
  Stops are ordered by `sequenceNo`; "open" = not `COMPLETED`, `SKIPPED`, or `CANCELLED`.
- UI states: loading → spinner "กำลังโหลดงาน…", error → error `InlineAlert` with
  "ลองอีกครั้ง" (re-fetch), empty tab → `EmptyState`.
- **Detail page** shows a progress summary ("X จาก N จุด ส่งแล้ว" + "ดูเส้นทาง" →
  `RoutePreviewModal` for origin → all stops) and a timeline: origin, delivered stops
  (✓ + `StatusBadge`), the **next open stop** as a highlighted card (address,
  "นำทาง" = Google Maps search of the address, "ยืนยันว่าส่งแล้ว"), then remaining
  stops; the last stop is suffixed "· ปลายทาง". A completed job shows a success notice
  instead of the next-stop card.
- **Known gap (API contract):** the design's next-stop card also has a "โทร" button, the
  order detail line, and a delivered time ("ส่งแล้ว 09:10"), but
  `JobResponse.RoutingItem` carries no `tel`, `detail`, or delivered timestamp. The UI
  renders "โทร"/detail only if those fields are present, so adding them to `RoutingItem`
  in `endpoint-service` lights them up without a frontend change.

---

## US-JOB-02 — Create a delivery job

**As an** operator, **I want to** pick an origin and a set of pending orders, **so
that** I can dispatch them together as one delivery run in a specific stop order.

**Entry point:** `ManageDeliveryPage` → "สร้างงานใหม่" (FAB) → "สร้างงานแบบไหน?" bottom
sheet ("ระบุปลายทาง" = destination-specified, listed first and highlighted; "เลือกทีละจุด" =
sequential; design
`docs/design/PopModePicker.dc.html`) → `AddJobPage` (route
`/manageDeliveryPage/add`, create mode, design `docs/design/AddJob.dc.html`). The picked
mode is only the starting value: create mode shows a "รูปแบบการจัดเส้นทาง" toggle on the page
and the operator can switch at any time (already-picked stops are kept). Edit mode hides the
toggle and always uses the sequential picker, regardless of which mode originally created
the job:
- **เลือกทีละจุด (sequential)** — pick an origin, then add stops one at a time
  from the inline "เพิ่มจุดที่ N" suggestion list (nearest-first from the last-picked stop)
  — see US-JOB-03. Selection order becomes the delivery sequence.
- **ระบุปลายทาง (destination-specified, default)** — listed first in both the picker sheet
  and the on-page toggle, and the starting mode when `AddJobPage` is opened without a pick
  from the sheet. Pick an origin **and** a final
  destination (a raw province/district/subdistrict location picked the same way as the
  origin; it is **not** tied to any order and is **not persisted** anywhere — it only
  exists client-side to help rank candidates for this one create flow), then pick stops
  **one at a time**, exactly like sequential mode: after every pick the suggestions are
  re-measured from the last-picked stop (or from the origin before the first pick) and
  shortlisted by how little they detour on the way from that point to the destination and
  listed nearest-first — see US-JOB-03. Selection order becomes the delivery sequence (no re-sorting).

Either mode produces the same request shape below — the backend has no notion of "mode"
at all; it only ever sees the final `orderIds` array in delivery-sequence order.

**API:** `POST /endpoint-core-service/api/jobs` · requires `Authorization` · body
`JobRequest { jobName?, originSubdistrictCode, scheduledDate?, orderIds[] }` ·
`201` on success.

### Acceptance criteria
- Origin / destination are picked in a "เลือกต้นทาง" / "เลือกปลายทาง" bottom sheet
  (`components/Jobs/LocationSheet.jsx`, design `docs/design/PopLocation.dc.html`):
  province → district → subdistrict selects, plus up to 4 "ใช้ล่าสุด" chips (recently
  picked subdistricts, stored per browser in `localStorage["ep.recentLocations"]`; tapping one
  selects it immediately). The destination sheet opens pre-set to the origin's province.
- Given the operator selects an origin and at least one delivery stop, when they tap
  "บันทึกงาน" (edit mode: "บันทึกการแก้ไข"), then:
  - `orderIds` must be non-empty — the save button is disabled until origin + ≥ 1 stop
    exist (server still guards: `IllegalArgumentException("At least one order must be
    selected")`).
  - **The order in which stops were selected becomes the delivery sequence** —
    `DeliveryRouting.sequenceNo` is assigned 1, 2, 3… in `orderIds` array order.
  - Every selected order must currently have `orderStatus` in `{NEW, PENDING}`
    (case-insensitive) or the whole request fails with `"Order {code} is not pending
    delivery"` — no orders are job-assigned, i.e. this is all-or-nothing, not partial.
  - On success, every order added to the job has its `orderStatus` set to
    `"IN_TRANSIT"` (see Known gap above).
  - `jobCode` is generated as `JOB-yyyyMMdd-<8-char-uppercase-UUID-fragment>`.
- A job cannot contain more than **200 orders**
  (`IllegalArgumentException("A job cannot contain more than 200 orders")`).
- Changing the origin **or the destination** **clears any already-selected stops**
  (explicit UX rule, not a bug — stops were ranked from the old point) and shows an info
  toast "เปลี่ยนต้นทาง/ปลายทางแล้ว — ล้างจุดส่งที่เลือกไว้".
- Bottom bar: "N จุดส่ง · ประมาณ X กม." — X is the sum of each picked stop's `distanceKm`
  from the suggestion list at pick time (= the leg from the previous point), computed
  client-side with no extra API call. It is hidden when any leg is unknown (stops prefilled
  in edit mode, a stop removed from the middle — the next stop's leg is invalidated — or a
  candidate with `distanceKm = null`) or when the total is 0.
- Save → success toast ("สร้างงานแล้ว" / "บันทึกการแก้ไขงานแล้ว"); create returns to the job
  list, edit returns to `JobDetailPage` showing the updated job. Failure → error toast (no
  `alert()`).
- Closing (✕) with unsaved changes opens `ConfirmDialog` "ออกโดยไม่บันทึก?" (design
  `docs/design/PopUnsaved.dc.html`): "กลับไปทำต่อ" (primary) / "ออกโดยไม่บันทึก" (red text).
  Esc / tapping the backdrop means *stay*. Without changes ✕ leaves immediately (create →
  job list, edit → job detail).

### Known gaps
- `JobRequest` has no Bean Validation annotations — the 200-order cap and "must be
  pending" checks are the only server-side guards; nothing stops a malformed direct API
  call from omitting `originSubdistrictCode` beyond the resulting `IllegalArgumentException`.
- `jobCode` uniqueness relies only on the DB `UNIQUE` constraint (same pattern as
  `orderCode` in [orders.md](orders.md)).
- An unknown `orderId`, or the same `orderId` twice, is rejected on create with the same
  message `"Some selected orders were not found"` (the duplicate collapses in
  `findAllById`, so the count no longer matches) — only update has the explicit
  `"Duplicate orders in the selected stop list"` message (US-JOB-04).

---

## US-JOB-03 — Pick candidate orders for a job

**As an** operator, **I want to** see pending orders near my current route (or "on the
way" to a destination I already know), **so that** I can efficiently choose which ones
to add as delivery stops.

**Entry point:** `AddJobPage` — an inline "เพิ่มจุดที่ N" section under the route card (no
modal). Each suggestion card shows name, subdistrict/district, a distance tag and a "+"
button (`aria-label` "เพิ่ม <name>"); the first 5 are shown, then "ดูเพิ่มอีก N รายการ".
"กรองตามอำเภอ / ตำบล" opens a bottom sheet with district/subdistrict filters scoped to the
origin's province (button label becomes "กรอง: อ.… ต.…" while active).
- **Sequential mode:** hint "เรียงจากใกล้<ต้นทาง / จุดที่ N (name)>ที่สุด".
- **Destination-specified mode:** shown only after both origin and destination are picked
  (otherwise an info `InlineAlert` asks for the missing one). The reference point is the
  **last-picked stop** (the origin before the first pick) and the chosen destination stays
  fixed, so every pick triggers a fresh
  `candidate-orders?fromSubdistrictCode=<last stop>&toSubdistrictCode=<destination>` call;
  hint "ใกล้<ต้นทาง / จุดที่ N (name)> และอยู่ระหว่างทางไปปลายทาง". (An earlier version used a
  one-shot multi-select checklist measured from the origin only; it was removed because
  distances could not be re-measured after each pick.)

**API:** `GET /endpoint-core-service/api/jobs/candidate-orders?fromSubdistrictCode=…&
toSubdistrictCode=…&districtCode=…&subdistrictCode=…` · `toSubdistrictCode` optional ·
controller does not read `Authorization` (the `prod` filter still requires it) · returns `List<CandidateOrderResponse>` (fields include both
`distanceKm` and `detourKm`).

### How "on the way" is determined — estimate, then confirm with Google road distance
`JobService.getCandidateOrders` works in two phases so it never asks Google about all (up to
500) candidate subdistricts:
1. **Estimate and shortlist (no Google).** Every leg (origin→candidate, candidate→destination,
   origin→destination) is estimated with the **straight-line** distance: the precomputed
   `subdistrict_distances` row if it is a `haversine` row, otherwise computed on the fly from
   the two subdistricts' `lat`/`lng`; unknown if a coordinate is missing. Rows already
   flagged `googleFetched` are deliberately ignored here (road distance is always longer than
   a straight line — mixing them would drag not-yet-fetched candidates into the shortlist a
   few at a time on every request). Candidates are ranked by this estimate and the best
   **10** are shortlisted.
2. **Confirm with Google road distance (shortlist only).** For each shortlisted candidate's
   subdistrict, `GoogleRoutesService.findRoute` (`computeRoutes`, `DRIVE`,
   `TRAFFIC_UNAWARE`) replaces the estimate with the real road distance — for all legs used
   by `distanceKm`/`detourKm`. A pair already stored (`googleFetched = true`) is read from the
   DB and costs nothing; a new pair calls Google **once**, is stored in both directions
   (`calcMethod = "google"`, `googleFetched = true`, `durationSeconds`; an existing `haversine`
   row is overwritten) and uses one unit of the daily budget
   (`configuration.GR_DAILY.value_1`, default 100/day, Asia/Bangkok day, editable at runtime —
   see the Google Routes integration doc). The 10 shortlisted
   candidates are then re-ranked with the road distances.
3. **Fallback keeps the estimate.** If Google can't be used for a leg (daily budget used up,
   API/network error, no API key, subdistrict without `lat`/`lng`) that leg simply keeps its
   straight-line estimate. After the budget is exhausted once, the rest of that request stops
   calling Google and only reads already-stored pairs. No error is shown to the operator.
- At most about `2 × 10 + 1` Google calls are made per request, and fewer and fewer over time
  because pairs are stored: repeating the same request costs 0 calls.
- The **first** request for a new origin/destination can be slower (Google is called
  synchronously, one pair at a time); later requests read the stored pairs.
- Only the shortlist is confirmed: a candidate whose straight-line estimate ranks 11th or
  worse is never shown, even if its road distance would have ranked higher.
- `getCandidateOrders` is declared `readOnly`, but the writes happen in separate
  `REQUIRES_NEW` transactions inside `GoogleRoutesService` / `SubdistrictDistanceCacheService`
  / `GoogleRoutesUsageService`.

### Acceptance criteria — without `toSubdistrictCode` (sequential mode)
- `fromSubdistrictCode` is the last-selected stop's subdistrict if any stops are already
  chosen, otherwise the job's origin subdistrict.
- Given a reference subdistrict, when the API is called, then it returns pending orders
  (`status='A'` and `orderStatus` in `{NEW, PENDING}`) **restricted to the same province**
  as the reference point, sorted by `distanceKm` ascending, returning at most 10 results.
  The candidate query has no `ORDER BY`; the first 500 rows it returns are ranked (see
  "How 'on the way' is determined"), so with more than 500 pending orders in the province
  some orders are never considered.
- `distanceKm` per candidate is:
  - `null` if the order's address has no resolvable subdistrict.
  - `0` if the candidate is in the exact same subdistrict as the reference point.
  - looked up from the precomputed subdistrict-distance table, falling back to a live
    Google Routes API call (cached for next time) if no row exists — see "How 'on the
    way' is determined" above. Still `null` if even the Google fallback can't resolve it
    (missing lat/lng, Google API failure, etc.) — unknown, not treated as 0 or infinite.
- Candidates with unknown (`null`) distance sort **last**, not excluded — shown in the UI
  with tag "ไม่ทราบระยะ" instead of a distance in km (`0` → "ตำบลเดียวกัน").
- Empty state (no error, not loading, zero results): `EmptyState` "ไม่มีออเดอร์รอจัดส่งใน
  เส้นทางนี้" (suggests clearing the district/subdistrict filter when one is active).
- `detourKm` is always `null` in this mode (no destination given).

### Acceptance criteria — with `toSubdistrictCode` (destination-specified mode)
- Candidates are restricted to the **union** of the origin's province and the
  destination's province (not just one), same pending-status filter as above; same
  500-order candidate pool, ranked, then capped at the nearest/lowest-detour 10 results.
- `fromSubdistrictCode` is the last-selected stop's subdistrict if any stop is chosen,
  otherwise the origin — exactly as in sequential mode — so the numbers are always relative
  to the most recent pick.
- Each candidate's `detourKm` = `distance(from→candidate) + distance(candidate→destination)
  − distance(from→destination)` — a small detour means the candidate is roughly "on the
  way" from the last point to the destination. `detourKm` decides **which** 10 candidates are
  shortlisted (lowest detour first, ties by `distanceKm`); the shortlisted candidates are then
  returned **sorted by `distanceKm` ascending — nearest to the reference point first** (ties by
  `detourKm`), so the "next stop" is at the top. Orders in the destination's own subdistrict
  therefore no longer float to the top just because their detour is 0.
- Any leg (`origin→candidate`, `candidate→destination`, or `origin→destination`) that
  cannot be resolved even after the Google fallback makes `detourKm` `null` for that
  candidate — sorts **last**, not excluded, same convention as `distanceKm` above.
- Same-subdistrict-as-origin or same-subdistrict-as-destination legs are `0`, not looked
  up (mirrors the existing same-subdistrict-as-reference-point rule).
- **How each row is labelled (frontend, `AddJobPage`).** A bare "+0 กม." confused operators, so
  the first tag always shows the distance from the reference point and a second tag
  describes the position on the route in words:
  - distance tag (neutral): `distanceKm` → **"X กม."**; `0` (same subdistrict as the reference
    point) → **"ตำบลเดียวกัน"**; `null` → **"ไม่ทราบระยะ"** (same in sequential mode);
  - destination mode only, position tag: order's `subdistrictCode` equals the destination's →
    success **"อยู่ที่ปลายทาง"**; `detourKm > 0` → warning **"อ้อมเพิ่ม Y กม."**;
    `detourKm <= 0` → success **"ตรงเส้นทาง"**; `detourKm` `null` → no tag.
    (An order in the reference or destination subdistrict has a detour of exactly 0 because
    distances are measured between subdistrict centres.)
- Delivery sequence = pick order in both modes (`DeliveryRouting.sequenceNo` follows the
  `orderIds` array, see US-JOB-02); the frontend no longer re-sorts destination-mode picks.
- Cost note: every pick measures from a new reference point, so each pick can need new
  Google pairs (about ≤ 10 origin-side legs + the reference→destination leg; candidate→
  destination legs are shared across picks and stored). Pairs are stored, so repeating the
  same picks costs nothing, but a long first-time session consumes the daily budget.

### Known gaps
- **Google calls are capped at 100 real requests per day** (adjustable: `configuration` row
  `GR_DAILY`, falling back to `google.maps.daily-request-limit`; Asia/Bangkok day, counted in `google_routes_usage`). Once the cap is hit, legs that are not
  already stored keep their straight-line estimate (so a detour can then mix road and
  straight-line legs); the refusal is only visible in the logs and in
  `GET …/google-distance/usage` as `rejectedCount`. Already-stored pairs keep working.
- **Cross-province legs have no precomputed row**, so they are estimated with the
  straight-line distance from `lat`/`lng` and then confirmed by Google (see "How 'on the way'
  is determined"). A leg stays `null` (candidate sorts last, tag "ไม่ทราบระยะ") only when
  a subdistrict on that leg has no `lat`/`lng` (`sync-subdistricts` not yet run for it) —
  Google can't be asked for it either (`GoogleRoutesService.findRoute` rejects that pair).
  If Google itself fails (network, API error, no route, no `google.maps.api-key`, budget
  used up) the straight-line estimate is kept instead of `null`.

---

## US-JOB-03a — Preview the route before saving

**As an** operator, **I want to** see the stops I picked on a map, in driving order, with the
distance of each leg, **so that** I can spot a wrong pick or a back-and-forth order before I
save the job.

**Entry point:** `AddJobPage` (create and edit, both modes) → "ดูเส้นทาง" in the bottom bar
(enabled once an origin and at least one stop are selected), or `JobDetailPage` → "ดูเส้นทาง"
→ `RoutePreviewModal` (a full-height `BottomSheet`; centred box on wide screens).

**API:** `POST /endpoint-core-service/api/jobs/route-preview` · controller does not read
`Authorization` (the `prod` filter still requires it) ·
body `RoutePreviewRequest { originSubdistrictCode, destinationSubdistrictCode?, orderIds[] }`
(`orderIds` in delivery order; the frontend sends the destination only in
destination-specified mode) · returns `RoutePreviewResponse { points[], legs[], totalKm,
unknownLegCount }`. Read-only: nothing is saved, order status is not checked (so it also works
for a job being edited).

### Acceptance criteria
- `points` = origin, then one point per order in the given order (`stopNo` 1, 2, …), then the
  destination if given; each carries the subdistrict name/district/province and the
  subdistrict centre `lat`/`lng` (`null` if the order has no resolvable subdistrict or the
  subdistrict has no coordinates).
- `legs[i]` goes from `points[i]` to `points[i+1]`. Each leg's `method` is:
  `SAME_SUBDISTRICT` (0 km, Google not called) · `ROAD` (Google road distance through
  `GoogleRoutesService.findRoute` — usually already stored while picking, so no extra budget) ·
  `STRAIGHT_LINE` (Google unavailable: budget used up, error, …; straight-line estimate) ·
  `UNKNOWN` (`distanceKm` `null`, a point has no subdistrict/coordinates).
- `totalKm` sums the known legs only; `unknownLegCount` tells how many were left out.
- Unknown `orderId` → `400 "Order not found: {id}"`; more than 200 orders → `400`.
- The modal shows: total distance, an OpenStreetMap map (Leaflet, no API key) with numbered
  markers styled like the stop list (S = origin, outlined primary; 1…n = gradient; E = destination, dark ink — colours from `theme.css` tokens) joined in order by straight lines
  (solid = road distance known, dashed = estimate), and a list of every point with the
  distance of the leg that reaches it.
- Markers that share a subdistrict (same centre) are fanned out ~400 m apart so each is
  visible.
- **Wrong-order hint:** for every pair of consecutive stops, if swapping them would shorten the
  route by more than 1 km (straight-line estimate between subdistrict centres), a warning
  "ลองสลับ จุดที่ X กับ จุดที่ Y …" is shown. It only compares adjacent pairs — it is a hint,
  not route optimisation.

### Known gaps
- Positions are subdistrict centres, not order addresses (orders have no coordinates — see
  the order `lat`/`lng` gap), so stops in the same subdistrict appear at almost the same
  place with 0 km between them.
- Lines on the map are straight segments between points, not the actual road path.
- Map tiles come from the public OpenStreetMap tile server (fine for light internal use; a
  heavier production load should use a tile provider).

---

## US-JOB-04 — Edit an existing delivery job

**As an** operator, **I want to** change a job's origin, name, or stop list after
creating it, **so that** I can adjust for new/cancelled orders without recreating the
whole job.

**Entry point:** `JobDetailPage` → "⋯" (label "แก้ไขหรือลบงาน") → "จัดการงาน" sheet →
"แก้ไขงาน" → hands the job off via `JobEditContext.editingJob` (not a URL param — this
router has no param support) → `AddJobPage` in edit mode.

**API:** `PUT /endpoint-core-service/api/jobs/{jobId}` · requires `Authorization` ·
same `JobRequest` shape as create.

### Acceptance criteria
- The "แก้ไขงาน" action is hidden entirely once `job.deliveryStatus ===
  "COMPLETED"` — a completed job can only be deleted, not edited, from the UI. This is
  a **UI-only restriction**: `JobService.updateJob` has no server-side check on
  `deliveryStatus` (it only checks the soft-delete `status` flag), so the `PUT` endpoint
  itself would still accept an edit to a completed job if called directly.
- Same non-empty / max-200-orders checks as create, **plus** a duplicate-order-id
  rejection: `"Duplicate orders in the selected stop list"` if `orderIds` contains the
  same id twice (create has no such check — see Known gap in US-JOB-02).
- A job that has been soft-deleted (`status != 'A'`) is treated as not found —
  `"Job not found: {id}"`, HTTP `400` (not `404`). Unknown added order ids →
  `"Some selected orders were not found"`.
- Diffing existing stops against the new `orderIds` list:
  - **Removed stops:** if not yet `COMPLETED`, the underlying order's status resets to
    `NEW`; the routing row is deleted either way (even a `COMPLETED` routing row for a
    removed stop is deleted, though the order itself keeps `COMPLETED` status in that
    case).
  - **Added stops:** must currently be `NEW`/`PENDING` or the whole update is rejected
    with the same "not pending delivery" error as create; newly added stops get
    `orderStatus = IN_TRANSIT`.
  - **Retained stops:** kept, just re-sequenced.
  - Final `sequenceNo` for the merged stop list is reassigned 1..N strictly in the order
    given by the new `orderIds` array — the original sequence is discarded, even for
    retained stops.
- `totalOrders` on the job is recalculated to the new stop count.

---

## US-JOB-05 — Delete (soft-delete) a job

**As an** operator, **I want to** remove a job that's no longer needed, **so that** its
not-yet-delivered orders become available again instead of being stuck "in transit"
forever.

**Entry point:** `JobDetailPage` → "⋯" → "จัดการงาน" sheet → "ลบงาน" → `ConfirmDialog`
(design `docs/design/PopDeleteJob.dc.html`): title `ลบงาน “<title>”?`, "ลบแล้วกู้คืนไม่ได้",
and a summary — "ส่งแล้ว X จุด — ยังนับเป็นส่งแล้ว ไม่เปลี่ยน" / "ยังไม่ส่ง Y จุด — ออเดอร์จะถูก
นำออกจากงานนี้ และจัดเข้างานใหม่ได้" (each line shown only when its count > 0); buttons
"ลบงานนี้" (danger) / "เก็บไว้ก่อน". API failure → error toast (no `alert()`).

**API:** `DELETE /endpoint-core-service/api/jobs/{jobId}` · requires `Authorization`.

### Acceptance criteria
- Given an **open** job with a mix of completed and not-yet-completed stops, when it's
  deleted, then every stop whose `routingStatus` is not `COMPLETED` (including `SKIPPED`)
  has its order's `orderStatus` reset to `NEW`; stops already `COMPLETED` are left untouched.
- Given a job whose `delivery_status` is already `COMPLETED`, when it's deleted, then **no**
  order status is changed — its skipped orders were already returned to `PENDING` when the
  job closed (US-JOB-07) and may by now belong to another job.
- The job itself is **soft-deleted** (`status` set to `'I'`) — it disappears from
  `GET /api/jobs` but its row and all its `DeliveryRouting` rows remain in the DB
  (routing rows are not deleted, unlike the removed-stop path in US-JOB-04).
- `deliveryStatus` on the job is left as-is (not reset), since the row itself becomes
  inactive.
- On success: success toast "ลบงาน “<title>” แล้ว" and navigate back to the job list,
  which re-fetches `GET /api/jobs` on mount.

---

## US-JOB-06 — Complete a delivery stop

**As an** operator, **I want to** mark a single stop as delivered as I complete each
leg of the route, **so that** the order list and job status stay accurate in real time.

**Entry point:** `JobDetailPage` → "ยืนยันว่าส่งแล้ว" on the next-stop card (or tap the
name of any later open stop to deliver out of order) → bottom sheet (design
`docs/design/PopCompleteStop.dc.html`): "จุดที่ X จาก N" · "ส่งของถึงแล้วใช่ไหม?" · the
stop's name/address · "จะบันทึกว่าส่งแล้ว เวลา <client HH:mm> · ต่อไปคือจุดที่ … / เป็นจุด
สุดท้ายของงานนี้"; buttons "ยืนยัน ส่งแล้ว" / "ยังไม่ส่ง". The shown time is the client
clock at render — the stored `deliveryDate` is the server's `now()`. API failure → error
toast, sheet stays open (no `alert()`).

**API:** `PATCH /endpoint-core-service/api/jobs/{jobId}/stops/{orderId}/complete` ·
requires `Authorization`.

### Acceptance criteria
- Given a pending **or skipped** stop on an open job, when completed, then:
  `routing.routingStatus = COMPLETED`, the order's `orderStatus = COMPLETED` and
  `deliveryDate = now()`.
- Given a job whose `delivery_status` is already `COMPLETED`, when any of its stops is
  completed, then the request is rejected (`IllegalArgumentException` → 400).
- If completing this stop leaves no open stops while other stops are skipped, the sheet
  warns "งานจะปิด และจุดที่ข้าม N จุดจะกลับไปรอจัดส่ง".
- Completed stops render with a green ✓ dot and a "ส่งแล้ว" `StatusBadge`, and are no
  longer actionable. On success a toast confirms ("บันทึกว่าส่ง <name> แล้ว", or
  "ส่งครบทุกจุดแล้ว" when the job auto-completes — US-JOB-07).
- Response returns the **full updated `JobResponse`**, which the frontend uses to
  replace that job's entry in local state wholesale (rather than patching just the one
  stop).

### Known gaps
- No guard against completing an already-`COMPLETED` stop on a still-open job — calling it
  twice just re-saves the same status (idempotent, but silently wasteful); the frontend's own
  click-guard (`isCompleted` disables the row) is the only thing preventing this in
  normal use — a direct API call bypasses it entirely.

---

## US-JOB-06a — Skip a delivery stop

**As an** operator, **I want to** skip a stop when the driver won't deliver to that
customer on this run, **so that** they can move on to the next stop and the order can be
regrouped into a later job.

**Entry point:** `JobDetailPage` → "ข้ามจุดนี้" (text button under "ยืนยันว่าส่งแล้ว" on the
next-stop card, or in the complete-stop sheet of any other open stop) → `ConfirmDialog`
(tone warning): "ข้าม <name>?" · buttons "ข้ามจุดนี้" / "ไม่ข้าม". No reason is captured.

**API:** `PATCH /endpoint-core-service/api/jobs/{jobId}/stops/{orderId}/skip` · requires
`Authorization` · returns the full updated `JobResponse`.

### Acceptance criteria
- Given an open stop (`NEW`/`PENDING`/`IN_TRANSIT`) on an open job, when skipped, then
  `routing.routingStatus = SKIPPED`; the order's `orderStatus` is **unchanged** (stays
  `IN_TRANSIT`) while the job is open.
- A skipped stop is not the "next stop"; the next open stop becomes the highlighted card.
  In the timeline it shows a dashed amber dot and a "ข้าม" `StatusBadge`, and its name stays
  tappable → complete-stop sheet, so it **can still be delivered** (US-JOB-06) until the job
  closes.
- Skipping a stop that is already `COMPLETED` or `SKIPPED`, or any stop on a job whose
  `delivery_status` is `COMPLETED`, is rejected (400).
- If the skip leaves no open stops, the job auto-closes (US-JOB-07); the dialog warns
  "งานจะปิดทันที" beforehand.
- Toast: "ข้าม <name> แล้ว", or "งานนี้ปิดแล้ว · ข้าม N จุด" when the skip closes the job.

---

## US-JOB-07 — Job auto-completes when no open stops remain

**As an** operator, **I want** a job to flip to completed automatically once every stop
on it is delivered or skipped, **so that** I don't have to separately close out the job.

**Trigger:** the `PATCH .../complete` (US-JOB-06) and `PATCH .../skip` (US-JOB-06a) calls.

### Acceptance criteria
- After marking a stop complete or skipped, the service re-checks **every** routing row on
  that job. If all of them have `routingStatus` `"COMPLETED"` or `"SKIPPED"`
  (case-insensitive), then `delivery_status` is set to uppercase `"COMPLETED"` and
  `completed_date = now()`.
- At that moment every `SKIPPED` stop's order is set to `orderStatus = PENDING` (รอจัดส่ง),
  which `findCandidateOrdersForJob` accepts — so skipped orders can be picked into a new
  job. The routing row keeps `SKIPPED` as history.
- A closed job with skipped stops shows "งานนี้ปิดแล้ว · ส่งแล้ว X จุด · ข้าม Y จุด — ออเดอร์ที่ข้าม
  กลับไปรอจัดส่ง จัดเข้างานรอบถัดไปได้"; skipped stops are no longer tappable.
- A job where **every** stop was skipped also closes (with 0 delivered).
- This is the **only** code path that ever changes `delivery_status` away from its
  default `"NEW"` — there is no explicit "close job" action.

---

## Dead code in this epic (present in the repo, not reachable from the live app)

Flagging these so they aren't mistaken for in-scope requirements when reading the code
directly:
- `pages/MapPage.jsx` and its helpers (`components/Map/LocationDistanceFormModal.jsx`,
  `components/DeliveryRoute/LocationSelector.jsx`, `hooks/useLocationPicker.js`,
  `services/{District,Subdistrict,Location}DistanceService.jsx`) — the map menu is
  temporarily disabled; its route is commented out in `router/routes.jsx`.
