# UI Guidelines — Endpoint

เอกสารนี้คือ **กติกา UI ที่ต้องทำตาม** ทุกครั้งที่สร้างหรือแก้หน้าจอใน `endpoint-webapp`
หน้าตาอ้างอิงอยู่ที่ [`docs/design/`](design/README.md) · ค่าทั้งหมดอยู่ใน `endpoint-webapp/src/styles/theme.css`

---

## 1. หลักการ

1. **มือถือก่อน** — ผู้ใช้หลักใช้บนมือถือขณะออกไปส่งของ ออกแบบที่ความกว้าง 390px ก่อน แล้วค่อยขยายเป็นจอกว้าง (≥ 992px)
2. **ทุกปุ่มต้องมีข้อความ** — ห้ามปุ่มหลักที่มีแต่ไอคอน (เช่น 💾 🗑) ปุ่มไอคอนล้วนใช้ได้เฉพาะปุ่มรองที่คนรู้ความหมาย (ปิด ✕, กลับ ‹, ตัวกรอง) และต้องมี `aria-label`
3. **1 หน้าจอ มีปุ่มหลัก (gradient) ได้ 1 ปุ่ม**
4. **เป้ากดสูงอย่างน้อย 44px** (`--ep-touch`)
5. **ห้าม hard-code สี** — ใช้ `var(--ep-…)` จาก `theme.css` เท่านั้น ห้าม `rgba(0,0,0,0.21)` หรือ `style={{ backgroundColor: 'rgb(26,26,26)' }}` แบบเดิม
6. **ห้ามใช้ `alert()` / `confirm()`** — ใช้ Toast หรือ ConfirmDialog จาก `src/components/ui/`
7. **ภาษา** — ข้อความบนจอเป็นภาษาไทย บอกผลลัพธ์ตรงๆ เช่น "ยกเลิกออเดอร์ 2 รายการ" ไม่ใช่ "ยืนยัน"

## 2. Design tokens (สรุป)

| กลุ่ม | ตัวแปร | ค่า |
| --- | --- | --- |
| สีหลัก | `--ep-primary` | `#3346C4` (ตัวอักษร ไอคอน เส้นขอบที่เลือก) |
| ไล่เฉด | `--ep-gradient` | `135deg #3346C4 → #5B34C9` (ปุ่มหลัก FAB แถบความคืบหน้า) |
| พื้นหลัง | `--ep-bg` / `--ep-surface` | `#F6F6FA` / `#FFFFFF` |
| เส้นขอบ | `--ep-border` / `--ep-border-strong` | `#E3E2EC` / `#CCCBDA` |
| ตัวอักษร | `--ep-ink` / `--ep-muted` | `#17191C` / `#5B5F66` |
| ฟอนต์หัวข้อ | `--ep-font-display` | IBM Plex Sans Thai 700 |
| ฟอนต์เนื้อหา | `--ep-font-body` | Sarabun |
| มุมโค้ง | tag 6 · input 10 · ปุ่ม 12 · การ์ด 14 · sheet 20 · pill 999 |
| ระยะห่าง | 4 · 8 · 12 · 16 · 20 (ขอบจอ) · 24 · 32 |

ขนาดตัวอักษร: หัวข้อหน้า 28 · หัวข้อ sheet 20 · ชื่อในการ์ด 17 · ช่องกรอก 16 · รอง 14 · caption 13 · overline 12

## 3. สีสถานะ

ต้องแสดง **ข้อความคู่กับสีเสมอ** (ห้ามใช้สีอย่างเดียว)

### Order (`order_status`)
| ค่า | ข้อความ | สี (ตัวอักษร / พื้น) |
| --- | --- | --- |
| `NEW` | ใหม่ | `--ep-info` / `--ep-info-bg` |
| `PENDING` | รอจัดส่ง | `--ep-warning` / `--ep-warning-bg` |
| `COMPLETED` | ส่งแล้ว | `--ep-success` / `--ep-success-bg` |
| `CANCELLED` | ยกเลิก | `--ep-danger` / `--ep-danger-bg` |

### จุดส่ง (`routingStatus`)
| ค่า | ข้อความ | สี |
| --- | --- | --- |
| `NEW` / `PENDING` | รอจัดส่ง | `--ep-neutral` / `--ep-neutral-bg` |
| `IN_TRANSIT` | กำลังจัดส่ง | `--ep-transit` / `--ep-transit-bg` |
| `COMPLETED` | ส่งแล้ว | `--ep-success` / `--ep-success-bg` |
| `CANCELLED` | ยกเลิก | `--ep-danger` / `--ep-danger-bg` |

ใช้ `<StatusBadge kind="order" status={order.orderStatus} />` หรือ `kind="stop"`

## 4. Components (`src/components/ui/`)

| Component | ใช้เมื่อ | แทนของเดิม |
| --- | --- | --- |
| `Button` | ทุกปุ่ม · `variant="primary|secondary|text|danger"` · `size="lg|md|sm"` · `loading` | `react-bootstrap/Button` + inline style |
| `IconButton` | ปุ่มไอคอนล้วน (ต้องส่ง `label`) | `<Button><FaTrash/></Button>` |
| `StatusBadge` | ป้ายสถานะ order / จุดส่ง | `Badge bg=...` |
| `PageHeader` | หัวหน้าหลัก (wordmark + หัวข้อ + action) / หน้าย่อย (ปุ่มกลับ) · หน้ารายการใส่ `sticky` ให้หัว+ค้นหา+แท็บตรึงไว้ เลื่อนเฉพาะรายการ | `<div>ORDERS</div>` |
| `SegmentedTabs` | สลับแท็บสถานะ พร้อมตัวนับ | `ButtonGroup` |
| `BottomSheet` | ฟอร์ม ตัวกรอง เลือกพื้นที่ ยืนยันส่ง | `Modal` กลางจอ |
| `ConfirmDialog` | ต้องตัดสินใจก่อนไปต่อ / ทำแล้วย้อนไม่ได้ | `Modal` ยืนยัน + `confirm()` |
| `ToastProvider` + `useToast()` | แจ้งผลสิ่งที่เพิ่งทำ | `alert()` |
| `InlineAlert` | ข้อความในหน้า (info/success/warning/error) | `div.alert` |
| `BottomNav` / `SideNav` | เมนูหลัก (มือถือ / จอกว้าง) | navbar + hamburger |
| `EmptyState` | รายการว่าง | "ยังไม่มีรายการ" ตัวเทา |

## 5. การนำทาง

- เมนูหลัก 3 เมนู: **ออเดอร์ · งานจัดส่ง · บัญชี** (เพิ่มได้ไม่เกิน 5)
- มือถือ = `BottomNav` ติดล่าง · จอ ≥ 992px = `SideNav` ด้านซ้าย
- หน้าย่อย (รายละเอียด สร้างงาน ฟอร์มเต็มจอ) **ซ่อนเมนูล่าง** และมีปุ่มกลับ ‹ มุมซ้ายบน
- โหมดมืด และ ออกจากระบบ อยู่ในหน้า **บัญชี** (ไม่อยู่บนแถบเมนู)
- แตะเมนูที่อยู่แล้วซ้ำ = เลื่อนขึ้นบนสุด

## 6. เลือกใช้ Alert แบบไหน

| แบบ | ใช้เมื่อ | ตัวอย่าง |
| --- | --- | --- |
| `InlineAlert` | เรื่องของเนื้อหาตรงนั้น | แก้ที่อยู่ไม่ได้ · ไม่มีออเดอร์ในเส้นทางนี้ |
| Banner | สถานะที่กระทบทั้งแอป | ออฟไลน์ |
| Toast | ผลของสิ่งที่เพิ่งกด (หายเองใน 4 วิ) | บันทึกแล้ว · ยกเลิก 2 ออเดอร์แล้ว |
| `ConfirmDialog` | ทำแล้วย้อนไม่ได้ / ต้องตัดสินใจ | ลบงาน · ออกโดยไม่บันทึก |

Dialog: หัวข้อเป็นคำถาม · ปุ่มบอกผลลัพธ์ · ปุ่มหลักอยู่บน · ปุ่มอันตรายใช้ `variant="danger"`

## 7. ฟอร์ม

- label อยู่**นอก**ช่องกรอกเสมอ (เลิกใช้ `FloatingLabel`)
- ช่องกรอกสูง 48px ตัวอักษร 16px
- error อยู่ใต้ช่อง สีแดง พร้อมบอกวิธีแก้
- ช่องที่ล็อก: พื้นเทา + ไอคอนกุญแจ + บอกเหตุผล
- ปุ่มบันทึกติดด้านล่างของ sheet/หน้า

## 8. Checklist ก่อน commit หน้า UI

- [ ] ไม่มีสี hex / rgba ใหม่ในไฟล์ `.jsx` (ยกเว้นสีจาก master data เช่น platform)
- [ ] ปุ่มหลักมีข้อความ · ปุ่มไอคอนมี `aria-label`
- [ ] ไม่มี `alert(` / `confirm(`
- [ ] ดูที่ความกว้าง 390px และ 1280px แล้ว
- [ ] ป้ายสถานะใช้ `StatusBadge`
- [ ] เทียบกับไฟล์ใน `docs/design/` ของหน้านั้นแล้ว
