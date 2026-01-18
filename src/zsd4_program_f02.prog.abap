*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_F02
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*   SCREEN 0100 (HOME CENTER)
*   Prefix : HC_
*----------------------------------------------------------------------*

*======================================================================*
* SECTION 1: CLASS IMPLEMENTATION
*======================================================================*

*----------------------------------------------------------------------*
* CLASS lcl_hc_event_handler IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_hc_event_handler IMPLEMENTATION.

  METHOD on_sapevent.
    " Debugging purpose
    " BREAK-POINT.

    CASE action.
      WHEN 'NAVIGATE'.
        " Check payload data passed from HTML
        IF getdata = 'CREDIT'.

          " [FIXED] Sử dụng Message Text trực tiếp thay vì Message ID không tồn tại
          MESSAGE 'Opening Credit Release (VKM1)...' TYPE 'I'.

          " Note: Direct CALL TRANSACTION in event handler can cause issues
          " in complex frameworks, but is acceptable here.
          " CALL TRANSACTION 'VKM1' AND SKIP FIRST SCREEN.
        ENDIF.

        " Future implementation: Handle other navigation actions here...

      WHEN 'REFRESH'.
        " Trigger dashboard data reload
        PERFORM hc_refresh_dashboard.

    ENDCASE.

    " Clear OK_CODE to prevent unintended PAI execution
    CLEAR ok_code.

    " Synchronize automation queue with GUI (Best Practice for Custom Controls)
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

ENDCLASS.

*======================================================================*
* SECTION 2: MAIN DASHBOARD LOGIC (DISPLAY & REFRESH)
*======================================================================*

*&---------------------------------------------------------------------*
*& Form hc_display_dashboard
*&---------------------------------------------------------------------*
*& Description: Main entry point to render the Home Center.
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM hc_display_dashboard.
  " Singleton Check: Prevent re-initialization if already exists
  CHECK go_hc_container IS INITIAL.

  " 1. Fetch latest business data from Database
  PERFORM hc_fetch_data.

  " 2. Initialize Main Container (Must match Screen Layout 'CC_HOME')
  go_hc_container = NEW #( container_name = 'CC_HOME' ).

  " 3. Initialize Splitter Layout (2 Rows, 1 Column)
  go_hc_splitter = NEW #( parent  = go_hc_container
                          rows    = 2
                          columns = 1 ).

  " 4. Configure Splitter Panes
  "    Top:    KPI Dashboard (HTML) - Height 20%
  "    Bottom: Order List (ALV)     - Remaining height
  go_hc_splitter->set_row_height( id = 1 height = 20 ).
  go_hc_splitter->set_border( border = abap_false ).

  go_hc_cont_top = go_hc_splitter->get_container( row = 1 column = 1 ).
  go_hc_cont_bot = go_hc_splitter->get_container( row = 2 column = 1 ).

  " 5. Setup Top Section: HTML Viewer
  go_hc_html = NEW #( parent = go_hc_cont_top ).

  "    5.1 Register Events (Sapevent for clickable cards)
  DATA: lt_events TYPE cntl_simple_events,
        ls_event  TYPE cntl_simple_event.
  ls_event-eventid    = go_hc_html->m_id_sapevent.
  ls_event-appl_event = abap_true.
  APPEND ls_event TO lt_events.
  go_hc_html->set_registered_events( events = lt_events ).

  "    5.2 Assign Event Handler
  IF go_hc_handler IS INITIAL.
    go_hc_handler = NEW #( ).
  ENDIF.
  SET HANDLER go_hc_handler->on_sapevent FOR go_hc_html.

  "    5.3 Render HTML
  PERFORM hc_load_html_kpi.

  " 6. Setup Bottom Section: ALV Grid
  go_hc_alv = NEW #( i_parent = go_hc_cont_bot ).
  PERFORM hc_display_alv.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form hc_refresh_dashboard
*&---------------------------------------------------------------------*
*& Description: Reloads data and updates UI without destroying objects.
*&              Ensures smooth user experience (no flickering).
*&---------------------------------------------------------------------*
FORM hc_refresh_dashboard.
  " 1. Refetch latest data
  PERFORM hc_fetch_data.

  " 2. Update HTML Content (KPIs recalculation included)
  PERFORM hc_load_html_kpi.

  " 3. Refresh ALV Grid
  IF go_hc_alv IS BOUND.
    " Keep scroll position and cursor stable
    DATA: ls_stable TYPE lvc_s_stbl.
    ls_stable-row = 'X'.
    ls_stable-col = 'X'.

    go_hc_alv->refresh_table_display(
      EXPORTING is_stable = ls_stable ).

  ENDIF.

  MESSAGE s094(zsd4_msg). " Msg: Dashboard Refreshed Successfully
ENDFORM.

*======================================================================*
* SECTION 3: DATA RETRIEVAL & BUSINESS LOGIC
*======================================================================*

*&---------------------------------------------------------------------*
*& Form hc_fetch_data
*&---------------------------------------------------------------------*
*& Description: Retrieves Sales Orders, calculates KPIs, and prepares
*&              the ALV output table with status logic.
*&---------------------------------------------------------------------*
FORM hc_fetch_data.
  " --- STEP 1: CALCULATE KPI METRICS (AGGREGATIONS) ---

  " Metric: Total Created Today
  SELECT COUNT( * ) FROM vbak INTO gv_hc_total_so
    WHERE erdat = sy-datum AND vbtyp = 'C'.

  " Metric: Incomplete Orders (Open or In Process)
  SELECT COUNT( * ) FROM vbak INTO gv_hc_pending
    WHERE gbstk IN ('A','B') AND vbtyp = 'C' AND erdat >= sy-datum.

  " Metric: Total Net Value (Today)
  SELECT SUM( netwr ) FROM vbak INTO gv_hc_net_val
    WHERE erdat = sy-datum AND vbtyp = 'C'.

  " Metric: Formatted Net Value (Billion/Million)
  DATA: lv_temp_val TYPE p DECIMALS 2.
  IF gv_hc_net_val >= 1000000000.
    lv_temp_val    = gv_hc_net_val / 1000000000.
    gv_hc_net_disp = |{ lv_temp_val NUMBER = USER DECIMALS = 2 } B|.
  ELSEIF gv_hc_net_val >= 1000000.
    lv_temp_val    = gv_hc_net_val / 1000000.
    gv_hc_net_disp = |{ lv_temp_val NUMBER = USER DECIMALS = 2 } M|.
  ELSE.
    gv_hc_net_disp = |{ gv_hc_net_val NUMBER = USER }|.
  ENDIF.

  " Metric: Fully Completed (PGI Done)
  SELECT COUNT( * ) FROM vbak INTO gv_hc_pgi
    WHERE erdat = sy-datum AND vbtyp = 'C' AND gbstk = 'C'.


  " --- STEP 2: PREPARE DETAIL LIST (ALV) ---
  REFRESH gt_hc_alv_data.

  " Fetch Raw Header Data
  SELECT vbeln, erzet, ernam, gbstk, auart, vkorg, vtweg, spart, netwr, waerk
    FROM vbak
    INTO TABLE @DATA(lt_raw_so)
    WHERE erdat = @sy-datum
    ORDER BY erzet DESCENDING.

  LOOP AT lt_raw_so INTO DATA(ls_raw).
    " Map basic fields
    DATA(ls_alv) = VALUE ty_hc_alv_display(
      vbeln      = ls_raw-vbeln
      auart      = ls_raw-auart
      erzet      = ls_raw-erzet
      ernam      = ls_raw-ernam
      netwr      = ls_raw-netwr
      waerk      = ls_raw-waerk
      sales_area = |{ ls_raw-vkorg }/{ ls_raw-vtweg }/{ ls_raw-spart }|
      gbstk      = ls_raw-gbstk
    ).

    " --- STEP 3: DETERMINE LOGICAL STATUS ---

    " 3.1 Identify Business Process Group
    DATA: lv_is_delivery_group TYPE abap_bool.
    CASE ls_raw-auart.
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.
        lv_is_delivery_group = abap_true.  " Group 1: Logistics Involved
      WHEN OTHERS.
        lv_is_delivery_group = abap_false. " Group 2: Billing Only / Standard
    ENDCASE.

    " 3.2 Check Billing & Accounting (High Priority)
    DATA: lv_billing_doc TYPE vbrk-vbeln,
          lv_fi_status   TYPE vbrk-rfbsk.
    CLEAR: lv_billing_doc, lv_fi_status.

    " Note: SELECT SINGLE inside LOOP is acceptable for daily dashboard (low volume).
    " For reporting over large periods, use FOR ALL ENTRIES.
    SELECT SINGLE vbrk~vbeln, vbrk~rfbsk
      FROM vbfa
      INNER JOIN vbrk ON vbrk~vbeln = vbfa~vbeln
      INTO (@lv_billing_doc, @lv_fi_status)
      WHERE vbfa~vbelv   = @ls_raw-vbeln
        AND vbfa~vbtyp_n = 'M'       " Invoice
        AND vbrk~fksto   = @space.   " Not Cancelled

    IF sy-subrc = 0.
      IF lv_fi_status = 'C'.
        ls_alv-gbstk_txt   = 'FI Doc created'.
        ls_alv-status_icon = icon_payment.        " Icon: Payment
      ELSE.
        ls_alv-gbstk_txt   = 'Billing created'.
        ls_alv-status_icon = icon_select_detail.  " Icon: Details
      ENDIF.

      APPEND ls_alv TO gt_hc_alv_data.
      CONTINUE. " Skip remaining checks if billed
    ENDIF.

    " 3.3 Check Delivery & Goods Movement
    IF lv_is_delivery_group = abap_true.
      DATA: lv_deliv_doc TYPE likp-vbeln,
            lv_gm_status TYPE likp-wbstk.
      CLEAR: lv_deliv_doc, lv_gm_status.

      SELECT SINGLE likp~vbeln, likp~wbstk
        FROM vbfa
        INNER JOIN likp ON likp~vbeln = vbfa~vbeln
        INTO (@lv_deliv_doc, @lv_gm_status)
        WHERE vbfa~vbelv   = @ls_raw-vbeln
          AND vbfa~vbtyp_n IN ('J', 'T'). " Delivery / Return Delivery

      IF sy-subrc = 0.
        IF ls_raw-auart = 'ZRET'. " Return Process
          IF lv_gm_status = 'C'.
            ls_alv-gbstk_txt   = 'PGR Posted, ready Billing'.
            ls_alv-status_icon = icon_select_detail.
          ELSE.
            ls_alv-gbstk_txt   = 'Return Del created, ready PGR'.
            ls_alv-status_icon = icon_delivery.
          ENDIF.
        ELSE. " Sales Process
          IF lv_gm_status = 'C'.
            ls_alv-gbstk_txt   = 'PGI Posted, ready Billing'.
            ls_alv-status_icon = icon_select_detail.
          ELSE.
            ls_alv-gbstk_txt   = 'Delivery created, ready PGI'.
            ls_alv-status_icon = icon_delivery.
          ENDIF.
        ENDIF.

        APPEND ls_alv TO gt_hc_alv_data.
        CONTINUE.
      ENDIF.

      " No Delivery Found
      ls_alv-gbstk_txt   = 'Order created'.
      ls_alv-status_icon = icon_order.

    ELSE.
      " 3.4 Default Non-Delivery Process
      ls_alv-gbstk_txt   = 'Ready Billing'.
      ls_alv-status_icon = icon_order.
    ENDIF.

    APPEND ls_alv TO gt_hc_alv_data.
  ENDLOOP.
ENDFORM.

*======================================================================*
* SECTION 4: UI RENDERING (HTML & ALV)
*======================================================================*

*&---------------------------------------------------------------------*
*& Form hc_load_html_kpi
*&---------------------------------------------------------------------*
*& Description: Constructs CSS/HTML string and loads it into Viewer.
*&---------------------------------------------------------------------*
FORM hc_load_html_kpi.
  DATA: lt_data TYPE solix_tab, lv_url TYPE c LENGTH 255.

  " 1. Calculate % Completion (Handle Division by Zero)
  DATA: lv_pct TYPE p DECIMALS 1.
  IF gv_hc_total_so > 0.
    lv_pct = ( gv_hc_pgi / gv_hc_total_so ) * 100.
  ELSE.
    lv_pct = 0.
  ENDIF.

  " 2. CSS Definition (Card Layouts & Colors)
  DATA(lv_css) =
    `<style>` &&
    `:root { --bg: #f5f7fa; --card: #ffffff; --text: #32363a; --sub: #6a6d70; ` &&
    `--green: #107e3e; --blue: #0854a0; --purple: #8800cc; --orange: #d04312; } ` &&
    `body { font-family: "72", Arial, sans-serif; background: var(--bg); color: var(--text); padding: 15px; margin: 0; } ` &&
    `.grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; } ` &&
    `.card { background: var(--card); padding: 20px; border-radius: 4px; box-shadow: 0 0 2px rgba(0,0,0,0.1); ` &&
    `border-left: 4px solid transparent; display: flex; flex-direction: column; } ` &&
    `.b-blue { border-left-color: var(--blue); } .b-orange { border-left-color: var(--orange); } ` &&
    `.b-purple { border-left-color: var(--purple); } .b-green { border-left-color: var(--green); } ` &&
    `.lbl { font-size: 14px; color: var(--sub); margin-bottom: 8px; } ` &&
    `.val { font-size: 32px; font-weight: normal; margin-bottom: 5px; color: var(--text); white-space: nowrap; } ` &&
    `.foot { font-size: 12px; color: var(--sub); } ` &&
    `small { font-size: 60%; } ` &&
    `</style>`.

  " 3. HTML Body Construction (Variable Injection)
  DATA(lv_body) =
    `<body><div class="grid">` &&
    `<div class="card b-blue"><div class="lbl">Sales Orders</div>` &&
    | <div class="val">{ gv_hc_total_so NUMBER = USER }</div><div class="foot">Created Today</div></div>| &&
    `<div class="card b-orange"><div class="lbl">Incomplete Orders</div>` &&
    | <div class="val">{ gv_hc_pending NUMBER = USER }</div><div class="foot">Open & In Process</div></div>| &&
    `<div class="card b-purple"><div class="lbl">Net Value (Today)</div>` &&
    | <div class="val">{ gv_hc_net_disp } <small>VND</small></div><div class="foot">Estimated Revenue</div></div>| &&
    `<div class="card b-green"><div class="lbl">Completion Rate</div>` &&
    | <div class="val" style="color:var(--green)">{ lv_pct NUMBER = USER DECIMALS = 1 }%</div>| &&
    | <div class="foot">Fully Completed ({ gv_hc_pgi NUMBER = USER })</div></div>| &&
    `</div></body>`.

  " 4. Convert String to Binary & Display
  DATA(lv_html) = `<!DOCTYPE html><html><head>` && lv_css && `</head>` && lv_body && `</html>`.
  DATA(lv_raw) = cl_abap_codepage=>convert_to( source = lv_html ).
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY' EXPORTING buffer = lv_raw TABLES binary_tab = lt_data.

  go_hc_html->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_data ).
  go_hc_html->show_url( url = lv_url ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form hc_display_alv
*&---------------------------------------------------------------------*
*& Description: Configures Field Catalog and Layout for ALV Grid.
*&---------------------------------------------------------------------*
FORM hc_display_alv.
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_layo TYPE lvc_s_layo.

  " --- FIELD CATALOG CONFIGURATION ---
  lt_fcat = VALUE #(
      " Status Icon
      ( fieldname = 'STATUS_ICON' coltext = 'Sts'      icon = 'X' outputlen = 4 just = 'C' )
      " Overall Status
      ( fieldname = 'GBSTK_TXT'   coltext = 'Overall Status' outputlen = 25 just = 'L' )
      " Sales Doc (Clickable)
      ( fieldname = 'VBELN'       coltext = 'Sales Document' hotspot = 'X' outputlen = 15 just = 'L' convexit = 'ALPHA' )
      " Created By
      ( fieldname = 'ERNAM'       coltext = 'Created By'     outputlen = 15 )
      " Time
      ( fieldname = 'ERZET'       coltext = 'Time'           outputlen = 10 just = 'C' )
      " Type
      ( fieldname = 'AUART'       coltext = 'Type'           outputlen = 8 just = 'C' )
      " Sales Area
      ( fieldname = 'SALES_AREA'  coltext = 'Sales Area'     outputlen = 25 )
      " Net Value (Currency Linked)
      ( fieldname = 'NETWR'
        coltext    = 'Net Value'
        do_sum     = 'X'
        outputlen  = 15
        cfieldname = 'WAERK'   " Currency Link
        ref_table  = 'VBAK'
        ref_field  = 'NETWR' )
      " Currency
      ( fieldname = 'WAERK'       coltext = 'Curr.'          outputlen = 5 just = 'L' )
  ).

  " --- LAYOUT CONFIGURATION ---
  ls_layo-zebra      = 'X'.
  ls_layo-sel_mode   = 'A'.
  ls_layo-grid_title = 'Recent Sales Documents (Today)'.
  ls_layo-no_toolbar = 'X'.
  ls_layo-no_rowmark = 'X'.
  " Note: cwidth_opt disabled intentionally to allow columns to stretch

  go_hc_alv->set_table_for_first_display(
    EXPORTING is_layout       = ls_layo
    CHANGING  it_outtab       = gt_hc_alv_data
              it_fieldcatalog = lt_fcat
  ).

ENDFORM.

*======================================================================*
* SECTION 5: HELPER FORMS (POPUPS)
*======================================================================*

*&---------------------------------------------------------------------*
*& Form popup_select_so_action
*&---------------------------------------------------------------------*
*& Description: Displays Popup for Sales Order actions.
*&---------------------------------------------------------------------*
*& <-> cv_answer : User selection ('1', '2'...)
*&---------------------------------------------------------------------*
FORM popup_select_so_action CHANGING cv_answer TYPE c.
  DATA: lt_spopli TYPE TABLE OF spopli,
        ls_spopli TYPE spopli.

  CLEAR cv_answer.

  " Define Options
  ls_spopli-varoption = '1. Create Single Order'.
  APPEND ls_spopli TO lt_spopli.
  ls_spopli-varoption = '2. Mass Upload Orders'.
  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel              = 'Manage Sales Order'
      textline1          = 'Please select an action:'
      cursorline         = 1
      display_only       = space
    IMPORTING
      answer             = cv_answer
    TABLES
      t_spopli           = lt_spopli
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_much_marks     = 3
      OTHERS             = 4.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form popup_select_billing_action
*&---------------------------------------------------------------------*
*& Description: Displays Popup for Billing actions.
*&---------------------------------------------------------------------*
*& <-> cv_answer : User selection
*&---------------------------------------------------------------------*
FORM popup_select_billing_action CHANGING cv_answer TYPE c.
  DATA: lt_spopli TYPE TABLE OF spopli,
        ls_spopli TYPE spopli.

  CLEAR cv_answer.

  ls_spopli-varoption = '1. Create Single Billing'.
  APPEND ls_spopli TO lt_spopli.
  ls_spopli-varoption = '2. Search & Process Billing'.
  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel              = 'Manage Billing'
      textline1          = 'Please select an action:'
      cursorline         = 1
    IMPORTING
      answer             = cv_answer
    TABLES
      t_spopli           = lt_spopli
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_much_marks     = 3
      OTHERS             = 4.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form popup_select_overview_action
*&---------------------------------------------------------------------*
*& Description: Displays Popup for Report selection.
*&---------------------------------------------------------------------*
*& <-> cv_answer : User selection
*&---------------------------------------------------------------------*
FORM popup_select_overview_action CHANGING cv_answer TYPE c.
  DATA: lt_spopli TYPE TABLE OF spopli,
        ls_spopli TYPE spopli.

  CLEAR cv_answer.

  ls_spopli-varoption = '1. Track Sales Order (Details Status)'.
  APPEND ls_spopli TO lt_spopli.
  ls_spopli-varoption = '2. Report Monitoring (General View)'.
  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel              = 'Overview & Reports'
      textline1          = 'Please select a report:'
      cursorline         = 1
    IMPORTING
      answer             = cv_answer
    TABLES
      t_spopli           = lt_spopli
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_much_marks     = 3
      OTHERS             = 4.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* CLASS lcl_mu_event_handler IMPLEMENTATION 0210
*----------------------------------------------------------------------*
CLASS lcl_mu_event_handler IMPLEMENTATION.

  METHOD handle_node_double_click.

    " 1. Trước khi vẽ màn hình mới, ta phải lưu những gì user vừa nhập
    " ở màn hình cũ vào bảng nội bộ (GT_MU_HEADER / GT_MU_ITEM).
    " Nếu không có dòng này, khi user nhập xong và click sang node khác,
    " dữ liệu vừa nhập sẽ bị mất.
    PERFORM save_current_data.

    " 2. Xác định User đang click vào cái gì (Header hay Item?)
    " Node Key quy ước: H_001 (Header 1), I_001_10 (Item 10 của H001)

    DATA: lv_type TYPE char1.
    lv_type = node_key(1). " Lấy ký tự đầu tiên: H hoặc I

    " 3. Điều hướng màn hình Subscreen
    IF lv_type = 'H'.
      gv_mu_subscreen = '0211'. " Header View

      " Tìm dòng dữ liệu trong bảng nội bộ tương ứng với Node Key
      " Ví dụ: Lấy ID H001 từ key 'H_001', đọc bảng gt_header vào gs_mu_header
      PERFORM prepare_header_detail USING node_key.

    ELSEIF lv_type = 'I'.
      gv_mu_subscreen = '0212'. " Item View

      " Tương tự, đọc bảng item vào gs_mu_item
      PERFORM prepare_item_detail USING node_key.
    ENDIF.

    " 4. Cap nhat bien theo doi
    gv_prev_node_key = node_key.

    " 5. Refresh màn hình để hiện dữ liệu mới
    cl_gui_cfw=>set_new_ok_code( new_code = 'REFRESH_SCREEN' ).

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*&      Form  PREPARE_HEADER_DETAIL
*&---------------------------------------------------------------------*
* Lấy dữ liệu từ bảng nội bộ (500 dòng) đổ vào cấu trúc màn hình (1 dòng)
*----------------------------------------------------------------------*
FORM prepare_header_detail USING pv_node_key TYPE tv_nodekey.

  " 1. Khai báo biến hứng Temp ID (theo kiểu của bảng Z)
  DATA: lv_temp_id TYPE ztb_so_upload_hd-temp_id.

  " 2. Parse Key: Bỏ ký tự 'H' đầu tiên để lấy Temp ID gốc
  " Ví dụ: Node Key = 'H_H001' -> lv_temp_id = 'H001'
  lv_temp_id = pv_node_key+1.

  " 3. Đọc từ bảng nội bộ
  CLEAR gs_mu_header.

  " [FIX]: Dùng field TEMP_ID để tìm kiếm thay vì VBELN
  READ TABLE gt_mu_header INTO gs_mu_header
    WITH KEY temp_id = lv_temp_id.

  IF sy-subrc = 0.

    " 1. Xử lý số Sales Order (Ví dụ: 0070000697 -> 70000697)
    IF gs_mu_header-vbeln_so IS NOT INITIAL.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = gs_mu_header-vbeln_so
        IMPORTING
          output = gs_mu_header-vbeln_so.
    ENDIF.

    " 2. Xử lý số Delivery (Ví dụ: 0080000104 -> 80000104)
    IF gs_mu_header-vbeln_dlv IS NOT INITIAL.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = gs_mu_header-vbeln_dlv
        IMPORTING
          output = gs_mu_header-vbeln_dlv.
    ENDIF.
  ELSE.
    " Reset màn hình nếu không tìm thấy
    CLEAR gs_mu_header.
  ENDIF.

  " 4. (Quan trọng) Gọi Refresh ALV Item bên dưới cho Header này
  " Logic này cần thiết để khi click Header thì list Item bên dưới cũng đổi theo
  PERFORM show_alv_items.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PREPARE_ITEM_DETAIL
*&---------------------------------------------------------------------*
* Lấy dữ liệu Item đổ vào màn hình Item Detail
*----------------------------------------------------------------------*
FORM prepare_item_detail USING pv_node_key TYPE tv_nodekey.

  " 1. Khai báo biến đúng kiểu bảng Z
  DATA: lv_temp_id TYPE ztb_so_upload_it-temp_id,
        lv_item_no TYPE ztb_so_upload_it-item_no, " [FIX] Dùng ITEM_NO thay POSNR
        lv_str     TYPE string.

*  " 2. Parse Key: Ví dụ Node Key = 'I_H001_10'
*  lv_str = pv_node_key+1. " Bỏ chữ 'I' đầu -> 'H001_10'
*
*  " Tách chuỗi tại dấu gạch dưới '_'
*  SPLIT lv_str AT '_' INTO lv_temp_id lv_item_no.

  " Key Format: I + TempID + _ + ItemNo (Ví dụ: IH001_10)
  lv_str = pv_node_key.
  SHIFT lv_str LEFT BY 1 PLACES. " Bỏ chữ I đầu -> H001_10

  " Tách tại dấu _
  SPLIT lv_str AT '_' INTO lv_temp_id lv_item_no.

  " Xử lý conversion (nếu Item No trong DB lưu dạng 000010)
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_item_no
    IMPORTING
      output = lv_item_no.

  " 3. Đọc từ bảng nội bộ Item
  CLEAR gs_mu_item.

  " [FIX] Dùng TEMP_ID và ITEM_NO để tìm kiếm
  READ TABLE gt_mu_item INTO gs_mu_item
    WITH KEY temp_id = lv_temp_id
             item_no = lv_item_no.

  " 4. (Quan trọng) Gọi Refresh ALV Condition bên dưới cho Item này
  PERFORM show_alv_conditions.

ENDFORM.

*&---------------------------------------------------------------------*
*& Screen 300 - SINGLE UPLOAD
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form get_and_set_derived_fields
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_SOLD_TO
*&---------------------------------------------------------------------*
FORM get_and_set_derived_fields USING iv_kunnr TYPE kunnr.

  " --- 1. Xác định Pricing Procedure (KAL_SM) ---
  " Lấy KALVG (Doc. Pricing Proc) từ Order Type (TVAK)
  SELECT SINGLE kalvg INTO @DATA(lv_kalvg) FROM tvak
    WHERE auart = @gs_so_heder_ui-so_hdr_auart.

  " Lấy KALKS (Cust. Pricing Proc) từ KNVV (Đã có trong SELECT ở pai_derive_data, nhưng SELECT lại cho an toàn)
*  SELECT SINGLE kalks INTO @DATA(lv_kalks) FROM knvv
*    WHERE kunnr = @iv_kunnr
*      AND vkorg = @gs_so_heder_ui-so_hdr_vkorg.

  SELECT SINGLE kalks
    INTO @DATA(lv_kalks)
    FROM knvv
   WHERE kunnr = @iv_kunnr
     AND vkorg = @gs_so_heder_ui-so_hdr_vkorg
     AND vtweg = @gs_so_heder_ui-so_hdr_vtweg
     AND spart = @gs_so_heder_ui-so_hdr_spart.

  " Tra cứu trong T683V
  SELECT SINGLE kalsm INTO @gs_so_heder_ui-so_hdr_kalsm " <<< ĐIỀN KAL_SM
    FROM t683v
    WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg
      AND vtweg = @gs_so_heder_ui-so_hdr_vtweg
      AND spart = @gs_so_heder_ui-so_hdr_spart
      AND kalvg = @lv_kalvg
      AND kalks = @lv_kalks.

  " --- 2. Sales Area Text ---
*  SELECT SINGLE vtext INTO @DATA(lv_vkorg_txt) FROM tvkot
*    WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg.
  SELECT SINGLE vtext
      INTO @DATA(lv_vkorg_txt)
      FROM tvkot
      WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg
       AND spras = @sy-langu.
*  SELECT SINGLE vtext INTO @DATA(lv_vtweg_txt) FROM tvtwt
*    WHERE vtweg = @gs_so_heder_ui-so_hdr_vtweg.
  SELECT SINGLE vtext
     INTO @DATA(lv_vtweg_txt)
     FROM tvtwt
    WHERE vtweg = @gs_so_heder_ui-so_hdr_vtweg
      AND spras = @sy-langu.
*  SELECT SINGLE vtext INTO @DATA(lv_spart_txt) FROM tspat
*    WHERE spart = @gs_so_heder_ui-so_hdr_spart.
  SELECT SINGLE vtext
      INTO @DATA(lv_spart_txt)
      FROM tspat
     WHERE spart = @gs_so_heder_ui-so_hdr_spart
       AND spras = @sy-langu.

  " ĐIỀN SALES AREA TEXT (FIELD output only)
  gs_so_heder_ui-so_hdr_salesarea = |{ gs_so_heder_ui-so_hdr_vkorg }/{ gs_so_heder_ui-so_hdr_vtweg }/{ gs_so_heder_ui-so_hdr_spart } ({ lv_vkorg_txt } - { lv_vtweg_txt } - { lv_spart_txt })|.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form default_dates_after_soldto
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM default_dates_after_soldto .
  " Logic này chỉ gán nếu trường còn rỗng
  IF gs_so_heder_ui-so_hdr_audat IS INITIAL.
    gs_so_heder_ui-so_hdr_audat = sy-datum. " Document Date
  ENDIF.
  IF gs_so_heder_ui-so_hdr_prsdt IS INITIAL.
    gs_so_heder_ui-so_hdr_prsdt = sy-datum. " Pricing Date
  ENDIF.
  IF gs_so_heder_ui-so_hdr_ketdat IS INITIAL.
    gs_so_heder_ui-so_hdr_ketdat = sy-datum. " Req. Deliv. Date
  ENDIF.
  IF gs_so_heder_ui-so_hdr_fkdat IS INITIAL.
    gs_so_heder_ui-so_hdr_fkdat = sy-datum. " Billing Date
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form perform_exit_confirmation
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LV_ACTION
*&---------------------------------------------------------------------*
FORM perform_exit_confirmation
  CHANGING
    cv_action TYPE c.

  DATA: lv_answer TYPE c.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar       = 'Exit Order Processing'
      text_question  = 'Do you wish to save your data first?'
      text_button_1  = 'Yes'
      text_button_2  = 'No'
      default_button = '1'
    IMPORTING
      answer         = lv_answer
    EXCEPTIONS
      text_not_found = 1
      OTHERS         = 2.

  IF sy-subrc <> 0.
    " Nếu Popup bị lỗi không hiện được, ta có thể gán mặc định là Cancel ('A')
    " hoặc xử lý thông báo lỗi hệ thống (tùy logic của bạn)
    lv_answer = 'A'.
  ENDIF.

  CASE lv_answer.
    WHEN '1'. " User chọn YES
      " --- SỬA: Khai báo bảng dùng kiểu global ---
      DATA: lt_incomp_log TYPE ty_t_incomp_log.

      PERFORM perform_incompletion_check
        TABLES
         lt_incomp_log. " <<< Dùng biến đã khai báo

      IF lt_incomp_log IS INITIAL.
        cv_action = 'SAVE'.
      ELSE.
        DATA lv_answer2 TYPE c.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar       = 'Save Incomplete Document'
            text_question  = 'Would you like to save or edit the incomplete document?'
            text_button_1  = 'Save'
            text_button_2  = 'Edit'
            default_button = '2'
          IMPORTING
            answer         = lv_answer2
          EXCEPTIONS
            text_not_found = 1
            OTHERS         = 2.

        IF sy-subrc <> 0.
          " Nếu Popup bị lỗi không hiện được, ta có thể gán mặc định là Cancel ('A')
          " hoặc xử lý thông báo lỗi hệ thống (tùy logic của bạn)
          lv_answer = 'A'.
        ENDIF.

        CASE lv_answer2.
          WHEN '1'.
            cv_action = 'SAVE'.
          WHEN '2'.
            PERFORM display_incompletion_popup TABLES lt_incomp_log.
            cv_action = 'STAY'.
          WHEN 'A'.
            cv_action = 'STAY'.
        ENDCASE.
      ENDIF.

    WHEN '2'.
      cv_action = 'BACK'.
    WHEN 'A'.
      cv_action = 'STAY'.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form reset_single_entry_screen
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM reset_single_entry_screen .
  " Xóa các trường Header (trừ Org Data)
  CLEAR: gs_so_heder_ui-so_hdr_vbeln,
         gs_so_heder_ui-so_hdr_audat, " Sẽ được PBO default lại
         gs_so_heder_ui-so_hdr_sold_addr,
         gs_so_heder_ui-so_hdr_bstnk,
         gs_so_heder_ui-so_hdr_kalsm,
         gs_so_heder_ui-so_hdr_waerk,
         gs_so_heder_ui-so_hdr_zterm,
         gs_so_heder_ui-so_hdr_inco1,
         gs_so_heder_ui-so_hdr_message.

  " Xóa Item ALV
  REFRESH gt_item_details.

  " --- SỬA LỖI: Hủy CẢ Handler VÀ Grid ---
  IF go_event_handler_single IS BOUND.
    FREE go_event_handler_single. " Hủy handler
  ENDIF.

  IF go_grid_item_single IS BOUND.
    " Dùng .free() để hủy control ở frontend
    go_grid_item_single->free( ).
    " Dùng CLEAR để hủy đối tượng ở backend
    CLEAR go_grid_item_single.
  ENDIF.
  " --- KẾT THÚC SỬA LỖI ---

  IF go_grid_item_single IS BOUND.
    go_grid_item_single->refresh_table_display( ).
  ENDIF.

  IF go_cont_item_single IS BOUND. " <<< THÊM DÒNG NÀY
    go_cont_item_single->free( ).   " <<< THÊM DÒNG NÀY
    CLEAR go_cont_item_single.     " <<< THÊM DÒNG NÀY
  ENDIF.
  " --- KẾT THÚC SỬA LỖI ---

  " Đặt lại trạng thái màn hình (nếu bạn dùng)
  gv_screen_state = '0'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form perform_incompletion_check
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_INCOMP_LOG
*&---------------------------------------------------------------------*
FORM perform_incompletion_check
  TABLES
    ct_incomplete_log TYPE ty_t_incomp_log. " <<< SỬA: Dùng kiểu global

  DATA: ls_incomp_log TYPE ty_incomp_log. " (Khai báo work area)

  REFRESH ct_incomplete_log.

  " === THỰC HIỆN KIỂM TRA ===
  IF gs_so_heder_ui-so_hdr_bstnk IS INITIAL.
    ls_incomp_log-group_desc = 'Missing Data'.
    ls_incomp_log-cell_cont  = 'Cust. Reference'.
    APPEND ls_incomp_log TO ct_incomplete_log.
  ENDIF.
  IF gs_so_heder_ui-so_hdr_inco1 IS INITIAL.
    ls_incomp_log-group_desc = 'Missing Data'.
    ls_incomp_log-cell_cont  = 'Incoterms'.
    APPEND ls_incomp_log TO ct_incomplete_log.
  ENDIF.
  IF gs_so_heder_ui-so_hdr_zterm IS INITIAL.
    ls_incomp_log-group_desc = 'Missing Data'.
    ls_incomp_log-cell_cont  = 'Pyt Terms'.
    APPEND ls_incomp_log TO ct_incomplete_log.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_incompletion_popup
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_INCOMP_LOG
*&---------------------------------------------------------------------*
FORM display_incompletion_popup
  TABLES
    it_incomp_log TYPE ty_t_incomp_log. " <<< SỬA: Dùng kiểu global

  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_fieldcat TYPE slis_fieldcat_alv,
        ls_selfield TYPE slis_selfield.

  " 1. Build Field Catalog thủ công
  REFRESH lt_fieldcat.
  ls_fieldcat-fieldname = 'GROUP_DESC'.
  ls_fieldcat-tabname   = 'IT_INCOMP_LOG'.
  ls_fieldcat-seltext_m = 'Group description'.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CELL_CONT'.
  ls_fieldcat-tabname   = 'IT_INCOMP_LOG'.
  ls_fieldcat-seltext_m = 'Cell Content...'.
  APPEND ls_fieldcat TO lt_fieldcat.

  " 2. Gọi ALV Popup
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = 'Create Sales Order: Incompletion Log'
      i_selection           = 'X'
      i_zebra               = 'X'
      i_screen_start_column = 10
      i_screen_start_line   = 5
      i_screen_end_column   = 90
      i_screen_end_line     = 10
      i_scroll_to_sel_line  = 'X'
      i_tabname             = 'IT_INCOMP_LOG'
      it_fieldcat           = lt_fieldcat
      i_callback_program    = sy-repid
    IMPORTING
      es_selfield           = ls_selfield
    TABLES
      t_outtab              = it_incomp_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.

FORM display_conditions_for_item USING iv_item_index TYPE sy-tabix.

  FIELD-SYMBOLS <fs_item> TYPE ty_item_details.

  " Khai báo biến cục bộ cho BAPI
  DATA: ls_header_in  TYPE bapisdhead,
        lt_item_in    TYPE TABLE OF bapiitemin,
        lt_partner_in TYPE TABLE OF bapipartnr,
        lt_sched_in   TYPE TABLE OF bapischdl,
        lt_cond_out   TYPE TABLE OF bapicond,
        lt_return     TYPE TABLE OF bapiret2.

  " Biến cho Cache
  DATA: ls_cache TYPE ty_cond_cache.

  " 1. Đọc Item hiện tại từ bảng chi tiết
  READ TABLE gt_item_details ASSIGNING <fs_item> INDEX iv_item_index.
  IF sy-subrc <> 0.
    REFRESH gt_conditions_alv.
    IF go_grid_conditions IS BOUND.
      go_grid_conditions->refresh_table_display( ).
    ENDIF.
    EXIT.
  ENDIF.

  " ====================================================================
  " BƯỚC 1: CHECK CACHE TỪ BẢNG GLOBAL (QUAN TRỌNG)
  " ====================================================================
  " Logic: Kiểm tra xem Item này đã có dữ liệu Condition trong bộ nhớ chưa?
  " Nếu có (do user vừa nhập hoặc đã load trước đó) -> Lấy ra dùng ngay.

  READ TABLE gt_cond_cache INTO ls_cache WITH TABLE KEY item_no = <fs_item>-item_no.

  IF sy-subrc = 0 AND ls_cache-conditions IS NOT INITIAL..
    " >>> FOUND IN CACHE: Dùng lại dữ liệu cũ, KHÔNG gọi BAPI
    gt_conditions_alv = ls_cache-conditions.

    " Refresh ALV và thoát Form ngay lập tức
    IF go_grid_conditions IS BOUND.
      DATA: ls_stable TYPE lvc_s_stbl.
      ls_stable-row = 'X'. ls_stable-col = 'X'.
      go_grid_conditions->refresh_table_display( is_stable = ls_stable ).

      DATA(lv_rows_cache) = lines( gt_conditions_alv ).
      go_grid_conditions->set_gridtitle( |Pricing Elements ({ lv_rows_cache } rows)| ).
    ENDIF.
    RETURN. " <--- THOÁT NGAY, KHÔNG CHẠY XUỐNG DƯỚI
  ENDIF.


  " ====================================================================
  " BƯỚC 2: CHUẨN BỊ VÀ GỌI BAPI SIMULATION (CHỈ CHẠY KHI CACHE RỖNG)
  " ====================================================================

  " Cập nhật biến Global loại Order (để chắc chắn)
  gv_order_type = gs_so_heder_ui-so_hdr_auart.

  " --- Map Header ---
  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.

  " --- Map Partner ---
  DATA(lv_sold_to) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner_in.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner_in.

  " --- Map Item ---
  DATA(lv_matnr_bapi) = <fs_item>-matnr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.

  DATA(ls_item_bapi) = VALUE bapiitemin(
                         itm_number = <fs_item>-item_no
                         material   = lv_matnr_bapi
                         plant      = <fs_item>-plant
                         store_loc  = <fs_item>-store_loc ).

  " Xử lý riêng cho ZDR (Target Qty) và ZORR (Req Qty)
  IF gs_so_heder_ui-so_hdr_auart = 'ZDR'.
    ls_item_bapi-target_qty = <fs_item>-quantity.
    ls_item_bapi-target_qu  = <fs_item>-unit.
    APPEND ls_item_bapi TO lt_item_in.
    " ZDR không cần Schedule line cho Pricing Simulation
  ELSE.
    APPEND ls_item_bapi TO lt_item_in.
    APPEND VALUE #( itm_number = <fs_item>-item_no
                    req_qty    = <fs_item>-quantity
                    req_date   = <fs_item>-req_date ) TO lt_sched_in.
  ENDIF.

  " --- Gọi BAPI ---
  CALL FUNCTION 'BAPI_SALESORDER_SIMULATE'
    EXPORTING
      order_header_in    = ls_header_in
    TABLES
      order_items_in     = lt_item_in
      order_partners     = lt_partner_in
      order_schedule_in  = lt_sched_in
      order_condition_ex = lt_cond_out
      messagetable       = lt_return.

  " ====================================================================
  " BƯỚC 3: PHÂN TÍCH KẾT QUẢ BAPI
  " ====================================================================
  DATA: lv_bapi_price TYPE kbetr,
        lv_bapi_curr  TYPE waers,
        lv_bapi_per   TYPE kpein,
        lv_bapi_uom   TYPE kmein,
        lv_bapi_tax   TYPE kbetr.

  " Mặc định
  lv_bapi_curr = 'VND'.
  lv_bapi_per  = 1.
  lv_bapi_uom  = <fs_item>-unit.

  " Lấy giá từ BAPI Output
  LOOP AT lt_cond_out ASSIGNING FIELD-SYMBOL(<fs_cond_out>).
    CASE <fs_cond_out>-cond_type.
      WHEN 'ZPRQ' OR 'PR00'. " Giá gốc
        lv_bapi_price = <fs_cond_out>-cond_value.
        lv_bapi_curr  = <fs_cond_out>-currency.
        lv_bapi_per   = <fs_cond_out>-cond_p_unt.
        lv_bapi_uom   = <fs_cond_out>-cond_unit.
      WHEN 'ZTAX' OR 'MWST'. " Thuế
        lv_bapi_tax   = <fs_cond_out>-cond_value.
        " Fix logic % nếu BAPI trả về 0.08 mà muốn hiện 8
        IF lv_bapi_tax < 1 AND lv_bapi_tax > 0.
          lv_bapi_tax = lv_bapi_tax * 100.
        ENDIF.
    ENDCASE.
  ENDLOOP.

  " Ưu tiên: Nếu tab Item đã có Unit Price (do user nhập), lấy giá đó
  IF <fs_item>-unit_price IS NOT INITIAL.
    lv_bapi_price = <fs_item>-unit_price.
  ENDIF.

  IF lv_bapi_tax IS INITIAL. lv_bapi_tax = 8. ENDIF. " Default thuế nếu không thấy

  " ====================================================================
  " BƯỚC 4: BUILD ALV THEO LOẠI ORDER (ZORR vs ZDR)
  " ====================================================================
  REFRESH gt_conditions_alv.

  CASE gs_so_heder_ui-so_hdr_auart.

      " --- Case ZORR (Sales Order) ---
    WHEN 'ZORR' OR 'ZTP'.
      PERFORM build_conditions_zorr
        USING lv_bapi_price
              lv_bapi_tax
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.

      " --- Case ZDR (Debit Memo Request) ---
    WHEN 'ZDR'.
      PERFORM build_conditions_zdr
        USING lv_bapi_price
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.

      " --- [MỚI] Case ZCRR (Credit) ---
    WHEN 'ZCRR'.
      PERFORM build_conditions_zcrr " Dùng ZCRP
        USING lv_bapi_price
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.

      " >>> [MỚI] THÊM CASE ZRET
    WHEN 'ZRET'.
      PERFORM build_conditions_zret
        USING lv_bapi_price
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.
      " >>> [MỚI]
    WHEN 'ZSC'.
      PERFORM build_conditions_zsc
        USING lv_bapi_price
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.
      " >>> [MỚI] CASE ZFOC
    WHEN 'ZFOC'.
      PERFORM build_conditions_zfoc
        USING lv_bapi_price
              lv_bapi_curr
              lv_bapi_per
              lv_bapi_uom
              <fs_item>-quantity.

      " --- Case Default ---
    WHEN OTHERS.
      " Gọi logic mặc định (ví dụ giống ZORR)
      PERFORM build_conditions_zorr
       USING lv_bapi_price
             lv_bapi_tax
             lv_bapi_curr
             lv_bapi_per
             lv_bapi_uom
             <fs_item>-quantity.
  ENDCASE.

  " ====================================================================
  " BƯỚC 5: LƯU VÀO CACHE GLOBAL (QUAN TRỌNG)
  " ====================================================================
  " Lưu lại kết quả vừa tính toán để lần sau check ở Bước 1 sẽ thấy

  ls_cache-item_no    = <fs_item>-item_no.
  ls_cache-conditions = gt_conditions_alv.

  INSERT ls_cache INTO TABLE gt_cond_cache.
  IF sy-subrc <> 0.
    MODIFY TABLE gt_cond_cache FROM ls_cache.
  ENDIF.

  " ====================================================================
  " BƯỚC 6: REFRESH HIỂN THỊ
  " ====================================================================
  IF go_grid_conditions IS BOUND.
    go_grid_conditions->refresh_table_display( ).
    DATA(lv_rows) = lines( gt_conditions_alv ).
    go_grid_conditions->set_gridtitle( |Pricing Elements ({ lv_rows } rows)| ).
  ENDIF.

ENDFORM.

FORM perform_single_item_simulate.

  " === 1. Khai báo biến ===
  DATA: ls_header_in  TYPE bapisdhead,
        lt_item_in    TYPE TABLE OF bapiitemin,
        lt_partner_in TYPE TABLE OF bapipartnr,
        lt_sched_in   TYPE TABLE OF bapischdl.

  " [THÊM MỚI] Khai báo biến dùng chung để tránh lỗi 'already declared'
  DATA: lv_base_new TYPE kwert.

  " Các bảng Output
  DATA: lt_item_out        TYPE TABLE OF bapiitemex,
        lt_sched_out       TYPE TABLE OF bapisdhedu,
        lt_cond_out        TYPE TABLE OF bapicond,
        lt_return          TYPE TABLE OF bapiret2,
        lt_incomplete      TYPE TABLE OF bapiincomp,
        lv_errors_occurred TYPE abap_bool.

  FIELD-SYMBOLS: <fs_item>      LIKE LINE OF gt_item_details,
                 <fs_item_out>  LIKE LINE OF lt_item_out,
                 <fs_sched_out> LIKE LINE OF lt_sched_out,
                 <fs_cond_out>  LIKE LINE OF lt_cond_out.

  " === 2. Chuẩn bị Header & Partner ===
  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.

  IF gs_so_heder_ui-so_hdr_prsdt IS NOT INITIAL.
    ls_header_in-price_date = gs_so_heder_ui-so_hdr_prsdt.
  ENDIF.

  DATA(lv_sold_to) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner_in.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner_in.

  " === 3. Chuẩn bị Item & Schedule Line ===
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    IF <fs_item>-matnr IS INITIAL. CONTINUE. ENDIF.

    DATA(lv_posnr) = sy-tabix * 10.
    DATA(lv_matnr_bapi) = <fs_item>-matnr.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.

    DATA(ls_item_bapi) = VALUE bapiitemin(
                           itm_number = lv_posnr
                           material   = lv_matnr_bapi
                           plant      = <fs_item>-plant
                           store_loc  = <fs_item>-store_loc ).

    " [PHÂN LOẠI 1]: ZDR/ZCRR dùng Target Qty, còn lại dùng Schedule Line
    IF gs_so_heder_ui-so_hdr_auart = 'ZDR' OR gs_so_heder_ui-so_hdr_auart = 'ZCRR'.

      ls_item_bapi-target_qty = <fs_item>-quantity.
      ls_item_bapi-target_qu  = <fs_item>-unit.
      APPEND ls_item_bapi TO lt_item_in.

    ELSE. " ZORR, ZTP, ZRET, ZSC

      APPEND ls_item_bapi TO lt_item_in.

      DATA lv_sched_date TYPE dats.
      IF <fs_item>-req_date IS NOT INITIAL AND <fs_item>-req_date <> '00000000'.
        lv_sched_date = <fs_item>-req_date.
      ELSE.
        lv_sched_date = gs_so_heder_ui-so_hdr_ketdat.
      ENDIF.

      APPEND VALUE #( itm_number = lv_posnr
                      req_qty    = <fs_item>-quantity
                      req_date   = lv_sched_date ) TO lt_sched_in.
    ENDIF.
  ENDLOOP.

  IF lt_item_in IS INITIAL. RETURN. ENDIF.

  " === 4. Gọi BAPI SIMULATE ===
  CALL FUNCTION 'BAPI_SALESORDER_SIMULATE'
    EXPORTING
      order_header_in    = ls_header_in
    TABLES
      order_items_in     = lt_item_in
      order_partners     = lt_partner_in
      order_schedule_in  = lt_sched_in
      order_items_out    = lt_item_out
      order_schedule_ex  = lt_sched_out
      order_condition_ex = lt_cond_out
      order_incomplete   = lt_incomplete
      messagetable       = lt_return.

  " === 5. Cập nhật dữ liệu trả về vào BẢNG NỘI BỘ ALV ===
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    lv_posnr = sy-tabix * 10.

    READ TABLE lt_item_out ASSIGNING <fs_item_out> WITH KEY itm_number = lv_posnr.
    IF sy-subrc = 0.
      <fs_item>-item_no     = <fs_item_out>-itm_number.
      <fs_item>-description = <fs_item_out>-short_text.
      <fs_item>-itca        = <fs_item_out>-item_categ.
      <fs_item>-currency    = gs_so_heder_ui-so_hdr_waerk.
      <fs_item>-plant       = <fs_item_out>-plant.
      <fs_item>-unit        = <fs_item_out>-sales_unit.
      <fs_item>-net_value   = <fs_item_out>-net_value.
      <fs_item>-tax         = <fs_item_out>-net_value1.

      IF <fs_item>-quantity IS NOT INITIAL AND <fs_item>-quantity <> 0.
        <fs_item>-net_price  = <fs_item>-net_value / <fs_item>-quantity.
        <fs_item>-unit_price = <fs_item>-net_price.
      ENDIF.

      " [PHÂN LOẠI 2]: Lấy Confirmed Qty
      IF gs_so_heder_ui-so_hdr_auart = 'ZDR' OR gs_so_heder_ui-so_hdr_auart = 'ZCRR'.
        <fs_item>-conf_qty = <fs_item_out>-target_qty.
      ENDIF.
    ENDIF.

    IF gs_so_heder_ui-so_hdr_auart <> 'ZDR' AND gs_so_heder_ui-so_hdr_auart <> 'ZCRR'.
      READ TABLE lt_sched_out ASSIGNING <fs_sched_out> WITH KEY itm_number = lv_posnr.
      IF sy-subrc = 0.
        <fs_item>-conf_qty = <fs_sched_out>-req_qty.
        IF <fs_item>-req_date IS INITIAL OR <fs_item>-req_date = '00000000'.
          <fs_item>-req_date = <fs_sched_out>-req_date.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT lt_cond_out ASSIGNING <fs_cond_out> WHERE itm_number = lv_posnr.
      <fs_item>-cond_type = <fs_cond_out>-cond_type.
      IF <fs_cond_out>-condclass = 'B'.
        <fs_item>-per = <fs_cond_out>-cond_p_unt.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  " === 6. CẬP NHẬT CACHE (TÍNH LẠI GIÁ TRỊ KHI ĐỔI SỐ LƯỢNG) ===
  FIELD-SYMBOLS: <fs_cache> TYPE ty_cond_cache,
                 <fs_cond>  TYPE ty_cond_alv.
  DATA: lv_new_qty   TYPE zquantity,
        lv_order_val TYPE kwert,
        lv_z100_val  TYPE kwert,
        lv_zdrp_pct  TYPE kbetr,
        lv_tax_pct   TYPE kbetr.

  LOOP AT gt_item_details ASSIGNING <fs_item>.
    lv_new_qty = <fs_item>-quantity.
    IF lv_new_qty <= 0. lv_new_qty = 1. ENDIF.

    READ TABLE gt_cond_cache ASSIGNING <fs_cache> WITH TABLE KEY item_no = <fs_item>-item_no.
    IF sy-subrc = 0.

      " --- A. CASE ZDR & ZCRR (Debit/Credit Memo) ---
      IF gs_so_heder_ui-so_hdr_auart = 'ZDR'.

        " 1. Tính lại ZPRQ
        LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond> WHERE kschl = 'ZPRQ'.
          <fs_cond>-kwert = <fs_cond>-amount * lv_new_qty.
          lv_order_val    = <fs_cond>-kwert.
        ENDLOOP.

        " 2. Lấy % ZDRP
        lv_zdrp_pct = 0.
        READ TABLE <fs_cache>-conditions INTO DATA(ls_zdrp) WITH KEY kschl = 'ZDRP'.
        IF sy-subrc = 0. lv_zdrp_pct = ls_zdrp-amount. ENDIF.

        " 3. Tính toán các dòng ăn theo
        LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond>.
          CASE <fs_cond>-kschl.
            WHEN 'ZDRP'. <fs_cond>-kwert = ( lv_order_val * <fs_cond>-amount ) / 100.
            WHEN 'Z100'.
              <fs_cond>-kwert = ( lv_order_val * <fs_cond>-amount ) / 100.
              lv_z100_val     = <fs_cond>-kwert.
            WHEN 'NETW'.
              <fs_cond>-kwert = lv_order_val + ( ( lv_order_val * lv_zdrp_pct ) / 100 ) + lv_z100_val.
              <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
          ENDCASE.
          IF <fs_cond>-vtext = 'Order Value'. <fs_cond>-kwert = lv_order_val. ENDIF.
        ENDLOOP.

        " --- B. CASE CÁC LOẠI CÒN LẠI (ZORR, ZTP, ZRET, ZSC) ---
        " --- [MỚI] B. CASE ZCRR (Credit) ---
        " --- B. CASE ZCRR (Credit Memo) ---
      ELSEIF gs_so_heder_ui-so_hdr_auart = 'ZCRR'.

        " 1. Tính lại Base (DẤU ÂM)
        lv_base_new = 0.
        LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond> WHERE kschl = 'ZPRQ'.
          <fs_cond>-kwert = ( <fs_cond>-amount * lv_new_qty ) * -1. " Nhân -1 ở đây
          lv_base_new     = <fs_cond>-kwert.
        ENDLOOP.

        " 2. Lấy % ZCRP
        DATA: lv_zcrp_p TYPE kbetr. lv_zcrp_p = 0.
        READ TABLE <fs_cache>-conditions INTO DATA(ls_zc) WITH KEY kschl = 'ZCRP'.
        IF sy-subrc = 0. lv_zcrp_p = ls_zc-amount. ENDIF.

        " 3. Tính toán lại (Logic âm)
        DATA: val_zcrp TYPE kwert, val_net1 TYPE kwert,
              val_z100 TYPE kwert, val_net2 TYPE kwert.

        val_zcrp = ( lv_base_new * lv_zcrp_p ) / 100.
        val_net1 = lv_base_new + val_zcrp.
        val_z100 = ( lv_base_new * -100 ) / 100.
        val_net2 = val_net1 + val_z100.

        " 4. Update Cache
        LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond>.
          CASE <fs_cond>-kschl.
            WHEN 'NETW'. <fs_cond>-kwert = lv_base_new.
            WHEN 'ZCRP'. <fs_cond>-kwert = val_zcrp.
            WHEN 'NET1'. <fs_cond>-kwert = val_net1.
            WHEN 'Z100'. <fs_cond>-kwert = val_z100.
            WHEN 'NET2'. <fs_cond>-kwert = val_net2.
          ENDCASE.

          " Tính Unit Price (Dương)
          IF lv_new_qty <> 0.
            IF <fs_cond>-kschl = 'NETW' OR <fs_cond>-kschl = 'NET1' OR
               <fs_cond>-kschl = 'NET2' OR <fs_cond>-kschl = 'GROS'.
              <fs_cond>-amount = abs( <fs_cond>-kwert / lv_new_qty ).
            ENDIF.
          ELSE.
            IF <fs_cond>-kschl = 'NETW' OR <fs_cond>-kschl = 'NET1' OR
               <fs_cond>-kschl = 'NET2' OR <fs_cond>-kschl = 'GROS'.
              <fs_cond>-amount = 0.
            ENDIF.
          ENDIF.
        ENDLOOP.

        " --- C. CÁC LOẠI KHÁC (ZORR...) ---
      ELSE.

        " >>> RIÊNG ZSC: Logic phức tạp (Base -> Net1 -> Net2) <<<
        IF gs_so_heder_ui-so_hdr_auart = 'ZSC'.

          " 1. Tính Base (ZPRQ)
          lv_base_new = 0.
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond> WHERE kschl = 'ZPRQ'.
            <fs_cond>-kwert = <fs_cond>-amount * lv_new_qty.
            lv_base_new     = <fs_cond>-kwert.
          ENDLOOP.

          " 2. Lấy % ZCF1 và ZTAX
          DATA: lv_zcf1_p TYPE kbetr, lv_tax_p TYPE kbetr.
          lv_zcf1_p = 20. lv_tax_p = 8. " Default
          READ TABLE <fs_cache>-conditions INTO DATA(ls_c1) WITH KEY kschl = 'ZCF1'.
          IF sy-subrc = 0. lv_zcf1_p = ls_c1-amount. ENDIF.
          READ TABLE <fs_cache>-conditions INTO DATA(ls_t1) WITH KEY kschl = 'ZTAX'.
          IF sy-subrc = 0. lv_tax_p = ls_t1-amount. ENDIF.

          " 3. Tính toán trung gian
          DATA: v_zcf1 TYPE kwert, v_net1 TYPE kwert, v_z100 TYPE kwert, v_net2 TYPE kwert, v_tax TYPE kwert.
          v_zcf1 = ( lv_base_new * lv_zcf1_p ) / 100.
          v_net1 = lv_base_new + v_zcf1.
          v_z100 = ( lv_base_new * -100 ) / 100.
          v_net2 = v_net1 + v_z100.
          v_tax  = ( v_net2 * lv_tax_p ) / 100.

          " 4. Update Cache
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond>.
            CASE <fs_cond>-kschl.
              WHEN 'NETW'. <fs_cond>-kwert = lv_base_new.
              WHEN 'ZCF1'. <fs_cond>-kwert = v_zcf1.
              WHEN 'NET1'. <fs_cond>-kwert = v_net1.
              WHEN 'Z100'. <fs_cond>-kwert = v_z100.
              WHEN 'NET2'. <fs_cond>-kwert = v_net2.
              WHEN 'ZTAX'. <fs_cond>-kwert = v_tax.
              WHEN 'GROS'. <fs_cond>-kwert = v_net2 + v_tax.
            ENDCASE.

            " Tính lại Amount cho các dòng tổng
            IF lv_new_qty <> 0.
              IF <fs_cond>-kschl = 'NETW' OR <fs_cond>-kschl = 'NET1' OR
                 <fs_cond>-kschl = 'NET2' OR <fs_cond>-kschl = 'GROS'.
                <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
              ENDIF.
            ENDIF.
          ENDLOOP.

        ENDIF.

        " >>> [MỚI] LOGIC RIÊNG CHO ZFOC
        IF gs_so_heder_ui-so_hdr_auart = 'ZFOC'.

          " 1. Tính lại Base (NETW)
          DATA(lv_net_new) = 0.
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond> WHERE kschl = 'NETW'.
            <fs_cond>-kwert = <fs_cond>-amount * lv_new_qty.
            lv_net_new      = <fs_cond>-kwert.
          ENDLOOP.

          " 2. Tính Z100 và Net1
          DATA: v_z100_foc TYPE kwert, v_net1_foc TYPE kwert.
          v_z100_foc = ( lv_net_new * -100 ) / 100.
          v_net1_foc = lv_net_new + v_z100_foc.

          " 3. Update Cache
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond>.
            CASE <fs_cond>-kschl.
              WHEN 'Z100'. <fs_cond>-kwert = v_z100_foc.
              WHEN 'NET1'.
                <fs_cond>-kwert = v_net1_foc.
                IF lv_new_qty <> 0. <fs_cond>-amount = v_net1_foc / lv_new_qty. ENDIF.
            ENDCASE.
          ENDLOOP.

          " >>> CÁC LOẠI STANDARD: ZORR, ZTP, ZRET (Logic chuẩn: Base -> Net -> Tax -> Gross) <<<
        ELSE.

          " 1. Tính Base
          lv_order_val = 0.
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond> WHERE kschl = 'ZPRQ'.
            <fs_cond>-kwert = <fs_cond>-amount * lv_new_qty.
            lv_order_val    = <fs_cond>-kwert.
          ENDLOOP.

          " 2. Lấy % Thuế
          lv_tax_pct = 0.
          READ TABLE <fs_cache>-conditions INTO DATA(ls_ztax) WITH KEY kschl = 'ZTAX'.
          IF sy-subrc = 0. lv_tax_pct = ls_ztax-amount. ENDIF.

          " 3. Tính toán Net -> Tax -> Gross
          LOOP AT <fs_cache>-conditions ASSIGNING <fs_cond>.
            CASE <fs_cond>-kschl.
              WHEN 'NETW'.
                <fs_cond>-kwert = lv_order_val.
                IF lv_new_qty <> 0.
                  <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
                ELSE.
                  <fs_cond>-amount = 0.
                ENDIF.
              WHEN 'ZTAX'.
                <fs_cond>-kwert = ( lv_order_val * lv_tax_pct ) / 100.
              WHEN 'GROS'.
                <fs_cond>-kwert = lv_order_val + ( ( lv_order_val * lv_tax_pct ) / 100 ).
                IF lv_new_qty <> 0.
                  <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
                ELSE.
                  <fs_cond>-amount = 0.
                ENDIF.
            ENDCASE.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " === 7. Tính tổng Header ===
  DATA: lv_total_net TYPE vbap-netwr,
        lv_total_tax TYPE vbap-mwsbp.
  CLEAR: lv_total_net, lv_total_tax.
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    lv_total_net = lv_total_net + <fs_item>-net_value.
    lv_total_tax = lv_total_tax + <fs_item>-tax.
  ENDLOOP.
  gs_so_heder_ui-so_hdr_total_net = lv_total_net.
  gs_so_heder_ui-so_hdr_total_tax = lv_total_tax.

  " === 8. Thông báo (Luôn hiện) ===
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ret>) WHERE type CA 'AEX'.
    lv_errors_occurred = abap_true.
    MESSAGE <ret>-message TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDLOOP.

  IF lv_errors_occurred = abap_false.
    MESSAGE 'Item details simulated successfully.' TYPE 'S'.
  ENDIF.

ENDFORM.

FORM build_conditions_zorr USING pv_price TYPE kbetr
                                 pv_tax   TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond    TYPE ty_cond_alv,
        ls_style   TYPE lvc_s_styl,
        lv_net_val TYPE kwert.

  " --- MACRO ĐỂ SET STYLE NHANH ---
  " &1: Tên Field
  " &2: Trạng thái (ENABLED / DISABLED)
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " 1. ZPRQ (Unit Price)
  " - Amount, Curr, Per, UoM: NHẬP ĐƯỢC
  " - Các cột còn lại: KHÓA
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Unit Price'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = ls_cond-amount * pv_qty.
  lv_net_val     = ls_cond-kwert.
*  ls_cond-icon   = icon_led_green.
  " [THAY ĐỔI] Check giá để set màu ban đầu
  IF ls_cond-amount IS INITIAL OR ls_cond-amount = 0.
    ls_cond-icon = icon_led_red.   " Mới vào chưa có giá -> Đỏ
  ELSE.
    ls_cond-icon = icon_led_green. " Đã có giá (load từ cache/bapi) -> Xanh
  ENDIF.

  " --- Cấu hình Lock/Unlock cho ZPRQ ---
  " 1. Các cột luôn KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " 2. Các cột ĐƯỢC NHẬP (Theo yêu cầu riêng cho ZPRQ)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " 2. NET VALUE (Read-only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.
  ls_cond-kwert  = lv_net_val.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " 3. ZTAX (Read-only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZTAX'.
  ls_cond-vtext  = 'Output Tax'.
  ls_cond-amount = pv_tax.
  ls_cond-waers  = '%'.
  ls_cond-kwert  = ( lv_net_val * pv_tax ) / 100.
  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " 4. GROSS VALUE (Read-only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'GROS'.
  ls_cond-vtext  = 'Gross Value'.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-amount = pv_price + ( ( pv_price * pv_tax ) / 100 ).
  ls_cond-kwert  = ls_cond-amount * pv_qty.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zdr USING pv_price TYPE kbetr
                                pv_curr  TYPE waers
                                pv_per   TYPE kpein
                                pv_uom   TYPE kmein
                                pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  DATA: lv_order_val TYPE kwert, " Biến tạm Order Value
        lv_zdrp_val  TYPE kwert, " Biến tạm ZDRP
        lv_z100_val  TYPE kwert. " Biến tạm Z100

  " --- MACRO SET STYLE ---
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " DÒNG 1: ZPRQ (Quantity/Price)
  " - Amount, Curr, Per, UoM: NHẬP ĐƯỢC
  " - Các cột còn lại: KHÓA
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = ls_cond-amount * pv_qty. " Value = Price * Qty
*  ls_cond-icon   = icon_led_green.
  " [THAY ĐỔI] Check giá để set màu ban đầu
  IF ls_cond-amount IS INITIAL OR ls_cond-amount = 0.
    ls_cond-icon = icon_led_red.   " Mới vào chưa có giá -> Đỏ
  ELSE.
    ls_cond-icon = icon_led_green. " Đã có giá (load từ cache/bapi) -> Xanh
  ENDIF.

  " [1] Các cột KHÓA (Theo yêu cầu chung)
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Các cột MỞ (Riêng ZPRQ được mở hết các field thông tin giá)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_order_val = ls_cond-kwert. " Lưu Order Value

  " ========================================================================
  " DÒNG 2: ORDER VALUE (Read Only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-vtext  = 'Order Value'.
  ls_cond-amount = pv_price.      " Copy Price
  ls_cond-kwert  = lv_order_val.  " Copy Value từ ZPRQ
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " DÒNG 3: ZDRP (Percentage - Debit)
  " - Amount: NHẬP ĐƯỢC
  " - Curr, Per, UoM: KHÓA (Yêu cầu: chỉ ZPRQ mới mở mấy cái này)
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZDRP'.
  ls_cond-vtext  = 'Percentage - Debit'.
  ls_cond-waers  = '%'. " Format hiển thị
  ls_cond-amount = 0.
  ls_cond-kwert  = 0.
  ls_cond-icon   = icon_led_green.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " [QUAN TRỌNG] Khóa Curr/Per/UoM theo yêu cầu (chỉ ZPRQ mới mở)
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Mở khóa Amount cho ZDRP
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " DÒNG 4: Z100 (-100% price) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-waers  = '%'.
  ls_cond-amount = -100.
  ls_cond-kwert  = ( lv_order_val * ls_cond-amount ) / 100.
  lv_z100_val    = ls_cond-kwert.
  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " DÒNG 5: NET VALUES (Tổng cộng) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Values'.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = lv_order_val + 0 + lv_z100_val.

  IF pv_qty <> 0.
    ls_cond-amount = ls_cond-kwert / pv_qty.
  ELSE.
    ls_cond-amount = 0.
  ENDIF.

*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zcrr USING pv_price TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  DATA: lv_base_val TYPE kwert,
        lv_zcrp_val TYPE kwert,
        lv_net1_val TYPE kwert,
        lv_z100_val TYPE kwert,
        lv_net2_val TYPE kwert.

  " --- MACRO SET STYLE ---
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " 1. ZPRQ (Quantity) - Amount, Curr, Per, UoM: NHẬP ĐƯỢC
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price. " Đơn giá vẫn hiển thị Dương
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " Giá trị KWERT phải là ÂM cho Credit Memo
  ls_cond-kwert  = ( pv_price * pv_qty ) * -1.
*  ls_cond-icon   = icon_led_green.
  " [THAY ĐỔI] Check giá để set màu ban đầu
  IF ls_cond-amount IS INITIAL OR ls_cond-amount = 0.
    ls_cond-icon = icon_led_red.   " Mới vào chưa có giá -> Đỏ
  ELSE.
    ls_cond-icon = icon_led_green. " Đã có giá (load từ cache/bapi) -> Xanh
  ENDIF.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Các cột MỞ (Cho phép nhập giá/tiền tệ cho ZPRQ)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_base_val = ls_cond-kwert. " Lưu giá trị âm

  " ========================================================================
  " 2. NET VALUE (Read Only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.
  ls_cond-kwert  = lv_base_val.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " 3. ZCRP (Percentage - Credit)
  " - Amount: NHẬP ĐƯỢC
  " - Curr, Per, UoM: KHÓA
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZCRP'.
  ls_cond-vtext  = 'Percentage - Credit'.
  ls_cond-amount = 0.
  ls_cond-waers  = '%'.
  ls_cond-kwert  = 0.
  ls_cond-icon   = icon_led_green.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " Khóa các cột tiền tệ/đơn vị (vì là %)
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Mở khóa Amount cho ZCRP
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_zcrp_val = ls_cond-kwert.

  " ========================================================================
  " 4. NET VALUE 1 (Read Only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NET1'.
  ls_cond-vtext  = 'Net Value 1'.
  ls_cond-kwert  = lv_base_val + lv_zcrp_val.

  IF pv_qty <> 0.
    ls_cond-amount = abs( ls_cond-kwert / pv_qty ).
  ENDIF.

  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_net1_val = ls_cond-kwert.

  " ========================================================================
  " 5. Z100 (-100% price) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-amount = -100.
  ls_cond-waers  = '%'.
  ls_cond-kwert  = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_z100_val = ls_cond-kwert.

  " ========================================================================
  " 6. NET VALUE 2 (Read Only) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NET2'.
  ls_cond-vtext  = 'Net Value 2'.
  ls_cond-kwert  = lv_net1_val + lv_z100_val.

  IF pv_qty <> 0.
    ls_cond-amount = abs( ls_cond-kwert / pv_qty ).
  ENDIF.

  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zret USING pv_price TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  " --- MACRO SET STYLE (Dùng lại để code gọn) ---
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " DÒNG 1: ZPRQ (Quantity/Price)
  " - Amount, Curr, Per, UoM: NHẬP ĐƯỢC
  " - Các cột còn lại: KHÓA
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = ls_cond-amount * pv_qty. " Value = Price * Qty
*  ls_cond-icon   = icon_led_green.
  " [THAY ĐỔI] Check giá để set màu ban đầu
  IF ls_cond-amount IS INITIAL OR ls_cond-amount = 0.
    ls_cond-icon = icon_led_red.   " Mới vào chưa có giá -> Đỏ
  ELSE.
    ls_cond-icon = icon_led_green. " Đã có giá (load từ cache/bapi) -> Xanh
  ENDIF.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Các cột MỞ (Cho phép chỉnh sửa thông tin giá của ZPRQ)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " DÒNG 2: NET VALUE (Tổng cộng) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'. " Mã ảo
  ls_cond-vtext  = 'Net Value'.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " Value = Giá trị của ZPRQ
  ls_cond-kwert  = pv_price * pv_qty.

  " Amount = Đơn giá ròng (Net Price)
  ls_cond-amount = pv_price.

*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ dòng NETW
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zsc USING pv_price TYPE kbetr
                                pv_curr  TYPE waers
                                pv_per   TYPE kpein
                                pv_uom   TYPE kmein
                                pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  DATA: lv_base_val TYPE kwert, " ZPRQ Value
        lv_zcf1_val TYPE kwert,
        lv_net1_val TYPE kwert,
        lv_z100_val TYPE kwert,
        lv_net2_val TYPE kwert,
        lv_tax_val  TYPE kwert.

  " --- MACRO SET STYLE ---
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " 1. ZPRQ (Quantity) - Amount, Curr, Per, UoM: NHẬP ĐƯỢC
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = pv_price * pv_qty.
*  ls_cond-icon   = icon_led_green.
  " [THAY ĐỔI] Check giá để set màu ban đầu
  IF ls_cond-amount IS INITIAL OR ls_cond-amount = 0.
    ls_cond-icon = icon_led_red.   " Mới vào chưa có giá -> Đỏ
  ELSE.
    ls_cond-icon = icon_led_green. " Đã có giá (load từ cache/bapi) -> Xanh
  ENDIF.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Các cột MỞ (Cho phép chỉnh sửa thông tin giá của ZPRQ)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_enabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_base_val = ls_cond-kwert. " Lưu Base

  " ========================================================================
  " 2. NET VALUE (Copy ZPRQ) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.
  ls_cond-kwert  = lv_base_val.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

  " ========================================================================
  " 3. ZCF1 (Commission fee)
  " - Amount: NHẬP ĐƯỢC
  " - Curr, Per, UoM: KHÓA
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZCF1'.
  ls_cond-vtext  = 'Commission fee'.
  ls_cond-amount = 20. " Mặc định
  ls_cond-waers  = '%'.
  ls_cond-kwert  = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_led_green.

  " [1] Các cột KHÓA
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.

  " Khóa các cột tiền tệ/đơn vị (vì là %)
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  " [2] Mở khóa Amount cho ZCF1 (Theo yêu cầu)
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_enabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_zcf1_val = ls_cond-kwert.

  " ========================================================================
  " 4. NET VALUE 1 (Base + Commission) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NET1'.
  ls_cond-vtext  = 'Net Value 1'.
  ls_cond-kwert  = lv_base_val + lv_zcf1_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_net1_val = ls_cond-kwert.

  " ========================================================================
  " 5. Z100 (-100% price) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-amount = -100.
  ls_cond-waers  = '%'.
  ls_cond-kwert  = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_z100_val = ls_cond-kwert.

  " ========================================================================
  " 6. NET VALUE 2 (Net 1 + Z100) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NET2'.
  ls_cond-vtext  = 'Net Value 2'.
  ls_cond-kwert  = lv_net1_val + lv_z100_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_net2_val = ls_cond-kwert.

  " ========================================================================
  " 7. ZTAX (Output Tax) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZTAX'.
  ls_cond-vtext  = 'Output Tax'.
  ls_cond-amount = 8.
  ls_cond-waers  = '%'.
  ls_cond-kwert  = ( lv_net2_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_tax_val = ls_cond-kwert.

  " ========================================================================
  " 8. Gross Value (Net 2 + Tax) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'GROS'.
  ls_cond-vtext  = 'Gross Value (After Tax)'.
  ls_cond-kwert  = lv_net2_val + lv_tax_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Lock toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zfoc USING pv_price TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  DATA: lv_base_val TYPE kwert,
        lv_z100_val TYPE kwert,
        lv_net1_val TYPE kwert.

  " --- MACRO SET STYLE ---
  DEFINE _set_style.
    ls_style-fieldname = &1.
    ls_style-style     = &2.
    INSERT ls_style INTO TABLE ls_cond-cell_style.
  END-OF-DEFINITION.

  " ========================================================================
  " DÒNG 1: NET VALUE (Base Price) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = pv_price * pv_qty.
*  ls_cond-icon   = icon_led_green.

  " [QUAN TRỌNG] Khóa toàn bộ các cột (bao gồm cả Amount)
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_base_val = ls_cond-kwert.

  " ========================================================================
  " DÒNG 2: Z100 (-100% price) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-amount = -100.
  ls_cond-waers  = '%'.

  " Value = Base * -100%
  ls_cond-kwert  = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_led_green.

  " Khóa toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.
  lv_z100_val = ls_cond-kwert.

  " ========================================================================
  " DÒNG 3: NET VALUE 1 (Tổng sau chiết khấu = 0) -> KHÓA HẾT
  " ========================================================================
  CLEAR ls_cond.
  ls_cond-kschl  = 'NET1'.
  ls_cond-vtext  = 'Net Value 1'.

  " Value = Base + Z100 Value (Thường sẽ bằng 0)
  ls_cond-kwert  = lv_base_val + lv_z100_val.

  " Amount = Value / Qty
  IF pv_qty <> 0.
    ls_cond-amount = ls_cond-kwert / pv_qty.
  ELSE.
    ls_cond-amount = 0.
  ENDIF.

  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
*  ls_cond-icon   = icon_led_green.

  " Khóa toàn bộ
  _set_style 'ICON'   cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KSCHL'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'VTEXT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KWERT'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'AMOUNT' cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'WAERS'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KPEIN'  cl_gui_alv_grid=>mc_style_disabled.
  _set_style 'KMEIN'  cl_gui_alv_grid=>mc_style_disabled.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form perform_create_single_so
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM perform_create_single_so.

  " ========================================================================
  " [PHẦN 1] CHUẨN BỊ DỮ LIỆU TỪ ALV
  " ========================================================================
  IF go_grid_conditions IS BOUND.
    go_grid_conditions->check_changed_data( ).
  ENDIF.

  " Logic lấy giá manual từ Grid Condition
  DATA: ls_manual_cond TYPE ty_cond_alv.
  LOOP AT gt_conditions_alv INTO ls_manual_cond WHERE amount IS NOT INITIAL.
    FIELD-SYMBOLS: <fs_curr_item_ui> LIKE LINE OF gt_item_details.
    IF gv_current_item_idx > 0.
      READ TABLE gt_item_details ASSIGNING <fs_curr_item_ui> INDEX gv_current_item_idx.
      IF sy-subrc = 0.
        <fs_curr_item_ui>-cond_type  = ls_manual_cond-kschl.
        <fs_curr_item_ui>-unit_price = ls_manual_cond-amount.
        <fs_curr_item_ui>-currency   = ls_manual_cond-waers.
        EXIT.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " ========================================================================
  " [PHẦN 2] KHAI BÁO BIẾN
  " ========================================================================

  " --- Biến cho BƯỚC 1 (SD_SALESDOCUMENT_CREATE) ---
  DATA: ls_header_crt     TYPE bapisdhd1,
        ls_header_crtx    TYPE bapisdhd1x,
        lt_items_crt      TYPE TABLE OF bapisditm,
        lt_items_crtx     TYPE TABLE OF bapisditmx,
        lt_partners_crt   TYPE TABLE OF bapiparnr,
        lt_schedules_crt  TYPE TABLE OF bapischdl,
        lt_schedules_crtx TYPE TABLE OF bapischdlx,
        lt_return_crt     TYPE TABLE OF bapiret2.

  " --- Biến cho BƯỚC 2 (BAPI_SALESORDER_CHANGE) ---
  DATA: lt_cond_change   TYPE TABLE OF bapicond,
        lt_cond_change_x TYPE TABLE OF bapicondx,
        ls_header_chg_x  TYPE bapisdh1x,
        lt_return_chg    TYPE TABLE OF bapiret2.

  DATA: lv_salesdocument_ex TYPE vbak-vbeln.
  DATA: lv_posnr            TYPE posnr.

  " Biến xác định Business Object Động
  DATA: lv_vbtyp   TYPE vbak-vbtyp,
        lv_bus_obj TYPE char10.

  " Cấu trúc buffer giá
  TYPES: BEGIN OF ty_price_buffer,
           itm_number TYPE posnr,
           cond_type  TYPE kscha,
           amount     TYPE p DECIMALS 2,
           currency   TYPE waers,
           unit       TYPE meins,
         END OF ty_price_buffer.
  DATA: lt_price_buffer TYPE TABLE OF ty_price_buffer.

  " Biến phụ trợ xử lý số liệu
  DATA: lv_cond_val_str TYPE char28,
        lv_amount_temp  TYPE p DECIMALS 2,
        lv_qty_str      TYPE string,
        lv_qty_p        TYPE p DECIMALS 3,
        lv_price_str    TYPE string,
        lv_price_p      TYPE p DECIMALS 2,
        lv_waers_check  TYPE tcurc-waers.

  " [THÊM MỚI] Biến để hứng giá trị sau khi convert tiền tệ
  DATA: lv_amount_internal TYPE bapicurr-bapicurr.

  FIELD-SYMBOLS: <fs_item> LIKE LINE OF gt_item_details.
  CLEAR gv_so_just_created.

  " ========================================================================
  " [PHẦN 3] VALIDATE HEADER UI
  " ========================================================================
  IF gs_so_heder_ui-so_hdr_sold_addr IS INITIAL OR gs_so_heder_ui-so_hdr_sold_addr = '0000000000'.
    MESSAGE 'Sold-to Party is required.' TYPE 'S' DISPLAY LIKE 'E'. EXIT.
  ENDIF.
  IF gs_so_heder_ui-so_hdr_bstnk IS INITIAL.
    MESSAGE 'Customer Reference is required.' TYPE 'S' DISPLAY LIKE 'E'. EXIT.
  ENDIF.
  IF gt_item_details IS INITIAL.
    MESSAGE 'Please enter at least one item.' TYPE 'S' DISPLAY LIKE 'E'. EXIT.
  ENDIF.

  " ========================================================================
  " [PHẦN 4] XÁC ĐỊNH BUSINESS OBJECT
  " ========================================================================
  SELECT SINGLE vbtyp INTO lv_vbtyp FROM tvak WHERE auart = gs_so_heder_ui-so_hdr_auart.
  IF sy-subrc <> 0.
    MESSAGE |Order Type { gs_so_heder_ui-so_hdr_auart } invalid configuration.| TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

  CASE lv_vbtyp.
    WHEN 'C'. lv_bus_obj = 'BUS2032'.
    WHEN 'H'. lv_bus_obj = 'BUS2102'.
    WHEN 'I'. lv_bus_obj = 'BUS2032'.
    WHEN 'K'. lv_bus_obj = 'BUS2094'.
    WHEN 'L'. lv_bus_obj = 'BUS2096'.
    WHEN 'G'. lv_bus_obj = 'BUS2034'.
    WHEN OTHERS. lv_bus_obj = 'BUS2032'.
  ENDCASE.

  " ========================================================================
  " [PHẦN 5] MAPPING DATA CHO BƯỚC 1 (CREATE - KHÔNG GIÁ)
  " ========================================================================
  " 1. Header
  CONDENSE gs_so_heder_ui-so_hdr_waerk NO-GAPS.
  TRANSLATE gs_so_heder_ui-so_hdr_waerk TO UPPER CASE.
  IF gs_so_heder_ui-so_hdr_waerk = 'EA'. gs_so_heder_ui-so_hdr_waerk = 'VND'. ENDIF.
  IF gs_so_heder_ui-so_hdr_waerk IS INITIAL. gs_so_heder_ui-so_hdr_waerk = 'VND'. ENDIF.

  SELECT SINGLE waers INTO lv_waers_check FROM tcurc WHERE waers = gs_so_heder_ui-so_hdr_waerk.
  IF sy-subrc <> 0. MESSAGE |Currency { gs_so_heder_ui-so_hdr_waerk } invalid.| TYPE 'S' DISPLAY LIKE 'E'. EXIT. ENDIF.

  ls_header_crt-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_crt-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_crt-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_crt-division   = gs_so_heder_ui-so_hdr_spart.
  ls_header_crt-purch_no_c = gs_so_heder_ui-so_hdr_bstnk.
  ls_header_crt-doc_date   = gs_so_heder_ui-so_hdr_audat.
  ls_header_crt-currency   = gs_so_heder_ui-so_hdr_waerk.
  ls_header_crt-pmnttrms   = gs_so_heder_ui-so_hdr_zterm.

  " 2. Partner
  DATA(lv_sold_to_save) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to_save IMPORTING output = lv_sold_to_save.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to_save ) TO lt_partners_crt.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to_save ) TO lt_partners_crt.


  "Chú ý 2
  " 3. Items & Buffer Pricing (SỬA LẠI ĐOẠN NÀY)
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    IF <fs_item>-matnr IS NOT INITIAL.
      lv_posnr = sy-tabix * 10.

      " --- A. Map Item & Schedule Line (Giữ nguyên) ---
      DATA(lv_matnr_bapi) = <fs_item>-matnr.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.

      CLEAR lv_qty_p.
      lv_qty_str = <fs_item>-quantity.
      REPLACE ALL OCCURRENCES OF ',' IN lv_qty_str WITH '.'.
      TRY. lv_qty_p = lv_qty_str. CATCH cx_root. lv_qty_p = 0. ENDTRY.
      IF lv_qty_p <= 0. MESSAGE |Item { sy-tabix }: Quantity required.| TYPE 'S' DISPLAY LIKE 'E'. EXIT. ENDIF.

      " Map Item Create
      APPEND VALUE #( itm_number = lv_posnr
                      material   = lv_matnr_bapi
                      target_qty = lv_qty_p
                      sales_unit = <fs_item>-unit
                      plant      = <fs_item>-plant
                      store_loc  = <fs_item>-store_loc ) TO lt_items_crt.

      " Map Schedule Line
      IF lv_vbtyp = 'C' OR lv_vbtyp = 'H' OR lv_vbtyp = 'I'.
        APPEND VALUE #( itm_number = lv_posnr
                        req_qty    = lv_qty_p
                        req_date   = <fs_item>-req_date ) TO lt_schedules_crt.
      ENDIF.

      " --- B. [FIX LỖI] LẤY TẤT CẢ CONDITIONS TỪ ALV VÀO BUFFER ---
      " Thay vì lấy từ <fs_item> (chỉ chứa 1 giá), ta quét bảng gt_conditions_alv

      DATA: ls_cond_ui TYPE ty_cond_alv.

      LOOP AT gt_conditions_alv INTO ls_cond_ui.

        " Chỉ xử lý các dòng có Amount khác 0 (hoặc Z100 có thể âm)
*         IF ls_cond_ui-amount IS INITIAL AND ls_cond_ui-kschl <> 'Z100'. CONTINUE. ENDIF.
        IF ls_cond_ui-amount IS INITIAL. CONTINUE. ENDIF.

        " Bỏ qua các dòng Subtotal không phải là Condition Type thực (VD: Net Value, Gross Value)
        " Mẹo: Check cột KSCHL có giá trị và không phải các mã ảo do mình tự đặt (NETW, GROS...)
        IF ls_cond_ui-kschl IS INITIAL
           OR ls_cond_ui-kschl = 'NETW'
           OR ls_cond_ui-kschl = 'NET1'
           OR ls_cond_ui-kschl = 'NET2'
           OR ls_cond_ui-kschl = 'GROS'
           OR ls_cond_ui-kschl = 'Z100'
           OR ls_cond_ui-kschl = 'ZTAX'.
          CONTINUE.
        ENDIF.

        " Xử lý Format Amount
        lv_price_str = ls_cond_ui-amount.
        DATA(lv_dummy) = -1.
        FIND FIRST OCCURRENCE OF '.' IN lv_price_str MATCH OFFSET lv_dummy.
        IF sy-subrc = 0.
          FIND FIRST OCCURRENCE OF ',' IN lv_price_str MATCH OFFSET lv_dummy.
          IF sy-subrc = 0. REPLACE ALL OCCURRENCES OF '.' IN lv_price_str WITH ''. ENDIF.
        ENDIF.
        REPLACE ALL OCCURRENCES OF ',' IN lv_price_str WITH '.'.
        TRY. lv_amount_temp = lv_price_str. CATCH cx_root. lv_amount_temp = 0. ENDTRY.

        " Validate Currency
        DATA(lv_curr_itm) = ls_cond_ui-waers.
        IF lv_curr_itm IS INITIAL. lv_curr_itm = gs_so_heder_ui-so_hdr_waerk. ENDIF.

        " Add vào Buffer (ZPRQ, ZDRP, Z100, ZTAX...)
        APPEND VALUE #( itm_number = lv_posnr
                        cond_type  = ls_cond_ui-kschl
                        amount     = lv_amount_temp
                        currency   = lv_curr_itm
                        unit       = <fs_item>-unit ) TO lt_price_buffer.
      ENDLOOP.

    ENDIF.
  ENDLOOP.

  " ========================================================================
  " [BƯỚC 1] GỌI SD_SALESDOCUMENT_CREATE
  " ========================================================================
  CALL FUNCTION 'SD_SALESDOCUMENT_CREATE'
    EXPORTING
      sales_header_in     = ls_header_crt
      sales_header_inx    = ls_header_crtx
      business_object     = lv_bus_obj
    IMPORTING
      salesdocument_ex    = lv_salesdocument_ex
    TABLES
      return              = lt_return_crt
      sales_items_in      = lt_items_crt
      sales_items_inx     = lt_items_crtx
      sales_partners      = lt_partners_crt
      sales_schedules_in  = lt_schedules_crt
      sales_schedules_inx = lt_schedules_crtx.

  " Check Lỗi Bước 1
  DATA: lv_err_step1 TYPE abap_bool.
  LOOP AT lt_return_crt INTO DATA(ls_ret1) WHERE type = 'E' OR type = 'A'.
    lv_err_step1 = abap_true.
    MESSAGE ID ls_ret1-id TYPE 'S' NUMBER ls_ret1-number
            WITH ls_ret1-message_v1 ls_ret1-message_v2 ls_ret1-message_v3 ls_ret1-message_v4
            DISPLAY LIKE 'E'.
    EXIT.
  ENDLOOP.

  IF lv_err_step1 = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    EXIT.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

  " ========================================================================
  " [BƯỚC 2] GỌI BAPI_SALESORDER_CHANGE (UPDATE GIÁ)
  " ========================================================================
  IF lv_salesdocument_ex IS NOT INITIAL AND lt_price_buffer IS NOT INITIAL.

    REFRESH: lt_cond_change, lt_cond_change_x, lt_return_chg.
    CLEAR ls_header_chg_x.

*    " [THÊM MỚI]: Khai báo biến trung gian đúng kiểu BAPI yêu cầu
*    DATA: lv_bapi_input_amt TYPE bapicurr-bapicurr.

    "Chú ý 5
    LOOP AT lt_price_buffer INTO DATA(ls_buff).

      " Biến tạm
      DATA: lv_bapi_curr TYPE bapicond-currency,
            lv_bapi_unit TYPE bapicond-cond_unit.

      lv_bapi_curr = ls_buff-currency.
      lv_bapi_unit = ls_buff-unit.

      " Safety Check Currency
      IF lv_bapi_curr IS INITIAL.
        lv_bapi_curr = gs_so_heder_ui-so_hdr_waerk.
        IF lv_bapi_curr IS INITIAL. lv_bapi_curr = 'VND'. ENDIF.
      ENDIF.

      " =================================================================
      " [FINAL FIX]: TÁCH RIÊNG LOGIC ZDRP VÀ ZCRP
      " =================================================================

      " CASE 1: ZDRP (Đã test OK: Cần nhân 100)
      IF ls_buff-cond_type = 'ZDRP'.
        lv_bapi_unit   = '%'.
        CLEAR lv_bapi_curr.       " Xóa Currency
        ls_buff-amount = ls_buff-amount * 100. " ZDRP vẫn nhân 100

        " CASE 2: ZCRP (Test mới: KHÔNG được nhân)
      ELSEIF ls_buff-cond_type = 'ZCRP'.
        lv_bapi_unit   = '%'.
        CLEAR lv_bapi_curr.       " Xóa Currency
        " ls_buff-amount = ls_buff-amount. " <<< GIỮ NGUYÊN (30 là 30)

        " CASE 3: Các loại % khác (ZCF1...) hoặc Unit là %
      ELSEIF ls_buff-cond_type = 'ZCF1' OR ls_buff-unit = '%'.
        lv_bapi_unit   = '%'.
        CLEAR lv_bapi_curr.
        " Thử nghiệm mặc định: Không nhân (An toàn nhất)
        " Nếu sau này ZCF1 cần nhân thì sửa sau

        " CASE 4: TIỀN TỆ (VND...)
      ELSE.
        " Check TCURC
        SELECT SINGLE waers INTO lv_waers_check FROM tcurc WHERE waers = lv_bapi_curr.
        IF sy-subrc <> 0. lv_bapi_curr = 'VND'. ENDIF.

        " Nhân 100 nếu là VND
        DATA: lv_currdec TYPE tcurx-currdec.
        CLEAR lv_currdec.
        SELECT SINGLE currdec INTO lv_currdec FROM tcurx WHERE currkey = lv_bapi_curr.

        IF sy-subrc = 0 AND lv_currdec = 0.
          ls_buff-amount = ls_buff-amount * 100.
        ENDIF.
      ENDIF.

      " 2. Convert sang String
      lv_cond_val_str = ls_buff-amount.
      CONDENSE lv_cond_val_str NO-GAPS.

      " 3. APPEND VÀO BAPI
      APPEND VALUE #( itm_number = ls_buff-itm_number
                      cond_type  = ls_buff-cond_type
                      cond_value = lv_cond_val_str
                      currency   = lv_bapi_curr
                      cond_unit  = lv_bapi_unit
                      cond_p_unt = 1 ) TO lt_cond_change.

      APPEND VALUE #( itm_number = ls_buff-itm_number
                      cond_type  = ls_buff-cond_type
                      updateflag = 'I'
                      cond_value = 'X'
                      currency   = 'X'
                      cond_unit  = 'X'
                      cond_p_unt = 'X' ) TO lt_cond_change_x.
    ENDLOOP.

    ls_header_chg_x-updateflag = 'U'.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = lv_salesdocument_ex
        order_header_inx = ls_header_chg_x
      TABLES
        return           = lt_return_chg
        conditions_in    = lt_cond_change
        conditions_inx   = lt_cond_change_x.

    " Check Lỗi Bước 2
    DATA: lv_err_step2 TYPE abap_bool.
    LOOP AT lt_return_chg INTO DATA(ls_ret2) WHERE type CA 'AE'.
      lv_err_step2 = abap_true.
      MESSAGE |Price Update Failed for SO { lv_salesdocument_ex }: { ls_ret2-message }| TYPE 'S' DISPLAY LIKE 'W'.
      EXIT.
    ENDLOOP.

    IF lv_err_step2 = abap_false.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    ENDIF.
  ENDIF.

  " ========================================================================
  " [PHẦN 6] KẾT THÚC & HẬU XỬ LÝ
  " ========================================================================
  gs_so_heder_ui-so_hdr_vbeln = lv_salesdocument_ex.
  gs_so_heder_ui-so_hdr_message = |Sales Order { lv_salesdocument_ex } created successfully.|.
  MESSAGE gs_so_heder_ui-so_hdr_message TYPE 'S'.

  " 1. Lưu ZTable
  IF gt_item_details IS NOT INITIAL.
    DATA lt_items_to_save TYPE TABLE OF ztb_so_item_sing.
    FIELD-SYMBOLS <fs_item_alv> LIKE LINE OF gt_item_details.
    LOOP AT gt_item_details ASSIGNING <fs_item_alv> WHERE matnr IS NOT INITIAL.
      <fs_item_alv>-req_id = gs_so_heder_ui-req_id.
      <fs_item_alv>-sales_order = lv_salesdocument_ex.
      <fs_item_alv>-proc_status = 'P'.
      APPEND CORRESPONDING #( <fs_item_alv> ) TO lt_items_to_save.
    ENDLOOP.
    IF lt_items_to_save IS NOT INITIAL.
      MODIFY ztb_so_item_sing FROM TABLE @lt_items_to_save. COMMIT WORK.
    ENDIF.
  ENDIF.

  " 2. Auto Delivery
  IF lv_vbtyp = 'C' OR lv_vbtyp = 'H' OR lv_vbtyp = 'I'.
    DATA: ls_temp_header_for_deliv TYPE ty_mu_header_ext.
    ls_temp_header_for_deliv-vbeln_so       = lv_salesdocument_ex.
    ls_temp_header_for_deliv-sales_org      = gs_so_heder_ui-so_hdr_vkorg.
    ls_temp_header_for_deliv-sales_channel  = gs_so_heder_ui-so_hdr_vtweg.
    ls_temp_header_for_deliv-sales_div      = gs_so_heder_ui-so_hdr_spart.
    ls_temp_header_for_deliv-sold_to_party  = gs_so_heder_ui-so_hdr_sold_addr.
    ls_temp_header_for_deliv-cust_ref       = gs_so_heder_ui-so_hdr_bstnk.

    PERFORM perform_auto_delivery USING lv_salesdocument_ex CHANGING ls_temp_header_for_deliv.

    IF ls_temp_header_for_deliv-message IS NOT INITIAL.
      MESSAGE ls_temp_header_for_deliv-message TYPE 'S'.
    ENDIF.
  ENDIF.

  " 3. Reset Screen
  gv_so_just_created = abap_true.
  PERFORM reset_single_entry_screen.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_SCREEN_VALUE
*&---------------------------------------------------------------------*
* Description:
* Retrieves the current value of a screen field during POV (Process On Value-request).
* Required because data is not yet available in the ABAP program (PAI not triggered).
* Parameters:
* --> P_FIELDNAME: Name of the screen field to read (e.g., 'VBAK-VKORG')
* <-- P_VALUE    : Returned value
*----------------------------------------------------------------------*
FORM get_screen_value USING p_fieldname TYPE csequence
                   CHANGING p_value     TYPE any.

  DATA: lt_dynp TYPE TABLE OF dynpread,
        ls_dynp TYPE dynpread.

  " 1. Prepare field for reading
  ls_dynp-fieldname = p_fieldname.
  APPEND ls_dynp TO lt_dynp.

  " 2. Read value from Dynpro stack
  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname             = sy-repid
      dynumb             = sy-dynnr
    TABLES
      dynpfields         = lt_dynp
    EXCEPTIONS
      others             = 1.

  " 3. Return result
  IF sy-subrc = 0.
    READ TABLE lt_dynp INTO ls_dynp INDEX 1.
    p_value = ls_dynp-fieldvalue.
  ELSE.
    CLEAR p_value.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CALL_F4_GENERAL
*&---------------------------------------------------------------------*
* Description:
* Generic utility to execute any Search Help with dynamic filters.
* Handles the full cycle: Get Description -> Filter -> Display -> Update Screen.
* Parameters:
* --> P_SHLP     : Technical name of Search Help (SE11)
* --> P_RETFIELD : Screen field to update
* --> P_SHLP_COL : Column in Search Help to map back (e.g., 'VTWEG')
* --> PT_SELECTION: Filter criteria (Range table)
*----------------------------------------------------------------------*
FORM call_f4_general USING p_shlp       TYPE shlpname
                           p_retfield   TYPE dynfnam
                           p_shlp_col   TYPE shlpfield
                           pt_selection TYPE ddshselops.

  " Local Data Definitions
  DATA: lt_return   TYPE TABLE OF ddshretval,
        ls_return   TYPE ddshretval.
  DATA: ls_shlp     TYPE shlp_descr.
  DATA: lt_dynp_upd TYPE TABLE OF dynpread,
        ls_dynp_upd TYPE dynpread.

  FIELD-SYMBOLS: <ls_interface> TYPE ddshiface.

  " ---------------------------------------------------------------------
  " Step 1: Retrieve Search Help Description
  " ---------------------------------------------------------------------
  CALL FUNCTION 'F4IF_GET_SHLP_DESCR'
    EXPORTING
      shlpname = p_shlp
    IMPORTING
      shlp     = ls_shlp.

  " ---------------------------------------------------------------------
  " Step 2: Apply Dynamic Filters (Pre-selection)
  " ---------------------------------------------------------------------
  IF pt_selection IS NOT INITIAL.
    APPEND LINES OF pt_selection TO ls_shlp-selopt.
  ENDIF.

  " ---------------------------------------------------------------------
  " Step 3: Configure Interface (Mark Return Column)
  " ---------------------------------------------------------------------
  " Crucial: Flag the specific column ('VALFIELD') that needs to be returned.
  LOOP AT ls_shlp-interface ASSIGNING <ls_interface>
       WHERE shlpfield = p_shlp_col.
    <ls_interface>-valfield = 'X'.
  ENDLOOP.

  " ---------------------------------------------------------------------
  " Step 4: Launch F4 Dialog
  " ---------------------------------------------------------------------
  CALL FUNCTION 'F4IF_START_VALUE_REQUEST'
    EXPORTING
      shlp          = ls_shlp
      disponly      = ' '
    TABLES
      return_values = lt_return
    EXCEPTIONS
      others        = 1.

  " ---------------------------------------------------------------------
  " Step 5: Update Screen Field (Dynpro Update)
  " ---------------------------------------------------------------------
  IF sy-subrc = 0 AND lt_return IS NOT INITIAL.

    " A. Find the correct return value
    READ TABLE lt_return INTO ls_return WITH KEY fieldname = p_shlp_col.

    " Fallback: Use the first selected value if exact mapping fails
    IF sy-subrc <> 0.
      READ TABLE lt_return INTO ls_return INDEX 1.
    ENDIF.

    " B. Prepare Dynpro update structure
    ls_dynp_upd-fieldname  = p_retfield.
    ls_dynp_upd-fieldvalue = ls_return-fieldval.
    APPEND ls_dynp_upd TO lt_dynp_upd.

    " C. Push value to screen immediately
    CALL FUNCTION 'DYNP_VALUES_UPDATE'
      EXPORTING
        dyname               = sy-repid
        dynumb               = sy-dynnr
      TABLES
        dynpfields           = lt_dynp_upd
      EXCEPTIONS
        others               = 8.

    IF sy-subrc <> 0.
      MESSAGE 'Technical Error: Update Screen Field Failed!' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F4_HELP_VTWEG
*&---------------------------------------------------------------------*
* Description: F4 for Distribution Channel, filtered by Sales Org
* Search Help: H_TVKOV
*----------------------------------------------------------------------*
FORM f4_help_vtweg.

  DATA: lt_sel   TYPE ddshselops,
        ls_sel   TYPE ddshselopt,
        lv_vkorg TYPE vkorg.

  " 1. Get dependent value (Sales Org)
  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VKORG' CHANGING lv_vkorg.

  " 2. Build Filter
  IF lv_vkorg IS NOT INITIAL.
    ls_sel-shlpfield = 'VKORG'.
    ls_sel-sign      = 'I'.
    ls_sel-option    = 'EQ'.
    ls_sel-low       = lv_vkorg.
    APPEND ls_sel TO lt_sel.
  ENDIF.

  " 3. Call Generic F4
  PERFORM call_f4_general USING 'H_TVKOV'                       " Search Help Name
                                'GS_SO_HEDER_UI-SO_HDR_VTWEG'   " Target Screen Field
                                'VTWEG'                         " Return Column
                                lt_sel.                         " Filter Criteria
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F4_HELP_SPART
*&---------------------------------------------------------------------*
* Description: F4 for Division, filtered by Sales Org AND Dist. Channel
* Search Help: H_TVTA
*----------------------------------------------------------------------*
FORM f4_help_spart.

  DATA: lt_sel   TYPE ddshselops,
        ls_sel   TYPE ddshselopt.
  DATA: lv_vkorg TYPE vkorg,
        lv_vtweg TYPE vtweg.

  " 1. Get dependent values
  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VKORG' CHANGING lv_vkorg.
  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VTWEG' CHANGING lv_vtweg.

  " 2. Build Filters
  IF lv_vkorg IS NOT INITIAL.
    ls_sel-shlpfield = 'VKORG'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_vkorg.
    APPEND ls_sel TO lt_sel.
  ENDIF.

  IF lv_vtweg IS NOT INITIAL.
    ls_sel-shlpfield = 'VTWEG'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_vtweg.
    APPEND ls_sel TO lt_sel.
  ENDIF.

  " 3. Call Generic F4
  PERFORM call_f4_general USING 'H_TVTA'                        " Search Help Name
                                'GS_SO_HEDER_UI-SO_HDR_SPART'   " Target Screen Field
                                'SPART'                         " Return Column
                                lt_sel.                         " Filter Criteria
ENDFORM.

*-- Sales Office (Cột cần lấy: VKBUR)
FORM f4_help_vkbur.
  DATA: lt_sel TYPE ddshselops, ls_sel TYPE ddshselopt, lv_val TYPE char50.

  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VKORG' CHANGING lv_val.
  IF lv_val IS NOT INITIAL.
    ls_sel-shlpfield = 'VKORG'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_val. APPEND ls_sel TO lt_sel.
  ENDIF.
  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VTWEG' CHANGING lv_val.
  IF lv_val IS NOT INITIAL.
    ls_sel-shlpfield = 'VTWEG'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_val. APPEND ls_sel TO lt_sel.
  ENDIF.
  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_SPART' CHANGING lv_val.
  IF lv_val IS NOT INITIAL.
    ls_sel-shlpfield = 'SPART'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_val. APPEND ls_sel TO lt_sel.
  ENDIF.

  PERFORM call_f4_general USING 'H_TVKBZ' 'GS_SO_HEDER_UI-SO_HDR_VKBUR' 'VKBUR' lt_sel.
ENDFORM.

*-- Sales Group (Cột cần lấy: VKGRP)
FORM f4_help_vkgrp.
  DATA: lt_sel   TYPE ddshselops, ls_sel TYPE ddshselopt, lv_vkbur TYPE vkbur.

  PERFORM get_screen_value USING 'GS_SO_HEDER_UI-SO_HDR_VKBUR' CHANGING lv_vkbur.
  IF lv_vkbur IS NOT INITIAL.
    ls_sel-shlpfield = 'VKBUR'. ls_sel-sign = 'I'. ls_sel-option = 'EQ'. ls_sel-low = lv_vkbur.
    APPEND ls_sel TO lt_sel.
  ENDIF.

  PERFORM call_f4_general USING 'H_TVBVK' 'GS_SO_HEDER_UI-SO_HDR_VKGRP' 'VKGRP' lt_sel.
ENDFORM.

FORM update_zprq_icon.
  FIELD-SYMBOLS: <fs_cond> TYPE ty_cond_alv.

  LOOP AT gt_conditions_alv ASSIGNING <fs_cond> WHERE kschl = 'ZPRQ'.
    " Logic: Nếu Amount = 0 -> Đỏ, ngược lại -> Xanh
    IF <fs_cond>-amount IS INITIAL OR <fs_cond>-amount = 0.
      <fs_cond>-icon = icon_led_red.   " Chưa nhập giá
    ELSE.
      <fs_cond>-icon = icon_led_green. " Đã có giá
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_INITIAL_DATA_SD4
*&---------------------------------------------------------------------*
* Retrieve initial dataset for Dashboard Screen 0400
* ---------------------------------------------------------------
* Logic:
* 1. Clears global internal tables.
* 2. Fetches Sales Orders (VBAK), Items (VBAP), and Customer Names (KNA1).
* 3. Filters by default Sales Organizations (CNSG, CNHN, CNDN).
* 4. Calculates KPIs and Statuses for display.
*----------------------------------------------------------------------*
FORM get_initial_data_sd4 .

  " 1. Initialize Global Data Containers
  REFRESH: gt_static_sd4, gt_alv_sd4.

  " 2. Fetch Raw Data from Database
  " Join Header (VBAK), Item (VBAP) and Customer Master (KNA1)
  SELECT a~vbeln, a~auart, a~audat, a~vdatu, a~vkorg, a~vtweg, a~spart,
         a~kunnr, a~bstnk, a~waerk, a~gbstk,
         c~name1,
         b~posnr, b~matnr, b~kwmeng, b~vrkme, b~netwr AS netwr_i
    FROM vbak AS a
    INNER JOIN vbap AS b ON a~vbeln = b~vbeln
    LEFT  JOIN kna1 AS c ON a~kunnr = c~kunnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_static_sd4
    WHERE a~vkorg IN ( 'CNSG', 'CNHN', 'CNDN' ). " Default branches filter

  " 3. Prepare Display Data
  " Copy to ALV table (gt_static is kept for backup/filtering purposes)
  gt_alv_sd4 = gt_static_sd4.

  " 4. Business Logic Processing
  " Determine Status Icons & Text (Document Flow check)
  PERFORM determine_custom_status_sd4.

  " Calculate Header KPIs (Total Sales, Order Count)
  PERFORM calculate_kpi_sd4.

  " 5. Default Layout Sorting
  " Sort by Document Date (Newest first)
  SORT gt_alv_sd4 BY audat DESCENDING vbeln DESCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DETERMINE_CUSTOM_STATUS_SD4
*&---------------------------------------------------------------------*
* Determine the overall business status of each Sales Order based on
* its document flow (Order -> Delivery -> Billing -> FI).
* ---------------------------------------------------------------
* Logic Overview:
* 1. Collect all SO Numbers to fetch data in bulk (Performance optimization).
* 2. Retrieve Document Flow (VBFA) to identify Subsequent Docs (Del/Bill).
* 3. Retrieve Header Statuses from LIKP (Delivery) and VBRK (Billing).
* 4. Iterate through ALV data to assign Status Text and Icon based on:
* - Order Type (Goods vs Service)
* - Existence of FI Document (Highest priority)
* - Existence of Billing Document
* - Goods Movement Status (PGI/PGR)
*----------------------------------------------------------------------*
FORM determine_custom_status_sd4 .
  DATA: lt_vbeln TYPE RANGE OF vbak-vbeln,
        ls_rng   LIKE LINE OF lt_vbeln.

  " 1. COLLECT SALES ORDER NUMBERS (Bulk Selection Preparation)
  LOOP AT gt_alv_sd4 INTO DATA(ls_alv).
    ls_rng-sign = 'I'. ls_rng-option = 'EQ'. ls_rng-low = ls_alv-vbeln.
    COLLECT ls_rng INTO lt_vbeln.
  ENDLOOP.
  IF lt_vbeln IS INITIAL. RETURN. ENDIF.

  " 2. RETRIEVE DOCUMENT FLOW (VBFA)
  TYPES: BEGIN OF ty_flow,
           vbelv   TYPE vbfa-vbelv,   " Preceding Doc (SO/Del)
           vbeln   TYPE vbfa-vbeln,   " Subsequent Doc (Del/Bill)
           vbtyp_n TYPE vbfa-vbtyp_n, " Doc Category (J=Del, M=Bill)
         END OF ty_flow.
  DATA: lt_flow TYPE TABLE OF ty_flow.

  " A. Fetch immediate successors: Delivery (J) and Invoice (M) directly from Order
  SELECT vbelv, vbeln, vbtyp_n
    FROM vbfa
    INTO TABLE @lt_flow
    WHERE vbelv   IN @lt_vbeln
      AND vbtyp_n IN ( 'J', 'M' ).

  " B. Fetch 2nd level successors: Invoice (M) from the Delivery (J) found above
  " Logic: Find Invoices (T2) where Preceding Doc is a Delivery (T1)
  " and that Delivery's Preceding Doc is our Sales Order.
  SELECT t2~vbelv, t2~vbeln, t2~vbtyp_n
    FROM vbfa AS t1                " Node 1: Delivery
    INNER JOIN vbfa AS t2          " Node 2: Invoice
      ON t1~vbeln = t2~vbelv
    APPENDING TABLE @lt_flow
    WHERE t1~vbelv   IN @lt_vbeln  " Root: Sales Order ID
      AND t1~vbtyp_n = 'J'         " Intermediate: Delivery
      AND t2~vbtyp_n = 'M'.        " Target: Invoice

  SORT lt_flow BY vbelv vbtyp_n.

  " 3. RETRIEVE HEADER STATUS DETAILS (Bulk Fetch)
  " A. Billing Status (VBRK)
  TYPES: BEGIN OF ty_bill_st,
           vbeln TYPE vbrk-vbeln,
           sfakn TYPE vbrk-sfakn, " Cancelled Flag
           rfbsk TYPE vbrk-rfbsk, " Posting Status (C = Posted to FI)
         END OF ty_bill_st.
  DATA: lt_bill_st TYPE HASHED TABLE OF ty_bill_st WITH UNIQUE KEY vbeln.

  " B. Delivery Status (LIKP)
  TYPES: BEGIN OF ty_del_st,
           vbeln TYPE likp-vbeln,
           wbstk TYPE likp-wbstk, " Goods Movement Status
         END OF ty_del_st.
  DATA: lt_del_st TYPE HASHED TABLE OF ty_del_st WITH UNIQUE KEY vbeln.

  " Collect IDs for detailed selection
  DATA: lr_bill TYPE RANGE OF vbrk-vbeln,
        lr_del  TYPE RANGE OF likp-vbeln.
  CLEAR ls_rng. ls_rng-sign = 'I'. ls_rng-option = 'EQ'.

  LOOP AT lt_flow INTO DATA(ls_f).
    IF ls_f-vbtyp_n = 'M'.     " Billing
      ls_rng-low = ls_f-vbeln. COLLECT ls_rng INTO lr_bill.
    ELSEIF ls_f-vbtyp_n = 'J'. " Delivery
      ls_rng-low = ls_f-vbeln. COLLECT ls_rng INTO lr_del.
    ENDIF.
  ENDLOOP.

  " Fetch Status Details
  IF lr_bill IS NOT INITIAL.
    SELECT vbeln, sfakn, rfbsk FROM vbrk INTO TABLE @lt_bill_st WHERE vbeln IN @lr_bill.
  ENDIF.
  IF lr_del IS NOT INITIAL.
    SELECT vbeln, wbstk FROM likp INTO TABLE @lt_del_st WHERE vbeln IN @lr_del.
  ENDIF.

  " 4. EXECUTE MAIN LOGIC (Iterate ALV Data)
  LOOP AT gt_alv_sd4 ASSIGNING FIELD-SYMBOL(<fs_data>).
    DATA: lv_has_fi   TYPE char1,
          lv_has_bill TYPE char1,
          lv_has_del  TYPE char1,
          lv_wbstk    TYPE likp-wbstk.

    CLEAR: lv_has_fi, lv_has_bill, lv_has_del, lv_wbstk.

    " --- CHECK BILLING & FI EXISTENCE ---

    " Case 1: Billing created directly from Order (SO -> Bill)
    LOOP AT lt_flow INTO ls_f WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'M'.
      READ TABLE lt_bill_st INTO DATA(ls_bst) WITH TABLE KEY vbeln = ls_f-vbeln.
      IF sy-subrc = 0 AND ls_bst-sfakn IS INITIAL. " Exists & Not Cancelled
        lv_has_bill = 'X'.
        IF ls_bst-rfbsk = 'C'. lv_has_fi = 'X'. EXIT. ENDIF. " FI Posted -> Priority 1
      ENDIF.
    ENDLOOP.

    " Case 2: Billing created via Delivery (SO -> Del -> Bill)
    " Only search if FI Doc not yet found in Case 1
    IF lv_has_fi IS INITIAL.
      " Iterate through Deliveries of this Order
      LOOP AT lt_flow INTO DATA(ls_del_ref) WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'J'.
        " For each Delivery, find its Billing
        LOOP AT lt_flow INTO ls_f WHERE vbelv = ls_del_ref-vbeln AND vbtyp_n = 'M'.
          READ TABLE lt_bill_st INTO ls_bst WITH TABLE KEY vbeln = ls_f-vbeln.
          IF sy-subrc = 0 AND ls_bst-sfakn IS INITIAL.
            lv_has_bill = 'X'.
            IF ls_bst-rfbsk = 'C'. lv_has_fi = 'X'. EXIT. ENDIF.
          ENDIF.
        ENDLOOP.
        IF lv_has_fi = 'X'. EXIT. ENDIF. " Found FI, stop searching
      ENDLOOP.
    ENDIF.

    " --- CHECK DELIVERY (To determine Goods Movement status) ---
    IF lv_has_bill IS INITIAL.
      LOOP AT lt_flow INTO ls_f WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'J'.
        lv_has_del = 'X'.
        READ TABLE lt_del_st INTO DATA(ls_dst) WITH TABLE KEY vbeln = ls_f-vbeln.
        IF sy-subrc = 0.
          lv_wbstk = ls_dst-wbstk. " Get Goods Movement Status
        ENDIF.
        EXIT. " Take the first active delivery found
      ENDLOOP.
    ENDIF.

    " --- MAPPING STATUS TEXT & ICON (Presentation Logic) ---
    CASE <fs_data>-auart.
        " === GROUP 1: GOODS / LOGISTICS (ZORR, ZBB, ZFOC, ZRET) ===
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        IF lv_has_fi = 'X'.
          <fs_data>-gbstk_txt   = 'FI Doc created'.
          <fs_data>-status_icon = icon_payment.

        ELSEIF lv_has_bill = 'X'.
          <fs_data>-gbstk_txt   = 'Billing created'.
          <fs_data>-status_icon = icon_display_text.

        ELSEIF lv_has_del = 'X'.
          IF <fs_data>-auart = 'ZRET'. " Returns Order
            IF lv_wbstk = 'C'.
              <fs_data>-gbstk_txt   = 'PGR Posted, ready Billing'.
              <fs_data>-status_icon = icon_display_text.
            ELSE.
              <fs_data>-gbstk_txt   = 'Return Del created, ready PGR'.
              <fs_data>-status_icon = icon_delivery.
            ENDIF.
          ELSE. " Standard Sales Order
            IF lv_wbstk = 'C'.
              <fs_data>-gbstk_txt   = 'PGI Posted, ready Billing'.
              <fs_data>-status_icon = icon_display_text.
            ELSE.
              <fs_data>-gbstk_txt   = 'Delivery created, ready PGI'.
              <fs_data>-status_icon = icon_delivery.
            ENDIF.
          ENDIF.

        ELSE.
          <fs_data>-gbstk_txt   = 'Order created'.
          <fs_data>-status_icon = icon_order.
        ENDIF.

        " === GROUP 2: SERVICE / NON-STOCK (ZDR, ZCRR, ZTP...) ===
      WHEN OTHERS.
        IF lv_has_fi = 'X'.
          <fs_data>-gbstk_txt   = 'FI Doc created'.
          <fs_data>-status_icon = icon_payment.
        ELSEIF lv_has_bill = 'X'.
          <fs_data>-gbstk_txt   = 'Billing created'.
          <fs_data>-status_icon = icon_display_text.
        ELSE.
          <fs_data>-gbstk_txt   = 'Ready Billing'.
          <fs_data>-status_icon = icon_order.
        ENDIF.

    ENDCASE.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CALCULATE_KPI_SD4
*&---------------------------------------------------------------------*
* Compute Dashboard Header Metrics:
* 1. Total Order Count (Distinct Headers)
* 2. Total Revenue (Sum of all Item Net Values)
*----------------------------------------------------------------------*
FORM calculate_kpi_sd4 .

  " 1. Initialize KPI Aggregates
  CLEAR: gv_kpi_total_sd4, gv_kpi_rev_sd4.

  " 2. Prepare for Control Break Processing
  " Sorting by Primary Key (VBELN) is mandatory for 'AT NEW' logic
  SORT gt_alv_sd4 BY vbeln.

  " 3. Execute Aggregation Loop
  LOOP AT gt_alv_sd4 INTO DATA(ls_row).

    " A. Accumulate Revenue (Summing up Net Value of every line item)
    gv_kpi_rev_sd4 = gv_kpi_rev_sd4 + ls_row-netwr_i.

    " B. Count Distinct Sales Orders
    " Triggered once for each new Document Number
    AT NEW vbeln.
      gv_kpi_total_sd4 = gv_kpi_total_sd4 + 1.
    ENDAT.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_DASHBOARD_UI_SD4
*&---------------------------------------------------------------------*
* Initialize and Render the Dashboard UI Layout (Screen 0400)
* ----------------------------------------------------------------------
* Structure:
* 1. Container Initialization (Singleton Pattern - Runs once)
* - Main Custom Container -> 'CC_REPORT'
* - Splitter Container    -> 2 Rows (Header / ALV)
* 2. Component Rendering
* - KPI Header (Top)
* - ALV Grid (Bottom)
*----------------------------------------------------------------------*
FORM update_dashboard_ui_sd4 .

  " --- 1. UI CONTROLS INITIALIZATION (Execute once) ---
  IF go_split_sd4 IS INITIAL.

    " A. Instantiate Main Container (Mapped to Screen Layout)
    CREATE OBJECT go_cc_report
      EXPORTING
        container_name = 'CC_REPORT'.

    " B. Instantiate Splitter Container
    " Configuration: 2 Rows, 1 Column
    CREATE OBJECT go_split_sd4
      EXPORTING
        parent  = go_cc_report
        rows    = 2
        columns = 1.

    " C. Retrieve Sub-Container References
    " Row 1: KPI Header / Row 2: Main Data Grid
    go_c_top_sd4 = go_split_sd4->get_container( row = 1 column = 1 ).
    go_c_bot_sd4 = go_split_sd4->get_container( row = 2 column = 1 ).

    " D. Configure Layout Properties
    " Set Header Height to 15% (Remaining 85% for ALV)
    go_split_sd4->set_row_height( id = 1 height = 15 ).

    " Remove Borders for a cleaner UI look
    go_split_sd4->set_border( border = space ).

  ENDIF.

  " --- 2. RENDER UI COMPONENTS (Refresh Content) ---
  " Draw KPI Statistics Header
  PERFORM draw_kpi_header_sd4.

  " Draw Main ALV Report
  PERFORM draw_alv_grid_sd4.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DRAW_KPI_HEADER_SD4
*&---------------------------------------------------------------------*
* Render the Top KPI Banner using HTML Viewer control.
* Displays aggregated metrics: Total Orders & Total Revenue.
*----------------------------------------------------------------------*
FORM draw_kpi_header_sd4 .

  " --------------------------------------------------------------------
  " 1. DATA DECLARATIONS
  " --------------------------------------------------------------------
  " HTML Content Handling
  DATA: lt_html TYPE TABLE OF char255,   " HTML Data Table
        ls_html TYPE char255,            " Line Buffer
        lv_url  TYPE char255.            " Assigned URL

  " Formatted String Values (for UI Display)
  DATA: lv_str_total TYPE string,
        lv_str_val   TYPE string.

  " Temporary String Buffer
  DATA: lv_html_content TYPE string.

  " --------------------------------------------------------------------
  " 2. PREPARE DATA PRESENTATION
  " --------------------------------------------------------------------
  " Format numeric values according to User's Decimal settings
  lv_str_total = |{ gv_kpi_total_sd4 NUMBER = USER }|.
  lv_str_val   = |{ gv_kpi_rev_sd4   NUMBER = USER }|.

  " --------------------------------------------------------------------
  " 3. INITIALIZE VIEWER CONTROL
  " --------------------------------------------------------------------
  " Instantiate HTML Control if not already created (Singleton)
  IF go_html_kpi_sd4 IS INITIAL.
    CREATE OBJECT go_html_kpi_sd4
      EXPORTING
        parent = go_c_top_sd4. " Bind to Top Container
  ENDIF.

  " --------------------------------------------------------------------
  " 4. BUILD HTML CONTENT
  " --------------------------------------------------------------------
  " Local Macro for appending HTML lines (Brevity helper)
  DEFINE add_h.
    ls_html = &1. APPEND ls_html TO lt_html.
  END-OF-DEFINITION.

  " --- A. Header & CSS Styles ---
  add_h '<html><head><style>'.
  add_h '  body { margin: 0; padding: 10px; font-family: "Segoe UI", Arial, sans-serif;'.
  add_h '         background: #f5f7fa; overflow: hidden; }'.
  add_h '  .kpi-box { display: flex; gap: 20px; justify-content: flex-start; }'.
  add_h '  .card { background: white; padding: 10px 20px; border-radius: 4px;'.
  add_h '          box-shadow: 0 2px 5px rgba(0,0,0,0.1); width: 200px;'.
  add_h '          border-left: 5px solid #007bff; }'.
  add_h '  .card.success { border-left-color: #28a745; }'.
  add_h '  .title { font-size: 11px; color: #666; text-transform: uppercase; margin-bottom: 5px; }'.
  add_h '  .value { font-size: 24px; font-weight: bold; color: #333; }'.
  add_h '</style></head><body>'.

  " --- B. Body Content (Cards) ---
  add_h '<div class="kpi-box">'.

  " Card 1: Total Orders
  add_h '  <div class="card">'.
  add_h '    <div class="title">Total Orders</div>'.
  lv_html_content = |    <div class="value">{ lv_str_total }</div>|.
  add_h lv_html_content.
  add_h '  </div>'.

  " Card 2: Total Revenue
  add_h '  <div class="card success">'.
  add_h '    <div class="title">Total Revenue</div>'.
  lv_html_content = |    <div class="value">{ lv_str_val }</div>|.
  add_h lv_html_content.
  add_h '  </div>'.

  add_h '</div></body></html>'.

  " --------------------------------------------------------------------
  " 5. LOAD & DISPLAY
  " --------------------------------------------------------------------
  " Load HTML table into memory and generate internal URL
  go_html_kpi_sd4->load_data(
    IMPORTING assigned_url = lv_url
    CHANGING  data_table   = lt_html ).

  " Render content
  go_html_kpi_sd4->show_url( url = lv_url ).

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DRAW_ALV_GRID_SD4
*&---------------------------------------------------------------------*
* Render or Refresh the ALV Grid for Sales Order Monitoring.
* - If grid exists: Refresh data and keep scroll position.
* - If grid is new: Instantiate, build field catalog, and display.
*----------------------------------------------------------------------*
FORM draw_alv_grid_sd4 .

  " --------------------------------------------------------------------
  " 1. REFRESH EXISTING GRID (Performance Optimization)
  " --------------------------------------------------------------------
  IF go_alv_sd4 IS BOUND.
    DATA: ls_stable TYPE lvc_s_stbl.
    " Keep Row and Column position stable after refresh
    ls_stable-row = 'X'.
    ls_stable-col = 'X'.
    go_alv_sd4->refresh_table_display( EXPORTING is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " --------------------------------------------------------------------
  " 2. INITIALIZE ALV CONTROL (Execute Once)
  " --------------------------------------------------------------------
  " Instantiate Grid Control in the Bottom Container
  CREATE OBJECT go_alv_sd4
    EXPORTING
      i_parent = go_c_bot_sd4.

  " --------------------------------------------------------------------
  " 3. BUILD FIELD CATALOG
  " --------------------------------------------------------------------
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_fcat TYPE lvc_s_fcat.

  " Local Macro: Simplify Field Catalog definition
  " &1: Fieldname, &2: Column Text, &3: Output Length
  DEFINE add_col.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-scrtext_m = &2.
    ls_fcat-outputlen = &3.

    " Specific Logic for Currency Fields (Summation)
    IF &1 = 'NETWR_I'.
       ls_fcat-do_sum     = 'X'.
       ls_fcat-cfieldname = 'WAERK'. " Link to Currency Key
    ENDIF.

    " Specific Logic for Status Icons
    IF &1 = 'STATUS_ICON'.
       ls_fcat-icon      = 'X'.
       ls_fcat-just      = 'C'. " Center alignment
       ls_fcat-scrtext_m = ''.  " Hide header text for icon column
    ENDIF.

    " Specific Logic for Date Fields (Format Reference)
    IF &1 = 'AUDAT' OR &1 = 'VDATU'.
       ls_fcat-ref_table = 'VBAK'. " Use DDIC properties from VBAK
       ls_fcat-ref_field = &1.
    ENDIF.

    APPEND ls_fcat TO lt_fcat.
  END-OF-DEFINITION.

  " --- Define Columns ---
  add_col 'STATUS_ICON' ''              4.   " Status Icon
  add_col 'GBSTK_TXT'   'Overall Stat.' 22.  " Status Description
  add_col 'VBELN'       'Sales Doc'     10.
  add_col 'AUART'       'Order Type'    5.
  add_col 'AUDAT'       'Doc. Date'     12.
  add_col 'VDATU'       'Req. Del. Date' 10.
  add_col 'VKORG'       'Sales Org.'    6.
  add_col 'VTWEG'       'Dis. Channel'  3.
  add_col 'SPART'       'Division'      2.
  add_col 'KUNNR'       'Sold-to'       10.
  add_col 'NAME1'       'Customer Name' 20.
  add_col 'POSNR'       'Item'          6.
  add_col 'MATNR'       'Material'      11.
  add_col 'KWMENG'      'Quantity'      12.
  add_col 'VRKME'       'Unit'          3.
  add_col 'NETWR_I'     'Net Value'     15.
  add_col 'WAERK'       'Currency'      5.

  " --------------------------------------------------------------------
  " 4. CONFIGURE LAYOUT
  " --------------------------------------------------------------------
  DATA: ls_layout TYPE lvc_s_layo.
  ls_layout-zebra    = 'X'. " Striped pattern
  ls_layout-sel_mode = 'A'. " Multiple row selection

  " --------------------------------------------------------------------
  " 5. DISPLAY GRID
  " --------------------------------------------------------------------
  go_alv_sd4->set_table_for_first_display(
    EXPORTING
      is_layout       = ls_layout
    CHANGING
      it_outtab       = gt_alv_sd4
      it_fieldcatalog = lt_fcat ).

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_FILTERED_DATA_SD4
*&---------------------------------------------------------------------*
* Retrieve data based on User Selection Criteria (Search Popup 0410).
* Logic:
* 1. Clear previous results.
* 2. Query Database using dynamic Select-Options.
* (Includes mandatory filter for branches: CNSG, CNHN, CNDN).
* 3. Derive custom statuses and recalculate Header KPIs.
*----------------------------------------------------------------------*
FORM get_filtered_data_sd4 .

  " 1. RESET DATA CONTAINER
  REFRESH: gt_alv_sd4.

  " 2. EXECUTE DATABASE QUERY
  " Join: Header (VBAK) -> Item (VBAP) -> Customer Name (KNA1)
  SELECT a~vbeln, a~auart, a~audat, a~vdatu, a~vkorg, a~vtweg, a~spart,
         a~kunnr, a~bstnk, a~waerk, a~gbstk,
         c~name1,
         b~posnr, b~matnr, b~kwmeng, b~vrkme, b~netwr AS netwr_i
    FROM vbak AS a
    INNER JOIN vbap AS b ON a~vbeln = b~vbeln
    LEFT  JOIN kna1 AS c ON a~kunnr = c~kunnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_alv_sd4
    WHERE a~vkorg IN ( 'CNSG', 'CNHN', 'CNDN' )  " Mandatory Scope
      AND a~vbeln IN @s_vbeln                    " -- Dynamic Filters --
      AND a~vkorg IN @s_vkorg
      AND a~kunnr IN @s_kunnr
      AND a~bstnk IN @s_bstnk
      AND a~audat IN @s_audat
      AND a~vdatu IN @s_vdatu
      AND a~gbstk IN @s_gbstk
      AND a~auart IN @s_auart
      AND a~vtweg IN @s_vtweg
      AND a~spart IN @s_spart
      AND a~erdat IN @s_erdat.

  " 3. POST-PROCESSING (Business Logic)
  " Determine Visual Status (Icon/Text) based on Document Flow
  PERFORM determine_custom_status_sd4.

  " 4. UPDATE DASHBOARD METRICS
  " Recalculate Totals based on the new filtered result set
  PERFORM calculate_kpi_sd4.

  " 5. DEFAULT SORTING
  " Sort by Document Date (Newest first)
  SORT gt_alv_sd4 BY audat DESCENDING vbeln DESCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*&             SCREEN 0430 - REPORT DASHBOARD.
*&---------------------------------------------------------------------*
*&  Purpose: Handle screen logic and event processing for Dashboard 0430
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&       Class LCL_EVENT_HANDLER_0430 Implementation
*&---------------------------------------------------------------------*
*&  Implementation of local class to handle events triggered from
*&  HTML Viewer (CL_GUI_HTML_VIEWER)
*&---------------------------------------------------------------------*
CLASS lcl_event_handler_0430 IMPLEMENTATION.

  "---------------------------------------------------------------------
  " Method: ON_SAPEVENT
  " Purpose: Handle 'sapevent' triggered from HTML/JavaScript
  " Parameters:
  "   action  - Action code sent from frontend (e.g. FILTER|Date|Region)
  "   table   - Data table (optional)
  "   getdata - Data string (optional)
  "---------------------------------------------------------------------
  METHOD on_sapevent.
    DATA: lv_action  TYPE string,
          lv_p1      TYPE string,
          lv_p2      TYPE string,
          lv_payload TYPE string.

    " --- [1] Parse Action String ---
    " Phân tách chuỗi action nhận được từ HTML để xác định loại sự kiện và tham số.
    " Format mong đợi: ACTION_CODE|PARAM1|PARAM2
    SPLIT action AT '|' INTO lv_action lv_p1 lv_p2.

    " --- [2] Event Processing Logic ---
    CASE lv_action.

        " --- Case 1: Filter Request ---
        " Người dùng nhấn nút 'Apply Filter' trên giao diện HTML
      WHEN 'FILTER'.
        " Ghép lại chuỗi payload để truyền vào form xử lý dữ liệu
        CONCATENATE lv_p1 lv_p2 INTO lv_payload SEPARATED BY '|'.

        " Xử lý trường hợp payload rỗng -> Load mặc định (ALL)
        IF lv_payload IS INITIAL OR lv_payload = '|'.
          lv_payload = 'ALL'.
        ENDIF.

        " Trigger tính toán lại dữ liệu và render lại biểu đồ
        PERFORM refresh_data_0430 USING lv_payload.

        " --- Case 2: Customer Interaction ---
        " Người dùng click vào chi tiết khách hàng trên biểu đồ
      WHEN 'CUSTOMER_CLICK'.
        DATA: lv_cust_data TYPE string.

        " Lấy dữ liệu chi tiết được gửi kèm sự kiện (Data context)
        lv_cust_data = getdata.

        " Gọi form xử lý nghiệp vụ chi tiết cho khách hàng (Drill-down)
        PERFORM handle_customer_click_0430 USING lv_cust_data.

      WHEN OTHERS.
        " No action for unknown events
    ENDCASE.

    " --- [3] Synchronization ---
    " Đồng bộ hóa hàng đợi Automation Queue để đảm bảo UI cập nhật tức thì
    cl_gui_cfw=>flush( ).

  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------------*
*&      Form  INIT_DASHBOARD_0430
*&---------------------------------------------------------------------*
*&  Purpose: Initialize UI components for Report Dashboard (Screen 0430)
*&           - Instantiate Custom Container
*&           - Instantiate HTML Viewer
*&           - Register Events
*&           - Load Initial Data
*&---------------------------------------------------------------------*
FORM init_dashboard_0430 .

  " --- [1] Singleton Pattern Check ---
  " Chỉ khởi tạo container và viewer một lần duy nhất khi PBO chạy lần đầu
  IF go_cc_dashboard_0430 IS INITIAL.

    " --- [2] Instantiate Custom Container ---
    " Tạo container liên kết với vùng 'CC_DASHBOARD_0430' trên Screen Painter
    CREATE OBJECT go_cc_dashboard_0430
      EXPORTING
        container_name = 'CC_DASHBOARD_0430'.

    " --- [3] Instantiate HTML Viewer ---
    " Nhúng trình duyệt HTML vào trong container vừa tạo
    CREATE OBJECT go_viewer_0430
      EXPORTING
        parent = go_cc_dashboard_0430.

    " --- [4] Event Registration ---
    " Đăng ký sự kiện 'sapevent' để Backend (ABAP) nhận được tín hiệu từ Frontend (JS)
    DATA: lt_events TYPE cntl_simple_events,
          ls_event  TYPE cntl_simple_event.

    ls_event-eventid    = go_viewer_0430->m_id_sapevent.
    ls_event-appl_event = 'X'. " Xử lý sự kiện ở PAI (Application Event)
    APPEND ls_event TO lt_events.

    go_viewer_0430->set_registered_events( events = lt_events ).

    " Gán Event Handler Class cho đối tượng Viewer
    SET HANDLER lcl_event_handler_0430=>on_sapevent FOR go_viewer_0430.

    " --- [5] Initial Data Load ---
    " Tải dữ liệu mặc định (Không lọc) khi màn hình khởi động
    PERFORM refresh_data_0430 USING 'ALL'.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  REFRESH_DATA_0430
*&---------------------------------------------------------------------*
*&  Purpose: Retrieve, Process, and Serialize Data for Dashboard 0430
*&           1. Fetch Sales Data (VBAK) based on filters.
*&           2. Determine Order Status (Flow from Order -> Delivery -> Billing -> FI).
*&           3. Fetch Finance Data (BSID/BSAD) for AR & Cashflow analysis.
*&           4. Aggregate data for Trend, Region, and Status charts.
*&           5. Map to JSON structure for HTML/Chart.js rendering.
*&---------------------------------------------------------------------*
FORM refresh_data_0430 USING p_filter_payload TYPE string.

  " --- [1] LOCAL TYPES DECLARATION ---
  " Define structure matching the JSON object expected by Chart.js (Frontend)
  TYPES: BEGIN OF ty_chart_item,
           label TYPE string,
           value TYPE netwr,
         END OF ty_chart_item.
  TYPES: tt_chart_data TYPE STANDARD TABLE OF ty_chart_item WITH EMPTY KEY.

  " Extended structure for Finance Scorecards (2x2 Grid)
  TYPES: BEGIN OF ty_finance_json,
           total_sales  TYPE netwr,
           billed_val   TYPE netwr,
           total_ar     TYPE netwr,
           clearing_val TYPE netwr,
           bill_rate    TYPE string,
           clear_pct    TYPE string,
           trend_sales  TYPE tt_netwr,  " Sparkline: Sales Trend
           trend_bill   TYPE tt_netwr,  " Sparkline: Billing Trend
           trend_clear  TYPE tt_netwr,  " Sparkline: Cash Collected Trend
           trend_ar     TYPE tt_netwr,  " Sparkline: Open AR Trend
           trend_labels TYPE tt_string,
         END OF ty_finance_json.

  " Main JSON Root Structure
  TYPES: BEGIN OF ty_dashboard_json_ext,
           kpi            TYPE ty_kpi_json,
           trend_labels   TYPE tt_string,
           trend_values   TYPE tt_netwr,
           status_data    TYPE tt_chart_data,
           region_data    TYPE tt_chart_data,
           top_cust_names TYPE tt_string,
           top_customers  TYPE tt_netwr,
           finance        TYPE ty_finance_json,
         END OF ty_dashboard_json_ext.

  DATA: ls_json_ext TYPE ty_dashboard_json_ext.

  " --- [2] PARSE INPUT PARAMETERS ---
  " Convert raw filter string (YYYYMMDD) to HTML format (YYYY-MM-DD) for Date Picker persistence
  DATA: lv_date_from_raw  TYPE string, lv_date_to_raw TYPE string,
        lv_date_from_html TYPE string, lv_date_to_html TYPE string,
        lv_datum_low      TYPE sy-datum, lv_datum_high TYPE sy-datum.

  lv_datum_low  = '20100101'. lv_datum_high = sy-datum.

  IF p_filter_payload = 'ALL' OR p_filter_payload IS INITIAL.
    CLEAR: lv_date_from_html, lv_date_to_html.
  ELSE.
    SPLIT p_filter_payload AT '|' INTO lv_date_from_raw lv_date_to_raw.
    lv_datum_low  = lv_date_from_raw. lv_datum_high = lv_date_to_raw.

    IF lv_datum_low IS NOT INITIAL.
      lv_date_from_html = |{ lv_datum_low(4) }-{ lv_datum_low+4(2) }-{ lv_datum_low+6(2) }|.
    ENDIF.
    IF lv_datum_high IS NOT INITIAL.
      lv_date_to_html = |{ lv_datum_high(4) }-{ lv_datum_high+4(2) }-{ lv_datum_high+6(2) }|.
    ENDIF.
  ENDIF.

  " --- [3] DATA OBJECTS DEFINITION ---
  " Main Sales Data
  DATA: lt_orders TYPE TABLE OF ty_sales_raw.

  " Document Flow (Sorted for Binary Search performance)
  DATA: lt_flow_del TYPE SORTED TABLE OF ty_doc_flow WITH NON-UNIQUE KEY vbelv,
        lt_flow_bil TYPE SORTED TABLE OF ty_doc_flow WITH NON-UNIQUE KEY vbelv.

  " Finance Data Buffers
  TYPES: BEGIN OF ty_fi_item, kunnr TYPE kunnr, bukrs TYPE bukrs, dmbtr TYPE dmbtr, END OF ty_fi_item.
  DATA: lt_bsid TYPE TABLE OF ty_fi_item, lt_bsad TYPE TABLE OF ty_fi_item.
  TYPES: BEGIN OF ty_tvko, vkorg TYPE vkorg, bukrs TYPE bukrs, END OF ty_tvko.
  DATA: lt_tvko TYPE TABLE OF ty_tvko.

  " Aggregation structures for Sparklines (Trend Analysis)
  TYPES: BEGIN OF ty_agg_fin_trend,
           erdat TYPE vbak-erdat,
           sales TYPE netwr,
           bill  TYPE netwr,
           clear TYPE netwr,
           ar    TYPE netwr,
         END OF ty_agg_fin_trend.
  DATA: lt_fin_trend TYPE SORTED TABLE OF ty_agg_fin_trend WITH UNIQUE KEY erdat,
        ls_fin_trend TYPE ty_agg_fin_trend.

  " Top Customers Aggregation
  TYPES: BEGIN OF ty_agg_cust, kunnr TYPE vbak-kunnr, netwr TYPE netwr, END OF ty_agg_cust.
  DATA: lt_cust_data TYPE SORTED TABLE OF ty_agg_cust WITH UNIQUE KEY kunnr, ls_cust_row TYPE ty_agg_cust.

  " Chart Aggregation Buffers (Hashed for performance)
  DATA: lt_status_agg TYPE HASHED TABLE OF ty_chart_item WITH UNIQUE KEY label,
        lt_region_agg TYPE HASHED TABLE OF ty_chart_item WITH UNIQUE KEY label,
        ls_agg_item   TYPE ty_chart_item.

  " KPI Accumulators
  DATA: lv_sales_sum TYPE netwr, lv_ret_sum TYPE netwr, lv_open_cnt TYPE i.
  DATA: lv_billed_sum   TYPE netwr, lv_ar_sum TYPE netwr, lv_clearing_sum TYPE netwr.

  " Use Ranges with Header Line for compatibility with older processing logic,
  " but ensuring S/4HANA View compliance in SELECTs below.
  DATA: r_kunnr TYPE RANGE OF kunnr WITH HEADER LINE,
        r_bukrs TYPE RANGE OF bukrs WITH HEADER LINE,
        r_augdt TYPE RANGE OF augdt WITH HEADER LINE,
        r_vkorg TYPE RANGE OF vkorg WITH HEADER LINE,
        r_erdat TYPE RANGE OF erdat WITH HEADER LINE.

  " --- [4] DATA RETRIEVAL (LOGISTICS) ---

  " 4.1. Set default filters (Hardcoded for Specific Regions as per Requirement)
  REFRESH r_vkorg. r_vkorg-sign = 'I'. r_vkorg-option = 'EQ'.
  r_vkorg-low = 'CNSG'. APPEND r_vkorg. r_vkorg-low = 'CNHN'. APPEND r_vkorg. r_vkorg-low = 'CNDN'. APPEND r_vkorg.

  " 4.2. Set Date Range
  REFRESH r_erdat. r_erdat-sign = 'I'. r_erdat-option = 'BT'. r_erdat-low = lv_datum_low. r_erdat-high = lv_datum_high. APPEND r_erdat.

  " 4.3. Fetch Sales Orders (VBAK)
  SELECT vbeln, auart, erdat, netwr, kunnr, vkorg
    INTO CORRESPONDING FIELDS OF TABLE @lt_orders
    FROM vbak WHERE vkorg IN @r_vkorg AND erdat IN @r_erdat.

  IF lt_orders IS NOT INITIAL.
    " 4.4. Fetch Related Organization Data
    SELECT vkorg, bukrs INTO CORRESPONDING FIELDS OF TABLE @lt_tvko
      FROM tvko FOR ALL ENTRIES IN @lt_orders
      WHERE vkorg = @lt_orders-vkorg.              "#EC CI_NO_TRANSFORM

    " 4.5. Fetch Document Flow (Billing & Delivery)
    SELECT a~vbelv, a~vbeln, a~vbtyp_n, b~rfbsk, b~fksto
      INTO CORRESPONDING FIELDS OF TABLE @lt_flow_bil
      FROM vbfa AS a INNER JOIN vbrk AS b ON a~vbeln = b~vbeln
      FOR ALL ENTRIES IN @lt_orders
      WHERE a~vbelv = @lt_orders-vbeln AND a~vbtyp_n = 'M' AND b~fksto = @space. "#EC CI_NO_TRANSFORM

    SELECT a~vbelv, a~vbeln, a~vbtyp_n, b~wbstk
      INTO CORRESPONDING FIELDS OF TABLE @lt_flow_del
      FROM vbfa AS a INNER JOIN likp AS b ON a~vbeln = b~vbeln
      FOR ALL ENTRIES IN @lt_orders
      WHERE a~vbelv = @lt_orders-vbeln AND a~vbtyp_n = 'J'. "#EC CI_NO_TRANSFORM

    " 4.6. Prepare Ranges for Finance Query (Extract Customers & Company Codes)
    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_o>).
      r_kunnr-sign = 'I'. r_kunnr-option = 'EQ'. r_kunnr-low = <ls_o>-kunnr. COLLECT r_kunnr.
      READ TABLE lt_tvko INTO DATA(ls_tvko) WITH KEY vkorg = <ls_o>-vkorg.
      IF sy-subrc = 0. r_bukrs-sign = 'I'. r_bukrs-option = 'EQ'. r_bukrs-low = ls_tvko-bukrs. COLLECT r_bukrs. ENDIF.
    ENDLOOP.

    " --- [5] DATA RETRIEVAL (FINANCE) ---
    IF r_kunnr[] IS NOT INITIAL AND r_bukrs[] IS NOT INITIAL.

      " 5.1. Fetch Open Items (AR) - Use S/4HANA CDS View 'BSID_VIEW'
      "      Logic: Get current open debt for selected customers
      SELECT kunnr, bukrs, dmbtr INTO CORRESPONDING FIELDS OF TABLE @lt_bsid
        FROM bsid_view
        WHERE kunnr IN @r_kunnr AND bukrs IN @r_bukrs.

      " 5.2. Prepare Date Range for Clearing Date
      "      Logic: We only care about payments cleared within the selected dashboard timeframe
      REFRESH r_augdt.
      LOOP AT r_erdat.
        r_augdt-sign   = r_erdat-sign.
        r_augdt-option = r_erdat-option.
        r_augdt-low    = r_erdat-low.
        r_augdt-high   = r_erdat-high.
        APPEND r_augdt.
      ENDLOOP.

      " 5.3. Fetch Cleared Items (Collected Cash) - Use S/4HANA CDS View 'BSAD_VIEW'
      SELECT kunnr, bukrs, dmbtr INTO CORRESPONDING FIELDS OF TABLE @lt_bsad
        FROM bsad_view
        WHERE kunnr IN @r_kunnr AND bukrs IN @r_bukrs AND augdt IN @r_augdt.
    ENDIF.
  ENDIF.

  " --- [6] MAIN LOGIC PROCESSING (CALCULATION & STATUS) ---
  DATA: ls_bill_info LIKE LINE OF lt_flow_bil, ls_del_info  LIKE LINE OF lt_flow_del.

  LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_ord>).
    CLEAR: <ls_ord>-status_txt.
    CLEAR: ls_fin_trend. ls_fin_trend-erdat = <ls_ord>-erdat.

    " 6.1. Status Determination Logic (Reverse Priority: FI -> Bill -> Delivery -> Order)
    "      Check if Billing Document exists
    READ TABLE lt_flow_bil INTO ls_bill_info WITH TABLE KEY vbelv = <ls_ord>-vbeln.
    IF sy-subrc = 0.
      " Check Accounting Status (RFBSK = 'C' means posted to FI)
      IF ls_bill_info-rfbsk = 'C'.
        <ls_ord>-status_txt = 'FI Doc created'.
        ls_fin_trend-clear = <ls_ord>-netwr. " Assume cleared for trend simplicity (refinement possible)
      ELSE.
        <ls_ord>-status_txt = 'Billing created'.
      ENDIF.

      " Accumulate Billed Value
      ls_fin_trend-bill = <ls_ord>-netwr.
      ADD <ls_ord>-netwr TO lv_billed_sum.
    ELSE.
      " No Billing found, check Delivery
      IF <ls_ord>-auart = 'ZORR' OR <ls_ord>-auart = 'ZBB' OR <ls_ord>-auart = 'ZFOC' OR <ls_ord>-auart = 'ZRET'.
        READ TABLE lt_flow_del INTO ls_del_info WITH TABLE KEY vbelv = <ls_ord>-vbeln.
        IF sy-subrc = 0.
          IF <ls_ord>-auart = 'ZRET'.
            IF ls_del_info-wbstk = 'C'. <ls_ord>-status_txt = 'PGR Posted, ready Billing'. ELSE. <ls_ord>-status_txt = 'Return Del created, ready PGR'. ENDIF.
          ELSE.
            IF ls_del_info-wbstk = 'C'. <ls_ord>-status_txt = 'PGI Posted, ready Billing'. ELSE. <ls_ord>-status_txt = 'Delivery created, ready PGI'. ENDIF.
          ENDIF.
        ELSE.
          <ls_ord>-status_txt = 'Order created'.
        ENDIF.
      ELSE.
        <ls_ord>-status_txt = 'Ready Billing'.
      ENDIF.
      " Not Billed yet -> Likely Open AR exposure
      ls_fin_trend-ar = <ls_ord>-netwr.
    ENDIF.

    " 6.2. KPI Accumulation
    IF <ls_ord>-auart = 'ZRET'.
      ADD <ls_ord>-netwr TO lv_ret_sum.
    ELSE.
      ADD <ls_ord>-netwr TO lv_sales_sum.
    ENDIF.

    " Count Open Orders (Anything not yet posted to FI or Billed)
    IF <ls_ord>-status_txt NP 'FI Doc*' AND <ls_ord>-status_txt NP 'Billing*'.
      ADD 1 TO lv_open_cnt.
    ENDIF.

    " 6.3. Collect Trend Data (Sparklines)
    ls_fin_trend-sales = <ls_ord>-netwr.
    COLLECT ls_fin_trend INTO lt_fin_trend.

    " 6.4. Collect Customer Data (Top 10)
    IF <ls_ord>-auart <> 'ZRET'.
      ls_cust_row-kunnr = <ls_ord>-kunnr. ls_cust_row-netwr = <ls_ord>-netwr.
      COLLECT ls_cust_row INTO lt_cust_data.
    ENDIF.

    " 6.5. Aggregate Status & Region for Charts
    CLEAR ls_agg_item. ls_agg_item-label = <ls_ord>-status_txt. ls_agg_item-value = 1.
    COLLECT ls_agg_item INTO lt_status_agg.

    CLEAR ls_agg_item.
    CASE <ls_ord>-vkorg.
      WHEN 'CNSG'. ls_agg_item-label = 'Ho Chi Minh'.
      WHEN 'CNHN'. ls_agg_item-label = 'Ha Noi'.
      WHEN 'CNDN'. ls_agg_item-label = 'Da Nang'.
      WHEN OTHERS. ls_agg_item-label = <ls_ord>-vkorg.
    ENDCASE.
    ls_agg_item-value = <ls_ord>-netwr.
    COLLECT ls_agg_item INTO lt_region_agg.
  ENDLOOP.

  " 6.6. Calculate Total Finance Sums
  LOOP AT lt_bsid INTO DATA(ls_bsid). ADD ls_bsid-dmbtr TO lv_ar_sum. ENDLOOP.
  LOOP AT lt_bsad INTO DATA(ls_bsad). ADD ls_bsad-dmbtr TO lv_clearing_sum. ENDLOOP.

  " --- [7] MAPPING DATA TO JSON (FRONTEND PREPARATION) ---

  " 7.1. KPI Cards (Scaled by Million, rounded to 2 decimals)
  ls_json_ext-kpi-sales   = |{ lv_sales_sum / lc_million DECIMALS = 2 }M|.
  ls_json_ext-kpi-returns = |{ lv_ret_sum / lc_million DECIMALS = 2 }M|.
  ls_json_ext-kpi-orders  = |{ lv_open_cnt }|.

  " 7.2. Finance Scorecard Values
  ls_json_ext-finance-total_sales  = lv_sales_sum.
  ls_json_ext-finance-billed_val   = lv_billed_sum.
  ls_json_ext-finance-total_ar     = lv_ar_sum.
  ls_json_ext-finance-clearing_val = lv_clearing_sum.

  " 7.3. Calculate Ratios (Bill Rate & Recovery Rate)
  "      Use CONV decfloat34 to force floating point division (avoid integer rounding)
  IF lv_sales_sum > 0.
    DATA(lv_rate) = ( CONV decfloat34( lv_billed_sum ) / lv_sales_sum ) * 100.
    ls_json_ext-finance-bill_rate = |{ lv_rate DECIMALS = 1 }|.
  ELSE.
    ls_json_ext-finance-bill_rate = '0.0'.
  ENDIF.

  IF ( lv_clearing_sum + lv_ar_sum ) > 0.
    DATA(lv_pct) = ( CONV decfloat34( lv_clearing_sum ) / ( lv_clearing_sum + lv_ar_sum ) ) * 100.
    ls_json_ext-finance-clear_pct = |{ lv_pct DECIMALS = 1 }|.
  ELSE.
    ls_json_ext-finance-clear_pct = '0.0'.
  ENDIF.

  " 7.4. Map Sparkline Trend Arrays
  LOOP AT lt_fin_trend INTO ls_fin_trend.
    APPEND ls_fin_trend-sales TO ls_json_ext-finance-trend_sales.
    APPEND ls_fin_trend-bill  TO ls_json_ext-finance-trend_bill.
    APPEND ls_fin_trend-clear TO ls_json_ext-finance-trend_clear.
    APPEND ls_fin_trend-ar    TO ls_json_ext-finance-trend_ar.

    " Format Date Label: YYYYMMDD -> DD/MM
    DATA(lv_d) = |{ ls_fin_trend-erdat+6(2) }/{ ls_fin_trend-erdat+4(2) }|.
    APPEND lv_d TO ls_json_ext-finance-trend_labels.

    " Backward compatibility for Main Sales Trend Chart
    APPEND ls_fin_trend-sales TO ls_json_ext-trend_values.
    APPEND lv_d TO ls_json_ext-trend_labels.
  ENDLOOP.

  " 7.5. Map Aggregated Charts
  LOOP AT lt_status_agg INTO ls_agg_item. APPEND ls_agg_item TO ls_json_ext-status_data. ENDLOOP.
  LOOP AT lt_region_agg INTO ls_agg_item. APPEND ls_agg_item TO ls_json_ext-region_data. ENDLOOP.

  " 7.6. Process Top 10 Customers
  DATA: lt_cust_std TYPE STANDARD TABLE OF ty_agg_cust.
  lt_cust_std = lt_cust_data. SORT lt_cust_std BY netwr DESCENDING.
  DATA: lv_c  TYPE i VALUE 0, lv_nm TYPE kna1-name1.
  LOOP AT lt_cust_std INTO ls_cust_row.
    lv_c = lv_c + 1.
    IF lv_c > 10. EXIT. ENDIF.
    " Retrieve Customer Name for display
    SELECT SINGLE name1 INTO lv_nm FROM kna1 WHERE kunnr = ls_cust_row-kunnr.
    IF sy-subrc <> 0. lv_nm = ls_cust_row-kunnr. ENDIF.
    APPEND ls_cust_row-netwr TO ls_json_ext-top_customers. APPEND lv_nm TO ls_json_ext-top_cust_names.
  ENDLOOP.

  " --- [8] SERIALIZATION ---
  " Serialize structure to JSON string
  DATA(lv_js_data) = /ui2/cl_json=>serialize( data = ls_json_ext compress = abap_true pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  IF lv_js_data IS INITIAL. lv_js_data = '{}'. ENDIF.

  " --- [9] RENDER ---
  " Pass JSON to HTML Renderer
  PERFORM render_html_0430 USING lv_js_data lv_date_from_html lv_date_to_html.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form render_html_0430
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_JS_DATA
*&      --> LV_DATE_FROM_HTML
*&      --> LV_DATE_TO_HTML
*&---------------------------------------------------------------------*
FORM render_html_0430 USING p_json_data TYPE string
                            p_d1        TYPE string  " Giữ để tương thích
                            p_d2        TYPE string. " Giữ để tương thích
  DATA: lv_html TYPE string.

  " --- [1] HTML HEADER & CSS ---
  lv_html =
  '<!DOCTYPE html><html><head><meta charset="UTF-8">' &&
  '<meta http-equiv="X-UA-Compatible" content="IE=edge">' &&
  '<style>' &&
  'body { font-family: "72", "Segoe UI", Arial, sans-serif; margin: 0; ' &&
  '       padding: 10px; background: #edf2f4; height: 95vh; display: flex; ' &&
  '       gap: 10px; overflow: hidden; color: #32363a; } ' &&

  " Layout
  '.col-left { flex: 1; background: #fff; display: flex; flex-direction: column; ' &&
  '            border-radius: 4px; box-shadow: 0 0 2px rgba(0,0,0,0.1); ' &&
  '            border-right: 1px solid #d9d9d9; padding: 15px; } ' &&
  '.col-mid  { flex: 3.5; display: flex; flex-direction: column; gap: 10px; } ' &&
  '.col-right{ flex: 1.2; background: #fff; padding: 15px; border-radius: 4px; ' &&
  '            box-shadow: 0 0 2px rgba(0,0,0,0.1); display: flex; ' &&
  '            flex-direction: column; } ' &&

  " Menu Styles (Đã chỉnh margin-top để đẹp hơn khi đứng đầu)
  '.sb-group { font-size: 12px; font-weight: bold; color: #6a6d70; ' &&
  '            text-transform: uppercase; margin-bottom: 10px; margin-top: 5px; } ' &&
  '.list-item { padding: 12px 10px; cursor: pointer; border-left: 3px solid transparent; ' &&
  '             color: #32363a; font-size: 14px; display: flex; align-items: center; ' &&
  '             border-bottom: 1px solid #f5f5f5; } ' && " Thêm gạch chân nhẹ cho đẹp
  '.list-item:hover { background: #f5f7f9; } ' &&
  '.list-item.selected { background: #eff4f9; border-left-color: #0070f2; ' &&
  '                     color: #0070f2; font-weight: 600; } ' &&
  '.icon { margin-right: 12px; width: 20px; text-align: center; font-size: 16px; } ' &&

  " KPI Cards
  '.kpi-row { display: flex; gap: 10px; height: 110px; flex-shrink: 0; } ' &&
  '.kpi-card { flex: 1; background: #fff; padding: 15px; border-radius: 4px; ' &&
  '            box-shadow: 0 0 2px rgba(0,0,0,0.1); display: flex; ' &&
  '            flex-direction: column; justify-content: center; ' &&
  '            border-top: 4px solid transparent; } ' &&
  '.bd-green { border-top-color: #107e3e; } .bd-red { border-top-color: #bb0000; } ' &&
  '.bd-blue { border-top-color: #0070f2; } ' &&
  '.kpi-val { font-size: 28px; font-weight: normal; color: #32363a; ' &&
  '           margin-bottom: 4px; } ' &&
  '.kpi-tit { font-size: 13px; color: #6a6d70; } ' &&

  " Chart Box
  '.chart-box { flex: 1; background: #fff; border-radius: 4px; box-shadow: 0 0 2px rgba(0,0,0,0.1); ' &&
  '             position: relative; overflow: hidden; display: flex; flex-direction: column; } ' &&
  '.chart-header { padding: 15px; border-bottom: 1px solid #eff4f9; display: flex; ' &&
  '                justify-content: space-between; align-items: center; height: 30px; flex-shrink: 0; } ' &&
  '.chart-tit-main { font-size: 16px; font-weight: normal; color: #32363a; } ' &&
  '.chart-wrap { flex: 1; position: relative; width: 100%; overflow: hidden; padding: 10px; box-sizing: border-box; } ' &&

  " Finance Grid
  '.fin-grid { display: none; height: 100%; width: 100%; box-sizing: border-box; ' &&
  '            padding: 10px; grid-template-columns: 1fr 1fr; ' &&
  '            grid-template-rows: repeat(2, minmax(0, 1fr)); gap: 15px; } ' &&
  '.fin-card { background: #fff; border: 1px solid #eee; border-radius: 6px; ' &&
  '            padding: 10px 15px; display: flex; flex-direction: column; ' &&
  '            position: relative; box-shadow: 0 2px 4px rgba(0,0,0,0.03); ' &&
  '            height: 100%; overflow: hidden; box-sizing: border-box; } ' &&
  '.fin-head { display: flex; justify-content: space-between; ' &&
  '            align-items: flex-start; margin-bottom: 2px; } ' &&
  '.fin-tit { font-size: 12px; color: #666; font-weight: bold; text-transform: uppercase; } ' &&
  '.fin-pct { font-size: 11px; font-weight: bold; padding: 2px 6px; border-radius: 4px; } ' &&
  '.pct-pos { color: #107e3e; background: #dff0d8; } ' &&
  '.pct-neu { color: #0070f2; background: #e8f0fe; } ' &&
  '.fin-val { font-size: 22px; font-weight: bold; color: #333; margin-bottom: 5px; } ' &&
  '.fin-chart-area { flex: 1; position: relative; width: 100%; min-height: 0; } ' &&
  '</style>' &&

  " Libraries
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>' &&
  '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">' &&
  '</head><body>'.

  " --- [2] HTML BODY ---
  lv_html = lv_html &&
  '<div class="col-left">' &&
  "  ĐÃ XÓA FILTER SECTION Ở ĐÂY "

  '  <div class="sb-group">View Options</div>' &&
  '  <div class="list-item chart-opt selected" onclick="switchChart(this, ''TREND'')">' &&
  '     <span class="icon"><i class="fas fa-chart-line"></i></span> Sales Trend</div>' &&
  '  <div class="list-item chart-opt" onclick="switchChart(this, ''STATUS'')">' &&
  '     <span class="icon"><i class="fas fa-chart-pie"></i></span> Order Status</div>' &&
  '  <div class="list-item chart-opt" onclick="switchChart(this, ''REGION'')">' &&
  '     <span class="icon"><i class="fas fa-globe-asia"></i></span> By Region</div>' &&
  '  <div class="list-item chart-opt" onclick="switchChart(this, ''FINANCE'')">' &&
  '     <span class="icon"><i class="fas fa-coins"></i></span> Finance & Cashflow</div>' &&
  '</div>' &&

  '<div class="col-mid">' &&
  ' <div class="kpi-row">' &&
  '  <div class="kpi-card bd-green"><div class="kpi-tit">Net Sales</div>' &&
  '      <div class="kpi-val" id="sales">---</div></div>' &&
  '  <div class="kpi-card bd-red"><div class="kpi-tit">Returns</div>' &&
  '      <div class="kpi-val" id="ret">---</div></div>' &&
  '  <div class="kpi-card bd-blue"><div class="kpi-tit">Open Orders</div>' &&
  '      <div class="kpi-val" id="open">---</div></div>' &&
  ' </div>' &&

  ' <div class="chart-box">' &&
  '   <div class="chart-header"><div class="chart-tit-main" id="chartTitle">Sales Trend Analysis</div></div>' &&
  '   <div class="chart-wrap" id="mainChartWrap"><canvas id="mainChart"></canvas></div>' &&

  '   <div class="fin-grid" id="finGrid">' &&
  '     <div class="fin-card">' &&
  '       <div class="fin-head"><span class="fin-tit">Total Revenue</span></div>' &&
  '       <div class="fin-val" id="f_sales">---</div>' &&
  '       <div class="fin-chart-area"><canvas id="c_sales"></canvas></div>' &&
  '     </div>' &&
  '     <div class="fin-card">' &&
  '       <div class="fin-head"><span class="fin-tit">Billed Value</span>' &&
  '           <span class="fin-pct pct-pos" id="f_brate">0%</span></div>' &&
  '       <div class="fin-val" id="f_billed">---</div>' &&
  '       <div class="fin-chart-area"><canvas id="c_billed"></canvas></div>' &&
  '     </div>' &&
  '     <div class="fin-card">' &&
  '       <div class="fin-head"><span class="fin-tit">Collected (Cash)</span>' &&
  '           <span class="fin-pct pct-pos" id="f_crate">0%</span></div>' &&
  '       <div class="fin-val" id="f_clear">---</div>' &&
  '       <div class="fin-chart-area"><canvas id="c_clear"></canvas></div>' &&
  '     </div>' &&
  '     <div class="fin-card">' &&
  '       <div class="fin-head"><span class="fin-tit">Open AR</span>' &&
  '           <span class="fin-pct pct-neu">Pending</span></div>' &&
  '       <div class="fin-val" id="f_ar">---</div>' &&
  '       <div class="fin-chart-area"><canvas id="c_ar"></canvas></div>' &&
  '     </div>' &&
  '   </div>' &&
  ' </div>' &&
  '</div>' &&

  '<div class="col-right">' &&
  '  <div style="font-weight:bold;margin-bottom:15px;text-align:center;font-size:12px;' &&
  '              color:#666;text-transform:uppercase">Top 6 Customers</div>' &&
  '  <div style="flex:1; position:relative"><canvas id="barChart"></canvas></div>' &&
  '</div>'.

  " --- [3] JAVASCRIPT ---
  lv_html = lv_html &&
  '<script>' &&
  'var sapData = ' && p_json_data && ';' &&
  'var mainChartInstance = null;' &&
  'var miniCharts = [];' &&

  " Đã xóa hàm doFilter() vì không còn nút bấm "

  'function drawSpark(ctxId, dataVals, color) {' &&
  '  return new Chart(document.getElementById(ctxId), {' &&
  '    type: "line",' &&
  '    data: { labels: sapData.finance.trendLabels, ' &&
  '            datasets: [{ data: dataVals, borderColor: color, borderWidth: 2, ' &&
  '                        pointRadius: 1, fill: false }] },' &&
  '    options: { responsive: true, maintainAspectRatio: false, legend: {display:false}, ' &&
  '               scales: { xAxes:[{display:false}], ' &&
  '                         yAxes:[{display:false, ticks:{beginAtZero:true}}] }, ' &&
  '               layout: {padding: {top: 5, bottom: 25, left: 5, right: 5}} }' &&
  '  });' &&
  '}' &&

  'function switchChart(el, type) {' &&
  '  document.querySelectorAll(".chart-opt").forEach(i => i.classList.remove("selected"));' &&
  '  el.classList.add("selected");' &&
  '  if(mainChartInstance) { mainChartInstance.destroy(); }' &&
  '  miniCharts.forEach(c => c.destroy()); miniCharts = [];' &&

  '  var mainWrap = document.getElementById("mainChartWrap");' &&
  '  var finGrid  = document.getElementById("finGrid");' &&

  '  if (type === "FINANCE") {' &&
  '     mainWrap.style.display = "none";' &&
  '     finGrid.style.display = "grid";' &&
  '     document.getElementById("chartTitle").innerText = "Financial Performance Scorecards";' &&

  '     document.getElementById("f_sales").innerText = parseInt(sapData.finance.totalSales).toLocaleString();' &&
  '     document.getElementById("f_billed").innerText = parseInt(sapData.finance.billedVal).toLocaleString();' &&
  '     document.getElementById("f_clear").innerText = parseInt(sapData.finance.clearingVal).toLocaleString();' &&
  '     document.getElementById("f_ar").innerText = parseInt(sapData.finance.totalAr).toLocaleString();' &&
  '     document.getElementById("f_brate").innerText = "Bill Rate: " + sapData.finance.billRate + "%";' &&
  '     document.getElementById("f_crate").innerText = "Recovery: " + sapData.finance.clearPct + "%";' &&

  '     miniCharts.push(drawSpark("c_sales", sapData.finance.trendSales, "#3498db"));' &&
  '     miniCharts.push(drawSpark("c_billed", sapData.finance.trendBill, "#2ecc71"));' &&
  '     miniCharts.push(drawSpark("c_clear", sapData.finance.trendClear, "#27ae60"));' &&
  '     miniCharts.push(drawSpark("c_ar", sapData.finance.trendAr, "#e74c3c"));' &&

  '  } else {' &&
  '     finGrid.style.display = "none";' &&
  '     mainWrap.style.display = "block";' &&
  '     var ctx = document.getElementById("mainChart");' &&

  '     if (type === "TREND") {' &&
  '        document.getElementById("chartTitle").innerText = "Sales Revenue Trend";' &&
  '        mainChartInstance = new Chart(ctx, { type: "line", ' &&
  '          data: { labels: sapData.trendLabels, ' &&
  '                  datasets: [{ label: "Revenue", data: sapData.trendValues, ' &&
  '                              borderColor: "#0070f2", backgroundColor: "rgba(0,112,242,0.1)", ' &&
  '                              pointRadius: 3 }] }, ' &&
  '          options: { responsive: true, maintainAspectRatio: false, legend: {display:false} } });' &&

  '     } else if (type === "STATUS") {' &&
  '        document.getElementById("chartTitle").innerText = "Order Processing Status";' &&
  '        var l=[], v=[]; sapData.statusData.forEach(i=>{l.push(i.label);v.push(i.value)});' &&
  '        mainChartInstance = new Chart(ctx, { type: "doughnut", ' &&
  '          data: { labels: l, datasets: [{ data: v, backgroundColor: ["#2b78c5","#d04343","#e09d00","#8f6dc8","#45586d"] }] }, ' &&
  '          options: { responsive: true, maintainAspectRatio: false, legend: {position:"right"} } });' &&

  '     } else if (type === "REGION") {' &&
  '        document.getElementById("chartTitle").innerText = "Sales by Region";' &&
  '        var l=[], v=[]; sapData.regionData.forEach(i=>{l.push(i.label);v.push(i.value)});' &&
  '        mainChartInstance = new Chart(ctx, { type: "bar", ' &&
  '          data: { labels: l, datasets: [{ label: "Revenue", data: v, backgroundColor: "#0070f2" }] }, ' &&
  '          options: { responsive: true, maintainAspectRatio: false, legend: {display:false} } });' &&
  '     }' &&
  '  }' &&
  '}' &&

  " Init
  'try {' &&
  '  document.getElementById("sales").innerText = sapData.kpi.sales;' &&
  '  document.getElementById("ret").innerText = sapData.kpi.returns;' &&
  '  document.getElementById("open").innerText = sapData.kpi.orders;' &&
  '  switchChart(document.querySelector(".chart-opt"), "TREND");' &&
  '  new Chart(document.getElementById("barChart"), { type: "bar", ' &&
  '    data: { labels: sapData.topCustNames, ' &&
  '            datasets: [{ label: "Sales", data: sapData.topCustomers, ' &&
  '                        backgroundColor: "#d04343" }] }, ' &&
  '    options: { responsive: true, maintainAspectRatio: false, legend: {display:false} } });' &&
  '} catch(e) { document.body.innerHTML += e.message; }' &&
  '</script></body></html>'.

  " --- [4] LOAD DATA ---
  DATA: lt_html_tab TYPE TABLE OF w3html.
  CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
    EXPORTING
      text      = lv_html
    TABLES
      ftext_tab = lt_html_tab.

  DATA: lv_url TYPE c LENGTH 255.
  go_viewer_0430->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_html_tab ).
  go_viewer_0430->show_url( url = lv_url ).
  cl_gui_cfw=>flush( ).
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  HANDLE_CUSTOMER_CLICK_0430
*&---------------------------------------------------------------------*
*&  Purpose: Handle drill-down navigation when a user clicks on a
*&           Top Customer bar in the dashboard.
*&           1. Resolve Customer Number (KUNNR) from the provided Name.
*&           2. Pre-fill selection criteria using SPA/GPA Memory.
*&           3. Launch Sales Order List (VA05) for the specific customer.
*&---------------------------------------------------------------------*
*&  Parameters:
*&    p_cust_name - Customer Name (or ID) passed from Chart.js label.
*&---------------------------------------------------------------------*
FORM handle_customer_click_0430 USING p_cust_name TYPE string.

  DATA: lv_kunnr TYPE kunnr.

  " --- [1] RESOLVE CUSTOMER ID (MAPPING) ---
  " The chart displays Customer Name (NAME1) for readability, but VA05 requires KUNNR.
  " Attempt to retrieve the unique Customer Number based on the clicked name.
  SELECT kunnr INTO lv_kunnr
    FROM kna1
    UP TO 1 ROWS
    WHERE name1 = p_cust_name
    ORDER BY kunnr ASCENDING.
  ENDSELECT.

  " --- [2] FALLBACK & NORMALIZATION ---
  " If name lookup fails (e.g. name not unique or chart label is already an ID),
  " treat the input string directly as the Customer Number.
  IF sy-subrc <> 0.
    lv_kunnr = p_cust_name.

    " Standardize format: Add leading zeros (Alpha Input Conversion)
    " This ensures '100' becomes '0000000100' to match DB keys.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_kunnr
      IMPORTING
        output = lv_kunnr.
  ENDIF.

  " --- [3] EXECUTE TRANSACTION (DRILL-DOWN) ---
  " Set SPA/GPA Memory ID 'KUN' (Customer Number)
  " This passes the context (lv_kunnr) to the target transaction's selection screen.
  SET PARAMETER ID 'KUN' FIELD lv_kunnr.

  " Launch 'List of Sales Orders' (VA05) and skip initial screen
  " to show the list immediately based on the Memory ID parameter.
  CALL TRANSACTION 'VA05' AND SKIP FIRST SCREEN.  "#EC CI_CALLTA

ENDFORM.
