*&------------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_TOP
*&------------------------------------------------------------------------*
* Description:  Global Data Declarations & Selection Screens
* Application:  Mass Upload Sales Order & Auto Outbound Delivery Execution
*&------------------------------------------------------------------------*

TYPE-POOLS: icon.
INCLUDE <icon>.

*----------------------------------------------------------------------*
* COMMON DECLARATIONS
*----------------------------------------------------------------------*
TABLES: vbak, vbap, vbep, kna1.

DATA: ok_code TYPE sy-ucomm,
      save_ok TYPE sy-ucomm.

* IMPORTANT: Forward declarations allow referencing classes defined in F00
CLASS lcl_hc_event_handler  DEFINITION DEFERRED.
CLASS lcl_mu_event_handler DEFINITION DEFERRED.
CLASS lcl_event_handler DEFINITION DEFERRED.
CLASS lcl_event_handler_0430 DEFINITION DEFERRED.

*======================================================================*
* SCOPE: SCREEN 0100 - HOME CENTER (Prefix: _HC_)
*======================================================================*

* 1. HC: Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_hc_alv_display,
         status_icon TYPE char4,          " Visual Indicator
         vbeln       TYPE vbak-vbeln,     " Sales Document
         auart       TYPE vbak-auart,     " Document Type
         erzet       TYPE vbak-erzet,     " Creation Time
         sales_area  TYPE string,         " Concatenated Sales Area
         ernam       TYPE vbak-ernam,     " Created By
         netwr       TYPE vbak-netwr,     " Net Value
         waerk       TYPE vbak-waerk,     " Currency
         gbstk       TYPE vbak-gbstk,     " Status Key
         gbstk_txt   TYPE string,         " Status Description
       END OF ty_hc_alv_display.

* 2. HC: GUI Controls
*----------------------------------------------------------------------*
DATA: go_hc_container TYPE REF TO cl_gui_custom_container,   " Main Container (0100)
      go_hc_splitter  TYPE REF TO cl_gui_splitter_container, " Layout Splitter

      go_hc_cont_top  TYPE REF TO cl_gui_container,          " Top Container (KPI Section)
      go_hc_cont_bot  TYPE REF TO cl_gui_container.          " Bottom Container (ALV Section)

DATA: go_hc_html TYPE REF TO cl_gui_html_viewer,        " KPI Dashboard
      go_hc_alv  TYPE REF TO cl_gui_alv_grid.           " Order List

* 3. HC: Business Data
*----------------------------------------------------------------------*
DATA: gv_hc_total_so TYPE i,            " Metric: Total Orders
      gv_hc_pending  TYPE i,            " Metric: Pending Orders
      gv_hc_pgi      TYPE i,            " Metric: Completed Orders
      gv_hc_net_val  TYPE p DECIMALS 2, " Metric: Net Value
      gv_hc_net_disp TYPE string.       " Metric: Display String

DATA: gt_hc_alv_data   TYPE TABLE OF ty_hc_alv_display.
DATA: go_hc_handler    TYPE REF TO lcl_hc_event_handler.

*======================================================================*
* SCOPE: SCREEN 0200 - MASS UPLOAD CENTER
*======================================================================*
* 1. Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_header.
         INCLUDE TYPE ztb_so_upload_hd. " Bảng Header Staging
TYPES:   icon     TYPE icon-internal,   " Đèn tín hiệu (Xanh/Đỏ/Vàng)
         celltab  TYPE lvc_t_scol,      " Tô màu từng ô (Cell Color)
         rowcolor TYPE char4,           " Tô màu cả dòng (Row Color)
         err_btn  TYPE icon-internal,
       END OF ty_header.
TYPES ty_t_header TYPE STANDARD TABLE OF ty_header WITH DEFAULT KEY.

TYPES: BEGIN OF ty_item.
         INCLUDE TYPE ztb_so_upload_it.
TYPES:   icon     TYPE icon-internal,
         celltab  TYPE lvc_t_scol,
         rowcolor TYPE char4,
         err_btn  TYPE icon-internal,
       END OF ty_item.
TYPES ty_t_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

TYPES: BEGIN OF ty_condition.
         INCLUDE TYPE ztb_so_upload_pr.
TYPES:   icon     TYPE icon-internal,
         rowcolor TYPE char4,
         celltab  TYPE lvc_t_scol,
         err_btn  TYPE icon-internal,
       END OF ty_condition.

*----------------------------------------------------------------------*
* INTERNAL TABLES
*----------------------------------------------------------------------*
" --- Tab 1: Validated ----
DATA: gt_hd_val TYPE TABLE OF ty_header,
      gt_it_val TYPE TABLE OF ty_item,
      gt_pr_val TYPE TABLE OF ty_condition.

" --- Tab 2: Posted Success ---
DATA: gt_hd_suc TYPE TABLE OF ty_header,
      gt_it_suc TYPE TABLE OF ty_item,
      gt_pr_suc TYPE TABLE OF ty_condition.

" --- Tab 3: Posted Failed  ---
DATA: gt_hd_fail TYPE TABLE OF ty_header,
      gt_it_fail TYPE TABLE OF ty_item,
      gt_pr_fail TYPE TABLE OF ty_condition.

*----------------------------------------------------------------------*
* GLOBAL DATA
*----------------------------------------------------------------------*
" --- Variables for HTML Welcome Screen ---
DATA: go_summary_container TYPE REF TO cl_gui_custom_container, " Container to contain html
      go_html_viewer       TYPE REF TO cl_gui_html_viewer.      " HTML Displayer

" --- Variables for upload file and load data to ALV ---
DATA:      gv_current_req_id TYPE zsd_req_id. " The global variable stores the ID of the current upload.
DATA:      gv_data_loaded    TYPE abap_bool.

*======================================================================*
* SCOPE: SCREEN 0210 - MASS UPLOAD (Prefix: _MU_)
*======================================================================*

* 1. MU: Type Definitions
*----------------------------------------------------------------------*
* Structure for Tree Nodes Data (To verify Header vs Item logic)
TYPES: BEGIN OF ty_mu_tree_data,
         node_key TYPE tv_nodekey,
         relatkey TYPE tv_nodekey,
         text     TYPE text50,
         is_item  TYPE char1, " ' ' = Header, 'X' = Item
       END OF ty_mu_tree_data.

* 1.1. MU: Type Definitions
*----------------------------------------------------------------------*
* Structure for Header
TYPES: BEGIN OF ty_mu_header_ext.
*         INCLUDE TYPE ztb_so_upload_hd.
         INCLUDE TYPE ZSTR_MU_HEADER.
TYPES:   icon     TYPE icon-internal,
         rowcolor TYPE char4,
       END OF ty_mu_header_ext.

* 1.2. MU: Type Definitions
*----------------------------------------------------------------------*
* Structure for Item
TYPES: BEGIN OF ty_mu_item_ext.
*         INCLUDE TYPE ztb_so_upload_it.
         INCLUDE TYPE ZSTR_MU_ITEM.
*TYPES:   icon       TYPE icon-internal,
*         rowcolor   TYPE char4,
*         celltab    TYPE lvc_t_scol,
*         cell_style TYPE lvc_t_styl,
*         err_btn    TYPE icon-internal,
 TYPES:   END OF ty_mu_item_ext.

* 1.3. MU: Type Definitions
*----------------------------------------------------------------------*
* Structure for Condition
TYPES: BEGIN OF ty_mu_cond_ext.
         INCLUDE TYPE ZSTR_MU_COND.
*TYPES:   icon       TYPE icon-internal,
*         rowcolor   TYPE char4,
*         celltab    TYPE lvc_t_scol,
*         cell_style TYPE lvc_t_styl,
*         err_btn    TYPE icon-internal,
TYPES:  END OF ty_mu_cond_ext.

* 2. MU: GUI Controls
*----------------------------------------------------------------------*
DATA: go_mu_docking   TYPE REF TO cl_gui_docking_container, " Tree Container (Left)
      go_mu_tree      TYPE REF TO cl_gui_simple_tree,       " Tree Control

      " Containers for Right Side Subscreens
      go_mu_cont_head TYPE REF TO cl_gui_custom_container,  " Container in Screen 211
      go_mu_cont_item TYPE REF TO cl_gui_custom_container.  " Container in Screen 212

DATA: go_mu_alv_items TYPE REF TO cl_gui_alv_grid,          " ALV for Header Items
      go_mu_alv_cond  TYPE REF TO cl_gui_alv_grid.          " ALV for Item Conditions

DATA: gv_prev_node_key TYPE tv_nodekey.

* 3. MU: Validation Summary Container
*----------------------------------------------------------------------*
DATA: go_mu_docking_top TYPE REF TO cl_gui_docking_container, " Validation Summary Container (Top)
      go_mu_html_top    TYPE REF TO cl_gui_html_viewer.

* Global Counters
DATA: gv_cnt_total  TYPE i,
      gv_cnt_ready  TYPE i, " Mới upload, chưa validate
      gv_cnt_valid  TYPE i, " Validate OK
      gv_cnt_error  TYPE i, " Validate Lỗi
      gv_cnt_posted TYPE i, " Đã tạo SO thành công
      gv_cnt_failed TYPE i. " Post BAPI bị lỗi

* 4. MU: Screen Control & Business Data
*----------------------------------------------------------------------*
DATA: gv_mu_subscreen  TYPE sy-dynnr VALUE '0211'. " Dynamic Subscreen (Default Header)

* Data Structures for Screen Binding (Must match Screen Painter Names)
DATA: gs_mu_header TYPE ty_mu_header_ext,
      gs_mu_item   TYPE ty_mu_item_ext.

* [B] DATA STORE (Internal Tables)
DATA: gt_mu_header TYPE TABLE OF ty_mu_header_ext,
      gt_mu_item   TYPE TABLE OF ty_mu_item_ext,
      gt_mu_cond   TYPE TABLE OF ty_mu_cond_ext.

DATA: gt_disp_items TYPE TABLE OF ty_mu_item_ext, " Item của 1 Header
      gt_disp_cond  TYPE TABLE OF ty_mu_cond_ext. " Cond của 1 Item

DATA: gt_mu_tree_nodes TYPE TABLE OF ty_mu_tree_data. " Tree Logic Data
DATA: go_mu_handler    TYPE REF TO lcl_mu_event_handler.

* 5. MU: Event Handlers
*----------------------------------------------------------------------*
DATA: go_event_mu_items TYPE REF TO lcl_event_handler, " Handle Edit/Click for Item
      go_event_mu_cond  TYPE REF TO lcl_event_handler. " Handle Edit/Click for Condition

* 5. MU: Field Catalog & Layout Variables
*----------------------------------------------------------------------*
DATA: gt_fcat_item TYPE lvc_t_fcat, " Fieldcat for Item
      gt_fcat_cond TYPE lvc_t_fcat. " Fieldcat for Condition

DATA: gs_edit TYPE abap_bool.

DATA: gs_layout     TYPE lvc_s_layo,     " Layout chung
      gs_variant    TYPE disvariant,     " Variant lưu cấu hình
      gt_exclude    TYPE ui_functions,   " Các nút cần ẩn
      gv_grid_title TYPE lvc_title.      " Tiêu đề Grid

DATA: go_grid_monitoring TYPE REF TO cl_gui_alv_grid,
      go_grid_pgi_all    TYPE REF TO cl_gui_alv_grid.

DATA: gt_fieldcat_item_single TYPE lvc_t_fcat,
      gt_fieldcat_conds       TYPE lvc_t_fcat,
      gt_fieldcat_monitoring  TYPE lvc_t_fcat,
      gt_fieldcat_pgi_all     TYPE lvc_t_fcat.

DATA: go_event_handler_moni TYPE REF TO lcl_event_handler,
      go_event_pgi_all      TYPE REF TO lcl_event_handler.

* 6. MU: Validation & Errors Highlight
*----------------------------------------------------------------------*
" Bảng lưu danh sách tên các Input Field bị lỗi để tô màu màn hình
DATA: gt_screen_err_fields TYPE TABLE OF fieldname.

" Cấu trúc Mapping tên trường (DB -> Screen Field)
TYPES: BEGIN OF ty_field_map,
         db_field  TYPE fieldname, " Tên trong bảng Log (DB)
         scr_field TYPE fieldname, " Tên trên màn hình (GS_MU_...)
       END OF ty_field_map.

*======================================================================*
* SCOPE: SCREEN 300 - SINGLE UPLOAD HEADER ENTRY
*======================================================================*
* 1. SU: Type Definitions
*----------------------------------------------------------------------*
DATA: gv_cursor_field     TYPE fieldname.   " Biến lưu vị trí con trỏ
DATA: gs_so_heder_ui      TYPE zstr_so_heder_ui.
DATA: gv_so_just_created  TYPE abap_bool.   " Cờ: 'X' = Vừa tạo SO thành công
DATA: gv_single_mode      TYPE char10.      " Biến chứa chế độ: 'CREATE' hoặc 'EDIT'
DATA: gv_screen_state     TYPE c VALUE '0'. " 0=Mới vào, 1=Đã nhập Sold-to

" Dùng 1 biến global để check chạy lần đầu
DATA: gv_first_run        TYPE c VALUE 'X'.
DATA: gv_data_saved       TYPE char1.       " Cờ báo hiệu: 'X' nếu Save thành công, '' nếu thất bại
DATA: gv_order_type       TYPE auart.

* 2. SU: Structure for Tree Nodes Data (To verify Header vs Item logic)
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_item_details.
         INCLUDE TYPE zstr_su_alv_item.
" Thêm các trường ALV-helper (không có trong DB)
*  TYPES:   icon        TYPE icon-internal,
*           status_code TYPE c LENGTH 1,
*           status_text TYPE char20,
*           message     TYPE string,
*           style       TYPE lvc_t_styl,
*           celltab     TYPE lvc_t_scol,
*           rowcolor    TYPE char4.
TYPES: END OF ty_item_details.

TYPES ty_t_item_details TYPE STANDARD TABLE OF ty_item_details WITH DEFAULT KEY.
DATA: gt_item_details TYPE ty_t_item_details.

TYPES: BEGIN OF ty_incomp_log,
         group_desc TYPE text40,
         cell_cont  TYPE text40,
       END OF ty_incomp_log.
TYPES: ty_t_incomp_log TYPE STANDARD TABLE OF ty_incomp_log WITH DEFAULT KEY.

TYPES: BEGIN OF ty_cond_alv.
         INCLUDE TYPE zstr_so_cond_ui.
" Các trường bổ sung cho logic tính toán & hiển thị ---
*        TYPES:
*          kwert       TYPE kwert,
*        " Các trường Helper của ALV ---
*          icon        TYPE icon-internal,
*          status_code TYPE c LENGTH 1,
*          status_text TYPE char20,
*          message     TYPE string,
*
*          cell_style  TYPE lvc_t_styl,
*          celltab     TYPE lvc_t_scol,
*          rowcolor    TYPE char4.
TYPES: END OF ty_cond_alv.
TYPES: ty_t_cond_alv TYPE STANDARD TABLE OF ty_cond_alv WITH DEFAULT KEY.

DATA: gt_conditions_alv     TYPE ty_t_cond_alv.

TYPES: BEGIN OF ty_cond_cache,
         item_no    TYPE posnr_va,       " Khóa chính: Số Item
         conditions TYPE ty_t_cond_alv,  " Bảng chứa các dòng Condition (ZPRQ, ZDRP...)
       END OF ty_cond_cache.

" 2. Khai báo biến Global
DATA: gt_cond_cache TYPE HASHED TABLE OF ty_cond_cache
                    WITH UNIQUE KEY item_no.

* 3. SU:  Event Handlers
*----------------------------------------------------------------------*
DATA: go_event_handler_single TYPE REF TO lcl_event_handler,
      go_event_handler_conds  TYPE REF TO lcl_event_handler.

* 4. SU: Field Catalog & Layout Variables
*----------------------------------------------------------------------*
DATA: go_grid_item_single     TYPE REF TO cl_gui_alv_grid.
DATA: go_cont_item_single TYPE REF TO cl_gui_custom_container,
      go_cont_conditions  TYPE REF TO cl_gui_custom_container,
      go_grid_conditions  TYPE REF TO cl_gui_alv_grid.

DATA: gv_current_item_idx     TYPE sy-tabix VALUE 1. " Con trỏ item (1, 2, 3...)

*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_MAIN'
CONSTANTS: BEGIN OF c_ts_main,
             tab1 LIKE sy-ucomm VALUE 'TS_MAIN_FC1',
             tab2 LIKE sy-ucomm VALUE 'TS_MAIN_FC2',
*             TAB3 LIKE SY-UCOMM VALUE 'TS_MAIN_FC3',
           END OF c_ts_main.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_MAIN'
CONTROLS:  ts_main TYPE TABSTRIP.
DATA: BEGIN OF g_ts_main,
        subscreen   LIKE sy-dynnr,
        prog        LIKE sy-repid VALUE 'ZSD4_PROGRAM',
        pressed_tab LIKE sy-ucomm VALUE c_ts_main-tab1,
      END OF g_ts_main.

*&SPWIZARD: FUNCTION CODES FOR TABSTRIP 'TS_VALI'
CONSTANTS: BEGIN OF c_ts_vali,
             tab1 LIKE sy-ucomm VALUE 'TS_VALI_FC1',
             tab2 LIKE sy-ucomm VALUE 'TS_VALI_FC2',
             tab3 LIKE sy-ucomm VALUE 'TS_VALI_FC3',
           END OF c_ts_vali.
*&SPWIZARD: DATA FOR TABSTRIP 'TS_VALI'
CONTROLS:  ts_vali TYPE TABSTRIP.
DATA: BEGIN OF g_ts_vali,
        subscreen   LIKE sy-dynnr,
        prog        LIKE sy-repid VALUE 'ZSD4_PROGRAM',
        pressed_tab LIKE sy-ucomm VALUE c_ts_vali-tab1,
      END OF g_ts_vali.

*&---------------------------------------------------------------------*
*& SCREEN 500 - Tracking Screen
*&---------------------------------------------------------------------*
TYPE-POOLS: icon.
"==========================================================
"   TABLES declarations for DDIC reference (avoid unknown field errors)
"==========================================================
*TABLES: vbak, likp, vbrk, vbfa, bkpf.
TABLES: likp, vbrk, vbfa, bkpf.

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
         creation_time     TYPE erzet,
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
DATA: go_container1 TYPE REF TO cl_gui_custom_container,
      go_alv        TYPE REF TO cl_gui_alv_grid,
      gt_fcat       TYPE lvc_t_fcat.
*      gs_layout     TYPE lvc_s_layo,
*      gt_exclude    TYPE ui_functions.

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
  gv_doc_date TYPE vbak-erdat,
  gv_deliv    TYPE vbeln_vl, " Delivery Document for Search
  gv_bill     TYPE vbeln_vf. " Billing Document for Search


DATA: gv_jobname TYPE tbtcjob-jobname VALUE 'Z_AUTO_DELIV_PROTOTYPE'.

DATA: gv_sarea TYPE char20. " Biến gộp cho Sales Area
*
" Thêm dòng này vào TRƯỚC dòng DATA
CLASS lcl_event_handler1 DEFINITION DEFERRED.

" Dòng code cũ của bạn
DATA: gr_event_handler1 TYPE REF TO lcl_event_handler1.

*&---------------------------------------------------------------------*
*&           SCREEN 0400: REPORT MONITORING
*&---------------------------------------------------------------------*

* 2. STRUCTURE DỮ LIỆU (Thêm hậu tố _SD4)
TYPES: BEGIN OF ty_alv_sd4,
         vbeln       TYPE vbak-vbeln,
         auart       TYPE vbak-auart,
         audat       TYPE vbak-audat,
         vdatu       TYPE vbak-vdatu,
         vkorg       TYPE vbak-vkorg,
         vtweg       TYPE vbak-vtweg,
         spart       TYPE vbak-spart,
         kunnr       TYPE vbak-kunnr,
         bstnk       TYPE vbak-bstnk,
         gbstk       TYPE vbak-gbstk,
         waerk       TYPE vbak-waerk,
         name1       TYPE kna1-name1,
         posnr       TYPE vbap-posnr,
         matnr       TYPE vbap-matnr,
         kwmeng      TYPE vbap-kwmeng,
         vrkme       TYPE vbap-vrkme,
         netwr_i     TYPE vbap-netwr,
         req_qty_i   TYPE vbep-wmeng,
         gbstk_txt   TYPE char35,
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
DATA: go_cc_report TYPE REF TO cl_gui_custom_container, " <-- Target Container
      go_split_sd4 TYPE REF TO cl_gui_splitter_container.

DATA: go_c_top_sd4 TYPE REF TO cl_gui_container,
*      go_c_mid_sd4    TYPE REF TO cl_gui_container,
      go_c_bot_sd4 TYPE REF TO cl_gui_container.

DATA: go_html_kpi_sd4 TYPE REF TO cl_gui_html_viewer,
*      go_html_cht_sd4 TYPE REF TO cl_gui_html_viewer,
      go_alv_sd4      TYPE REF TO cl_gui_alv_grid.

" Cờ kiểm soát Search
DATA: gv_exec_srch_sd4 TYPE char1.

* 6. SUBSCREEN SEARCH (0801)
SELECTION-SCREEN BEGIN OF SCREEN 0410 AS SUBSCREEN.
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
SELECTION-SCREEN END OF SCREEN 0410.

*&---------------------------------------------------------------------*
*&               Screen 0430 DECLARATIONS.
*&---------------------------------------------------------------------*
DATA: go_cc_dashboard_0430 TYPE REF TO cl_gui_custom_container,
      go_viewer_0430       TYPE REF TO cl_gui_html_viewer.

CONSTANTS: lc_million TYPE p DECIMALS 2 VALUE 1000000.

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
