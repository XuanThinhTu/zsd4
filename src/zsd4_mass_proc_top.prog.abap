*&---------------------------------------------------------------------*
*& Include          ZSD4_MASS_PROC_TOP
*&---------------------------------------------------------------------*

TYPE-POOLS: slis.
TYPE-POOLS: BAPISD.

* Global Variables
DATA: gv_upload_type     TYPE c LENGTH 1,  " S = Single, M = Mass
      gv_management_type TYPE c LENGTH 1.  " T = Tracking, R = Report

DATA: gv_single_mode TYPE char10. " Biến chứa chế độ: 'CREATE' hoặc 'EDIT'
DATA: gv_data_saved  TYPE char1.  " Cờ báo hiệu: 'X' nếu Save thành công, '' nếu thất bại

DATA: gv_order_type TYPE auart. " Biến lưu loại đơn hàng (ZORR, ZFOC...)

" --- Biến Đếm cho Validation Summary (MỚI) ---
DATA: gv_cnt_val_ready   TYPE i, " Đếm số dòng Ready trong tab Validated
      gv_cnt_val_incomp  TYPE i, " Đếm số dòng Incomplete trong tab Validated
      gv_cnt_val_err     TYPE i, " Đếm số dòng Error trong tab Validated

      gv_cnt_suc_comp    TYPE i, " Đếm số dòng Complete trong tab Success
      gv_cnt_suc_incomp  TYPE i, " Đếm số dòng Incomplete trong tab Success

      gv_cnt_fail_err    TYPE i. " Đếm số dòng Error trong tab Failed

" --- Biến Tổng (Nếu cần dùng để hiện Total) ---
DATA: gv_cnt_h_tot       TYPE i,
      gv_cnt_i_tot       TYPE i,
      gv_cnt_c_tot       TYPE i.

" 2. Item Counts (Chi tiết - dùng để tính tổng)
DATA: gv_cnt_i_val       TYPE i,
      gv_cnt_i_suc       TYPE i,
      gv_cnt_i_fail      TYPE i.

" 3. Condition Counts (Chi tiết - dùng để tính tổng)
DATA: gv_cnt_c_val       TYPE i,
      gv_cnt_c_suc       TYPE i,
      gv_cnt_c_fail      TYPE i.

DATA: go_docking_summary TYPE REF TO cl_gui_docking_container. " <--- DÙNG CÁI NÀY

* Radio button flags
DATA: rb_single  TYPE abap_bool,
      rb_mass    TYPE abap_bool,
      rb_status  TYPE abap_bool,
      rb_remon  TYPE abap_bool.

DATA gv_req_id TYPE zsd_req_id.
DATA: gv_data_loaded    TYPE abap_bool.
DATA: gv_current_req_id TYPE ZSD_REQ_ID. " Biến toàn cục lưu ID của lần upload hiện tại

*DATA: go_splitter_alv   TYPE REF TO cl_gui_splitter_container, " <<< THÊM CÁI NÀY
*      go_tabstrip       TYPE REF TO cl_gui_tabstrip.           " <<< THÊM CÁI NÀY (Nếu dùng OO Tabstrip)

*DATA: s_vbak TYPE vbak.
DATA: gs_so_heder_ui TYPE zstr_so_heder_ui.

* OK_CODE
DATA:      OK_CODE TYPE SY-UCOMM.

* QUICK TIPS for 0100 PBO.
DATA: lt_tips    TYPE STANDARD TABLE OF string,
      tip_text   TYPE string.
* HELLO in QUICK TIPS
DATA: gv_hello_text TYPE string.



* Screen State (status for screen)
DATA: gv_screen_state TYPE c VALUE '0'. " 0=Mới vào, 1=Đã nhập Sold-to

DATA: gv_so_just_created TYPE abap_bool. " Cờ: 'X' = Vừa tạo SO thành công

*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_MAIN'
CONSTANTS: BEGIN OF C_TS_MAIN,
             TAB1 LIKE SY-UCOMM VALUE 'TS_MAIN_FC1',
             TAB2 LIKE SY-UCOMM VALUE 'TS_MAIN_FC2',
*             TAB3 LIKE SY-UCOMM VALUE 'TS_MAIN_FC3',
           END OF C_TS_MAIN.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_MAIN'
CONTROLS:  TS_MAIN TYPE TABSTRIP.
DATA:      BEGIN OF G_TS_MAIN,
             SUBSCREEN   LIKE SY-DYNNR,
             PROG        LIKE SY-REPID VALUE 'ZSD4_MASS_PROC',
             PRESSED_TAB LIKE SY-UCOMM VALUE C_TS_MAIN-TAB1,
           END OF G_TS_MAIN.

" Dùng 1 biến global để check chạy lần đầu
DATA: gv_first_run TYPE c VALUE 'X'.

*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_VALI'
CONSTANTS: BEGIN OF C_TS_VALI,
             TAB1 LIKE SY-UCOMM VALUE 'TS_VALI_FC1',
             TAB2 LIKE SY-UCOMM VALUE 'TS_VALI_FC2',
             TAB3 LIKE SY-UCOMM VALUE 'TS_VALI_FC3',
           END OF C_TS_VALI.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_VALI'
CONTROLS:  TS_VALI TYPE TABSTRIP.
DATA:      BEGIN OF G_TS_VALI,
             SUBSCREEN   LIKE SY-DYNNR,
             PROG        LIKE SY-REPID VALUE 'ZSD4_MASS_PROC',
             PRESSED_TAB LIKE SY-UCOMM VALUE C_TS_VALI-TAB1,
           END OF G_TS_VALI.


"ThangNB new transfer code

"---------------------------------CONSTANT DECLARATION AND CLASS DEFINITION------------------------------
"====================[ Constants dùng chung ]==========================
CONSTANTS:
  gc_sheet_header TYPE string  VALUE 'Header',
  gc_sheet_item   TYPE string  VALUE 'Item',
  gc_status_comp  TYPE char20  VALUE 'Complete',
  gc_status_err   TYPE char20  VALUE 'Error',
  gc_status_new   TYPE char20  VALUE 'New',
  gc_fc_check     TYPE syucomm VALUE 'CHECK',
  gc_fc_save      TYPE syucomm VALUE 'SAVE',
  gc_fc_crea      TYPE syucomm VALUE 'CREA',
  gc_fc_exit      TYPE syucomm VALUE 'EXIT',
  gc_icon_red     TYPE icon-name VALUE 'ICON_LED_RED',
  gc_icon_yellow  TYPE icon-name VALUE 'ICON_LED_YELLOW',
  gc_icon_green   TYPE icon-name VALUE 'ICON_LED_GREEN'.

CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING
          io_grid  TYPE REF TO cl_gui_alv_grid
          it_table TYPE REF TO data,
      handle_user_command
        FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      handle_toolbar
        FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      handle_data_changed
        FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING
          er_data_changed,
      handle_data_changed_finished
        FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING
          e_modified
          et_good_cells,
      " <<< THÊM 2 DÒNG NÀY VÀO >>>
      handle_hotspot_click
        FOR EVENT hotspot_click OF cl_gui_alv_grid
        IMPORTING e_row_id e_column_id es_row_no.
  PRIVATE SECTION.
    DATA:
      mo_grid  TYPE REF TO cl_gui_alv_grid,
      mt_table TYPE REF TO data.
ENDCLASS.

"--------------------------------------TYPES STRUCTURES---------------------------------------
*--- Error Structure ---

TYPES: BEGIN OF ty_validation_error,
         temp_id   TYPE char10,         " Link to Header/Item
         item_no   TYPE posnr_va,       " Item Number (blank for header errors)
         fieldname TYPE fieldname,      " Field causing the error
         message   TYPE string,         " Error message text
       END OF ty_validation_error.

*--- Error Table Type ---
TYPES: ty_t_validation_error TYPE STANDARD TABLE OF ty_validation_error WITH EMPTY KEY. " <<< ADD THIS LINE

TYPES: BEGIN OF ty_header.
         INCLUDE TYPE ztb_so_upload_hd. " Bảng Header Staging
  TYPES: icon     TYPE icon-internal,   " Đèn tín hiệu (Xanh/Đỏ/Vàng)
         celltab  TYPE lvc_t_scol,      " Tô màu từng ô (Cell Color)
         rowcolor TYPE char4,           " Tô màu cả dòng (Row Color)
         err_btn  TYPE icon-internal,
       END OF ty_header.
       TYPES ty_t_header TYPE STANDARD TABLE OF ty_header WITH DEFAULT KEY.

TYPES: BEGIN OF ty_item.
         INCLUDE TYPE ztb_so_upload_it. " Bảng Item Staging
  TYPES: icon     TYPE icon-internal,
         celltab  TYPE lvc_t_scol,
         rowcolor TYPE char4,
         err_btn  TYPE icon-internal,
       END OF ty_item.
       TYPES ty_t_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

" 1. Định nghĩa cấu trúc hiển thị ALV cho Condition
TYPES: BEGIN OF ty_condition.
         INCLUDE TYPE ztb_so_upload_pr. " (Bảng Z Pricing của bạn)
  TYPES: icon     TYPE icon-internal,
         rowcolor TYPE char4,
         celltab  TYPE lvc_t_scol,
         err_btn  TYPE icon-internal,
       END OF ty_condition.

" 3. Khai báo Bảng Nội bộ (Internal Tables) cho 3 Tab Mới
" --- Tab 1: Validated (Chờ xử lý) ---
DATA: gt_hd_val TYPE TABLE OF ty_header,
      gt_it_val TYPE TABLE OF ty_item,
      gt_pr_val TYPE TABLE OF ty_condition.

" --- Tab 2: Posted Success (Thành công) ---
DATA: gt_hd_suc TYPE TABLE OF ty_header,
      gt_it_suc TYPE TABLE OF ty_item,
      gt_pr_suc TYPE TABLE OF ty_condition.

" --- Tab 3: Posted Failed (Thất bại) ---
DATA: gt_hd_fail TYPE TABLE OF ty_header,
      gt_it_fail TYPE TABLE OF ty_item,
      gt_pr_fail TYPE TABLE OF ty_condition.


" 4. Khai báo ALV Grid Objects (9 Grids cho 3 Tab x 3 Bảng)
" --- Tab 1: Validated ---
DATA: go_grid_hdr_val TYPE REF TO cl_gui_alv_grid,
      go_grid_itm_val TYPE REF TO cl_gui_alv_grid,
      go_grid_cnd_val TYPE REF TO cl_gui_alv_grid.

" --- Tab 2: Success ---
DATA: go_grid_hdr_suc TYPE REF TO cl_gui_alv_grid,
      go_grid_itm_suc TYPE REF TO cl_gui_alv_grid,
      go_grid_cnd_suc TYPE REF TO cl_gui_alv_grid.

" --- Tab 3: Failed ---
DATA: go_grid_hdr_fail TYPE REF TO cl_gui_alv_grid,
      go_grid_itm_fail TYPE REF TO cl_gui_alv_grid,
      go_grid_cnd_fail TYPE REF TO cl_gui_alv_grid.


" 5. Khai báo Event Handler Objects (Để bắt sự kiện Click/Change)
" --- Tab 1: Validated ---
DATA: go_event_hdr_val TYPE REF TO lcl_event_handler,
      go_event_itm_val TYPE REF TO lcl_event_handler,
      go_event_cnd_val TYPE REF TO lcl_event_handler.

" --- Tab 2: Success (Thường chỉ cần Header click) ---
DATA: go_event_hdr_suc TYPE REF TO lcl_event_handler,
      go_event_itm_suc TYPE REF TO lcl_event_handler,
      go_event_cnd_suc TYPE REF TO lcl_event_handler.

" --- Tab 3: Failed ---
DATA: go_event_hdr_fail TYPE REF TO lcl_event_handler,
      go_event_itm_fail TYPE REF TO lcl_event_handler,
      go_event_cnd_fail TYPE REF TO lcl_event_handler.


" 6. Khai báo Container (Để chứa ALV)
DATA: go_cont_val  TYPE REF TO cl_gui_custom_container, " Tab Validated
      go_cont_suc  TYPE REF TO cl_gui_custom_container, " Tab Success
      go_cont_fail TYPE REF TO cl_gui_custom_container. " Tab Failed

TYPES: BEGIN OF ty_item_details.
         " 1. Bao gồm tất cả các trường từ Z-table
         INCLUDE TYPE ZTB_SO_ITEM_SING.
         " 2. Thêm các trường ALV-helper (không có trong DB)
  TYPES:   icon        TYPE icon-internal,
           status_code TYPE c LENGTH 1,
           status_text TYPE char20,
           message     TYPE string,
           style       TYPE lvc_t_styl,
           celltab     TYPE lvc_t_scol, " Bảng màu cho ô
           rowcolor    TYPE char4.      " Màu cho dòng
TYPES: END OF ty_item_details.

TYPES ty_t_item_details TYPE STANDARD TABLE OF ty_item_details WITH DEFAULT KEY.

" --- [SỬA] Cấu trúc cho ALV Conditions (Giống Item Details) ---
TYPES: BEGIN OF ty_cond_alv.
        " --- A. Các trường lấy từ Database (ZTB_SO_COND_SING) ---
        INCLUDE TYPE ztb_so_cond_sing.
        " (Gồm: REQ_ID, ITEM_NO, KSCHL, AMOUNT, WAERS, KPEIN, KMEIN...)

        " --- B. Các trường bổ sung cho logic tính toán & hiển thị ---
        TYPES:
          kwert       TYPE kwert,        " [QUAN TRỌNG] Thành tiền (Amount * Qty)

          " --- C. Các trường Helper của ALV ---
          icon        TYPE icon-internal,
          status_code TYPE c LENGTH 1,
          status_text TYPE char20,
          message     TYPE string,

          cell_style  TYPE lvc_t_styl,   " [ĐỔI TÊN]: Từ 'style' -> 'cell_style' để khớp logic code
          celltab     TYPE lvc_t_scol,   " Màu ô
          rowcolor    TYPE char4.        " Màu dòng
TYPES: END OF ty_cond_alv.
TYPES: ty_t_cond_alv TYPE STANDARD TABLE OF ty_cond_alv WITH DEFAULT KEY.

DATA: gt_conditions_alv     TYPE ty_t_cond_alv. " (Bảng này giờ đã đúng)
DATA: gt_fieldcat_conds     TYPE lvc_t_fcat.

DATA: gt_fcat_header TYPE lvc_t_fcat,
      gt_fcat_item   TYPE lvc_t_fcat,
      gt_fcat_cond   TYPE lvc_t_fcat. " [MỚI] Cho Condition


" 1. Định nghĩa kiểu dữ liệu cho bảng Cache
TYPES: BEGIN OF ty_cond_cache,
         item_no    TYPE posnr_va,      " Khóa chính: Số Item
         conditions TYPE ty_t_cond_alv,  " Bảng chứa các dòng Condition (ZPRQ, ZDRP...)
       END OF ty_cond_cache.

" 2. Khai báo biến Global
DATA: gt_cond_cache TYPE HASHED TABLE OF ty_cond_cache
                    WITH UNIQUE KEY item_no.

*===== Raw & globals =====
TYPES: BEGIN OF ty_rawdata,
         data TYPE string,
       END OF ty_rawdata.

*======================================================================
*==  STAGING TABLE: Combine Header + Item for Mass SO Creation       ==
*======================================================================
TYPES: BEGIN OF ty_staging,
         temp_id        TYPE char10,          "Link header & item
         sales_org      TYPE vbak-vkorg,
         dist_chnl      TYPE vbak-vtweg,
         division       TYPE vbak-spart,
         sold_to_party  TYPE vbak-kunnr,
         ship_to_party  TYPE vbak-kunnr,
         cust_ref       TYPE vbak-bstnk,
         req_date       TYPE vbak-vdatu,
         order_type     TYPE auart,
         currency       TYPE waers,

         item_no        TYPE posnr_va,
         matnr          TYPE matnr,
         short_text     TYPE arktx,
         qty            TYPE kwmeng,
         uom            TYPE vrkme,
         plant          TYPE werks_d,
         store_loc      TYPE lgort_d,
         cond_type      TYPE konwa,
         cond_value     TYPE kbetr,
END OF ty_staging.

*======================================================================
*==  RESULT TABLE: Display SO Creation Summary                       ==
*======================================================================
TYPES: BEGIN OF ty_result,
         temp_id   TYPE char10,       " <<< THÊM TRƯỜNG NÀY
         vbeln     TYPE vbak-vbeln,   "Sales Doc
         vkorg     TYPE vbak-vkorg,
         vtweg     TYPE vbak-vtweg,
         spart     TYPE vbak-spart,
         sold_to   TYPE vbak-kunnr,
         ship_to   TYPE vbak-kunnr,
         bstkd     TYPE vbak-bstnk,
         req_date  TYPE vbak-vdatu,
         qty       TYPE i,
         volume    TYPE wrbtr,
         status    TYPE char20,
         message   TYPE string,
END OF ty_result.

TYPES: BEGIN OF ty_delivery_result,
         vbeln_vl   TYPE likp-vbeln,   " Delivery number
         vbeln_va   TYPE vbak-vbeln,   " Sales Order
         vkorg      TYPE vbak-vkorg,
         vtweg      TYPE vbak-vtweg,
         spart      TYPE vbak-spart,
         kunnr      TYPE vbak-kunnr,
         lfart      TYPE likp-lfart,
         wadat_ist  TYPE likp-wadat_ist, " Planned GI Date
         status     TYPE char20,
         message    TYPE string,
END OF ty_delivery_result.

*===== VA05-like line =====
TYPES: BEGIN OF ty_va05,
         cust_ref   TYPE vbak-bstnk,   " Customer Reference
         doc_date   TYPE dats,         " Document Date
         doc_type   TYPE auart,        " Sales Doc. Type
         vbeln      TYPE vbak-vbeln,   " Sales Document
         posnr      TYPE posnr_va,     " Item
         sold_to    TYPE vbak-kunnr,   " Sold-to party
         matnr      TYPE vbap-matnr,   " Material
         qty        TYPE kwmeng,       " Order Qty
         uom        TYPE vrkme,        " Sales Unit
         netwr      TYPE wrbtr,        " Net value (Item)
         waerk      TYPE waers,        " Doc. Currency
         status     TYPE char20,       " CREATED / INCOMPLETE (từ Z)
END OF ty_va05.

*===== Delivery Tab Data Type (Extended for Checkbox + Message) =====
TYPES: BEGIN OF ty_delivery_ext,
         sel         TYPE char1,            " Checkbox for ALV
         vbeln_so    TYPE vbak-vbeln,       " Sales Order
         vbeln_dlv   TYPE likp-vbeln,       " Delivery
         vkorg       TYPE vbak-vkorg,       " Sales Org
         vtweg       TYPE vbak-vtweg,       " Dist. Channel
         spart       TYPE vbak-spart,       " Division
         kunnr_sold  TYPE vbak-kunnr,       " Sold-to Party
         kunnr_ship  TYPE vbak-kunnr,       " Ship-to Party
         bstkd       TYPE vbak-bstnk,       " Customer Reference
         lfart       TYPE likp-lfart,       " Delivery Type
         erdat       TYPE likp-erdat,       " Created Date
         ernam       TYPE likp-ernam,       " Created By
         status      TYPE char20,           " Status
         message     TYPE string,           " Message (for PGI result)
END OF ty_delivery_ext.

*---------------------------------------------------------------------*
* Sales Document Management (Screen 0400)
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_doc_display,
         sel                 TYPE char1,       " Checkbox
         process_phase       TYPE char30,
         vbeln_so            TYPE vbak-vbeln,
         vbeln_dl            TYPE likp-vbeln,
         vbeln_bi            TYPE vbrk-vbeln,
         auart               TYPE vbak-auart,
         erdat               TYPE vbak-erdat,
         vkorg               TYPE vbak-vkorg,
         vtweg               TYPE vbak-vtweg,
         spart               TYPE vbak-spart,
         kunnr               TYPE vbak-kunnr,
         netwr               TYPE vbak-netwr,
         waerk               TYPE vbak-waerk,
         vdatu               TYPE vbep-edatu,
END OF ty_doc_display.



" <<< THÊM 2 DÒNG NÀY VÀO CUỐI PHẦN TYPES >>>
" --- Cấu trúc cho Popup Incompletion Log (Giống pophinh6.png) ---
TYPES: BEGIN OF ty_incomp_log,
         group_desc TYPE text40,
         cell_cont  TYPE text40,
       END OF ty_incomp_log.
TYPES: ty_t_incomp_log TYPE STANDARD TABLE OF ty_incomp_log WITH DEFAULT KEY.


*& Biến Global cho Screen 300 (PGI Details)
*&---------------------------------------------------------------------*
" 1. Structure Header (Giữ nguyên)
DATA: gs_pgi_detail_ui TYPE zsd4_pgi_detail_ui.

" --- THÊM DÒNG NÀY ---
DATA: gs_pgi_process_ui TYPE zstr_pgi_process_ui. " Structure cho Tab 2
" --- KẾT THÚC THÊM ---

" 2. Cấu trúc ALV Tab 1 "All Items" (Dùng ZTB_PGI_ALL_ITEM)
TYPES: BEGIN OF ty_pgi_all_items.
         INCLUDE TYPE ztb_pgi_all_item. " <<< Dùng tên bảng của bạn
  TYPES:   icon        TYPE icon-internal,
           status_code TYPE c LENGTH 1,
           message     TYPE string,
           style       TYPE lvc_t_styl.
TYPES: END OF ty_pgi_all_items.
TYPES: ty_t_pgi_all_items TYPE STANDARD TABLE OF ty_pgi_all_items
                               WITH DEFAULT KEY.

" <<< THÊM MỚI: Cấu trúc cho Validation Template Excel >>>
TYPES: BEGIN OF ty_excel_column,
         col_id   TYPE char2,  " 'A', 'B', 'C'...
         col_name TYPE string, " '*Sales Order Type'
       END OF ty_excel_column.
TYPES: ty_t_excel_column TYPE STANDARD TABLE OF ty_excel_column
                               WITH DEFAULT KEY.

"-------------------------------------------------------------------------------------
"-------------------------DATA AND GLOBAL TABLE DECLARATION--------------------------
*--- Raw data
DATA: gs_rawdata TYPE ty_rawdata,
      gt_rawdata TYPE STANDARD TABLE OF ty_rawdata.

" <<< THÊM 2 DÒNG NÀY ĐỂ XỬ LÝ POPUP EXIT >>>
DATA: gv_orig_ucomm   TYPE sy-ucomm. " Lưu lệnh gốc (BACK, EXIT)
DATA: gv_popup_action TYPE c.      " Lưu kết quả popup (SAVE, BACK, STAY)



*--- ALV Grid Tables (Screen 0100 trong bài cũ -> Screen 0200 trong bài mới)
DATA: gs_so_header TYPE ty_header,
      gt_so_header TYPE ty_t_header,
      gs_so_item   TYPE ty_item,
      gt_so_item   TYPE ty_t_item.



DATA: gt_item_details TYPE ty_t_item_details. " <<< THÊM DÒNG NÀY

*--- Staging (for BAPI)
DATA: gt_staging TYPE STANDARD TABLE OF ty_staging,
      gs_staging TYPE ty_staging.

*--- Result Tables (SO Creation + Delivery)
DATA: gt_result TYPE STANDARD TABLE OF ty_result,
      gs_result TYPE ty_result.
DATA: gt_delivery_result TYPE STANDARD TABLE OF ty_delivery_result,
      gs_delivery_result TYPE ty_delivery_result.

*--- VA05 - Status Screen
DATA: gt_va05_all       TYPE STANDARD TABLE OF ty_va05,
      gt_va05_created   TYPE STANDARD TABLE OF ty_va05,
      gt_va05_incomp    TYPE STANDARD TABLE OF ty_va05.

*--- Delivery Processing (PGI)
DATA: gt_delivery TYPE STANDARD TABLE OF ty_delivery_ext,
      gs_delivery TYPE ty_delivery_ext.
DATA: gt_deliv_pgi TYPE STANDARD TABLE OF ty_delivery_ext,
      gs_deliv_pgi TYPE ty_delivery_ext.

*--- Doc Management
DATA: gt_doc_display TYPE STANDARD TABLE OF ty_doc_display,
      gs_doc_display TYPE ty_doc_display.

" Có thể bạn cũng cần bảng Complete riêng, thay vì dùng gt_so_header/item chung
DATA: gt_so_header_comp TYPE ty_t_header, " For Complete tab (optional)
      gt_so_item_comp   TYPE ty_t_item.
"--------------------------------------------------------------------------------------------

"------------------------------------------------------------------------------------------
"---------------------------------GLOBAL ALV DATA DECLARATION------------------------------
*--- ALV Objects (Screen 0200 - Validation)
DATA: go_grid_hdr TYPE REF TO cl_gui_alv_grid, "Đổi tên thành go_grid_hdr cho rõ
      go_grid_item TYPE REF TO cl_gui_alv_grid, "Đổi tên thành go_grid_item cho rõ
      go_event_hdr TYPE REF TO lcl_event_handler,
      go_event_item TYPE REF TO lcl_event_handler.
DATA: gt_fieldcat_head TYPE lvc_t_fcat,
      gt_fieldcat_item TYPE lvc_t_fcat.


"----------------------ALV TAB-----------------------------------------------
DATA: go_grid_hdr_incomp    TYPE REF TO cl_gui_alv_grid,
      go_event_hdr_incomp   TYPE REF TO lcl_event_handler,
      go_grid_item_incomp   TYPE REF TO cl_gui_alv_grid,
      go_event_item_incomp  TYPE REF TO lcl_event_handler,
      go_grid_hdr_err       TYPE REF TO cl_gui_alv_grid,
      go_event_hdr_err      TYPE REF TO lcl_event_handler,
      go_grid_item_err      TYPE REF TO cl_gui_alv_grid,
      go_event_item_err     TYPE REF TO lcl_event_handler.

DATA: gt_so_header_incomp TYPE ty_t_header, " For Incomplete tab
      gt_so_item_incomp   TYPE ty_t_item,
      gt_so_header_err    TYPE ty_t_header, " For Error tab
      gt_so_item_err      TYPE ty_t_item.

*--- ALV Objects (Screen 0200 - Result Tab)
DATA: go_grid_res       TYPE REF TO cl_gui_alv_grid,
      gt_fieldcat_res   TYPE lvc_t_fcat.

DATA: go_grid_item_single     TYPE REF TO cl_gui_alv_grid.
DATA: go_cont_item_single    TYPE REF TO cl_gui_custom_container. " <<< THÊM DÒNG NÀY
DATA: gt_fieldcat_item_single TYPE lvc_t_fcat.
DATA: go_event_handler_single TYPE REF TO lcl_event_handler. " <<< THÊM DÒNG NÀY

" --- THÊM MỚI: Biến cho Tab Monitoring (Screen 600) ---
DATA: go_cont_monitoring      TYPE REF TO cl_gui_custom_container,
      go_grid_monitoring      TYPE REF TO cl_gui_alv_grid,
      go_event_handler_moni   TYPE REF TO lcl_event_handler.

" --- Bảng dữ liệu (dùng structure Z của bạn) ---
DATA: gt_monitoring_data TYPE STANDARD TABLE OF zsd4_so_monitoring.
DATA: gt_fieldcat_monitoring TYPE lvc_t_fcat.

" --- THÊM MỚI: Biến cho Tab Conditions (Screen 0113) ---
DATA: gv_current_item_idx     TYPE sy-tabix VALUE 1, " Con trỏ item (1, 2, 3...)
      go_cont_conditions      TYPE REF TO cl_gui_custom_container,
      go_grid_conditions      TYPE REF TO cl_gui_alv_grid,
      go_event_handler_conds  TYPE REF TO lcl_event_handler.

*--- ALV Objects (FOR POPUP) ---
DATA: gt_fieldcat_popup TYPE slis_t_fieldcat_alv. " <<< THÊM MỚI: Biến riêng cho popup

*--- ALV Objects (Screen 0200 - VA05 Tabs)
DATA: go_grid_all     TYPE REF TO cl_gui_alv_grid,
      go_grid_created TYPE REF TO cl_gui_alv_grid,
      go_grid_incomp  TYPE REF TO cl_gui_alv_grid.
DATA: gt_fcat_va05 TYPE lvc_t_fcat,
      gs_layo_va05 TYPE lvc_s_layo.

*--- ALV Objects (Screen 021x - PGI/Delivery)
DATA: go_grid_deliv TYPE REF TO cl_gui_alv_grid.
DATA: go_cont_pgi TYPE REF TO cl_gui_custom_container,
      go_grid_pgi TYPE REF TO cl_gui_alv_grid.


" 4. Biến Global (Data + ALV Objects)
DATA: gt_pgi_all_items   TYPE ty_t_pgi_all_items,
      gt_fieldcat_pgi_all  TYPE lvc_t_fcat,
      go_cont_pgi_all      TYPE REF TO cl_gui_custom_container,
      go_grid_pgi_all      TYPE REF TO cl_gui_alv_grid,
      go_event_pgi_all     TYPE REF TO lcl_event_handler.

DATA: gv_pgi_edit_mode TYPE abap_bool. " 'X' = Change, ' ' = Display
DATA: lt_lips_global TYPE TABLE OF lips. " <<< THÊM DÒNG NÀY

DATA: gv_filepath TYPE rlgrap-filename. " Variable for Screen 0120 file path field P_FILE

"-----------------------------------------------------------------------------------------
"---------------------------------------------HELPER DATA---------------------------------
DATA: gv_mode   TYPE string.
DATA: gs_edit TYPE abap_bool. " 'X' = Change Mode, ' ' = Display Mode
DATA: gv_flag_header TYPE abap_bool VALUE abap_true,
      gv_flag_item   TYPE abap_bool VALUE abap_true,
      gv_grid_title  TYPE lvc_title,
      gs_layout      TYPE lvc_s_layo,
      gs_variant     TYPE disvariant,
      gt_exclude     TYPE ui_functions,
      gt_sort        TYPE lvc_t_sort,
      gt_filter      TYPE lvc_t_filt,
      gt_fieldcat    TYPE lvc_t_fcat.

" --- 1. Biến Filter (Tên phải khớp 100% với Screen Painter) ---
" (SAP tự động gán tên biến từ Screen Painter,
"  bạn cần khai báo chúng ở đây với cùng tên và kiểu)
DATA:
  FROM_DAT  TYPE dats,       " From Date
  TO_DAT    TYPE dats,       " To Date
  SALES_ORD TYPE vbeln_va,   " Sales Order
  SOLD_TO   TYPE kunnr,      " Sold-to-Party
  MATERIAL  TYPE matnr,      " Material
  SALE_ORG  TYPE vkorg,      " Sales Org.
  DIST_CHAN TYPE vtweg,      " Dist Channel
  DIVI      TYPE spart,      " Division
  STATUS    TYPE char20.     " Status (Filter)

" --- 2. Biến Output (Cho 3 trường tổng ở cuối màn hình) ---
DATA:
  TO_STA TYPE char20,   " Status (Summary)
  TOSO   TYPE int4,        " Total Sales Order
  TO_VAL TYPE netwr.    " Total Net Value

DATA: gv_monitor_first_load TYPE abap_bool VALUE abap_true.


*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_PGI'
CONSTANTS: BEGIN OF C_TS_PGI,
             TAB1 LIKE SY-UCOMM VALUE 'TS_PGI_FC1',
             TAB2 LIKE SY-UCOMM VALUE 'TS_PGI_FC2',
           END OF C_TS_PGI.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_PGI'
CONTROLS:  TS_PGI TYPE TABSTRIP.
DATA:      BEGIN OF G_TS_PGI,
             SUBSCREEN   LIKE SY-DYNNR,
             PROG        LIKE SY-REPID VALUE 'ZSD4_MASS_PROC',
             PRESSED_TAB LIKE SY-UCOMM VALUE C_TS_PGI-TAB1,
           END OF G_TS_PGI.



*TYPES: BEGIN OF ty_tracking,
*         process_phase      TYPE char30,
*         sales_document     TYPE vbak-vbeln,
*         delivery_document  TYPE likp-vbeln,
*         billing_document   TYPE vbrk-vbeln,
*         order_type         TYPE vbak-auart,
*         document_date      TYPE vbak-erdat,
*         sales_org          TYPE vbak-vkorg,
*         distr_chan         TYPE vbak-vtweg,
*         division           TYPE vbak-spart,
*         sold_to_party      TYPE vbak-kunnr,
*         net_value          TYPE vbak-netwr,
*         currency           TYPE vbak-waerk,
*         req_delivery_date  TYPE vbep-edatu,
*       END OF ty_tracking.
*
*DATA: gt_tracking TYPE STANDARD TABLE OF ty_tracking,
*      gs_tracking TYPE ty_tracking.

*--------------------------------------------------*
*    Screen0600 Declare data cho Graph - img       *
*--------------------------------------------------*
DATA: go_container1 TYPE REF TO cl_gui_custom_container,
      go_picture1   TYPE REF TO cl_gui_picture,
      go_container2 TYPE REF TO cl_gui_custom_container,
      go_picture2   TYPE REF TO cl_gui_picture.

*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_BILLING'
CONSTANTS: BEGIN OF C_TS_BILLING,
             TAB1 LIKE SY-UCOMM VALUE 'TS_BILLING_FC1',
             TAB2 LIKE SY-UCOMM VALUE 'TS_BILLING_FC2',
           END OF C_TS_BILLING.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_BILLING'
CONTROLS:  TS_BILLING TYPE TABSTRIP.
DATA:      BEGIN OF G_TS_BILLING,
             SUBSCREEN   LIKE SY-DYNNR,
             PROG        LIKE SY-REPID VALUE 'ZSD4_MASS_PROC',
             PRESSED_TAB LIKE SY-UCOMM VALUE C_TS_BILLING-TAB1,
           END OF G_TS_BILLING.

**********************************************************************
*                                                                    *
*                               SCREEN 0600                          *
*                                                                    *
**********************************************************************
**********************************************************************
* 1. OBJECT REFERENCES FOR GUI - ALV CONTROL FOR CC_ALV - SCR0600    *
**********************************************************************
DATA: go_container TYPE REF TO cl_gui_custom_container,
      go_alv       TYPE REF TO cl_gui_alv_grid.

**********************************************************************
*                                                                    *
* 2. LOCAL DATA STRUCTURE DEFINITION     - SCR0600                   *
*                                                                    *
**********************************************************************
TYPES: BEGIN OF ty_so_monitoring,
         status   TYPE char20,
         vbeln    TYPE vbak-vbeln,
         auart    TYPE vbak-auart,
         erdat    TYPE vbak-erdat,
         vdatu    TYPE vbak-vdatu,
         vkorg    TYPE vbak-vkorg,
         vtweg    TYPE vbak-vtweg,
         spart    TYPE vbak-spart,
         sold_to  TYPE char60,
         posnr    TYPE vbap-posnr,
         matnr    TYPE vbap-matnr,
         kwmeng   TYPE vbap-kwmeng,
         vrkme    TYPE vbap-vrkme,
         netwr    TYPE vbap-netwr,
         waerk    TYPE vbak-waerk,
       END OF ty_so_monitoring.

**********************************************************************
*                                                                    *
* 3. GLOBAL DECLARATION     - SCR0600                                *
*                                                                    *
**********************************************************************
DATA: gt_data TYPE STANDARD TABLE OF ty_so_monitoring,
      gs_data TYPE ty_so_monitoring.

*--------------------------------------------------*
*              Declare data cho Graph - img        *
*--------------------------------------------------*
DATA: go_html_container TYPE REF TO cl_gui_custom_container,
      go_html_viewer    TYPE REF TO cl_gui_html_viewer.
**********************************************************************
*                                                                    *
*                               SCREEN 0500                          *
*                                                                    *
**********************************************************************

TYPE-POOLS: icon.
"==========================================================
"   TABLES declarations for DDIC reference (avoid unknown field errors)
"==========================================================
TABLES: vbak, likp, vbrk, vbfa, bkpf.

"==========================================================
"   Dropdown variables (Combo boxes)
"==========================================================
DATA:
  cb_phase TYPE char20 VALUE 'All',
  cb_sosta TYPE char20 VALUE 'All',   "Sales Doc Status
  cb_ddsta TYPE char20 VALUE 'All',   "Delivery Doc Status
  cb_bdsta TYPE char20 VALUE 'All'.   "Billing Doc Status

"==========================================================
"   ALV Tracking Structure
"==========================================================

TYPES: BEGIN OF ty_tracking,
         process_phase     TYPE char30,
         sales_document    TYPE vbeln_va,
         arktx             TYPE arktx,
         delivery_document TYPE vbeln_vl,
         billing_document  TYPE vbeln_vf,
         order_type        TYPE auart,
         document_date     TYPE erdat,
         sales_org         TYPE vkorg,
         distr_chan        TYPE vtweg,
         division          TYPE spart,
         sold_to_party     TYPE kunnr,
         net_value         TYPE netwr,
         currency          TYPE waers,
         req_delivery_date TYPE edatu,
         error_msg         TYPE string,
         created_by        TYPE ernam,
         phase_icon        TYPE icon_d,
         sel_box           TYPE c LENGTH 1,
         fi_doc_billing    TYPE bkpf-belnr, " FI for Billing Doc
         bill_doc_cancel   TYPE vbrk-vbeln, " Billing Cancelled doc
         fi_doc_cancel     TYPE bkpf-belnr, " FI for cancel billing Doc
         release_flag      TYPE icon_d,
       END OF ty_tracking.

DATA: gt_tracking TYPE STANDARD TABLE OF ty_tracking,
      gs_tracking TYPE ty_tracking.

"==========================================================
"   ALV Objects
"==========================================================
DATA: go_container3 TYPE REF TO cl_gui_custom_container,
      go_alv1       TYPE REF TO cl_gui_alv_grid,
      gt_fcat      TYPE lvc_t_fcat,
      gs_layout1    TYPE lvc_s_layo,
      gt_exclude1    TYPE ui_functions.

" <<< THÊM DÒNG NÀY VÀO >>>
DATA: go_event_handler_track TYPE REF TO lcl_event_handler.
" <<< KẾT THÚC THÊM MỚI >>>

" <<< THÊM 2 DÒNG NÀY VÀO (Cho Summary Box) >>>
DATA: go_summary_container TYPE REF TO cl_gui_custom_container,
      go_summary_html      TYPE REF TO cl_dd_document.
" <<< KẾT THÚC THÊM MỚI >>>

"==========================================================
"   Supporting structures for VBFA join (link SO → Delivery → Billing)
"==========================================================
TYPES: BEGIN OF ty_vbfa_link,
         vbelv   TYPE vbfa-vbelv,   "Preceding document (SO)
         vbeln   TYPE vbfa-vbeln,   "Subsequent document (Delivery/Billing)
         vbtyp_n TYPE vbfa-vbtyp_n, "Subsequent doc type
       END OF ty_vbfa_link.

DATA: lt_delv TYPE TABLE OF ty_vbfa_link,
      ls_delv TYPE ty_vbfa_link,
      lt_bil  TYPE TABLE OF ty_vbfa_link,
      ls_bil  TYPE ty_vbfa_link.

"==========================================================
"   Flags for Process Phase determination
"==========================================================
DATA: lv_has_delv            TYPE abap_bool,
      lv_has_delv_not_pgi    TYPE abap_bool,
      lv_has_pgi_no_billing  TYPE abap_bool,
      lv_has_billing_no_fi   TYPE abap_bool,
      lv_has_billing_with_fi TYPE abap_bool,
      lv_so_reject           TYPE abap_bool.

"==========================================================
"   Helper variables for Delivery / Billing / Accounting
"==========================================================
DATA: lv_wadat_ist TYPE likp-wadat_ist,  " Actual GI date (PGI)
      lv_faksk     TYPE vbak-faksk,      " Rejection status
      lv_belnr_fi  TYPE bkpf-belnr,      " Accounting doc number
      lv_awkey     TYPE bkpf-awkey.      " Link key for BKPF (billing + year)

"==========================================================
"   Search / Filter form variables
"==========================================================
DATA:
  gv_vbeln    TYPE vbak-vbeln,
  gv_kunnr    TYPE vbak-kunnr,
  gv_ernam    TYPE vbak-ernam,
  gv_vkorg    TYPE vbak-vkorg,
  gv_vtweg    TYPE vbak-vtweg,
  gv_spart    TYPE vbak-spart,
  gv_doc_date TYPE vbak-erdat.

DATA: gv_jobname TYPE tbtcjob-jobname VALUE 'Z_AUTO_DELIV_PROTOTYPE'.

DATA: gv_sarea TYPE char20. " Biến gộp cho Sales Area


" Thêm dòng này vào TRƯỚC dòng DATA
CLASS lcl_event_handler1 DEFINITION DEFERRED.

" Dòng code cũ của bạn
DATA: gr_event_handler1 TYPE REF TO lcl_event_handler1.
DATA:
  gv_deliv TYPE vbeln_vl, " Delivery Document for Search
  gv_bill  TYPE vbeln_vf. " Billing Document for Search
*----------------------------------------------------------------------*
* CLASS lcl_event_handler DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_event_handler1 DEFINITION.
  PUBLIC SECTION.
    METHODS:
      handle_double_click
        FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column es_row_no.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_event_handler IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_event_handler1 IMPLEMENTATION.
  METHOD handle_double_click.
    " --- [FIX LỖI] ---
    " Khai báo biến trung gian để hứng index
    DATA: lv_index TYPE i.

    " Chuyển giá trị từ e_row-index sang biến kiểu Integer
    lv_index = e_row-index.

    " Truyền biến lv_index vào FORM (lúc này kiểu dữ liệu đã khớp)
    PERFORM show_document_flow_popup USING lv_index.
    " -----------------
  ENDMETHOD.
ENDCLASS.

" <<< THÊM MỚI: Cấu trúc cho Error Log Popup (PGI) >>>
TYPES: BEGIN OF ty_error_log,
         icon    TYPE c LENGTH 4, " (Dùng c length 4 như đã sửa)
         msgty   TYPE symsgty,
         msgno   TYPE symsgno,
         msgv1   TYPE symsgv1,
         msgv2   TYPE symsgv2,
         msgv3   TYPE symsgv3,
         msgv4   TYPE symsgv4,
         message TYPE string,
       END OF ty_error_log.
TYPES: ty_t_error_log TYPE STANDARD TABLE OF ty_error_log WITH DEFAULT KEY.

"==========================================================
"   Tabstrip 0700
"==========================================================
* Khai báo Tabstrip Control (phải dùng tên Control trên màn hình)
CONTROLS: TAB_MAIN TYPE TABSTRIP.

* Biến lưu trữ Fcode của tab hiện tại.
* Khai báo biến này với một độ dài đủ để chứa Fcode của tab.
DATA: G_CURRSU_TAB TYPE CHAR10 VALUE 'FITEM'. " TAB1 là Fcode của tab Item

*--------------------------------------------------------------------*
* [HOME CENTER] GLOBAL DATA DEFINITION
* Prefix: HC (Home Center) to avoid conflicts with Main Program
*--------------------------------------------------------------------*
TYPE-POOLS: icon.
INCLUDE <icon>.

* 1. Container & GUI Objects
DATA: go_hc_container TYPE REF TO cl_gui_custom_container,   " Main Container for Screen 0100
      go_hc_splitter  TYPE REF TO cl_gui_splitter_container, " Splitter (Top/Bottom)
      go_hc_cont_top  TYPE REF TO cl_gui_container,          " Top: HTML
      go_hc_cont_bot  TYPE REF TO cl_gui_container.          " Bottom: ALV

DATA: go_hc_html      TYPE REF TO cl_gui_html_viewer,        " KPI Viewer
      go_hc_alv       TYPE REF TO cl_gui_alv_grid.           " Order List

* 2. Business Data (KPIs)
DATA: gv_hc_total_so  TYPE i,
      gv_hc_pending   TYPE i,
      gv_hc_pgi       TYPE i,
      gv_hc_net_val   TYPE p DECIMALS 2,
      gv_hc_net_disp  TYPE string. " Formatted Value string (e.g. 4.5 B)

* 3. ALV Data Structure
TYPES: BEGIN OF ty_hc_alv_display,
         status_icon TYPE char4,        " Status Icon (Optional)
         vbeln       TYPE vbak-vbeln,   " Sales Document
         auart       TYPE vbak-auart,   " Order Type
         erzet       TYPE vbak-erzet,   " Time
         sales_area  TYPE string,       " Org / DCh / Div
         ernam       TYPE vbak-ernam,   " Created By
         netwr       TYPE vbak-netwr,   " Net Value
         waerk       TYPE vbak-waerk,   " Currency
         gbstk       TYPE vbak-gbstk,   " Status Key
         gbstk_txt   TYPE string,       " Status Text (Completed/Open...)
       END OF ty_hc_alv_display.

DATA: gt_hc_alv_data TYPE TABLE OF ty_hc_alv_display.

* 4. Local Class Definition (Unique Name)
CLASS lcl_hc_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action getdata.
ENDCLASS.

DATA: go_hc_handler TYPE REF TO lcl_hc_event_handler.

*&---------------------------------------------------------------------*
*&           SCREEN 0800: REPORT MONITORING
*&---------------------------------------------------------------------*

* 1. TABLES
TABLES: vbap, vbep.
TYPE-POOLS: icon.

* 2. STRUCTURE DỮ LIỆU (Thêm hậu tố _SD4)
TYPES: BEGIN OF ty_alv_sd4,
         vbeln     TYPE vbak-vbeln,
         auart     TYPE vbak-auart,
         audat     TYPE vbak-audat,
         vdatu     TYPE vbak-vdatu,
         vkorg     TYPE vbak-vkorg,
         vtweg     TYPE vbak-vtweg,
         spart     TYPE vbak-spart,
         kunnr     TYPE vbak-kunnr,
         bstnk     TYPE vbak-bstnk,
         gbstk     TYPE vbak-gbstk,
         waerk     TYPE vbak-waerk,
         name1     TYPE kna1-name1,
         posnr     TYPE vbap-posnr,
         matnr     TYPE vbap-matnr,
         kwmeng    TYPE vbap-kwmeng,
         vrkme     TYPE vbap-vrkme,
         netwr_i   TYPE vbap-netwr,
         req_qty_i  TYPE vbep-wmeng,
         gbstk_txt TYPE char35,
         status_icon TYPE icon_d,
         "t_color   TYPE lvc_t_scol,
       END OF ty_alv_sd4.

" Dữ liệu hiển thị trên ALV
DATA: gt_alv_sd4    TYPE TABLE OF ty_alv_sd4.
" Dữ liệu gốc (để tính KPI/Chart không bị mất khi lọc)
DATA: gt_static_sd4 TYPE TABLE OF ty_alv_sd4.

* 4. KPI VARIABLES
DATA: gv_kpi_total_sd4 TYPE i,
      gv_kpi_rev_sd4   TYPE p DECIMALS 2.

* 5. GUI OBJECTS (Đổi tên để không trùng với các màn hình khác)
DATA: go_cc_report    TYPE REF TO cl_gui_custom_container, " <-- Target Container
      go_split_sd4    TYPE REF TO cl_gui_splitter_container.

DATA: go_c_top_sd4    TYPE REF TO cl_gui_container,
*      go_c_mid_sd4    TYPE REF TO cl_gui_container,
      go_c_bot_sd4    TYPE REF TO cl_gui_container.

DATA: go_html_kpi_sd4 TYPE REF TO cl_gui_html_viewer,
*      go_html_cht_sd4 TYPE REF TO cl_gui_html_viewer,
      go_alv_sd4      TYPE REF TO cl_gui_alv_grid.

" Cờ kiểm soát Search
DATA: gv_exec_srch_sd4 TYPE char1.

* 6. SUBSCREEN SEARCH (0801)
SELECTION-SCREEN BEGIN OF SCREEN 0801 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF BLOCK b_sd4_1 WITH FRAME TITLE TEXT-001.
    SELECT-OPTIONS: s_vbeln FOR vbak-vbeln,
                    s_vkorg FOR vbak-vkorg NO INTERVALS,
                    s_kunnr FOR vbak-kunnr.
  SELECTION-SCREEN END OF BLOCK b_sd4_1.

  SELECTION-SCREEN BEGIN OF BLOCK b_sd4_2 WITH FRAME TITLE TEXT-002.
    SELECT-OPTIONS: s_audat FOR vbak-audat,
                    s_vdatu FOR vbak-vdatu,
                    s_gbstk FOR vbak-gbstk NO INTERVALS.
  SELECTION-SCREEN END OF BLOCK b_sd4_2.

  SELECTION-SCREEN BEGIN OF BLOCK b_sd4_3 WITH FRAME TITLE TEXT-003.
    SELECT-OPTIONS: s_auart FOR vbak-auart,
                    s_vtweg FOR vbak-vtweg,
                    s_spart FOR vbak-spart,
                    s_bstnk FOR vbak-bstnk NO INTERVALS,
                    s_erdat FOR vbak-erdat.
  SELECTION-SCREEN END OF BLOCK b_sd4_3.
SELECTION-SCREEN END OF SCREEN 0801.

*&---------------------------------------------------------------------*
*&               Screen 0900 DECLARATIONS.
*&---------------------------------------------------------------------*
DATA: go_cc_dashboard_0900 TYPE REF TO cl_gui_custom_container,
      go_viewer_0900       TYPE REF TO cl_gui_html_viewer.

TYPES: tt_netwr  TYPE STANDARD TABLE OF netwr WITH EMPTY KEY.
TYPES: tt_string TYPE STANDARD TABLE OF string WITH EMPTY KEY.

TYPES: BEGIN OF ty_kpi_json,
         sales   TYPE string,
         returns TYPE string,
         orders  TYPE string,
       END OF ty_kpi_json.

TYPES: BEGIN OF ty_dashboard_json,
         kpi            TYPE ty_kpi_json,
         trend          TYPE tt_netwr,
         top_customers  TYPE tt_netwr,
         top_cust_names TYPE tt_string,
         trend_labels   TYPE tt_string,
       END OF ty_dashboard_json.

TYPES: BEGIN OF ty_sales_raw,
         vbeln      TYPE vbak-vbeln,
         auart      TYPE vbak-auart,
         erdat      TYPE vbak-erdat,
         netwr      TYPE vbak-netwr,
         kunnr      TYPE vbak-kunnr,
         vkorg      TYPE vbak-vkorg,
         status_txt TYPE string,
       END OF ty_sales_raw.

TYPES: BEGIN OF ty_doc_flow,
         vbelv   TYPE vbfa-vbelv,
         vbeln   TYPE vbfa-vbeln,
         vbtyp_n TYPE vbfa-vbtyp_n,
         wbstk   TYPE likp-wbstk,
         rfbsk   TYPE vbrk-rfbsk,
         fksto   TYPE vbrk-fksto,
       END OF ty_doc_flow.

RANGES: r_vkorg FOR vbak-vkorg,
        r_erdat FOR vbak-erdat.

CLASS lcl_event_handler_0900 DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
        IMPORTING action frame getdata postdata query_table.
ENDCLASS.
