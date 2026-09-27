# Epic: Order Management (ออเดอร์)

Source of truth generated from current code, not aspirational design. Where the code
disagrees with itself (validation gaps, dead fields, status mismatches), that is called
out explicitly under **Known gaps** rather than smoothed over — treat those as backlog
items, not as intended behavior to build against.

**Key term (see root `CLAUDE.md`):** an `order` (order) is a single delivery request for
one customer, created from a channel such as phone, Facebook chat, or Line chat. Orders
are later grouped into a `job` (see [jobs.md](jobs.md)) for actual delivery.

## Actor, authentication and permissions
There is a single actor type in the UI (`ผู้ใช้งาน` / operator) who logs in and sends a JWT
`Authorization: Bearer <token>` header with every call (`services/apiClient.jsx`). What the
backend enforces depends on the Spring profile:

| | Default profile (`application.yml`) | `prod` profile (`application-prod.yml`) |
| --- | --- | --- |
| `security.filter.enabled` | `false` — `SecurityFilter` lets every request through | `true` |
| Token check | none (controllers that read the header still need it present) | every `/endpoint-{core,master,search}-service/**` request needs a valid token that also has a live row in `user_sessions` (`AuthenticationService.validateToken`) |
| Permission check | none | **core only** (`/endpoint-core-service/**`): the token's role must have an active `permissions` → `providers` row whose `method` + `api` equal the request method and the Spring mapping pattern (e.g. `PUT /endpoint-core-service/api/orders/{orderId}`). Result cached 1 h per role+method+pattern (`permissionCache`). Master and search endpoints need a valid token only. |
| Search scoping | none — search returns every operator's orders | the JWT `sub` (username) is forced into the search as `createdBy` (US-ORD-04) |

- A failed token **or permission** check returns `401`. The webapp treats every `401` as an
  expired session: `AuthContext` logs the operator out and returns them to the login page.
  So a missing permission row looks like "I got logged out" to the operator.
- `db/permissions-orders-data.sql` seeds the five order endpoints (create, update, complete,
  cancel, delete) for **every** role; `db/permissions-jobs-data.sql` does the same for the
  eight job endpoints (see [jobs.md](jobs.md#actor)). Neither is run automatically by
  `db/docker-compose.yml` — run them after creating the schema.
- Error UX shared by every page: any non-2xx response (except the login/logout/validate/
  refresh calls, which are `silent`) also opens the global `ApiErrorModal` with the server's
  `message`; a network failure shows "ไม่สามารถเชื่อมต่อกับระบบได้ กรุณาลองใหม่อีกครั้ง". Pages add
  their own toast on top.

## Order status reference (`order_status` / `orderStatus`)

| Value | Thai label (`StatusBadge kind="order"`) | Set by | In `schema-db.sql` CHECK? |
| --- | --- | --- | --- |
| `NEW` | ใหม่ | create (default); job edit/delete returning an order to the pool | yes (default) |
| `PENDING` | รอจัดส่ง | `JobService` when a job closes with this order's stop `SKIPPED` (US-JOB-07 in [jobs.md](jobs.md)) | yes |
| `IN_TRANSIT` | กำลังจัดส่ง | `JobService` when the order is put on a job | yes |
| `COMPLETED` | ส่งแล้ว | `JobService.completeStop` (US-JOB-06) or `OrderController.completeOrder` (US-ORD-06) | yes |
| `CANCELLED` | ยกเลิก | `OrderService.cancelOrder` (US-ORD-05) | yes |

`constants/orderStatus.js` exports `ORDER_STATUS` (all five values) and
`getOrderStatusLabel`, whose own label map only covers `NEW`/`PENDING`/`COMPLETED` (used for
the read-only notice in `OrderFormModal`). Badges use the full map in
`components/ui/StatusBadge.jsx`.

### Schema note: the `orders.order_status` CHECK constraint
`db/schema-db.sql` allows all five values above (setup order for a new database:
`db/README.md`). A database created from an older copy of that file rejects `IN_TRANSIT`,
which makes putting an order on a job fail with `500`; fix it with
`ALTER TABLE orders DROP CONSTRAINT orders_order_status_check;` and re-add the CHECK from
`schema-db.sql`. The current development database has no CHECK constraint on `orders`.

---

## US-ORD-01 — Create an order

**As an** operator, **I want to** enter a new order with customer, address, and shipment
details, **so that** it is available in the order list and can later be assigned to a
delivery job.

**Entry point:** `OrdersManagePage` → "เพิ่มออเดอร์" (floating button, or the empty-state
button) → `OrderFormModal` bottom sheet titled "เพิ่มออเดอร์" (design
`docs/design/OrderForm.dc.html`).

**API:** `POST /endpoint-core-service/api/orders` · `Authorization` header required (the
username becomes `createdBy`) · body `OrderRequest` · returns `201` with the created
`OrderResponse`.

### Form fields
| Field (label) | Sent as | Rule |
| --- | --- | --- |
| ชื่อลูกค้า | `customer.name` | required, max 100 chars |
| เบอร์โทร (ถ้ามี) | `customer.phone` | optional; formatted `xxx-xxx-xxxx` while typing (digits only, max 10), dashes stripped before sending |
| ช่องทางที่สั่ง | `platformId` (+ `platformCode`, ignored by the backend) | required; chips from the active `platforms` configuration group |
| บ้านเลขที่ / ถนน / จุดสังเกต | `address.addressLine` | required |
| จังหวัด / อำเภอ / ตำบล | `address.provinceCode` / `districtCode` / `subdistrictCode` | required; cascading selects, each disabled until its parent is chosen |
| รหัสไปรษณีย์ | `address.zipCode` | optional; auto-filled from the chosen subdistrict, editable, max 5 |
| ลิงก์ Google Maps (ถ้ามี) | `address.mapLink` | optional; "วาง" pastes from the clipboard |
| รายละเอียดสินค้า / หมายเหตุ | `detail` | optional, max 300 chars |

### Acceptance criteria
- Given the required fields are filled, when the operator taps "บันทึกออเดอร์", then an
  order is created with `orderStatus = NEW`, `sequenceNo = 1` and a generated `orderCode`
  `ORD-yyyyMMdd-<8-char-uppercase-UUID-fragment>` (e.g. `ORD-20260905-A1B2C3D4`).
- A missing required field shows a red message under that field ("กรุณากรอกชื่อลูกค้า",
  "กรุณาเลือกช่องทาง", …) and nothing is sent.
- A brand-new `Customer` row and a brand-new `OrderAddress` row are created for every
  order — there is no lookup/reuse of an existing customer or address.
- Success → toast "เพิ่มออเดอร์แล้ว", the sheet closes and the list re-searches. Failure →
  toast with the server message (or "บันทึกไม่สำเร็จ ลองอีกครั้ง"); the sheet stays open.

### Known gaps
- **No server-side validation.** `OrderRequest` has no Bean Validation annotations — a direct
  API call can create an order with a null customer name or missing address; it only fails
  on a DB `NOT NULL`/`CHECK` constraint, surfacing as a generic `500`. A request without a
  `customer` or `address` object fails with a `500` (null pointer).
- On create the backend trusts `orderStatus` from the request (defaults to `NEW` only when
  null); the webapp always sends `"NEW"`.
- The webapp also sends `email`, `commodity`, `size`, `price`, `weight`, `width`, `height`,
  `remark` (all empty/0 — the form has no inputs for them), `deliveryDate` (ignored by
  create) and `address.lat`/`lng` (always null; `com.core.entity.OrderAddress` does not map
  those columns anyway).
- `orderCode` uniqueness relies only on the DB `UNIQUE` constraint — a UUID-fragment
  collision would surface as a `500`.

---

## US-ORD-02 — Edit an existing order

**As an** operator, **I want to** update an order's details, **so that** I can correct
mistakes or reflect changed shipment info before it's delivered.

**Entry point:** `OrdersManagePage` → the "›" button on an order card (label
"แก้ไข <name>") → `OrderFormModal` titled "แก้ไขออเดอร์", pre-filled, button
"บันทึกการแก้ไข".

**API:** `PUT /endpoint-core-service/api/orders/{orderId}` · `Authorization` required ·
body `OrderRequest` · `200` on success.

### Acceptance criteria
- The `Customer` and `OrderAddress` rows tied to the order are overwritten in place (full
  replace, not a merge), and the order's commodity/size/price/weight/width/height/detail/
  remark/`platformId` are overwritten. `sequenceNo` keeps its stored value when the request
  sends `null` (the webapp omits it on edit).
- **Editing never changes `orderStatus`.** The backend ignores `orderStatus` on update, and
  the webapp does not send it; status only moves through cancel/complete and the job flow.
- Unknown `orderId` → **`400`** (not `404`) "Order not found: {id}".
- **Status-based locking**, enforced in `OrderFormModal` and again in
  `OrderService.updateOrder`:
  - `COMPLETED` or `CANCELLED`: the sheet is read-only with the notice
    "ออเดอร์นี้ “<label>” แล้ว · ดูข้อมูลได้อย่างเดียว แก้ไขไม่ได้" and no save button;
    the server rejects the update with `400`.
  - `PENDING` or `IN_TRANSIT`: province/district/subdistrict/zip are disabled with the
    warning "แก้ที่อยู่ไม่ได้"; the server silently keeps the stored values for those four
    fields. Everything else stays editable.
- Success → toast "บันทึกการแก้ไขแล้ว".

### Known gaps
- Same absence of server-side validation as US-ORD-01.

---

## US-ORD-03 — Copy an order

**As an** operator, **I want to** duplicate an existing order's details into a new
order, **so that** I don't have to re-type recurring/similar shipments from scratch.

**Entry point:** `OrdersManagePage` → "คัดลอก" on an order card → `OrderFormModal` titled
"คัดลอกออเดอร์", pre-filled, in create mode.

### Acceptance criteria
- All fields are pre-filled from the source order and nothing is locked (whatever the source
  order's status). Submitting calls `POST .../orders`, producing a brand-new order with its
  own `orderCode`, `orderId`, `Customer`, and `OrderAddress` rows — the source is untouched.
- Success → toast "เพิ่มออเดอร์แล้ว".

---

## US-ORD-04 — Browse, search and filter orders

**As an** operator, **I want to** filter the order list by status, customer name,
platform, or location, **so that** I can quickly find the order(s) I need.

**Entry points** (`OrdersManagePage`, design `docs/design/Main.dc.html`):
- Status tabs (`SegmentedTabs`): "ใหม่" (`NEW`, default), "รอจัดส่ง" (`PENDING`),
  "ทั้งหมด" (no status filter).
- Header search box "ค้นหาชื่อลูกค้า".
- Filter button ("ตัวกรอง") → `OrderSearchModal`: ชื่อ, แพลตฟอร์ม, จังหวัด/อำเภอ/ตำบล (cascading,
  each "ทั้งหมด" by default), buttons "ค้นหา" and "ล้างการค้นหา". No status field — status is
  controlled only by the tabs.

**API:** `POST /endpoint-search-service/api/search/orders` (package `com.search`) · body
`OrderSearchRequest { customerName, platformId, provinceId, districtId, subdistrictId,
orderStatus, page, size, sortBy, sortDirection }` · returns `PageResponse<OrderResponse>`.

### Acceptance criteria
- The page loads the first search on open; results are sorted by `createdAt` descending.
- Changing tab re-searches immediately. Typing in the search box re-searches 400 ms after the
  last keystroke (no loading overlay); Enter searches immediately.
- `customerName` matches case-insensitively as a substring of the customer's `name`,
  `firstName` or `lastName`.
- `platformId`, `provinceId`, `districtId`, `subdistrictId` equal to `0` mean "no filter".
- "ล้างการค้นหา" resets every filter and the status back to `NEW`, then re-searches.
- In the `prod` profile only orders whose `createdBy` equals the logged-in username are
  returned (see Actor); with the filter disabled every order is returned.
- Each card shows: platform tag, `orderCode`, the status badge (only on the "ทั้งหมด" tab),
  created time (HH:mm), customer name, address line + "ต. อ. จ.", detail, and actions:
  "โทร" (when the customer has a phone), "แผนที่" (when the order has a Google Maps link —
  opens it in a new tab), "คัดลอก", edit.
- No results → `EmptyState` "ยังไม่มีออเดอร์".

### Known gaps
- **Only the first 10 orders are ever shown.** Every search asks for `page 0, size 10` and the
  page has no paging or "load more" control, so older matches are unreachable.
- Orders that are `IN_TRANSIT` (on an open job) appear only under "ทั้งหมด" — neither
  "ใหม่" nor "รอจัดส่ง" matches them.
- The webapp sends `platformCode`; `OrderSearchRequest` has no such field (ignored).
- The location filters are sent as `provinceId`/`districtId`/`subdistrictId` holding the
  numeric **code** (`parseInt(code)`), and are compared against the string
  `provinceCode`/`districtCode`/`subdistrictCode` columns — works for today's numeric codes
  but is type-fragile.
- `OrdersManagePage` still contains a Google Maps pin/direction modal, but the only caller
  (`openMapForOrder`) is reached from the "แผนที่" button, which is rendered only when a
  `mapLink` exists and then opens the link instead — the modal is unreachable.

---

## US-ORD-05 — Cancel one or more orders

**As an** operator, **I want to** select multiple orders and cancel them at once,
**so that** I can clear out orders that are no longer needed without deleting them.

**Entry point:** `OrdersManagePage` → "เลือก" (header) → select mode (design
`docs/design/OrdersSelect.dc.html`): header "เลือกออเดอร์" / "เลือกแล้ว N รายการ", "เลือกทั้งหมด"
/ "ไม่เลือกทั้งหมด", notice "เลือกได้เฉพาะออเดอร์ “ใหม่” — ออเดอร์ที่ถูกจัดเข้างานแล้วจะเลือกไม่ได้",
a checkbox per card, and a bottom button "ยกเลิกออเดอร์ N รายการ" → `ConfirmDialog` (design
`docs/design/PopCancel.dc.html`) "ยกเลิก N ออเดอร์?" listing the selected orders, buttons
"ยกเลิกออเดอร์ N รายการ" / "ไม่ใช่ตอนนี้". "✕" leaves select mode.

**API:** `PATCH /endpoint-core-service/api/orders/cancel/{orderId}`, called once per
selected order in parallel (`Promise.all`) — there is no bulk endpoint.

### Acceptance criteria
- Only `NEW` orders can be selected: other cards are shown greyed out with a disabled
  checkbox, "เลือกทั้งหมด" only picks `NEW` orders, and `toggleOrderSelection` ignores
  non-`NEW` orders.
- On confirm each selected order becomes `CANCELLED`; the list re-searches, a toast
  "ยกเลิก N ออเดอร์แล้ว" is shown and select mode closes.
- `OrderService.cancelOrder` rejects any order whose status is not `NEW` with `400`, so a
  direct API call cannot cancel an order that is on a job or already finished.
- Nothing is hard-deleted from this screen.

### Known gaps
- Partial failure is reported as success: `apiClient` does not throw on HTTP errors, so if
  some cancellations fail the toast still says all N were cancelled (the global
  `ApiErrorModal` shows the server error, and the refreshed list shows the truth).

---

## US-ORD-06 — Complete an order (backend capability, no direct UI)

**As an** operator, **I want** an order to be marked `COMPLETED` when it is delivered,
**so that** the order list reflects real delivery status.

**API:** `PATCH /endpoint-core-service/api/orders/complete/{orderId}` · `Authorization`
required — sets `orderStatus = COMPLETED`, `deliveryDate = now()`. No prior-status guard.

### Known gaps
- No screen calls this endpoint. Orders are completed through **US-JOB-06** in
  [jobs.md](jobs.md) (`PATCH /api/jobs/{jobId}/stops/{orderId}/complete`), which also
  updates the job's routing row. `OrdersContext.completeOrders` exists but is unused.
- Calling it directly on an order that is on a job leaves that job's stop open.

---

## US-ORD-07 — Delete an order (backend capability, no direct UI)

**As an** operator, **I want** an order and its related records fully removed,
**so that** bad/duplicate data doesn't linger.

**API:** `DELETE /endpoint-core-service/api/orders/{orderId}`. The controller does not read
the `Authorization` header (no audit of who deleted), but in the `prod` profile the security
filter still requires a valid token and the delete permission.

### Business rules
- Hard-deletes, in order: every `DeliveryRouting` row referencing the order (for the FK),
  the `Order` row, then its `Customer` and `OrderAddress` rows.
- Unknown `orderId` → `400` "Order not found: {id}". No status guard.

### Known gaps
- Not reachable from any screen (`OrdersContext.deleteOrder`/`deleteOrders` exist but are
  unused).
- Removing the order's customer/address is only safe because every order owns its own rows
  (US-ORD-01).
- `DeliveryJob.totalOrders` of a job that lost a routing row is not adjusted.
