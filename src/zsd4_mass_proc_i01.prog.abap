*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Include          ZSD4_SALES_ORDER_CENTERI01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
      LEAVE PROGRAM.
    WHEN 'EXEC_SO'.
      IF rb_single = abap_true.
        gv_upload_type = 'S'.
        CALL SCREEN 0110.  " Single Upload Screen
      ELSEIF rb_mass = abap_true.
        gv_upload_type = 'M'.
        CALL SCREEN 0120.  " Mass Upload Screen
      ELSEIF rb_status = abap_true.
        gv_management_type = 'T'.
        CALL SCREEN 0500.  " Processing Status
      ELSEIF rb_remon = abap_true.
        gv_management_type = 'R'.
        CALL SCREEN 0600.  " Report Monitoring
      ENDIF.
    WHEN OTHERS.
      MESSAGE 'Function not recognized' TYPE 'I'.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0120  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0120 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN 'PREVIEW'.

    WHEN 'DWN_TMPL'. " <<< THÊM MỚI
      PERFORM download_template .

  ENDCASE.

  CLEAR sy-ucomm. " Clear the OK code
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0110  INPUT
*&---------------------------------------------------------------------*
*       Single Upload Header Entry
*----------------------------------------------------------------------*
MODULE user_command_0110 INPUT.

  CASE sy-ucomm.
    WHEN 'CREATE_SO'.
      DATA: lv_is_valid TYPE abap_bool VALUE abap_true.
      CLEAR: gs_so_heder_ui-so_hdr_kalsm,
             gs_so_heder_ui-so_hdr_salesarea,
             gs_so_heder_ui-so_hdr_waerk,
             gs_so_heder_ui-so_hdr_zterm,
             gs_so_heder_ui-so_hdr_inco1.

      " --- 1. KIỂM TRA BẮT BUỘC: Order Type ---
      IF gs_so_heder_ui-so_hdr_auart IS INITIAL.
        lv_is_valid = abap_false.
        MESSAGE 'Sales Doc. Type is required.' TYPE 'S' DISPLAY LIKE 'E'.
        EXIT. " Lỗi này là lỗi duy nhất dừng chương trình
      ELSE.
        " Validate Order Type (nếu có nhập)
        SELECT SINGLE 'X' FROM tvak INTO @DATA(lv_x_auart)
          WHERE auart = @gs_so_heder_ui-so_hdr_auart.
        IF sy-subrc <> 0.
          lv_is_valid = abap_false.
          MESSAGE |Sales Doc. Type '{ gs_so_heder_ui-so_hdr_auart }' is not valid.| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
      ENDIF.

      " --- 2. KIỂM TRA KHÔNG BẮT BUỘC: Sales Org (Nếu có nhập) ---
      IF gs_so_heder_ui-so_hdr_vkorg IS NOT INITIAL.
        SELECT SINGLE 'X' FROM tvko INTO @DATA(lv_x_vkorg)
          WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg.
        IF sy-subrc <> 0.
          lv_is_valid = abap_false.
          MESSAGE |Sales Org. '{ gs_so_heder_ui-so_hdr_vkorg }' is not valid.| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
      ENDIF.

      " --- 3. KIỂM TRA KHÔNG BẮT BUỘC: Distr. Channel (Nếu có nhập) ---
      IF gs_so_heder_ui-so_hdr_vtweg IS NOT INITIAL.
        SELECT SINGLE 'X' FROM tvtw INTO @DATA(lv_x_vtweg)
          WHERE vtweg = @gs_so_heder_ui-so_hdr_vtweg.
        IF sy-subrc <> 0.
          lv_is_valid = abap_false.
          MESSAGE |Distr. Channel '{ gs_so_heder_ui-so_hdr_vtweg }' is not valid.| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
      ENDIF.

      " --- 4. KIỂM TRA KHÔNG BẮT BUỘC: Division (Nếu có nhập) ---
      IF gs_so_heder_ui-so_hdr_spart IS NOT INITIAL.
        SELECT SINGLE 'X' FROM tspat INTO @DATA(lv_x_spart)
          WHERE spart = @gs_so_heder_ui-so_hdr_spart.
        IF sy-subrc <> 0.
          lv_is_valid = abap_false.
          MESSAGE |Division '{ gs_so_heder_ui-so_hdr_spart }' is not valid.| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
      ENDIF.

      " --- 5. CỔNG KIỂM SOÁT (GATEKEEPER) ---
      IF lv_is_valid = abap_false.
        EXIT. " Dừng PAI, ở lại Screen 0110
      ENDIF.

      " --- 6. THÀNH CÔNG ---
      SET SCREEN 111.
      LEAVE SCREEN.

    WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
      LEAVE TO SCREEN 0.

    WHEN 'CLEAR'.
      CLEAR: gs_so_heder_ui-so_hdr_auart,
             gs_so_heder_ui-so_hdr_vkorg,
             gs_so_heder_ui-so_hdr_vtweg,
             gs_so_heder_ui-so_hdr_spart,
             gs_so_heder_ui-so_hdr_vkgrp,
             gs_so_heder_ui-so_hdr_vkbur.
      MESSAGE 'All fields cleared.' TYPE 'S'.

  ENDCASE.

ENDMODULE.


*&---------------------------------------------------------------------*
*&      Module  MOVE_SCREEN_TO_VAR  INPUT
*&---------------------------------------------------------------------*
*       Move data from screen into s_vbak
*----------------------------------------------------------------------*
MODULE move_screen_to_var INPUT.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  RESET_FLAG_ON_CHANGE  INPUT
*&---------------------------------------------------------------------*
*  Nếu user thay đổi bất kỳ trường nào, reset cờ 'gv_so_just_created'
*& để ẩn nút "Go to Monitor" và hiện lại nút "Save".
*----------------------------------------------------------------------*
MODULE reset_flag_on_change INPUT.
  " Nếu user thay đổi bất cứ gì VÀ chúng ta đang ở trạng thái "vừa save xong"
  IF gv_so_just_created = abap_true.
    CLEAR gv_so_just_created.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0111  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0111 INPUT.

  DATA: lv_ok_code TYPE sy-ucomm.
  lv_ok_code = ok_code.
  CLEAR ok_code.

  CASE lv_ok_code.
      DATA: lv_action TYPE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.

      PERFORM perform_exit_confirmation
        CHANGING
          lv_action.

      CASE lv_action.
        WHEN 'SAVE'.
          " User chọn 'Yes' -> 'Save'
          PERFORM perform_create_single_so .
          IF gv_so_just_created = abap_true.
            " <<< SỬA LỖI 2: Quay về Screen 0110 >>>
            LEAVE TO SCREEN 0110.
          ENDIF.
          " (Nếu Save lỗi, user sẽ thấy lỗi và ở lại màn hình)

        WHEN 'BACK'.
          " User chọn 'No'
          PERFORM reset_single_entry_screen .
          " <<< SỬA LỖI 1: Quay về Screen 0110 >>>
          LEAVE TO SCREEN 0110.

        WHEN 'STAY'.
          " User chọn 'Cancel' hoặc 'Edit'
          " (Không làm gì cả, ở lại Screen 0111)
      ENDCASE.

    WHEN 'SAVE'.
PERFORM perform_create_single_so.

    WHEN 'TRCK'.
      CLEAR gv_so_just_created.
      LEAVE TO SCREEN 0500.

  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0200 INPUT.
  DATA: lv_upload_mode TYPE c.

  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      gv_data_loaded = abap_false.
      LEAVE TO SCREEN 0.

    WHEN 'DWN_TMPL'.
      PERFORM download_template .

      " --- Nút UPLOAD (Duy nhất) ---
    WHEN 'UPLOAD'.
      " 1. Hiện Popup cho user chọn
      PERFORM popup_select_upload_mode CHANGING lv_upload_mode.

      " 2. Xử lý dựa trên lựa chọn
      CASE lv_upload_mode.
        WHEN 'N'. " Upload New
          PERFORM generate_request_id CHANGING gv_current_req_id.
          PERFORM perform_mass_upload USING 'NEW' gv_current_req_id.
*          PERFORM validate_staging_data USING gv_current_req_id.
*          PERFORM load_data_from_staging USING gv_current_req_id.
*          gv_data_loaded = abap_true.

        WHEN 'R'. " Resubmit
          PERFORM perform_mass_upload USING 'RESUBMIT' gv_current_req_id.
          PERFORM validate_staging_data USING gv_current_req_id.
          PERFORM load_data_from_staging USING gv_current_req_id.
          gv_data_loaded = abap_true.

        WHEN 'C'. " Resume (Your Record)
          " (Logic Resume: Load từ DB)
          PERFORM load_staging_from_db USING sy-uname.
          " (FORM này sẽ tự gán gv_current_req_id)
          " 2. Nếu tìm thấy (gv_current_req_id có dữ liệu), load chi tiết lên ALV
          IF gv_current_req_id IS NOT INITIAL.
            PERFORM load_data_from_staging USING gv_current_req_id.
            gv_data_loaded = abap_true.
          ENDIF.

        WHEN OTHERS.
          " User bấm Cancel popup -> Không làm gì cả
      ENDCASE.

    WHEN 'VALI'.
      PERFORM revalidate_data.

    WHEN 'SAVE'.
      " (Logic lưu Staging mà không validate)

    WHEN 'CREA_SO'.
      PERFORM perform_create_sales_orders.

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

*&SPWIZARD: INPUT MODULE FOR TS 'TS_VALI'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: GETS ACTIVE TAB
MODULE ts_vali_active_tab_get INPUT.
  ok_code = sy-ucomm.
  CASE ok_code.
    WHEN c_ts_vali-tab1.
      g_ts_vali-pressed_tab = c_ts_vali-tab1.
    WHEN c_ts_vali-tab2.
      g_ts_vali-pressed_tab = c_ts_vali-tab2.
    WHEN c_ts_vali-tab3.
      g_ts_vali-pressed_tab = c_ts_vali-tab3.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  F4_FOR_FILEPATH  INPUT
*&---------------------------------------------------------------------*
* Provides F4 help (file selection dialog) for the file path field
*----------------------------------------------------------------------*
MODULE f4_for_filepath INPUT.
  " Call the same form we already created!
  PERFORM open_file_dialog CHANGING gv_filepath.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0500  INPUT
*&---------------------------------------------------------------------*
*MODULE user_command_0500 INPUT.
*
*  "=========================================================
*  "===  1. XỬ LÝ SỰ KIỆN ALV & ĐỒNG BỘ HÓA
*  "=========================================================
*  " (Lấy từ Module Pool gốc)
*  " Phải gọi dispatch() TRƯỚC CASE SY-UCOMM để bắt sự kiện ALV (vd: hotspot)
*  cl_gui_cfw=>dispatch( ).
*
*  " (Lấy từ Program gốc, nhưng ĐỔI TÊN BIẾN)
*  " Phải gọi check_changed_data() TRƯỚC khi get_selected_rows
*  IF go_alv1 IS BOUND.  " <<< THAY ĐỔI: Dùng go_alv1
*    CALL METHOD go_alv1->check_changed_data. " <<< THAY ĐỔI: Dùng go_alv1
*  ENDIF.
*  "=========================================================
*
*  CASE sy-ucomm.
*
*      "=========================================================
*      " 🔍 1️⃣ LỌC CHÍNH (VÀ CẬP NHẬT MÀN HÌNH)
*      "=========================================================
*    WHEN 'SEARCH' OR 'UPD_STAT'.
*      IF cb_sosta = 'INC'.
*        CLEAR: cb_ddsta, cb_bdsta.
*      ENDIF.
*      PERFORM load_tracking_data.
*      PERFORM apply_phase_logic.
*      PERFORM filter_process_phase.
*      PERFORM filter_tracking_data.
*      PERFORM filter_delivery_status.
*      PERFORM filter_billing_status.
*      IF cb_sosta <> 'INC'.
*        PERFORM filter_pricing_procedure.
*      ENDIF.
*
*      " Refresh ALV
*      IF go_alv1 IS BOUND.  " <<< THAY ĐỔI: Dùng go_alv1
*        CALL METHOD go_alv1->refresh_table_display( ). " <<< THAY ĐỔI: Dùng go_alv1
*      ENDIF.
*
*
*      "=========================================================
*      " ⚙️ 2️⃣ CÁC NÚT ACTIONS
*      "=========================================================
*      " HỢP NHẤT: Bao gồm UCOMM từ cả 2 file để đảm bảo bắt đúng
*    WHEN 'POST_PGI' OR 'REVERSE_PGI' OR 'REVERSE_GI'
*      OR 'CANCEL_BILL' OR 'CREATE_BILL' OR 'CREATE_BILLING'.
*
*      " --- Bắt đầu code logic actions từ program gốc ---
*      DATA: lt_selected_rows TYPE lvc_t_row,
*            ls_selected_row  TYPE lvc_s_row.
**            lv_count         TYPE i.
*      FIELD-SYMBOLS: <fs_tracking> TYPE ty_tracking.
*
*      DATA: lv_last_msg     TYPE string.
*      DATA: lv_last_msg_typ TYPE c.
*
*      lv_count = 0.
*
*      " 1. LẤY DANH SÁCH DÒNG ĐÃ CHỌN (BẰNG CHECKBOX)
*      " Phải check BOUND trước khi gọi
*      IF go_alv1 IS NOT BOUND. " <<< THAY ĐỔI: Dùng go_alv1
*        MESSAGE 'Lỗi: ALV object GO_ALV1 chưa được tạo.' TYPE 'E'.
*        EXIT. " Thoát khỏi PAI
*      ENDIF.
*
*      " <<< THAY ĐỔI: Dùng go_alv1
*      CALL METHOD go_alv1->get_selected_rows
*        IMPORTING
*          et_index_rows = lt_selected_rows.
*
*      " 2. LẶP QUA CÁC DÒNG ĐÃ TICK
*      LOOP AT lt_selected_rows INTO ls_selected_row.
*        READ TABLE gt_tracking ASSIGNING <fs_tracking>
*                           INDEX ls_selected_row-index.
*        IF sy-subrc <> 0. CONTINUE. ENDIF.
*
*        lv_count = lv_count + 1.
*
*        " 3. THỰC THI ACTION
*        CASE sy-ucomm.
*          WHEN 'POST_PGI'.
*            PERFORM process_post_goods_issue
*              USING <fs_tracking> CHANGING <fs_tracking>.
*
*            " HỢP NHẤT: Cả hai UCOMM cùng chạy 1 logic
*          WHEN 'CREATE_BILL' OR 'CREATE_BILLING'.
*            PERFORM process_create_billing
*              USING <fs_tracking> CHANGING <fs_tracking>.
*
*            " HỢP NHẤT: Cả hai UCOMM cùng chạy 1 logic
*          WHEN 'REVERSE_PGI' OR 'REVERSE_GI'.
*            PERFORM process_reverse_pgi
*              USING <fs_tracking> CHANGING <fs_tracking>.
*
*          WHEN 'CANCEL_BILL'.
*            PERFORM process_cancel_billing
*              USING <fs_tracking> CHANGING <fs_tracking>.
*        ENDCASE.
*
*        " 4. THU HOẠCH KẾT QUẢ (lưu message cuối)
*        lv_last_msg = <fs_tracking>-error_msg.
*        IF <fs_tracking>-error_msg CS 'LỖI' OR
*           <fs_tracking>-error_msg CS 'ERROR' OR
*           <fs_tracking>-error_msg CS 'thất bại'.
*          lv_last_msg_typ = 'E'.
*        ELSE.
*          lv_last_msg_typ = 'S'.
*        ENDIF.
*
*      ENDLOOP.
*
*      " 5. KIỂM TRA VÀ HIỂN THỊ KẾT QUẢ
*      IF lv_count > 0.
*        MESSAGE '' TYPE 'S'. " Xóa message cũ
*
*        IF lv_count = 1.
*          IF lv_last_msg_typ = 'S'.
*            MESSAGE lv_last_msg TYPE 'S'.
*          ELSE.
*            MESSAGE lv_last_msg TYPE 'S' DISPLAY LIKE 'E'.
*          ENDIF.
*        ELSE.
*          MESSAGE |Đã xử lý { lv_count } dòng.| TYPE 'S'.
*        ENDIF.
*
*        PERFORM apply_phase_logic.
*
*        " Refresh (đã check BOUND ở trên)
*        " <<< THAY ĐỔI: Dùng go_alv1
*        CALL METHOD go_alv1->refresh_table_display( ).
*
*      ELSE.
*        MESSAGE 'Bạn vui lòng tick ít nhất một dòng (checkbox) để xử lý.' TYPE 'S' DISPLAY LIKE 'E'.
*        " <<< THAY ĐỔI: XÓA 'LEAVE LIST-PROCESSING'
*        " Lệnh này không dùng trong Module Pool
*      ENDIF.
*      " --- Kết thúc code logic actions từ program gốc ---
*
*
*      "=========================================================
*      " 🚪 3️⃣ THOÁT (Sử dụng logic của Module Pool)
*      "=========================================================
*    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
*      " <<< THAY ĐỔI: Dùng LEAVE TO SCREEN 0
*      " Lệnh này sẽ quay về màn hình trước đó (thường là menu chính)
*      " KHÔNG DÙNG 'LEAVE PROGRAM' (vì sẽ thoát toàn bộ T-Code)
*      LEAVE TO SCREEN 0.
*  ENDCASE.
*
*ENDMODULE.
*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0500 INPUT
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0500 INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0500 INPUT.

  " =========================================================
  " 1. KHAI BÁO BIẾN (GỘP CHUNG Ở ĐẦU ĐỂ TRÁNH LỖI TRÙNG LẶP)
  " =========================================================
  DATA: lt_selected_rows TYPE lvc_t_row,
        ls_selected_row  TYPE lvc_s_row,
*        lv_count         TYPE i,
        lv_last_msg      TYPE string,
        lv_last_msg_typ  TYPE c.
  FIELD-SYMBOLS: <fs_tracking> TYPE ty_tracking.

  " =========================================================
  " 2. ĐỒNG BỘ DỮ LIỆU TỪ ALV XUỐNG CHƯƠNG TRÌNH
  " =========================================================
  cl_gui_cfw=>dispatch( ).

  IF go_alv1 IS BOUND.
    CALL METHOD go_alv1->check_changed_data.
  ENDIF.

  " =========================================================
  " 3. XỬ LÝ SỰ KIỆN NGƯỜI DÙNG
  " =========================================================
  CASE sy-ucomm.

    " -------------------------------------------------------
    " 🔍 NHÓM 1: TÌM KIẾM & LÀM MỚI
    " -------------------------------------------------------
    WHEN 'SEARCH' OR 'UPD_STAT'.
      IF cb_sosta = 'INC'.
        CLEAR: cb_ddsta, cb_bdsta.
      ENDIF.

      " Quy trình nạp lại dữ liệu chuẩn:
      PERFORM load_tracking_data.       " Đọc DB
      PERFORM apply_phase_logic.        " Tính toán Phase/Icon
      PERFORM filter_process_phase.     " Lọc Phase
      PERFORM filter_tracking_data.     " Lọc Status SO
      PERFORM filter_delivery_status.   " Lọc Delivery
      PERFORM filter_billing_status.    " Lọc Billing
      IF cb_sosta <> 'INC'.
        PERFORM filter_pricing_procedure.
      ENDIF.

      " Vẽ lại ALV
      IF go_alv1 IS BOUND.
        CALL METHOD go_alv1->refresh_table_display( ).
      ENDIF.

    " -------------------------------------------------------
    " 📅 NHÓM 2: QUẢN LÝ JOB BACKGROUND
    " -------------------------------------------------------
    WHEN 'SET_JOB'.
      PERFORM setup_job_schedule.

    WHEN 'JOB_MON'.
      PERFORM show_job_monitor_popup.

    " -------------------------------------------------------
    " ⚙️ NHÓM 3: CÁC NÚT THAO TÁC NGHIỆP VỤ (QUAN TRỌNG)
    " -------------------------------------------------------
    WHEN 'POST_PGI' OR 'REVERSE_PGI' OR 'REVERSE_GI'
      OR 'CANCEL_BILL' OR 'CREATE_BILL' OR 'CREATE_BILLING'
      OR 'REL_ACC'.

      lv_count = 0.

      " A. Lấy danh sách các dòng được chọn
      IF go_alv1 IS BOUND.
        CALL METHOD go_alv1->get_selected_rows
          IMPORTING
            et_index_rows = lt_selected_rows.
      ENDIF.

      " B. Lặp qua từng dòng để xử lý
      LOOP AT lt_selected_rows INTO ls_selected_row.
        READ TABLE gt_tracking ASSIGNING <fs_tracking>
                               INDEX ls_selected_row-index.
        IF sy-subrc <> 0. CONTINUE. ENDIF.

        lv_count = lv_count + 1.

        " C. Gọi FORM xử lý tương ứng
        CASE sy-ucomm.
          WHEN 'POST_PGI'.
            PERFORM process_post_goods_issue
              USING <fs_tracking> CHANGING <fs_tracking>.

          WHEN 'CREATE_BILL' OR 'CREATE_BILLING'.
            PERFORM process_create_billing
              USING <fs_tracking> CHANGING <fs_tracking>.

          WHEN 'REVERSE_PGI' OR 'REVERSE_GI'.
            PERFORM process_reverse_pgi
              USING <fs_tracking> CHANGING <fs_tracking>.

          WHEN 'CANCEL_BILL'.
            PERFORM process_cancel_billing
              USING <fs_tracking> CHANGING <fs_tracking>.

          WHEN 'REL_ACC'.
            PERFORM process_release_to_account
              USING <fs_tracking> CHANGING <fs_tracking>.
        ENDCASE.

        " D. Lưu lại thông báo lỗi cuối cùng để hiển thị
        lv_last_msg = <fs_tracking>-error_msg.
        IF <fs_tracking>-error_msg CS 'LỖI' OR
           <fs_tracking>-error_msg CS 'ERROR' OR
           <fs_tracking>-error_msg CS 'thất bại' OR
           <fs_tracking>-error_msg CS 'Failed'.
          lv_last_msg_typ = 'E'.
        ELSE.
          lv_last_msg_typ = 'S'.
        ENDIF.
      ENDLOOP.

      " E. Hiển thị kết quả & Làm mới màn hình
      IF lv_count > 0.
        MESSAGE '' TYPE 'S'. " Xóa thông báo cũ trên thanh status

        " Hiển thị thông báo kết quả
        IF lv_count = 1.
          IF lv_last_msg_typ = 'S'.
            MESSAGE lv_last_msg TYPE 'S'.
          ELSE.
            MESSAGE lv_last_msg TYPE 'S' DISPLAY LIKE 'E'.
          ENDIF.
        ELSE.
          MESSAGE |Đã xử lý { lv_count } dòng.| TYPE 'S'.
        ENDIF.

        " [QUAN TRỌNG] Nạp lại dữ liệu để cập nhật trạng thái mới (số hóa đơn, PGI...)
        PERFORM load_tracking_data.
        PERFORM apply_phase_logic.
        PERFORM filter_process_phase.
        PERFORM filter_tracking_data.
        PERFORM filter_delivery_status.
        PERFORM filter_billing_status.
        IF cb_sosta <> 'INC'.
          PERFORM filter_pricing_procedure.
        ENDIF.

        " Refresh Grid
        IF go_alv1 IS BOUND.
          CALL METHOD go_alv1->refresh_table_display( ).
        ENDIF.

      ELSE.
        MESSAGE 'Bạn vui lòng tick ít nhất một dòng (checkbox) để xử lý.' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.

    " -------------------------------------------------------
    " 🚪 NHÓM 4: THOÁT
    " -------------------------------------------------------
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.

  ENDCASE.

ENDMODULE.
"=========================================================
" CÁC MODULE F4 HELP (Sao chép nguyên bản từ program gốc)
" Đặt các module này bên ngoài MODULE user_command_0500
"=========================================================
MODULE f4_for_vbeln.
  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      tabname     = 'VBAK'
      fieldname   = 'VBELN'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'GV_VBELN'
    EXCEPTIONS
      OTHERS      = 1.
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
ENDMODULE.

*MODULE f4_for_vkorg.
*  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
*    EXPORTING
*      tabname     = 'VBAK'
*      fieldname   = 'VKORG'
*      dynpprog    = sy-repid
*      dynpnr      = sy-dynnr
*      dynprofield = 'GV_VKORG'
*    EXCEPTIONS
*      OTHERS      = 1.
*ENDMODULE.
*
*MODULE f4_for_vtweg.
*  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
*    EXPORTING
*      tabname     = 'VBAK'
*      fieldname   = 'VTWEG'
*      dynpprog    = sy-repid
*      dynpnr      = sy-dynnr
*      dynprofield = 'GV_VTWEG'
*    EXCEPTIONS
*      OTHERS      = 1.
*ENDMODULE.
*
*MODULE f4_for_spart.
*  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
*    EXPORTING
*      tabname     = 'VBAK'
*      fieldname   = 'SPART'
*      dynpprog    = sy-repid
*      dynpnr      = sy-dynnr
*      dynprofield = 'GV_SPART'
*    EXCEPTIONS
*      OTHERS      = 1.
*ENDMODULE.

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
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0112  INPUT
*&---------------------------------------------------------------------*
*  Module này rất quan trọng để ALV events (data_changed, toolbar) hoạt động
*----------------------------------------------------------------------*
MODULE pai_subscreen_0112 INPUT.
  " Dispatch các sự kiện ALV (ví dụ: nhấn Enter, nhấn &ADD...)
  " đến class lcl_event_handler
  cl_gui_cfw=>dispatch( ).

  " 2. [THÊM MỚI] Kích hoạt sự kiện DATA CHANGED (khi Enter/chuyển ô)
  "    Đây là dòng code bị thiếu trong PAI của bạn.
  IF go_grid_item_single IS BOUND.
    CALL METHOD go_grid_item_single->check_changed_data.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_HANDLE_DATA_TRANSFER  INPUT
*&---------------------------------------------------------------------*
*     Luôn chạy để validate dữ liệu header và auto-fill
*----------------------------------------------------------------------*
MODULE pai_handle_data_transfer INPUT.
  " Chỉ chạy nếu không phải là lệnh thoát
  CHECK sy-ucomm <> 'BACK' AND sy-ucomm <> 'EXIT' AND sy-ucomm <> 'CANC'.

  PERFORM pai_auto_populate.
  PERFORM pai_validate_input. " Validate các trường bắt buộc
  PERFORM pai_derive_data.    " Validate Sold-to, auto-fill, set gv_screen_state
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form load_tips
*&---------------------------------------------------------------------*
*& QUICK TIPS in SCREEN 0100 PBO
*&---------------------------------------------------------------------*
FORM load_tips .
  CLEAR lt_tips.

  APPEND '💡 Use F4 to search for customers or materials.'             TO lt_tips.
  APPEND '💡 Press F1 on any field to view help instantly.'           TO lt_tips.
  APPEND '💡 Use VA03 to check document flow after order creation.'  TO lt_tips.
  APPEND '💡 Mass upload saves time with large orders.'              TO lt_tips.
  APPEND '💡 Always verify partner functions before saving SO.'      TO lt_tips.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0600  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0600 INPUT.

  " Xử lý ALV events (nếu có)
  cl_gui_cfw=>dispatch( ).

  CASE sy-ucomm.

    WHEN 'BACK'.
      " Quay lại màn hình trước đó (nếu có)
      gv_monitor_first_load = abap_true. " <<< RESET CỜ KHI THOÁT
      LEAVE TO SCREEN 0.

    WHEN 'CANCEL' OR 'EXIT'.
      " Thoát hẳn chương trình
      LEAVE PROGRAM.

    WHEN 'BTN_GO' OR 'BTN_RESET'. " Nút 'Go' (Filter) hoặc 'Refresh'
      PERFORM load_monitoring_data .
      " Refresh lại grid
      IF go_grid_monitoring IS BOUND.
        go_grid_monitoring->refresh_table_display( ).
      ENDIF.

  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0113  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_subscreen_0113 INPUT.

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

*&SPWIZARD: INPUT MODULE FOR TS 'TS_BILLING'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: GETS ACTIVE TAB
MODULE ts_billing_active_tab_get INPUT.
  ok_code = sy-ucomm.
  CASE ok_code.
    WHEN c_ts_billing-tab1.
      g_ts_billing-pressed_tab = c_ts_billing-tab1.
    WHEN c_ts_billing-tab2.
      g_ts_billing-pressed_tab = c_ts_billing-tab2.
    WHEN OTHERS.
*&SPWIZARD:      DO NOTHING
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SCREEN_0300_EXIT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_screen_0300_exit INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0. " Quay về màn hình Home
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SCREEN_0300_USER  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_screen_0300_user INPUT.
  ok_code = sy-ucomm.
  CASE ok_code.
    WHEN 'DELE'.
      " (Logic Delete)
    WHEN 'CHNG'.
      PERFORM toggle_pgi_edit_mode .
    WHEN 'FLW'.
      " (Logic Document Flow)
    WHEN 'PGI'.
      PERFORM perform_post_goods_issue .
  ENDCASE.
  CLEAR ok_code.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0301  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_subscreen_0301 INPUT.
  cl_gui_cfw=>dispatch( ).
  IF go_grid_pgi_all IS BOUND.
    go_grid_pgi_all->check_changed_data( ).
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  PAI_SUBSCREEN_0302  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_subscreen_0302 INPUT.
*  cl_gui_cfw=>dispatch( ).
*  IF go_grid_pgi_proc IS BOUND.
*    go_grid_pgi_proc->check_changed_data( ).
*  ENDIF.

  " <<< SỬA: Đổi tên biến để tránh trùng lặp >>>
  DATA lv_max_pgi_items TYPE i.
  DESCRIBE TABLE gt_pgi_all_items LINES lv_max_pgi_items.
  IF lv_max_pgi_items = 0.
    lv_max_pgi_items = 1.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'BTN_FIRST'.
      gv_current_item_idx = 1.
    WHEN 'BTN_LEFT'.
      IF gv_current_item_idx > 1.
        gv_current_item_idx = gv_current_item_idx - 1.
      ELSE.
        MESSAGE 'Already at the first item.' TYPE 'S'.
      ENDIF.
    WHEN 'BTN_NEXT'.
      IF gv_current_item_idx < lv_max_pgi_items. " <<< SỬA
        gv_current_item_idx = gv_current_item_idx + 1.
      ELSE.
        MESSAGE 'There are no more items to be displayed' TYPE 'S'.
      ENDIF.
    WHEN 'BTN_LAST'.
      gv_current_item_idx = lv_max_pgi_items. " <<< SỬA
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0102  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0102 INPUT.
  DATA: lv_choice TYPE c.
  DATA(lv_ucomm) = ok_code.
  CLEAR ok_code.

  CASE sy-ucomm.
      " --- 1. MANAGE SALES ORDER ---
    WHEN 'MAN_SO'.
      PERFORM popup_select_so_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Create Single Order
          CALL SCREEN 0110.
        WHEN '2'. " Mass Upload Orders
          CALL SCREEN 0211. " (Screen test của bạn)
        WHEN '3'. " Search & Process
          MESSAGE 'Chức năng đang phát triển (Search & Process SO).' TYPE 'S'.
      ENDCASE.

      " --- 2. MANAGE DELIVERY ---
    WHEN 'MAN_DLV'.
      MESSAGE 'Chức năng đang phát triển (Manage Delivery).' TYPE 'S'.

      " --- 3. MANAGE BILLING ---
    WHEN 'MAN_BIL'.
      PERFORM popup_select_billing_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Create Single Billing
          MESSAGE 'Chức năng đang phát triển (Create Billing).' TYPE 'S'.
        WHEN '2'. " Search & Process
          MESSAGE 'Chức năng đang phát triển (Search Billing).' TYPE 'S'.
      ENDCASE.

      " --- 4. OVERVIEW ---
    WHEN 'OVERVIEW'.
      PERFORM popup_select_overview_action CHANGING lv_choice.
      CASE lv_choice.
        WHEN '1'. " Track Sales Order
          CALL SCREEN 0500.
        WHEN '2'. " Report Monitoring
          CALL SCREEN 0800.
        WHEN '3'. " Change Log
          MESSAGE 'Chức năng đang phát triển (Change Log).' TYPE 'S'.
      ENDCASE.

      " --- THOÁT ---
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

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0700  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0700 INPUT.
  CASE sy-ucomm.

    WHEN 'FITEM'.
      g_currsu_tab = 'FITEM'.
    WHEN 'FSHIP'.
      g_currsu_tab = 'FSHIP'.
    WHEN 'FCOND'.
      g_currsu_tab = 'FCOND'.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN OTHERS.

  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0800  INPUT
*&---------------------------------------------------------------------*
*       REPORT MONITORING
*----------------------------------------------------------------------*
MODULE user_command_0800 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      " Giải phóng bộ nhớ (Optional nhưng tốt)
      IF go_html_kpi_sd4 IS BOUND. go_html_kpi_sd4->free( ). ENDIF.
      IF go_html_cht_sd4 IS BOUND. go_html_cht_sd4->free( ). ENDIF.
      IF go_alv_sd4      IS BOUND. go_alv_sd4->free( ). ENDIF.
      IF go_cc_report    IS BOUND. go_cc_report->free( ). ENDIF.
      LEAVE TO SCREEN 0.

    WHEN 'SEARCH'.
      CLEAR gv_exec_srch_sd4.
      " Gọi Popup 0802 (Popup này chứa Subscreen 0801)
      CALL SCREEN 0802 STARTING AT 10 5 ENDING AT 105 25.

      " Xử lý sau khi đóng Popup
      IF gv_exec_srch_sd4 = 'X'.
        PERFORM get_filtered_data_sd4.
        PERFORM update_dashboard_ui_sd4.
      ENDIF.

    WHEN 'REFRESH'.
      PERFORM get_initial_data_sd4.
      PERFORM update_dashboard_ui_sd4.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0802  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0802 INPUT.
CASE sy-ucomm.
    WHEN 'EXECUTE'.
      gv_exec_srch_sd4 = 'X'.
      LEAVE TO SCREEN 0.
    WHEN 'CANCEL' OR 'CLOSE'.
      CLEAR gv_exec_srch_sd4.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.
