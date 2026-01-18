*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_O01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'ST0100'.
  SET TITLEBAR 'T0100'.

  PERFORM hc_display_dashboard.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0200 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'ST0200'. " Create two application buttons: Upload File and Download Mass Upload Template
  SET TITLEBAR 'T0200'.   " Title: Mass Upload Sales Order
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module INIT_WELCOME_SCREEN OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE init_welcome_screen OUTPUT.
  " Display HTML Welcome using Custom Container
  IF go_summary_container IS INITIAL.
    CREATE OBJECT go_summary_container
      EXPORTING
        container_name = 'CC_SUMMARY'.

    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = go_summary_container.

    PERFORM display_welcome_screen. " Form HTML cũ của bạn
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0210 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0210 OUTPUT.
  SET PF-STATUS 'ST0210'.
  SET TITLEBAR 'T0210'.

  " Khởi tạo Container (Chỉ chạy 1 lần)
  IF go_mu_docking_top IS INITIAL.
    CREATE OBJECT go_mu_docking_top
      EXPORTING
        side      = cl_gui_docking_container=>dock_at_top
        extension = 50 " Chiều cao pixel (tùy chỉnh)
        repid     = sy-repid
        dynnr     = sy-dynnr.

    CREATE OBJECT go_mu_html_top
      EXPORTING
        parent = go_mu_docking_top.
  ENDIF.

  " Khởi tạo Container và Tree (Chỉ chạy 1 lần)
  IF go_mu_docking IS INITIAL.
    " 1. Tạo Docking bên trái
    CREATE OBJECT go_mu_docking
      EXPORTING
        side      = cl_gui_docking_container=>dock_at_left
        extension = 300.

    " 2. Tạo Cây
    CREATE OBJECT go_mu_tree
      EXPORTING
        parent              = go_mu_docking
        node_selection_mode = cl_gui_simple_tree=>node_sel_mode_single. "Only select 1 line

    " 3. Đăng ký sự kiện
    CREATE OBJECT go_mu_handler.
    SET HANDLER go_mu_handler->handle_node_double_click FOR go_mu_tree.

    " Tell the frontend that 'I want to capture the Double Click event'"
    DATA: lt_events TYPE cntl_simple_events.
    " This is a crucial part of making the tree interactive.
    " When a user double-clicks on a node (e.g., Node "Sales Order 1"),
    " the system triggers an event to display the details on the right.
    lt_events = VALUE #( ( eventid = cl_gui_simple_tree=>eventid_node_double_click appl_event = 'X' ) ).
    go_mu_tree->set_registered_events( events = lt_events ).

    " 4. Vẽ dữ liệu
    PERFORM build_tree_from_data.
  ENDIF.

  " It runs every time the screen is refreshed (for example, after pressing the Validate button).
  PERFORM update_status_counts_tree.
  PERFORM build_html_summary_tree.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0211 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0211 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.

  " -----------------------------------------------------------
  " LOCK CÁC FIELD HEADER KHÔNG CHO NHẬP (READ-ONLY)
  " -----------------------------------------------------------
  LOOP AT SCREEN.

    " Kiểm tra tên field trên màn hình (Lưu ý: Phải viết HOA toàn bộ)
    IF screen-name = 'GS_MU_HEADER-TEMP_ID'        OR
       screen-name = 'GS_MU_HEADER-SHIP_COND'      OR
       screen-name = 'GS_MU_HEADER-CURRENCY'       OR
       screen-name = 'GS_MU_HEADER-REQ_DATE'       OR
       screen-name = 'GS_MU_HEADER-PRICE_DATE'     OR
       screen-name = 'GS_MU_HEADER-ORDER_DATE'.

       screen-input = 0.  " 0 = Khóa (Read-only), 1 = Mở (Editable)
    ENDIF.
       " Tùy chọn: Làm tối màu đi để user biết là không nhập được
       " screen-intensified = 0.

    IF gs_mu_header-vbeln_so IS NOT INITIAL.

      " Dùng CP (Contains Pattern) để bắt tất cả các field thuộc Header
      IF screen-name CP '*GS_MU_HEADER*'.
         screen-input = 0. " Khóa toàn bộ
      ENDIF.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0212 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0212 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.

  " -----------------------------------------------------------
  " LOCK CÁC FIELD ITEM DETAIL (READ-ONLY)
  " -----------------------------------------------------------
  LOOP AT SCREEN.

    " Kiểm tra tên field (Phải viết HOA và đúng tên biến gán trong SE51)
    " Giả sử bạn đang bind dữ liệu vào structure GS_MU_ITEM
    IF screen-name = 'GS_MU_ITEM-SHORT_TEXT'   OR  " Mô tả
       screen-name = 'GS_MU_HEADER-SCHEDULE_DATE'     OR  " Ngày giao hàng
       screen-name = 'GS_MU_HEADER-KALSM'   OR  " Pricing Procedure
       screen-name = 'GS_MU_ITEM-UNIT'         OR  " Đơn vị tính
       screen-name = 'GS_MU_ITEM-ITEM_NO'.         " Số thứ tự Item

       screen-input = 0.  " Khóa lại (Chỉ xem)

       " Tùy chọn: Làm xám màu đi (như bị disable)
       " screen-intensified = 0.
    ENDIF.

    IF gs_mu_header-vbeln_so IS NOT INITIAL.

      " Khóa tất cả các field thuộc structure Item
      IF screen-name CP '*GS_MU_ITEM*'.
         screen-input = 0.
      ENDIF.

      " Nếu trong subscreen này có dính field của Header (ví dụ Schedule Date)
      IF screen-name CP '*GS_MU_HEADER*'.
         screen-input = 0.
      ENDIF.

    ENDIF.

    MODIFY SCREEN.

  ENDLOOP.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module MODIFY_SCREEN_HIGHLIGHT OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE modify_screen_highlight OUTPUT.
  LOOP AT SCREEN.
    " Kiểm tra xem tên field hiện tại có nằm trong danh sách lỗi không
    READ TABLE gt_screen_err_fields TRANSPORTING NO FIELDS
         WITH KEY table_line = screen-name.

    IF sy-subrc = 0.
      screen-intensified = '1'. " 1 = Màu đỏ (hoặc xanh đậm tùy theme, thường là nổi bật)
      " screen-color = 6. " (Chỉ hoạt động trên một số hệ thống cũ/đặc thù)
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0300 OUTPUT
*&---------------------------------------------------------------------*
*& Purpose: Define the User Interface state for Screen 0300 (PBO)
*&          - Set GUI Status (Menu, Buttons)
*&          - Set Title bar
*&          - Handle Cursor positioning
*&          - Initialize Command field (OK_CODE)
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
  " --- [1] SET INTERFACE ---
  SET PF-STATUS 'ST0300'.
  SET TITLEBAR  'T0300'.

  " --- [2] DYNAMIC CURSOR POSITIONING ---
  " Restore the cursor to the last active field (User Experience improvement)
  " gv_cursor_field is typically set in PAI user command
  IF gv_cursor_field IS NOT INITIAL.
    SET CURSOR FIELD gv_cursor_field.
  ENDIF.

  " --- [3] INITIALIZATION ---
  " Critical: Clear OK_CODE to prevent accidental re-triggering of the last action
  " when the user presses Enter or performs a generic screen refresh.
  CLEAR ok_code.

ENDMODULE.

*&SPWIZARD: OUTPUT MODULE FOR TS 'TS_MAIN'. DO NOT CHANGE THIS LINE!
*&---------------------------------------------------------------------*
*& Module TS_MAIN_ACTIVE_TAB_SET OUTPUT
*&---------------------------------------------------------------------*
*& Purpose: Tabstrip Control Logic (Wizard Generated)
*&          Determines which Subscreen to display based on the Active Tab.
*&---------------------------------------------------------------------*
*&SPWIZARD: SETS ACTIVE TAB
MODULE ts_main_active_tab_set OUTPUT.

  " Set the active tab attribute of the Tabstrip control
  ts_main-activetab = g_ts_main-pressed_tab.

  " Map the Pressed Tab ID to the corresponding Subscreen Number
  CASE g_ts_main-pressed_tab.
    WHEN c_ts_main-tab1.
      g_ts_main-subscreen = '0311'. " Subscreen for Header Data
    WHEN c_ts_main-tab2.
      g_ts_main-subscreen = '0312'. " Subscreen for Item Details
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0310 OUTPUT
*&---------------------------------------------------------------------*
*& Prepares the screen interface before display (PBO).
*& Refactored: Removed unused 'EDIT' mode, supports 'CREATE' only.
*&---------------------------------------------------------------------*
MODULE status_0310 OUTPUT.

  " --------------------------------------------------------------------
  " 1. Set Standard GUI Status & Titlebar
  " --------------------------------------------------------------------
  SET PF-STATUS 'ST0310'.
  SET TITLEBAR 'T0310'.

  " --------------------------------------------------------------------
  " 2. Dynamic GUI Adjustment
  " --------------------------------------------------------------------
  PERFORM pbo_screen_0310.

  " --------------------------------------------------------------------
  " 3. Screen Field Modification
  " --------------------------------------------------------------------
  " Lock/Unlock fields based on logic (Output-only vs Input fields)
  PERFORM pbo_modify_screen.

  " --------------------------------------------------------------------
  " 4. Data Initialization
  " --------------------------------------------------------------------
  PERFORM pbo_default_data.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Form  PBO_SCREEN_0310
*&---------------------------------------------------------------------*
* Process Before Output logic for Screen 0310.
* Handles dynamic GUI Status adjustments (Hiding/Showing buttons).
*----------------------------------------------------------------------*
FORM pbo_screen_0310 .

  " Internal table to store function codes that should be hidden
  DATA: lt_exclude TYPE TABLE OF sy-ucomm.

  " --------------------------------------------------------------------
  " Determine which buttons to exclude based on the application state
  " --------------------------------------------------------------------
  IF gv_so_just_created = abap_true.
    " CASE: Document successfully saved
    " Prevent duplicate saving by disabling the 'SAVE' button
    APPEND 'SAVE' TO lt_exclude.

  ELSE.
    " CASE: Normal Processing (Create/Edit Mode)
    " 'Tracking' is not available during initial entry
    APPEND 'TRCK' TO lt_exclude.

  ENDIF.

  " --------------------------------------------------------------------
  " Set GUI Status with the exclusion list
  " --------------------------------------------------------------------
  SET PF-STATUS 'ST0310' EXCLUDING lt_exclude.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PBO_MODIFY_SCREEN
*&---------------------------------------------------------------------*
* Modify screen attributes (input/output) dynamically at PBO.
* Implements locking logic for header fields based on entry state.
*----------------------------------------------------------------------*
FORM pbo_modify_screen .

  LOOP AT SCREEN.

    " --------------------------------------------------------------------
    " 1. GLOBAL LOCKS: Output-Only Fields (Always Disabled)
    " --------------------------------------------------------------------
    CASE screen-name.
      WHEN 'GS_SO_HEDER_UI-SO_HDR_VBELN'       OR  " Sales Document ID
           'GS_SO_HEDER_UI-SO_HDR_KAL_SM'      OR  " Pricing Procedure
           'GS_SO_HEDER_UI-SO_HDR_SOLD_ADRNR'  OR  " Sold-to Name
           'GS_SO_HEDER_UI-SO_HDR_SHIP_ADRNR'  OR  " Ship-to Name
           'GS_SO_HEDER_UI-SO_HDR_SALESAREA'   OR  " Sales Area Description
           'GS_SO_HEDER_UI-SO_HDR_AUART'.          " Order Type (Pre-filled, locked)

        screen-input = 0.
        MODIFY SCREEN.
        CONTINUE. " Skip subsequent logic for these fields

    " --------------------------------------------------------------------
    " 2. BYPASS CONTROLS: Tabstrip Elements
    " --------------------------------------------------------------------
      WHEN 'TS_MAIN_TAB1' OR 'TS_MAIN_TAB2' OR 'TS_MAIN_TAB3'.
        CONTINUE.
    ENDCASE.

    " --------------------------------------------------------------------
    " 3. DYNAMIC LOCKS: 'CREATE' Mode Logic (State-Dependent)
    " --------------------------------------------------------------------
    CASE gv_screen_state.

      " --- STATE '0': Initial Entry (Enter Org Data & Partner) ---
      WHEN '0'.
        CASE screen-name.
          WHEN 'GS_SO_HEDER_UI-SO_HDR_SOLD_ADDR'   OR  " Sold-to Party
               'GS_SO_HEDER_UI-SO_HDR_VKORG'       OR  " Sales Organization
               'GS_SO_HEDER_UI-SO_HDR_VTWEG'       OR  " Distribution Channel
               'GS_SO_HEDER_UI-SO_HDR_SPART'.          " Division
            screen-input = 1. " Enable key fields for initial input

          WHEN OTHERS.
            screen-input = 0. " Disable all other input fields
        ENDCASE.

      " --- STATE '1': Detail Entry (Enter Header Data) ---
      WHEN '1'.
        CASE screen-name.
          WHEN 'GS_SO_HEDER_UI-SO_HDR_BSTNK'       OR  " Customer Reference (PO)
               'GS_SO_HEDER_UI-SO_HDR_KETDAT'      OR  " Req. Delivery Date
               'GS_SO_HEDER_UI-SO_HDR_AUDAT'.          " Document Date
            screen-input = 1. " Enable editable header fields

          WHEN OTHERS.
            screen-input = 0. " Lock Org Data & Partner (Prevent changes)
        ENDCASE.

    ENDCASE.

    " Apply changes to the current screen element
    MODIFY SCREEN.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form pbo_default_data - 0310
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM pbo_default_data .
  " Nếu là lần chạy đầu tiên (chế độ tạo mới)
  IF gv_first_run = 'X'.
    " Tự động điền ngày hôm nay
    IF gs_so_heder_ui-so_hdr_audat IS INITIAL.
      gs_so_heder_ui-so_hdr_audat = sy-datum. " Document Date
    ENDIF.
    IF gs_so_heder_ui-so_hdr_prsdt IS INITIAL.
      gs_so_heder_ui-so_hdr_prsdt = sy-datum. " Pricing Date
    ENDIF.
    IF gs_so_heder_ui-so_hdr_fkdat IS INITIAL.
      gs_so_heder_ui-so_hdr_fkdat = sy-datum. " Billing Date
    ENDIF.

    CLEAR gv_first_run. " Xóa cờ, để lần Enter sau không chạy vào đây nữa
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0311 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0311 OUTPUT.
  " 1. Logic thêm dòng trống mặc định (QUAN TRỌNG)
  " Nếu bảng chưa có dòng nào, ta thêm ngay 1 dòng trống để user nhập
  IF gt_item_details IS INITIAL.
    APPEND INITIAL LINE TO gt_item_details.
  ENDIF.

  PERFORM prepare_single_item_styles.

  " 2. Gọi Form dựng ALV
  PERFORM build_alv_layout_single_item.

  " 3. Nếu Grid đã hiển thị rồi (sau sự kiện PAI), ta phải Refresh để nó hiện dòng mới thêm
  IF go_grid_item_single IS BOUND.
    DATA: ls_stable TYPE lvc_s_stbl.
    ls_stable-row = 'X'.
    ls_stable-col = 'X'.

    go_grid_item_single->refresh_table_display(
      EXPORTING
        is_stable = ls_stable ).

  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0312 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0312 OUTPUT.
  PERFORM build_conditions_alv.
  IF go_grid_conditions IS BOUND.
    " Kích hoạt sự kiện khi nhấn ENTER
    CALL METHOD go_grid_conditions->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_enter.

    " Kích hoạt sự kiện khi thay đổi dữ liệu (mất focus)
    CALL METHOD go_grid_conditions->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified.
  ENDIF.
  " ====================================================================
  PERFORM display_conditions_for_item USING gv_current_item_idx.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0500 OUTPUT
*&---------------------------------------------------------------------*
*&  Thiết lập PF-STATUS, gọi dropdown initialization
*&---------------------------------------------------------------------*
MODULE status_0500 OUTPUT.

  "1. Set GUI status and title
  SET PF-STATUS 'ST0500'.
* SET TITLEBAR 'ST_TITLE'.   "Tùy chọn nếu có titlebar riêng

  "2. Initialize dropdown values (từ include ZPG_216_SOF00)
  PERFORM set_dropdown_sales_status.
  PERFORM set_dropdown_delivery_status.
  PERFORM set_dropdown_billing_status.
  PERFORM set_dropdown_process_phase.

ENDMODULE.


MODULE display_tracking_alv OUTPUT.

  IF go_container1 IS INITIAL.
    CREATE OBJECT go_container1
      EXPORTING container_name = 'CC_TRACKING'.

    CREATE OBJECT go_alv
      EXPORTING i_parent = go_container1.

    " Đăng ký sự kiện (Giữ nguyên)
    IF gr_event_handler1 IS NOT BOUND.
      CREATE OBJECT gr_event_handler1.
    ENDIF.
    SET HANDLER gr_event_handler1->handle_double_click FOR go_alv.


    cb_sosta = 'ALL'.
    cb_ddsta = 'ALL'.
    cb_bdsta = 'ALL'.

    PERFORM load_tracking_data.
    PERFORM apply_phase_logic.
    PERFORM filter_process_phase.
    PERFORM filter_tracking_data.
    PERFORM filter_delivery_status.
    PERFORM filter_billing_status.

    " 3. Chuẩn bị Fieldcat (Giữ nguyên)
    PERFORM alv_prepare.

    " 4. Hiển thị lên màn hình
    CALL METHOD go_alv->set_table_for_first_display
      EXPORTING
        is_layout            = gs_layout
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_tracking
        it_fieldcatalog      = gt_fcat.

  ENDIF.

  " Giữ nguyên phần set_ready_for_input
  IF go_alv IS BOUND.
    CALL METHOD go_alv->set_ready_for_input
      EXPORTING i_ready_for_input = 1.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module MODIFY_SCREEN_FIELDS OUTPUT
*&---------------------------------------------------------------------*
MODULE modify_screen_fields OUTPUT.

  DATA: lv_input_flag TYPE c LENGTH 1.

  " 1. Quyết định trạng thái (Enabled/Disabled)
  IF cb_sosta = 'INC'.
    lv_input_flag = '0'. " 0 = Vô hiệu hóa (Disabled)
  ELSE.
    lv_input_flag = '1'. " 1 = Kích hoạt (Enabled)
  ENDIF.

  " 2. Áp dụng trạng thái cho 2 dropdown còn lại
  LOOP AT SCREEN.
    CASE screen-name.
      WHEN 'CB_DDSTA' OR 'CB_BDSTA'.
        screen-input = lv_input_flag.
        MODIFY SCREEN.
    ENDCASE.
  ENDLOOP.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0400  OUTPUT
*&---------------------------------------------------------------------*
* Process Before Output for Screen 0400 (Dashboard Monitoring)
* - Set GUI Status and Titlebar
* - Initialize Containers (Singleton Pattern)
* - Trigger Initial Data Retrieval
*----------------------------------------------------------------------*
MODULE status_0400 OUTPUT.
  " --- 1. Set GUI Interface ---
  SET PF-STATUS 'ST0400'.
  SET TITLEBAR  'T0400'.

  " --- 2. Initialize UI Controls (Run once) ---
  IF go_cc_report IS INITIAL.

    " A. Create Main Custom Container (Mapped to Screen Layout)
    CREATE OBJECT go_cc_report
      EXPORTING
        container_name = 'CC_REPORT'.

    " B. Create Splitter Container
    " Layout: 2 Rows, 1 Column (Row 1: KPI Header, Row 2: ALV Grid)
    CREATE OBJECT go_split_sd4
      EXPORTING
        parent  = go_cc_report
        rows    = 2
        columns = 1.

    " C. Adjust Layout Dimensions
    " Set Header height to 15% (Bottom area takes remaining 85%)
    go_split_sd4->set_row_height( id = 1 height = 15 ).

    " D. Assign Sub-Containers to References
    go_c_top_sd4 = go_split_sd4->get_container( row = 1 column = 1 ).
    go_c_bot_sd4 = go_split_sd4->get_container( row = 2 column = 1 ).

    " --- 3. Data Retrieval & Rendering ---
    PERFORM get_initial_data_sd4.
    PERFORM update_dashboard_ui_sd4.

  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0420 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0420 OUTPUT.
  SET PF-STATUS 'ST0420'.
  SET TITLEBAR 'T0420'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0430 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0430 OUTPUT.
  SET PF-STATUS 'ST430'.
  SET TITLEBAR 'T430'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module INIT_DASHBOARD_0430 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE init_dashboard_0430 OUTPUT.
  PERFORM init_dashboard_0430.
  PERFORM refresh_data_0430 USING 'ALL'.
ENDMODULE.
