*&---------------------------------------------------------------------*
*& Include          ZSD4_MASS_PROC_TOP
*&---------------------------------------------------------------------*

TYPE-POOLS: slis.
TYPE-POOLS: BAPISD.

* Global Variables
DATA: gv_upload_type     TYPE c LENGTH 1,  " S = Single, M = Mass
      gv_management_type TYPE c LENGTH 1.  " T = Tracking, R = Report

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
         " 1. Bao gồm tất cả các trường từ Z-table
         INCLUDE TYPE ztb_so_cond_sing.
         " 2. Thêm các trường ALV-helper (không có trong DB)
  TYPES:   icon        TYPE icon-internal,
           status_code TYPE c LENGTH 1,
           status_text TYPE char20,
           message     TYPE string,
           style       TYPE lvc_t_styl,
           celltab     TYPE lvc_t_scol,  " Để xử lý màu ô (tránh lỗi GETWA_NOT_ASSIGNED)
           rowcolor    TYPE char4.       " Để xử lý màu dòng
TYPES: END OF ty_cond_alv.
TYPES: ty_t_cond_alv TYPE STANDARD TABLE OF ty_cond_alv WITH DEFAULT KEY.

DATA: gt_conditions_alv     TYPE ty_t_cond_alv. " (Bảng này giờ đã đúng)
DATA: gt_fieldcat_conds     TYPE lvc_t_fcat.

DATA: gt_fcat_header TYPE lvc_t_fcat,
      gt_fcat_item   TYPE lvc_t_fcat,
      gt_fcat_cond   TYPE lvc_t_fcat. " [MỚI] Cho Condition


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
*TYPES: BEGIN OF ty_tracking,
*         process_phase       TYPE char30,
*         sales_document      TYPE vbeln_va,
*         delivery_document   TYPE vbeln_vl,
*         billing_document    TYPE vbeln_vf,
*         order_type          TYPE auart,
*         document_date       TYPE erdat,
*         sales_org           TYPE vkorg,
*         distr_chan          TYPE vtweg,
*         division            TYPE spart,
*         sold_to_party       TYPE kunnr,
*         net_value           TYPE netwr,
*         currency            TYPE waers,
*         req_delivery_date   TYPE edatu,
*         error_msg           TYPE string,
*         created_by          TYPE ernam,
*         phase_icon          TYPE icon_d,
*         sel_box             TYPE c LENGTH 1,
*       END OF ty_tracking.

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
DATA:
  gv_deliv TYPE vbeln_vl, " Delivery Document for Search
  gv_bill  TYPE vbeln_vf. " Billing Document for Search


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


**&---------------------------------------------------------------------*
**&  BLOCK 5 – CLASS lcl_event_handler
**&  Event Handler for all ALV grids in the program
**&---------------------------------------------------------------------*
*
*CLASS lcl_event_handler DEFINITION.
*  PUBLIC SECTION.
*
*    " Constructor: Gắn grid + table nội bộ
*    METHODS: constructor
*        IMPORTING
*          io_grid  TYPE REF TO cl_gui_alv_grid    " Grid cần bắt event
*          it_table TYPE REF TO data.              " Table làm nguồn dữ liệu
*
*    " Khi người dùng nhấn nút (button) trên ALV toolbar
*    METHODS: handle_user_command
*        FOR EVENT user_command OF cl_gui_alv_grid
*        IMPORTING e_ucomm.
*
*    " Tùy biến toolbar: thêm, ẩn, disable nút
*    METHODS: handle_toolbar
*        FOR EVENT toolbar OF cl_gui_alv_grid
*        IMPORTING e_object e_interactive.
*
*    " Khi người dùng thay đổi dữ liệu trong ALV (live edit)
*    METHODS: handle_data_changed
*        FOR EVENT data_changed OF cl_gui_alv_grid
*        IMPORTING er_data_changed.
*
*    " Sau khi hệ thống xử lý xong thay đổi data_changed
*    METHODS: handle_data_changed_finished
*        FOR EVENT data_changed_finished OF cl_gui_alv_grid
*        IMPORTING e_modified et_good_cells.
*
*    " Khi người dùng click vào cell có hotspot (icon xem lỗi, item drilldown…)
*    METHODS: handle_hotspot_click
*        FOR EVENT hotspot_click OF cl_gui_alv_grid
*        IMPORTING e_row_id e_column_id es_row_no.
*
*  PRIVATE SECTION.
*    DATA:
*      mo_grid  TYPE REF TO cl_gui_alv_grid,   " Grid ALV tương ứng
*      mt_table TYPE REF TO data.              " Nội dung data tương ứng
*ENDCLASS.
*
*
**&---------------------------------------------------------------------*
**&  BLOCK 1 – TYPE POOLS + GLOBAL MODE FLAGS + SCREEN STATE
**&---------------------------------------------------------------------*
*
*"-------------------------------------------------------------*
*" TYPE-POOLS: Import các định nghĩa type chuẩn của SAP
*"-------------------------------------------------------------*
*TYPE-POOLS: slis.      " SLIS: Dùng cho field catalog kiểu cũ (REUSE_ALV...)
*TYPE-POOLS: bapisd.    " BAPISD: Chứa type của BAPI Sales Order (BAPI_SALESORDER*)
*
*"-------------------------------------------------------------*
*" GLOBAL FLAGS – Xác định chế độ hệ thống đang chạy
*"-------------------------------------------------------------*
*DATA: gv_upload_type TYPE c LENGTH 1,     " S = Create Single SO, M = Mass Upload
*      gv_management_type TYPE c LENGTH 1. " T = Tracking, R = Report dashboard
*
*"-------------------------------------------------------------*
*" SCREEN FLAGS – Quản lý trạng thái nhập liệu chính của screen
*"-------------------------------------------------------------*
*DATA: gv_screen_state TYPE c VALUE '0'.
*" 0 = User vừa vào màn hình (no Sold-to yet)
*" 1 = Đã nhập xong Sold-to → cho phép nhập thêm Item, Conditions…
*
*DATA: gv_so_just_created TYPE abap_bool.
*" 'X' = Vừa tạo Sales Order thành công (Single Upload)
*" Dùng để trigger refresh tab / popup thành công
*
*"-------------------------------------------------------------*
*" REQUEST ID – Dùng để trace 1 lần upload → lưu vào bảng staging/log
*"-------------------------------------------------------------*
*DATA gv_req_id TYPE zsd_req_id.           " Req_ID được generate khi user upload file
*DATA gv_current_req_id TYPE zsd_req_id.   " Lưu Req_ID hiện tại suốt chương trình
*
*"-------------------------------------------------------------*
*" FIRST RUN – Kiểm tra chương trình chạy lần đầu
*"-------------------------------------------------------------*
*DATA gv_first_run TYPE c VALUE 'X'.
*" X = Run lần đầu → Load các cấu hình ban đầu (tips, layout…)
*
*"-------------------------------------------------------------*
*" DATA LOADED FLAG – Kiểm tra đã load file chưa
*"-------------------------------------------------------------*
*DATA gv_data_loaded TYPE abap_bool.
*" 'X' = W đã upload file Excel thành công
*" Dùng để enable/disable các nút (Validate, Clear, Save...)
*
*"-------------------------------------------------------------*
*" OK-CODE – Biến nhận function code từ UI (PBO/PAI)
*"-------------------------------------------------------------*
*DATA ok_code TYPE sy-ucomm.
*
*"-------------------------------------------------------------*
*" RADIO BUTTON FLAGS – Dùng trong màn hình chọn chế độ xử lý
*"-------------------------------------------------------------*
*DATA: rb_single TYPE abap_bool,   " Single Sales Order mode
*      rb_mass   TYPE abap_bool,   " Mass Upload mode
*      rb_status TYPE abap_bool,   " Status checking mode (VA05-like)
*      rb_remon  TYPE abap_bool.   " Remote Monitoring (bổ sung nếu có)
*
*"-------------------------------------------------------------*
*" QUICK TIPS – Hiển thị hướng dẫn (UI feature)
*"-------------------------------------------------------------*
*DATA: lt_tips  TYPE STANDARD TABLE OF string,  " Danh sách câu tips
*      tip_text TYPE string,                    " 1 tip đơn lẻ
*      gv_hello_text TYPE string.               " Lời chào tùy biến trên screen
*
**&---------------------------------------------------------------------*
**&  BLOCK 2 – VALIDATION SUMMARY COUNTERS
**&---------------------------------------------------------------------*
*" Các biến thống kê số dòng theo trạng thái, hiển thị trên Validation Summary
*" dùng cho UI trong màn hình Mass Upload (Tab Validated / Success / Failed)
*
*"======================================================================
*" 1. COUNTS FOR VALIDATED TAB – Sau khi chạy VALIDATE TEMPLATE + VALIDATE DATA
*"======================================================================
*
*DATA: gv_cnt_val_ready   TYPE i,
*      " Số header/item có trạng thái READY TO POST
*      " (Validate thành công – có thể SAVE TO STAGING hoặc CREATE SO)
*
*      gv_cnt_val_incomp  TYPE i,
*      " Số dòng bị INCOMPLETE – thiếu dữ liệu bắt buộc
*      " Xuất hiện trong Validation Summary màu vàng
*
*      gv_cnt_val_err     TYPE i.
*      " Số dòng ERROR – sai format, sai master data, pricing sai…
*      " Xuất hiện trong Validation Summary màu đỏ
*
*
*"======================================================================
*" 2. COUNTS FOR SUCCESS TAB – Sau khi CREATE SALES ORDER thành công
*"======================================================================
*
*DATA: gv_cnt_suc_comp    TYPE i,
*      " Số dòng COMPLETE – SO tạo thành công + Delivery (nếu auto-delivery)
*
*      gv_cnt_suc_incomp  TYPE i.
*      " Số dòng lập được Sales Order nhưng INCOMPLETE (thiếu data VA02)
*      " Thường xảy ra khi master data thiếu hoặc pricing chưa đầy đủ
*
*
*"======================================================================
*" 3. COUNTS FOR FAILED TAB – SO CREATION FAILED (BAPI trả về E/M)
*"======================================================================
*
*DATA: gv_cnt_fail_err    TYPE i.
*      " Số dòng FAILED (BAPI_SALESORDER_CREATEFROMDAT2 trả về ERROR)
*      " Dòng này được move sang Tab 'Failed' cùng thông báo lỗi cụ thể
*
*
*"======================================================================
*" 4. Tổng số dòng (Header / Item / Condition) – dùng để hiển thị footer
*"======================================================================
*
*DATA: gv_cnt_h_tot       TYPE i,
*      " Tổng số dòng HEADER của toàn bộ file upload
*
*      gv_cnt_i_tot       TYPE i,
*      " Tổng số ITEM
*
*      gv_cnt_c_tot       TYPE i.
*      " Tổng số CONDITION (pricing) – nếu có sheet Pricing riêng
*
*
*"======================================================================
*" 5. Item counts trong từng tab – dùng cho thống kê chi tiết Item
*"======================================================================
*
*DATA: gv_cnt_i_val       TYPE i,
*      " Số dòng Item ở tab Validated (Ready + Incomplete + Error)
*
*      gv_cnt_i_suc       TYPE i,
*      " Số dòng Item thuộc các SO được tạo thành công (Success tab)
*
*      gv_cnt_i_fail      TYPE i.
*      " Item của SO bị lỗi (Failed tab)
*
*
*"======================================================================
*" 6. Condition counts – tương tự Item nhưng cho Pricing tab
*"======================================================================
*
*DATA: gv_cnt_c_val       TYPE i,
*      " Số điều kiện giá (ZPRQ, ZXXX…) sau Validate
*
*      gv_cnt_c_suc       TYPE i,
*      " Conditions thuộc SO tạo thành công
*
*      gv_cnt_c_fail      TYPE i.
*      " Conditions thuộc SO bị lỗi
*
**&---------------------------------------------------------------------*
**&  BLOCK 3 – MAIN UI OBJECTS (DOCKING, TABSTRIPS, CONTAINERS)
**&---------------------------------------------------------------------*
*
*"======================================================================
*" 1. DOCKING CONTAINER – HIỂN THỊ VALIDATION SUMMARY
*"======================================================================
*
*DATA: go_docking_summary TYPE REF TO cl_gui_docking_container.
*" Docking container đặt bên trái/phải màn hình → giống nhóm kia
*" Dùng để hiển thị Validation Summary: Ready / Incomplete / Error
*" Ưu điểm:
*"   - Tự co giãn theo giao diện (resize)
*"   - Không cần đặt cố định trong Screen Painter
*"   - Giữ cố định khi chuyển tab (Validated → Success → Failed)
*
*" Đây là container *thay thế* custom container cũ (go_cont_0200).
*
*
*"======================================================================
*" 2. TABSTRIP CHÍNH – TS_MAIN
*"======================================================================
*
**&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_MAIN'
*CONSTANTS: BEGIN OF c_ts_main,
*             tab1 LIKE sy-ucomm VALUE 'TS_MAIN_FC1',   " Tab: Create SO
*             tab2 LIKE sy-ucomm VALUE 'TS_MAIN_FC2',   " Tab: Tracking/Report
**             tab3 LIKE sy-ucomm VALUE 'TS_MAIN_FC3',   " (Nếu mở rộng thêm)
*           END OF c_ts_main.
*
*CONTROLS: ts_main TYPE tabstrip.
*" Tên control phải đúng 100% với Screen Painter (màn hình 0200 hoặc 0100)
*
*DATA: BEGIN OF g_ts_main,
*        subscreen   LIKE sy-dynnr,
*        prog        LIKE sy-repid VALUE 'ZSD4_MASS_PROC',
*        pressed_tab LIKE sy-ucomm VALUE c_ts_main-tab1,
*      END OF g_ts_main.
*" g_ts_main quyết định: mỗi tab hiển thị subscreen nào
*" pressed_tab lưu tab hiện tại user đang đứng
*
*
*"======================================================================
*" 3. TABSTRIP VALIDATION – TS_VALI (Bao gồm 3 TAB: Validated, Success, Failed)
*"======================================================================
*
**&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_VALI'
*CONSTANTS: BEGIN OF c_ts_vali,
*             tab1 LIKE sy-ucomm VALUE 'TS_VALI_FC1',   " Tab Validated
*             tab2 LIKE sy-ucomm VALUE 'TS_VALI_FC2',   " Tab Success
*             tab3 LIKE sy-ucomm VALUE 'TS_VALI_FC3',   " Tab Failed
*           END OF c_ts_vali.
*
*CONTROLS: ts_vali TYPE tabstrip.
*
*DATA: BEGIN OF g_ts_vali,
*        subscreen   LIKE sy-dynnr,
*        prog        LIKE sy-repid VALUE 'ZSD4_MASS_PROC',
*        pressed_tab LIKE sy-ucomm VALUE c_ts_vali-tab1,
*      END OF g_ts_vali.
*" TS_VALI xuất hiện trong màn hình Mass Upload (screen 0200)
*" → Cho phép user xem 3 tab:
*"     (1) Validated (Ready & Incomplete & Error)
*"     (2) Success (SO post thành công)
*"     (3) Failed (SO post thất bại)
*
*
*"======================================================================
*" 4. MAIN CUSTOM CONTAINERS CHO ALV (Validated / Success / Failed)
*"======================================================================
*
*DATA: go_cont_val  TYPE REF TO cl_gui_custom_container, " Tab Validated
*      go_cont_suc  TYPE REF TO cl_gui_custom_container, " Tab Success
*      go_cont_fail TYPE REF TO cl_gui_custom_container. " Tab Failed
*
*" Mỗi tab có 3 ALV:
*"   Header ALV
*"   Item ALV
*"   Condition ALV
*" Do đó cần nhiều grid hơn trong Block 4 & Block 5 (Grid + Event Handler)
*"
*" Các container này được đặt trong Screen Painter của subscreen:
*"   0211 – Validated
*"   0212 – Success
*"   0213 – Failed
*
*
*"======================================================================
*" 5. SINGLE UPLOAD CONTAINER – DÙNG TRONG SCREEN 0110/0113
*"======================================================================
*
*DATA: go_cont_item_single TYPE REF TO cl_gui_custom_container.
*" Container để hiển thị ALV Item trong SINGLE UPLOAD mode
*" Screen: 0110 – Header
*"         0113 – Conditions
*
*" Vì Single Upload có 3 phần:
*"   - Header form (input fields)
*"   - Item ALV
*"   - Condition ALV
*" Nên bạn có go_grid_item_single + go_grid_conditions
*
*
*"======================================================================
*" 6. MONITORING CONTAINER – TAB MONITORING (SCREEN 600)
*"======================================================================
*
*DATA: go_cont_monitoring TYPE REF TO cl_gui_custom_container,
*      go_grid_monitoring TYPE REF TO cl_gui_alv_grid,
*      go_event_handler_moni TYPE REF TO lcl_event_handler.
*
*" Tab Monitoring để hiển thị:
*"   - Sales Order status
*"   - Delivery status
*"   - Billing status
*"   - Accounting status
*" Và các icon phase (SO → Delivery → PGI → Billing → FI)
*
*
*"======================================================================
*" 7. PGI / DELIVERY CONTAINER (SCREEN 021x)
*"======================================================================
*
*DATA: go_cont_pgi TYPE REF TO cl_gui_custom_container,
*      go_grid_pgi TYPE REF TO cl_gui_alv_grid.
*
*" Tab PGI (Post Goods Issue)
*"   - Hiển thị item delivery
*"   - Checkbox để chọn line post PGI
*"   - Message sau PGI thành công
*
*
*"======================================================================
*" 8. POPUP CONTAINER (GRID TRONG POPUP – ERROR LOG / INCOMP LOG)
*"======================================================================
*
*" Dùng field catalog kiểu cũ (SLIS) vì popup ALV dùng REUSE_ALV_GRID_DISPLAY
*
*" Popup sử dụng container tạm thời của ALV function module
*" Không cần OBJECT container cố định trong TOP
*
*
*"======================================================================
*" 9. HTML SUMMARY CONTAINER – Render HTML bên phải (Screen 0400)
*"======================================================================
*
*DATA: go_summary_container TYPE REF TO cl_gui_custom_container,
*      go_summary_html TYPE REF TO cl_dd_document.
*
*" Dùng để render Summary Box đẹp như nhóm kia:
*"   - Icon LED
*"   - Tổng số Sales Orders
*"   - Tổng giá trị
*"   - Tổng error/success
*
**&---------------------------------------------------------------------*
**&  BLOCK 4 – CONSTANTS (Sheet Names, Status Texts, FCodes, Icons)
**&---------------------------------------------------------------------*
*
*"======================================================================
*" 1. CONSTANTS FOR EXCEL SHEET NAMES
*"======================================================================
*
*CONSTANTS:
*  gc_sheet_header TYPE string VALUE 'Header',   " Tên sheet chứa dữ liệu Header
*  gc_sheet_item   TYPE string VALUE 'Item'.     " Tên sheet chứa dữ liệu Item
*
*" Nếu có thêm sheet Pricing → sẽ có thêm gc_sheet_cond = 'Pricing'
*" Chương trình dùng constant này khi:
*"   - Validate template structure
*"   - Map từ Excel vào internal table
*"   - Lỗi tên sheet sẽ báo ngay đầu validate
*
*
*"======================================================================
*" 2. CONSTANTS FOR STATUS TEXT (Used in Validation + Result)
*"======================================================================
*
*CONSTANTS:
*  gc_status_comp TYPE char20 VALUE 'Complete',   " SO/DLV tạo thành công
*  gc_status_err  TYPE char20 VALUE 'Error',      " Lỗi Validate hoặc Lỗi BAPI
*  gc_status_new  TYPE char20 VALUE 'New'.        " Dòng mới upload, chưa validate
*
*" Ý nghĩa:
*"   - gc_status_new : Load xong file → tất cả là NEW
*"   - VALIDATE → chuyển sang READY / INCOMPLETE / ERROR
*"   - POST → chuyển SUCCESS / FAILED
*"
*" Các giá trị này được gắn vào:
*"   - gt_hd_val-rowcolor
*"   - gt_hd_suc-status
*"   - popup log
*
*
*"======================================================================
*" 3. CONSTANTS FOR FUNCTION CODES (BUTTONS IN PAI)
*"======================================================================
*
*CONSTANTS:
*  gc_fc_check TYPE syucomm VALUE 'CHECK',   " Button VALIDATE
*  gc_fc_save  TYPE syucomm VALUE 'SAVE',    " SAVE TO STAGING
*  gc_fc_crea  TYPE syucomm VALUE 'CREA',    " CREATE SALES ORDER
*  gc_fc_exit  TYPE syucomm VALUE 'EXIT'.    " BACK / EXIT / LEAVE PROGRAM
*
*" Nơi dùng:
*"   - case ok_code trong PAI của screen 0200
*"   - Nếu user nhấn VALIDATE → gọi perform validate_data
*"   - Nhấn SAVE → save staging
*"   - Nhấn CREATE → BAPI_SALESORDER_CREATEFROMDAT2
*"   - Nhấn EXIT → xử lý popup “Do you want to exit?”
*
*
*"======================================================================
*" 4. ICON CONSTANTS (LED INDICATORS)
*"======================================================================
*
*CONSTANTS:
*  gc_icon_red    TYPE icon-name VALUE 'ICON_LED_RED',     " Error
*  gc_icon_yellow TYPE icon-name VALUE 'ICON_LED_YELLOW',  " Incomplete / Warning
*  gc_icon_green  TYPE icon-name VALUE 'ICON_LED_GREEN'.   " Ready / Success
*
*" 3 icon này là cốt lõi cho UI/UX:
*"   - Header ALV: icon field show trạng thái mỗi dòng
*"   - Condition ALV: highlight rules
*"   - Validation Summary: đếm số Ready/Incomplete/Error
*"   - Success tab: LED xanh toàn bộ
*"   - Failed tab : LED đỏ tất cả
*
**&---------------------------------------------------------------------*
**&  BLOCK 6 – TYPES CHO HEADER / ITEM / CONDITION
**&  STRUCTURE, INTERNAL TABLES, ALV GRID OBJECTS, EVENT HANDLER OBJECTS, FIELD CATALOG
**&---------------------------------------------------------------------*
*
*"======================================================================
*" 1. STRUCTURE FOR VALIDATION ERROR LOG
*"======================================================================
*TYPES: BEGIN OF ty_validation_error,
*         temp_id   TYPE char10,     " Khóa nối Header/Item (H001, H002...)
*         item_no   TYPE posnr_va,   " Item số mấy (10, 20, 30...) – để trace lỗi
*         fieldname TYPE fieldname,  " Tên field gây lỗi (MATNR, VKORG…)
*         message   TYPE string,     " Mô tả lỗi hiển thị trong popup
*       END OF ty_validation_error.
*
*TYPES: ty_t_validation_error TYPE STANDARD TABLE OF ty_validation_error
*       WITH EMPTY KEY.
*
*"======================================================================
*" 2. HEADER STRUCTURE (Mass Upload – 3 Tabs)
*"======================================================================
*TYPES: BEGIN OF ty_header.
*         INCLUDE TYPE ztb_so_upload_hd. " Toàn bộ field của bảng staging header
*  TYPES:
*         icon     TYPE icon-internal,   " LED theo trạng thái dòng (Green/Yellow/Red)
*         celltab  TYPE lvc_t_scol,      " Màu từng ô (optional)
*         rowcolor TYPE char4,           " Màu cả dòng: C610 = đỏ, C500 = vàng, C200 = xanh
*         err_btn  TYPE icon-internal,   " Icon hotspot để click xem lỗi
*       END OF ty_header.
*
*TYPES ty_t_header TYPE STANDARD TABLE OF ty_header WITH DEFAULT KEY.
*
*"======================================================================
*" 3. ITEM STRUCTURE (Mass Upload – 3 Tabs)
*"======================================================================
*
*TYPES: BEGIN OF ty_item.
*         INCLUDE TYPE ztb_so_upload_it. " Bảng staging item
*  TYPES:
*         icon     TYPE icon-internal,
*         celltab  TYPE lvc_t_scol,
*         rowcolor TYPE char4,
*         err_btn  TYPE icon-internal,
*       END OF ty_item.
*
*TYPES ty_t_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.
*
*"======================================================================
*" 4. CONDITION STRUCTURE (Mass Upload – Pricing – 3 Tabs)
*"======================================================================
*
*TYPES: BEGIN OF ty_condition.
*         INCLUDE TYPE ztb_so_upload_pr.   " Bảng pricing staging
*  TYPES:
*         icon     TYPE icon-internal,
*         rowcolor TYPE char4,
*         celltab  TYPE lvc_t_scol,
*         err_btn  TYPE icon-internal,
*       END OF ty_condition.
*
*"======================================================================
*" 5. INTERNAL TABLES FOR 3 TAB MASS UPLOAD
*"======================================================================
*
*" Tab 1: Validated
*DATA: gt_hd_val TYPE TABLE OF ty_header,
*      gt_it_val TYPE TABLE OF ty_item,
*      gt_pr_val TYPE TABLE OF ty_condition.
*
*" Tab 2: Success
*DATA: gt_hd_suc TYPE TABLE OF ty_header,
*      gt_it_suc TYPE TABLE OF ty_item,
*      gt_pr_suc TYPE TABLE OF ty_condition.
*
*" Tab 3: Failed
*DATA: gt_hd_fail TYPE TABLE OF ty_header,
*      gt_it_fail TYPE TABLE OF ty_item,
*      gt_pr_fail TYPE TABLE OF ty_condition.
*
*"======================================================================
*" 6. ALV GRID OBJECTS CHO 9 GRID (3 tabs × 3 bảng)
*"======================================================================
*
*" Tab 1 – Validated
*DATA: go_grid_hdr_val TYPE REF TO cl_gui_alv_grid,
*      go_grid_itm_val TYPE REF TO cl_gui_alv_grid,
*      go_grid_cnd_val TYPE REF TO cl_gui_alv_grid.
*
*" Tab 2 – Success
*DATA: go_grid_hdr_suc TYPE REF TO cl_gui_alv_grid,
*      go_grid_itm_suc TYPE REF TO cl_gui_alv_grid,
*      go_grid_cnd_suc TYPE REF TO cl_gui_alv_grid.
*
*" Tab 3 – Failed
*DATA: go_grid_hdr_fail TYPE REF TO cl_gui_alv_grid,
*      go_grid_itm_fail TYPE REF TO cl_gui_alv_grid,
*      go_grid_cnd_fail TYPE REF TO cl_gui_alv_grid.
*
*"======================================================================
*" 7. EVENT HANDLER OBJECTS CHO MỖI GRID
*"======================================================================
*
*DATA: go_event_hdr_val TYPE REF TO lcl_event_handler,
*      go_event_itm_val TYPE REF TO lcl_event_handler,
*      go_event_cnd_val TYPE REF TO lcl_event_handler,
*
*      go_event_hdr_suc TYPE REF TO lcl_event_handler,
*      go_event_itm_suc TYPE REF TO lcl_event_handler,
*      go_event_cnd_suc TYPE REF TO lcl_event_handler,
*
*      go_event_hdr_fail TYPE REF TO lcl_event_handler,
*      go_event_itm_fail TYPE REF TO lcl_event_handler,
*      go_event_cnd_fail TYPE REF TO lcl_event_handler.
*
*
*"======================================================================
*" 8. SINGLE UPLOAD STRUCTURE (Header already separate, here is Item)
*"======================================================================
*
*TYPES: BEGIN OF ty_item_details.
*         INCLUDE TYPE ztb_so_item_sing.     " Structure của Single Upload Item
*  TYPES:
*         icon        TYPE icon-internal,
*         status_code TYPE c LENGTH 1,        " READY/ERROR/INCOMP
*         status_text TYPE char20,
*         message     TYPE string,            " Lỗi validate inline
*         style       TYPE lvc_t_styl,        " Enable/Disable edit cell
*         celltab     TYPE lvc_t_scol,        " Tô màu theo ô
*         rowcolor    TYPE char4.             " Tô màu cả dòng
*TYPES END OF ty_item_details.
*
*TYPES ty_t_item_details TYPE STANDARD TABLE OF ty_item_details WITH DEFAULT KEY.
*
*DATA: gt_item_details TYPE ty_t_item_details.
*
*"======================================================================
*" 9. SINGLE UPLOAD CONDITION STRUCTURE
*"======================================================================
*
*TYPES: BEGIN OF ty_cond_alv.
*         INCLUDE TYPE ztb_so_cond_sing.   " Pricing for Single Upload
*  TYPES:
*         icon        TYPE icon-internal,
*         status_code TYPE c LENGTH 1,
*         status_text TYPE char20,
*         message     TYPE string,
*         style       TYPE lvc_t_styl,
*         celltab     TYPE lvc_t_scol,
*         rowcolor    TYPE char4.
*TYPES END OF ty_cond_alv.
*
*TYPES ty_t_cond_alv TYPE STANDARD TABLE OF ty_cond_alv WITH DEFAULT KEY.
*
*DATA: gt_conditions_alv TYPE ty_t_cond_alv.
*
*"======================================================================
*" 10. FIELD CATALOG CHO HEADER / ITEM / CONDITION
*"======================================================================
*
*DATA: gt_fcat_header TYPE lvc_t_fcat,
*      gt_fcat_item   TYPE lvc_t_fcat,
*      gt_fcat_cond   TYPE lvc_t_fcat.
*
*"======================================================================
*" BLOCK 7 – STAGING & RESULT STRUCTURES
*"======================================================================
*
*"======================================================================
*" 1. RAW DATA (Excel raw string before mapping)S
*"======================================================================
*
*TYPES: BEGIN OF ty_rawdata,
*         data TYPE string,
*       END OF ty_rawdata.
*
*DATA: gs_rawdata TYPE ty_rawdata,
*      gt_rawdata TYPE STANDARD TABLE OF ty_rawdata.
*
*"======================================================================
*" 2. STAGING STRUCTURE KẾT HỢP HEADER + ITEM
*"======================================================================
*
*TYPES: BEGIN OF ty_staging,
*         temp_id        TYPE char10,       " Khóa nối Header–Item cùng 1 SO
*
*         "----- Header fields -----
*         sales_org      TYPE vbak-vkorg,
*         dist_chnl      TYPE vbak-vtweg,
*         division       TYPE vbak-spart,
*         sold_to_party  TYPE vbak-kunnr,
*         ship_to_party  TYPE vbak-kunnr,
*         cust_ref       TYPE vbak-bstnk,
*         req_date       TYPE vbak-vdatu,
*         order_type     TYPE auart,
*         currency       TYPE waers,
*
*         "----- Item fields -----
*         item_no        TYPE posnr_va,
*         matnr          TYPE matnr,
*         short_text     TYPE arktx,
*         qty            TYPE kwmeng,
*         uom            TYPE vrkme,
*         plant          TYPE werks_d,
*         store_loc      TYPE lgort_d,
*
*         "----- Pricing fields (if any) -----
*         cond_type      TYPE konwa,
*         cond_value     TYPE kbetr,
*END OF ty_staging.
*
*DATA: gt_staging TYPE STANDARD TABLE OF ty_staging,
*      gs_staging TYPE ty_staging.
*
*"======================================================================
*" 3. RESULT STRUCTURE (SALES ORDER RESULT)
*"======================================================================
*
*TYPES: BEGIN OF ty_result,
*         temp_id   TYPE char10,       " Map lại temp_id H001/H002
*         vbeln     TYPE vbak-vbeln,   " Sales Order Number
*         vkorg     TYPE vbak-vkorg,
*         vtweg     TYPE vbak-vtweg,
*         spart     TYPE vbak-spart,
*         sold_to   TYPE vbak-kunnr,
*         ship_to   TYPE vbak-kunnr,
*         bstkd     TYPE vbak-bstnk,   " Customer Reference
*         req_date  TYPE vbak-vdatu,
*         qty       TYPE i,            " Tổng qty của SO
*         volume    TYPE wrbtr,        " Tổng giá trị SO
*         status    TYPE char20,       " Complete / Incomplete / Error
*         message   TYPE string,       " Error/Sucess message from BAPI
*END OF ty_result.
*
*DATA: gt_result TYPE STANDARD TABLE OF ty_result,
*      gs_result TYPE ty_result.
*
*"======================================================================
*" 4. DELIVERY RESULT STRUCTURE (Auto Delivery → PGI)
*"======================================================================
*
*TYPES: BEGIN OF ty_delivery_result,
*         vbeln_vl   TYPE likp-vbeln,   " Delivery Number
*         vbeln_va   TYPE vbak-vbeln,   " Sales Order Number
*         vkorg      TYPE vbak-vkorg,
*         vtweg      TYPE vbak-vtweg,
*         spart      TYPE vbak-spart,
*         kunnr      TYPE vbak-kunnr,   " Ship-to Party
*         lfart      TYPE likp-lfart,   " Delivery Type
*         wadat_ist  TYPE likp-wadat_ist, " Planned GI date
*         status     TYPE char20,       " Complete/Error
*         message    TYPE string,       " Message returned from BAPI
*END OF ty_delivery_result.
*
*DATA: gt_delivery_result TYPE STANDARD TABLE OF ty_delivery_result,
*      gs_delivery_result TYPE ty_delivery_result.
*
*"======================================================================
*" 5. VA05 STYLE STRUCTURE (Item-level SO status)
*"======================================================================
*
*TYPES: BEGIN OF ty_va05,
*         cust_ref TYPE vbak-bstnk,     " Customer Reference
*         doc_date TYPE dats,           " Document Date
*         doc_type TYPE auart,          " Order Type
*         vbeln    TYPE vbak-vbeln,     " SO number
*         posnr    TYPE posnr_va,       " Item
*         sold_to  TYPE vbak-kunnr,
*         matnr    TYPE vbap-matnr,
*         qty      TYPE kwmeng,
*         uom      TYPE vrkme,
*         netwr    TYPE wrbtr,
*         waerk    TYPE waers,
*         status   TYPE char20,         " CREATED / INCOMPLETE / ERROR
*END OF ty_va05.
*
*DATA: gt_va05_all     TYPE STANDARD TABLE OF ty_va05,
*      gt_va05_created TYPE STANDARD TABLE OF ty_va05,
*      gt_va05_incomp  TYPE STANDARD TABLE OF ty_va05.
*
*"======================================================================
*" 6. DELIVERY PROCESSING STRUCTURE (PGI)
*"======================================================================
*
*TYPES: BEGIN OF ty_delivery_ext,
*         sel         TYPE char1,          " Checkbox chọn item
*         vbeln_so    TYPE vbak-vbeln,     " SO
*         vbeln_dlv   TYPE likp-vbeln,     " Delivery
*         vkorg       TYPE vbak-vkorg,
*         vtweg       TYPE vbak-vtweg,
*         spart       TYPE vbak-spart,
*         kunnr_sold  TYPE vbak-kunnr,     " Sold-to
*         kunnr_ship  TYPE vbak-kunnr,     " Ship-to
*         bstkd       TYPE vbak-bstnk,     " Cust Ref
*         lfart       TYPE likp-lfart,     " Delivery Type
*         erdat       TYPE likp-erdat,     " Created date
*         ernam       TYPE likp-ernam,     " Created by
*         status      TYPE char20,         " Status before PGI
*         message     TYPE string,         " Message after PGI
*END OF ty_delivery_ext.
*
*DATA: gt_delivery      TYPE STANDARD TABLE OF ty_delivery_ext,
*      gs_delivery      TYPE ty_delivery_ext,
*      gt_deliv_pgi     TYPE STANDARD TABLE OF ty_delivery_ext,
*      gs_deliv_pgi     TYPE ty_delivery_ext.
*
*"======================================================================
*" BLOCK 8 – DELIVERY / PGI / MONITORING / TRACKING STRUCTURES
*"======================================================================
*
*"======================================================================
*" 1. PGI Detail (Screen 300 – Header)
*"======================================================================
*
*DATA: gs_pgi_detail_ui TYPE zsd4_pgi_detail_ui.
*
*"======================================================================
*" 2. PGI Process Header (NEW – Tab 2 trong Screen 300)
*"======================================================================
*DATA: gs_pgi_process_ui TYPE zstr_pgi_process_ui.
*
*"======================================================================
*" 3. PGI Item List (Screen 021x – ALL ITEMS)
*"======================================================================
*
*TYPES: BEGIN OF ty_pgi_all_items.
*         INCLUDE TYPE ztb_pgi_all_item. " Bảng Z lưu item chuẩn bị PGI
*  TYPES:
*         icon        TYPE icon-internal,   " LED cho trạng thái
*         status_code TYPE c LENGTH 1,      " R/E/W
*         message     TYPE string,          " Thông báo PGI từng item
*         style       TYPE lvc_t_styl.      " Enable/Disable edit cell
*TYPES END OF ty_pgi_all_items.
*
*TYPES: ty_t_pgi_all_items TYPE STANDARD TABLE OF ty_pgi_all_items WITH DEFAULT KEY.
*
*DATA: gt_pgi_all_items TYPE ty_t_pgi_all_items,
*      gt_fieldcat_pgi_all TYPE lvc_t_fcat,
*      go_cont_pgi_all TYPE REF TO cl_gui_custom_container,
*      go_grid_pgi_all TYPE REF TO cl_gui_alv_grid,
*      go_event_pgi_all TYPE REF TO lcl_event_handler.
*
*"======================================================================
*" 4. MONITORING (SCREEN 0600)
*"======================================================================
*
*DATA: go_container TYPE REF TO cl_gui_custom_container,
*      go_alv       TYPE REF TO cl_gui_alv_grid.
*
*TYPES: BEGIN OF ty_so_monitoring,
*         status   TYPE char20,     " COMPLETED / DELIVERY CREATED / BILLED / PGI DONE
*         vbeln    TYPE vbak-vbeln, " SO number
*         auart    TYPE vbak-auart, " Order type
*         erdat    TYPE vbak-erdat, " Created
*         vdatu    TYPE vbak-vdatu, " Requested Delivery Date
*         vkorg    TYPE vbak-vkorg,
*         vtweg    TYPE vbak-vtweg,
*         spart    TYPE vbak-spart,
*         sold_to  TYPE char60,     " Sold-to name (converted from KNA1)
*         posnr    TYPE vbap-posnr, " Item
*         matnr    TYPE vbap-matnr,
*         kwmeng   TYPE vbap-kwmeng,
*         vrkme    TYPE vbap-vrkme,
*         netwr    TYPE vbap-netwr,
*         waerk    TYPE vbak-waerk,
*       END OF ty_so_monitoring.
*
*DATA: gt_data TYPE STANDARD TABLE OF ty_so_monitoring,
*      gs_data TYPE ty_so_monitoring.
*
*"======================================================================
*" 5. TRACKING GRAPH (SCREEN 0500 – HTML + IMAGES)
*"======================================================================
*
*DATA: go_html_container TYPE REF TO cl_gui_custom_container,
*      go_html_viewer    TYPE REF TO cl_gui_html_viewer.
*
*"======================================================================
*" 6. TRACKING TAB (SCREEN 0700)
*"======================================================================
*
*CONTROLS: TAB_MAIN TYPE TABSTRIP.
*DATA: G_CURRSU_TAB TYPE CHAR10 VALUE 'FITEM'.   " Tab Item default
*
*TYPES: BEGIN OF ty_tracking,
*         process_phase       TYPE char30,  " SALES ORDER / DELIVERY / BILLING / FI
*         sales_document      TYPE vbeln_va,
*         delivery_document   TYPE vbeln_vl,
*         billing_document    TYPE vbeln_vf,
*         order_type          TYPE auart,
*         document_date       TYPE erdat,
*         sales_org           TYPE vkorg,
*         distr_chan          TYPE vtweg,
*         division            TYPE spart,
*         sold_to_party       TYPE kunnr,
*         net_value           TYPE netwr,
*         currency            TYPE waers,
*         req_delivery_date   TYPE edatu,
*         error_msg           TYPE string,  " Error từ BAPI hoặc status
*         created_by          TYPE ernam,
*         phase_icon          TYPE icon_d,  " icon: SO, DLV, PGI, BIL, FI
*         sel_box             TYPE c LENGTH 1, " Checkbox cho thao tác hàng loạt
*       END OF ty_tracking.
*
*DATA: gt_tracking TYPE STANDARD TABLE OF ty_tracking,
*      gs_tracking TYPE ty_tracking.
*
*"======================================================================
*" 7. VBFA LINK (SO → DLV → BIL)
*"======================================================================
*
*TYPES: BEGIN OF ty_vbfa_link,
*         vbelv   TYPE vbfa-vbelv,      " Preceding document (SO)
*         vbeln   TYPE vbfa-vbeln,      " Subsequent document (Delivery/Billing)
*         vbtyp_n TYPE vbfa-vbtyp_n,    " Type of subsequent document
*       END OF ty_vbfa_link.
*
*DATA: lt_delv TYPE TABLE OF ty_vbfa_link,
*      ls_delv TYPE ty_vbfa_link,
*      lt_bil  TYPE TABLE OF ty_vbfa_link,
*      ls_bil  TYPE ty_vbfa_link.
*
*"======================================================================
*" 8. STATUS FLAGS CHO TỪNG PHASE
*"======================================================================
*
*DATA: lv_has_delv            TYPE abap_bool,
*      lv_has_delv_not_pgi    TYPE abap_bool,
*      lv_has_pgi_no_billing  TYPE abap_bool,
*      lv_has_billing_no_fi   TYPE abap_bool,
*      lv_has_billing_with_fi TYPE abap_bool,
*      lv_so_reject           TYPE abap_bool.
*
*"======================================================================
*" 9. DELIVERY / BILLING / FI Helper Variables
*"======================================================================
*
*DATA: lv_wadat_ist TYPE likp-wadat_ist,   " Actual GI date
*      lv_faksk     TYPE vbak-faksk,       " Rejection status
*      lv_belnr_fi  TYPE bkpf-belnr,       " Accounting document number
*      lv_awkey     TYPE bkpf-awkey.       " Key linking Billing → FI
*
*"======================================================================
*" 10. Search / Filter Variables (Tracking Tab)
*"======================================================================
*DATA:
*  gv_vbeln    TYPE vbak-vbeln,
*  gv_kunnr    TYPE vbak-kunnr,
*  gv_ernam    TYPE vbak-ernam,
*  gv_vkorg    TYPE vbak-vkorg,
*  gv_vtweg    TYPE vbak-vtweg,
*  gv_spart    TYPE vbak-spart,
*  gv_doc_date TYPE vbak-erdat.
*
*"======================================================================
*" 12. ERROR LOG FOR PGI POPUP
*"======================================================================
**DATA: go_summary_container TYPE REF TO cl_gui_custom_container,
**      go_summary_html      TYPE REF TO cl_dd_document.
*
*"======================================================================
*" BLOCK 9 – POPUP STRUCTURES (INCOMPLETION LOG + ERROR LOG)
*"======================================================================
*
*"======================================================================
*" 1. INCOMPLETION LOG STRUCTURE
*"======================================================================
*
*TYPES: BEGIN OF ty_incomp_log,
*         group_desc TYPE text40,   " Nhóm lỗi (Partner, Pricing, Delivery…)
*         cell_cont  TYPE text40,   " Field cụ thể bị thiếu (Material, Qty…)
*       END OF ty_incomp_log.
*
*TYPES: ty_t_incomp_log TYPE STANDARD TABLE OF ty_incomp_log WITH DEFAULT KEY.
*
*"======================================================================
*" 2. ERROR LOG STRUCTURE (GENERAL ERROR POPUP)
*"======================================================================
*
*TYPES: BEGIN OF ty_error_log,
*         icon    TYPE c LENGTH 4,   " @0A@, @08@, @0C@ (Message icon)
*         msgty   TYPE symsgty,      " I / W / E / A / S
*         msgno   TYPE symsgno,      " Số message
*         msgv1   TYPE symsgv1,      " Tham số 1
*         msgv2   TYPE symsgv2,
*         msgv3   TYPE symsgv3,
*         msgv4   TYPE symsgv4,
*         message TYPE string,       " Chuỗi thông báo hoàn chỉnh
*       END OF ty_error_log.
*
*TYPES: ty_t_error_log TYPE STANDARD TABLE OF ty_error_log WITH DEFAULT KEY.
*
*"======================================================================
*" 3. POPUP ALV FIELD CATALOG
*"======================================================================
*DATA: gt_fieldcat_popup TYPE slis_t_fieldcat_alv.
*
*"======================================================================
*" BLOCK 10 – HELPER VARIABLES, FILTERS, DROPDOWNS, FIELDCAT, LAYOUT, CONTAINERS
*"======================================================================
*
*"======================================================================
*" 1. MODE FLAGS (Edit/Display Mode)
*"======================================================================
*
*DATA: gv_mode   TYPE string.        " Chế độ chạy tổng quát (nếu cần)
*DATA: gs_edit   TYPE abap_bool.     " 'X' = Edit Mode, ' ' = Display Mode
*
*"======================================================================
*" 2. HEADER/ITEM TOGGLING FLAGS (Mass Upload Validation UI)
*"======================================================================
*
*DATA: gv_flag_header TYPE abap_bool VALUE abap_true,   " Default: show Header ALV
*      gv_flag_item   TYPE abap_bool VALUE abap_true.   " Default: show Item ALV
*
*"======================================================================
*" 3. GRID TITLE, LAYOUT & VARIANT
*"======================================================================
*
*DATA: gv_grid_title TYPE lvc_title,   " Title cho grid ALV
*      gs_layout     TYPE lvc_s_layo,  " Layout chuẩn của LVC ALV (colors, zebra…)
*      gs_variant    TYPE disvariant.  " Lưu variant người dùng (nếu cho phép)
*
*"======================================================================
*" 4. GRID TOOLBAR EXCLUSION (Ẩn nút ALV)
*"======================================================================
*
*DATA: gt_exclude TYPE ui_functions.    " Danh sách nút ALV cần ẩn
*
*"======================================================================
*" 5. SORTING & FILTERING STRUCTURES
*"======================================================================
*
*DATA: gt_sort   TYPE lvc_t_sort,     " ALV sorting rules
*      gt_filter TYPE lvc_t_filt.     " ALV filtering rules
*
*"======================================================================
*" 6. GENERAL FIELDCAT (Dynamic Build)
*"======================================================================
*
*DATA: gt_fieldcat TYPE lvc_t_fcat.    " Field catalog build tạm thời
*
*"======================================================================
*" 7. FILTER FIELDS (Screen Painter Input Fields – VERY IMPORTANT)
*"======================================================================
*
*DATA:
*  FROM_DAT  TYPE dats,      " From Date filter
*  TO_DAT    TYPE dats,      " To Date filter
*  SALES_ORD TYPE vbeln_va,  " Sales Order filter (single)
*  SOLD_TO   TYPE kunnr,     " Sold-to filter
*  MATERIAL  TYPE matnr,     " Material filter
*  SALE_ORG  TYPE vkorg,     " Sales Org filter
*  DIST_CHAN TYPE vtweg,     " Distribution Channel filter
*  DIVI      TYPE spart,     " Division filter
*  STATUS    TYPE char20.    " Status filter (Created/Incomplete/Error)
*
*"======================================================================
*" 8. OUTPUT TOTALS (Footer Result Summary)
*"======================================================================
*
*DATA:
*  TO_STA TYPE char20,    " Status label hiển thị dưới ALV
*  TOSO   TYPE int4,      " Total số Sales Orders
*  TO_VAL TYPE netwr.     " Total Net Value toàn SO
*
*"======================================================================
*" 9. FLAG CHO MONITOR TAB (Load First Time)
*"======================================================================
*
*DATA: gv_monitor_first_load TYPE abap_bool VALUE abap_true.
*
*"======================================================================
*" 10. PGI TABSTRIP DECLARATION
*"======================================================================
*
**&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_PGI'
*CONSTANTS: BEGIN OF C_TS_PGI,
*             TAB1 LIKE SY-UCOMM VALUE 'TS_PGI_FC1',
*             TAB2 LIKE SY-UCOMM VALUE 'TS_PGI_FC2',
*           END OF C_TS_PGI.
*
*CONTROLS: TS_PGI TYPE TABSTRIP.
*
*DATA: BEGIN OF G_TS_PGI,
*        SUBSCREEN   LIKE SY-DYNNR,
*        PROG        LIKE SY-REPID VALUE 'ZSD4_MASS_PROC',
*        PRESSED_TAB LIKE SY-UCOMM VALUE C_TS_PGI-TAB1,
*      END OF G_TS_PGI.
*
*"======================================================================
*" 11. IMAGE CONTAINERS FOR SCREEN 0600 (GRAPH)
*"======================================================================
*
*DATA: go_container1 TYPE REF TO cl_gui_custom_container,
*      go_picture1   TYPE REF TO cl_gui_picture,
*      go_container2 TYPE REF TO cl_gui_custom_container,
*      go_picture2   TYPE REF TO cl_gui_picture.
*
*"======================================================================
*" 12. FIELDCAT & LAYOUT CHO DELIVERY FLOW / TRACKING
*"======================================================================
*
*DATA: gt_fcat     TYPE lvc_t_fcat,
*      gs_layout1  TYPE lvc_s_layo,
*      gt_exclude1 TYPE ui_functions.
*
*"======================================================================
*" 13. HANDLER CHO TAB TRACKING
*"======================================================================
*
*DATA: go_event_handler_track TYPE REF TO lcl_event_handler.
*
*"======================================================================
*" 14. "SUMMARY BOX" (HTML Render)
*"======================================================================
*
**DATA: go_summary_container TYPE REF TO cl_gui_custom_container,
**      go_summary_html      TYPE REF TO cl_dd_document.
*
*"======================================================================
*" 15. FILE PATH FOR UPLOAD SCREEN 0120
*"======================================================================
*
*DATA: gv_filepath TYPE rlgrap-filename.   " P_FILE-SCREEN 0120
*
*"======================================================================
*" 16. CONTAINERS FOR PGI (Main Screen)
*"======================================================================
**
**DATA: go_cont_pgi TYPE REF TO cl_gui_custom_container,
**      go_grid_pgi TYPE REF TO cl_gui_alv_grid.
*
*"======================================================================
*" 17. SAVE LIPS DATA WHEN NECESSARY
*"======================================================================
*
*DATA: lt_lips_global TYPE TABLE OF lips. " Lưu item của delivery để thao tác PGI

*--------------------------------------------------------------------*
* [HOME CENTER] GLOBAL DATA DEFINITION
* Prefix: HC (Home Center) to avoid conflicts with Main Program
*--------------------------------------------------------------------*
TYPE-POOLS: icon.

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
*&           REPORT MONITORING
*&---------------------------------------------------------------------*

* 1. TABLES
TABLES: vbap.

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
         gbstk_txt TYPE char20,
         t_color   TYPE lvc_t_scol,
       END OF ty_alv_sd4.

" Dữ liệu hiển thị trên ALV
DATA: gt_alv_sd4    TYPE TABLE OF ty_alv_sd4.
" Dữ liệu gốc (để tính KPI/Chart không bị mất khi lọc)
DATA: gt_static_sd4 TYPE TABLE OF ty_alv_sd4.

* 3. DATA CHO CHART
TYPES: BEGIN OF ty_org_sd4,
         vkorg        TYPE vbak-vkorg,
         total_orders TYPE i,
       END OF ty_org_sd4.
DATA: gt_chart_sd4 TYPE STANDARD TABLE OF ty_org_sd4.

* 4. KPI VARIABLES
DATA: gv_kpi_total_sd4 TYPE i,
      gv_kpi_rev_sd4   TYPE p DECIMALS 2.

* 5. GUI OBJECTS (Đổi tên để không trùng với các màn hình khác)
DATA: go_cc_report    TYPE REF TO cl_gui_custom_container, " <-- Target Container
      go_split_sd4    TYPE REF TO cl_gui_splitter_container.

DATA: go_c_top_sd4    TYPE REF TO cl_gui_container,
      go_c_mid_sd4    TYPE REF TO cl_gui_container,
      go_c_bot_sd4    TYPE REF TO cl_gui_container.

DATA: go_html_kpi_sd4 TYPE REF TO cl_gui_html_viewer,
      go_html_cht_sd4 TYPE REF TO cl_gui_html_viewer,
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
