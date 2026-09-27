# Endpoint UI Design — ไฟล์อ้างอิง

ดีไซน์ต้นฉบับอยู่บน canvas ใน Claude (Endpoint UI Redesign)
โฟลเดอร์นี้เก็บ **สำเนาไฟล์ดีไซน์** ไว้ให้คนและ AI ใน VS Code อ่านเป็นแม่แบบ

> ไฟล์ `.dc.html` เปิดตรงๆ ในเบราว์เซอร์จะไม่แสดงผลครบ (ต้องใช้ runtime ของ canvas)
> ให้ใช้เป็น **สเปก**: อ่านค่าสี ระยะห่าง ขนาดตัวอักษร ข้อความ และโครงสร้างจาก inline style

กติกาที่ต้องทำตามอยู่ใน [`../ui-guidelines.md`](../ui-guidelines.md)
ค่าสี/ระยะห่างใช้จาก `endpoint-webapp/src/styles/theme.css` เท่านั้น

## แผนที่ไฟล์

| หมวด | ไฟล์ | หน้าจอในโค้ด |
| ---- | ---- | ------------ |
| พื้นฐาน | `Foundations.dc.html` | สี ตัวอักษร ระยะห่าง มุมโค้ง เงา |
| Components | `CompForms.dc.html` | ปุ่ม ช่องกรอก ตัวเลือก |
| | `CompData.dc.html` | ป้ายสถานะ การ์ด ลำดับจุดส่ง |
| | `CompNav.dc.html` | แถบนำทาง toast dialog สถานะว่าง |
| หน้าจอหลัก | `Main.dc.html` | `OrdersManagePage` |
| | `OrdersSelect.dc.html` | `OrdersManagePage` (โหมดเลือกเพื่อยกเลิก) |
| | `OrderForm.dc.html` | `OrderFormModal` → bottom sheet |
| | `Jobs.dc.html` | `ManageDeliveryPage` (รายการ) |
| | `JobDetail.dc.html` | `ManageDeliveryPage` (รายละเอียด + ยืนยันส่ง) |
| | `AddJob.dc.html` | `AddJobPage` |
| Pop-ups | `PopCancel`, `PopDeleteJob`, `PopApiError`, `PopUnsaved` | กล่องยืนยัน / แจ้งผิดพลาด |
| | `PopCompleteStop`, `PopFilter`, `PopModePicker`, `PopMap` | bottom sheet |
| | `PopLocation`, `PopToast`, `PopOffline`, `PopLoading` | เลือกพื้นที่ / toast / โหลด |
| | `Backdrop.dc.html` | พื้นหลังจำลองที่ pop-up ใช้ |
| Navbar | `NavMobile.dc.html`, `NavBar.dc.html` | เมนูล่าง (มือถือ) |
| | `NavDesktop.dc.html` | แถบด้านซ้าย (≥ 992px) |
| | `Account.dc.html` | หน้าบัญชี |
| Login | `LoginStates.dc.html`, `LoginMobile.dc.html` | `LoginPage` (มือถือ 3 สถานะ) |
| | `LoginDesktop.dc.html` | `LoginPage` (จอกว้าง) |

`canvas.json` = ตำแหน่งและชื่อของแต่ละบอร์ดบน canvas
