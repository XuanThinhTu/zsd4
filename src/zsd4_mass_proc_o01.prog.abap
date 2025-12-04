*&---------------------------------------------------------------------*
*& Include          ZSD4_SALES_ORDER_CENTERO01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.

  " Set GUI status and title
  SET PF-STATUS 'ST0100'.
  SET TITLEBAR 'T0100'.

  " Set default selection if none selected
  IF rb_single IS INITIAL AND rb_mass IS INITIAL AND
     rb_status IS INITIAL AND rb_remon IS INITIAL.
    rb_single = abap_true.
  ENDIF.

  " Load tip texts
  PERFORM load_tips.

  " Pick a random tip from lt_tips
  DATA: lv_count  TYPE i,
        lv_random TYPE i.

  DESCRIBE TABLE lt_tips LINES lv_count.

  IF lv_count > 0.
    lv_random = ( sy-uzeit MOD lv_count ) + 1.
    READ TABLE lt_tips INDEX lv_random INTO tip_text.
  ENDIF.

* SAY HI AS FIORI FORM
  DATA: lv_fullname TYPE string,
        lv_dept     TYPE string,
        ls_address  TYPE bapiaddr3,            " Cấu trúc của ADDRESS
        lt_return   TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY.  " Bắt buộc

  CALL FUNCTION 'BAPI_USER_GET_DETAIL'
    EXPORTING
      username = sy-uname
    IMPORTING
      address  = ls_address
    TABLES
      return   = lt_return.   " BẮT BUỘC trong SAP GUI 800+

  " Lấy tên & bộ phận
  lv_fullname = ls_address-fullname.

  " Fallback nếu trống
  IF lv_fullname IS INITIAL.
    lv_fullname = sy-uname.
  ENDIF.

  gv_hello_text = |Hello, { lv_fullname }|.


ENDMODULE.



*&---------------------------------------------------------------------*
*& Module STATUS_0120 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0120 OUTPUT.
  SET PF-STATUS 'ST0120'.
  SET TITLEBAR 'T0120'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0110 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0110 OUTPUT.
  SET PF-STATUS 'ST0110'.
  SET TITLEBAR 'T0110'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0111 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0111 OUTPUT.
  " Default setting
  "SET the default as disabling the Tracking navigation button
  "If save is success then Track is available
  SET PF-STATUS 'ST0111'.
  SET TITLEBAR 'T0111'.

  " 2. Gọi FORM logic PBO chính (sẽ chứa logic ẩn/hiện nút)
  PERFORM pbo_screen_0111.

  " Screen logic
  PERFORM pbo_modify_screen.

  " Assign default value
  PERFORM pbo_default_data.

ENDMODULE.

MODULE status_0200 OUTPUT.

  DATA: lt_exclude TYPE TABLE OF sy-ucomm.
  REFRESH lt_exclude.

  " Ẩn/hiện nút trên PF-STATUS
  IF gv_data_loaded = abap_false.
    APPEND 'VALI'    TO lt_exclude.
    APPEND 'CLEA'    TO lt_exclude.
    APPEND 'SAVE'    TO lt_exclude.
    APPEND 'CREA_SO' TO lt_exclude.
  ENDIF.

  SET PF-STATUS 'ST_0200' EXCLUDING lt_exclude.
  SET TITLEBAR 'T0200'.

  "-------------------------------------------------
  " 1. Khởi tạo Docking Container cho Validation Summary
  "-------------------------------------------------
  IF go_docking_summary IS INITIAL.
    CREATE OBJECT go_docking_summary
      EXPORTING
        side      = cl_gui_docking_container=>dock_at_top
        extension = 120          " <-- Chiều cao ban đầu của summary (pixel)
        repid     = sy-repid
        dynnr     = sy-dynnr
      EXCEPTIONS
        OTHERS    = 1.

    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = go_docking_summary.
  ENDIF.

  "-------------------------------------------------
  " 2. Resize dynamic theo trạng thái dữ liệu
  "-------------------------------------------------
  IF gv_data_loaded = abap_false.

    " Chưa có data -> cho welcome screen cao hơn chút cho dễ đọc
    go_docking_summary->set_extension( 300 ).  " to hơn

    PERFORM display_welcome_screen.

  ELSE.

    " ĐÃ có data -> cho summary thấp lại,
    " tabstrip sẽ chiếm gần như toàn bộ màn hình
    go_docking_summary->set_extension( 80 ).   " nhỏ lại, tuỳ bạn chỉnh 60/80/100

    PERFORM update_status_counts.
    PERFORM build_html_summary.

  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0201 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0201 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0202 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0202 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0203 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0203 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
ENDMODULE.

*&SPWIZARD: OUTPUT MODULE FOR TS 'TS_MAIN'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: SETS ACTIVE TAB
MODULE ts_main_active_tab_set OUTPUT.
  ts_main-activetab = g_ts_main-pressed_tab.
  CASE g_ts_main-pressed_tab.
    WHEN c_ts_main-tab1.
      g_ts_main-subscreen = '0112'.
    WHEN c_ts_main-tab2.
      g_ts_main-subscreen = '0113'.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.

*&SPWIZARD: OUTPUT MODULE FOR TS 'TS_VALI'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: SETS ACTIVE TAB
MODULE ts_vali_active_tab_set OUTPUT.
  ts_vali-activetab = g_ts_vali-pressed_tab.
  CASE g_ts_vali-pressed_tab.
    WHEN c_ts_vali-tab1.
      g_ts_vali-subscreen = '0201'.
    WHEN c_ts_vali-tab2.
      g_ts_vali-subscreen = '0202'.
    WHEN c_ts_vali-tab3.
      g_ts_vali-subscreen = '0203'.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0201 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0201 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
  " Call the form that will build the ALV layout for this subscreen
  PERFORM build_alv_layout_0201.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0202 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0202 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
  PERFORM build_alv_layout_0202.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0203 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0203 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
  PERFORM build_alv_layout_0203.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0500  OUTPUT
*&---------------------------------------------------------------------*
*&      Module này set PF-Status và load các giá trị dropdown
*&---------------------------------------------------------------------*
MODULE status_0500 OUTPUT.
  "1. Set GUI status and title
  SET PF-STATUS 'ST0500'.
* SET TITLEBAR 'ST_TITLE'.  "Tùy chọn nếu có titlebar riêng

  "2. Initialize dropdown values (từ include ZPG_216_SOF00)
  PERFORM set_dropdown_sales_status.
  PERFORM set_dropdown_delivery_status.
  PERFORM set_dropdown_billing_status.
  PERFORM set_dropdown_process_phase.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  DISPLAY_TRACKING_ALV  OUTPUT
*&---------------------------------------------------------------------*
*&      Module này khởi tạo ALV Grid trong container
*&---------------------------------------------------------------------*
MODULE display_tracking_alv OUTPUT.

  "=========================================================
  "=== 1. KHỞI TẠO ALV (CHỈ CHẠY 1 LẦN)
  "=========================================================
  " Chúng ta lấy logic khởi tạo đầy đủ nhất (có event handler và checkbox)
  IF go_container3 IS INITIAL.

    " 1. Tạo container
    CREATE OBJECT go_container3
      EXPORTING container_name = 'CC_TRACKING'. "Tên container trên Screen

    " 2. Tạo ALV Grid
    CREATE OBJECT go_alv1
      EXPORTING i_parent = go_container3.

    " 3. Tạo Event Handler (Quan trọng để bắt hotspot/double click)
    " (Giả định go_event_handler_track đã được khai báo ở TOP)
    CREATE OBJECT go_event_handler_track
      EXPORTING
        io_grid  = go_alv1
        it_table = REF #( gt_tracking ).

    " 4. Đăng ký (Set) các sự kiện cho ALV này
    SET HANDLER go_event_handler_track->handle_hotspot_click FOR go_alv1.
    " (Kích hoạt các handler khác nếu cần)
    " SET HANDLER go_event_handler_track->handle_user_command FOR go_alv1.
    " SET HANDLER go_event_handler_track->handle_toolbar FOR go_alv1.

    " 5. Chuẩn bị Field Catalog VÀ Layout
    PERFORM alv_prepare. " (Đảm bảo PERFORM này tạo gt_fcat và gt_exclude1)

    " 6. GÁN LAYOUT CHO CHECKBOX (Rất quan trọng cho PAI)
    gs_layout1-box_fname = 'SEL_BOX'. " Tên trường checkbox

    " 7. GÁN CHẾ ĐỘ CHỌN NHIỀU
    gs_layout1-sel_mode = 'A'. " Cho phép chọn nhiều dòng

    " 8. Hiển thị ALV lần đầu
    CALL METHOD go_alv1->set_table_for_first_display
      EXPORTING
        is_layout            = gs_layout1
        it_toolbar_excluding = gt_exclude1 " Sử dụng biến từ code "dọn dẹp"
      CHANGING
        it_outtab            = gt_tracking
        it_fieldcatalog      = gt_fcat.
  ENDIF.

  "=========================================================
  "=== 2. SET SẴN SÀNG NHẬP LIỆU (CHẠY MỖI LẦN)
  "=========================================================
  " Logic này phải chạy MỖI KHI PBO được gọi (nằm ngoài IF INITIAL)
  " để ALV biết nhận diện checkbox đã tick ở PAI.
  "
  " (ĐÃ SỬA: Dùng go_alv1 thay vì go_alv)
  "=========================================================
  IF go_alv1 IS BOUND.
    CALL METHOD go_alv1->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.
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

*&SPWIZARD: OUTPUT MODULE FOR TS 'TS_PGI'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: SETS ACTIVE TAB
MODULE ts_pgi_active_tab_set OUTPUT.
  ts_pgi-activetab = g_ts_pgi-pressed_tab.
  CASE g_ts_pgi-pressed_tab.
    WHEN c_ts_pgi-tab1.
      g_ts_pgi-subscreen = '0301'.
    WHEN c_ts_pgi-tab2.
      g_ts_pgi-subscreen = '0302'.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0112 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0112 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
  " Gọi FORM để vẽ ALV Item (chúng ta đã tạo kế hoạch)
  PERFORM build_alv_layout_single_item.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0600 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0600 OUTPUT.
  SET PF-STATUS 'ST0600'.
  SET TITLEBAR 'T0600'.

   " <<< THÊM DÒNG NÀY >>>
  PERFORM set_dropdown_monitoring_status.

  " Gọi FORM build ALV
  PERFORM build_alv_monitoring.

     " <<< SỬA LOGIC AUTO-LOAD >>>
  IF gv_monitor_first_load = abap_true.
    CLEAR gv_monitor_first_load. " Xóa cờ (chỉ chạy 1 lần)
    status = 'ALL'. " Set default filter
    PERFORM load_monitoring_data.

    " 2. [THÊM MỚI] Báo cho ALV Grid biết data đã thay đổi
    IF go_grid_monitoring IS BOUND.
      CALL METHOD go_grid_monitoring->refresh_table_display( ).
    ENDIF.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0113 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0113 OUTPUT.
    PERFORM build_conditions_alv .

  " ====================================================================
  " [QUAN TRỌNG] ĐĂNG KÝ SỰ KIỆN ENTER ĐỂ KÍCH HOẠT TÍNH TOÁN NGAY LẬP TỨC
  " ====================================================================
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
  PERFORM display_conditions_for_item
    USING gv_current_item_idx.
ENDMODULE.

*&SPWIZARD: OUTPUT MODULE FOR TS 'TS_BILLING'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: SETS ACTIVE TAB
MODULE ts_billing_active_tab_set OUTPUT.
  ts_billing-activetab = g_ts_billing-pressed_tab.
  CASE g_ts_billing-pressed_tab.
    WHEN c_ts_billing-tab1.
      g_ts_billing-subscreen = '0401'.
    WHEN c_ts_billing-tab2.
      g_ts_billing-subscreen = '0402'.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SCREEN_0600 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_screen_0600 OUTPUT.

  " Gọi FORM build ALV
  PERFORM build_alv_monitoring.

  " Lấy dữ liệu (Chỉ chạy lần đầu)
  IF gt_monitoring_data IS INITIAL.
    PERFORM load_monitoring_data.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0300 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
 SET PF-STATUS 'ST0300'.
* SET TITLEBAR 'xxx'.
  PERFORM load_pgi_details.


  " <<< THÊM MỚI (SỬA LỖI): Báo cho ALV Tab 1 biết data đã thay đổi >>>
  " (Chúng ta phải refresh ở đây, ngay sau khi data được nạp)
  IF go_grid_pgi_all IS BOUND.
    CALL METHOD go_grid_pgi_all->refresh_table_display( ).
  ENDIF.
  " <<< KẾT THÚC THÊM MỚI >>

     " --- [SỬA] LOGIC KHÓA/MỞ TRƯỜNG HEADER ---
  LOOP AT SCREEN.
    IF screen-group1 = 'PG1'. " (Group cho Header Box)
      IF gv_pgi_edit_mode = abap_true.
        " === CHẾ ĐỘ CHANGE ===
        " (Hiện tại bạn chưa yêu cầu edit trường Header nào)
        screen-input = 0. " Khóa tất cả
      ELSE.
        " === CHẾ ĐỘ DISPLAY ===
        screen-input = 0. " Khóa tất cả
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
  " <<< KẾT THÚC THÊM MỚI >>>

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0301 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0301 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
  PERFORM build_alv_pgi_all.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_SUBSCREEN_0302 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_subscreen_0302 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.
*  PERFORM build_alv_pgi_proc

*    " <<< SỬA: Gọi FORM helper để fill data >>>
  PERFORM fill_processing_tab
    USING gv_current_item_idx. " (Dùng Index global)

  LOOP AT SCREEN.
    IF screen-group1 = 'PG2'. " <<< Tên Group bạn vừa gán
       " Yêu cầu: Chỉ cho edit S.Loc (LGORT)
       IF gv_pgi_edit_mode = abap_true.
         IF screen-name = 'GS_PGI_PROCESS_UI-LGORT'.
           screen-input = 1. " Mở
         ELSE.
           screen-input = 0. " Khóa
         ENDIF.
       ELSE.
         screen-input = 0. " Khóa (Display mode)
       ENDIF.
       MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
  " <<< KẾT THÚC THÊM MỚI >>>
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_0120_MODIFY_SCREEN OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_0120_modify_screen OUTPUT.
" Logic này sẽ chạy MỌI LẦN PBO (sau khi PAI báo lỗi)
  " và BẮT BUỘC mở khóa trường gv_filepath

  LOOP AT SCREEN.
    IF screen-name = 'GV_FILEPATH'. " (Tên trường I/O của bạn)
      screen-input = 1. " 1 = Mở (Enabled)
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0101 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0101 OUTPUT.
 SET PF-STATUS 'ST0101'.
 SET TITLEBAR 'T0101'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0102 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0102 OUTPUT.
 SET PF-STATUS 'ST0102'.
 SET TITLEBAR 'T0102'.

 " Call unique form for Home Center display
  PERFORM hc_display_dashboard.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module PBO_0200_SUMMARY OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE pbo_0200_summary OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.

   " Create container
  IF go_summary_container IS INITIAL.
    CREATE OBJECT go_summary_container
      EXPORTING
        container_name = 'CC_SUMMARY'.
  ENDIF.

  " Create HTML viewer
  IF go_html_viewer IS INITIAL.
    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = go_summary_container.
  ENDIF.

IF gv_data_loaded = abap_true.
  PERFORM build_html_summary.
ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0700 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0700 OUTPUT.
 SET PF-STATUS 'ST0700'.
 SET TITLEBAR 'T0700'.

  TAB_MAIN-ACTIVETAB = G_CURRSU_TAB.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0800 OUTPUT
*&---------------------------------------------------------------------*
*& REPORT MONITORING
*&---------------------------------------------------------------------*
MODULE status_0800 OUTPUT.
 SET PF-STATUS 'ST0800'.
 SET TITLEBAR 'T0800'.

 IF go_cc_report IS INITIAL.
    " 1. Map vào Custom Control 'CC_REPORT' trên Screen 0800
    CREATE OBJECT go_cc_report
      EXPORTING container_name = 'CC_REPORT'.

    " 2. Splitter
    CREATE OBJECT go_split_sd4
      EXPORTING parent  = go_cc_report
                rows    = 3
                columns = 1.

    go_split_sd4->set_row_height( id = 1 height = 12 ).
    go_split_sd4->set_row_height( id = 2 height = 40 ).

    go_c_top_sd4 = go_split_sd4->get_container( row = 1 column = 1 ).
    go_c_mid_sd4 = go_split_sd4->get_container( row = 2 column = 1 ).
    go_c_bot_sd4 = go_split_sd4->get_container( row = 3 column = 1 ).

    " 3. Lấy dữ liệu lần đầu
    PERFORM get_initial_data_sd4.
    PERFORM update_dashboard_ui_sd4.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_0802 OUTPUT
*&---------------------------------------------------------------------*
*& FILTER SEARCH DIALOG
*&---------------------------------------------------------------------*
MODULE status_0802 OUTPUT.
 SET PF-STATUS 'ST0802'.
 SET TITLEBAR 'T0802'.
ENDMODULE.
