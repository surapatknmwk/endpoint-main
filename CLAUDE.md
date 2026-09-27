# ENDPOINT SYSTEM

## Related Services
- Frontend endpoint-webapp/
- Backend endpoint-service/

## Working across submodules
- Each submodule is an independent git repo with its own `dev` branch (see `.gitmodules`). Commit
  and push inside the submodule directory itself, not from the root.
- Never run build/test commands from this root — `cd` into the relevant submodule first.
- If a change spans both submodules (e.g. API contract change), make the changes in each
  submodule's own commit and note the corresponding commit/branch in each PR description.

## When writing unit tests use the following guidelines

### Unit Test Writing Workflow
1. ASK QUESTIONS
   You must ask these questions before getting started

- **WHAT** does this method promise? (contract: return value, state change, exception)
- **WHEN** does that hold? (normal / edge / broken input)
- **THEN** what is the observable proof? (what you assert)

2. Structure Every Test using comment then follow by code

```
//GIVEN  - set up the world + mocks
...Code
//WHEN   - call the method
...Code
//THEN   - assert the promise
...Code
```

3. Start by writing test name with the following naming format

```
void should_[outcome]_when_condition
```

4. Write one test at a time

5. In Given/prepare data use ZOMBIES: What Data to Prepare

| Letter | Stands For | What to test                                   |
| ------ | ---------- | ---------------------------------------------- |
| Z      | Zero       | Empty list, 0 count, null result               |
| O      | One        | Single valid record — minimal case             |
| M      | Many       | Multiple items, loops, bulk                    |
| B      | Boundary   | Max 200 IDs (chunk limit), first/last date     |
| I      | Interface  | Null param, wrong type, missing field          |
| E      | Exception  | Oracle MS 500, DB unreachable, invalid state   |
| S      | Scenario   | Happy path — baseline everything deviates from |

Run through all 7 mentally. Consciously decide to skip — never accidentally miss.

6. Mock the Boundary, Test the Logic

| Dependency                   | Mock?                  |
| ---------------------------- | ---------------------- |
| PostgreSQL query             | MOCK or Testcontainers |
| Date/time (LocalDate.now())  | MOCK — inject Clock    |
| Business logic in same class | NEVER MOCK             |
| Pure utility / math          | TEST REAL              |
| Static with side effects     | WRAP IT                |


## Documentation — source of truth
`docs/user-stories/` contains the **source of truth** requirement documentation for this
project, written as User Stories generated directly from the current code (not
aspirational design). Each file covers one epic/domain, with API contracts, business
rules, status transitions, and known gaps/inconsistencies called out explicitly per
story. Consult these before making assumptions about intended behavior, and update the
relevant file whenever a change alters the behavior it describes.

- [docs/user-stories/orders.md](docs/user-stories/orders.md) — Order epic (create, edit,
  copy, search, cancel, complete, delete)
- [docs/user-stories/jobs.md](docs/user-stories/jobs.md) — Job / delivery route epic (job
  listing, creation, candidate-order picking, editing, delete, stop completion)

## UI — source of truth
- ทุกการสร้าง/แก้ UI ใน `endpoint-webapp` ต้องทำตาม [docs/ui-guidelines.md](docs/ui-guidelines.md)
- หน้าตาอ้างอิงของแต่ละหน้าอยู่ที่ [docs/design/](docs/design/README.md) (ไฟล์ `.dc.html` อ่านเป็นสเปก: สี ระยะห่าง ข้อความ โครงสร้าง)
- ใช้ตัวแปรจาก `endpoint-webapp/src/styles/theme.css` เท่านั้น ห้าม hard-code สีใหม่
- ใช้ component จาก `endpoint-webapp/src/components/ui/` ก่อนสร้างของใหม่ ถ้าต้องสร้างใหม่ให้เพิ่มไว้ในโฟลเดอร์นั้น
- ห้ามใช้ `alert()` / `confirm()` — ใช้ `useToast()` / `ConfirmDialog`

## Key Terms

| Term    | Definition                                                                                |
| ------- | ----------------------------------------------------------------------------------------- |
| order      | คือ รายการ การสั่งการส่ง หรือ การระบุการส่งของให้ลูกค้า ซึ่งจะได้มาจากช่องทางต่างๆ จากการติดต่อเช่น การโทรติดต่อ, facebook chat, line chat และอื่น |
| job / งาน | คือ รายการ การจัดส่งของให้ลูกค้า จะต้องมี ต้นทาง ไป ปลายทาง ซึ่งใน 1 งาน อาจจะมีหลาย orders ก็ได้ ขึ้นอยู่กับว่า จะไปแวะไปส่ง orders ไหนบ้างระหว่างการเดินทางเพื่อจัดส่ง ถึงปลายทาง |

## Status Values

### Order status (`order_status` / `orderStatus`)
Served as `orderStatus` in `endpoint-service` DTOs; values in
`endpoint-webapp/src/constants/orderStatus.js` (`ORDER_STATUS`); labeled in
`endpoint-webapp/src/components/ui/StatusBadge.jsx` (`StatusBadge kind="order"`).
DB CHECK constraint in `db/schema-db.sql` (new-database setup: `db/README.md`) — see
[docs/user-stories/orders.md](docs/user-stories/orders.md).

| Value        | แสดงผลเป็น (ภาษาไทย) | ความหมาย                          |
| ------------ | --------------------- | ---------------------------------- |
| `NEW`        | ใหม่                   | order ที่เพิ่งเข้ามา ยังไม่ถูกจัดเข้า job (หรือถูกเอาออกจาก job) |
| `IN_TRANSIT` | กำลังจัดส่ง            | order ที่ถูกจัดเข้า job แล้ว อยู่ระหว่างจัดส่ง |
| `PENDING`    | รอจัดส่ง               | order ที่ถูกข้ามใน job ที่ปิดไปแล้ว รอจัดเข้า job รอบถัดไป |
| `COMPLETED`  | ส่งแล้ว                | order ที่จัดส่งสำเร็จแล้ว              |
| `CANCELLED`  | ยกเลิก                 | order ที่ถูกยกเลิก                    |

### Job / stop status (`routingStatus`)
Labeled in `endpoint-webapp/src/components/ui/StatusBadge.jsx` (`StatusBadge kind="stop"`) — this is
the status of a stop within a job's delivery route, separate from `order_status` above.

| Value        | แสดงผลเป็น (ภาษาไทย) | ความหมาย                        |
| ------------ | --------------------- | --------------------------------- |
| `NEW` / `PENDING` | รอจัดส่ง          | stop ที่ยังไม่เริ่มจัดส่ง            |
| `IN_TRANSIT` | กำลังจัดส่ง            | อยู่ระหว่างการจัดส่งไปยัง stop นี้      |
| `COMPLETED`  | ส่งแล้ว                | จัดส่งถึง stop นี้สำเร็จแล้ว          |
| `SKIPPED`    | ข้าม                   | คนส่งข้าม stop นี้ — ยังกลับมาส่งได้จนกว่างานจะปิด, งานปิดแล้ว order กลับเป็น `PENDING` |
| `CANCELLED`  | ยกเลิก                 | stop ที่ถูกยกเลิก                    |