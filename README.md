# SD4 - Mass Sales Order Processing & Auto Delivery Cockpit

![SAP ABAP](https://img.shields.io/badge/SAP-ABAP-blue.svg)
![Module](https://img.shields.io/badge/Module-SD-orange.svg)
![Status](https://img.shields.io/badge/Status-Development-green.svg)

## 📖 Introduction (Giới thiệu)

**SD4 Mass Processing Cockpit** là giải pháp tối ưu hóa quy trình Order-to-Cash (O2C) trên hệ thống SAP. Chương trình cung cấp giao diện tập trung (Unified Cockpit) thay thế các T-code tiêu chuẩn (VA01, VA02, VA03), cho phép người dùng tạo đơn hàng thủ công hoặc tải lên hàng loạt từ Excel, đồng thời tự động hóa quy trình tạo Delivery và Picking ngay lập tức.

## 🚀 Key Features (Tính năng chính)

### 1. Input & Validation (Đầu vào & Kiểm tra)
* **Single Order Entry:** Màn hình nhập liệu đơn lẻ với giao diện thân thiện, hỗ trợ tìm kiếm (F4) và validate dữ liệu master data theo thời gian thực.
* **Mass Processing (Excel Upload):**
    * Hỗ trợ upload file Excel cấu trúc chuẩn (Header, Item, Condition).
    * Cơ chế **Validate & Error Handling** ngay trên màn hình ALV: Tô đỏ dòng lỗi, hiển thị log chi tiết.
    * **In-line Editing:** Cho phép sửa lỗi dữ liệu trực tiếp trên lưới ALV và Re-validate mà không cần upload lại file.
    * **Single Shipping Point Check:** Đảm bảo tính nhất quán dữ liệu cho quy trình tự động.

### 2. Process Automation (Tự động hóa)
* **Auto Creation:** Sử dụng BAPI chuẩn (`BAPI_SALESORDER_CREATEFROMDAT2`) để tạo Sales Order.
* **Auto Delivery Execution:** Tự động kích hoạt tạo Outbound Delivery ngay khi SO được tạo thành công (Status Complete).
* **Auto Picking:** Tự động thực hiện Pick hàng (Set Picked Qty = Delivery Qty) thông qua `WS_DELIVERY_UPDATE`.
* **Incomplete Handling:** Quy trình xử lý thông minh cho các đơn hàng thiếu dữ liệu (Incomplete SO) -> Cho phép bổ sung và tự động chạy tiếp Delivery sau khi fix.

### 3. Tracking & Actions Cockpit (Theo dõi & Xử lý)
* **Real-time Monitoring:** Báo cáo trạng thái đơn hàng theo thời gian thực (Order $\rightarrow$ Delivery $\rightarrow$ PGI $\rightarrow$ Billing).
* **Quick Actions:** Thực hiện các bước Logistics/Finance chỉ với 1 cú click chuột:
    * Post Goods Issue (PGI).
    * Create Billing Document.
    * Reverse PGI / Cancel Billing (Hỗ trợ luồng đảo ngược).
* **Background Job Support:** Hỗ trợ chạy ngầm (Background Job) cho các file dữ liệu lớn để tránh Time-out.

---

## 🛠️ Technical Architecture (Kiến trúc kỹ thuật)

### Prerequisites (Yêu cầu hệ thống)
* **SAP GUI Version:** SAP Logon 800
* **SAP Basis:** 757
* **Configuration:** Cần cấu hình chuẩn cho Shipping Point Determination (OVL2) và Copy Control (VTLA).

### Main Objects (Các đối tượng chính)
| Object Type | Name | Description |
| :--- | :--- | :--- |
| **Program** | `ZSD4_MASS_PROC` | Chương trình chính (Main Executable). |
| **Tables** | `ZTB_SO_UPLOAD_HD` | Bảng lưu trữ Header (Staging). |
| | `ZTB_SO_UPLOAD_IT` | Bảng lưu trữ Item (Staging). |
| | `ZTB_SO_ERROR_LOG` | Bảng lưu trữ lịch sử lỗi. |
| **Class** | `ZCL_SD_MASS_VALIDATOR` | Class xử lý logic validate dữ liệu. |
| **Include** | `ZSD4_TOP`, `ZSD4_F01` | Khai báo biến và Subroutines. |

---

## 📦 Installation & Setup (Cài đặt)

Dự án này được quản lý bằng **abapGit**.

1.  Cài đặt [abapGit](https://github.com/abapGit/abapGit) trên hệ thống SAP của bạn.
2.  Mở T-code `ZABAPGIT`.
3.  Chọn **New Online** và dán URL repository này vào.
4.  Thực hiện **Pull** để kéo toàn bộ source code về hệ thống.
5.  Active toàn bộ objects (Lưu ý: Active Tables và Domains trước).

---

## 📖 Usage Guide (Hướng dẫn sử dụng)

1.  **Chạy chương trình:** T-code `ZSD4` (hoặc chạy Program `ZSD4_MASS_PROC` trong SE38).
2.  **Chọn chế độ:**
    * *Tab Single Entry:* Nhập thông tin đơn lẻ và bấm Save.
    * *Tab Mass Upload:* Chọn file Excel mẫu -> Bấm Upload.
3.  **Xử lý trên ALV:**
    * Kiểm tra các dòng bị tô đỏ (Lỗi).
    * Click vào dòng lỗi để xem chi tiết hoặc sửa trực tiếp trên màn hình.
    * Bấm **"Revalidate"** để kiểm tra lại.
4.  **Thực thi:**
    * Bấm **"Create SO"** để hệ thống chạy quy trình tự động.
    * Chuyển sang tab **"Tracking"** để theo dõi trạng thái và thực hiện Billing/PGI.

---

## 🤝 Contributing

* **Developer:** [Tên của bạn]
* **Module:** SAP SD
* **Last Update:** December 2025

---
