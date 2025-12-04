*&---------------------------------------------------------------------*
*& Include          ZSD4_SALES_ORDER_CENTERF00
*&---------------------------------------------------------------------*

"--------------------------------THANGNB CODE TRANSFER----------------------------------
"------------------------------------CLASS IMPLEMENTATION---------------------------------
CLASS lcl_event_handler IMPLEMENTATION.
  METHOD constructor.
    mo_grid  = io_grid.
    mt_table = it_table.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN '&DEL'.
        DATA: lt_rows   TYPE lvc_t_row,
              ls_row    TYPE lvc_s_row,
              lv_answer TYPE c.
        FIELD-SYMBOLS: <table>    TYPE STANDARD TABLE,
                       <any_line> TYPE any.

        CALL METHOD mo_grid->get_selected_rows
          IMPORTING
            et_index_rows = lt_rows.
        CHECK lt_rows IS NOT INITIAL.

        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = 'Confirm Deletion'
            text_question         = 'Do you really want to delete selected rows?'
            text_button_1         = 'Yes'
            text_button_2         = 'No'
            default_button        = '2'
            display_cancel_button = ''
          IMPORTING
            answer                = lv_answer.
        CHECK lv_answer = '1'.

        ASSIGN mt_table->* TO <table>.
        CHECK <table> IS ASSIGNED.

        LOOP AT lt_rows INTO ls_row FROM lines( lt_rows ) TO 1 STEP -1.
          READ TABLE <table> INDEX ls_row-index ASSIGNING <any_line>.
          IF sy-subrc = 0.
            DELETE <table> INDEX ls_row-index.
          ENDIF.
        ENDLOOP.

        " <<< THÊM 2 DÒNG NÀY ĐỂ CẬP NHẬT TIÊU ĐỀ >>>
        DATA(lv_entry_del) = lines( <table> ).
        mo_grid->set_gridtitle( |Item Details (Single Entry) ({ lv_entry_del } rows)| ).

        CALL METHOD mo_grid->refresh_table_display.

      WHEN '&ADD'.
        FIELD-SYMBOLS: <new_line> TYPE any.
        ASSIGN mt_table->* TO <table>.
        CHECK <table> IS ASSIGNED.
        APPEND INITIAL LINE TO <table> ASSIGNING <new_line>.

        " <<< THÊM 2 DÒNG NÀY ĐỂ CẬP NHẬT TIÊU ĐỀ >>>
        DATA(lv_entry_add) = lines( <table> ).
        mo_grid->set_gridtitle( |Item Details (Single Entry) ({ lv_entry_add } rows)| ).

        CALL METHOD mo_grid->refresh_table_display.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_toolbar.
    DATA: ls_button TYPE stb_button.
    IF gs_edit <> 'X'.
      RETURN.
    ENDIF.
    CLEAR ls_button.
    ls_button-function   = '&DEL'.
    ls_button-icon       = icon_delete_row.
    ls_button-quickinfo  = 'Delete Selected Row(s)'.
    ls_button-text       = 'Delete'.
    ls_button-butn_type  = '0'.
    APPEND ls_button TO e_object->mt_toolbar.

    CLEAR ls_button.
    ls_button-function   = '&ADD'.
    ls_button-icon       = icon_insert_row.
    ls_button-quickinfo  = 'Add New Row'.
    ls_button-text       = 'Add'.
    ls_button-butn_type  = '0'.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

*METHOD handle_data_changed.
*
*    DATA: ls_mod_cell TYPE lvc_s_modi,
*          lv_qty_temp TYPE kwmeng.
*
*    FIELD-SYMBOLS: <ls_item> TYPE ty_item_details,
*                   <lv_field_data> TYPE any.
*
*    " 1. Duyệt qua các ô vừa nhập
*    LOOP AT er_data_changed->mt_good_cells INTO ls_mod_cell.
*
*      CASE ls_mod_cell-fieldname.
*        WHEN 'TARGET_QTY' OR 'KWMENG' OR 'MENGE' OR 'ZMENG'.
*
*          READ TABLE gt_item_details ASSIGNING <ls_item> INDEX ls_mod_cell-row_id.
*          IF sy-subrc = 0.
*            " Ép kiểu và Gán giá trị
*            lv_qty_temp = ls_mod_cell-value.
*            ASSIGN COMPONENT ls_mod_cell-fieldname OF STRUCTURE <ls_item> TO <lv_field_data>.
*            IF sy-subrc = 0.
*              <lv_field_data> = lv_qty_temp.
*            ENDIF.
*
*            " Logic đổi màu
*            IF lv_qty_temp > 0.
*               <ls_item>-icon        = icon_led_green.
*               <ls_item>-status_text = 'OK'.
*               <ls_item>-message     = space.
*            ELSE.
*               <ls_item>-icon        = icon_led_red.
*               <ls_item>-status_text = 'Input Qty'.
*            ENDIF.
*          ENDIF.
*
*      ENDCASE.
*    ENDLOOP.
*
*    " 2. Tính toán lại giá (Simulate)
*    " [SỬA TẠI ĐÂY]: Xóa 'USING er_data_changed' vì FORM không cần tham số này nữa
*    PERFORM perform_single_item_simulate.
*
*    " 3. Vẽ lại màn hình
*    IF go_grid_item_single IS NOT INITIAL.
*      CALL METHOD go_grid_item_single->refresh_table_display
*        EXPORTING
*          is_stable = VALUE #( row = 'X' col = 'X' ).
*    ENDIF.
*
*  ENDMETHOD.
METHOD handle_data_changed.
  DATA: ls_mod_cell TYPE lvc_s_modi,
        lv_qty      TYPE kwmeng.

  FIELD-SYMBOLS: <ls_cond> TYPE ty_cond_alv,      " Structure ALV Condition
                 <ls_item> TYPE ty_item_details.  " Structure Item Detail

  LOOP AT er_data_changed->mt_good_cells INTO ls_mod_cell.
    CASE ls_mod_cell-fieldname.

      " --- XỬ LÝ KHI NHẬP AMOUNT (KBETR) ---
      " Kiểm tra fieldcat xem tên trường là 'KBETR' hay 'AMOUNT' để sửa lại cho khớp
      WHEN 'KBETR' OR 'AMOUNT'.

        " 1. Cập nhật giá trị vào bảng nội bộ
        " Lưu ý: Cần đảm bảo gt_conditions_alv là biến global chứa dữ liệu đang hiển thị
        READ TABLE gt_conditions_alv ASSIGNING <ls_cond> INDEX ls_mod_cell-row_id.

        IF sy-subrc = 0.
           " Cập nhật Amount mới từ ô vừa nhập
           <ls_cond>-amount = ls_mod_cell-value.

           " A. Lấy số lượng của Item hiện tại để tính toán
           " Biến gv_current_item_idx phải là index của item đang được chọn bên ngoài
           READ TABLE gt_item_details ASSIGNING <ls_item> INDEX gv_current_item_idx.
           IF sy-subrc = 0.
              lv_qty = <ls_item>-quantity.
           ELSE.
              lv_qty = 1.  " Default nếu ko tìm thấy
           ENDIF.

           " B. Tính toán Condition Value (KWERT) = Đơn giá * Số lượng
           <ls_cond>-cond_value = <ls_cond>-amount * lv_qty.

           " --- LOGIC QUAN TRỌNG: ĐỔI MÀU ĐÈN ---
           " Chỉ cần có Amount khác 0 là chuyển Xanh
           IF <ls_cond>-amount IS NOT INITIAL.
              <ls_cond>-icon        = icon_led_green.  " Đèn Xanh
              <ls_cond>-status_text = 'OK'.

              " Tự động điền Currency nếu thiếu (Logic giống VA01)
              IF <ls_cond>-waers IS INITIAL.
                <ls_cond>-waers = 'VND'.
              ENDIF.

              " Tự động điền Condition Type mặc định nếu thiếu
              IF <ls_cond>-kschl IS INITIAL.
                <ls_cond>-kschl = 'PR00'.
              ENDIF.
           ELSE.
              " Nếu xóa Amount -> Về lại màu đỏ (hoặc xám tùy logic)
              <ls_cond>-icon = icon_led_red.
              <ls_cond>-cond_value = 0.
           ENDIF.

           " C. Refresh lại màn hình ngay lập tức để user thấy đèn xanh và số tiền nhảy
           IF go_grid_conditions IS BOUND.
             CALL METHOD go_grid_conditions->refresh_table_display
                EXPORTING is_stable = VALUE #( row = 'X' col = 'X' ).
           ENDIF.
        ENDIF.

    ENDCASE.
  ENDLOOP.
ENDMETHOD.
*  METHOD handle_data_changed.
*    DATA: ls_mod_cell TYPE lvc_s_modi.
*
*    DATA: lv_qty      TYPE kwmeng.
*
*    FIELD-SYMBOLS: <ls_cond> TYPE ty_cond_alv, " Structure ALV Condition của bạn
*                   <ls_item> TYPE ty_item_details.
*
*    " Duyệt qua các ô vừa thay đổi
*    LOOP AT er_data_changed->mt_good_cells INTO ls_mod_cell.
*
*      " =========================================================
*      " CASE 1: SINGLE ENTRY (Logic Mô phỏng giá, đổi màu đèn)
*      " =========================================================
*      IF mo_grid = go_grid_item_single OR mo_grid = go_grid_conditions.
*         " (Giữ nguyên logic cũ của bạn: Tính toán Cond Value, đổi màu đèn...)
*         " ... [Paste lại code cũ của bạn vào đây] ...
*        CASE ls_mod_cell-fieldname.
*
*      " --- XỬ LÝ KHI NHẬP AMOUNT (KBETR) ---
*      WHEN 'KBETR' OR 'AMOUNT'. " (Check tên trường trong Fieldcat của bạn)
*
*        " 1. Cập nhật giá trị vào bảng nội bộ
*        READ TABLE gt_conditions_alv ASSIGNING <ls_cond> INDEX ls_mod_cell-row_id.
*        IF sy-subrc = 0.
*           <ls_cond>-amount = ls_mod_cell-value. " Cập nhật Amount mới
*
*           " --- LOGIC GIỐNG VA01: TÍNH TOÁN CONDITION VALUE ---
*           " Công thức: Cond Value = Amount * Quantity (Của Item đang chọn)
*
*           " A. Lấy số lượng của Item hiện tại
*           READ TABLE gt_item_details ASSIGNING <ls_item> INDEX gv_current_item_idx.
*           IF sy-subrc = 0.
*              lv_qty = <ls_item>-quantity.
*           ELSE.
*              lv_qty = 1. " Default nếu ko tìm thấy
*           ENDIF.
*
*           " B. Tính toán Condition Value (KWERT)
*           <ls_cond>-cond_value = <ls_cond>-amount * lv_qty.
*
*           " --- LOGIC GIỐNG VA01: ĐỔI MÀU ĐÈN ---
*           " Chỉ cần có Amount là Xanh
*           IF <ls_cond>-amount IS NOT INITIAL.
*              <ls_cond>-icon        = icon_led_green. " Đèn Xanh
*              <ls_cond>-status_text = 'OK'.
*
*              " Tự điền Currency nếu thiếu (như VA01)
*              IF <ls_cond>-waers IS INITIAL. <ls_cond>-waers = 'VND'. ENDIF.
*              " Tự điền Cond Type nếu thiếu
*              IF <ls_cond>-kschl IS INITIAL. <ls_cond>-kschl = 'PR00'. ENDIF.
*           ELSE.
*              " Xóa Amount -> Về lại màu xám hoặc đỏ
*              <ls_cond>-icon = icon_led_red.
*              <ls_cond>-cond_value = 0.
*           ENDIF.
*
*           " C. [QUAN TRỌNG] Đẩy giá trị Cond Value mới tính ra màn hình ngay lập tức
*           " (Nếu không có đoạn này, người dùng phải Refresh mới thấy số nhảy)
*           CALL METHOD go_grid_conditions->refresh_table_display
*              EXPORTING is_stable = VALUE #( row = 'X' col = 'X' ).
*
*        ENDIF.
*
*    ENDCASE.
*      ENDIF.
*
*      " =========================================================
*      " CASE 2: MASS UPLOAD (Validated & Failed) - Logic Sửa Lỗi
*      " =========================================================
*      IF mo_grid = go_grid_hdr_val  OR mo_grid = go_grid_hdr_fail OR
*         mo_grid = go_grid_itm_val  OR mo_grid = go_grid_itm_fail OR
*         mo_grid = go_grid_cnd_val  OR mo_grid = go_grid_cnd_fail.
*
*         " Nhiệm vụ: Chỉ cần đảm bảo dữ liệu được đẩy vào bảng nội bộ
*         " (Việc này ALV tự làm khá tốt, nhưng ta có thể thêm logic validate sơ bộ ở đây nếu muốn)
*         " Hiện tại: Để trống, chờ sự kiện Finished để xử lý sau.
*      ENDIF.
*
*    ENDLOOP.
*
*    " Refresh nếu cần (Thường không cần refresh ở bước này cho Mass Upload)
*  ENDMETHOD.

METHOD HANDLE_DATA_CHANGED_FINISHED.
    " Kiểm tra xem ALV nào đã gọi sự kiện này
    IF mo_grid = go_grid_item_single.
      " --- ALV Item Details (Screen 0112) đã thay đổi ---
      PERFORM perform_single_item_simulate .

      IF mo_grid IS BOUND.
        mo_grid->refresh_table_display( ).
      ENDIF.

      FIELD-SYMBOLS: <table> TYPE STANDARD TABLE.
      ASSIGN mt_table->* TO <table>.
      IF <table> IS ASSIGNED.
        DATA(lv_entry_fin) = lines( <table> ).
        mo_grid->set_gridtitle( |Item Details (Single Entry) ({ lv_entry_fin } rows)| ).
      ENDIF.

    ELSEIF mo_grid = go_grid_conditions.
      " --- ALV Conditions (Screen 0113) đã thay đổi ---
      FIELD-SYMBOLS: <fs_item>     TYPE ty_item_details,
                     <fs_cond_alv> TYPE ty_cond_alv.

      " 1. Đọc item chính (ví dụ: Item 1) đang được hiển thị
      READ TABLE gt_item_details ASSIGNING <fs_item> INDEX gv_current_item_idx.
      IF sy-subrc <> 0.
        EXIT. " Không tìm thấy item, thoát
      ENDIF.

        LOOP AT gt_conditions_alv ASSIGNING <fs_cond_alv>
          WHERE amount IS NOT INITIAL. " Chỉ lấy dòng user nhập/thay đổi

        " 3. LƯU giá trị thủ công này vào "bộ nhớ" (bảng item chính)
        " <<< SỬA: XÓA 'IF ... = ZPRQ' VÀ DÙNG LOGIC CHUNG >>>
        " (Không lưu Subtotal hoặc Tax)
        IF <fs_cond_alv>-kschl <> 'MWST' AND <fs_cond_alv>-kschl <> 'NETW'
           AND <fs_cond_alv>-kschl <> 'GRWR'. " (Và các Subtotal khác)

          <fs_item>-cond_type  = <fs_cond_alv>-kschl.  " Lưu 'ZPT0'
          <fs_item>-unit_price = <fs_cond_alv>-amount. " Lưu '200'
          <fs_item>-currency    = <fs_cond_alv>-waers. " Lưu 'VND'
          EXIT. " Chỉ lấy 1 giá trị thủ công đầu tiên
        ENDIF.
        " <<< KẾT THÚC SỬA >>>
      ENDLOOP.

      " 4. [SỬA] Gọi lại PBO (FORM display...) để TÍNH TOÁN LẠI
      "    (Thay vì chỉ gọi 'refresh_table_display')
      PERFORM display_conditions_for_item
        USING gv_current_item_idx.
    ENDIF.
  ENDMETHOD.

*  METHOD handle_data_changed_finished.
*
*    " =========================================================
*    " CASE 1: SINGLE ENTRY (Logic Mô phỏng giá)
*    " =========================================================
*    IF mo_grid = go_grid_item_single.
*      PERFORM perform_single_item_simulate IN PROGRAM zsd4_sales_order_center.
*      mo_grid->refresh_table_display( ).
*      " ... (Logic set title cũ) ...
*
*    ELSEIF mo_grid = go_grid_conditions.
*      " ... (Logic đồng bộ condition cũ) ...
*      PERFORM display_conditions_for_item IN PROGRAM zsd4_sales_order_center USING gv_current_item_idx.
*
*
*    " =========================================================
*    " CASE 2: MASS UPLOAD (Logic Sync & Validate) - [QUAN TRỌNG]
*    " =========================================================
*    ELSEIF mo_grid = go_grid_hdr_val OR mo_grid = go_grid_itm_val OR mo_grid = go_grid_cnd_val OR
*           mo_grid = go_grid_hdr_fail OR mo_grid = go_grid_itm_fail OR mo_grid = go_grid_cnd_fail.
*
*      " Khi user sửa xong trên Mass Upload -> Ta cần đồng bộ xuống DB ngay
*      " (Để nếu họ bấm nút Validate thì dữ liệu mới nhất được dùng)
*
*      PERFORM sync_alv_to_staging_tables IN PROGRAM zsd4_sales_order_center.
*
*      " (Tùy chọn: Tự động chạy Validate lại ngay khi sửa xong?
*      "  Thường thì KHÔNG NÊN vì sẽ làm chậm màn hình. Để user bấm nút Validate thì hơn).
*
*      " Chỉ cần Refresh lại Grid để đảm bảo hiển thị đúng
*      mo_grid->refresh_table_display( ).
*
*    ENDIF.
*
*  ENDMETHOD.

    METHOD handle_hotspot_click.
    " 1. Khai báo biến chung
    FIELD-SYMBOLS: <lt_data> TYPE STANDARD TABLE,
                   <ls_row>  TYPE any,
                   <lv_val>  TYPE any.

    DATA: lv_req_id  TYPE zsd_req_id,
          lv_temp_id TYPE char10,
          lv_item_no TYPE posnr_va.

    " 2. Lấy bảng dữ liệu của Grid đang được click (mt_table đã gán ở Constructor)
    ASSIGN mt_table->* TO <lt_data>.
    IF <lt_data> IS NOT ASSIGNED. RETURN. ENDIF.

    " 3. Đọc dòng dữ liệu được click
    READ TABLE <lt_data> ASSIGNING <ls_row> INDEX es_row_no-row_id.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " -------------------------------------------------------
    " CASE A: XỬ LÝ CHO MÀN HÌNH TRACKING (Screen 0500/0600)
    " -------------------------------------------------------
    IF e_column_id = 'DELIVERY_DOCUMENT' OR e_column_id = 'VBELN_DLV'.

       " Lấy giá trị Delivery
       ASSIGN COMPONENT e_column_id OF STRUCTURE <ls_row> TO <lv_val>.

       IF <lv_val> IS NOT INITIAL.
         " Chuyển sang màn hình PGI (0300)
         SET PARAMETER ID 'VL' FIELD <lv_val>.
         CALL SCREEN 0300.
       ELSE.
         MESSAGE 'No Delivery Document exists for this line.' TYPE 'S' DISPLAY LIKE 'W'.
       ENDIF.
       RETURN. " Xử lý xong thì thoát
    ENDIF.

    IF e_column_id = 'SALES_DOCUMENT' OR e_column_id = 'VBELN_SO'.
       " (Optional) Click vào số SO -> Xem VA03
       ASSIGN COMPONENT e_column_id OF STRUCTURE <ls_row> TO <lv_val>.
       IF <lv_val> IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD <lv_val>.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
       ENDIF.
       RETURN.
    ENDIF.

      IF e_column_id = 'ERR_BTN'.

      " A. Lấy REQ_ID từ dòng click (An toàn hơn dùng biến Global)
      ASSIGN COMPONENT 'REQ_ID' OF STRUCTURE <ls_row> TO <lv_val>.
      IF <lv_val> IS ASSIGNED. lv_req_id = <lv_val>. ENDIF.

      " B. Lấy TEMP_ID
      ASSIGN COMPONENT 'TEMP_ID' OF STRUCTURE <ls_row> TO <lv_val>.
      IF <lv_val> IS ASSIGNED. lv_temp_id = <lv_val>. ENDIF.

      " B. Xác định Item No dựa trên GRID đang click
      " (Logic này an toàn hơn là assign component tự động)

      IF mo_grid = go_grid_hdr_val OR mo_grid = go_grid_hdr_fail.
         " Nếu click ở Header -> Item No luôn là 000000
         lv_item_no = '000000'.

      ELSE.
         " Nếu click ở Item hoặc Condition -> Lấy Item No từ dòng dữ liệu
         ASSIGN COMPONENT 'ITEM_NO' OF STRUCTURE <ls_row> TO <lv_val>.
         IF <lv_val> IS ASSIGNED.
            " Convert sang format chuẩn (000010) để so sánh
             DATA: lv_in TYPE string, lv_out TYPE posnr_va.
             lv_in = <lv_val>.
             CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
               EXPORTING input = lv_in IMPORTING output = lv_out.
             lv_item_no = lv_out.
         ENDIF.
      ENDIF.

      " Gọi Popup (Truyền thêm REQ_ID)
      PERFORM show_error_details_popup
        USING lv_req_id lv_temp_id lv_item_no.

      RETURN.
    ENDIF.

  ENDMETHOD.

  "  --- KẾT THÚC THÊM ---
ENDCLASS.

*&---------------------------------------------------------------------*
*& Form alv_grid_display
*&---------------------------------------------------------------------*
FORM alv_grid_display USING pv_grid_nm TYPE fieldname.
  PERFORM alv_layout        USING pv_grid_nm.
  PERFORM alv_variant       USING pv_grid_nm.
  PERFORM alv_toolbar       USING pv_grid_nm.
  PERFORM alv_fieldcatalog  USING pv_grid_nm.
  PERFORM alv_event         USING pv_grid_nm.
ENDFORM.

FORM alv_layout USING pv_grid_nm.
  CLEAR: gv_grid_title, gs_layout.
  PERFORM alv_set_gridtitle USING pv_grid_nm.

  " --- SỬA LOGIC EDIT ---
  DATA: lv_edit TYPE abap_bool.
  IF pv_grid_nm = 'GO_GRID_ITEM_SINGLE' OR pv_grid_nm = 'GO_GRID_CONDITIONS'.
    lv_edit = abap_true. " ALV Single Item LUÔN LUÔN edit
  ELSEIF pv_grid_nm = 'GO_GRID_MONITORING'. " <<< THÊM MỚI
    lv_edit = abap_false. " (Read-only)
  ELSEIF pv_grid_nm = 'GO_GRID_PGI_ALL'.
    lv_edit = gv_pgi_edit_mode. " <<< THÊM (Dùng cờ PGI)
  " === MASS UPLOAD TABS ===

  " 1. Tab Validated: MỞ (Để user sửa lỗi validation/data trước khi Post)
  ELSEIF pv_grid_nm = 'GO_GRID_HDR_VAL' OR pv_grid_nm = 'GO_GRID_ITM_VAL' OR pv_grid_nm = 'GO_GRID_CND_VAL'.
    lv_edit = abap_true.

  " 2. Tab Posted Success: KHÓA (Đã xong, không cho sửa nữa)
  ELSEIF pv_grid_nm = 'GO_GRID_HDR_SUC' OR pv_grid_nm = 'GO_GRID_ITM_SUC' OR pv_grid_nm = 'GO_GRID_CND_SUC'.
    lv_edit = abap_false.

  " 3. Tab Posted Failed: MỞ (Để user sửa lỗi BAPI và Post lại)
  ELSEIF pv_grid_nm = 'GO_GRID_HDR_FAIL' OR pv_grid_nm = 'GO_GRID_ITM_FAIL' OR pv_grid_nm = 'GO_GRID_CND_FAIL'.
    lv_edit = abap_true.

  " === DEFAULT ===
  ELSE.
    lv_edit = gs_edit. " Các trường hợp còn lại
  ENDIF.

  gs_layout = VALUE #(
      sel_mode   = 'A'
      stylefname = 'STYLE'
      " [QUAN TRỌNG]: Khai báo tên cột chứa thông tin màu sắc
      ctab_fname = 'CELLTAB'    " (Tô màu Ô - Cell Color)
      info_fname = 'ROWCOLOR'   " (Tô màu Dòng - Row Color)
      smalltitle = abap_true
      cwidth_opt = abap_true
      zebra      = abap_true
      edit       = lv_edit
      grid_title = gv_grid_title
      no_rowmark = space
  ).
ENDFORM.

*---------------------------------------------------------------------*
* Form alv_set_gridtitle - Set ALV Title Text
*---------------------------------------------------------------------*
FORM alv_set_gridtitle USING pv_grid_nm TYPE fieldname.
  DATA: lv_entry TYPE i,
        lv_title TYPE string.

  CASE pv_grid_nm.
   " =========================================================
    " 1. TAB VALIDATED (Pending / Processing)
    " =========================================================
    WHEN 'GO_GRID_HDR_VAL'.
      lv_title = 'Header Data (Validated)'.
      lv_entry = lines( gt_hd_val ).
    WHEN 'GO_GRID_ITM_VAL'.
      lv_title = 'Item Data (Validated)'.
      lv_entry = lines( gt_it_val ).
    WHEN 'GO_GRID_CND_VAL'.
      lv_title = 'Condition Data (Validated)'.
      lv_entry = lines( gt_pr_val ).

    " =========================================================
    " 2. TAB POSTED SUCCESS (Thành công)
    " =========================================================
    WHEN 'GO_GRID_HDR_SUC'.
      lv_title = 'Header Data (Success)'.
      lv_entry = lines( gt_hd_suc ).
    WHEN 'GO_GRID_ITM_SUC'.
      lv_title = 'Item Data (Success)'.
      lv_entry = lines( gt_it_suc ).
    WHEN 'GO_GRID_CND_SUC'.
      lv_title = 'Condition Data (Success)'.
      lv_entry = lines( gt_pr_suc ).

    " =========================================================
    " 3. TAB POSTED FAILED (Thất bại)
    " =========================================================
    WHEN 'GO_GRID_HDR_FAIL'.
      lv_title = 'Header Data (Failed)'.
      lv_entry = lines( gt_hd_fail ).
    WHEN 'GO_GRID_ITM_FAIL'.
      lv_title = 'Item Data (Failed)'.
      lv_entry = lines( gt_it_fail ).
    WHEN 'GO_GRID_CND_FAIL'.
      lv_title = 'Condition Data (Failed)'.
      lv_entry = lines( gt_pr_fail ).
    WHEN 'GO_GRID_ITEM_SINGLE'.
      lv_title = 'Item Details (Single Entry)'.
      lv_entry = lines( gt_item_details ).
      " <<< KẾT THÚC THÊM >>>
      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_CONDITIONS'.
      lv_title = 'Pricing Elements'.
      lv_entry = lines( gt_conditions_alv ).
      " <<< KẾT THÚC THÊM >>>
      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_MONITORING'.
      lv_title = 'Sales Order Monitoring'.
      lv_entry = lines( gt_monitoring_data ).
      " <<< KẾT THÚC THÊM >>>
     " <<< THÊM 2 CASE MỚI >>>
    WHEN 'GO_GRID_PGI_ALL'.
      lv_title = 'All Items'.
      lv_entry = lines( gt_pgi_all_items ).

    WHEN OTHERS.
      lv_title = 'ALV Grid'.
      lv_entry = 0.
  ENDCASE.

  gv_grid_title = |{ lv_title } ({ lv_entry } rows)|. " Gán vào biến global gs_layout dùng
ENDFORM.

FORM alv_variant USING pv_grid_nm TYPE fieldname.
  CLEAR gs_variant.

  gs_variant-report   = sy-repid.
  gs_variant-username = sy-uname.

  " Gán Handle riêng biệt cho từng Grid (Để lưu Layout riêng)
  CASE pv_grid_nm.
    " --- Tab 1: Validated (V) ---
    WHEN 'GO_GRID_HDR_VAL'.  gs_variant-handle = 'V1'.
    WHEN 'GO_GRID_ITM_VAL'.  gs_variant-handle = 'V2'.
    WHEN 'GO_GRID_CND_VAL'.  gs_variant-handle = 'V3'. " [MỚI]

    " --- Tab 2: Posted Success (S) ---
    WHEN 'GO_GRID_HDR_SUC'.  gs_variant-handle = 'S1'.
    WHEN 'GO_GRID_ITM_SUC'.  gs_variant-handle = 'S2'.
    WHEN 'GO_GRID_CND_SUC'.  gs_variant-handle = 'S3'. " [MỚI]

    " --- Tab 3: Posted Failed (F) ---
    WHEN 'GO_GRID_HDR_FAIL'. gs_variant-handle = 'F1'.
    WHEN 'GO_GRID_ITM_FAIL'. gs_variant-handle = 'F2'.
    WHEN 'GO_GRID_CND_FAIL'. gs_variant-handle = 'F3'. " [MỚI]

    " --- Các Chức năng Khác (Giữ nguyên handle cũ để không mất layout cũ) ---
    WHEN 'GO_GRID_ITEM_SINGLE'. gs_variant-handle = '07'.
    WHEN 'GO_GRID_CONDITIONS'.  gs_variant-handle = '08'. " (Condition của Single Entry)
    WHEN 'GO_GRID_MONITORING'.  gs_variant-handle = '09'.
    WHEN 'GO_GRID_PGI_ALL'.     gs_variant-handle = '10'.

    WHEN OTHERS.                gs_variant-handle = 'XX'.
  ENDCASE.
ENDFORM.

*---------------------------------------------------------------------*
* Form alv_toolbar - Define Toolbar Buttons to Exclude
*---------------------------------------------------------------------*
FORM alv_toolbar USING pv_grid_nm.
  CLEAR gt_exclude.
  PERFORM get_alv_exclude_tb_func USING gt_exclude.
ENDFORM.

*---------------------------------------------------------------------*
* Form get_alv_exclude_tb_func - Hide Unused Toolbar Functions
*---------------------------------------------------------------------*
FORM get_alv_exclude_tb_func USING pt_exclude TYPE ui_functions.
  pt_exclude = VALUE #(
    ( cl_gui_alv_grid=>mc_fc_loc_delete_row )
    ( cl_gui_alv_grid=>mc_fc_filter )
  ).
ENDFORM.

*---------------------------------------------------------------------*
* Form alv_fieldcatalog - Determine Which Fieldcatalog to Use
*---------------------------------------------------------------------*
FORM alv_fieldcatalog USING pv_grid_nm TYPE fieldname.
  CASE pv_grid_nm.
   " --- 1. Header Validated & Failed (KHÔNG hiện cột SO/DLV) ---
    WHEN 'GO_GRID_HDR_VAL' OR 'GO_GRID_HDR_FAIL'.
       PERFORM alv_fieldcatalog_01 USING abap_false CHANGING gt_fcat_header.

    " --- 2. Header Success (HIỆN cột SO/DLV) ---
    WHEN 'GO_GRID_HDR_SUC'.
       PERFORM alv_fieldcatalog_01 USING abap_true CHANGING gt_fcat_header.

    " --- Nhóm Item (3 Tab) ---
    WHEN 'GO_GRID_ITM_VAL' OR 'GO_GRID_ITM_SUC' OR 'GO_GRID_ITM_FAIL'.
       PERFORM alv_fieldcatalog_02 CHANGING gt_fcat_item.

    " --- Nhóm Condition (3 Tab) [MỚI] ---
    WHEN 'GO_GRID_CND_VAL' OR 'GO_GRID_CND_SUC' OR 'GO_GRID_CND_FAIL'.
       PERFORM alv_fieldcatalog_cond CHANGING gt_fcat_cond.
    WHEN 'GO_GRID_ITEM_SINGLE'.
      PERFORM alv_fieldcatalog_single_item CHANGING gt_fieldcat_item_single.
      " --- KẾT THÚC THÊM MỚI ---
      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_CONDITIONS'.
      PERFORM alv_fieldcatalog_conditions CHANGING gt_fieldcat_conds.
      " <<< KẾT THÚC THÊM >>>
      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_MONITORING'.
      PERFORM alv_fieldcatalog_monitoring CHANGING gt_fieldcat_monitoring.
      " <<< KẾT THÚC THÊM >>>
     " <<< THÊM 2 CASE MỚI >>>
    WHEN 'GO_GRID_PGI_ALL'.
      PERFORM alv_fieldcatalog_pgi_all CHANGING gt_fieldcat_pgi_all.
*    WHEN 'GO_GRID_PGI_PROC'.
*      PERFORM alv_fieldcatalog_pgi_proc CHANGING gt_fieldcat_pgi_proc.
*    " <<< KẾT THÚC THÊM >>>
    WHEN OTHERS.
      " Optional: Handle unknown grid names
      MESSAGE |Field catalog logic not defined for grid: { pv_grid_nm }| TYPE 'W'.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_01 (Header - Dynamic Columns)
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_01
  USING    iv_show_result TYPE abap_bool " [MỚI] Cờ hiển thị
  CHANGING pt_fieldcat    TYPE lvc_t_fcat.

  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " --- Định nghĩa Macro ---
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-edit       = COND #( WHEN gs_edit = abap_true THEN 'X' ELSE space ).
    ls_fcat-fieldname  = &1.
    ls_fcat-just       = &2.
    ls_fcat-col_opt    = &3.
    ls_fcat-coltext    = &4.
    ls_fcat-seltext    = &4.
    ls_fcat-tooltip    = &4.
    ls_fcat-fix_column = &5.
    ls_fcat-ref_table  = 'ZTB_SO_UPLOAD_HD'.
    ls_fcat-ref_field  = &1.
    ls_fcat-edit_mask  = &6.
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " 1. Cột Status Icon (Luôn hiện)
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ICON'.
  ls_fcat-coltext   = 'Status'.
  ls_fcat-icon      = abap_true.
  ls_fcat-fix_column = abap_true.
  ls_fcat-outputlen = 4.
  APPEND ls_fcat TO pt_fieldcat.

  " [THÊM MỚI] Cột Error Details (Thường để cuối cùng)
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERR_BTN'.
  ls_fcat-coltext   = 'Error Log'.
  ls_fcat-icon      = abap_true.   " Hiển thị dạng Icon
  ls_fcat-hotspot   = abap_true.   " Có thể click được
  ls_fcat-outputlen = 4.
  ls_fcat-just      = 'C'.
  APPEND ls_fcat TO pt_fieldcat.

  " 2. [SỬA QUAN TRỌNG] Chỉ hiện SO & Delivery nếu cờ = TRUE
  IF iv_show_result = abap_true.
    _add_fieldcat 'VBELN_SO'  'C' 'X' 'Sales Doc.'  'X' ''.
    _add_fieldcat 'VBELN_DLV' 'C' 'X' 'Delivery No' 'X' ''.

    " (Lưu ý: Tôi dùng Macro cho gọn, nhưng đè lại thuộc tính edit = space để không cho sửa)
    " Hoặc bạn có thể khai báo thủ công như trước cũng được.
    " Logic edit = space cho 2 cột này đã được xử lý ở FORM ALV_LAYOUT (bước trước)
    " hoặc ALV tự khóa vì Tab Success chúng ta đã set layout edit = false toàn bộ.
  ENDIF.

  " 3. Các cột dữ liệu (Luôn hiện)
  _add_fieldcat:
    'TEMP_ID'           'L' 'X' 'Temp ID'                 'X' '',
    'ORDER_TYPE'        'L' 'X' 'Order Type'              ''  '',
    'SALES_ORG'         'L' 'X' 'Sales Org'               ''  '',
    'SALES_CHANNEL'     'L' 'X' 'Dist Channel'            ''  '',
    'SALES_DIV'         'L' 'X' 'Division'                ''  '',
    'SALES_OFF'         'L' 'X' 'Sales Office'            ''  '',
    'SALES_GRP'         'L' 'X' 'Sales Group'             ''  '',
    'SOLD_TO_PARTY'     'L' 'X' 'Sold-To Party'           ''  '',
    'CUST_REF'          'L' 'X' 'Cust Ref'                ''  '',
    'REQ_DATE'          'C' 'X' 'Req Delivery Date'       ''  '__.__.____',
    'PRICE_DATE'        'C' 'X' 'Price Date'              ''  '__.__.____',
    'PMNTTRMS'          'L' 'X' 'Payment Terms'           ''  '',
    'INCOTERMS'         'L' 'X' 'Incoterms'               ''  '',
    'INCO2'             'L' 'X' 'Inco. Location'          ''  '',
    'CURRENCY'          'L' 'X' 'Currency'                ''  '',
    'ORDER_DATE'        'C' 'X' 'Order Date'              ''  '__.__.____',
    'SHIP_COND'         'L' 'X' 'Shipping Cond'           ''  ''.

ENDFORM.

*---------------------------------------------------------------------*
* Form alv_fieldcatalog_02 - Item Fields
*---------------------------------------------------------------------*
FORM alv_fieldcatalog_02 CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " --- UPDATED MACRO DEFINITION with EDIT_MASK (&6) ---
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-edit       = COND #( WHEN gs_edit = abap_true THEN 'X' ELSE space ).
    ls_fcat-fieldname  = &1.
    ls_fcat-just       = &2.
    ls_fcat-col_opt    = &3.
    ls_fcat-coltext    = &4.
    ls_fcat-seltext    = &4.
    ls_fcat-tooltip    = &4.
    ls_fcat-scrtext_l  = &4.
    ls_fcat-scrtext_m  = &4.
    ls_fcat-scrtext_s  = &4.
    ls_fcat-fix_column = &5.
    ls_fcat-ref_table  = 'ZTB_SO_UPLOAD_IT'. " <<< CORRECT TABLE NAME
    ls_fcat-ref_field  = &1.              " Use fieldname as ref_field
    ls_fcat-edit_mask  = &6.              " <<< ADD EDIT_MASK PARAMETER (&6)
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  DEFINE _add_icon_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-fieldname = 'ICON'.
    ls_fcat-coltext   = 'Status'.
    ls_fcat-seltext   = 'Status'.
    ls_fcat-tooltip   = 'Status'.
    ls_fcat-just      = 'C'.
    ls_fcat-col_opt   = abap_on.
    ls_fcat-icon      = abap_on.
    ls_fcat-fix_column = abap_on.
    ls_fcat-edit      = space.
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  _add_icon_fieldcat.

    " [THÊM MỚI] Cột Error Details (Thường để cuối cùng)
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERR_BTN'.
  ls_fcat-coltext   = 'Error Log'.
  ls_fcat-icon      = abap_true.   " Hiển thị dạng Icon
  ls_fcat-hotspot   = abap_true.   " Có thể click được
  ls_fcat-outputlen = 4.
  ls_fcat-just      = 'C'.
  APPEND ls_fcat TO pt_fieldcat.

  " --- UPDATED MACRO CALLS with EditMask ---
  " Fieldname        Just Opt  Coltext                FixCol EditMask
  _add_fieldcat:
    'TEMP_ID'            'L' abap_on 'Temp ID'              abap_on  '', " No mask
    'PRICE_PROC'         'L' abap_on 'Pricing Procedure'    abap_off '',
    'ITEM_NO'            'L' abap_on 'Item No'              abap_off '',
    'MATERIAL'              'L' abap_on 'Material'             abap_off '',
    'SHORT_TEXT'         'L' abap_on 'Short Text'           abap_off '',
    'PLANT'              'L' abap_on 'Plant'                abap_off '',
    'SHIP_POINT'         'L' abap_on 'Shipping Point'       abap_off '',
    'STORE_LOC'          'L' abap_on 'Storage Loc.'         abap_off '',
    'QUANTITY'           'R' abap_on 'Order Quantity'       abap_off '',
*    'UNIT_PRICE'         'R' abap_on 'Unit Price'           abap_off '',
*    'PER'                'C' abap_on 'Per'                  abap_off '',
*    'UNIT'               'L' abap_on 'UoM'                  abap_off '',
*    'COND_TYPE'          'L' abap_on 'Cond. Type'           abap_off '',
    'REQ_DATE'           'C' abap_on 'Schedule Line Date'   abap_off '__.__.____'. " <<< ADD MASK

ENDFORM.

*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_COND (Cho bảng Pricing)
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_cond CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  DEFINE _add_fcat_cond.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-ref_table = 'ZTB_SO_UPLOAD_PR'. " Tên bảng Z của bạn
    ls_fcat-ref_field = &1.
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

    CLEAR ls_fcat.
  ls_fcat-fieldname = 'ICON'.
  ls_fcat-coltext   = 'Status'.
  ls_fcat-icon      = abap_true.
  ls_fcat-fix_column = abap_true.
    APPEND ls_fcat TO pt_fieldcat.

  " [THÊM MỚI] Cột Error Details (Thường để cuối cùng)
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERR_BTN'.
  ls_fcat-coltext   = 'Error Log'.
  ls_fcat-icon      = abap_true.   " Hiển thị dạng Icon
  ls_fcat-hotspot   = abap_true.   " Có thể click được
  ls_fcat-outputlen = 4.
  ls_fcat-just      = 'C'.
  APPEND ls_fcat TO pt_fieldcat.

  " Cấu hình cột cho Condition
  _add_fcat_cond 'TEMP_ID'    'Temp ID'.
  _add_fcat_cond 'ITEM_NO'    'Item No'.
  _add_fcat_cond 'COND_TYPE'  'Condition Type'.
  _add_fcat_cond 'AMOUNT'     'Amount'.
  _add_fcat_cond 'CURRENCY'   'Currency'.
  _add_fcat_cond 'PER'        'Pricing Unit'.
  _add_fcat_cond 'UOM'        'UoM'.

  " Cột Status Icon (Quan trọng để hiện đèn)
*  CLEAR ls_fcat.
*  ls_fcat-fieldname = 'ICON'.
*  ls_fcat-coltext   = 'Status'.
*  ls_fcat-icon      = abap_true.
*  ls_fcat-fix_column = abap_true.
*  APPEND ls_fcat TO pt_fieldcat.
ENDFORM.

*---------------------------------------------------------------------*
* Form alv_event - Attach Toolbar & Command Handler
*---------------------------------------------------------------------*
FORM alv_event USING pv_grid_nm TYPE fieldname.

  CASE pv_grid_nm.
    " ========================================================
    " 1. NHÓM MASS UPLOAD (HEADER) - Cần bắt sự kiện Click
    " ========================================================
    WHEN 'GO_GRID_HDR_VAL'.
      CHECK go_grid_hdr_val IS BOUND.
      IF go_event_hdr_val IS INITIAL.
        CREATE OBJECT go_event_hdr_val
          EXPORTING io_grid = go_grid_hdr_val it_table = REF #( gt_hd_val ).
      ENDIF.
      " Đăng ký Hotspot Click (để lọc Item bên dưới)
      SET HANDLER go_event_hdr_val->handle_hotspot_click FOR go_grid_hdr_val.
      " Đăng ký Data Changed (để sửa dữ liệu)
      SET HANDLER go_event_hdr_val->handle_data_changed FOR go_grid_hdr_val.

    WHEN 'GO_GRID_HDR_SUC'.
      CHECK go_grid_hdr_suc IS BOUND.
      IF go_event_hdr_suc IS INITIAL.
        CREATE OBJECT go_event_hdr_suc
          EXPORTING io_grid = go_grid_hdr_suc it_table = REF #( gt_hd_suc ).
      ENDIF.
      SET HANDLER go_event_hdr_suc->handle_hotspot_click FOR go_grid_hdr_suc.
      " (Tab Success không cho sửa nên không cần Data Changed)

    WHEN 'GO_GRID_HDR_FAIL'.
      CHECK go_grid_hdr_fail IS BOUND.
      IF go_event_hdr_fail IS INITIAL.
        CREATE OBJECT go_event_hdr_fail
          EXPORTING io_grid = go_grid_hdr_fail it_table = REF #( gt_hd_fail ).
      ENDIF.
      SET HANDLER go_event_hdr_fail->handle_hotspot_click FOR go_grid_hdr_fail.
      SET HANDLER go_event_hdr_fail->handle_data_changed  FOR go_grid_hdr_fail.

    " ========================================================
    " 2. NHÓM MASS UPLOAD (ITEM) - Cần bắt sự kiện Sửa đổi
    " ========================================================
    WHEN 'GO_GRID_ITM_VAL'.
      CHECK go_grid_itm_val IS BOUND.
      IF go_event_itm_val IS INITIAL.
        CREATE OBJECT go_event_itm_val
          EXPORTING io_grid = go_grid_itm_val it_table = REF #( gt_it_val ).
      ENDIF.
      SET HANDLER go_event_itm_val->handle_hotspot_click FOR go_grid_itm_val.
      SET HANDLER go_event_itm_val->handle_data_changed FOR go_grid_itm_val.

    WHEN 'GO_GRID_ITM_FAIL'.
      CHECK go_grid_itm_fail IS BOUND.
      IF go_event_itm_fail IS INITIAL.
        CREATE OBJECT go_event_itm_fail
          EXPORTING io_grid = go_grid_itm_fail it_table = REF #( gt_it_fail ).
      ENDIF.
      SET HANDLER go_event_itm_fail->handle_hotspot_click FOR go_grid_itm_fail.
      SET HANDLER go_event_itm_fail->handle_data_changed FOR go_grid_itm_fail.

    " ========================================================
    " 3. NHÓM MASS UPLOAD (CONDITION)
    " ========================================================
    WHEN 'GO_GRID_CND_VAL'.
      CHECK go_grid_cnd_val IS BOUND.
      IF go_event_cnd_val IS INITIAL.
        CREATE OBJECT go_event_cnd_val
          EXPORTING io_grid = go_grid_cnd_val it_table = REF #( gt_pr_val ).
      ENDIF.
      SET HANDLER go_event_cnd_val->handle_hotspot_click FOR go_grid_cnd_val.
      SET HANDLER go_event_cnd_val->handle_data_changed FOR go_grid_cnd_val.

    WHEN 'GO_GRID_CND_FAIL'.
      CHECK go_grid_cnd_fail IS BOUND.
      IF go_event_cnd_fail IS INITIAL.
        CREATE OBJECT go_event_cnd_fail
          EXPORTING io_grid = go_grid_cnd_fail it_table = REF #( gt_pr_fail ).
      ENDIF.
       SET HANDLER go_event_cnd_fail->handle_hotspot_click FOR go_grid_cnd_fail.
      SET HANDLER go_event_cnd_fail->handle_data_changed FOR go_grid_cnd_fail.

      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_ITEM_SINGLE'.
      CHECK go_grid_item_single IS BOUND.
      IF go_event_handler_single IS INITIAL.
        CREATE OBJECT go_event_handler_single
          EXPORTING
            io_grid  = go_grid_item_single
            it_table = REF #( gt_item_details ).
      ENDIF.
      SET HANDLER:
        go_event_handler_single->handle_user_command       FOR go_grid_item_single,
        go_event_handler_single->handle_toolbar            FOR go_grid_item_single,
        go_event_handler_single->handle_data_changed       FOR go_grid_item_single,
*        go_event_handler_single->handle_onf4                FOR go_grid_item_single,
        go_event_handler_single->handle_data_changed_finished FOR go_grid_item_single.


*        go_event_handler_single->handle_data_changed_finished FOR go_grid_item_single.
      "  <<< KẾT THÚC THÊM >>>
      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_CONDITIONS'.
      CHECK go_grid_conditions IS BOUND.
      IF go_event_handler_conds IS INITIAL.
        CREATE OBJECT go_event_handler_conds
          EXPORTING
            io_grid  = go_grid_conditions
            it_table = REF #( gt_conditions_alv ).
      ENDIF.
*      SET HANDLER
      " (Không cần user_command/toolbar vì nút nằm ngoài ALV)
*        go_event_handler_conds->handle_data_changed_finished FOR go_grid_conditions.
      " <<< KẾT THÚC THÊM >>>

      " <<< THÊM CASE NÀY VÀO (Không cần handler, nhưng để cho đủ) >>>
    WHEN 'GO_GRID_MONITORING'.
      CHECK go_grid_monitoring IS BOUND.
      IF go_event_handler_moni IS INITIAL.
        CREATE OBJECT go_event_handler_moni
          EXPORTING
            io_grid  = go_grid_monitoring
            it_table = REF #( gt_monitoring_data ).
      ENDIF.
      " (Không cần SET HANDLER vì đây là report read-only)
      " <<< KẾT THÚC THÊM >>>

      " <<< THÊM 2 CASE MỚI >>>
    WHEN 'GO_GRID_PGI_ALL'.
      CHECK go_grid_pgi_all IS BOUND.
      IF go_event_pgi_all IS INITIAL.
        CREATE OBJECT go_event_pgi_all
          EXPORTING
            io_grid  = go_grid_pgi_all
            it_table = REF #( gt_pgi_all_items ).
      ENDIF.
      SET HANDLER:
        go_event_pgi_all->handle_data_changed_finished FOR go_grid_pgi_all.

    WHEN OTHERS.
      " Optional: Add error handling or ignore

  ENDCASE.
ENDFORM.
*---------------------------------------------------------------------*
* Form alv_outtab_display - Render ALV Data
*---------------------------------------------------------------------*
FORM alv_outtab_display USING pv_grid_nm TYPE fieldname.
  FIELD-SYMBOLS: <lfs_grid> TYPE REF TO cl_gui_alv_grid.
  DATA: lt_fcat TYPE lvc_t_fcat,
        lt_data TYPE REF TO data.

  ASSIGN (pv_grid_nm) TO <lfs_grid>.
  CHECK <lfs_grid> IS BOUND.

  CASE pv_grid_nm.
      " --- Tab 1: Validated ---
    WHEN 'GO_GRID_HDR_VAL'.
      lt_data = REF #( gt_hd_val ).
      lt_fcat = gt_fcat_header. " (Bạn cần khai báo biến này trong TOP)
    WHEN 'GO_GRID_ITM_VAL'.
      lt_data = REF #( gt_it_val ).
      lt_fcat = gt_fcat_item.
    WHEN 'GO_GRID_CND_VAL'. " [MỚI]
      lt_data = REF #( gt_pr_val ).
      lt_fcat = gt_fcat_cond.   " (Bạn cần khai báo biến này trong TOP)

    " --- Tab 2: Success ---
    WHEN 'GO_GRID_HDR_SUC'.
      lt_data = REF #( gt_hd_suc ).
      lt_fcat = gt_fcat_header.
    WHEN 'GO_GRID_ITM_SUC'.
      lt_data = REF #( gt_it_suc ).
      lt_fcat = gt_fcat_item.
    WHEN 'GO_GRID_CND_SUC'. " [MỚI]
      lt_data = REF #( gt_pr_suc ).
      lt_fcat = gt_fcat_cond.

    " --- Tab 3: Failed ---
    WHEN 'GO_GRID_HDR_FAIL'.
      lt_data = REF #( gt_hd_fail ).
      lt_fcat = gt_fcat_header.
    WHEN 'GO_GRID_ITM_FAIL'.
      lt_data = REF #( gt_it_fail ).
      lt_fcat = gt_fcat_item.
    WHEN 'GO_GRID_CND_FAIL'. " [MỚI]
      lt_data = REF #( gt_pr_fail ).
      lt_fcat = gt_fcat_cond.


      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_ITEM_SINGLE'.
      lt_data = REF #( gt_item_details ).
      lt_fcat = gt_fieldcat_item_single.
      " <<< KẾT THÚC THÊM >>>

      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_CONDITIONS'.
      lt_data = REF #( gt_conditions_alv ).
      lt_fcat = gt_fieldcat_conds.
      " <<< KẾT THÚC THÊM >>>

      " <<< THÊM CASE NÀY VÀO >>>
    WHEN 'GO_GRID_MONITORING'.
      lt_data = REF #( gt_monitoring_data ).
      lt_fcat = gt_fieldcat_monitoring.
      " <<< KẾT THÚC THÊM >>>

    " <<< THÊM 2 CASE MỚI >>>
    WHEN 'GO_GRID_PGI_ALL'.
      lt_data = REF #( gt_pgi_all_items ).
      lt_fcat = gt_fieldcat_pgi_all.
*    WHEN 'GO_GRID_PGI_PROC'.
*      lt_data = REF #( gt_pgi_processing ).
*      lt_fcat = gt_fieldcat_pgi_proc.
*    " <<< KẾT THÚC THÊM >>>


    WHEN OTHERS.
      MESSAGE |ALV display logic not defined for grid: { pv_grid_nm }| TYPE 'W'.
      RETURN.
  ENDCASE.

  " --- Phần gọi set_table_for_first_display giữ nguyên ---
  <lfs_grid>->set_table_for_first_display(
    EXPORTING
      i_buffer_active    = abap_true
      i_bypassing_buffer = abap_true
      i_save             = 'A'
      is_layout          = gs_layout " Đảm bảo gs_layout đã được set trước đó
    CHANGING
      it_outtab          = lt_data->* " Sẽ lấy đúng bảng dữ liệu đã gán ở CASE trên
      it_fieldcatalog    = lt_fcat    " Sẽ lấy đúng fieldcat đã gán ở CASE trên
  ).

  cl_gui_control=>set_focus( control = <lfs_grid> ).
  cl_gui_cfw=>flush( ).
ENDFORM.

*---------------------------------------------------------------------*
* Form alv_create_result_cont - Create Container for Result ALV (0200)
*---------------------------------------------------------------------*
FORM alv_create_result_cont.
  IF sy-dynnr = '0200'.
    DATA(lo_custom_cont) = NEW cl_gui_custom_container(
                              repid          = sy-repid
                              dynnr          = sy-dynnr
                              container_name = 'GO_CUSTOM_CONT_RES' ).
    go_grid_res = NEW cl_gui_alv_grid( i_parent = lo_custom_cont ).
  ENDIF.
ENDFORM.



*&---------------------------------------------------------------------*
*& Form alv_set_result_catalog - Fieldcatalog for Result ALV (LVC type)
*&---------------------------------------------------------------------*
FORM alv_set_result_catalog CHANGING pt_fcat TYPE lvc_t_fcat. " <<< SỬA KIỂU: LVC

  DATA ls TYPE lvc_s_fcat. " <<< SỬA KIỂU: LVC
  CLEAR pt_fcat.

  DEFINE add_col.
    CLEAR ls.
    ls-fieldname = &1.
    ls-coltext   = &2. " <<< SỬA: Dùng coltext cho LVC
    ls-col_pos   = sy-tabix.
    APPEND ls TO pt_fcat.
  END-OF-DEFINITION.

  add_col 'VBELN'    'Sales Doc'.
  add_col 'VKORG'    'Sales Org'.
  add_col 'VTWEG'    'Dist. Chnl'.
  add_col 'SPART'    'Division'.
  add_col 'SOLD_TO'  'Sold-to'.
  add_col 'SHIP_TO'  'Ship-to'.
  add_col 'BSTKD'    'Cust. Ref.'.
  add_col 'REQ_DATE' 'Req. Date'.
  add_col 'QTY'      'Items'.
  add_col 'VOLUME'   'Volume'.
  add_col 'STATUS'   'Status'.
  add_col 'MESSAGE'  'Message'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_POPUP_FIELDCAT_SLIS
*&---------------------------------------------------------------------*
*& Builds the SLIS field catalog manually for the result popup
*&---------------------------------------------------------------------*
FORM build_popup_fieldcat_slis CHANGING ct_fieldcat TYPE slis_t_fieldcat_alv.

  DATA ls_fcat TYPE slis_fieldcat_alv.
  REFRESH ct_fieldcat.

  DEFINE add_col.
    CLEAR ls_fcat.
    ls_fcat-fieldname  = &1.
    ls_fcat-seltext_m  = &2. " Text cho cột
    ls_fcat-col_pos    = sy-tabix.
    APPEND ls_fcat TO ct_fieldcat.
  END-OF-DEFINITION.

  " Thêm các cột theo đúng thứ tự bạn muốn
  add_col 'TEMP_ID'  'Temp ID'.     " <<< THÊM CỘT NÀY
  add_col 'VBELN'    'Sales Doc'.
  add_col 'STATUS'   'Status'.
  add_col 'MESSAGE'  'Message'.
  add_col 'VKORG'    'Sales Org'.
  add_col 'VTWEG'    'Dist. Chnl'.
  add_col 'SPART'    'Division'.
  add_col 'SOLD_TO'  'Sold-to'.
  add_col 'SHIP_TO'  'Ship-to'.
  add_col 'BSTKD'    'Cust. Ref.'.
  add_col 'REQ_DATE' 'Req. Date'.
  add_col 'QTY'      'Items'.
  add_col 'VOLUME'   'Volume'.
  " Thêm các trường khác của ty_result nếu cần

ENDFORM.

*---------------------------------------------------------------------*
* Form alv_display_result - Display Result ALV on Screen 0200
*---------------------------------------------------------------------*
FORM alv_display_result.

  " 1. Tạo container cho ALV kết quả (nếu chưa có)
  IF go_grid_res IS INITIAL.
    PERFORM alv_create_result_cont.
  ENDIF.

  " 2. Chuẩn bị fieldcatalog
  PERFORM alv_set_result_catalog CHANGING gt_fieldcat_res.

  " 3. Hiển thị ALV nếu container đã tồn tại
  IF go_grid_res IS BOUND.
    CALL METHOD go_grid_res->set_table_for_first_display
      EXPORTING
        i_buffer_active    = abap_true
        i_bypassing_buffer = abap_true
        i_save             = 'A'
      CHANGING
        it_outtab          = gt_result
        it_fieldcatalog    = gt_fieldcat_res.
  ENDIF.

  " 4. Cập nhật giao diện (tránh lỗi Control Framework)
  cl_gui_cfw=>flush( ).

ENDFORM.


FORM va05_set_layout_and_fcat.
  gs_layo_va05 = VALUE #( zebra = abap_true
                          cwidth_opt = abap_true
                          smalltitle = abap_true ).
  CLEAR gt_fcat_va05.

  DATA ls TYPE lvc_s_fcat.   " <-- giữ lại dòng này, chỉ 1 lần ở ngoài macro

  DEFINE _add_fieldcat.
    CLEAR ls.
    ls-fieldname  = &1.
    ls-just       = &2.
    ls-col_opt    = &3.
    ls-coltext    = &4.
    ls-seltext    = &4.
    ls-tooltip    = &4.
    ls-scrtext_l  = &4.
    ls-scrtext_m  = &4.
    ls-scrtext_s  = &4.
    ls-fix_column = &5.
    APPEND ls TO gt_fcat_va05.
  END-OF-DEFINITION.

  _add_fieldcat:
    'CUST_REF' 'L' abap_on 'Customer Reference' abap_on,
    'DOC_DATE' 'C' abap_on 'Document Date'      abap_off,
    'DOC_TYPE' 'L' abap_on 'Sales Doc. Type'    abap_off,
    'VBELN'    'L' abap_on 'Sales Document'     abap_off,
    'POSNR'    'R' abap_on 'Item'               abap_off,
    'SOLD_TO'  'L' abap_on 'Sold-to Party'      abap_off,
    'MATNR'    'L' abap_on 'Material'           abap_off,
    'QTY'      'R' abap_on 'Order Qty (Item)'   abap_off,
    'UOM'      'L' abap_on 'Sales Unit'         abap_off,
    'NETWR'    'R' abap_on 'Net Value (Item)'   abap_off,
    'WAERK'    'L' abap_on 'Doc. Currency'      abap_off.
ENDFORM.




*---------------------------------------------------------------------*
* FORM show_tab_alv - Display ALV by Tab (All / Created / Incomplete)
*---------------------------------------------------------------------*
FORM show_tab_alv USING pv_tab TYPE c.
  DATA: lo_cont TYPE REF TO cl_gui_custom_container,
        lo_grid TYPE REF TO cl_gui_alv_grid,
        lv_cc   TYPE scrfname.

  PERFORM va05_set_layout_and_fcat.

  CASE pv_tab.
    WHEN 'A'.  lv_cc = 'CC_ALL'.
    WHEN 'C'.  lv_cc = 'CC_CREATED'.
    WHEN 'I'.  lv_cc = 'CC_INCOMP'.
    WHEN OTHERS. RETURN.
  ENDCASE.

  " Create container & grid once
  IF pv_tab = 'A'.
    IF go_grid_all IS NOT BOUND.
      lo_cont = NEW cl_gui_custom_container( container_name = lv_cc ).
      go_grid_all = NEW cl_gui_alv_grid( i_parent = lo_cont ).
    ENDIF.
    lo_grid = go_grid_all.
  ELSEIF pv_tab = 'C'.
    IF go_grid_created IS NOT BOUND.
      lo_cont = NEW cl_gui_custom_container( container_name = lv_cc ).
      go_grid_created = NEW cl_gui_alv_grid( i_parent = lo_cont ).
    ENDIF.
    lo_grid = go_grid_created.
  ELSE.
    IF go_grid_incomp IS NOT BOUND.
      lo_cont = NEW cl_gui_custom_container( container_name = lv_cc ).
      go_grid_incomp = NEW cl_gui_alv_grid( i_parent = lo_cont ).
    ENDIF.
    lo_grid = go_grid_incomp.
  ENDIF.

  " Pick data set
  DATA ref_tab TYPE REF TO data.
  CASE pv_tab.
    WHEN 'A'.  ref_tab = REF #( gt_va05_all ).
    WHEN 'C'.  ref_tab = REF #( gt_va05_created ).
    WHEN 'I'.  ref_tab = REF #( gt_va05_incomp ).
  ENDCASE.

  " Display ALV
  lo_grid->set_table_for_first_display(
    EXPORTING i_save = 'A' is_layout = gs_layo_va05
    CHANGING  it_outtab = ref_tab->* it_fieldcatalog = gt_fcat_va05 ).

  cl_gui_cfw=>flush( ).

ENDFORM.


*---------------------------------------------------------------------*
* FORM show_tab_alv_delivery
*---------------------------------------------------------------------*
FORM show_tab_alv_delivery.

  DATA: lo_cont TYPE REF TO cl_gui_custom_container,
        lo_grid TYPE REF TO cl_gui_alv_grid,
        lv_cc   TYPE scrfname.

  lv_cc = 'CC_DELIV'.

  " Lấy dữ liệu từ Z-table Delivery
  CLEAR gt_delivery.
  SELECT * FROM ztb_delivery_213
    INTO CORRESPONDING FIELDS OF TABLE @gt_delivery.
  IF sy-subrc <> 0.
    MESSAGE 'No delivery data found in ZTB_DELIVERY_213' TYPE 'I'.
    RETURN.
  ENDIF.

  " Layout cơ bản
  DATA gs_layo TYPE lvc_s_layo.
  gs_layo = VALUE #( zebra = abap_true cwidth_opt = abap_true smalltitle = abap_true ).

  " Field catalog
  DATA lt_fcat TYPE lvc_t_fcat.
  PERFORM build_fieldcat_delivery CHANGING lt_fcat.

  " Create container
  IF go_grid_deliv IS NOT BOUND.
    lo_cont = NEW cl_gui_custom_container( container_name = lv_cc ).
    go_grid_deliv = NEW cl_gui_alv_grid( i_parent = lo_cont ).
  ENDIF.

  " Display ALV
  go_grid_deliv->set_table_for_first_display(
    EXPORTING
      i_save    = 'A'
      is_layout = gs_layo
    CHANGING
      it_outtab       = gt_delivery
      it_fieldcatalog = lt_fcat ).

  cl_gui_cfw=>flush( ).
ENDFORM.

FORM build_fieldcat_delivery CHANGING ct_fcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.

  " Checkbox chọn dòng
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'SEL'.
  ls_fcat-coltext   = 'Select'.
  ls_fcat-seltext   = 'Select'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-edit      = abap_true.
  ls_fcat-outputlen = 6.
  ls_fcat-fix_column = abap_true.
  APPEND ls_fcat TO ct_fcat.

  " Các cột còn lại
  APPEND VALUE #( fieldname = 'VBELN_DLV'  coltext = 'Outbound Delivery' ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'VBELN_SO'   coltext = 'Sales Order'       ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'VKORG'      coltext = 'Sales Org'         ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'VTWEG'      coltext = 'Dist. Channel'     ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'SPART'      coltext = 'Division'          ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'KUNNR_SOLD' coltext = 'Sold-to Party'     ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'KUNNR_SHIP' coltext = 'Ship-to Party'     ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'BSTKD'      coltext = 'Cust. Reference'   ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'ERDAT'      coltext = 'Date'              ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'STATUS'     coltext = 'Status'            ) TO ct_fcat.
  APPEND VALUE #( fieldname = 'MESSAGE'    coltext = 'Message'           ) TO ct_fcat.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_ALV_LAYOUT_0201 (Tab Validated: 3 ALVs)
*&---------------------------------------------------------------------*
FORM build_alv_layout_0201.
  STATICS: sv_first_call TYPE abap_bool VALUE abap_true.
  DATA: ls_stable TYPE lvc_s_stbl.

  " --- 1. REFRESH nếu đã tồn tại ---
  " (Dùng đúng tên biến toàn cục của Tab Validated)
  IF go_grid_hdr_val IS BOUND AND go_grid_itm_val IS BOUND AND go_grid_cnd_val IS BOUND.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.

    go_grid_hdr_val->refresh_table_display( is_stable = ls_stable ).
    go_grid_itm_val->refresh_table_display( is_stable = ls_stable ).
    go_grid_cnd_val->refresh_table_display( is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " --- 2. Free Controls cũ (Nếu chuyển từ tab khác sang) ---
  " (Lưu ý: Nếu dùng Subscreen riêng biệt thì không cần free biến của tab khác,
  "  nhưng cần free biến của tab này nếu nó bị lỗi)
  IF go_grid_hdr_val IS BOUND. go_grid_hdr_val->free( ). CLEAR go_grid_hdr_val. ENDIF.
  IF go_grid_itm_val IS BOUND. go_grid_itm_val->free( ). CLEAR go_grid_itm_val. ENDIF.
  IF go_grid_cnd_val IS BOUND. go_grid_cnd_val->free( ). CLEAR go_grid_cnd_val. ENDIF.

  " --- 3. Khởi tạo Container ---
  DATA: lo_main_container TYPE REF TO cl_gui_custom_container,
        lo_split_main     TYPE REF TO cl_gui_splitter_container,
        lo_split_sub      TYPE REF TO cl_gui_splitter_container.

  sv_first_call = abap_false.

  " 3.1. Main Container
  CREATE OBJECT lo_main_container EXPORTING container_name = 'CC_ALV_AREA'.
  IF sy-subrc <> 0. RETURN. ENDIF.

  " 3.2. Splitter Chính
  CREATE OBJECT lo_split_main EXPORTING parent = lo_main_container rows = 2 columns = 1.
  lo_split_main->set_row_height( id = 1 height = 40 ).

  DATA(lo_cont_top) = lo_split_main->get_container( row = 1 column = 1 ).
  DATA(lo_cont_bot) = lo_split_main->get_container( row = 2 column = 1 ).

  " 3.3. Splitter Phụ
  CREATE OBJECT lo_split_sub EXPORTING parent = lo_cont_bot rows = 1 columns = 2.
  lo_split_sub->set_column_width( id = 1 width = 60 ).

  DATA(lo_cont_itm) = lo_split_sub->get_container( row = 1 column = 1 ).
  DATA(lo_cont_cnd) = lo_split_sub->get_container( row = 1 column = 2 ).

  " --- 4. Tạo Objects ALV Grid (Dùng biến toàn cục _VAL) ---
  CREATE OBJECT go_grid_hdr_val EXPORTING i_parent = lo_cont_top.
  CREATE OBJECT go_grid_itm_val EXPORTING i_parent = lo_cont_itm.
  CREATE OBJECT go_grid_cnd_val EXPORTING i_parent = lo_cont_cnd.

  " --- 5. Hiển thị ---
  PERFORM alv_grid_display   USING 'GO_GRID_HDR_VAL'.
  PERFORM alv_outtab_display USING 'GO_GRID_HDR_VAL'.

  " [THÊM]: Đăng ký Edit Event cho Header (Validated)
  go_grid_hdr_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  go_grid_hdr_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  PERFORM alv_grid_display   USING 'GO_GRID_ITM_VAL'.
  PERFORM alv_outtab_display USING 'GO_GRID_ITM_VAL'.
  go_grid_itm_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  go_grid_itm_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  PERFORM alv_grid_display   USING 'GO_GRID_CND_VAL'.
  PERFORM alv_outtab_display USING 'GO_GRID_CND_VAL'.
  go_grid_cnd_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  go_grid_cnd_val->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  cl_gui_cfw=>flush( ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_alv_layout_0202
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM build_alv_layout_0202.
  STATICS: sv_first_call TYPE abap_bool VALUE abap_true.
  DATA: ls_stable TYPE lvc_s_stbl.

  " --- 1. REFRESH (Dùng biến _SUC) ---
  IF go_grid_hdr_suc IS BOUND AND go_grid_itm_suc IS BOUND AND go_grid_cnd_suc IS BOUND.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.

    go_grid_hdr_suc->refresh_table_display( is_stable = ls_stable ).
    go_grid_itm_suc->refresh_table_display( is_stable = ls_stable ).
    go_grid_cnd_suc->refresh_table_display( is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " --- 2. Free Controls ---
  IF go_grid_hdr_suc IS BOUND. go_grid_hdr_suc->free( ). CLEAR go_grid_hdr_suc. ENDIF.
  IF go_grid_itm_suc IS BOUND. go_grid_itm_suc->free( ). CLEAR go_grid_itm_suc. ENDIF.
  IF go_grid_cnd_suc IS BOUND. go_grid_cnd_suc->free( ). CLEAR go_grid_cnd_suc. ENDIF.

  " --- 3. Khởi tạo Container (Giữ nguyên logic Splitter) ---
  DATA: lo_main_container TYPE REF TO cl_gui_custom_container,
        lo_split_main     TYPE REF TO cl_gui_splitter_container,
        lo_split_sub      TYPE REF TO cl_gui_splitter_container.

  sv_first_call = abap_false.

  CREATE OBJECT lo_main_container EXPORTING container_name = 'CC_ALV_SUCCESS'.
  IF sy-subrc <> 0. RETURN. ENDIF.

  CREATE OBJECT lo_split_main EXPORTING parent = lo_main_container rows = 2 columns = 1.
  lo_split_main->set_row_height( id = 1 height = 40 ).

  DATA(lo_cont_top) = lo_split_main->get_container( row = 1 column = 1 ).
  DATA(lo_cont_bot) = lo_split_main->get_container( row = 2 column = 1 ).

  CREATE OBJECT lo_split_sub EXPORTING parent = lo_cont_bot rows = 1 columns = 2.
  lo_split_sub->set_column_width( id = 1 width = 60 ).

  DATA(lo_cont_itm) = lo_split_sub->get_container( row = 1 column = 1 ).
  DATA(lo_cont_cond) = lo_split_sub->get_container( row = 1 column = 2 ).

  " --- 4. Tạo Objects ALV Grid (Dùng biến _SUC) ---
  CREATE OBJECT go_grid_hdr_suc EXPORTING i_parent = lo_cont_top.
  CREATE OBJECT go_grid_itm_suc EXPORTING i_parent = lo_cont_itm.
  CREATE OBJECT go_grid_cnd_suc EXPORTING i_parent = lo_cont_cond.

  " --- 5. Hiển thị (Dùng tên Grid _SUC) ---
  PERFORM alv_grid_display   USING 'GO_GRID_HDR_SUC'.
  PERFORM alv_outtab_display USING 'GO_GRID_HDR_SUC'.

  PERFORM alv_grid_display   USING 'GO_GRID_ITM_SUC'.
  PERFORM alv_outtab_display USING 'GO_GRID_ITM_SUC'.

  PERFORM alv_grid_display   USING 'GO_GRID_CND_SUC'.
  PERFORM alv_outtab_display USING 'GO_GRID_CND_SUC'.

  cl_gui_cfw=>flush( ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_alv_layout_0203
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM build_alv_layout_0203.
  STATICS: sv_first_call TYPE abap_bool VALUE abap_true.
  DATA: ls_stable TYPE lvc_s_stbl.

  " --- 1. REFRESH (Dùng biến _FAIL) ---
  IF go_grid_hdr_fail IS BOUND AND go_grid_itm_fail IS BOUND AND go_grid_cnd_fail IS BOUND.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.

    go_grid_hdr_fail->refresh_table_display( is_stable = ls_stable ).
    go_grid_itm_fail->refresh_table_display( is_stable = ls_stable ).
    go_grid_cnd_fail->refresh_table_display( is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " --- 2. Free Controls ---
  IF go_grid_hdr_fail IS BOUND. go_grid_hdr_fail->free( ). CLEAR go_grid_hdr_fail. ENDIF.
  IF go_grid_itm_fail IS BOUND. go_grid_itm_fail->free( ). CLEAR go_grid_itm_fail. ENDIF.
  IF go_grid_cnd_fail IS BOUND. go_grid_cnd_fail->free( ). CLEAR go_grid_cnd_fail. ENDIF.

  " --- 3. Khởi tạo Container ---
  DATA: lo_main_container TYPE REF TO cl_gui_custom_container,
        lo_split_main     TYPE REF TO cl_gui_splitter_container,
        lo_split_sub      TYPE REF TO cl_gui_splitter_container.

  sv_first_call = abap_false.

  CREATE OBJECT lo_main_container EXPORTING container_name = 'CC_ALV_FAILED'.
  IF sy-subrc <> 0. RETURN. ENDIF.

  CREATE OBJECT lo_split_main EXPORTING parent = lo_main_container rows = 2 columns = 1.
  lo_split_main->set_row_height( id = 1 height = 40 ).

  DATA(lo_cont_top) = lo_split_main->get_container( row = 1 column = 1 ).
  DATA(lo_cont_bot) = lo_split_main->get_container( row = 2 column = 1 ).

  CREATE OBJECT lo_split_sub EXPORTING parent = lo_cont_bot rows = 1 columns = 2.
  lo_split_sub->set_column_width( id = 1 width = 60 ).

  DATA(lo_cont_itm) = lo_split_sub->get_container( row = 1 column = 1 ).
  DATA(lo_cont_cond) = lo_split_sub->get_container( row = 1 column = 2 ).

  " --- 4. Tạo Objects ALV Grid (Dùng biến _FAIL) ---
  CREATE OBJECT go_grid_hdr_fail EXPORTING i_parent = lo_cont_top.
  CREATE OBJECT go_grid_itm_fail EXPORTING i_parent = lo_cont_itm.
  CREATE OBJECT go_grid_cnd_fail EXPORTING i_parent = lo_cont_cond.

  " --- 5. Hiển thị (Dùng tên Grid _FAIL) ---
  PERFORM alv_grid_display   USING 'GO_GRID_HDR_FAIL'.
  PERFORM alv_outtab_display USING 'GO_GRID_HDR_FAIL'.
  GO_GRID_HDR_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  GO_GRID_HDR_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  PERFORM alv_grid_display   USING 'GO_GRID_ITM_FAIL'.
  PERFORM alv_outtab_display USING 'GO_GRID_ITM_FAIL'.
  GO_GRID_ITM_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  GO_GRID_ITM_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  PERFORM alv_grid_display   USING 'GO_GRID_CND_FAIL'.
  PERFORM alv_outtab_display USING 'GO_GRID_CND_FAIL'.
  GO_GRID_CND_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  GO_GRID_CND_FAIL->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  cl_gui_cfw=>flush( ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form REFRESH_ALL_ALVS
*&---------------------------------------------------------------------*
*& Refreshes the display of all active ALV grids on Screen 200 tabs.
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form REFRESH_ALL_ALVS (Cập nhật cho 3 Tab Mới + Condition)
*&---------------------------------------------------------------------*
FORM refresh_all_alvs.
  DATA: ls_stable TYPE lvc_s_stbl.

  " Cấu hình giữ nguyên vị trí con trỏ/thanh cuộn khi refresh (UX tốt hơn)
  ls_stable-row = abap_true.
  ls_stable-col = abap_true.

  " --- 1. Tab Validated (Sửa tên biến cho khớp với TOP) ---
  IF go_grid_hdr_val IS BOUND.
    go_grid_hdr_val->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_itm_val IS BOUND.
    go_grid_itm_val->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_cnd_val IS BOUND. " [MỚI] Condition
    go_grid_cnd_val->refresh_table_display( is_stable = ls_stable ).
  ENDIF.

  " --- 2. Tab Posted Success ---
  IF go_grid_hdr_suc IS BOUND.
    go_grid_hdr_suc->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_itm_suc IS BOUND.
    go_grid_itm_suc->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_cnd_suc IS BOUND. " [MỚI] Condition
    go_grid_cnd_suc->refresh_table_display( is_stable = ls_stable ).
  ENDIF.

  " --- 3. Tab Posted Failed ---
  IF go_grid_hdr_fail IS BOUND.
    go_grid_hdr_fail->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_itm_fail IS BOUND.
    go_grid_itm_fail->refresh_table_display( is_stable = ls_stable ).
  ENDIF.
  IF go_grid_cnd_fail IS BOUND. " [MỚI] Condition
    go_grid_cnd_fail->refresh_table_display( is_stable = ls_stable ).
  ENDIF.

  " Đẩy cập nhật ra màn hình ngay lập tức
  cl_gui_cfw=>flush( ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form DISPLAY_RESULT_POPUP_ALV
*&---------------------------------------------------------------------*
*& Hiển thị bảng gt_result trong một ALV popup (dùng SLIS)
*&---------------------------------------------------------------------*
FORM display_result_popup_alv.

  IF gt_result IS INITIAL.
    MESSAGE 'Processing complete. No results to display.' TYPE 'I'.
    RETURN.
  ENDIF.

  " 1. Tạo Field Catalog (SLIS) cho popup
  REFRESH gt_fieldcat_popup. " <<< SỬA: Dùng biến POPUP

  " --- SỬA Ở ĐÂY ---
  " Gọi FORM build thủ công thay vì FM merge
  PERFORM build_popup_fieldcat_slis CHANGING gt_fieldcat_popup.
  " --- HẾT SỬA ---

  " --- Tùy chỉnh độ rộng cột Message ---
  READ TABLE gt_fieldcat_popup ASSIGNING FIELD-SYMBOL(<fs_fcat>)
                           WITH KEY fieldname = 'MESSAGE'.
  IF sy-subrc = 0.
    <fs_fcat>-outputlen = 100. " Tăng độ rộng
  ENDIF.

  " 2. Đặt thông tin cho Popup
  DATA: ls_popup_layout TYPE slis_layout_alv.
  ls_popup_layout-window_titlebar = 'Sales Order Creation Results'.
  ls_popup_layout-colwidth_optimize = 'X'.

  " 3. Gọi ALV Grid ở chế độ Popup
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program    = sy-repid
      is_layout             = ls_popup_layout
      it_fieldcat           = gt_fieldcat_popup " <<< SỬA: Dùng biến POPUP
      i_screen_start_column = 10
      i_screen_start_line   = 5
      i_screen_end_column   = 150
      i_screen_end_line     = 20
    TABLES
      t_outtab              = gt_result
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
  IF sy-subrc <> 0.
    MESSAGE 'Error displaying results ALV popup.' TYPE 'E'.
  ENDIF.

ENDFORM.
**&---------------------------------------------------------------------*
**& Form HIGHLIGHT_ERROR_CELLS
**&---------------------------------------------------------------------*
**& Updates the STYLE field in classified tables based on error list.
**&---------------------------------------------------------------------*
*FORM highlight_error_cells USING it_errors TYPE TABLE OF ty_validation_error.
*
*  " --- FIX: Define local table with specific type ---
*  DATA: lt_local_errors TYPE STANDARD TABLE OF ty_validation_error WITH EMPTY KEY.
*  lt_local_errors = it_errors. " Assign generic parameter to specific table
*
*  FIELD-SYMBOLS: <error>   LIKE LINE OF lt_local_errors,
*                 <header>  LIKE LINE OF gt_so_header, " Use base type
*                 <item>    LIKE LINE OF gt_so_item.   " Use base type
*
*  DATA: ls_style TYPE lvc_s_styl,
*        lt_style TYPE lvc_t_styl.
*
*  LOOP AT lt_local_errors ASSIGNING <error>.
*    CLEAR lt_style.
*    ls_style-fieldname = <error>-fieldname.
*    ls_style-style = cl_gui_alv_grid=>mc_style_enabled + " Base style
*                     cl_gui_alv_grid=>mc_style_background +
*                     cl_gui_alv_grid=>mc_style_int_negative. " Red background
*    APPEND ls_style TO lt_style.
*
*    IF <error>-item_no IS INITIAL. " Header Error
*      " Check all 3 header tables
*      READ TABLE gt_so_header_comp ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*      READ TABLE gt_so_header_incomp ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*      READ TABLE gt_so_header_err ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*    ELSE. " Item Error
*      " Check all 3 item tables
*      READ TABLE gt_so_item_comp ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      READ TABLE gt_so_item_incomp ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      READ TABLE gt_so_item_err ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*    ELSE.
*       " Header error, not yet found
*       READ TABLE gt_so_header_err ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*       IF sy-subrc = 0.
*         INSERT LINES OF lt_style INTO TABLE <header>-style.
*       ELSE.
*          " Item error, not yet found
*          READ TABLE gt_so_item_err ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*           IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*       ENDIF.
*    ENDIF.
*  ENDLOOP.
*ENDFORM.


**&---------------------------------------------------------------------*
**& Form HIGHLIGHT_ERROR_CELLS
**&---------------------------------------------------------------------*
*FORM highlight_error_cells USING it_errors TYPE ty_t_validation_error. " <<< CHANGE: Use specific table type
*
**  " --- FIX: Define local table with specific type ---
**  DATA: lt_local_errors TYPE STANDARD TABLE OF ty_validation_error WITH EMPTY KEY.
**  lt_local_errors = it_errors. " Assign generic parameter to specific table
*
*  FIELD-SYMBOLS: <error>   LIKE LINE OF it_errors, " <<< LIKE LINE OF works with specific type
*                 <header>  LIKE LINE OF gt_so_header,
*                 <item>    LIKE LINE OF gt_so_item.
*
*  DATA: ls_style TYPE lvc_s_styl,
*        lt_style TYPE lvc_t_styl.
*
*  " --- Use the local table in the LOOP ---
*  LOOP AT it_errors ASSIGNING <error>.
*    CLEAR lt_style.
*    ls_style-fieldname = <error>-fieldname.
*    ls_style-style = cl_gui_alv_grid=>mc_style_enabled.
**                     cl_gui_alv_grid=>mc_style_background +
**                     cl_gui_alv_grid=>mc_style_int_negative.
*    APPEND ls_style TO lt_style.
*
*    IF <error>-item_no IS INITIAL. " Header Error
*      " Check all 3 header tables
*      READ TABLE gt_so_header_comp ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*      READ TABLE gt_so_header_incomp ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*      READ TABLE gt_so_header_err ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <header>-style. ENDIF.
*    ELSE. " Item Error
*      " Check all 3 item tables
*      READ TABLE gt_so_item_comp ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      READ TABLE gt_so_item_incomp ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      READ TABLE gt_so_item_err ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      " --- REMOVED REDUNDANT ELSE BLOCK ---
*      " ELSE. " This block was likely redundant or misplaced
*      "  " Header error, not yet found
*      "  READ TABLE gt_so_header_err ASSIGNING <header> WITH KEY temp_id = <error>-temp_id.
*      "  IF sy-subrc = 0.
*      "    INSERT LINES OF lt_style INTO TABLE <header>-style.
*      "  ELSE.
*      "     " Item error, not yet found
*      "     READ TABLE gt_so_item_err ASSIGNING <item> WITH KEY temp_id = <error>-temp_id item_no = <error>-item_no.
*      "      IF sy-subrc = 0. INSERT LINES OF lt_style INTO TABLE <item>-style. ENDIF.
*      "  ENDIF.
*      " ENDIF.
*    ENDIF.
*  ENDLOOP.
*ENDFORM.
**&---------------------------------------------------------------------*
**& Form ALV_FIELDCATALOG_SINGLE_ITEM
**&---------------------------------------------------------------------*
**& Field Catalog cho ALV Single Entry Item (Screen 0112)
**&---------------------------------------------------------------------*
*FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  REFRESH pt_fieldcat.
*
**  " Macro riêng: &1=Fieldname, &2=Just, &3=Coltext, &4=Edit Flag
**  DEFINE _add_field.
**    CLEAR ls_fcat.
**    ls_fcat-fieldname = &1.
**    ls_fcat-just      = &2.
**    ls_fcat-coltext   = &3.
**    ls_fcat-seltext   = &3.
**    ls_fcat-edit      = &4. " abap_true / abap_false
**    APPEND ls_fcat TO pt_fieldcat.
**  END-OF-DEFINITION.
*
*  DEFINE _add_field.
*  CLEAR ls_fcat.
*  ls_fcat-fieldname  = &1.
*  ls_fcat-just       = &2.
*  ls_fcat-coltext    = &3.
*  ls_fcat-seltext    = &3.
*  ls_fcat-edit       = &4.
*  ls_fcat-ref_table  = 'TY_SINGLE_ITEM'. " <<< THÊM: Tham chiếu cấu trúc
*  ls_fcat-ref_field  = &1.              " <<< THÊM: Tham chiếu trường
*  " --- THÊM 2 DÒNG SAU CHO SỐ LƯỢNG VÀ GIÁ TRỊ ---
*  ls_fcat-qfieldname = &5. " &5 = Tên cột Đơn vị (Unit)
*  ls_fcat-cfieldname = &6. " &6 = Tên cột Tiền tệ (Currency)
*  APPEND ls_fcat TO pt_fieldcat.
*END-OF-DEFINITION.
*
*  " Fieldname         Just  Coltext                Edit Flag
*  _add_field:
**    'ITEM'            'R' 'Item'                 abap_false, " Output
**    'MATERIAL'        'L' 'Material'             abap_true,  " Input
**    'DESCRIPTION'     'L' 'Description'          abap_false, " Output
**    'HI_LVL_ITEM'     'R' 'Higher-level item'    abap_false, " Output
**    'UNIT'            'L' 'Sales Unit'           abap_true,  " Defaulted
**    'QUANTITY'        'R' 'Order Quantity'       abap_true,  " Input
**    'CONF_QTY'        'R' 'Confirmed quantity'   abap_false, " Output
*
*  'ITEM'            'R' 'Item'                  abap_false ''       '',
*  'MATERIAL'        'L' 'Material'              abap_true  ''       '',
*  'DESCRIPTION'     'L' 'Description'           abap_false ''       '',
*  'HI_LVL_ITEM'     'R' 'Higher-level item'     abap_false ''       '',
*  'UNIT'            'L' 'Sales Unit'            abap_true  ''       '',
*  'QUANTITY'        'R' 'Order Quantity'        abap_true  'UNIT'   '', " <<< SỬA: Tham chiếu 'UNIT'
*  'CONF_QTY'        'R' 'Confirmed quantity'    abap_false 'UNIT'   '', " <<< SỬA: Tham chiếu 'UNIT'
*
*    'ITCA'            'L' 'Itca'                 abap_false, " Output
*    'COND_TYPE'       'L' 'CnTy'                 abap_true,  " Optional Input
*    'REQ_DATE'        'C' 'Delivery Date'        abap_true,  " Defaulted
*    'PLANT'           'L' 'Plant'                abap_true,  " Defaulted
*    'SHIP_POINT'      'L' 'Shipping point'       abap_false, " Output
*    'STORE_LOC'       'L' 'Storage location'     abap_true,  " Defaulted
**    'UNIT_PRICE'      'R' 'Amount'               abap_true,  " Optional Input
**    'PER'             'R' 'Per'                  abap_true,  " Optional Input
**    'NET_PRICE'       'R' 'Net price'            abap_false, " Output
**    'OVERALL_STATUS'  'L' 'Overall status'       abap_false, " Output
**    'NET_VALUE'       'R' 'Total Net Value'      abap_false, " Output
**    'TAX'             'R' 'Tax'                  abap_false. " Output
*
*     'UNIT_PRICE'      'R' 'Amount'               abap_true  ''       'CURRENCY', " <<< SỬA: Tham chiếu 'CURRENCY'
*     'PER'             'R' 'Per'                  abap_true  ''       '',
*     'NET_PRICE'       'R' 'Net price'            abap_false ''       'CURRENCY', " <<< SỬA
*     'OVERALL_STATUS'  'L' 'Overall status'       abap_false            , " Output
*     'NET_VALUE'       'R' 'Total Net Value'      abap_false ''       'CURRENCY', " <<< SỬA
*     'TAX'             'R' 'Tax'                  abap_false ''       'CURRENCY'. " <<< SỬA
*
*ENDFORM.

**&---------------------------------------------------------------------*
**& Form ALV_FIELDCATALOG_SINGLE_ITEM (ĐÃ CẬP NHẬT)
**&---------------------------------------------------------------------*
*FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  REFRESH pt_fieldcat.
*
*  " Macro mới: &1=Fieldname, &2=Just, &3=Coltext, &4=Edit,
*  "            &5=QField (Cột Unit), &6=CField (Cột Currency)
*  DEFINE _add_field.
*    CLEAR ls_fcat.
*    ls_fcat-fieldname  = &1.
*    ls_fcat-just       = &2.
*    ls_fcat-coltext    = &3.
*    ls_fcat-seltext    = &3.
*    ls_fcat-edit       = &4. " abap_true / abap_false
**    ls_fcat-ref_table  = 'TY_SINGLE_ITEM'. " Tham chiếu đến cấu trúc
*    ls_fcat-ref_table = 'gt_item_details'.
*    ls_fcat-qfieldname = &5. " Tham chiếu cột Quantity (UoM)
*    ls_fcat-cfieldname = &6. " Tham chiếu cột Currency
*    APPEND ls_fcat TO pt_fieldcat.
*  END-OF-DEFINITION.
*
*  " Fieldname         Just  Coltext                Edit Flag  QField   CField
*  _add_field:
*    'ITEM_NO'         'R' 'Item'                 abap_false ''       '',
*    'MATERIAL'        'L' 'Material'             abap_true  ''       '',
*    'DESCRIPTION'     'L' 'Description'          abap_false ''       '',
*    'HI_LVL_ITEM'     'R' 'Higher-level item'    abap_false ''       '',
*    'UNIT'            'L' 'Sales Unit'           abap_true  ''       '',
*    'QUANTITY'        'R' 'Order Quantity'       abap_true  'UNIT'   '', " <<< SỬA
*    'CONF_QTY'        'R' 'Confirmed quantity'   abap_false 'UNIT'   '', " <<< SỬA
*    'ITCA'            'L' 'Itca'                 abap_false ''       '',
*    'COND_TYPE'       'L' 'CnTy'                 abap_true  ''       '',
*    'REQ_DATE'        'C' 'Delivery Date'        abap_true  ''       '',
*    'PLANT'           'L' 'Plant'                abap_true  ''       '',
*    'SHIP_POINT'      'L' 'Shipping point'       abap_false ''       '',
*    'STORE_LOC'       'L' 'Storage location'     abap_true  ''       '',
*    'UNIT_PRICE'      'R' 'Amount'               abap_true  ''       'CURRENCY', " <<< SỬA
*    'PER'             'R' 'Per'                  abap_true  ''       '',
*    'NET_PRICE'       'R' 'Net price'            abap_false ''       'CURRENCY', " <<< SỬA
*    'OVERALL_STATUS'  'L' 'Overall status'       abap_false ''       '',
*    'NET_VALUE'       'R' 'Total Net Value'      abap_false ''       'CURRENCY', " <<< SỬA
*    'TAX'             'R' 'Tax'                  abap_false ''       'CURRENCY', " <<< SỬA
*    'CURRENCY'        'L' 'Currency'             abap_false ''       ''. " <<< THÊM (Có thể ẩn)
*
*ENDFORM.

*FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  REFRESH pt_fieldcat.
*
*  " &1=fieldname &2=just &3=coltext &4=edit &5=qfield &6=cfield &7=ref_tab &8=ref_fld
*  DEFINE _add.
*    CLEAR ls_fcat.
*    ls_fcat-fieldname   = &1.
*    ls_fcat-just        = &2.
*    ls_fcat-coltext     = &3.
*    ls_fcat-seltext     = &3.
*    ls_fcat-edit        = &4.                " abap_true/abap_false
**    ls_fcat-qfieldname  = &5.                " UNIT ref
**    ls_fcat-cfieldname  = &6.                " CURRENCY ref
**    ls_fcat-ref_table   = &7.                " <-- DDIC ref is MUST for TYPES
**    ls_fcat-ref_field   = &8.
*
*     " Kiểm tra nếu có QFIELDNAME/CURRENCY field thì mới gán
**    IF &5 <> ''.
**      ls_fcat-qfieldname = &5.
**    ENDIF.
**
**    IF &6 <> ''.
**      ls_fcat-cfieldname = &6.
**  ENDIF.
*
*    APPEND ls_fcat TO pt_fieldcat.
*  END-OF-DEFINITION.
*
*  "  Fieldname       J  Text                 Edit     QField  CField     ref_tab  ref_fld
**  _add:
**  'ITEM_NO'         'R' 'Item'               abap_false ''     ''         'VBAP'   'POSNR',
**  'MATNR'        'L' 'Material'              abap_true  ''     ''         'VBAP'   'MATNR',
**  'DESCRIPTION'     'L' 'Description'        abap_false ''     ''         'MAKT'   'MAKTX',
**  'HI_LVL_ITEM'     'R' 'Higher-level item'  abap_false ''     ''         'VBAP'   'UEPOS',
**
**  " Unit & Quantity (qfieldname->UNIT, UNIT must have UNIT type)
**  'UNIT'            'L' 'Sales Unit'         abap_true  ''     ''         'MARA'   'MEINS',
**  'QUANTITY'        'R' 'Order Quantity'     abap_true  'UNIT' ''         'VBAP'   'KWMENG',
**  'CONF_QTY'        'R' 'Confirmed quantity' abap_false 'UNIT' ''         'VBEP'   'BMENG',
**
**  " Item Category
**  'ITCA'            'L' 'Itca'               abap_false ''     ''         'VBAP'   'PSTYV',
**
**  " Dates/plant/loc
**  'COND_TYPE'       'L' 'CnTy'               abap_true  ''     ''         'BAPICOND' 'COND_TYPE',
**  'REQ_DATE'        'C' 'Delivery date'      abap_true  ''     ''         'VBEP'   'EDATU',
**  'PLANT'           'L' 'Plant'              abap_true  ''     ''         'VBAP'   'WERKS',
**  'SHIP_POINT'      'L' 'Shipping point'     abap_false ''     ''         'VBAP'   'VSTEL',
**  'STORE_LOC'       'L' 'Storage location'   abap_true  ''     ''         'VBAP'   'LGORT',
**
**  " Prices/values (cfieldname->CURRENCY, CURRENCY must be CUKY)
***  'UNIT_PRICE'      'R' 'Amount'             abap_true  ''     'CURRENCY' 'KONV'   'KBETR',   " hoặc ZTB... nếu DDIC của bạn là CURR
**  'UNIT_PRICE'      'R' 'Amount'             abap_true  ''     ''         ''       '',
**  'PER'             'R' 'Per'                abap_true  ''     ''         'KONV'   'KPEIN',
**  'NET_PRICE'       'R' 'Net price'          abap_false ''     'CURRENCY' 'VBAP'   'NETPR',
**  'OVERALL_STATUS'  'L' 'Overall status'     abap_false ''     ''         'VBUP'   'GBSTA',
**  'NET_VALUE'       'R' 'Total Net Value'    abap_false ''     'CURRENCY' 'VBAP'   'NETWR',
**  'TAX'             'R' 'Tax'                abap_false ''     'CURRENCY' 'KOMV'   'MWSKZ',   " nếu bạn lưu tiền thuế → dùng WRBTR phù hợp
**
**  " Currency key (CUKY) – có thể ẩn nhưng PHẢI có trong fieldcat
**  'CURRENCY'        'L' 'Currency'           abap_false ''     ''         'VBAK'   'WAERK'.
*
*   _add:
*    'ITEM_NO'        'R' 'Item'                abap_false  ,
*    'MATNR'          'L' 'Material'            abap_true  ,
*    'DESCRIPTION'    'L' 'Description'         abap_false  ,
*    'HI_LVL_ITEM'    'R' 'Higher-level item'   abap_false  ,
*    'UNIT'           'L' 'Sales Unit'          abap_true   ,
*    'QUANTITY'       'R' 'Order Quantity'      abap_true  , " nếu bạn không dùng QFIELDNAME nữa
*    'CONF_QTY'       'R' 'Confirmed quantity'  abap_false  ,
*    'ITCA'           'L' 'Itca'                abap_false  ,
*    'COND_TYPE'      'L' 'Cond. Type'          abap_true   ,
*    'REQ_DATE'       'C' 'Delivery date'       abap_true   ,
*    'PLANT'          'L' 'Plant'               abap_true   ,
*    'SHIP_POINT'     'L' 'Shipping point'      abap_false  ,
*    'STORE_LOC'      'L' 'Storage location'    abap_true   ,
*    'UNIT_PRICE'     'R' 'Amount'              abap_true   ,
*    'PER'            'R' 'Per'                 abap_true  ,
*    'NET_PRICE'      'R' 'Net price'           abap_false  ,
*    'OVERALL_STATUS' 'L' 'Overall status'      abap_false  .
*
*
*ENDFORM.

**&---------------------------------------------------------------------*
**& Form ALV_FIELDCATALOG_SINGLE_ITEM (ĐÃ SỬA LẠI HOÀN CHỈNH)
**&---------------------------------------------------------------------*
**FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
**  DATA ls_fcat TYPE lvc_s_fcat.
**  REFRESH pt_fieldcat.
**
**   SỬA LẠI MACRO: Thêm &5 (QField), &6 (CField), &7 (RefTab), &8 (RefFld)
**  DEFINE _add.
**    CLEAR ls_fcat.
**    ls_fcat-fieldname   = &1.
**    ls_fcat-just        = &2.
**    ls_fcat-coltext     = &3.
**    ls_fcat-seltext     = &3.
**    ls_fcat-edit        = &4.
**    ls_fcat-qfieldname  = &5.  " <<< THÊM LẠI: Tham chiếu cột Quantity (UoM)
**    ls_fcat-cfieldname  = &6.  " <<< THÊM LẠI: Tham chiếu cột Currency
**    ls_fcat-ref_table   = &7.  " <<< THÊM LẠI: Tham chiếu Bảng DDIC
**    ls_fcat-ref_field   = &8.  " <<< THÊM LẠI: Tham chiếu Trường DDIC
**    APPEND ls_fcat TO pt_fieldcat.
**  END-OF-DEFINITION.
**
**   Fieldname        Just  Coltext                Edit        QField  CField      RefTab      RefFld
**  _add:
**    'ITEM_NO'        'R'   'Item'                 abap_false  ''      ''          'VBAP'      'POSNR',
**    'MATNR'          'L'   'Material'             abap_true   ''      ''          'VBAP'      'MATNR',
**    'DESCRIPTION'    'L'   'Description'          abap_false  ''      ''          'MAKT'      'MAKTX',
**    'HI_LVL_ITEM'    'R'   'Higher-level item'    abap_false  ''      ''          'VBAP'      'UEPOS',
**    'UNIT'           'L'   'Sales Unit'           abap_true   ''      ''          'VBAP'      'VRKME',
**    'QUANTITY'       'R'   'Order Quantity'       abap_true   'UNIT'  ''          'VBAP'      'KWMENG',
**    'CONF_QTY'       'R'   'Confirmed quantity'   abap_false  'UNIT'  ''          'VBEP'      'BMENG',
**    'ITCA'           'L'   'Itca'                 abap_false  ''      ''          'VBAP'      'PSTYV',
**    'COND_TYPE'      'L'   'Cond. Type'           abap_true   ''      ''          'BAPICOND'  'COND_TYPE',
**    'REQ_DATE'       'C'   'Delivery date'        abap_true   ''      ''          'VBEP'      'EDATU',
**    'PLANT'          'L'   'Plant'                abap_true   ''      ''          'VBAP'      'WERKS',
**    'SHIP_POINT'     'L'   'Shipping point'       abap_false  ''      ''          'VBAP'      'VSTEL',
**    'STORE_LOC'      'L'   'Storage location'     abap_true   ''      ''          'VBAP'      'LGORT',
**    'UNIT_PRICE'     'R'   'Amount'               abap_true   ''      'CURRENCY'  'KONV'      'KBETR',
**    'PER'            'R'   'Per'                  abap_true   ''      ''          'KONV'      'KPEIN',
**    'NET_PRICE'      'R'   'Net price'            abap_false  ''      'CURRENCY'  'VBAP'      'NETPR',
**    'OVERALL_STATUS' 'L'   'Overall status'       abap_false  ''      ''          'VBUP'      'GBSTA'.
**     --- THÊM CỘT CURRENCY (BẮT BUỘC NẾU DÙNG CFIELDNAME = 'CURRENCY') ---
**     Cột này phải tồn tại trong 'ty_single_item' và trong fieldcat.
**     Bạn có thể ẩn nó đi nếu không muốn user thấy bằng cách thêm ls_fcat-no_out = 'X' vào macro.
**  _add:
**    'CURRENCY'       'L'   'Currency'             abap_false  ''      ''          'VBAK'      'WAERK'.
**
**ENDFORM.

**&---------------------------------------------------------------------*
**& Form ALV_FIELDCATALOG_SINGLE_ITEM (THEO FORMAT MỚI)
**&---------------------------------------------------------------------*
*FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  REFRESH pt_fieldcat.
*
*  " --- Macro GIỐNG HỆT _01/_02 (nhưng không có edit_mask) ---
*  " &1 = Fieldname, &2 = Just, &3 = Coltext, &4 = FixCol
*  DEFINE _add_fieldcat.
*    CLEAR ls_fcat.
*    ls_fcat-edit       = COND #( WHEN gs_edit = abap_true THEN 'X' ELSE space ).
*    " Edit-mode sẽ được control bằng `set_ready_for_input = 1`
*    " và `gs_layout-edit = 'X'` (trong build_alv_layout_single_item)
*    " ls_fcat-edit      = abap_true. " <-- Chúng ta set edit cho từng cột
*    ls_fcat-fieldname   = &1.
*    ls_fcat-just        = &2.
*    ls_fcat-coltext     = &3.
*    ls_fcat-seltext     = &3.
*    ls_fcat-tooltip     = &3.
*    ls_fcat-fix_column  = &4.
*    " --- ĐỒNG BỘ: Dùng Z-table mới làm tham chiếu ---
*    ls_fcat-ref_table   = 'ZTB_SO_ITEM_SING'.
*    ls_fcat-ref_field   = &1. " Tên trường Z-table = Tên fieldname
*
*    " === SỬA LẠI: Gán edit-flag thủ công (vì _01/_02 dùng gs_edit) ===
*    CASE &1.
*      " Các trường user được phép nhập
*      WHEN 'MATNR' OR 'UNIT' OR 'QUANTITY' OR 'COND_TYPE' OR
*           'REQ_DATE' OR 'PLANT' OR 'STORE_LOC' OR
*           'UNIT_PRICE' OR 'PER'.
*        ls_fcat-edit = abap_true.
*      " Các trường auto-fill hoặc output-only
*      WHEN OTHERS.
*        ls_fcat-edit = abap_false.
*    ENDCASE.
*
*    APPEND ls_fcat TO pt_fieldcat.
*  END-OF-DEFINITION.
*
*  " --- Fieldname         Just  Coltext                FixCol ---
*  _add_fieldcat:
*    'ITEM_NO'         'R'   'Item'                 abap_false,
*    'MATNR'           'L'   'Material'             abap_false,
*    'DESCRIPTION'     'L'   'Description'          abap_false,
*    'HI_LVL_ITEM'     'R'   'Higher-level item'    abap_false,
*    'UNIT'            'L'   'Sales Unit'           abap_false,
*    'QUANTITY'        'R'   'Order Quantity'       abap_false,
*    'CONF_QTY'        'R'   'Confirmed quantity'   abap_false,
*    'ITCA'            'L'   'Itca'                 abap_false,
*    'COND_TYPE'       'L'   'Cond. Type'           abap_false,
*    'REQ_DATE'        'C'   'Delivery date'        abap_false,
*    'PLANT'           'L'   'Plant'                abap_false,
*    'SHIP_POINT'      'L'   'Shipping point'       abap_false,
*    'STORE_LOC'       'L'   'Storage location'     abap_false,
*    'UNIT_PRICE'      'R'   'Amount'               abap_false,
*    'PER'             'R'   'Per'                  abap_false,
*    'NET_PRICE'       'R'   'Net price'            abap_false,
*    'OVERALL_STATUS'  'L'   'Overall status'       abap_false,
**    'CURRENCY'        'L'   'Currency'             abap_false.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_SINGLE_ITEM (ĐÃ ĐỒNG BỘ)
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " --- Macro ĐỒNG BỘ (giống hệt _01/_02) ---
  " &1 = Fieldname
  " &2 = Just
  " &3 = Col_Opt (Optimize width)
  " &4 = Coltext (Text)
  " &5 = Fix_Column
  " &6 = Edit_Mask
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
*    ls_fcat-edit       = COND #( WHEN gs_edit = abap_true THEN 'X' ELSE space ).
    ls_fcat-fieldname   = &1.
    ls_fcat-just        = &2.
    ls_fcat-col_opt     = &3.  " <<< THÊM: Tối ưu độ rộng cột
    ls_fcat-coltext     = &4.
    ls_fcat-seltext     = &4.  " <<< THÊM: Đồng bộ text
    ls_fcat-tooltip     = &4.  " <<< THÊM: Đồng bộ text
    ls_fcat-scrtext_l   = &4.  " <<< THÊM: Đồng bộ text
    ls_fcat-scrtext_m   = &4.  " <<< THÊM: Đồng bộ text
    ls_fcat-scrtext_s   = &4.  " <<< THÊM: Đồng bộ text
    ls_fcat-fix_column  = &5.
    ls_fcat-ref_table   = 'ZTB_SO_ITEM_SING'. " (Tên Z-Table của bạn)
    ls_fcat-ref_field   = &1.
    ls_fcat-edit_mask   = &6.  " <<< THÊM: Edit Mask

    " <<< THÊM DÒNG NÀY ĐỂ TẮT CONVERSION EXIT >>>
    IF &1 = 'MATNR'.
      ls_fcat-no_convext = 'X'.
    ENDIF.

    " === Logic Edit (Giữ nguyên) ===
    CASE &1.
      " Các trường user được phép nhập
      WHEN 'MATNR' OR 'UNIT' OR 'QUANTITY' OR 'COND_TYPE' OR
           'REQ_DATE' OR 'PLANT' OR 'STORE_LOC' OR
           'UNIT_PRICE' OR 'PER'.
        ls_fcat-edit = abap_true.
      " Các trường auto-fill hoặc output-only
      WHEN OTHERS.
        ls_fcat-edit = abap_false.
    ENDCASE.

    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " --- Các lời gọi Macro (ĐÃ CẬP NHẬT 6 THAM SỐ) ---
  " Fieldname         Just  Opt       Coltext                FixCol      EditMask
  _add_fieldcat:
    'ITEM_NO'         'R'   abap_on   'Item'                 abap_off  '',
    'MATNR'           'L'   abap_on   'Material'             abap_off  '',
    'DESCRIPTION'     'L'   abap_on   'Description'          abap_off  '',
    'HI_LVL_ITEM'     'R'   abap_on   'Higher-level item'    abap_off  '',
    'UNIT'            'L'   abap_on   'Sales Unit'           abap_off  '',
    'QUANTITY'        'R'   abap_on   'Order Quantity'       abap_off  '',
    'CONF_QTY'        'R'   abap_on   'Confirmed quantity'   abap_off  '',
    'ITCA'            'L'   abap_on   'Itca'                 abap_off  '',
    'COND_TYPE'       'L'   abap_on   'Cond. Type'           abap_off  '',
    'REQ_DATE'        'C'   abap_on   'Delivery date'        abap_off  '__.__.____', " <<< THÊM MASK
    'PLANT'           'L'   abap_on   'Plant'                abap_off  '',
    'SHIP_POINT'      'L'   abap_on   'Shipping point'       abap_off  '',
    'STORE_LOC'       'L'   abap_on   'Storage location'     abap_off  '',
    'UNIT_PRICE'      'R'   abap_on   'Amount'               abap_off  '',
    'PER'             'R'   abap_on   'Per'                  abap_off  '',
    'NET_PRICE'       'R'   abap_on   'Net price'            abap_off  '',
    'OVERALL_STATUS'  'L'   abap_on   'Overall status'       abap_off  '',
    'CURRENCY'        'L'   abap_on   'Currency'             abap_off  ''.

ENDFORM.


**&---------------------------------------------------------------------*
**& Form BUILD_ALV_LAYOUT_SINGLE_ITEM
**&---------------------------------------------------------------------*
**& PBO logic cho Subscreen 0112 (Tab "Item Details" của Single Entry)
**&---------------------------------------------------------------------*
*FORM build_alv_layout_single_item.
*
*  " Chỉ tạo ALV lần đầu tiên
*  IF go_grid_item_single IS NOT BOUND.
*    DATA lo_cont TYPE REF TO cl_gui_custom_container.
*
*    " 1. Tạo Container
*    CREATE OBJECT lo_cont
*      EXPORTING
*        container_name = 'ALL_ITEMS' " <<< Tên Custom Control trên Subscreen 0112
*      EXCEPTIONS
*        OTHERS = 1.
*    IF sy-subrc <> 0.
*      MESSAGE 'Error creating container CC_ITEM_SINGLE.' TYPE 'E'.
*      RETURN.
*    ENDIF.
*
*    " 2. Tạo ALV Grid
*    CREATE OBJECT go_grid_item_single
*      EXPORTING
*        i_parent = lo_cont.
*
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_enter ).
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).
*
*
*    " 3. Chuẩn bị Field Catalog (Gọi dispatcher, dispatcher sẽ gọi FORM mới)
*    PERFORM alv_fieldcatalog_single_item CHANGING gt_fieldcat_item_single.
*
**    " 4. Chuẩn bị Layout
**    PERFORM alv_layout USING 'GO_GRID_ITEM_SINGLE'. " Sẽ set sel_mode = 'A', edit = 'X'
**    gs_layout-edit = abap_true. " Ép edit mode = ON
*
*        " 4. Chuẩn bị Layout
*    PERFORM alv_layout USING 'GO_GRID_ITEM_SINGLE'.
*      gs_layout-edit = abap_true.  " <<< MỞ LẠI DÒNG NÀY
*      " gs_layout-edit = abap_false. " <<< COMMENT DÒNG NÀY
*
*    " 5. Gắn Event Handler (cho CRUD)
*    IF go_event_handler_single IS NOT BOUND.
*       CREATE OBJECT go_event_handler_single
*         EXPORTING
*           io_grid  = go_grid_item_single
*           it_table = REF #( gt_item_details ).
*    ENDIF.
*    SET HANDLER:
*      go_event_handler_single->handle_user_command FOR go_grid_item_single,
*      go_event_handler_single->handle_toolbar      FOR go_grid_item_single,
*      go_event_handler_single->handle_data_changed FOR go_grid_item_single. " <<< THÊM DÒNG NÀY
*
*    SET HANDLER go_event_handler_single->handle_data_changed_finished FOR go_grid_item_single.
*
*
**      " --- THÊM LOGIC: Đảm bảo có ít nhất 1 dòng trống ban đầu ---
**    IF gt_item_details IS INITIAL.
**      APPEND INITIAL LINE TO gt_item_details.
**    ENDIF.
**    " --- KẾT THÚC THÊM LOGIC ---
*
*    " 6. Hiển thị ALV
*    CALL METHOD go_grid_item_single->set_table_for_first_display
*      EXPORTING
*        is_layout     = gs_layout
*      CHANGING
*        it_outtab     = gt_item_details
*        it_fieldcatalog = gt_fieldcat_item_single. " <<< Dùng fieldcat MỚI
*
*      " <<< THÊM DÒNG NÀY ĐỂ KÍCH HOẠT CHỨC NĂNG BẮT SỰ KIỆN >>>
*  CALL METHOD go_grid_item_single->set_ready_for_input
*    EXPORTING
*      i_ready_for_input = 1.
*  " <<< KẾT THÚC THÊM >>>
*
*    cl_gui_cfw=>flush( ).
*  ENDIF.
*ENDFORM.

**&---------------------------------------------------------------------*
**& Form BUILD_ALV_LAYOUT_SINGLE_ITEM (THEO CẤU TRÚC MỚI)
**&---------------------------------------------------------------------*
*FORM build_alv_layout_single_item.
*
*  " 1. Chỉ chạy 1 lần (để tạo control)
*  STATICS: sv_first_call TYPE abap_bool VALUE abap_true.
*  IF go_grid_item_single IS BOUND AND sv_first_call = abap_false.
*    RETURN.
*  ENDIF.
*
*  " 2. Hủy control cũ nếu có (để tránh lỗi khi quay lại)
*  IF go_grid_item_single IS BOUND.
*    go_grid_item_single->free( ).
*    CLEAR go_grid_item_single.
*  ENDIF.
*  IF go_event_handler_single IS BOUND.
*    FREE go_event_handler_single.
*  ENDIF.
*
*  " 3. Tạo Container (Giống code cũ của bạn)
*  DATA: lo_cont TYPE REF TO cl_gui_custom_container.
*  CREATE OBJECT lo_cont
*    EXPORTING
*      container_name = 'ALL_ITEMS' " Tên Custom Control trên Subscreen 0112
*    EXCEPTIONS
*      cntl_error = 1
*      cntl_system_error = 2
*      create_error = 3
*      lifetime_error = 4
*      lifetime_dynpro_dynpro_link = 5
*      OTHERS = 6.
*
*  IF sy-subrc <> 0.
*    " SỬA: Dùng 'S' DISPLAY LIKE 'E' để tránh crash
*    MESSAGE 'Error creating container ALL_ITEMS.' TYPE 'E'.
*    RETURN.
*  ENDIF.
*
*  " 4. Tạo ALV Grid (Giống code cũ của bạn)
*  CREATE OBJECT go_grid_item_single
*    EXPORTING
*      i_parent = lo_cont.
*
*  " 5. Đăng ký các sự kiện (Giống code cũ của bạn)
**  go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_enter ).
**  go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).
*
*  " 6. [CHUẨN HÓA] Gọi helper FORMs (Giống Mass Upload)
*  PERFORM alv_grid_display USING 'GO_GRID_ITEM_SINGLE'.
*  PERFORM alv_outtab_display USING 'GO_GRID_ITEM_SINGLE'.
*
**  " 7. [CHUẨN HÓA] Bật chế độ Edit (vì ALV này luôn edit)
**  CALL METHOD go_grid_item_single->set_ready_for_input
**    EXPORTING
**      i_ready_for_input = 1.
*
*  " 8. Flush
*  cl_gui_cfw=>flush( ).
*ENDFORM.


**&---------------------------------------------------------------------*
**& Form BUILD_ALV_LAYOUT_SINGLE_ITEM (SỬA LỖI HIỂN THỊ)
**&---------------------------------------------------------------------*
*FORM build_alv_layout_single_item.
*
*  " 1. Tạo Container (PHẢI LÀM MỖI LẦN PBO)
*  DATA lo_cont TYPE REF TO cl_gui_custom_container.
*  CREATE OBJECT lo_cont
*    EXPORTING
*      container_name = 'ALL_ITEMS' " Tên Custom Control trên Subscreen 0112
*    EXCEPTIONS
*      OTHERS         = 1.
*  IF sy-subrc <> 0.
*    " Dùng 'E' vì PBO có thể dừng.
*    MESSAGE 'Error creating container ALL_ITEMS.' TYPE 'E'.
*    RETURN.
*  ENDIF.
*
*  " 2. Kiểm tra Grid Object
*  IF go_grid_item_single IS INITIAL.
*    " --- LẦN CHẠY ĐẦU TIÊN (HOẶC SAU KHI BỊ FREE) ---
*
*    " 2a. Tạo ALV Grid, gán vào container
*    CREATE OBJECT go_grid_item_single
*      EXPORTING
*        i_parent = lo_cont.
*
*    " 2b. Đăng ký sự kiện (BỎ COMMENT LẠI, VÌ LỖI CRASH ĐÃ SỬA)
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_enter ).
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).
*
*    " 2c. Gọi helper FORMs (Như bạn muốn)
*    PERFORM alv_grid_display USING 'GO_GRID_ITEM_SINGLE'.
*    PERFORM alv_outtab_display USING 'GO_GRID_ITEM_SINGLE'.
*
*    " 2d. Bật chế độ Edit (BỎ COMMENT LẠI)
*    CALL METHOD go_grid_item_single->set_ready_for_input
*      EXPORTING
*        i_ready_for_input = 1.
*
*  ELSE.
*    " --- CÁC LẦN PBO SAU (VÍ DỤ: SAU KHI NHẤN ENTER) ---
*    " Grid object đã tồn tại, chỉ cần "gắn" nó lại với container MỚI
*    CALL METHOD go_grid_item_single->set_parent
*      EXPORTING
*        parent = lo_cont.
*  ENDIF.
*
*  " 3. Flush (Chạy mỗi PBO)
*  cl_gui_cfw=>flush( ).
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_ALV_LAYOUT_SINGLE_ITEM (SỬA LỖI HIỂN THỊ - CHUẨN)
*&---------------------------------------------------------------------*
FORM build_alv_layout_single_item.

  " 1. Tạo Container (CHỈ 1 LẦN)
  IF go_cont_item_single IS INITIAL. " <<< KIỂM TRA CONTAINER GLOBAL
    CREATE OBJECT go_cont_item_single " <<< TẠO CONTAINER GLOBAL
      EXPORTING
        container_name = 'ALL_ITEMS'
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Error creating container ALL_ITEMS.' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  " 2. Tạo Grid (CHỈ 1 LẦN)
  IF go_grid_item_single IS INITIAL.
    " 2a. Tạo ALV Grid, gán vào container global
    CREATE OBJECT go_grid_item_single
      EXPORTING
        i_parent = go_cont_item_single. " <<< DÙNG CONTAINER GLOBAL

*    " 2b. Đăng ký sự kiện (Bật lại, vì lỗi crash PAI đã sửa)
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_enter ).
*    go_grid_item_single->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).

    CALL METHOD go_grid_item_single->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_enter. " Triggers on Enter key

    CALL METHOD go_grid_item_single->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified. " Triggers on Tab key/leaving the cell

    " 2c. Gọi helper FORMs (Như bạn muốn)
    PERFORM alv_grid_display USING 'GO_GRID_ITEM_SINGLE'.
    PERFORM alv_outtab_display USING 'GO_GRID_ITEM_SINGLE'.

*      " --- THÊM LOGIC: Đảm bảo có ít nhất 1 dòng trống ban đầu ---
*    IF gt_item_details IS INITIAL.
*      APPEND INITIAL LINE TO gt_item_details.
*    ENDIF.
**     --- KẾT THÚC THÊM LOGIC ---

    " 2d. Bật chế độ Edit (Bật lại)
    CALL METHOD go_grid_item_single->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    " 2e. Flush (Chỉ flush khi tạo lần đầu)
    cl_gui_cfw=>flush( ).
  ENDIF.
  " (Không cần ELSE, các PBO sau không cần làm gì cả)

ENDFORM.
*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_CONDITIONS (Đồng bộ với Item Details)
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_conditions CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " --- Macro ĐỒNG BỘ (giống hệt Item Details) ---
  " &1 = Fieldname, &2 = Just, &3 = Col_Opt, &4 = Coltext, &5 = Fix_Col, &6 = Edit_Mask
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-fieldname   = &1.
    ls_fcat-just        = &2.
    ls_fcat-col_opt     = &3.
    ls_fcat-coltext     = &4.
    ls_fcat-seltext     = &4.
    ls_fcat-tooltip     = &4.
    ls_fcat-scrtext_l   = &4.
    ls_fcat-scrtext_m   = &4.
    ls_fcat-scrtext_s   = &4.
    ls_fcat-fix_column  = &5.
    ls_fcat-ref_table   = 'ZTB_SO_COND_SING'. " <<< Dùng Z-table mới
    ls_fcat-ref_field   = &1.
    ls_fcat-edit_mask   = &6.

    " (Không cần no_convext cho KSCHL)

    " === Logic Edit (Chỉ cho nhập Amount) ===
    CASE &1.
*      WHEN 'AMOUNT'. " Chỉ cho phép sửa cột Amount
*        ls_fcat-edit = abap_true.
      WHEN OTHERS.
        ls_fcat-edit = abap_false.
    ENDCASE.

    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " --- Fieldname         Just  Opt       Coltext             FixCol      EditMask
  _add_fieldcat:
    'ICON'            'C'   abap_on   'Inactive'          abap_false  '',
    'KSCHL'           'L'   abap_on   'CnTy'              abap_false  '',
    'VTEXT'           'L'   abap_on   'Description'       abap_false  '',
    'AMOUNT'          'R'   abap_on   'Amount'            abap_false  '',
    'WAERS'           'L'   abap_on   'Crcy'              abap_false  '',
    'KPEIN'           'R'   abap_on   'per'               abap_false  '',
    'KMEIN'           'L'   abap_on   'Unit of Measure'   abap_false  '',
    'COND_VALUE'      'R'   abap_on   'Condition Value'   abap_false  ''.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_CONDITIONS_ALV (Đồng bộ với Item Details)
*&---------------------------------------------------------------------*
FORM build_conditions_alv.

  " 1. Tạo Container (CHỈ 1 LẦN)
  IF go_cont_conditions IS INITIAL.
    CREATE OBJECT go_cont_conditions
      EXPORTING
        container_name = 'CC_CONDITIONS'
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Error creating container CC_CONDITIONS.' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  " 2. Tạo Grid (CHỈ 1 LẦN)
  IF go_grid_conditions IS INITIAL.
    " 2a. Tạo ALV Grid
    CREATE OBJECT go_grid_conditions
      EXPORTING
        i_parent = go_cont_conditions.

" ==================================================================
    " [FIX]: KHỞI TẠO HANDLER VỚI ĐẦY ĐỦ THAM SỐ
    " ==================================================================
    IF go_event_handler_conds IS INITIAL.
      CREATE OBJECT go_event_handler_conds
        EXPORTING
          io_grid  = go_grid_conditions          " Truyền Grid Conditions vào
          it_table = REF #( gt_conditions_alv ). " Truyền bảng dữ liệu vào
    ENDIF.

    " Sau đó mới Set Handler
    SET HANDLER go_event_handler_conds->handle_data_changed FOR go_grid_conditions.
    " ==================================================================

    " 2b. Đăng ký sự kiện (Code cũ của bạn - OK)
    CALL METHOD go_grid_conditions->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_enter.
    CALL METHOD go_grid_conditions->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified.

    " 2c. Gọi helper FORMs
    PERFORM alv_grid_display USING 'GO_GRID_CONDITIONS'.
    PERFORM alv_outtab_display USING 'GO_GRID_CONDITIONS'.

    " 2d. Bật chế độ Edit
    CALL METHOD go_grid_conditions->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    " 2e. Flush
    cl_gui_cfw=>flush( ).
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_MONITORING
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_monitoring CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " --- Macro ĐỒNG BỘ (giống hệt _01/_02) ---
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-edit        = abap_false. " Luôn luôn read-only
    ls_fcat-fieldname   = &1.
    ls_fcat-just        = &2.
    ls_fcat-col_opt     = &3.
    ls_fcat-coltext     = &4.
    ls_fcat-seltext     = &4.
    ls_fcat-tooltip     = &4.
    ls_fcat-scrtext_l   = &4.
    ls_fcat-scrtext_m   = &4.
    ls_fcat-scrtext_s   = &4.
    ls_fcat-fix_column  = &5.
    ls_fcat-ref_table   = 'ZSD4_SO_MONITORING'. " <<< Dùng Structure của bạn
    ls_fcat-ref_field   = &1.
    ls_fcat-edit_mask   = &6.
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " --- Các lời gọi Macro (Dựa trên Structure của bạn) ---
  " Fieldname         Just  Opt       Coltext                FixCol      EditMask
  _add_fieldcat:
    'STATUS'          'L'   abap_on   'Overall Status'       abap_false  '',
    'VBELN'           'L'   abap_on   'Sales Order'          abap_false  '',
    'AUART'           'L'   abap_on   'Sales Doc. Type'      abap_false  '',
    'ERDAT'           'C'   abap_on   'Document Date'        abap_false  '__.__.____',
    'VDATU'           'C'   abap_on   'Req. Deliv. Date'     abap_false  '__.__.____',
    'VKORG'           'L'   abap_on   'Sales Org.'           abap_false  '',
    'VTWEG'           'L'   abap_on   'Dist. Channel'        abap_false  '',
    'SPART'           'L'   abap_on   'Division'             abap_false  '',
    'SOLD_TO'         'L'   abap_on   'Sold-to-Party'        abap_false  '',
    'POSNR'           'R'   abap_on   'Items'                abap_false  '',
    'MATNR'           'L'   abap_on   'Material'             abap_false  '',
    'KWMENG'          'R'   abap_on   'Quantity'             abap_false  '',
    'VRKME'           'L'   abap_on   'Sales Unit'           abap_false  '',
    'NETWR'           'R'   abap_on   'Net Value'            abap_false  '',
    'WAERK'           'L'   abap_on   'Currency'             abap_false  ''.
ENDFORM.


*&---------------------------------------------------------------------*
*& Form BUILD_ALV_MONITORING
*&---------------------------------------------------------------------*
FORM build_alv_monitoring.
  " 1. Tạo Container (CHỈ 1 LẦN)
  IF go_cont_monitoring IS INITIAL.
    CREATE OBJECT go_cont_monitoring
      EXPORTING
        container_name = 'CC_MONITORING' " (Tên container của bạn)
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Error creating container CC_MONITORING.' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  " 2. Tạo Grid (CHỈ 1 LẦN)
  IF go_grid_monitoring IS INITIAL.
    " 2a. Tạo ALV Grid
    CREATE OBJECT go_grid_monitoring
      EXPORTING
        i_parent = go_cont_monitoring.

    " 2c. Gọi helper FORMs
    PERFORM alv_grid_display USING 'GO_GRID_MONITORING'.
    PERFORM alv_outtab_display USING 'GO_GRID_MONITORING'.

    " 2d. Bật chế độ (Read-only)
    CALL METHOD go_grid_monitoring->set_ready_for_input
      EXPORTING
        i_ready_for_input = 0.

    " 2e. Flush
    cl_gui_cfw=>flush( ).
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SET_DROPDOWN_MONITORING_STATUS (Cho Screen 600)
*&---------------------------------------------------------------------*
FORM set_dropdown_monitoring_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  " 1. Thêm dòng 'All' (Trống)
  ls_value-key  = 'ALL'.
  ls_value-text = ' '. " (Để trống cho đẹp)
  APPEND ls_value TO lt_values.
  " 2. Thêm logic của bạn
  ls_value-key  = 'COMP'.
  ls_value-text = 'Completed'.
  APPEND ls_value TO lt_values.
  ls_value-key  = 'OPEN'.
  ls_value-text = 'Open/ In Process'.
  APPEND ls_value TO lt_values.
  ls_value-key  = 'REJ'.
  ls_value-text = 'Rejected'.
  APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'STATUS' " Tên biến trên Screen 600
      values = lt_values.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SET_DROPDOWN_Tracking_STATUS (Cho Screen 500)
*&---------------------------------------------------------------------*
*FORM set_dropdown_process_phase.
*  DATA: lt_values TYPE vrm_values,
*        ls_value  TYPE vrm_value.
*
*  CLEAR lt_values.
*
**  " SỬA: Thêm một dòng trống (Key là 'ALL' hoặc SPACE)
**  ls_value-key  = 'ALL'.
**  ls_value-text = ' '. " <== Chỉ để một khoảng trắng
**  APPEND ls_value TO lt_values.
*
*  " Thêm các Phase
*  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
*  ls_value-key  = 'ORD'. ls_value-text = 'Order processing'. APPEND ls_value TO lt_values.
*  ls_value-key  = 'DEL'. ls_value-text = 'Delivery processing'. APPEND ls_value TO lt_values.
*  ls_value-key  = 'INV'. ls_value-text = 'Invoice processing'. APPEND ls_value TO lt_values.
*  ls_value-key  = 'ACC'. ls_value-text = 'Accounting'. APPEND ls_value TO lt_values.
*
*  CALL FUNCTION 'VRM_SET_VALUES'
*    EXPORTING
*      id     = 'CB_PHASE'
*      values = lt_values.
*ENDFORM.

FORM set_dropdown_process_phase.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.

  " Thêm các Phase
  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key  = 'ORD'. ls_value-text = 'Order created'. APPEND ls_value TO lt_values.
  ls_value-key  = 'DEL'. ls_value-text = 'Delivery created , ready PGI'. APPEND ls_value TO lt_values.
  ls_value-key  = 'INV'. ls_value-text = 'PGI posted, ready Billing'. APPEND ls_value TO lt_values.
  ls_value-key  = 'ACC'. ls_value-text = 'FI Doc created'. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_PHASE'
      values = lt_values.
ENDFORM.

FORM set_dropdown_sales_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key  = 'INC'. ls_value-text = 'Order Incomplete'. APPEND ls_value TO lt_values.
  ls_value-key  = 'COM'. ls_value-text = 'Order Complete'. APPEND ls_value TO lt_values.
  ls_value-key  = 'BLK'. ls_value-text = 'Billing Block'. APPEND ls_value TO lt_values.
  ls_value-key  = 'REJ'. ls_value-text = 'Rejected'. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_SOSTA'
      values = lt_values.
ENDFORM.

FORM set_dropdown_delivery_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key  = 'GRP'. ls_value-text = 'GR Posted'. APPEND ls_value TO lt_values.
  ls_value-key  = 'PGI'.  ls_value-text = 'GI Posted'. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_DDSTA'
      values = lt_values.
ENDFORM.

FORM set_dropdown_billing_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key  = 'OPEN'. ls_value-text = 'Open'. APPEND ls_value TO lt_values.
  ls_value-key  = 'CANC'. ls_value-text = 'Cancelled'. APPEND ls_value TO lt_values.
  ls_value-key  = 'COMP'. ls_value-text = 'Completed'. APPEND ls_value TO lt_values.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_BDSTA'
      values = lt_values.
ENDFORM.

FORM    alv_prepare.
*  CLEAR: gt_fcat, gs_layout.
*
*  gs_layout-zebra      = abap_true.
*  gs_layout-cwidth_opt = abap_true.
*  gs_layout-grid_title = 'Sales Document Tracking'.
*
*  " BÁO ALV DÙNG CHECKBOX HỆ THỐNG:
*  gs_layout-box_fname  = 'SEL_BOX'. " Tên trường data để lưu 'X'
*  gs_layout-sel_mode   = 'D'.       " Cho phép chọn nhiều
*
*  DEFINE add_field.
*    APPEND VALUE lvc_s_fcat(
*      fieldname = &1
*      coltext   = &2
*      outputlen = &3
*      edit      = &4
*    ) TO gt_fcat.
*  END-OF-DEFINITION.
*  "============================================
*  " THÊM MỚI: XÓA CÁC NÚT KHÔNG CẦN THIẾT
*  "============================================
*  " Xóa nút 'Find next' (Tìm kiếm nâng cao)
*  APPEND cl_gui_alv_grid=>mc_fc_find_more TO gt_exclude.
*  " Xóa nút 'Subtotal' (Tổng phụ)
*  APPEND cl_gui_alv_grid=>mc_fc_subtot TO gt_exclude.
*  " Xóa nút 'Information' (Thông tin)
*  APPEND cl_gui_alv_grid=>mc_fc_info TO gt_exclude.
*  " Xóa nút 'Views' (Giao diện) - (Nút này khác với 'Layout')
*  APPEND cl_gui_alv_grid=>mc_fc_views TO gt_exclude.
*  " XÓA DÒNG NÀY ĐI:
*  " add_field 'SEL_BOX' '' 1 abap_true. " <== XÓA BỎ
*
*  "============================================
*  " BẮT ĐẦU SỬA: Thêm Icon
*  "============================================
*
*  " 1. Thêm trường icon (không cần tiêu đề, không edit)
*  add_field 'PHASE_ICON' '' 4 abap_false.
*
*  add_field 'PROCESS_PHASE'   'Process Phase'      20 abap_false.
*  add_field 'SALES_DOCUMENT'   'Sales Documents'       12 abap_false.
*  add_field 'ORDER_TYPE'        'Sales Order Type'    4  abap_false.
*  add_field 'DOCUMENT_DATE'     'Document Date'       10 abap_false.
*  add_field 'SOLD_TO_PARTY'     'Sold-to Party'       10 abap_false.
*  add_field 'SALES_ORG'         'Sales Org'           4  abap_false.
*  add_field 'DISTR_CHAN'        'Dist. Channel'       2  abap_false.
*  add_field 'DIVISION'          'Division'            2  abap_false.
*  add_field 'DELIVERY_DOCUMENT' 'Delivery Documents' 12 abap_false.
*  add_field 'REQ_DELIVERY_DATE' 'Requested Delivery Date' 10 abap_false.
*  add_field 'BILLING_DOCUMENT'  'Billing Documents'   12 abap_false.
*  add_field 'NET_VALUE'         'Net Value'           15 abap_false.
*  add_field 'CURRENCY'          'Currency'            5  abap_false.
*  add_field 'ERROR_MSG'         'BAPI Message'       50 abap_false.
*  " 3. Báo cho ALV biết 'PHASE_ICON' là một icon
*  DATA: ls_fcat_icon TYPE lvc_s_fcat.
*  READ TABLE gt_fcat WITH KEY fieldname = 'PHASE_ICON'
*                     INTO ls_fcat_icon.
*  IF sy-subrc = 0.
*    ls_fcat_icon-icon = abap_true. " <== ĐÁNH DẤU LÀ ICON
*    MODIFY gt_fcat FROM ls_fcat_icon INDEX sy-tabix.
*  ENDIF.

    CLEAR: gt_fcat, gs_layout.

  gs_layout-zebra      = abap_true.
  gs_layout-cwidth_opt = abap_true.
  gs_layout-grid_title = 'Sales Document Tracking'.

  " BÁO ALV DÙNG CHECKBOX HỆ THỐNG:
  gs_layout-box_fname  = 'SEL_BOX'. " Tên trường data để lưu 'X'
  gs_layout-sel_mode   = 'D'.       " Cho phép chọn nhiều

  "============================================
  " SỬA: BẬT TÍNH NĂNG GỘP Ô (MERGE CELL)
  "============================================
  gs_layout-no_merging = space. " <== QUAN TRỌNG: Để cột Sales Doc tự gộp lại
  "============================================

  DEFINE add_field.
    APPEND VALUE lvc_s_fcat(
      fieldname = &1
      coltext   = &2
      outputlen = &3
      edit      = &4
    ) TO gt_fcat.
  END-OF-DEFINITION.
  "============================================
  " THÊM MỚI: XÓA CÁC NÚT KHÔNG CẦN THIẾT
  "============================================
  " Xóa nút 'Find next' (Tìm kiếm nâng cao)
  APPEND cl_gui_alv_grid=>mc_fc_find_more TO gt_exclude.
  " Xóa nút 'Subtotal' (Tổng phụ)
  APPEND cl_gui_alv_grid=>mc_fc_subtot TO gt_exclude.
  " Xóa nút 'Information' (Thông tin)
  APPEND cl_gui_alv_grid=>mc_fc_info TO gt_exclude.
  " Xóa nút 'Views' (Giao diện) - (Nút này khác với 'Layout')
  APPEND cl_gui_alv_grid=>mc_fc_views TO gt_exclude.

  "============================================
  " BẮT ĐẦU KHAI BÁO CỘT
  "============================================

  " 1. Thêm trường icon (không cần tiêu đề, không edit)
  add_field 'PHASE_ICON'    '' 4 abap_false.
  add_field 'RELEASE_FLAG'  '' 4 abap_false.
  add_field 'PROCESS_PHASE' 'Process Phase'       20 abap_false.
  add_field 'SALES_DOCUMENT' 'Sales Documents'    12 abap_false.


  add_field 'ORDER_TYPE'        'Sales Order Type'    4  abap_false.
  add_field 'DOCUMENT_DATE'     'Document Date'       10 abap_false.
  add_field 'SOLD_TO_PARTY'     'Sold-to Party'       10 abap_false.
  add_field 'SALES_ORG'         'Sales Org'           4  abap_false.
  add_field 'DISTR_CHAN'        'Dist. Channel'       2  abap_false.
  add_field 'DIVISION'          'Division'            2  abap_false.
  add_field 'DELIVERY_DOCUMENT' 'Delivery Documents' 12 abap_false.
  add_field 'REQ_DELIVERY_DATE' 'Requested Delivery Date' 10 abap_false.
  add_field 'BILLING_DOCUMENT'  'Billing Documents'   12 abap_false.
  add_field 'NET_VALUE'         'Net Value'           15 abap_false.
  add_field 'CURRENCY'          'Currency'            5  abap_false.
  " add_field 'ERROR_MSG'         'BAPI Message'       50 abap_false.

  "============================================
  "=== BẮT ĐẦU THÊM 3 CỘT MỚI (FI/CANCEL)
  "============================================
  add_field 'FI_DOC_BILLING'    'FI for Billing Doc'   12 abap_false.
  add_field 'BILL_DOC_CANCEL'   'Billing Cancelled doc'  12 abap_false.
  add_field 'FI_DOC_CANCEL'     'FI for cancel billing Doc' 12 abap_false.
  "============================================

  "============================================
  "=== CẤU HÌNH LẠI CÁC CỘT ĐẶC BIỆT
  "============================================

  " 1. Xử lý RELEASE_FLAG (Hotspot)
  DATA: ls_fcat_release TYPE lvc_s_fcat.
  READ TABLE gt_fcat WITH KEY fieldname = 'RELEASE_FLAG'
                   INTO ls_fcat_release.
  IF sy-subrc = 0.
    ls_fcat_release-icon = abap_true.
    ls_fcat_release-hotspot = abap_true.  " Cho phép click
    MODIFY gt_fcat FROM ls_fcat_release INDEX sy-tabix.
  ENDIF.

  " 2. Xử lý PHASE_ICON (Icon hiển thị)
  DATA: ls_fcat_icon TYPE lvc_s_fcat.
  READ TABLE gt_fcat WITH KEY fieldname = 'PHASE_ICON'
                    INTO ls_fcat_icon.
  IF sy-subrc = 0.
    ls_fcat_icon-icon = abap_true. " Đánh dấu là Icon
    MODIFY gt_fcat FROM ls_fcat_icon INDEX sy-tabix.
  ENDIF.

  " 3. Xử lý SALES_DOCUMENT (Tô màu & Key để Merge đẹp hơn)
  DATA: ls_fcat_so TYPE lvc_s_fcat.
  READ TABLE gt_fcat WITH KEY fieldname = 'SALES_DOCUMENT'
                    INTO ls_fcat_so.
  IF sy-subrc = 0.
    ls_fcat_so-emphasize = 'C500'. " Tô màu xanh
    ls_fcat_so-key       = abap_true. " Cột khóa (để không cuộn ngang và hỗ trợ merge)
    MODIFY gt_fcat FROM ls_fcat_so INDEX sy-tabix.
  ENDIF.
  "============================================
  " KẾT THÚC SỬA
  "============================================


  " <<< THÊM MỚI TỪ ĐÂY >>>
  " 4. Báo cho ALV biết 'DELIVERY_DOCUMENT' là một Hotspot
  DATA: ls_fcat_hotspot TYPE lvc_s_fcat.
  READ TABLE gt_fcat WITH KEY fieldname = 'DELIVERY_DOCUMENT'
                       INTO ls_fcat_hotspot.
  IF sy-subrc = 0.
    ls_fcat_hotspot-hotspot = abap_true. " <<< BIẾN THÀNH LINK
    MODIFY gt_fcat FROM ls_fcat_hotspot INDEX sy-tabix.
  ENDIF.
  " <<< KẾT THÚC THÊM MỚI >>>

ENDFORM.


*&---------------------------------------------------------------------*
*& Form ALV_FIELDCATALOG_PGI_ALL (Tab 1)
*&---------------------------------------------------------------------*
FORM alv_fieldcatalog_pgi_all CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.
  " (Dùng Macro chuẩn của bạn)
  DEFINE _add_fieldcat.
    CLEAR ls_fcat.
    ls_fcat-edit        = COND #( WHEN gv_pgi_edit_mode = abap_true THEN 'X' ELSE space ).
    ls_fcat-fieldname   = &1.
    ls_fcat-just        = &2.
    ls_fcat-col_opt     = &3.
    ls_fcat-coltext     = &4.
    ls_fcat-seltext     = &4.
    ls_fcat-tooltip     = &4.
    ls_fcat-scrtext_l   = &4.
    ls_fcat-scrtext_m   = &4.
    ls_fcat-scrtext_s   = &4.
    ls_fcat-fix_column  = &5.
    ls_fcat-ref_table   = 'ZTB_PGI_ALL_ITEM'. " <<< Tên Z-Table của bạn
    ls_fcat-ref_field   = &1.
    ls_fcat-edit_mask   = &6.

    " === SỬA LOGIC EDIT (Theo yêu cầu của bạn) ===
    IF gv_pgi_edit_mode = abap_true.
      CASE &1.
        WHEN 'LFIMG' OR 'PIKMG'. " Chỉ 2 cột này được edit
          ls_fcat-edit = abap_true.
        WHEN OTHERS.
          ls_fcat-edit = abap_false.
      ENDCASE.
    ELSE.
      ls_fcat-edit = abap_false. " Luôn khóa ở Display mode
    ENDIF.
    " === KẾT THÚC SỬA ===

    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.
  " Fieldname         Just  Opt       Coltext                FixCol      EditMask
  _add_fieldcat:
    'POSNR'           'R'   abap_on   'Item'                 abap_false  '',
    'MATNR'           'L'   abap_on   'Material'             abap_false  '',
    'LFIMG'           'R'   abap_on   'Delivery Quantity'    abap_false  '',
    'VRKME'           'L'   abap_on   'Sales Unit'           abap_false  '',
    'ARKTX'           'L'   abap_on   'Description'          abap_false  '',
    'PIKMG'           'R'   abap_on   'Picked Quantity'      abap_false  '',
    'PSTYV'           'L'   abap_on   'Item Category'        abap_false  '',
    'KZTLF'           'C'   abap_on   'Part deli indi'       abap_false  '',
    'UEPOS'           'R'   abap_on   'High level item'      abap_false  '',
    'XCHPF'           'C'   abap_on   'Batch split in'       abap_false  '',
    'KDMAT'           'L'   abap_on   'Customer material number' abap_false  ''.
ENDFORM.

**&---------------------------------------------------------------------*
**& Form ALV_FIELDCATALOG_PGI_PROC (Tab 2)
**&---------------------------------------------------------------------*
*FORM alv_fieldcatalog_pgi_proc CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  REFRESH pt_fieldcat.
*  " (Dùng Macro chuẩn của bạn)
*  DEFINE _add_fieldcat.
*    CLEAR ls_fcat.
*    ls_fcat-edit        = COND #( WHEN gv_pgi_edit_mode = abap_true THEN 'X' ELSE space ).
*    ls_fcat-fieldname   = &1.
*    ls_fcat-just        = &2.
*    ls_fcat-col_opt     = &3.
*    ls_fcat-coltext     = &4.
*    ls_fcat-seltext     = &4.
*    ls_fcat-tooltip     = &4.
*    ls_fcat-scrtext_l   = &4.
*    ls_fcat-scrtext_m   = &4.
*    ls_fcat-scrtext_s   = &4.
*    ls_fcat-fix_column  = &5.
*    ls_fcat-ref_table   = 'ZTB_PGI_PROCESS'. " <<< Tên Z-Table của bạn
*    ls_fcat-ref_field   = &1.
*    ls_fcat-edit_mask   = &6.
*    APPEND ls_fcat TO pt_fieldcat.
*  END-OF-DEFINITION.
*  " Fieldname         Just  Opt       Coltext                FixCol      EditMask
*  _add_fieldcat:
*    'POSNR'           'R'   abap_on   'Item'                 abap_false  '',
*    'MATNR'           'L'   abap_on   'Material'             abap_false  '',
*    'ARKTX'           'L'   abap_on   'Description'          abap_false  '',
*    'WERKS'           'L'   abap_on   'Plant'                abap_false  '',
*    'VTWEG'           'L'   abap_on   'Dist. Channel'        abap_false  '',
*    'SPART'           'L'   abap_on   'Division'             abap_false  '',
*    'LGORT'           'L'   abap_on   'Storage Location'     abap_false  '',
*    'LGPBE'           'L'   abap_on   'Storage Bin'          abap_false  '',
*    'CHARG'           'L'   abap_on   'Batch'                abap_false  '',
*    'KOSTA'           'C'   abap_on   'Picking Status'       abap_false  '',
*    'PKSTA'           'C'   abap_on   'Packing Status'       abap_false  '',
*    'WBSTA'           'C'   abap_on   'Good Issue Status'    abap_false  '',
*    'FKREL'           'C'   abap_on   'Deliv.Rel.Billg Sts'  abap_false  '',
*    'LADGR'           'L'   abap_on   'Loading Group'        abap_false  '',
*    'BWART'           'L'   abap_on   'Movement Type'        abap_false  '',
*    'TEXT'            'L'   abap_on   'Text'                 abap_false  ''.
*ENDFORM.


*&---------------------------------------------------------------------*
*& Form BUILD_ALV_PGI_ALL (Tab 1)
*&---------------------------------------------------------------------*
FORM build_alv_pgi_all.
  " 1. Tạo Container (CHỈ 1 LẦN)
  IF go_cont_pgi_all IS INITIAL.
    CREATE OBJECT go_cont_pgi_all
      EXPORTING
        container_name = 'CC_PGI_ALL' " Tên trên Subscreen 0301
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Error creating container CC_PGI_ALL.' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDIF.
  " 2. Tạo Grid (CHỈ 1 LẦN)
  IF go_grid_pgi_all IS INITIAL.
    CREATE OBJECT go_grid_pgi_all
      EXPORTING
        i_parent = go_cont_pgi_all.
    " (Đăng ký sự kiện nếu cần edit)
    " CALL METHOD go_grid_pgi_all->register_edit_event...
    PERFORM alv_grid_display USING 'GO_GRID_PGI_ALL'.
    PERFORM alv_outtab_display USING 'GO_GRID_PGI_ALL'.
    CALL METHOD go_grid_pgi_all->set_ready_for_input
      EXPORTING
        i_ready_for_input = COND #( WHEN gv_pgi_edit_mode = abap_true THEN 1 ELSE 0 ).
    cl_gui_cfw=>flush( ).
  ENDIF.
ENDFORM.

**&---------------------------------------------------------------------*
**& Form BUILD_ALV_PGI_PROC (Tab 2)
**&---------------------------------------------------------------------*
*FORM build_alv_pgi_proc.
*  " 1. Tạo Container (CHỈ 1 LẦN)
*  IF go_cont_pgi_proc IS INITIAL.
*    CREATE OBJECT go_cont_pgi_proc
*      EXPORTING
*        container_name = 'CC_PGI_PROC' " Tên trên Subscreen 0302
*      EXCEPTIONS
*        OTHERS         = 1.
*    IF sy-subrc <> 0.
*      MESSAGE 'Error creating container CC_PGI_PROC.' TYPE 'E'.
*      RETURN.
*    ENDIF.
*  ENDIF.
*  " 2. Tạo Grid (CHỈ 1 LẦN)
*  IF go_grid_pgi_proc IS INITIAL.
*    CREATE OBJECT go_grid_pgi_proc
*      EXPORTING
*        i_parent = go_cont_pgi_proc.
*    " (Đăng ký sự kiện nếu cần edit)
*    PERFORM alv_grid_display USING 'GO_GRID_PGI_PROC'.
*    PERFORM alv_outtab_display USING 'GO_GRID_PGI_PROC'.
*    CALL METHOD go_grid_pgi_proc->set_ready_for_input
*      EXPORTING
*        i_ready_for_input = COND #( WHEN gv_pgi_edit_mode = abap_true THEN 1 ELSE 0 ).
*    cl_gui_cfw=>flush( ).
*  ENDIF.
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form REFRESH_PGI_ALVS (Làm mới ALV cho Screen 300)
*&---------------------------------------------------------------------*
FORM refresh_pgi_alvs.
  DATA lv_ready_input TYPE i.
  lv_ready_input = COND #( WHEN gv_pgi_edit_mode = abap_true THEN 1 ELSE 0 ).

  " --- 1. Cập nhật ALV "All Items" (Tab 1) ---
  IF go_grid_pgi_all IS BOUND.
    " 1a. Xây dựng lại Fieldcat (vì 'edit' flag đã thay đổi)
    PERFORM alv_fieldcatalog_pgi_all CHANGING gt_fieldcat_pgi_all.
    CALL METHOD go_grid_pgi_all->set_frontend_fieldcatalog
      EXPORTING
        it_fieldcatalog = gt_fieldcat_pgi_all.

    " 1b. Set chế độ Sẵn sàng Nhập
    CALL METHOD go_grid_pgi_all->set_ready_for_input
      EXPORTING
        i_ready_for_input = lv_ready_input.

    " 1c. Vẽ lại
    CALL METHOD go_grid_pgi_all->refresh_table_display.
  ENDIF.

  cl_gui_cfw=>flush( ).
ENDFORM.
