*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_I01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
* Process user actions on Screen 0100
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  DATA: lv_choice TYPE c.
  DATA(lv_ucomm) = ok_code.
  CLEAR ok_code.

  CASE sy-ucomm.

      " -----------------------------------------------------------------
      " GROUP 1: SALES ORDER MANAGEMENT
      " -----------------------------------------------------------------
    WHEN 'MAN_SO'.
      PERFORM popup_select_so_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Create Single Order
          CALL SCREEN 0300.
        WHEN '2'. " Mass Upload Orders
          CALL SCREEN 0200. "
      ENDCASE.

      " -----------------------------------------------------------------
      " GROUP 2: LOGISTICS & BILLING
      " -----------------------------------------------------------------
    WHEN 'MAN_DLV'.
      MESSAGE 'Chức năng đang phát triển (Manage Delivery).' TYPE 'S'.

    WHEN 'MAN_BIL'.
      PERFORM popup_select_billing_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Create Single Billing
          MESSAGE 'Chức năng đang phát triển (Create Billing).' TYPE 'S'.
        WHEN '2'. " Search & Process
          MESSAGE 'Chức năng đang phát triển (Search Billing).' TYPE 'S'.
      ENDCASE.

      " -----------------------------------------------------------------
      " GROUP 3: ANALYTICS & REPORTS
      " -----------------------------------------------------------------
    WHEN 'OVERVIEW'.
      PERFORM popup_select_overview_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Track Sales Order
          CALL SCREEN 0500.
        WHEN '2'. " Report Monitoring
          CALL SCREEN 0400.
      ENDCASE.

    WHEN 'REFRESH'.
      " --- [NEW] GỌI FORM REFRESH ---
      PERFORM hc_refresh_dashboard.

      " -----------------------------------------------------------------
      " GROUP 4: SYSTEM COMMANDS
      " -----------------------------------------------------------------
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      " --- CLEANUP HOME CENTER OBJECTS ---
      IF go_hc_alv IS NOT INITIAL.
        go_hc_alv->free( ). CLEAR go_hc_alv.
      ENDIF.

      IF go_hc_html IS NOT INITIAL.
        go_hc_html->free( ). CLEAR go_hc_html.
      ENDIF.

      IF go_hc_splitter IS NOT INITIAL.
        go_hc_splitter->free( ). CLEAR go_hc_splitter.
      ENDIF.

      IF go_hc_container IS NOT INITIAL.
        go_hc_container->free( ). CLEAR go_hc_container.
      ENDIF.

      " Return to previous screen or exit
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

MODULE user_command_0200 INPUT.

  "1. Catch Event (Save Function Code user click to lv_ucomm)
  lv_ucomm = sy-ucomm.
  CLEAR sy-ucomm.

  CASE lv_ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      gv_data_loaded = abap_false.
      LEAVE TO SCREEN 0.

    WHEN 'DWN_TMPL'.
      PERFORM download_template.

    WHEN 'UPLOAD'.
      " 1. Create new Request ID
      PERFORM generate_request_id CHANGING gv_current_req_id.

      " 2. Execute Upload File (ReadExcel -> Save Staging)
      PERFORM perform_mass_upload USING 'NEW' gv_current_req_id.

      " 3. Load data from Staging to Internal Table GT_MU_HEADER/ITEM
      PERFORM load_data_for_tree_ui USING gv_current_req_id.

      " 4. Move to screen 0210 (Tree View)
      IF gt_mu_header IS NOT INITIAL.
        gv_data_loaded = abap_true.
        LEAVE TO SCREEN 0210.
      ELSE.
        MESSAGE 'No data uploaded or file is empty.' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0210  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0210 INPUT.
  save_ok = ok_code.

  CASE save_ok.
    WHEN 'FC_SHOW_LOG' OR 'FC_SHOW_LOG_ITM'.
      " KHÔNG CLEAR OK_CODE ở đây, để nó trôi xuống Subscreen PAI

    WHEN OTHERS.
      " Với các lệnh khác (Back, Exit, Vali...), ta clear như cũ để tránh lặp
      CLEAR ok_code.
  ENDCASE.

  CASE save_ok.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      LEAVE TO SCREEN 200.
    WHEN 'REFRESH_SCREEN'.
      " PBO sẽ chạy lại và cập nhật Subscreen
    WHEN 'UPLOAD'.
      DATA: lv_ans TYPE c.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar      = 'Confirm New Upload'
          text_question = 'Uploading a new file will discard current unsaved changes. Continue?'
          icon_button_1 = 'Yes'
          icon_button_2 = 'No'
        IMPORTING
          answer        = lv_ans.

      IF lv_ans = '2' OR lv_ans = 'A'. RETURN. ENDIF.

      " Xóa sạch bảng nội bộ chứa dữ liệu cũ
      CLEAR: gt_mu_header, gt_mu_item, gt_mu_cond.
      CLEAR: gs_mu_header, gs_mu_item.

      " [QUAN TRỌNG] Reset biến lưu vết Node cũ
      " Để tránh logic Save tự động chạy sai khi cây mới được vẽ
      CLEAR gv_prev_node_key.

      " 1. Tạo Request ID mới
      PERFORM generate_request_id CHANGING gv_current_req_id.

      " 2. Đọc File Excel & Lưu Staging
      PERFORM perform_mass_upload USING 'NEW' gv_current_req_id.

      " 3. Load lại vào bảng nội bộ GT_MU_...
      PERFORM load_data_for_tree_ui USING gv_current_req_id.

      IF gt_mu_header IS NOT INITIAL.
        " Vẽ lại cây mới (Form này đã bao gồm logic chọn Node đầu tiên)
        PERFORM build_tree_from_data.

        " Đánh dấu cờ dữ liệu đã load
        gv_data_loaded = abap_true.

        " Thông báo thành công
        MESSAGE 'New file uploaded successfully.' TYPE 'S'.
      ELSE.
        " Nếu file rỗng hoặc lỗi, xóa sạch cây
        IF go_mu_tree IS BOUND.
          go_mu_tree->delete_all_nodes( ).
          " Flush lệnh xuống GUI
          CALL METHOD cl_gui_cfw=>flush
            EXCEPTIONS
              cntl_system_error = 1
              cntl_error        = 2
              OTHERS            = 3.

          IF sy-subrc <> 0.
            " Xử lý lỗi nhẹ nhàng hơn thay vì để Dump
            " Có thể log lại lỗi hoặc bỏ qua nếu việc update icon không quá quan trọng
            MESSAGE 'Error loading data to tree' TYPE 'S' DISPLAY LIKE 'E'.
          ENDIF.
        ENDIF.
        MESSAGE 'No data found in the new file.' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

    WHEN 'VALI'.
      PERFORM execute_validation USING gv_current_req_id.
    WHEN 'CREA_SO'.
      " Step 1: Save data on screen to internal tables
      PERFORM save_current_data.

      " Step 2: Sync Data to DB
      PERFORM sync_memory_to_staging USING gv_current_req_id.

      " Step 3: Validate again to ensure clean data
      PERFORM execute_validation USING gv_current_req_id.

      " Step 4: Execute create Sales Order
      PERFORM perform_create_sales_orders.

      " Step 5: Refresh UI
      PERFORM update_tree_icons.
      PERFORM refresh_current_screen.

  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0211  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0211 INPUT.
  DATA: lv_ucomm_0211 TYPE sy-ucomm.

  lv_ucomm_0211 = ok_code.
  CLEAR ok_code.

  PERFORM save_current_data.

  CASE lv_ucomm_0211.
    WHEN 'FC_SHOW_LOG'.
      PERFORM show_context_error_log
        USING gs_mu_header-req_id
              gs_mu_header-temp_id
              '000000'.

    WHEN OTHERS.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0212  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0212 INPUT.
  DATA: lv_ucomm_0212 TYPE sy-ucomm.

  lv_ucomm_0212 = ok_code.
  CLEAR ok_code.

  PERFORM save_current_data.

  CASE lv_ucomm_0212.
    WHEN 'FC_SHOW_LOG'.
      PERFORM show_context_error_log
        USING gs_mu_item-req_id
              gs_mu_item-temp_id
              gs_mu_item-item_no.

    WHEN OTHERS.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
* PROCESS AFTER INPUT (PAI) Handling for Screen 0300
* - Handle User Commands (Create, Clear)
* - Perform Field Validations (Existence & Business Logic)
* - Navigation Control
*----------------------------------------------------------------------*
MODULE user_command_0300 INPUT.

*-- [1] UX IMPROVEMENT: CURSOR POSITIONING
  " Store current cursor position to restore it later in PBO (Status Module).
  " This prevents the cursor from jumping back to the first field after an error.
  GET CURSOR FIELD gv_cursor_field.

  CASE sy-ucomm.

*======================================================================*
* CREATE SALES ORDER
*======================================================================*
    WHEN 'CREATE_SO'.

      " --- [Step A] MANDATORY FIELDS CHECK -----------------------------
      " Check if critical fields are populated.
      " Using 'DISPLAY LIKE E' allows us to control the flow (RETURN)
      " instead of halting the screen immediately like a standard TYPE 'E'.
      IF gs_so_heder_ui-so_hdr_auart IS INITIAL.
        MESSAGE 'Sales Doc. Type is required.' TYPE 'S' DISPLAY LIKE 'E'.
        SET CURSOR FIELD 'GS_SO_HEDER_UI-SO_HDR_AUART'.
        RETURN. " Stop processing, wait for user input
      ENDIF.

      " --- [Step B] EXISTENCE CHECKS (MASTER DATA) ---------------------
      " Validate individual fields against Standard SAP Tables.
      " We check these first to avoid unnecessary complex queries later.

      " -- B.1 Check Sales Organization (Table TVKO) --
      IF gs_so_heder_ui-so_hdr_vkorg IS NOT INITIAL.
        DATA: lv_dummy_tvko TYPE c.

        " Optimization: Use SELECT SINGLE 'X' to check existence only.
        " This is faster than selecting data we don't need.
        SELECT SINGLE 'X'
          FROM tvko
          INTO @lv_dummy_tvko
          WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg.

        IF sy-subrc <> 0.
          " Error: Sales Org does not exist in system
          MESSAGE ID 'V1' TYPE 'S' NUMBER '312'
                  WITH gs_so_heder_ui-so_hdr_vkorg
                  DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
      ENDIF.

      " -- B.2 Check Distribution Channel (Table TVTW) --
      IF gs_so_heder_ui-so_hdr_vtweg IS NOT INITIAL.
        DATA: lv_dummy_tvtw TYPE c.

        SELECT SINGLE 'X'
          FROM tvtw
          INTO @lv_dummy_tvtw
          WHERE vtweg = @gs_so_heder_ui-so_hdr_vtweg.

        IF sy-subrc <> 0.
          MESSAGE 'Distribution Channel invalid' TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
      ENDIF.

      " --- [Step C] BUSINESS LOGIC CHECK (SALES AREA) ------------------
      " Validate the COMBINATION of Sales Org + Channel + Division.
      " Even if individual fields are correct, the combination might not exist
      " in Table TVTA (Sales Area Definitions).
      IF gs_so_heder_ui-so_hdr_vkorg IS NOT INITIAL AND
         gs_so_heder_ui-so_hdr_vtweg IS NOT INITIAL AND
         gs_so_heder_ui-so_hdr_spart IS NOT INITIAL.

        DATA: lv_dummy_tvta TYPE c.

        SELECT SINGLE 'X'
          FROM tvta
          INTO @lv_dummy_tvta
          WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg
            AND vtweg = @gs_so_heder_ui-so_hdr_vtweg
            AND spart = @gs_so_heder_ui-so_hdr_spart.

        IF sy-subrc <> 0.
          " Error: The specific Sales Area is not defined
          MESSAGE ID 'V1' TYPE 'S' NUMBER '316'
                  WITH gs_so_heder_ui-so_hdr_vkorg
                       gs_so_heder_ui-so_hdr_vtweg
                       gs_so_heder_ui-so_hdr_spart
                  DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
      ENDIF.

      " --- [Step D] SUCCESS & NAVIGATION -------------------------------
      " If all checks pass, proceed to the next screen (Item Entry).
      SET SCREEN 0310.
      LEAVE SCREEN.

*======================================================================*
* CLEAR DATA
*======================================================================*
    WHEN 'CLEAR_INFO'.
      " 1. Reset Screen Structure
      CLEAR gs_so_heder_ui.

      " 2. Reset Cursor Memory (Force PBO to use default or specific field)
      CLEAR gv_cursor_field.

      " 3. Set focus to the first field for quick entry
      SET CURSOR FIELD 'GS_SO_HEDER_UI-SO_HDR_AUART'.

      " 4. User Feedback
      MESSAGE 'Screen data has been cleared.' TYPE 'S'.

  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  EXIT_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
* HANDLES STANDARD TOOLBAR EXIT COMMANDS (Type 'E')
* Note: This module is triggered via 'AT EXIT-COMMAND' in Flow Logic.
* It bypasses all field validations on the screen.
*----------------------------------------------------------------------*
MODULE exit_command_0300 INPUT.

  CASE sy-ucomm.

*======================================================================*
* BACK
* Behavior: Navigate to the previous screen (Parent Screen)
*======================================================================*
    WHEN 'BACK'.
      " Go back to the calling screen or Main Menu (Screen 0100)
      SET SCREEN 0100.
      LEAVE SCREEN.

*======================================================================*
* EXIT  & CANCEL
* Behavior: Terminate the transaction/program immediately
*======================================================================*
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.

  ENDCASE.

ENDMODULE.

*&SPWIZARD: INPUT MODULE FOR TS 'TS_MAIN'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: GETS ACTIVE TAB
MODULE ts_main_active_tab_get INPUT.
  ok_code = sy-ucomm.
  CASE ok_code.
    WHEN c_ts_main-tab1.
      g_ts_main-pressed_tab = c_ts_main-tab1.
    WHEN c_ts_main-tab2.
      g_ts_main-pressed_tab = c_ts_main-tab2.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  RESET_FLAG_ON_CHANGE  INPUT
*&---------------------------------------------------------------------*
* Reset status flags upon user interaction/input
*----------------------------------------------------------------------*
MODULE reset_flag_on_change INPUT.

  " Reset the creation flag after the first display cycle
  IF gv_so_just_created = abap_true.
    CLEAR gv_so_just_created.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  PAI_HANDLE_DATA_TRANSFER  INPUT
*&---------------------------------------------------------------------*
* Central PAI Controller: Validation and Data Processing
*----------------------------------------------------------------------*
MODULE pai_handle_data_transfer INPUT.

  " Check for standard navigation commands (Back, Exit, Cancel)
  " Stop processing if user intends to leave the screen
  CHECK sy-ucomm <> 'BACK' AND sy-ucomm <> 'EXIT' AND sy-ucomm <> 'CANC'.

  PERFORM pai_auto_populate.   " Populate default values
  PERFORM pai_derive_data.     " Execute business logic and data derivation

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Form  PAI_AUTO_POPULATE
*&---------------------------------------------------------------------*
* Derive dependent partner data (Ship-to, Payer) from Sold-to
*----------------------------------------------------------------------*
FORM pai_auto_populate .

  " Default Ship-to Party from Sold-to Party if not manually maintained
  IF gs_so_heder_ui-so_hdr_ship_addr IS INITIAL AND
     gs_so_heder_ui-so_hdr_sold_addr IS NOT INITIAL.

    gs_so_heder_ui-so_hdr_ship_addr = gs_so_heder_ui-so_hdr_sold_addr.
  ENDIF.

  " Default Payer from Sold-to Party if not manually maintained
  IF gs_so_heder_ui-so_hdr_payer     IS INITIAL AND
     gs_so_heder_ui-so_hdr_sold_addr IS NOT INITIAL.

    gs_so_heder_ui-so_hdr_payer      = gs_so_heder_ui-so_hdr_sold_addr.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PAI_DERIVE_DATA
*&---------------------------------------------------------------------*
* Description:
* Central logic to derive Sales Order Header data based on Sold-to Party.
* Process flow:
* 1. Validate Sold-to Party existence (General Data).
* 2. Determine Sales Area (Trigger Popup if not manually entered).
* 3. Fetch Customer Sales Data (KNVV) for the specific Sales Area.
* 4. Default header fields (Payment terms, Incoterms, Currency).
*----------------------------------------------------------------------*
FORM pai_derive_data .

  DATA: lv_sold_to TYPE kunnr,
        lv_ship_to TYPE kunnr.

  " ---------------------------------------------------------------------
  " 1. INITIAL CHECK
  " ---------------------------------------------------------------------
  " If Sold-to Party is removed/empty, reset dependent fields and screen state.
  IF gs_so_heder_ui-so_hdr_sold_addr IS INITIAL.
    CLEAR: gs_so_heder_ui-so_hdr_sold_adrnr, " Name
           gs_so_heder_ui-so_hdr_ship_adrnr. " Ship-to Name

    gv_screen_state = '0'. " Set state to Initial/Locked
    EXIT.
  ENDIF.

  " ---------------------------------------------------------------------
  " 2. PRE-PROCESSING (NORMALIZATION)
  " ---------------------------------------------------------------------
  " Convert input to internal format (e.g., '123' -> '0000000123') for DB lookup.
  " NOTE: We use a local variable (lv_sold_to) to keep the User Interface
  " friendly (without leading zeros) while querying the database.
  lv_sold_to = gs_so_heder_ui-so_hdr_sold_addr.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_sold_to
    IMPORTING
      output = lv_sold_to.

  " ---------------------------------------------------------------------
  " 3. MASTER DATA VALIDATION (GENERAL DATA - KNA1)
  " ---------------------------------------------------------------------
  " Check if Customer exists in General Master Data and retrieve Name.
  SELECT SINGLE name1 FROM kna1
    INTO gs_so_heder_ui-so_hdr_sold_adrnr
    WHERE kunnr = lv_sold_to.

  IF sy-subrc <> 0.
    CLEAR gs_so_heder_ui-so_hdr_sold_adrnr.
    gv_screen_state = '0'.
    MESSAGE 'Sold-to Party not found' TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

  " Populate default partners (Ship-to/Payer) if applicable
  PERFORM pai_auto_populate.

  " ---------------------------------------------------------------------
  " 4. SALES AREA DETERMINATION
  " ---------------------------------------------------------------------
  " If Sales Area (Org/Channel/Division) is missing, trigger a selection popup.
  " This allows the user to enter a Customer first, then choose the Sales Area.
  IF gs_so_heder_ui-so_hdr_vkorg IS INITIAL OR
     gs_so_heder_ui-so_hdr_vtweg IS INITIAL OR
     gs_so_heder_ui-so_hdr_spart IS INITIAL.

    PERFORM get_sales_area_from_popup
      USING    lv_sold_to  " Use internal format
      CHANGING gs_so_heder_ui-so_hdr_vkorg
               gs_so_heder_ui-so_hdr_vtweg
               gs_so_heder_ui-so_hdr_spart.

    " If user cancels the popup or no valid area found, stop processing.
    IF sy-subrc <> 0.
      gv_screen_state = '0'.
      EXIT.
    ENDIF.
  ENDIF.

  " ---------------------------------------------------------------------
  " 5. DATA DERIVATION (SALES DATA - KNVV)
  " ---------------------------------------------------------------------
  " Fetch Sales-Area-dependent data (Payment Terms, Incoterms, Currency).
  SELECT SINGLE zterm, inco1, waers
    FROM knvv
    INTO (@gs_so_heder_ui-so_hdr_zterm,
          @gs_so_heder_ui-so_hdr_inco1,
          @gs_so_heder_ui-so_hdr_waerk)
    WHERE kunnr = @lv_sold_to
      AND vkorg = @gs_so_heder_ui-so_hdr_vkorg
      AND vtweg = @gs_so_heder_ui-so_hdr_vtweg
      AND spart = @gs_so_heder_ui-so_hdr_spart.

  IF sy-subrc = 0.
    " --- SUCCESS CASE ---
    " Derive description texts and set default dates
    PERFORM get_and_set_derived_fields USING lv_sold_to.

    gv_screen_state = '1'. " Set state to Active/Ready
    PERFORM default_dates_after_soldto.

  ELSE.
    " --- ERROR CASE ---
    " Customer exists (KNA1) but is not extended to this specific Sales Area (KNVV).
    gv_screen_state = '0'.

    MESSAGE |Customer { gs_so_heder_ui-so_hdr_sold_addr } not defined for Sales Area|
      TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_SALES_AREA_FROM_POPUP
*&---------------------------------------------------------------------*
* Retrieves valid Sales Areas (Org/Channel/Division) for a customer.
* Applies dynamic filtering based on input (Sales Org/Distr. Channel).
* - Single Match: Automatically assigns values.
* - Multiple Matches: Displays ALV Popup for user selection.
*----------------------------------------------------------------------*
FORM get_sales_area_from_popup
  USING    iv_kunnr TYPE kunnr       " Input: Customer Number
  CHANGING cv_vkorg TYPE vkorg       " In/Out: Sales Organization
           cv_vtweg TYPE vtweg       " In/Out: Distribution Channel
           cv_spart TYPE spart.      " Out: Division

  " --------------------------------------------------------------------
  " 1. Data Definitions
  " --------------------------------------------------------------------
  TYPES: BEGIN OF ty_sales_area_f4,
           vkorg TYPE vkorg,
           vtweg TYPE vtweg,
           spart TYPE spart,
           vtext TYPE text120,
         END OF ty_sales_area_f4.

  DATA: lt_knvv     TYPE STANDARD TABLE OF knvv,
        ls_knvv     TYPE knvv,
        lt_f4_data  TYPE STANDARD TABLE OF ty_sales_area_f4,
        ls_f4_data  TYPE ty_sales_area_f4,
        lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_fieldcat TYPE slis_fieldcat_alv,
        ls_selfield TYPE slis_selfield.

  " --------------------------------------------------------------------
  " 2. Dynamic Selection (Using Ranges)
  " --------------------------------------------------------------------
  " Define ranges to handle flexible filtering (Org and/or Channel)
  DATA: lr_vkorg TYPE RANGE OF vkorg,
        lr_vtweg TYPE RANGE OF vtweg.

  " Populate Range for Sales Organization (if provided)
  IF cv_vkorg IS NOT INITIAL.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = cv_vkorg ) TO lr_vkorg.
  ENDIF.

  " Populate Range for Distribution Channel (if provided)
  IF cv_vtweg IS NOT INITIAL.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = cv_vtweg ) TO lr_vtweg.
  ENDIF.

  " Fetch Sales Area data from KNVV with dynamic filters
  SELECT vkorg, vtweg, spart
    FROM knvv
    INTO CORRESPONDING FIELDS OF TABLE @lt_knvv
    WHERE kunnr = @iv_kunnr
      AND vkorg IN @lr_vkorg
      AND vtweg IN @lr_vtweg.

  " --------------------------------------------------------------------
  " 3. Validation & Error Handling
  " --------------------------------------------------------------------
  IF sy-subrc <> 0.
    " Handle 'No Data Found' scenarios with specific error messages
    IF cv_vkorg IS NOT INITIAL AND cv_vtweg IS NOT INITIAL.
      MESSAGE |Customer { iv_kunnr } not defined in Org { cv_vkorg } / Channel { cv_vtweg }.| TYPE 'S' DISPLAY LIKE 'E'.
    ELSEIF cv_vkorg IS NOT INITIAL.
      MESSAGE |Customer { iv_kunnr } not defined in Org { cv_vkorg }.| TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE |Customer { iv_kunnr } is not assigned to any Sales Area.| TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.

    sy-subrc = 4.
    EXIT.
  ENDIF.

  " Remove duplicates to ensure clean display
  SORT lt_knvv BY vkorg vtweg spart.
  DELETE ADJACENT DUPLICATES FROM lt_knvv COMPARING vkorg vtweg spart.

  " --------------------------------------------------------------------
  " 4. Result Processing
  " --------------------------------------------------------------------
  IF lines( lt_knvv ) = 1.
    " CASE A: Single Match Found -> Auto-assign values (No Popup required)
    READ TABLE lt_knvv INDEX 1 INTO ls_knvv.
    cv_vkorg = ls_knvv-vkorg.
    cv_vtweg = ls_knvv-vtweg.
    cv_spart = ls_knvv-spart.
    sy-subrc = 0.

  ELSE.
    " CASE B: Multiple Matches Found -> Trigger Selection Popup

    " 4a. Enrich data with descriptions (Texts)
    LOOP AT lt_knvv INTO ls_knvv.
      CLEAR: ls_f4_data.
      ls_f4_data-vkorg = ls_knvv-vkorg.
      ls_f4_data-vtweg = ls_knvv-vtweg.
      ls_f4_data-spart = ls_knvv-spart.

      " Retrieve text descriptions for Org/Channel/Division
      SELECT SINGLE vtext INTO @DATA(lv_t1) FROM tvkot WHERE vkorg = @ls_knvv-vkorg AND spras = @sy-langu.
      SELECT SINGLE vtext INTO @DATA(lv_t2) FROM tvtwt WHERE vtweg = @ls_knvv-vtweg AND spras = @sy-langu.
      SELECT SINGLE vtext INTO @DATA(lv_t3) FROM tspat WHERE spart = @ls_knvv-spart AND spras = @sy-langu.

      ls_f4_data-vtext = |{ lv_t1 } / { lv_t2 } / { lv_t3 }|.
      APPEND ls_f4_data TO lt_f4_data.
    ENDLOOP.

    " 4b. Build Field Catalog for ALV
    REFRESH lt_fieldcat.

    " Column: Sales Organization
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'VKORG'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'S.Org'.
    ls_fieldcat-outputlen = 6.
    APPEND ls_fieldcat TO lt_fieldcat.

    " Column: Distribution Channel
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'VTWEG'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'D.Ch'.
    ls_fieldcat-outputlen = 4.
    APPEND ls_fieldcat TO lt_fieldcat.

    " Column: Division
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'SPART'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'Div'.
    ls_fieldcat-outputlen = 4.
    APPEND ls_fieldcat TO lt_fieldcat.

    " Column: Description
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'VTEXT'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'Description'.
    ls_fieldcat-outputlen = 50.
    APPEND ls_fieldcat TO lt_fieldcat.

    " 4c. Invoke ALV Popup
    CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
      EXPORTING
        i_title               = 'Select Sales Area'
        i_selection           = 'X'
        i_zebra               = 'X'
        i_scroll_to_sel_line  = 'X'
        i_screen_start_column = 10
        i_screen_start_line   = 5
        i_screen_end_column   = 110
        i_screen_end_line     = 15
        it_fieldcat           = lt_fieldcat
        i_tabname             = 'LT_F4_DATA'
        i_callback_program    = sy-repid
      IMPORTING
        es_selfield           = ls_selfield
      TABLES
        t_outtab              = lt_f4_data
      EXCEPTIONS
        program_error         = 1
        OTHERS                = 2.

    " 4d. Handle User Selection
    IF sy-subrc = 0 AND ls_selfield-tabindex > 0.
      " Valid selection made
      READ TABLE lt_f4_data INDEX ls_selfield-tabindex INTO ls_f4_data.
      cv_vkorg = ls_f4_data-vkorg.
      cv_vtweg = ls_f4_data-vtweg.
      cv_spart = ls_f4_data-spart.
      sy-subrc = 0.
    ELSE.
      " User cancelled or closed the popup
      MESSAGE 'Action cancelled. Sales Area not determined.' TYPE 'S' DISPLAY LIKE 'E'.
      sy-subrc = 4.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0310  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0310 INPUT.
  DATA: lv_ok_code TYPE sy-ucomm.
  DATA: lv_action TYPE sy-ucomm.
  lv_ok_code = ok_code.
  CLEAR ok_code.

  CASE lv_ok_code.
      " ---------------------------------------------------------------------
      " 1. XỬ LÝ NHÓM NÚT THOÁT (BACK, EXIT, CANCEL)
      " ---------------------------------------------------------------------
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.

      " [CASE A]: CHẾ ĐỘ EDIT (TỪ MASS UPLOAD)
      IF gv_single_mode = 'EDIT'.
        " Quay về màn hình gọi nó (Mass Upload - Screen 0200)
        " LEAVE TO SCREEN 0 sẽ pop screen 0111 ra khỏi stack
        LEAVE TO SCREEN 0.

        " [CASE B]: CHẾ ĐỘ CREATE (BÌNH THƯỜNG)
      ELSE.
        " Logic cũ: Hỏi xác nhận Save trước khi thoát
        PERFORM perform_exit_confirmation CHANGING lv_action.

        CASE lv_action.
          WHEN 'SAVE'.
            " User chọn 'Yes' -> Lưu mới
            PERFORM perform_create_single_so.
            IF gv_so_just_created = abap_true.
              LEAVE TO SCREEN 0300.
            ENDIF.

          WHEN 'BACK'.
            " User chọn 'No' -> Không lưu, Reset màn hình
            PERFORM reset_single_entry_screen.
            LEAVE TO SCREEN 0300.

          WHEN 'STAY'.
            " User chọn 'Cancel' -> Ở lại
        ENDCASE.
      ENDIF.

      " ---------------------------------------------------------------------
      " 2. XỬ LÝ NÚT SAVE
      " ---------------------------------------------------------------------
    WHEN 'SAVE'.

      " [CASE A]: CHẾ ĐỘ EDIT
      IF gv_single_mode = 'EDIT'.
        " Gọi Form Update (Dùng BAPI_SALESORDER_CHANGE)
*         PERFORM perform_update_single_so.

        " Nếu Update thành công (cờ gv_data_saved được bật trong Form update)
        IF gv_data_saved = 'X'.
          " Quay về Mass Upload để refresh lưới
          LEAVE TO SCREEN 0.
        ENDIF.
        " Nếu lỗi -> Ở lại màn hình để User sửa tiếp

        " [CASE B]: CHẾ ĐỘ CREATE
      ELSE.
        PERFORM perform_create_single_so.
        " Logic chuyển màn hình sau khi tạo (nếu cần)
        IF gv_so_just_created = abap_true.
          " Tùy chọn: Muốn quay về hay ở lại xem
          " LEAVE TO SCREEN 0110.
        ENDIF.
      ENDIF.

      " ---------------------------------------------------------------------
      " 3. CÁC NÚT KHÁC
      " ---------------------------------------------------------------------
    WHEN 'TRCK'.
      CLEAR gv_so_just_created.
      LEAVE TO SCREEN 0500.

  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0311  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_subscreen_0311 INPUT.
  " dispatch các sự kiện ALV (ví dụ: nhấn Enter, nhấn &ADD...)
  " dến class lcl_event_handler
  cl_gui_cfw=>dispatch( ).

  " 2. Kích hoạt sự kiện DATA CHANGED (khi Enter/chuyển ô)
  IF go_grid_item_single IS BOUND.
    CALL METHOD go_grid_item_single->check_changed_data.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0312  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_subscreen_0312 INPUT.
  " <<< SỬA 1: Gán SY-UCOMM vào OK_CODE ngay lập tức >>>
  " Chỉ gán nếu nó không phải là lệnh PAI của màn hình chính
  IF sy-ucomm <> 'BACK' AND sy-ucomm <> 'EXIT' AND sy-ucomm <> 'CANC' AND
     sy-ucomm <> 'SAVE' AND sy-ucomm <> 'TRCK' AND
     sy-ucomm <> 'TS_MAIN_FC1' AND sy-ucomm <> 'TS_MAIN_FC2'.

    ok_code = sy-ucomm. " Gán 'NEXT_ITEM', 'PREV_ITEM'...
  ENDIF.

  " 1. Xử lý các SỰ KIỆN COMMAND (như &ADD, &DEL)
  cl_gui_cfw=>dispatch( ).

  " 2. Kích hoạt sự kiện DATA CHANGED (Phải chạy trước CASE)
  IF go_grid_conditions IS BOUND.
    CALL METHOD go_grid_conditions->check_changed_data.
  ENDIF.

  " 3. Xử lý các nút điều hướng Item
  DATA lv_max_items TYPE i.
  DESCRIBE TABLE gt_item_details LINES lv_max_items.
  IF lv_max_items = 0.
    lv_max_items = 1. " Mặc định là 1 (tránh lỗi)
  ENDIF.

  CASE ok_code. " (ok_code là global)
    WHEN 'FIRST_ITEM'.
      gv_current_item_idx = 1.
    WHEN 'PREV_ITEM'.
      IF gv_current_item_idx > 1.
        gv_current_item_idx = gv_current_item_idx - 1.
      ELSE.
        MESSAGE 'There are no more items to be displayed' TYPE 'S'. " <<< THÊM
      ENDIF.
    WHEN 'NEXT_ITEM'.
      IF gv_current_item_idx < lv_max_items.
        gv_current_item_idx = gv_current_item_idx + 1.
      ELSE.
        MESSAGE 'There are no more items to be displayed' TYPE 'S'. " <<< THÊM
      ENDIF.
    WHEN 'LAST_ITEM'.
      gv_current_item_idx = lv_max_items.
  ENDCASE.

  " Xóa ok_code (tránh bị lặp lại ở PAI sau)
  IF ok_code = 'FIRST_ITEM' OR ok_code = 'PREV_ITEM' OR
     ok_code = 'NEXT_ITEM' OR ok_code = 'LAST_ITEM'.
    CLEAR ok_code.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  F4_VTWEG  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE f4_vtweg INPUT.
  PERFORM f4_help_vtweg.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  F4_SPART  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE f4_spart INPUT.
  PERFORM f4_help_spart.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  F4_VKGRP  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE f4_vkgrp INPUT.
  PERFORM f4_help_vkgrp.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  F4_VKBUR  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE f4_vkbur INPUT.
  PERFORM f4_help_vkbur.
ENDMODULE.

*  *&---------------------------------------------------------------------*
*  *&      Module  USER_COMMAND_0100  INPUT
*  *&---------------------------------------------------------------------*
*  * Handle user actions (Search / Go / Billing / PGI / etc.)
*  *----------------------------------------------------------------------*
MODULE user_command_0500 INPUT.

  DATA: lv_count        TYPE i,
        lv_last_msg     TYPE string,
        lv_last_msg_typ TYPE c.
  DATA: lt_rows TYPE lvc_t_row,
        ls_row  TYPE lvc_s_row.
*  DATA: ls_stable TYPE lvc_s_stbl.

  FIELD-SYMBOLS: <fs_tracking> TYPE ty_tracking.

  " --- 2. LOGIC CHUNG ---
  IF go_alv IS BOUND.
    CALL METHOD go_alv->check_changed_data.
  ENDIF.

  " --- 3. BẮT ĐẦU CASE DUY NHẤT ---
  CASE sy-ucomm.
    WHEN 'SEARCH' OR 'UPD_STAT'.
      IF cb_sosta = 'INC'.
        CLEAR: cb_ddsta, cb_bdsta.
      ENDIF.

      PERFORM load_tracking_data.
      PERFORM apply_phase_logic.
      PERFORM filter_process_phase.
      PERFORM filter_tracking_data.
      PERFORM filter_delivery_status.
      PERFORM filter_billing_status.

      IF cb_sosta <> 'INC'.
        PERFORM filter_pricing_procedure.
      ENDIF.

      IF go_alv IS BOUND.
        CALL METHOD go_alv->refresh_table_display( ).
      ENDIF.

    WHEN 'SET_JOB'.
      PERFORM setup_job_schedule.

    WHEN 'JOB_MON'.
      PERFORM show_job_monitor_popup.

    WHEN 'REFRESH'.
      " Load lại data
      PERFORM load_tracking_data.
      PERFORM apply_phase_logic.
      PERFORM filter_process_phase.
      PERFORM filter_tracking_data.
      PERFORM filter_delivery_status.
      PERFORM filter_billing_status.
      IF cb_sosta <> 'INC'.
        PERFORM filter_pricing_procedure.
      ENDIF.

      " Refresh giữ nguyên vị trí dòng/cột
      ls_stable-row = 'X'.
      ls_stable-col = 'X'.

      IF go_alv IS BOUND.
        CALL METHOD go_alv->refresh_table_display
          EXPORTING
            is_stable = ls_stable
          EXCEPTIONS
            finished  = 1
            OTHERS    = 2.

        IF sy-subrc <> 0.
          " Optional: Log error or raise message here
        ENDIF.
      ENDIF.

    WHEN 'POST_PGI' OR 'REVERSE_PGI' OR 'CANCEL_BILL' OR 'CREATE_BILL' OR 'REL_ACC'.

      lv_count = 0.

      " Lấy dòng được chọn
      IF go_alv IS BOUND.
        CALL METHOD go_alv->get_selected_rows
          IMPORTING
            et_index_rows = lt_rows.
      ENDIF.

      IF lt_rows IS NOT INITIAL.
        LOOP AT lt_rows INTO ls_row.
          READ TABLE gt_tracking ASSIGNING <fs_tracking> INDEX ls_row-index.
          IF sy-subrc = 0.
            <fs_tracking>-sel_box = 'X'.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " Vòng lặp xử lý
      LOOP AT gt_tracking ASSIGNING <fs_tracking> WHERE sel_box = 'X'.
        lv_count = lv_count + 1.

        CASE sy-ucomm.
          WHEN 'POST_PGI'.
            PERFORM process_post_goods_issue    USING <fs_tracking> CHANGING <fs_tracking>.
          WHEN 'CREATE_BILL'.
            PERFORM process_create_billing      USING <fs_tracking> CHANGING <fs_tracking>.
          WHEN 'REVERSE_PGI'.
            PERFORM process_reverse_pgi         USING <fs_tracking> CHANGING <fs_tracking>.
          WHEN 'CANCEL_BILL'.
            PERFORM process_cancel_billing      USING <fs_tracking> CHANGING <fs_tracking>.
          WHEN 'REL_ACC'.
            PERFORM process_release_to_account  USING <fs_tracking> CHANGING <fs_tracking>.
        ENDCASE.

        " Set loại thông báo
        lv_last_msg = <fs_tracking>-error_msg.
        IF <fs_tracking>-error_msg CS 'ERROR' OR
           <fs_tracking>-error_msg CS 'failed' OR
           <fs_tracking>-error_msg CS 'LỖI'.
          lv_last_msg_typ = 'E'.
        ELSE.
          lv_last_msg_typ = 'S'.
        ENDIF.
      ENDLOOP.

      " Hiển thị kết quả sau khi xử lý xong
      IF lv_count > 0.
        IF lv_count = 1.
          MESSAGE lv_last_msg TYPE 'S' DISPLAY LIKE lv_last_msg_typ.
        ELSE.
          MESSAGE |Mass Processing: Completed { lv_count } rows. Please check Status column.| TYPE 'S'.
        ENDIF.

        COMMIT WORK AND WAIT.
        WAIT UP TO 1 SECONDS.

        " Load lại data để cập nhật status
        PERFORM load_tracking_data.
        PERFORM apply_phase_logic.
        PERFORM filter_process_phase.
        PERFORM filter_tracking_data.
        PERFORM filter_delivery_status.
        PERFORM filter_billing_status.
        IF cb_sosta <> 'INC'.
          PERFORM filter_pricing_procedure.
        ENDIF.

        " Refresh ALV
        IF go_alv IS BOUND.
          CLEAR ls_stable.
          ls_stable-row = 'X'.
          ls_stable-col = 'X'.
          CALL METHOD go_alv->refresh_table_display
            EXPORTING
              is_stable = ls_stable.
        ENDIF.

      ELSE.
        MESSAGE 'Please select at least one row (Highlight or Checkbox) to process.' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

      "=========================================================
      "  🚪 5. THOÁT
      "=========================================================
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.

  ENDCASE. " <--- Đóng CASE duy nhất tại đây

ENDMODULE.


MODULE f4_for_vbeln.

  " 1. Khai báo cấu trúc bảng hiển thị
  TYPES: BEGIN OF ty_so_list,
           vbeln TYPE vbak-vbeln, " Số chứng từ
           erdat TYPE vbak-erdat, " Ngày tạo
           erzet TYPE vbak-erzet, " Giờ tạo
           ernam TYPE vbak-ernam, " Người tạo
           auart TYPE vbak-auart, " Loại đơn
           netwr TYPE vbak-netwr, " Giá trị
         END OF ty_so_list.

  DATA: lt_so_list TYPE STANDARD TABLE OF ty_so_list,
        lt_return  TYPE STANDARD TABLE OF ddshretval.

  " 2. SELECT Dữ liệu trực tiếp (Không còn lọc ERNAM)
  " Lấy 500 đơn hàng mới nhất trên toàn hệ thống khớp với loại chứng từ
  SELECT vbeln, erdat, erzet, ernam, auart, netwr
    FROM vbak
    UP TO 500 ROWS
    INTO CORRESPONDING FIELDS OF TABLE @lt_so_list
    WHERE vbtyp IN ('C','L','K','I','H')  " Lọc các loại: Order, Debit, Credit, Free of charge, Returns...
    ORDER BY erdat DESCENDING, erzet DESCENDING.

  " 3. Gọi hàm hiển thị dạng Bảng
  IF lt_so_list IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'VBELN'          " Tên cột sẽ lấy giá trị trả về
        window_title    = 'Danh sách đơn hàng (Tất cả User)'
        value_org       = 'S'              " Structure
      TABLES
        value_tab       = lt_so_list       " Bảng dữ liệu ta vừa Select
        return_tab      = lt_return        " Kết quả user chọn
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.

    " 4. Gán lại vào biến màn hình
    IF sy-subrc = 0 AND lt_return IS NOT INITIAL.
      READ TABLE lt_return INTO DATA(ls_return) INDEX 1.
      gv_vbeln = ls_return-fieldval.
      " Lưu ý: Đảm bảo biến gv_vbeln trùng tên với biến trên màn hình của bạn
    ENDIF.

  ELSE.
    MESSAGE 'Không tìm thấy đơn hàng nào trong hệ thống.' TYPE 'S' DISPLAY LIKE 'W'.
  ENDIF.

ENDMODULE.
MODULE f4_for_deliv INPUT.

  " 1. Khai báo cấu trúc bảng hiển thị
  TYPES: BEGIN OF ty_dl_list,
           vbeln TYPE likp-vbeln, " Số giao hàng
           erdat TYPE likp-erdat, " Ngày tạo
           erzet TYPE likp-erzet, " Giờ tạo
           ernam TYPE likp-ernam, " Người tạo
           lfart TYPE likp-lfart, " Loại giao hàng
           kunnr TYPE likp-kunnr, " Khách hàng
         END OF ty_dl_list.

  DATA: lt_dl_list TYPE STANDARD TABLE OF ty_dl_list,
        lt_ret_dl  TYPE STANDARD TABLE OF ddshretval.

  " 2. SELECT Dữ liệu: Lấy 500 phiếu Outbound Delivery mới nhất
  SELECT vbeln, erdat, erzet, ernam, lfart, kunnr
    FROM likp
    UP TO 500 ROWS
    INTO CORRESPONDING FIELDS OF TABLE @lt_dl_list
    WHERE vbtyp IN ('J' , 'T')
    ORDER BY erdat DESCENDING, erzet DESCENDING.

  " 3. Gọi hàm hiển thị Search Help
  IF lt_dl_list IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'VBELN'
        window_title    = 'Danh sách Phiếu Giao Hàng'
        value_org       = 'S'
      TABLES
        value_tab       = lt_dl_list
        return_tab      = lt_ret_dl
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.

    " 4. Gán kết quả chọn vào biến màn hình gv_deliv
    IF sy-subrc = 0 AND lt_ret_dl IS NOT INITIAL.
      READ TABLE lt_ret_dl INTO DATA(ls_ret_dl) INDEX 1.
      gv_deliv = ls_ret_dl-fieldval. " <--- Đã khớp với khai báo của bạn
    ENDIF.

  ELSE.
    MESSAGE 'Không tìm thấy phiếu giao hàng nào.' TYPE 'S' DISPLAY LIKE 'W'.
  ENDIF.

ENDMODULE.
MODULE f4_for_bill INPUT.

  " 1. Khai báo cấu trúc bảng hiển thị
  TYPES: BEGIN OF ty_bl_list,
           vbeln TYPE vbrk-vbeln, " Số hóa đơn
           fkdat TYPE vbrk-fkdat, " Ngày hóa đơn
           erzet TYPE vbrk-erzet, " Giờ tạo
           ernam TYPE vbrk-ernam, " Người tạo
           fkart TYPE vbrk-fkart, " Loại hóa đơn
           netwr TYPE vbrk-netwr, " Giá trị
         END OF ty_bl_list.

  DATA: lt_bl_list TYPE STANDARD TABLE OF ty_bl_list,
        lt_ret_bl  TYPE STANDARD TABLE OF ddshretval.

  " 2. SELECT Dữ liệu: Lấy 500 hóa đơn mới nhất (Invoice, Memo, Cancel...)
  SELECT vbeln, fkdat, erzet, ernam, fkart, netwr
    FROM vbrk
    UP TO 500 ROWS
    INTO CORRESPONDING FIELDS OF TABLE @lt_bl_list
    WHERE vbtyp IN ('M', 'O', 'P', 'S')
    ORDER BY fkdat DESCENDING, erzet DESCENDING.

  " 3. Gọi hàm hiển thị Search Help
  IF lt_bl_list IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'VBELN'
        window_title    = 'Danh sách Hóa Đơn'
        value_org       = 'S'
      TABLES
        value_tab       = lt_bl_list
        return_tab      = lt_ret_bl
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.

    " 4. Gán kết quả chọn vào biến màn hình gv_bill
    IF sy-subrc = 0 AND lt_ret_bl IS NOT INITIAL.
      READ TABLE lt_ret_bl INTO DATA(ls_ret_bl) INDEX 1.
      gv_bill = ls_ret_bl-fieldval. " <--- Đã khớp với khai báo của bạn
    ENDIF.

  ELSE.
    MESSAGE 'Không tìm thấy hóa đơn nào.' TYPE 'S' DISPLAY LIKE 'W'.
  ENDIF.

ENDMODULE.
MODULE f4_for_kunnr.
  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      tabname     = 'VBAK'
      fieldname   = 'KUNNR'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'GV_KUNNR'
    EXCEPTIONS
      OTHERS      = 1.

  IF sy-subrc <> 0.
    " MESSAGE 'Không thể gọi F4 cho KUNNR' TYPE 'E'.
  ENDIF.
ENDMODULE.


MODULE f4_for_ernam.
  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      tabname     = 'VBAK'
      fieldname   = 'ERNAM'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'GV_ERNAM'
    EXCEPTIONS
      OTHERS      = 1.

  IF sy-subrc <> 0.
    " MESSAGE 'Không thể gọi F4 cho ERNAM' TYPE 'E'.
  ENDIF.
ENDMODULE.

MODULE f4_for_doc_date.
  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      tabname     = 'VBAK'
      fieldname   = 'ERDAT'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'GV_DOC_DATE'
    EXCEPTIONS
      OTHERS      = 1.

  IF sy-subrc <> 0.
    " MESSAGE 'Không thể gọi F4 cho ERDAT' TYPE 'E'.
  ENDIF.
ENDMODULE.


*  &---------------------------------------------------------------------*
*  &      Module  VALIDATE_DATE  INPUT
*  &---------------------------------------------------------------------*
MODULE validate_date INPUT.
  IF gv_doc_date IS NOT INITIAL.
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING
        date                      = gv_doc_date
      EXCEPTIONS
        plausibility_check_failed = 1
        OTHERS                    = 2.

    IF sy-subrc <> 0.
      " [TRANSLATED] Date validation error
      MESSAGE 'Invalid date entered (DD.MM.YYYY).' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDMODULE.

*  &---------------------------------------------------------------------*
*  &      Module  VALIDATE_EXISTENCE  INPUT
*  &---------------------------------------------------------------------*
MODULE validate_existence INPUT.

  " --- 1. Check Sales Order ---
  IF gv_vbeln IS NOT INITIAL.
    DATA: lv_vbeln_check TYPE vbak-vbeln.
    lv_vbeln_check = gv_vbeln.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_vbeln_check
      IMPORTING
        output = lv_vbeln_check.

    SELECT SINGLE vbeln FROM vbak INTO @DATA(lv_tmp_so)
      WHERE vbeln = @lv_vbeln_check.
    IF sy-subrc <> 0.
      " [TRANSLATED] SO not found
      MESSAGE |Sales Order { gv_vbeln } does not exist.| TYPE 'E'.
    ENDIF.
  ENDIF.

  " --- 2. Check Customer (Sold-to Party) ---
  IF gv_kunnr IS NOT INITIAL.
    DATA: lv_kunnr_check TYPE kna1-kunnr.
    lv_kunnr_check = gv_kunnr.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_kunnr_check
      IMPORTING
        output = lv_kunnr_check.

    SELECT SINGLE kunnr FROM kna1 INTO @DATA(lv_tmp_cust)
      WHERE kunnr = @lv_kunnr_check.
    IF sy-subrc <> 0.
      " [TRANSLATED] Customer not found
      MESSAGE |Customer { gv_kunnr } does not exist.| TYPE 'E'.
    ENDIF.
  ENDIF.

  " --- 3. Check Delivery ---
  IF gv_deliv IS NOT INITIAL.
    DATA: lv_deliv_check TYPE likp-vbeln.
    lv_deliv_check = gv_deliv.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_deliv_check
      IMPORTING
        output = lv_deliv_check.

    SELECT SINGLE vbeln FROM likp INTO @DATA(lv_tmp_del)
      WHERE vbeln = @lv_deliv_check.
    IF sy-subrc <> 0.
      " [TRANSLATED] Delivery not found
      MESSAGE |Delivery Document { gv_deliv } does not exist.| TYPE 'E'.
    ENDIF.
  ENDIF.

  " --- 4. Check Billing ---
  IF gv_bill IS NOT INITIAL.
    DATA: lv_bill_check TYPE vbrk-vbeln.
    lv_bill_check = gv_bill.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_bill_check
      IMPORTING
        output = lv_bill_check.

    SELECT SINGLE vbeln FROM vbrk INTO @DATA(lv_tmp_bil)
      WHERE vbeln = @lv_bill_check.
    IF sy-subrc <> 0.
      " [TRANSLATED] Billing not found
      MESSAGE |Billing Document { gv_bill } does not exist.| TYPE 'E'.
    ENDIF.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0400  INPUT
*&---------------------------------------------------------------------*
* Handle User Actions on Screen 0400 (Dashboard Main)
* - Navigation (Back/Exit) with Memory Cleanup
* - Search Popup Trigger
* - Data Refresh
* - Drill-down navigation
*----------------------------------------------------------------------*
MODULE user_command_0400 INPUT.

  CASE sy-ucomm.

    " ------------------------------------------------------------------
    " 1. NAVIGATION & CLEANUP (Back / Exit / Cancel)
    " ------------------------------------------------------------------
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      " [CRITICAL] MEMORY CLEANUP
      " Controls must be freed in 'Bottom-Up' order (Child -> Parent).
      " References must be CLEARED to ensure correct PBO re-initialization.

      " A. Free Content Controls (Leaf Nodes)
      IF go_html_kpi_sd4 IS BOUND.
        go_html_kpi_sd4->free( ).
        CLEAR go_html_kpi_sd4. " Required for 'IS INITIAL' check in PBO
      ENDIF.

      IF go_alv_sd4 IS BOUND.
        go_alv_sd4->free( ).
        CLEAR go_alv_sd4.      " Required for 'IS INITIAL' check in PBO
      ENDIF.

      " B. Free Layout Containers (Splitters)
      IF go_split_sd4 IS BOUND.
        go_split_sd4->free( ).
        CLEAR go_split_sd4.
      ENDIF.

      " C. Free Root Container
      IF go_cc_report IS BOUND.
        go_cc_report->free( ).
        CLEAR go_cc_report.
      ENDIF.

      " D. Clear Sub-Container References
      " (These are generated by Splitter, no need to call free(), just clear ref)
      CLEAR: go_c_top_sd4, go_c_bot_sd4.

      " Return to previous screen
      LEAVE TO SCREEN 0.

    " ------------------------------------------------------------------
    " 2. FUNCTION: SEARCH
    " ------------------------------------------------------------------
    WHEN 'SEARCH'.
      CLEAR gv_exec_srch_sd4.

      " Open Search Criteria Popup (Modal Dialog)
      CALL SCREEN 0420 STARTING AT 10 5 ENDING AT 105 25.

      " Post-Processing: Only update if User clicked 'Execute' in Popup
      IF gv_exec_srch_sd4 = 'X'.
        PERFORM get_filtered_data_sd4.
        PERFORM update_dashboard_ui_sd4.
      ENDIF.

    " ------------------------------------------------------------------
    " 3. FUNCTION: REFRESH
    " ------------------------------------------------------------------
    WHEN 'REFRESH'.
      " Reload Default Data Set & Repaint UI
      PERFORM get_initial_data_sd4.
      PERFORM update_dashboard_ui_sd4.

    " ------------------------------------------------------------------
    " 4. NAVIGATION: DETAILED DASHBOARD
    " ------------------------------------------------------------------
    WHEN 'DASHBOARD'.
      " Navigate to Detailed Charts (Screen 0430)
      CALL SCREEN 0430.

  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0420  INPUT
*&---------------------------------------------------------------------*
* Handle User Input for Search Popup (Screen 0420).
* Logic:
* - EXECUTE: Sets a flag to signal the Parent Screen (0400) to
* proceed with database selection.
* - CANCEL:  Clears the flag to ensure no action is taken upon return.
*----------------------------------------------------------------------*
MODULE user_command_0420 INPUT.

  CASE sy-ucomm.

    " ------------------------------------------------------------------
    " 1. CONFIRM SELECTION (Trigger Search)
    " ------------------------------------------------------------------
    WHEN 'EXECUTE'.
      " Set Signal Flag: 'X' indicates valid criteria input.
      " The Caller (Screen 0400) checks this flag in PAI to start filtering.
      gv_exec_srch_sd4 = 'X'.

      " Close Popup & Return control to Parent Screen
      LEAVE TO SCREEN 0.

    " ------------------------------------------------------------------
    " 2. ABORT ACTION (Cancel / Close)
    " ------------------------------------------------------------------
    WHEN 'CANCEL' OR 'CLOSE'.
      " Reset Flag: Ensures the Parent Screen ignores the return action.
      CLEAR gv_exec_srch_sd4.

      LEAVE TO SCREEN 0.

  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0430  INPUT
*&---------------------------------------------------------------------*
* Handle User Actions on Screen 0430 (Detailed Charts)
* Implements standard SAP navigation behavior:
* - BACK/EXIT: Return to Parent Screen (0400)
* - CANCEL:    Abort Transaction (Leave Program)
*----------------------------------------------------------------------*
MODULE user_command_0430 INPUT.

  CASE sy-ucomm.

    " ------------------------------------------------------------------
    " 1. NAVIGATION: RETURN (F3 / Shift+F3)
    " ------------------------------------------------------------------
    WHEN 'BACK' OR 'EXIT'.
      LEAVE TO SCREEN 0.

    " ------------------------------------------------------------------
    " 2. NAVIGATION: ABORT (F12)
    " ------------------------------------------------------------------
    WHEN 'CANCEL'.
      LEAVE PROGRAM.

    " ------------------------------------------------------------------
    " 3. FUNCTION: DATA REFRESH
    " ------------------------------------------------------------------
    WHEN 'REFRESH'.
      PERFORM refresh_data_0430 USING 'ALL'.

  ENDCASE.

ENDMODULE.
