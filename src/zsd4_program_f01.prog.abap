*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_F01
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*   SCREEN 0200 (MASS UPLOAD CENTER)
*----------------------------------------------------------------------*

*======================================================================*
* SECTION 1: CLASS IMPLEMENTATION
*======================================================================*

*----------------------------------------------------------------------*
* CLASS lcl_event_handler IMPLEMENTATION
*----------------------------------------------------------------------*

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD constructor.
    mo_grid  = io_grid.
    mt_table = it_table.
  ENDMETHOD.

  METHOD handle_data_changed.

    " ===========================================================
    " 1. KHAI BÁO BIẾN (DÙNG CHUNG CHO TOÀN BỘ METHOD)
    " ===========================================================
    DATA: ls_mod_cell  TYPE lvc_s_modi,
          lv_qty       TYPE zquantity,
          lv_price     TYPE kbetr,       " Giá ZPRQ

          " Biến dùng chung cho các Case
          lv_tax_pct   TYPE kbetr,
          lv_net_val   TYPE kwert,

          " Biến cho ZDR/ZCRR
          lv_zdrp_pct  TYPE kbetr,
          lv_z100_pct  TYPE kbetr,
          lv_order_val TYPE kwert,
          lv_z100_val  TYPE kwert,

          " Biến cho ZSC
          lv_zcf1_pct  TYPE kbetr,
          lv_zcf1_val  TYPE kwert,
          lv_net1_val  TYPE kwert,
          lv_net2_val  TYPE kwert,
          lv_tax_val   TYPE kwert,
          lv_base_val  TYPE kwert,

          " Structure dùng để Read Table (Khai báo ở đây để tránh lỗi Inline Declaration)
          ls_zprq      TYPE ty_cond_alv,
          ls_ztax      TYPE ty_cond_alv,
          ls_zdrp      TYPE ty_cond_alv,
          ls_zcrp      TYPE ty_cond_alv,
          ls_zc        TYPE ty_cond_alv,
          ls_z100      TYPE ty_cond_alv,
          ls_zcf1      TYPE ty_cond_alv.

    " Cache variables
    DATA: ls_cache     TYPE ty_cond_cache.

    FIELD-SYMBOLS: <fs_item>   TYPE ty_item_details,
                   <fs_cond>   TYPE ty_cond_alv,
                   <fs_detail> TYPE ty_item_details.

    " -----------------------------------------------------------
    " 2. LẤY SỐ LƯỢNG (QUANTITY)
    " -----------------------------------------------------------
    READ TABLE gt_item_details ASSIGNING <fs_item> INDEX gv_current_item_idx.
    IF sy-subrc = 0.
      lv_qty = <fs_item>-quantity.
    ELSE.
      lv_qty = 1.
    ENDIF.
    IF lv_qty <= 0. lv_qty = 1. ENDIF.

    " -----------------------------------------------------------
    " 3. UPDATE AMOUNT MỚI VÀO BẢNG TỪ NGƯỜI DÙNG NHẬP
    " -----------------------------------------------------------
    LOOP AT er_data_changed->mt_good_cells INTO ls_mod_cell.
      READ TABLE gt_conditions_alv ASSIGNING FIELD-SYMBOL(<fs_upd>) INDEX ls_mod_cell-row_id.
      IF sy-subrc = 0.
        " Chỉ update nếu sửa cột Amount
        IF ls_mod_cell-fieldname = 'AMOUNT'.
          <fs_upd>-amount = ls_mod_cell-value.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " ===========================================================
    " 4. TÍNH TOÁN THEO LOẠI ĐƠN HÀNG (CORE LOGIC)
    " ===========================================================

    " >>>>>>>>>>>>>>> CASE 1: ZORR & ZTP (Standard) <<<<<<<<<<<<<<<
    IF gv_order_type = 'ZORR' OR gv_order_type = 'ZTP'.

      " A. Lấy tham số đầu vào
      READ TABLE gt_conditions_alv INTO ls_zprq WITH KEY kschl = 'ZPRQ'.
      IF sy-subrc = 0. lv_price = ls_zprq-amount. ENDIF.

      READ TABLE gt_conditions_alv INTO ls_ztax WITH KEY kschl = 'ZTAX'.
      IF sy-subrc = 0. lv_tax_pct = ls_ztax-amount. ENDIF.

      " B. Loop tính toán
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
          WHEN 'ZPRQ'.
            <fs_cond>-kwert = lv_price * lv_qty.
            lv_net_val      = <fs_cond>-kwert. " Lưu base
            <fs_cond>-icon  = icon_led_green.

          WHEN 'NETW'.
            <fs_cond>-amount = lv_price.
            <fs_cond>-kwert  = lv_net_val.
            <fs_cond>-waers  = ls_zprq-waers.

          WHEN 'ZTAX'.
            <fs_cond>-kwert = ( lv_net_val * lv_tax_pct ) / 100.
            <fs_cond>-waers = ls_zprq-waers.

          WHEN 'GROS'.
            <fs_cond>-amount = lv_price + ( ( lv_price * lv_tax_pct ) / 100 ).
            <fs_cond>-kwert  = <fs_cond>-amount * lv_qty.
            <fs_cond>-waers  = ls_zprq-waers.
        ENDCASE.
      ENDLOOP.

      " >>>>>>>>>>>>>>> CASE 2: ZDR & ZCRR (Debit/Credit Memo) <<<<<<<<<<<<<<<
    ELSEIF gv_order_type = 'ZDR'.

      " A. Lấy tham số đầu vào
      READ TABLE gt_conditions_alv INTO ls_zprq WITH KEY kschl = 'ZPRQ'.
      IF sy-subrc = 0. lv_price = ls_zprq-amount. ENDIF.

      READ TABLE gt_conditions_alv INTO ls_zdrp WITH KEY kschl = 'ZDRP'.
      IF sy-subrc = 0. lv_zdrp_pct = ls_zdrp-amount. ENDIF.

      READ TABLE gt_conditions_alv INTO ls_z100 WITH KEY kschl = 'Z100'.
      IF sy-subrc = 0.
        lv_z100_pct = ls_z100-amount.
      ELSE.
        lv_z100_pct = -100. " Mặc định -100 nếu chưa có
      ENDIF.

      " B. Loop tính toán
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
            " 1. ZPRQ
          WHEN 'ZPRQ'.
            <fs_cond>-kwert = lv_price * lv_qty.
            lv_order_val    = <fs_cond>-kwert.
            <fs_cond>-icon  = icon_led_green.

            " 2. ZDRP (% Debit)
          WHEN 'ZDRP'.
            <fs_cond>-kwert = ( lv_order_val * lv_zdrp_pct ) / 100.
            <fs_cond>-waers = ls_zprq-waers.

            " 3. Z100 (-100%)
          WHEN 'Z100'.
            <fs_cond>-kwert = ( lv_order_val * lv_z100_pct ) / 100.
            lv_z100_val     = <fs_cond>-kwert.
            <fs_cond>-waers = ls_zprq-waers.

            " 4. NETW (Net Values)
          WHEN 'NETW'.
            <fs_cond>-kwert = lv_order_val +
                              ( ( lv_order_val * lv_zdrp_pct ) / 100 ) +
                              lv_z100_val.

            " Tính lại cột Amount (Đơn giá ròng)
            IF lv_qty <> 0.
              <fs_cond>-amount = <fs_cond>-kwert / lv_qty.
            ELSE.
              <fs_cond>-amount = 0.
            ENDIF.
            <fs_cond>-waers = ls_zprq-waers.
        ENDCASE.

        " Xử lý riêng cho dòng Order Value (không có KSCHL hoặc là text)
        IF <fs_cond>-vtext = 'Order Value'.
          <fs_cond>-amount = lv_price.
          <fs_cond>-kwert  = lv_order_val.
          <fs_cond>-waers  = ls_zprq-waers.
        ENDIF.
      ENDLOOP.

      " >>>>>>>>>>>>>>> CASE 3: ZCRR (Credit Memo) <<<<<<<<<<<<<<<
    ELSEIF gv_order_type = 'ZCRR'.

      READ TABLE gt_conditions_alv INTO ls_zprq WITH KEY kschl = 'ZPRQ'.
      IF sy-subrc = 0. lv_price = ls_zprq-amount. ENDIF.

      DATA: lv_zcrp_pct TYPE kbetr.
      READ TABLE gt_conditions_alv INTO ls_zcrp WITH KEY kschl = 'ZCRP'.
      IF sy-subrc = 0. lv_zcrp_pct = ls_zcrp-amount. ENDIF.

      " --- TÍNH TOÁN VỚI DẤU ÂM ---
      DATA: v_base_val TYPE kwert, v_zcrp_val TYPE kwert,
            v_net1_val TYPE kwert, v_z100_val TYPE kwert, v_net2_val TYPE kwert.

      " 1. Base luôn là số âm (Credit)
      v_base_val = ( lv_price * lv_qty ) * -1.      " VD: -40.000

      " 2. ZCRP tính trên Base âm
      v_zcrp_val = ( v_base_val * lv_zcrp_pct ) / 100. " VD: -8.000

      " 3. Net 1 = Base + ZCRP
      v_net1_val = v_base_val + v_zcrp_val.         " VD: -48.000

      " 4. Z100 = -100% Base (Sẽ ra số Dương)
      v_z100_val = ( v_base_val * -100 ) / 100.     " VD: 40.000

      " 5. Net 2 = Net 1 + Z100
      v_net2_val = v_net1_val + v_z100_val.         " VD: -8.000

      " C. Update ALV
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
          WHEN 'ZPRQ'.
            <fs_cond>-kwert = v_base_val.
            <fs_cond>-icon  = icon_led_green.

          WHEN 'NETW'.
            <fs_cond>-amount = lv_price.
            <fs_cond>-kwert  = v_base_val.

          WHEN 'ZCRP'.
            <fs_cond>-kwert = v_zcrp_val.

          WHEN 'NET1'.
            <fs_cond>-kwert = v_net1_val.
            IF lv_qty <> 0. <fs_cond>-amount = abs( v_net1_val / lv_qty ). ENDIF.

          WHEN 'Z100'.
            <fs_cond>-kwert = v_z100_val.

          WHEN 'NET2'.
            <fs_cond>-kwert = v_net2_val.
            IF lv_qty <> 0. <fs_cond>-amount = abs( v_net2_val / lv_qty ). ENDIF.
        ENDCASE.
      ENDLOOP.

      " >>>>>>>>>>>>>>> CASE 3: ZRET (Returns) <<<<<<<<<<<<<<<
    ELSEIF gv_order_type = 'ZRET'.

      " A. Lấy giá ZPRQ
      READ TABLE gt_conditions_alv INTO ls_zprq WITH KEY kschl = 'ZPRQ'.
      IF sy-subrc = 0. lv_price = ls_zprq-amount. ENDIF.

      " B. Tính toán
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
          WHEN 'ZPRQ'.
            <fs_cond>-kwert = lv_price * lv_qty.
            lv_net_val      = <fs_cond>-kwert.
            <fs_cond>-icon  = icon_led_green.

          WHEN 'NETW'.
            <fs_cond>-kwert  = lv_net_val.
            <fs_cond>-amount = lv_price.
            <fs_cond>-waers  = ls_zprq-waers.
        ENDCASE.
      ENDLOOP.

      " >>>>>>>>>>>>>>> CASE 4: ZSC (Service/Commission) <<<<<<<<<<<<<<<
    ELSEIF gv_order_type = 'ZSC'.

      " A. Lấy Input
      READ TABLE gt_conditions_alv INTO ls_zprq WITH KEY kschl = 'ZPRQ'.
      IF sy-subrc = 0. lv_price = ls_zprq-amount. ENDIF.

      READ TABLE gt_conditions_alv INTO ls_zcf1 WITH KEY kschl = 'ZCF1'.
      IF sy-subrc = 0. lv_zcf1_pct = ls_zcf1-amount. ENDIF.

      READ TABLE gt_conditions_alv INTO ls_ztax WITH KEY kschl = 'ZTAX'.
      IF sy-subrc = 0. lv_tax_pct = ls_ztax-amount. ENDIF.

      " B. Tính toán biến trung gian
      lv_base_val = lv_price * lv_qty.                 " Base
      lv_zcf1_val = ( lv_base_val * lv_zcf1_pct ) / 100. " Commission Value
      lv_net1_val = lv_base_val + lv_zcf1_val.           " Net 1
      lv_z100_val = ( lv_base_val * -100 ) / 100.        " Z100 Value
      lv_net2_val = lv_net1_val + lv_z100_val.           " Net 2
      lv_tax_val  = ( lv_net2_val * lv_tax_pct ) / 100.  " Tax Value

      " C. Update ALV
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
          WHEN 'ZPRQ'.
            <fs_cond>-kwert = lv_base_val.
            <fs_cond>-icon  = icon_led_green.

          WHEN 'NETW'. " Net Value
            <fs_cond>-amount = lv_price.
            <fs_cond>-kwert  = lv_base_val.
            <fs_cond>-waers  = ls_zprq-waers.

          WHEN 'ZCF1'.
            <fs_cond>-kwert = lv_zcf1_val.

          WHEN 'NET1'. " Net Value 1
            <fs_cond>-kwert = lv_net1_val.
            IF lv_qty <> 0. <fs_cond>-amount = lv_net1_val / lv_qty. ENDIF.
            <fs_cond>-waers = ls_zprq-waers.

          WHEN 'Z100'.
            <fs_cond>-kwert = lv_z100_val.

          WHEN 'NET2'. " Net Value 2
            <fs_cond>-kwert = lv_net2_val.
            IF lv_qty <> 0. <fs_cond>-amount = lv_net2_val / lv_qty. ENDIF.
            <fs_cond>-waers = ls_zprq-waers.

          WHEN 'ZTAX'.
            <fs_cond>-kwert = lv_tax_val.

          WHEN 'GROS'.
            <fs_cond>-kwert = lv_net2_val + lv_tax_val.
            IF lv_qty <> 0. <fs_cond>-amount = <fs_cond>-kwert / lv_qty. ENDIF.
            <fs_cond>-waers = ls_zprq-waers.
        ENDCASE.
      ENDLOOP.

      " >>> [MỚI] CASE 5: ZFOC (Free of Charge)
    ELSEIF gv_order_type = 'ZFOC'.

      " 1. Lấy giá Base (Net Value)
      " Lưu ý: User không nhập được, nên lấy giá trị hiện tại trong bảng
      READ TABLE gt_conditions_alv INTO DATA(ls_base) WITH KEY kschl = 'NETW'.
      IF sy-subrc = 0. lv_price = ls_base-amount. ENDIF.

      " 2. Tính toán
      lv_base_val = lv_price * lv_qty.              " Base
      lv_z100_val = ( lv_base_val * -100 ) / 100.   " Z100
      lv_net1_val = lv_base_val + lv_z100_val.      " Net 1

      " 3. Update ALV
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond>.
        CASE <fs_cond>-kschl.
          WHEN 'NETW'.
            <fs_cond>-kwert = lv_base_val.

          WHEN 'Z100'.
            <fs_cond>-kwert = lv_z100_val.

          WHEN 'NET1'.
            <fs_cond>-kwert  = lv_net1_val.
            IF lv_qty <> 0. <fs_cond>-amount = lv_net1_val / lv_qty. ENDIF.
        ENDCASE.
      ENDLOOP.

    ENDIF.

    " -----------------------------------------------------------
    " 5. LƯU VÀO CACHE GLOBAL (QUAN TRỌNG)
    " -----------------------------------------------------------
    " Lấy Item No thực tế từ Index
    READ TABLE gt_item_details ASSIGNING <fs_detail> INDEX gv_current_item_idx.
    IF sy-subrc = 0.

      ls_cache-item_no    = <fs_detail>-item_no.
      ls_cache-conditions = gt_conditions_alv.

      " Update Cache
      INSERT ls_cache INTO TABLE gt_cond_cache.
      IF sy-subrc <> 0.
        MODIFY TABLE gt_cond_cache FROM ls_cache.
      ENDIF.
    ENDIF.

    " -----------------------------------------------------------
    " 6. REFRESH ALV (HARD REFRESH)
    " -----------------------------------------------------------
    IF go_grid_conditions IS BOUND.
      DATA: ls_stable TYPE lvc_s_stbl.
      ls_stable-row = 'X'.
      ls_stable-col = 'X'.
      go_grid_conditions->refresh_table_display( is_stable = ls_stable ).
      cl_gui_cfw=>flush( ).
    ENDIF.

  ENDMETHOD.

*METHOD HANDLE_DATA_CHANGED_FINISHED.
*    " Kiểm tra xem ALV nào đã gọi sự kiện này
*    IF mo_grid = go_grid_item_single.
*      " --- ALV Item Details (Screen 0112) đã thay đổi ---
*      PERFORM perform_single_item_simulate.
*
*      IF mo_grid IS BOUND.
*        " [ĐÃ XÓA] mo_grid->optimize_all_cols( ). <--- Dòng này gây lỗi
*
*        " Chỉ cần gọi refresh, việc co giãn sẽ do Layout đảm nhận
*        mo_grid->refresh_table_display( ).
*      ENDIF.
*
*      FIELD-SYMBOLS: <table> TYPE STANDARD TABLE.
*      ASSIGN mt_table->* TO <table>.
*      IF <table> IS ASSIGNED.
*        DATA(lv_entry_fin) = lines( <table> ).
*        mo_grid->set_gridtitle( |Item Details (Single Entry) ({ lv_entry_fin } rows)| ).
*      ENDIF.
*
*    ELSEIF mo_grid = go_grid_conditions.
*      " --- ALV Conditions (Screen 0113) đã thay đổi ---
*      " [LƯU Ý QUAN TRỌNG]: Nếu bạn đã đổi sang Structure ZSTR_... thì sửa dòng dưới
*      " thành: FIELD-SYMBOLS: <fs_item> TYPE zstr_su_alv_item.
*      " Còn nếu đang dùng TYPES cũ thì giữ nguyên dòng dưới:
*      FIELD-SYMBOLS: <fs_item>     TYPE ty_item_details,
*                     <fs_cond_alv> TYPE ty_cond_alv.
*
*      " 1. Đọc item chính (ví dụ: Item 1) đang được hiển thị
*      READ TABLE gt_item_details ASSIGNING <fs_item> INDEX gv_current_item_idx.
*      IF sy-subrc <> 0.
*        EXIT. " Không tìm thấy item, thoát
*      ENDIF.
*
*      LOOP AT gt_conditions_alv ASSIGNING <fs_cond_alv>
*        WHERE amount IS NOT INITIAL. " Chỉ lấy dòng user nhập/thay đổi
*
*        " 3. LƯU giá trị thủ công này vào "bộ nhớ" (bảng item chính)
*        IF <fs_cond_alv>-kschl <> 'MWST' AND <fs_cond_alv>-kschl <> 'NETW'
*           AND <fs_cond_alv>-kschl <> 'GRWR'.
*
*          <fs_item>-cond_type  = <fs_cond_alv>-kschl.
*          <fs_item>-unit_price = <fs_cond_alv>-amount.
*          <fs_item>-currency   = <fs_cond_alv>-waers.
*          EXIT.
*        ENDIF.
*      ENDLOOP.
*
*      " 4. Gọi lại PBO để TÍNH TOÁN LẠI
*      PERFORM display_conditions_for_item
*        USING gv_current_item_idx.
*    ENDIF.
*  ENDMETHOD.

  METHOD handle_data_changed_finished.

    " Khai báo biến để xử lý con trỏ (Cursor)
    DATA: ls_row_id    TYPE lvc_s_row.

    DATA: ls_row_no TYPE lvc_s_roid, " ID dòng (Stable Row ID)
          ls_col_id TYPE lvc_s_col.  " ID cột (Chứa Fieldname)

    DATA: lv_stay_row TYPE i,
          lv_stay_col TYPE fieldname.

    " --- CASE 1: GRID ITEM DETAILS (Screen 311) ---
    IF mo_grid = go_grid_item_single.

      mo_grid->get_current_cell(
      IMPORTING
        es_col_id = ls_col_id  " Lấy Structure cột (có chứa Fieldname)
        es_row_no = ls_row_no  " Lấy Stable Row ID
    ).

      " 1. Gọi logic tính giá (như cũ)
      PERFORM perform_single_item_simulate.

      " 2. [SỬA LẠI] LOGIC AUTO-APPEND: CHỈ KHI CÓ SỐ LƯỢNG MỚI THÊM
      FIELD-SYMBOLS: <table> TYPE STANDARD TABLE.
      ASSIGN mt_table->* TO <table>.

      IF <table> IS ASSIGNED.
        DATA(lv_lines) = lines( <table> ).
        IF lv_lines > 0.
          " Đọc dòng cuối cùng
          READ TABLE <table> ASSIGNING FIELD-SYMBOL(<ls_last>) INDEX lv_lines.
          IF sy-subrc = 0.

            " [THAY ĐỔI]: Kiểm tra trường QUANTITY thay vì MATNR
            ASSIGN COMPONENT 'QUANTITY' OF STRUCTURE <ls_last> TO FIELD-SYMBOL(<lv_qty>).
            ASSIGN COMPONENT 'MATNR'    OF STRUCTURE <ls_last> TO FIELD-SYMBOL(<lv_matnr>).

            " Điều kiện: Phải có Mã hàng VÀ Số lượng > 0 thì mới thêm dòng mới
            IF sy-subrc = 0 AND <lv_matnr> IS NOT INITIAL AND <lv_qty> > 0.

              " Nếu thỏa mãn -> Tự thêm dòng mới xuống dưới
              APPEND INITIAL LINE TO <table> ASSIGNING FIELD-SYMBOL(<ls_new>).

              " Tự đánh số item tiếp theo (VD: 30 -> 40)
              ASSIGN COMPONENT 'ITEM_NO' OF STRUCTURE <ls_new> TO FIELD-SYMBOL(<lv_new_item>).
              IF sy-subrc = 0.
                <lv_new_item> = ( lv_lines + 1 ) * 10.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.

        " Cập nhật tiêu đề số dòng
        DATA(lv_entry_fin) = lines( <table> ).
        mo_grid->set_gridtitle( |Item Details (Single Entry) ({ lv_entry_fin } rows)| ).
      ENDIF.

      LOOP AT et_good_cells INTO DATA(ls_cell).
        CASE ls_cell-fieldname.
            " Nếu vừa nhập MATERIAL -> Nhảy sang QUANTITY
          WHEN 'MATNR'.
            ls_col_id-fieldname = 'QUANTITY'. " Chỉ đổi tên cột đích
            " Lưu ý: ls_row_no đã giữ đúng dòng hiện tại từ bước A rồi
        ENDCASE.
      ENDLOOP.

      PERFORM prepare_single_item_styles.

      " 3. Refresh Grid
      IF mo_grid IS BOUND.
        DATA: ls_stable TYPE lvc_s_stbl.
        ls_stable-row = 'X'.
        ls_stable-col = 'X'.
        mo_grid->refresh_table_display( is_stable = ls_stable ).

        CALL METHOD mo_grid->set_current_cell_via_id
          EXPORTING
            is_row_no    = ls_row_no    " Dòng ổn định (Stable Row)
            is_column_id = ls_col_id.   " Cột đích (Fieldname)
      ENDIF.

      " --- CASE 2: GRID CONDITIONS (Screen 312) ---
    ELSEIF mo_grid = go_grid_conditions.

      " [LƯU Ý]: Vẫn giữ nguyên logic cũ của Conditions
      " Nếu bạn đã dùng Structure ZSTR... thì sửa Type ở đây, còn không thì giữ nguyên
      FIELD-SYMBOLS: <fs_item>     TYPE zstr_su_alv_item, " <-- Đã sửa theo Structure mới
                     <fs_cond_alv> TYPE ty_cond_alv.

      " Logic đọc Item hiện tại
      READ TABLE gt_item_details ASSIGNING <fs_item> INDEX gv_current_item_idx.
      IF sy-subrc <> 0. EXIT. ENDIF.

      " Logic cập nhật giá tay
      LOOP AT gt_conditions_alv ASSIGNING <fs_cond_alv> WHERE amount IS NOT INITIAL.
        IF <fs_cond_alv>-kschl <> 'MWST' AND <fs_cond_alv>-kschl <> 'NETW' AND <fs_cond_alv>-kschl <> 'GRWR'.
          <fs_item>-cond_type  = <fs_cond_alv>-kschl.
          <fs_item>-unit_price = <fs_cond_alv>-amount.
          <fs_item>-currency   = <fs_cond_alv>-waers.
          EXIT.
        ENDIF.
      ENDLOOP.

      " Tính toán lại
      PERFORM display_conditions_for_item USING gv_current_item_idx.

    ENDIF.
  ENDMETHOD.

  METHOD handle_hotspot_click.

    DATA: lv_temp_id TYPE ztb_so_upload_it-temp_id,
          lv_item_no TYPE ztb_so_upload_it-item_no.

    IF e_column_id = 'ERR_BTN'.

      " 1. Nếu click trên lưới ITEMS (Màn 0211)
      IF sender = go_mu_alv_items.
        READ TABLE gt_disp_items INTO DATA(ls_item) INDEX e_row_id-index.
        IF sy-subrc = 0.
          " Gọi Popup
          PERFORM show_error_details_popup USING gv_current_req_id
                                                 ls_item-temp_id
                                                 ls_item-item_no.
        ENDIF.
        RETURN.
      ENDIF.

      " 2. Nếu click trên lưới CONDITIONS (Màn 0212)
      IF sender = go_mu_alv_cond.
        READ TABLE gt_disp_cond INTO DATA(ls_cond) INDEX e_row_id-index.
        IF sy-subrc = 0.
          " Gọi Popup
          PERFORM show_error_details_popup USING gv_current_req_id
                                                 ls_cond-temp_id
                                                 ls_cond-item_no.
        ENDIF.
        RETURN.
      ENDIF.

    ENDIF.

  ENDMETHOD.
ENDCLASS.
*======================================================================*
* SECTION 2: WELCOME SCREEN LOGIC (DISPLAY)
*======================================================================*
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_WELCOME_SCREEN
*&---------------------------------------------------------------------*
FORM display_welcome_screen.

  DATA: lv_html     TYPE string,
        lt_html     TYPE STANDARD TABLE OF w3html,
        ls_html     TYPE w3html,
        lv_url      TYPE char1024,
        lv_len      TYPE i,
        lv_off      TYPE i,
        lv_chunklen TYPE i.

  "--------------------------------------------------------------------
  " 1. Tạo Container
  "--------------------------------------------------------------------
*  IF go_summary_container IS INITIAL.
*    CREATE OBJECT go_summary_container
*      EXPORTING
*        container_name = 'CC_SUMMARY'.
*  ENDIF.
*
*  IF go_html_viewer IS INITIAL.
*    CREATE OBJECT go_html_viewer
*      EXPORTING
*        parent = go_summary_container.
*  ENDIF.

  "--------------------------------------------------------------------
  " 2. Xây dựng nội dung HTML (Đã tối ưu Responsive)
  "--------------------------------------------------------------------
  CLEAR lv_html.

  CONCATENATE lv_html
    '<!DOCTYPE html>'
    '<html><head>'
    '<meta charset="UTF-8">'
    '<meta http-equiv="X-UA-Compatible" content="IE=edge">' "Giúp render tốt hơn trên SAP GUI mới
    '<style>'

    " --- Global Style & Reset ---
    '* { box-sizing: border-box; }' "Quan trọng: giúp padding không làm vỡ khung
    'body { font-family: "Segoe UI", Arial, sans-serif; background-color: #f8f9fa;'
    '       margin: 0; padding: 20px;'
    '       height: 100vh; width: 100%;' "Chiếm toàn bộ chiều cao/rộng viewport
    '       overflow-y: auto; overflow-x: hidden;' "Cho phép cuộn dọc nếu cần, ẩn cuộn ngang
    '       display: flex; flex-direction: column; align-items: center; justify-content: center; }' "Căn giữa toàn màn hình

    " --- Typography ---
    'h1 { color: #1a73e8; margin: 0 0 10px 0; font-size: 2.2rem; font-weight: 600; text-align: center; }'
    '.subtitle { color: #5f6368; font-size: 1rem; margin-bottom: 40px; max-width: 90%;'
    '            line-height: 1.5; text-align: center; }'

    " --- Grid Steps (Dàn ngang responsive) ---
    '.row { display: flex; gap: 20px; justify-content: center;'
    '       width: 100%; max-width: 100%; padding: 0 20px;' "Bỏ giới hạn 1200px cứng, dùng padding
    '       flex-wrap: wrap; }' "Quan trọng: Tự xuống dòng nếu màn hình nhỏ

    '.step-card { flex: 1 1 300px; ' "Tham số flex: grow shrink basis (tối thiểu 300px)
    '             background: #ffffff; padding: 25px; border-radius: 12px;'
    '             border: 1px solid #e1e4e8; max-width: 400px;' "Không cho card quá to
    '             box-shadow: 0 4px 12px rgba(0,0,0,0.05); transition: all 0.3s ease;'
    '             display: flex; flex-direction: column; align-items: center; text-align: center; }'

    '.step-card:hover { transform: translateY(-5px); box-shadow: 0 8px 20px rgba(0,0,0,0.1); border-color: #d2e3fc; }'

    " --- Elements ---
    '.icon-box { width: 50px; height: 50px; background: #e8f0fe; border-radius: 50%;'
    '            display: flex; align-items: center; justify-content: center; margin-bottom: 15px;'
    '            color: #1967d2; font-weight: bold; font-size: 20px; }'

    '.step-title { font-size: 1.1rem; font-weight: 700; color: #202124; margin-bottom: 10px; }'
    '.step-desc { font-size: 0.9rem; color: #5f6368; line-height: 1.5; }'

    " --- Footer Hint ---
    '.footer-hint { margin-top: 40px; background: #e3f2fd; color: #1a73e8; padding: 12px 25px;'
    '               border-radius: 50px; display: inline-flex; align-items: center;'
    '               font-size: 0.95rem; border: 1px solid #bbdefb; font-weight: 500; }'
    '.footer-hint span { font-size: 1.2rem; margin-right: 8px; }'

    'b { color: #1a73e8; }'

    '</style></head><body>'

    '<h1>Mass Sales Order Upload</h1>'
    '<p class="subtitle">Streamline your sales process. Upload your Excel file to automatically generate a hierarchical view of your orders.</p>'

    '<div class="row">'

      " --- STEP 1 ---
      '<div class="step-card">'
        '<div class="icon-box">1</div>'
        '<div class="step-title">Upload File</div>'
        '<div class="step-desc">Click the <b>Upload File</b> button in the toolbar. System will enrich master data automatically.</div>'
      '</div>'

      " --- STEP 2 ---
      '<div class="step-card">'
        '<div class="icon-box">2</div>'
        '<div class="step-title">Interactive Tree</div>'
        '<div class="step-desc">A <b>Tree Structure</b> will appear on the left. <br>Double-click <b>ID</b> to view details.</div>'
      '</div>'

      " --- STEP 3 ---
      '<div class="step-card">'
        '<div class="icon-box">3</div>'
        '<div class="step-title">Validate & Create</div>'
        '<div class="step-desc">Use <b>Validate</b> to check errors. Then click <b>Create Sales Order</b> to post to SAP.</div>'
      '</div>'

    '</div>'

    '<div class="footer-hint">'
      '<span>👉</span> Ready to begin? Please click the&nbsp;<b>Upload File</b>&nbsp;button.'
    '</div>'

    '</body></html>'
  INTO lv_html SEPARATED BY space.

  "--------------------------------------------------------------------
  " 3. Convert String to HTML Table
  "--------------------------------------------------------------------
  CLEAR lt_html.
  lv_len = strlen( lv_html ).
  lv_off = 0.

  WHILE lv_off < lv_len.
    lv_chunklen = lv_len - lv_off.
    IF lv_chunklen > 255. lv_chunklen = 255. ENDIF.
    CLEAR ls_html.
    ls_html-line = lv_html+lv_off(lv_chunklen).
    APPEND ls_html TO lt_html.
    lv_off = lv_off + lv_chunklen.
  ENDWHILE.

  "--------------------------------------------------------------------
  " 4. Load Data
  "--------------------------------------------------------------------
  go_html_viewer->load_data(
    EXPORTING type = 'text/html'
    IMPORTING assigned_url = lv_url
    CHANGING  data_table   = lt_html
  ).

  go_html_viewer->show_url( lv_url ).

ENDFORM.

*======================================================================*
* SECTION 2: LOGIC EXCEL READ AND UPLOAD
*======================================================================*

*&---------------------------------------------------------------------*
*& Form download_template
*&---------------------------------------------------------------------*
*& Description: Template Excel Download
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM download_template.
  DATA: lv_folder    TYPE string,
        lv_full_path TYPE rlgrap-filename,
        lv_objid     TYPE wwwdata-objid,
        lwa_data     TYPE wwwdatatab,
        lv_subrc     TYPE sy-subrc,
        lwa_rec      TYPE wwwdatatab.

  " --- 1. Object SMWO of the program
  lv_objid = 'ZSD4_FILE_TEMPLATE7'. " (Tên bạn đã upload ở Bước 1)

  "--- 2. Display dialog choosing Folder
  CALL METHOD cl_gui_frontend_services=>directory_browse
    EXPORTING
      window_title         = 'Choose folder to save template file'
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.
  IF sy-subrc <> 0 OR lv_folder IS INITIAL.
    MESSAGE 'Cancelled' TYPE 'I'.
    EXIT.
  ENDIF.

  "--- 3. Name of the file template
  CONCATENATE lv_folder '\ZSD4_TEMPLATE_MASS.xlsx' INTO lv_full_path.

  "--- 4. Take object SMWO
  SELECT SINGLE relid, objid INTO CORRESPONDING FIELDS OF @lwa_rec
    FROM wwwdata
    WHERE srtf2 = 0
      AND relid = 'MI'
      AND objid = @lv_objid.
  IF sy-subrc <> 0.
    MESSAGE |Template not found '{ lv_objid }' in SMW0!| TYPE 'E'.
    EXIT.
  ENDIF.
  lwa_data = CORRESPONDING #( lwa_rec ).

  "--- 5. Download File
  CALL FUNCTION 'DOWNLOAD_WEB_OBJECT'
    EXPORTING
      key         = lwa_data
      destination = lv_full_path
    IMPORTING
      rc          = lv_subrc.

  IF lv_subrc = 0.
    MESSAGE |Download template successfully: { lv_full_path }| TYPE 'S'.
  ELSE.
    MESSAGE 'Error file downloading from SMW0!' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form generate_request_id
*&---------------------------------------------------------------------*
*& Description: Request ID Auto Generate For Each File Uploaded
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM generate_request_id CHANGING cv_req_id TYPE zsd_req_id.
  DATA: lv_max_id TYPE zsd_req_id,
        lv_num    TYPE n LENGTH 7.

  " 1. Find the largest ID in the header table
  SELECT MAX( req_id )
    FROM ztb_so_upload_hd
    INTO lv_max_id
    WHERE req_id LIKE 'REQ%'.

  " 2. Calculate new ID
  IF lv_max_id IS INITIAL.
    " In case of of no data: Begin from 1
    lv_num = 1.
  ELSE.
    " Take the number (remove the 'REQ' from start) and plus 1
    " For example: 'REQ0000015' -> Take '0000015' ->Plus 1 = 16
    lv_num = lv_max_id+3(7).
    lv_num = lv_num + 1.
  ENDIF.

  " 3. Combine into complete string (Ví dụ: REQ0000016)
  cv_req_id = |REQ{ lv_num }|.
ENDFORM.

FORM upload_file
  USING
    iv_path   TYPE string
    iv_req_id TYPE zsd_req_id
  CHANGING
    ct_header TYPE STANDARD TABLE
    ct_item   TYPE STANDARD TABLE
    ct_cond   TYPE STANDARD TABLE.

  DATA: lo_excel_ref TYPE REF TO cl_fdt_xl_spreadsheet,
        lv_xstring   TYPE xstring,
        lv_len       TYPE i,
        lt_bin       TYPE solix_tab.

  DATA: lo_data_ref TYPE REF TO data.

  DATA: lv_raw_val TYPE string.

  FIELD-SYMBOLS: <gt_data_raw> TYPE STANDARD TABLE,
                 <fs_raw>      TYPE any.

  " --- 1. Đọc File ---
  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      filename                = iv_path
      filetype                = 'BIN'
    IMPORTING
      filelength              = lv_len
    TABLES
      data_tab                = lt_bin
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      OTHERS                  = 17.

  IF sy-subrc <> 0. MESSAGE 'Cannot read file.' TYPE 'E'. ENDIF.

  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING
      input_length = lv_len
    IMPORTING
      buffer       = lv_xstring
    TABLES
      binary_tab   = lt_bin
    EXCEPTIONS
       FAILED             = 1
       OTHERS             = 2.

    IF sy-subrc <> 0.
      MESSAGE 'Error converting binary to xstring.' TYPE 'E'.
    ENDIF.

  TRY.
*      CREATE OBJECT lo_excel_ref EXPORTING xdocument = lv_xstring.
      CREATE OBJECT lo_excel_ref
        EXPORTING
          xdocument     = lv_xstring
          document_name = iv_path.
    CATCH cx_root.
      MESSAGE 'Invalid Excel format.' TYPE 'E'.
  ENDTRY.

  " ====================================================================
  " XỬ LÝ SHEET HEADER
  " ====================================================================
  " 2. Validate Cấu trúc Header (Dùng FORM validate_template_structure của bạn)
  " (Lưu ý: FORM này chỉ check dòng tiêu đề, không trả về dữ liệu mapped)
  PERFORM validate_template_structure
    USING lo_excel_ref 'Header' 'ztb_so_upload_hd'
    CHANGING lo_data_ref.

  " Check the Boundary before Assigning"
  " Check if Validation was successful?"
  IF lo_data_ref IS NOT BOUND.
    RETURN.
  ENDIF.

  " Point the Field Symbol to the memory area containing the Header data.
  ASSIGN lo_data_ref->* TO <gt_data_raw>.
  IF <gt_data_raw> IS INITIAL. RETURN. ENDIF.

  " --- 3. Mapping Header ---
*  DELETE <gt_data_raw> INDEX 1. " Xoa tiêu đề

  LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
    DATA(ls_header) = VALUE ztb_so_upload_hd( ). " Creating a hollow structure"

    " Mapping each Excel column (in order 1, 2, 3...) to a temporary variable"
    ASSIGN COMPONENT 1  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<h_temp_id>).
    ASSIGN COMPONENT 2  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<order_type>).
    ASSIGN COMPONENT 3  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<sales_org>).
    ASSIGN COMPONENT 4  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<dist_chnl>).
    ASSIGN COMPONENT 5  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<division>).
    ASSIGN COMPONENT 6  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<sales_off>).
    ASSIGN COMPONENT 7  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<sales_grp>).
    ASSIGN COMPONENT 8  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<sold_to>).
    ASSIGN COMPONENT 9  OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<cust_ref>).
    ASSIGN COMPONENT 10 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<req_date>).
    ASSIGN COMPONENT 11 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<pmnttrms>).
    ASSIGN COMPONENT 12 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<incoterms>).
    ASSIGN COMPONENT 13 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<inco2>).

    " If this line does not have a Temp ID (e.g., the last blank line in the file) -> Ignore"
    CHECK <h_temp_id> IS ASSIGNED AND <h_temp_id> IS NOT INITIAL.

    " Date processing (converting Excel format to SAP YYYYMMDD)"
    DATA: lv_req_dats TYPE dats.
    IF <req_date> IS ASSIGNED.
      PERFORM convert_date_ddmmyyyy USING <req_date>
                                    CHANGING lv_req_dats.
    ENDIF.
    " (Assign to Structure Z-Table)
    ls_header-req_id           = iv_req_id.
    ls_header-status           = 'NEW'.
    ls_header-created_by       = sy-uname.
    ls_header-created_on       = sy-datum.

    ls_header-temp_id          = COND #( WHEN <h_temp_id> IS ASSIGNED THEN <h_temp_id> ).
    ls_header-order_type       = COND #( WHEN <order_type> IS ASSIGNED THEN <order_type> ).
    ls_header-sales_org        = COND #( WHEN <sales_org> IS ASSIGNED THEN <sales_org> ).
    ls_header-sales_channel    = COND #( WHEN <dist_chnl> IS ASSIGNED THEN <dist_chnl> ).
    ls_header-sales_div        = COND #( WHEN <division> IS ASSIGNED THEN <division> ).
    ls_header-sales_off        = COND #( WHEN <sales_off> IS ASSIGNED THEN <sales_off> ).
    ls_header-sales_grp        = COND #( WHEN <sales_grp> IS ASSIGNED THEN <sales_grp> ).
    ls_header-sold_to_party    = COND #( WHEN <sold_to>    IS ASSIGNED THEN <sold_to> ).
    ls_header-cust_ref         = COND #( WHEN <cust_ref>   IS ASSIGNED THEN <cust_ref> ).
    ls_header-req_date = lv_req_dats.
    ls_header-pmnttrms         = COND #( WHEN <pmnttrms>   IS ASSIGNED THEN <pmnttrms> ).
    ls_header-incoterms        = COND #( WHEN <incoterms>  IS ASSIGNED THEN <incoterms> ).
    ls_header-inco2            = COND #( WHEN <inco2>      IS ASSIGNED THEN <inco2> ).

    APPEND ls_header TO ct_header.
  ENDLOOP.

  " ====================================================================
  " B. XỬ LÝ ITEM (7 Cột - Fixed)
  " ====================================================================
  CLEAR lo_data_ref.
  PERFORM validate_template_structure USING lo_excel_ref 'Item' 'ZTB_SO_UPLOAD_IT' CHANGING lo_data_ref.

  IF lo_data_ref IS NOT BOUND. RETURN. ENDIF.
  ASSIGN lo_data_ref->* TO <gt_data_raw>.
  IF <gt_data_raw> IS INITIAL. RETURN. ENDIF.

  LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
    DATA(ls_item) = VALUE ztb_so_upload_it( ).

    ASSIGN COMPONENT 1 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<i_temp_id>).
    ASSIGN COMPONENT 2 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<item_no>).
    ASSIGN COMPONENT 3 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<matnr>).
    ASSIGN COMPONENT 4 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<plant>).
    ASSIGN COMPONENT 5 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<ship_point>).
    ASSIGN COMPONENT 6 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<stloc>).
    ASSIGN COMPONENT 7 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<qty>).

    CHECK <i_temp_id> IS ASSIGNED AND <i_temp_id> IS NOT INITIAL.

    ls_item-req_id     = iv_req_id.
    ls_item-status     = 'NEW'.
    ls_item-created_by = sy-uname.
    ls_item-created_on = sy-datum.
    ls_item-temp_id    = COND #( WHEN <i_temp_id> IS ASSIGNED THEN <i_temp_id> ).

    IF <item_no> IS ASSIGNED.
      TRY.
          " 1. Ép kiểu
          ls_item-item_no = <item_no>.
          " 2. Check dấu âm (Manual Check)
          IF <item_no> CS '-'.
            ls_item-item_no = '000000'.
          ENDIF.
        CATCH cx_sy_conversion_no_number.
          " [LỖI]: Nhập chữ (10A, Item10)
          ls_item-item_no = '000000'.
        CATCH cx_sy_conversion_overflow.
          " [LỖI]: Tràn số
          ls_item-item_no = '000000'.
      ENDTRY.
    ELSE.
      ls_item-item_no = '000000'.
    ENDIF.

    ls_item-material    = COND #( WHEN <matnr> IS ASSIGNED THEN <matnr> ). " [FIX]: Dùng MATERIAL
    ls_item-plant       = COND #( WHEN <plant> IS ASSIGNED THEN <plant> ).
    ls_item-ship_point  = COND #( WHEN <ship_point> IS ASSIGNED THEN <ship_point> ).
    ls_item-store_loc   = COND #( WHEN <stloc> IS ASSIGNED THEN <stloc> ).
*    ls_item-quantity    = COND #( WHEN <qty> IS ASSIGNED THEN <qty> ).
    IF <qty> IS ASSIGNED.
      TRY.
          " 1. Thử ép kiểu từ Excel vào biến số
          " Nếu <qty> là 'ab', dòng này sẽ bắn lỗi cx_sy_conversion_no_number ngay
          " Nếu <qty> là số quá lớn, dòng này sẽ bắn lỗi cx_sy_conversion_overflow
          ls_item-quantity = <qty>.

          " 2. Kiểm tra Logic Giới hạn (Restriction) - Business Logic
          " Mặc dù biến có thể chứa số lớn, nhưng nghiệp vụ có thể chỉ cho phép max 100,000
          " Bạn sửa con số 999999999 thành giới hạn mong muốn của dự án
          IF ls_item-quantity > 999999999.
            ls_item-quantity = 0.
            " (Optional) Ghi log lỗi tại đây nếu cần: 'Quantity exceeds limit'
          ENDIF.

          " 3. Kiểm tra số âm (Nếu nghiệp vụ không cho phép)
          IF ls_item-quantity < 0.
            ls_item-quantity = 0.
          ENDIF.

        CATCH cx_sy_conversion_no_number.
          " [QUAN TRỌNG]: Bắt lỗi nhập chữ (ví dụ 'ab', 'xyz', '10 boxes')
          ls_item-quantity = 0.

        CATCH cx_sy_conversion_overflow.
          " [QUAN TRỌNG]: Bắt lỗi số quá khủng (tràn biến chứa)
          ls_item-quantity = 0.

      ENDTRY.
    ELSE.
      " Trường hợp cột đó không tồn tại trong Excel hoặc chưa assign
      ls_item-quantity = 0.
    ENDIF.

    APPEND ls_item TO ct_item.
  ENDLOOP.

  " ====================================================================
  " C. XỬ LÝ CONDITION (7 Cột - Fixed)
  " ====================================================================
  CLEAR lo_data_ref.
  PERFORM validate_template_structure USING lo_excel_ref 'Condition' 'ZTB_SO_UPLOAD_PR' CHANGING lo_data_ref.

  IF lo_data_ref IS BOUND.
    ASSIGN lo_data_ref->* TO <gt_data_raw>.

    LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
      DATA(ls_cond) = VALUE ztb_so_upload_pr( ).

      ASSIGN COMPONENT 1 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_temp_id>).
      ASSIGN COMPONENT 2 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_item_no>).
      ASSIGN COMPONENT 3 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_type>).
      ASSIGN COMPONENT 4 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_amount>).
      ASSIGN COMPONENT 5 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_curr>).
      ASSIGN COMPONENT 6 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_per>).
      ASSIGN COMPONENT 7 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_uom>).

      CHECK <c_temp_id> IS ASSIGNED AND <c_temp_id> IS NOT INITIAL.

      ls_cond-req_id     = iv_req_id.
      ls_cond-status     = 'NEW'.
      ls_cond-created_by = sy-uname.
      ls_cond-created_on = sy-datum.
      ls_cond-temp_id    = <c_temp_id>.

      IF <c_item_no> IS ASSIGNED.
        TRY.
            " 1. Ép kiểu
            ls_cond-item_no = <c_item_no>.
            " 2. Check dấu âm
            IF <c_item_no> CS '-'.
              ls_cond-item_no = '000000'.
            ENDIF.
          CATCH cx_sy_conversion_no_number.
            ls_cond-item_no = '000000'.
          CATCH cx_sy_conversion_overflow.
            ls_cond-item_no = '000000'.
        ENDTRY.
      ELSE.
        ls_cond-item_no = '000000'.
      ENDIF.

      ls_cond-cond_type  = COND #( WHEN <c_type> IS ASSIGNED THEN <c_type> ).
      ls_cond-currency   = COND #( WHEN <c_curr> IS ASSIGNED THEN <c_curr> ).
      ls_cond-uom        = COND #( WHEN <c_uom>  IS ASSIGNED THEN <c_uom> ).

      IF <c_amount> IS ASSIGNED. TRY. ls_cond-amount = <c_amount>. CATCH cx_root. ENDTRY. ENDIF.
*      IF <c_per>    IS ASSIGNED. TRY. ls_cond-per    = <c_per>.    CATCH cx_root. ENDTRY. ENDIF.

      IF <c_per> IS ASSIGNED. TRY. ls_cond-per = <c_per>. CATCH cx_root. ENDTRY. ENDIF.

      " [THÊM MỚI]: Tự động đánh số thứ tự để tránh trùng khóa DB
      " (Mỗi dòng excel sẽ có 1 số khác nhau, vd: 1, 2, 3...)
      ls_cond-counter = sy-tabix.

      APPEND ls_cond TO ct_cond.

    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form convert_date_ddmmyyyy
*&---------------------------------------------------------------------*
*& Description: Convert date into format dd/mm/yyyy
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM convert_date_ddmmyyyy USING    iv_date_any TYPE any
                           CHANGING cv_dats     TYPE dats.

  DATA: lv_raw TYPE string.
  CLEAR cv_dats.

  " 1) Empty? -> return
  IF iv_date_any IS INITIAL.
    RETURN.
  ENDIF.

  " 2) To string & trim
  lv_raw = |{ iv_date_any }|.
  SHIFT lv_raw LEFT  DELETING LEADING space.
  SHIFT lv_raw RIGHT DELETING TRAILING space.

  " --- Handle potential Excel serial number ---
  IF lv_raw CO '0123456789'. " Check if it's purely numeric
    TRY.
        DATA(lv_num_days) = CONV i( lv_raw ).
        " Excel base date is 1899-12-31 (day 0) for calculation purposes
        " Excel base date is 1899-12-31 (day 0) for calculation purposes
        " Excel incorrectly treats 1900 as a leap year (day 60 = Feb 29).
        " Correct by subtracting 1 day for dates AFTER Feb 28, 1900 (day 59).
        IF lv_num_days > 59.
          lv_num_days = lv_num_days - 1.
        ENDIF.

        cv_dats = '18991231'. " Base date for calculation
        cv_dats = cv_dats + lv_num_days.

        " Check if the resulting date is plausible (valid date)
        CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
          EXPORTING
            date   = cv_dats
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc = 0.
          RETURN. " Successfully converted from serial number
        ELSE.
          CLEAR cv_dats.
          lv_raw = ''. " Conversion failed, try other formats if original wasn't purely numeric
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        CLEAR cv_dats.
        lv_raw = ''. " Not a valid number or calc error, try other formats
    ENDTRY.
    " If purely numeric but conversion failed OR RETURNED above, exit.
    " If not purely numeric originally, lv_raw was cleared, forcing exit below.
    IF lv_raw IS INITIAL AND cv_dats IS INITIAL.
      RETURN.
    ENDIF.

  ENDIF.
  " --- END Handle Excel Serial ---

  " 3) Attempt processing as formatted string (if not converted from serial)
  " Remove common non-digits (flexible separators)
  REPLACE ALL OCCURRENCES OF PCRE '[^0-9]' IN lv_raw WITH ''.

  " 4) Only handle 8 digits after cleaning
  IF strlen( lv_raw ) <> 8.
    RETURN. " Cannot determine format
  ENDIF.

  " 5) Detect format (Assuming YYYYMMDD or DDMMYYYY after cleaning)
  IF lv_raw+0(4) BETWEEN '1900' AND '2100'. " Looks like yyyymmdd
    cv_dats = lv_raw.
  ELSE. " Assume ddmmyyyy -> yyyymmdd
    cv_dats = |{ lv_raw+4(4) }{ lv_raw+2(2) }{ lv_raw(2) }|.
  ENDIF.

  " 6. Final Plausibility Check
  CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
    EXPORTING
      date   = cv_dats
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    CLEAR cv_dats. " Invalid date created
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  EXEC_ENRICH_RAW_DATA
*&---------------------------------------------------------------------*
* Tự động điền các trường thiếu (Autofill) dựa trên Master Data
*----------------------------------------------------------------------*
FORM exec_enrich_raw_data
  CHANGING pt_hd TYPE STANDARD TABLE
           pt_it TYPE STANDARD TABLE
           pt_pr TYPE STANDARD TABLE.

  " --- 1. Khai báo FIELD-SYMBOL có cấu trúc CỤ THỂ ---
  " Đây là chìa khóa để xử lý bảng Generic
  FIELD-SYMBOLS: <fs_hd> TYPE ztb_so_upload_hd,
                 <fs_it> TYPE ztb_so_upload_it,
                 <fs_pr> TYPE ztb_so_upload_pr.

  " --- Biến cục bộ cho Master Data ---
  DATA: ls_knvv  TYPE knvv,
        ls_mvke  TYPE mvke,
        ls_mara  TYPE mara,
        ls_makt  TYPE makt,
        ls_tvstz TYPE tvstz.

  DATA: lv_posnr_counter TYPE posnr_va,
        lv_prev_tempid   TYPE char10,
        lv_kunnr_pad     TYPE kunnr,
        lv_matnr_pad     TYPE matnr.

  " ==============================================================================
  " 1. HEADER ENRICHMENT
  " ==============================================================================
  LOOP AT pt_hd ASSIGNING FIELD-SYMBOL(<fs_gen_hd>).

    " [QUAN TRỌNG]: Ép kiểu (Cast) từ Generic sang Cụ thể
    ASSIGN <fs_gen_hd> TO <fs_hd> CASTING.

    " A. Default Req Date
    IF <fs_hd>-req_date IS INITIAL.
      <fs_hd>-req_date = sy-datum.
    ENDIF.

    " B. Autofill từ Customer Master (KNVV)
    IF <fs_hd>-sold_to_party IS NOT INITIAL AND <fs_hd>-sales_org IS NOT INITIAL.

      " Xử lý số 0 cho Customer (Ví dụ: 100 -> 0000000100) để Select được DB
      lv_kunnr_pad = <fs_hd>-sold_to_party.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_kunnr_pad
        IMPORTING
          output = lv_kunnr_pad.

      SELECT SINGLE zterm, inco1, inco2, waers
        FROM knvv
        INTO CORRESPONDING FIELDS OF @ls_knvv
        WHERE kunnr = @lv_kunnr_pad
          AND vkorg = @<fs_hd>-sales_org
          AND vtweg = @<fs_hd>-sales_channel
          AND spart = @<fs_hd>-sales_div.

      IF sy-subrc = 0.
        IF <fs_hd>-pmnttrms  IS INITIAL. <fs_hd>-pmnttrms  = ls_knvv-zterm. ENDIF.
        IF <fs_hd>-incoterms IS INITIAL. <fs_hd>-incoterms = ls_knvv-inco1. ENDIF.
        IF <fs_hd>-inco2     IS INITIAL. <fs_hd>-inco2     = ls_knvv-inco2. ENDIF.
        IF <fs_hd>-currency  IS INITIAL. <fs_hd>-currency  = ls_knvv-waers. ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " ==============================================================================
  " 2. ITEM ENRICHMENT
  " ==============================================================================
  " Sắp xếp bảng Item theo TempID và ItemNo để đánh số thứ tự đúng
  " (Cú pháp dynamic sort cho bảng generic)
  SORT pt_it BY ('TEMP_ID') ('ITEM_NO').

  lv_prev_tempid = ''.

  LOOP AT pt_it ASSIGNING FIELD-SYMBOL(<fs_gen_it>).

    " [QUAN TRỌNG]: Ép kiểu Item
    ASSIGN <fs_gen_it> TO <fs_it> CASTING.

    " A. Tự động đánh số Item (10, 20...)
    " Check if you are on a new or old order (TEMP_ID changes).
    IF <fs_it>-temp_id <> lv_prev_tempid.
      lv_posnr_counter = 10.
      lv_prev_tempid = <fs_it>-temp_id.
    ELSE.
      lv_posnr_counter = lv_posnr_counter + 10.
    ENDIF.

*    IF <fs_it>-item_no IS INITIAL OR <fs_it>-item_no = '000000'.
*      <fs_it>-item_no = lv_posnr_counter.
*      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*        EXPORTING
*          input  = <fs_it>-item_no
*        IMPORTING
*          output = <fs_it>-item_no.
*    ENDIF.

    IF <fs_it>-item_no IS INITIAL OR <fs_it>-item_no = '000000'.
      " Case 1: Không nhập hoặc nhập lỗi (bị gán 000000 ở bước Upload)
      " -> Tự động điền 10, 20, 30...
      <fs_it>-item_no = lv_posnr_counter.

      " Format lại cho chuẩn 6 số (vd: 10 -> 000010)
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = <fs_it>-item_no
        IMPORTING
          output = <fs_it>-item_no.

    ELSE.
      " Case 2: User có nhập (vd: 10, 20)
      " -> Chỉ cần format lại thêm số 0 vào đầu
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = <fs_it>-item_no
        IMPORTING
          output = <fs_it>-item_no.
    ENDIF.

    " B. Tìm Header tương ứng để lấy Sales Org (Cần cho việc tìm Plant)
    " (Vì bảng Header là generic, ta phải loop để tìm, không READ TABLE KEY được dễ dàng)
    DATA(ls_hd_found) = abap_false.
    DATA: ls_hd_ref TYPE ztb_so_upload_hd.

    LOOP AT pt_hd ASSIGNING <fs_gen_hd>.
      ASSIGN <fs_gen_hd> TO <fs_hd> CASTING.
      IF <fs_hd>-temp_id = <fs_it>-temp_id.
        ls_hd_ref   = <fs_hd>.
        ls_hd_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF ls_hd_found = abap_true AND <fs_it>-material IS NOT INITIAL.

      " Xử lý số 0 cho Material (Matnr)
      lv_matnr_pad = <fs_it>-material.
      CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
        EXPORTING
          input  = lv_matnr_pad
        IMPORTING
          output = lv_matnr_pad.

      " 1. Lấy Description (MAKT)
      IF <fs_it>-short_text IS INITIAL.
        SELECT SINGLE maktx FROM makt INTO <fs_it>-short_text
          WHERE matnr = lv_matnr_pad AND spras = sy-langu.
      ENDIF.

      " 2. Lấy UOM (MARA)
      IF <fs_it>-unit IS INITIAL.
        SELECT SINGLE meins FROM mara INTO <fs_it>-unit WHERE matnr = lv_matnr_pad.
      ENDIF.

      " 3. Lấy Plant (MVKE - Sales View)
      IF <fs_it>-plant IS INITIAL.
        SELECT SINGLE dwerk FROM mvke INTO <fs_it>-plant
          WHERE matnr = lv_matnr_pad
            AND vkorg = ls_hd_ref-sales_org
            AND vtweg = ls_hd_ref-sales_channel.
      ENDIF.

      " 4. Lấy Storage Location (MARD)
      IF <fs_it>-store_loc IS INITIAL AND <fs_it>-plant IS NOT INITIAL.
*         SELECT SINGLE lgort FROM mard INTO <fs_it>-store_loc
*           WHERE matnr = lv_matnr_pad AND werks = <fs_it>-plant.
        SELECT lgort FROM mard INTO <fs_it>-store_loc
          UP TO 1 ROWS
          WHERE matnr = lv_matnr_pad
            AND werks = <fs_it>-plant
          ORDER BY lgort ASCENDING. " Luôn lấy kho có mã nhỏ nhất (VD: 0001)
        ENDSELECT.
      ENDIF.

      " 5. Lấy Shipping Point (TVSTZ)
      IF <fs_it>-ship_point IS INITIAL AND <fs_it>-plant IS NOT INITIAL.
        DATA: lv_ladgr TYPE marc-ladgr,
              lv_vsbed TYPE tvstz-vsbed.
*        SELECT SINGLE vstel FROM tvstz INTO <fs_it>-ship_point
*          WHERE werks = <fs_it>-plant.

        IF <fs_it> IS ASSIGNED.

          " ------------------------------------------------------------------
          " 5. Lấy Shipping Point (Logic chuẩn: Plant + Loading Grp + Shipping Cond)
          " ------------------------------------------------------------------
          IF <fs_it>-ship_point IS INITIAL AND <fs_it>-plant IS NOT INITIAL.

            SELECT SINGLE ladgr
              INTO @lv_ladgr
              FROM marc
             WHERE matnr = @<fs_it>-material
               AND werks = @<fs_it>-plant.

            lv_vsbed = gs_so_heder_ui-so_hdr_vsbed.

            IF lv_ladgr IS NOT INITIAL AND lv_vsbed IS NOT INITIAL.
              SELECT SINGLE vstel
                INTO @<fs_it>-ship_point
                FROM tvstz
               WHERE werks = @<fs_it>-plant
                 AND ladgr = @lv_ladgr
                 AND vsbed = @lv_vsbed
                 AND lgort = @<fs_it>-store_loc.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      " 6. Default Schedule Date
      IF <fs_it>-req_date IS INITIAL.
        <fs_it>-req_date = ls_hd_ref-req_date.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " ==============================================================================
  " 3. CONDITION ENRICHMENT
  " ==============================================================================
  LOOP AT pt_pr ASSIGNING FIELD-SYMBOL(<fs_gen_pr>).

    " [QUAN TRỌNG]: Ép kiểu Condition
    ASSIGN <fs_gen_pr> TO <fs_pr> CASTING.

    IF <fs_pr>-item_no IS NOT INITIAL.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = <fs_pr>-item_no
        IMPORTING
          output = <fs_pr>-item_no.
    ENDIF.

    " Tìm Header (Lấy Currency)
    CLEAR ls_hd_ref.
    LOOP AT pt_hd ASSIGNING <fs_gen_hd>.
      ASSIGN <fs_gen_hd> TO <fs_hd> CASTING.
      IF <fs_hd>-temp_id = <fs_pr>-temp_id.
        ls_hd_ref = <fs_hd>. EXIT.
      ENDIF.
    ENDLOOP.

    " Tìm Item (Lấy UOM)
    DATA: ls_it_ref TYPE ztb_so_upload_it.
    CLEAR ls_it_ref.
    LOOP AT pt_it ASSIGNING <fs_gen_it>.
      ASSIGN <fs_gen_it> TO <fs_it> CASTING.
      IF <fs_it>-temp_id = <fs_pr>-temp_id AND <fs_it>-item_no = <fs_pr>-item_no.
        ls_it_ref = <fs_it>. EXIT.
      ENDIF.
    ENDLOOP.

    " Fill Currency
    IF <fs_pr>-currency IS INITIAL AND ls_hd_ref-currency IS NOT INITIAL.
      <fs_pr>-currency = ls_hd_ref-currency.
    ENDIF.

    " Fill UOM
    IF <fs_pr>-uom IS INITIAL AND ls_it_ref-unit IS NOT INITIAL.
      <fs_pr>-uom = ls_it_ref-unit.
    ENDIF.

    " Fill Per
    IF <fs_pr>-per IS INITIAL. <fs_pr>-per = 1. ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_template_structure
*&---------------------------------------------------------------------*
*& Description: Template Structure Validation When Upload File
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM validate_template_structure
  USING
    io_excel      TYPE REF TO cl_fdt_xl_spreadsheet
    iv_sheet      TYPE string
    iv_tabname    TYPE tabname
  CHANGING
    co_data_ref   TYPE REF TO data.

  FIELD-SYMBOLS: <fs_data_raw> TYPE STANDARD TABLE,
                 <fs_row_1>    TYPE any,
                 <lv_cell>     TYPE any.

  " --- 1. Định nghĩa Khuôn mẫu (Golden Template) ---
  TYPES: BEGIN OF ty_golden,
           col_idx  TYPE i,
           col_name TYPE string,
         END OF ty_golden.
  DATA: lt_golden TYPE TABLE OF ty_golden.

  IF iv_tabname = 'ZTB_SO_UPLOAD_HD'.
    lt_golden = VALUE #(
      ( col_idx = 1  col_name = '*TEMP ID' )
      ( col_idx = 2  col_name = '*SALES ORDER TYPE' )
      ( col_idx = 3  col_name = '*SALES ORG.' )
      ( col_idx = 4  col_name = '*DIST. CHNL' )
      ( col_idx = 5  col_name = '*DIVISION' )
      ( col_idx = 6  col_name = 'SALES OFFICE' )
      ( col_idx = 7  col_name = 'SALES GROUP' )
      ( col_idx = 8  col_name = '*SOLD-TO PARTY' )
      ( col_idx = 9  col_name = '*CUST. REF.' )
      ( col_idx = 10 col_name = 'REQUESTED DELIVERY DATE' )
      ( col_idx = 11 col_name = '*PAYT. TERM' )
      ( col_idx = 12 col_name = 'INCOTERM' )
      ( col_idx = 13 col_name = 'INCOTERM-LOCATION' )
    ).
  ELSEIF iv_tabname = 'ZTB_SO_UPLOAD_IT'.
    lt_golden = VALUE #(
      ( col_idx = 1  col_name = '*TEMP ID' )
      ( col_idx = 2  col_name = '*ITEM NO' )
      ( col_idx = 3  col_name = '*MATERIAL' )
      ( col_idx = 4  col_name = 'PLANT' )
      ( col_idx = 5  col_name = 'SHIPPING POINT' )
      ( col_idx = 6  col_name = 'STORAGE LOC.' )
      ( col_idx = 7  col_name = '*ORDER QUANTITY' )
    ).
  ELSEIF iv_tabname = 'ZTB_SO_UPLOAD_PR'.
    lt_golden = VALUE #(
      ( col_idx = 1  col_name = '*TEMP ID' )
      ( col_idx = 2  col_name = '*ITEM NO' )
      ( col_idx = 3  col_name = 'COND. TYPE' )
      ( col_idx = 4  col_name = 'AMOUNT' )
      ( col_idx = 5  col_name = 'CURRENCY' )
      ( col_idx = 6  col_name = 'PER' )
      ( col_idx = 7  col_name = 'UOM' )
    ).
  ENDIF.

  " --- 2. Lấy dữ liệu thô từ Excel ---
  TRY.
      " Call a method of the standard class to retrieve all data in Sheet iv_sheet"
      co_data_ref = io_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet( iv_sheet ).

      " Point the Field Symbol to the memory location containing the data just retrieved.
      ASSIGN co_data_ref->* TO <fs_data_raw>.

    CATCH cx_fdt_excel.
      MESSAGE |Sheet '{ iv_sheet }' not found in template.| TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref.
      RETURN.
  ENDTRY.

  " --- 3. Đọc dòng tiêu đề (Row 1) ---
  READ TABLE <fs_data_raw> ASSIGNING <fs_row_1> INDEX 1.
  IF sy-subrc <> 0.
    " If the Sheet name is not found (e.g., User changed the name 'Header' to 'Sheet1') -> Report an error"
    MESSAGE |Sheet '{ iv_sheet }' is empty.| TYPE 'S' DISPLAY LIKE 'E'.
    CLEAR co_data_ref. RETURN.
  ENDIF.

  " --- 4. So sánh với Khuôn mẫu ---
  LOOP AT lt_golden INTO DATA(ls_golden).
    " Get the value of the cell at the corresponding column position in the Excel file"
    " Example: ls_golden-col_idx = 1 -> Get the first cell of the header row"
    ASSIGN COMPONENT ls_golden-col_idx OF STRUCTURE <fs_row_1> TO <lv_cell>.

    " If the Excel file doesn't have this column (e.g., the file only has 5 columns but we need a 6th column)"
    IF <lv_cell> IS NOT ASSIGNED.
      MESSAGE |Invalid Template: Column { ls_golden-col_idx } missing in sheet { iv_sheet }.| TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref. RETURN.
    ENDIF.

    " Extract the text content from the Excel cell, capitalize it, and remove extra spaces."
    DATA(lv_user_col) = |{ <lv_cell> }|.
    CONDENSE lv_user_col.
    TRANSLATE lv_user_col TO UPPER CASE.

    " COMPARISON: Does the column name 'User Upload' match the standard column name?
    " Example: User entered 'Material No' but the standard is '*MATERIAL' -> Error
    IF lv_user_col <> ls_golden-col_name.
      MESSAGE |Template Error ({ iv_sheet }): Column { ls_golden-col_idx } should be '{ ls_golden-col_name }' but found '{ lv_user_col }'.|
        TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref. RETURN.
    ENDIF.
  ENDLOOP.

  " --- 5. Xóa dòng tiêu đề ---
  DELETE <fs_data_raw> INDEX 1.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form perform_mass_upload
*&---------------------------------------------------------------------*
*& Description: Mass Upload Execution (Upload File, Read File, Extract Data, Validate Data, Load Data to ALV)
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM perform_mass_upload
  USING
    iv_mode   TYPE c
    iv_req_id TYPE zsd_req_id.

  DATA: lv_file_path TYPE string,
        lv_rc        TYPE i,
        lt_filetab   TYPE filetable.

  DATA: lv_log_reqid    TYPE zso_log_213-req_id,
        lv_filename_log TYPE zso_log_213-filename.

  " 1. Tạo ID Log (Log hệ thống, không phải REQ_ID dữ liệu)
  lv_log_reqid = |UPL{ sy-uname+0(3) }{ sy-datum+2(6) }{ sy-uzeit(6) }|.
  REPLACE ALL OCCURRENCES OF '-' IN lv_log_reqid WITH ''.

  " 2. Mở File Dialog
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = 'Select Mass Upload File'
      default_extension       = 'xlsx'
      file_filter             = 'Excel Files (*.xlsx)|*.xlsx'
    CHANGING
      file_table              = lt_filetab
      rc                      = lv_rc
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5.

  IF sy-subrc <> 0.
    CASE sy-subrc.
      WHEN 1. MESSAGE 'File Open Dialog Failed.' TYPE 'S' DISPLAY LIKE 'E'.
      WHEN 2. MESSAGE 'Control Error (GUI).'     TYPE 'S' DISPLAY LIKE 'E'.
      WHEN 3. MESSAGE 'Error: No GUI available.' TYPE 'S' DISPLAY LIKE 'E'.
      WHEN 4. MESSAGE 'Not supported by GUI.'    TYPE 'S' DISPLAY LIKE 'E'.
      WHEN OTHERS. MESSAGE 'Unknown error opening file.' TYPE 'S' DISPLAY LIKE 'E'.
    ENDCASE.
    RETURN.
  ENDIF.

  IF lv_rc <= 0 OR lines( lt_filetab ) = 0.
    MESSAGE 'File selection cancelled. Data remains unchanged.' TYPE 'S'.
    RETURN.
  ENDIF.

  READ TABLE lt_filetab INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_file>).
  lv_file_path = <fs_file>-filename.
  lv_filename_log = lv_file_path.

  " 3. Khai báo bảng tạm
  DATA: lt_header_raw TYPE STANDARD TABLE OF ztb_so_upload_hd,
        lt_item_raw   TYPE STANDARD TABLE OF ztb_so_upload_it,
        lt_cond_raw   TYPE STANDARD TABLE OF ztb_so_upload_pr.

  " --- 4. Đọc File Excel ---
  PERFORM upload_file
    USING    lv_file_path
             iv_req_id
    CHANGING lt_header_raw
             lt_item_raw
             lt_cond_raw.

  PERFORM exec_enrich_raw_data
   CHANGING
     lt_header_raw
     lt_item_raw
     lt_cond_raw.

  " --- 5. Lưu vào Z-Table (Staging) ---
  PERFORM save_raw_to_staging
    USING
      iv_mode
      iv_req_id
      lt_header_raw
      lt_item_raw
      lt_cond_raw.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  LOAD_DATA_FOR_TREE_UI
*&---------------------------------------------------------------------*
* Đọc dữ liệu từ Staging Table lên bảng nội bộ GT_MU_... để vẽ cây
*----------------------------------------------------------------------*
FORM load_data_for_tree_ui USING iv_req_id TYPE zsd_req_id.

  " 1. Clear dữ liệu cũ
  CLEAR: gt_mu_header, gt_mu_item, gt_mu_cond.

  " 2. Select Header (Dùng CORRESPONDING vì GT_MU_HEADER có thêm field UI)
  SELECT * FROM ztb_so_upload_hd
    INTO CORRESPONDING FIELDS OF TABLE gt_mu_header
    WHERE req_id = iv_req_id.

  " 3. Select Item
  SELECT * FROM ztb_so_upload_it
    INTO CORRESPONDING FIELDS OF TABLE gt_mu_item
    WHERE req_id = iv_req_id.

  " 4. Select Condition
  SELECT * FROM ztb_so_upload_pr
    INTO CORRESPONDING FIELDS OF TABLE gt_mu_cond
    WHERE req_id = iv_req_id.

  " 5. Sắp xếp dữ liệu (Quan trọng để vẽ cây đúng thứ tự)
  SORT gt_mu_header BY temp_id.
  SORT gt_mu_item   BY temp_id item_no.
  SORT gt_mu_cond   BY temp_id item_no cond_type.

  " 6. (Optional) Set trạng thái mặc định
  " Ví dụ: Set đèn Xám (hoặc Vàng) cho tất cả dòng vì chưa validate
  LOOP AT gt_mu_header ASSIGNING FIELD-SYMBOL(<fs_head>).
    <fs_head>-icon = icon_led_inactive. " Hoặc icon_yellow_light
    <fs_head>-message  = 'Ready to validate'.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form save_raw_to_staging
*&---------------------------------------------------------------------*
*& Description: Save Excel Data to Staging Tables
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM save_raw_to_staging
  USING
    iv_mode       TYPE c
    iv_req_id_new TYPE zsd_req_id
    it_header_raw TYPE STANDARD TABLE
    it_item_raw   TYPE STANDARD TABLE
    it_cond_raw   TYPE STANDARD TABLE.

  DATA: ls_header_db TYPE ztb_so_upload_hd,
        lt_header_db TYPE TABLE OF ztb_so_upload_hd,
        ls_item_db   TYPE ztb_so_upload_it,
        lt_item_db   TYPE TABLE OF ztb_so_upload_it,
        ls_cond      TYPE ztb_so_upload_pr,
        lt_cond_db   TYPE TABLE OF ztb_so_upload_pr.

  DATA: lr_req_id    TYPE RANGE OF zsd_req_id,
        ls_req_range LIKE LINE OF lr_req_id.

  " --- 1. Xử lý Header & Item (Giữ nguyên logic cũ của bạn) ---
  LOOP AT it_header_raw ASSIGNING FIELD-SYMBOL(<fs_h>).
    MOVE-CORRESPONDING <fs_h> TO ls_header_db.
    IF iv_mode = 'NEW'. ls_header_db-req_id = iv_req_id_new. ENDIF.
    ls_header_db-status = 'NEW'.
    ls_header_db-created_by = sy-uname.
    ls_header_db-created_on = sy-datum.
    APPEND ls_header_db TO lt_header_db.

    " Collect REQ_ID để xóa cũ nếu cần
    ls_req_range-sign = 'I'. ls_req_range-option = 'EQ'. ls_req_range-low = ls_header_db-req_id.
    COLLECT ls_req_range INTO lr_req_id.
  ENDLOOP.

  LOOP AT it_item_raw ASSIGNING FIELD-SYMBOL(<fs_i>).
    MOVE-CORRESPONDING <fs_i> TO ls_item_db.
    IF iv_mode = 'NEW'. ls_item_db-req_id = iv_req_id_new. ENDIF.
    ls_item_db-status = 'NEW'.
    ls_item_db-created_by = sy-uname.
    ls_item_db-created_on = sy-datum.
    APPEND ls_item_db TO lt_item_db.
  ENDLOOP.

  " --- 2. Xử lý Condition (SỬA LỖI COUNTER TẠI ĐÂY) ---
  LOOP AT it_cond_raw ASSIGNING FIELD-SYMBOL(<fs_c>).
    MOVE-CORRESPONDING <fs_c> TO ls_cond.

    IF iv_mode = 'NEW'.
      ls_cond-req_id = iv_req_id_new.
    ENDIF.

    " Tự động đánh số Counter theo thứ tự vòng lặp
    " Đảm bảo mỗi dòng có 1 số duy nhất (1, 2, 3...) -> Không bao giờ trùng khóa
    " The system variable contains the current loop index.
    ls_cond-counter    = sy-tabix.

    ls_cond-status     = 'NEW'.
    ls_cond-created_by = sy-uname.
    ls_cond-created_on = sy-datum.
    APPEND ls_cond TO lt_cond_db.
  ENDLOOP.

  " --- 3. Xóa dữ liệu cũ (Nếu Resubmit) ---
  IF iv_mode = 'RESUBMIT' AND lr_req_id IS NOT INITIAL.
    DELETE FROM ztb_so_upload_hd WHERE req_id IN lr_req_id.
    DELETE FROM ztb_so_upload_it WHERE req_id IN lr_req_id.
    DELETE FROM ztb_so_upload_pr WHERE req_id IN lr_req_id.
  ENDIF.

  " --- 4. Lưu xuống DB
  IF lt_header_db IS NOT INITIAL. MODIFY ztb_so_upload_hd FROM TABLE lt_header_db. ENDIF.
  IF lt_item_db   IS NOT INITIAL. MODIFY ztb_so_upload_it FROM TABLE lt_item_db.   ENDIF.

  " [FIX QUAN TRỌNG]: Dùng MODIFY thay vì INSERT
  IF lt_cond_db   IS NOT INITIAL.
    MODIFY ztb_so_upload_pr FROM TABLE lt_cond_db.
  ENDIF.

  COMMIT WORK.
  MESSAGE 'Data saved to Staging successfully.' TYPE 'S'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_staging_data
*&---------------------------------------------------------------------*
*& Description: Validate Data From Staging Tables Filter By Currenct RequestID
*&              Initializes Containers, Splitters, HTML KPI, and ALV Grid.
*&---------------------------------------------------------------------*
FORM validate_staging_data USING iv_req_id TYPE zsd_req_id.

  DATA: lt_header TYPE TABLE OF ztb_so_upload_hd,
        lt_item   TYPE TABLE OF ztb_so_upload_it,
        lt_cond   TYPE TABLE OF ztb_so_upload_pr.

  DATA: lt_errors_total TYPE ztty_validation_error.
  DATA: lr_temp_id_reval TYPE RANGE OF char10.

  " --- 1. Đọc dữ liệu từ Staging ---
  " Chỉ lấy các trường cần thiết để Validate Header
  SELECT req_id, temp_id, status, message,      " Các trường quản lý
         order_type, sales_org, sales_channel, sales_div, " Sales Area
         sales_off, sales_grp,                  " Sales Group
         sold_to_party, cust_ref,               " Partner
         req_date, price_date, order_date,      " Date
         pmnttrms, incoterms, inco2,            " Payment & Inco
         currency, ship_cond                    " Others
    FROM ztb_so_upload_hd
    INTO CORRESPONDING FIELDS OF TABLE @lt_header
    WHERE req_id = @iv_req_id.

  IF sy-subrc <> 0. EXIT. ENDIF.

  " Chỉ lấy các cột cần thiết để Validate
  SELECT req_id, temp_id, item_no,
         material, plant, quantity, unit, store_loc, ship_point, " <--- Các field cần validate
         status, message
    FROM ztb_so_upload_it
    INTO CORRESPONDING FIELDS OF TABLE @lt_item " (Lưu ý: lt_item nên được khai báo khớp với danh sách này hoặc dùng CORRESPONDING)
    WHERE req_id = @iv_req_id.
  SELECT * FROM ztb_so_upload_pr INTO TABLE lt_cond WHERE req_id = iv_req_id.

  " --- 2. Thiết lập Class Validator ---
  CALL METHOD zcl_sd_mass_validator=>set_context( iv_req_id ).
  CALL METHOD zcl_sd_mass_validator=>clear_errors.

  " ====================================================================
  " [FIX QUAN TRỌNG]: DỌN DẸP LOG CŨ CỦA CÁC DÒNG SẮP RE-VALIDATE
  " ====================================================================
  " Chỉ xóa log của những dòng KHÔNG PHẢI LÀ SUCCESS (vì Success không validate lại)
  LOOP AT lt_header INTO DATA(ls_hd_chk) WHERE status <> 'SUCCESS'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_hd_chk-temp_id ) TO lr_temp_id_reval.
  ENDLOOP.

  IF lr_temp_id_reval IS NOT INITIAL.
    " Xóa sạch lỗi cũ trong DB để tránh tô màu 'bóng ma'
    DELETE FROM ztb_so_error_log
      WHERE req_id = iv_req_id
        AND temp_id IN lr_temp_id_reval.
    COMMIT WORK. " Commit việc xóa ngay
  ENDIF.

  " ====================================================================
  " A. VALIDATE HEADER
  " ====================================================================
  LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<fs_header>).
    " Bỏ qua dòng đã thành công
    IF <fs_header>-status = 'SUCCESS'. CONTINUE. ENDIF.

    CALL METHOD zcl_sd_mass_validator=>execute_validation_hdr
      CHANGING
        cs_header = <fs_header>.

    UPDATE ztb_so_upload_hd FROM <fs_header>.
  ENDLOOP.

  " ====================================================================
  " B. VALIDATE ITEM
  " ====================================================================
  LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).
    " Tìm Header cha để check status
    READ TABLE lt_header ASSIGNING FIELD-SYMBOL(<fs_header_parent>)
      WITH KEY temp_id = <fs_item>-temp_id.

    " Nếu Header cha đã Success -> Bỏ qua Item con
    IF sy-subrc = 0 AND <fs_header_parent>-status = 'SUCCESS'.
      CONTINUE.
    ENDIF.

    IF sy-subrc <> 0.
      " Mất Header -> Lỗi
      <fs_item>-status  = 'ERROR'.
      <fs_item>-message = 'Parent Header missing.'.
      CALL METHOD zcl_sd_mass_validator=>add_error
        EXPORTING
          iv_temp_id   = <fs_item>-temp_id
          iv_item_no   = <fs_item>-item_no
          iv_fieldname = 'TEMP_ID'
          iv_msg_type  = 'E'
          iv_message   = 'Parent Header missing.'.
      UPDATE ztb_so_upload_it FROM <fs_item>.
      CONTINUE.
    ENDIF.

    " Gọi Validate Item
    CALL METHOD zcl_sd_mass_validator=>execute_validation_itm
      EXPORTING
        is_header = <fs_header_parent>
      CHANGING
        cs_item   = <fs_item>.

    UPDATE ztb_so_upload_it FROM <fs_item>.
  ENDLOOP.

  " 1. Tạo bảng phụ để đếm số lần xuất hiện
  DATA: lt_cond_check TYPE TABLE OF ztb_so_upload_pr.
  lt_cond_check = lt_cond.
  SORT lt_cond_check BY temp_id item_no cond_type. " Sắp xếp để đếm

  LOOP AT lt_cond ASSIGNING FIELD-SYMBOL(<fs_cond>).

    " Check Header cha (như cũ)
    READ TABLE lt_header ASSIGNING <fs_header_parent> WITH KEY temp_id = <fs_cond>-temp_id.
    IF sy-subrc = 0 AND <fs_header_parent>-status = 'SUCCESS'. CONTINUE. ENDIF.

    " --- [LOGIC MỚI]: CHECK DUPLICATE ---
    DATA(lv_count) = 0.

    " Đếm xem có bao nhiêu dòng cùng ID, Item và Cond Type này
    LOOP AT lt_cond_check TRANSPORTING NO FIELDS
         WHERE temp_id   = <fs_cond>-temp_id
           AND item_no   = <fs_cond>-item_no
           AND cond_type = <fs_cond>-cond_type.
      lv_count = lv_count + 1.
    ENDLOOP.

    " Nếu xuất hiện nhiều hơn 1 lần -> LỖI CẢ ĐÁM
    IF lv_count > 1.
      <fs_cond>-status  = 'ERROR'.
      <fs_cond>-message = |Duplicate Condition Type { <fs_cond>-cond_type }|.

      " Ghi log lỗi
      CALL METHOD zcl_sd_mass_validator=>add_error
        EXPORTING
          iv_temp_id   = <fs_cond>-temp_id
          iv_item_no   = <fs_cond>-item_no
          iv_fieldname = 'COND_TYPE'
          iv_msg_type  = 'E'
          iv_message   = 'Duplicate Condition Type found.'.

      " Cập nhật DB và bỏ qua validate chi tiết (vì đã sai rồi)
      UPDATE ztb_so_upload_pr FROM <fs_cond>.
      CONTINUE.
    ENDIF.

    " --- Validate chi tiết (Nếu không trùng) ---
    CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
      CHANGING
        cs_pricing = <fs_cond>.

    UPDATE ztb_so_upload_pr FROM <fs_cond>.
  ENDLOOP.

  " ====================================================================
  " D. LƯU LOG & COMMIT
  " ====================================================================
  lt_errors_total = zcl_sd_mass_validator=>get_errors( ).

  " Lưu các lỗi MỚI (nếu có) vào DB
  CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
    EXPORTING
      it_errors = lt_errors_total.

  COMMIT WORK.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form load_data_from_staging
*&---------------------------------------------------------------------*
*& Description: Load Data From Staging Tables
*&---------------------------------------------------------------------*
FORM load_data_from_staging USING iv_req_id TYPE zsd_req_id.

  " 1. Refresh
  REFRESH: gt_hd_val, gt_it_val, gt_pr_val,
           gt_hd_suc, gt_it_suc, gt_pr_suc,
           gt_hd_fail, gt_it_fail, gt_pr_fail.

  " 2. Read DB
  SELECT * FROM ztb_so_upload_hd INTO TABLE @DATA(lt_hd) WHERE req_id = @iv_req_id.
  IF lt_hd IS INITIAL. RETURN. ENDIF.

  " Chỉ lấy các trường cần thiết cho ALV Item
  SELECT req_id, temp_id, item_no, material, short_text,
         plant, ship_point, store_loc, quantity, unit,
         schedule_date, price_proc, status, message
    FROM ztb_so_upload_it
    INTO TABLE @DATA(lt_it)
    WHERE req_id = @iv_req_id.

  " Chỉ Select các cột cần thiết cho ALV và xử lý logic
  SELECT req_id, temp_id, item_no, cond_type, amount, currency, per, uom, status, message
    FROM ztb_so_upload_pr
    INTO TABLE @DATA(lt_pr)
    WHERE req_id = @iv_req_id.

  " Biến tạm
  DATA: ls_hd_alv TYPE ty_header,
        ls_it_alv TYPE ty_item,
        ls_pr_alv TYPE ty_condition.

  " 3. Phân loại
  LOOP AT lt_hd INTO DATA(ls_hd_db).
    CLEAR ls_hd_alv.
    MOVE-CORRESPONDING ls_hd_db TO ls_hd_alv.

    CASE ls_hd_db-status.

        " === TAB 1: VALIDATED ===
      WHEN 'NEW' OR 'READY' OR 'INCOMP' OR 'ERROR'.

        " Icon & Err Btn cho Header
        IF ls_hd_db-status = 'ERROR'.
          ls_hd_alv-icon    = icon_led_red.
          ls_hd_alv-err_btn = icon_protocol. " [SỬA]: Dùng ls_hd_alv
        ELSEIF ls_hd_db-status = 'INCOMP'.
          ls_hd_alv-icon    = icon_led_yellow.
          ls_hd_alv-err_btn = icon_protocol. " [SỬA]
        ELSE.
          ls_hd_alv-icon    = icon_led_green.
          ls_hd_alv-err_btn = ' '.
        ENDIF.

        APPEND ls_hd_alv TO gt_hd_val.

        " --- Item ---
        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
          CLEAR ls_it_alv.
          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.

          " Icon & Err Btn cho Item
          IF ls_it_db-status = 'ERROR'.
            ls_it_alv-icon    = icon_led_red.
            ls_it_alv-err_btn = icon_protocol. " [MỚI]: Gán cho Item
          ELSEIF ls_it_db-status = 'INCOMP' OR ls_it_db-status = 'W'.
            ls_it_alv-icon    = icon_led_yellow.
            ls_it_alv-err_btn = icon_protocol. " [MỚI]
          ELSE.
            ls_it_alv-icon    = icon_led_green.
            ls_it_alv-err_btn = ' '.
          ENDIF.

          APPEND ls_it_alv TO gt_it_val.
        ENDLOOP.

        " --- Condition ---
        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
          CLEAR ls_pr_alv.
          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.

          " Icon & Err Btn cho Condition
          IF ls_pr_db-status = 'ERROR'.
            ls_pr_alv-icon    = icon_led_red.
            ls_pr_alv-err_btn = icon_protocol. " [MỚI]
          ELSEIF ls_pr_db-status = 'INCOMP'.
            ls_pr_alv-icon    = icon_led_yellow.
            ls_pr_alv-err_btn = icon_protocol. " [MỚI]
          ELSE.
            ls_pr_alv-icon    = icon_led_green.
            ls_pr_alv-err_btn = ' '.
          ENDIF.

          APPEND ls_pr_alv TO gt_pr_val.
        ENDLOOP.

        " === TAB 2: POSTED SUCCESS ===
      WHEN 'SUCCESS' OR 'POSTED'.
        " Chỉ cần append vào bảng, không cần lo màu sắc ở đây nữa
        APPEND ls_hd_alv TO gt_hd_suc.

        " Lấy Item/Cond (Giữ nguyên logic lấy con)
        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
          APPEND ls_it_alv TO gt_it_suc.
        ENDLOOP.
        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
          APPEND ls_pr_alv TO gt_pr_suc.
        ENDLOOP.

        " === TAB 3: FAILED ===
      WHEN 'FAILED'.
        ls_hd_alv-icon    = icon_led_red.
        ls_hd_alv-err_btn = icon_protocol. " [SỬA]
        APPEND ls_hd_alv TO gt_hd_fail.

        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
          ls_it_alv-icon    = icon_led_red.
          ls_it_alv-err_btn = icon_protocol. " [SỬA]: Nên hiện lỗi nếu có
          APPEND ls_it_alv TO gt_it_fail.
        ENDLOOP.
        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
          ls_pr_alv-icon    = icon_led_red.
          ls_pr_alv-err_btn = icon_protocol. " [SỬA]
          APPEND ls_pr_alv TO gt_pr_fail.
        ENDLOOP.

    ENDCASE.
  ENDLOOP.

  PERFORM highlight_error_cells.
  PERFORM highlight_success_cells.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form highlight_success_cells
*&---------------------------------------------------------------------*
*& Description: Highlight cells for SO Number and Delivery Number that is created successfully and returned
*&---------------------------------------------------------------------*
FORM highlight_success_cells.

  DATA: ls_color       TYPE lvc_s_scol,
        lv_has_warning TYPE abap_bool.

  " Macro thêm màu
  DEFINE _add_color.
    CLEAR ls_color.
    ls_color-fname     = &1.
    ls_color-color-col = &2. " 3=Vàng, 5=Xanh
    ls_color-color-int = 1.
    INSERT ls_color INTO TABLE &3-celltab.
  END-OF-DEFINITION.

  " Duyệt qua bảng Header Success
  LOOP AT gt_hd_suc ASSIGNING FIELD-SYMBOL(<fs_hd>).

    REFRESH <fs_hd>-celltab.
    CLEAR lv_has_warning.

    " 1. Kiểm tra xem có Log Warning (Incomplete) trong DB không?
    SELECT SINGLE @abap_true
      INTO @lv_has_warning
      FROM ztb_so_error_log
      WHERE req_id   = @<fs_hd>-req_id
        AND temp_id  = @<fs_hd>-temp_id
        AND msg_type = 'W'. " W = Warning (Incomplete)

    " 2. Quyết định màu sắc
    IF lv_has_warning = abap_true.
      " === TRƯỜNG HỢP: INCOMPLETE (VÀNG) ===
      <fs_hd>-icon = icon_led_yellow.

      " Tô Vàng ô Sales Order (Cảnh báo)
      _add_color 'VBELN_SO' 3 <fs_hd>.

      " Hiện nút Log để user xem chi tiết thiếu gì
      <fs_hd>-err_btn = icon_protocol.

    ELSE.
      " === TRƯỜNG HỢP: COMPLETE (XANH) ===
      <fs_hd>-icon = icon_led_green.

      " Tô Xanh ô Sales Order
      _add_color 'VBELN_SO' 5 <fs_hd>.

      " Nếu có Delivery thì tô xanh luôn Delivery cho đẹp (không bắt buộc)
      IF <fs_hd>-vbeln_dlv IS NOT INITIAL.
        _add_color 'VBELN_DLV' 5 <fs_hd>.
      ENDIF.

      " Ẩn nút Log
      <fs_hd>-err_btn = ' '.
    ENDIF.

    " Đồng bộ Icon cho Item/Cond con
    LOOP AT gt_it_suc ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE temp_id = <fs_hd>-temp_id.
      <fs_it>-icon = <fs_hd>-icon.
    ENDLOOP.

    LOOP AT gt_pr_suc ASSIGNING FIELD-SYMBOL(<fs_pr>) WHERE temp_id = <fs_hd>-temp_id.
      <fs_pr>-icon = <fs_hd>-icon.
    ENDLOOP.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_STATUS_COUNTS_TREE
*&      Description: Count Status Of Data on Tree
*&---------------------------------------------------------------------*
*FORM update_status_counts_tree.
*  CLEAR: gv_cnt_total, gv_cnt_ready, gv_cnt_valid,
*         gv_cnt_error, gv_cnt_posted, gv_cnt_failed.
*
*  gv_cnt_total = lines( gt_mu_header ).
*
*  LOOP AT gt_mu_header INTO DATA(ls_head).
*
*    " Logic phân loại dựa trên trạng thái (Bạn điều chỉnh field check cho đúng logic dự án)
*    " Ví dụ: Check field STATUS hoặc ICON
*
*    IF ls_head-vbeln_so IS NOT INITIAL.
*      " 1. Đã có số SO -> Success
*      ADD 1 TO gv_cnt_posted.
*
*    ELSEIF ls_head-message CS 'Error' OR ls_head-icon = icon_led_red.
*      " 2. Có thông báo lỗi hoặc đèn đỏ -> Error
*      " (Phân biệt lỗi Validation hay lỗi Post dựa vào ngữ cảnh nếu cần)
*      ADD 1 TO gv_cnt_error.
*
*    ELSEIF ls_head-message CS 'Success' OR ls_head-icon = icon_led_green.
*      " 3. Đèn xanh nhưng chưa có SO -> Validated OK
*      ADD 1 TO gv_cnt_valid.
*
*    ELSE.
*      " 4. Còn lại -> Mới Upload (Ready)
*      ADD 1 TO gv_cnt_ready.
*    ENDIF.
*
*  ENDLOOP.
*ENDFORM.
FORM update_status_counts_tree.
  CLEAR: gv_cnt_total, gv_cnt_ready, gv_cnt_valid,
         gv_cnt_error, gv_cnt_posted, gv_cnt_failed.

  DATA: lv_has_error TYPE abap_bool.

  gv_cnt_total = lines( gt_mu_header ).

  LOOP AT gt_mu_header INTO DATA(ls_head).
    lv_has_error = abap_false.

    " ====================================================================
    " 1. CHECK STATUS: ĐÃ POST THÀNH CÔNG?
    " ====================================================================
    IF ls_head-vbeln_so IS NOT INITIAL.
      ADD 1 TO gv_cnt_posted.
      CONTINUE. " Đã post rồi thì không tính là lỗi nữa
    ENDIF.

    " ====================================================================
    " 2. CHECK STATUS: TÌM LỖI (QUÉT SÂU - DEEP SCAN)
    " ====================================================================

    " A. Kiểm tra bản thân Header
    IF ls_head-status = 'ERROR' OR ls_head-status = 'E' OR ls_head-icon = icon_led_red.
      lv_has_error = abap_true.
    ENDIF.

    " B. Kiểm tra Items con (Nếu Header chưa thấy lỗi)
    IF lv_has_error = abap_false.
      LOOP AT gt_mu_item TRANSPORTING NO FIELDS
           WHERE temp_id = ls_head-temp_id
             AND ( status = 'ERROR' OR status = 'E' OR icon = icon_led_red ).
        lv_has_error = abap_true.
        EXIT. " Thấy 1 item lỗi là đủ kết luận Header này lỗi
      ENDLOOP.
    ENDIF.

    " C. Kiểm tra Conditions cháu (Nếu Header & Item chưa thấy lỗi)
    " [QUAN TRỌNG] Đây là phần bạn đang thiếu
    IF lv_has_error = abap_false.
      LOOP AT gt_mu_cond TRANSPORTING NO FIELDS
           WHERE temp_id = ls_head-temp_id
             AND ( status = 'ERROR' OR status = 'E' OR icon = icon_led_red ).
        lv_has_error = abap_true.
        EXIT. " Thấy 1 condition lỗi là đủ kết luận Header này lỗi
      ENDLOOP.
    ENDIF.

    " ====================================================================
    " 3. CỘNG DỒN VÀO BIẾN ĐẾM
    " ====================================================================
    IF lv_has_error = abap_true.
      " -> Có lỗi ở bất kỳ cấp độ nào (Header/Item/Condition)
      ADD 1 TO gv_cnt_error.

    ELSEIF ls_head-status = 'SUCCESS' OR ls_head-icon = icon_led_green.
      " -> Không lỗi & đã Validate OK
      ADD 1 TO gv_cnt_valid.

    ELSE.
      " -> Mới Upload (Ready) hoặc Incomplete
      ADD 1 TO gv_cnt_ready.
    ENDIF.

  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_HTML_SUMMARY_TREE
*&      Description: Display HTML Validation Summary
*&---------------------------------------------------------------------*
FORM build_html_summary_tree.
  DATA: lv_html TYPE string,
        lt_html TYPE STANDARD TABLE OF w3html,
        ls_html TYPE w3html,
        lv_url  TYPE char1024.

  " Convert số sang text
  DATA: txt_tot TYPE c LENGTH 10, txt_rdy TYPE c LENGTH 10,
        txt_ok  TYPE c LENGTH 10, txt_err TYPE c LENGTH 10,
        txt_suc TYPE c LENGTH 10.

  WRITE gv_cnt_total  TO txt_tot. CONDENSE txt_tot NO-GAPS.
  WRITE gv_cnt_ready  TO txt_rdy. CONDENSE txt_rdy NO-GAPS.
  WRITE gv_cnt_valid  TO txt_ok.  CONDENSE txt_ok  NO-GAPS.
  WRITE gv_cnt_error  TO txt_err. CONDENSE txt_err NO-GAPS.
  WRITE gv_cnt_posted TO txt_suc. CONDENSE txt_suc NO-GAPS.

  " --- BẮT ĐẦU VẼ HTML ---
  lv_html =
    '<html><head><style>' &&
    'body { font-family: Segoe UI, sans-serif; margin: 0; padding: 5px; background: #f2f2f2; overflow: hidden; }' &&

    " [FIX 1] Thêm width: 100% để container luôn chiếm hết màn hình
    '.container { display: flex; gap: 15px; align-items: center; height: 100%; width: 100%; box-sizing: border-box; }' &&

    " [FIX 2] Thêm flex: 1 để các card tự động chia đều khoảng trắng dư thừa
    '.card { flex: 1; background: white; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); ' &&
    '        min-width: 100px; padding: 10px; display: flex; flex-direction: column; border-left: 5px solid #ccc; }' &&

    '.c-total { border-color: #666; }' &&
    '.c-ready { border-color: #0078d4; }' &&
    '.c-ok    { border-color: #ffb900; }' &&
    '.c-err   { border-color: #d13438; }' &&
    '.c-suc   { border-color: #107c10; }' &&

    '.lbl { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }' &&
    '.val { font-size: 20px; font-weight: bold; color: #333; margin-top: 2px; }' &&
    '</style></head><body>' &&

    '<div class="container">'.

  " Card 1: TOTAL
  CONCATENATE lv_html
    '<div class="card c-total"><span class="lbl">Total Rows</span><span class="val">' txt_tot '</span></div>'
  INTO lv_html.

  " Card 2: READY
  CONCATENATE lv_html
    '<div class="card c-ready"><span class="lbl">Ready</span><span class="val">' txt_rdy '</span></div>'
  INTO lv_html.

  " Card 3: VALIDATED
  CONCATENATE lv_html
    '<div class="card c-ok"><span class="lbl">Validated OK</span><span class="val">' txt_ok '</span></div>'
  INTO lv_html.

  " Card 4: ERROR
  CONCATENATE lv_html
    '<div class="card c-err"><span class="lbl">Errors</span><span class="val">' txt_err '</span></div>'
  INTO lv_html.

  " Card 5: POSTED
  CONCATENATE lv_html
    '<div class="card c-suc"><span class="lbl">Posted SO</span><span class="val">' txt_suc '</span></div>'
  INTO lv_html.

  CONCATENATE lv_html '</div></body></html>' INTO lv_html.

  " --- Load vào HTML Viewer ---
  CLEAR lt_html.
  DATA: lv_len   TYPE i, lv_off TYPE i, lv_chunk TYPE i.
  lv_len = strlen( lv_html ).
  lv_off = 0.
  WHILE lv_off < lv_len.
    lv_chunk = lv_len - lv_off.
    IF lv_chunk > 255. lv_chunk = 255. ENDIF.
    ls_html-line = lv_html+lv_off(lv_chunk).
    APPEND ls_html TO lt_html.
    lv_off = lv_off + lv_chunk.
  ENDWHILE.

  go_mu_html_top->load_data( EXPORTING type = 'text/html' IMPORTING assigned_url = lv_url CHANGING data_table = lt_html ).
  go_mu_html_top->show_url( lv_url ).

ENDFORM.

FORM build_tree_from_data.
  DATA: lt_nodes TYPE TABLE OF mtreesnode,  " Table containing tree structure"
        ls_node  TYPE mtreesnode.   " Single row node structure"

  " 1. Sắp xếp dữ liệu để đảm bảo Node Cha được vẽ trước Node Con
  SORT gt_mu_header BY temp_id.         " Sắp xếp theo Temp ID
  SORT gt_mu_item   BY temp_id item_no. " Sắp xếp theo Temp ID + Item No

  " 2. Loop qua danh sách Header
  LOOP AT gt_mu_header INTO DATA(ls_head).
    CLEAR ls_node.

    " --- TẠO NODE CHA (HEADER) ---
    " Key = 'H' + TempID (Ví dụ: HH001)
    ls_node-node_key  = 'H' && ls_head-temp_id. " [FIX] Dùng TEMP_ID

    " Text hiển thị: Temp ID - Sold To Party
    ls_node-text      = |{ ls_head-temp_id } - { ls_head-sold_to_party }|.
    ls_node-isfolder  = 'X'. " Đánh dấu đây là thư mục (có thể mở ra/đóng vào)

    " Icon Status (Dựa trên cột MESSAGE trong bảng Z)
    IF ls_head-message CS 'Error' OR ls_head-message CS 'Fail'.
      ls_node-n_image   = icon_led_red.
      ls_node-exp_image = icon_led_red.
    ELSE.
      ls_node-n_image   = icon_led_green.
      ls_node-exp_image = icon_led_green.
    ENDIF.

    APPEND ls_node TO lt_nodes.

    " 3. Loop qua danh sách Item con thuộc Header này
    LOOP AT gt_mu_item INTO DATA(ls_item) WHERE temp_id = ls_head-temp_id.
      CLEAR ls_node.

      " --- TẠO NODE CON (ITEM) ---
      " Key = 'I' + TempID + '_' + ItemNo (Ví dụ: IH001_10)
      ls_node-node_key = 'I' && ls_head-temp_id && '_' && ls_item-item_no.

      " Link vào cha
      " Relatkey phải trùng với node_key của Header ở trên ('HTMP001')
      ls_node-relatkey = 'H' && ls_head-temp_id.

      " Text hiển thị
      ls_node-text     = |Item { ls_item-item_no ALPHA = OUT } - { ls_item-material }|.
      ls_node-n_image  = icon_document.
      ls_node-isfolder = space.

      APPEND ls_node TO lt_nodes.
    ENDLOOP.
  ENDLOOP.

  " 4. Đẩy dữ liệu ra màn hình
  IF go_mu_tree IS BOUND.
    " Khi Upload lại file mới hoặc Refresh. Nếu không xóa, các node mới sẽ chèn thêm vào node cũ gây lộn xộn.
    go_mu_tree->delete_all_nodes( ).

    go_mu_tree->add_nodes(
      table_structure_name = 'MTREESNODE'
      node_table           = lt_nodes ).

    " Tự động mở rộng các thư mục cha (để user thấy luôn item bên trong)
    go_mu_tree->expand_root_nodes( ).

    READ TABLE gt_mu_header INTO ls_head INDEX 1.
    IF sy-subrc = 0.
      DATA: lv_first_key TYPE tv_nodekey.
      lv_first_key = 'H' && ls_head-temp_id.

      " A. Set trạng thái Selected trên cây (Visual)
      go_mu_tree->set_selected_node( node_key = lv_first_key ).

      " B. Load dữ liệu vào màn hình bên phải (Subscreen 0211)
      PERFORM prepare_header_detail USING lv_first_key.

      " C. Set Subscreen mặc định
      gv_mu_subscreen = '0211'.

      " D. Khởi tạo biến lưu vết
      " Để lần click tiếp theo, hệ thống biết đây là node cũ cần lưu
      gv_prev_node_key = lv_first_key.
    ENDIF.

    " Phải có dòng này Tree mới hiện lên ngay lập tức!
    " Flush lệnh xuống GUI
    " Các lệnh như add_nodes, set_selected_node chỉ đang xếp hàng trong hàng đợi (Queue) của hệ thống.
    " Lệnh flush bắt buộc hệ thống thực thi ngay các lệnh đó để vẽ cây lên màn hình.
    CALL METHOD cl_gui_cfw=>flush
      EXCEPTIONS
        cntl_system_error = 1
        cntl_error        = 2
        OTHERS            = 3.

    IF sy-subrc <> 0.
      " Xử lý lỗi nhẹ nhàng hơn thay vì để Dump
      " Có thể log lại lỗi hoặc bỏ qua nếu việc update icon không quá quan trọng
      MESSAGE 'Error load data to tree' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SAVE_CURRENT_DATA
*&---------------------------------------------------------------------*
* Description: Save data of current screen into internal tables (GT_MU_*)
* before switch to another screen
*----------------------------------------------------------------------*
FORM save_current_data.

  " Nếu chưa có node cũ (lần đầu vào) thì thoát
  IF gv_prev_node_key IS INITIAL.
    RETURN.
  ENDIF.

  DATA: lv_type TYPE c,
        lv_str  TYPE string.

  DATA: lv_temp_id TYPE ztb_so_upload_hd-temp_id,
        lv_item_no TYPE ztb_so_upload_it-item_no.

  DATA: lv_new_text      TYPE mtreesnode-text,
        lv_item_node_key TYPE tv_nodekey,
        lv_item_text     TYPE mtreesnode-text.

  lv_type = gv_prev_node_key(1). " Lấy ký tự đầu: H hoặc I

  " ===================================================================
  " 1. NODE CŨ LÀ HEADER
  " ===================================================================
  IF lv_type = 'H'.
    " Parse ID: H001 -> 001
    lv_str = gv_prev_node_key+1.
    lv_temp_id = lv_str.

    " [QUAN TRỌNG] Ép kiểu về dạng chuẩn (thêm số 0 nếu cần) để khớp với DB
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_temp_id
      IMPORTING
        output = lv_temp_id.

    " A. Cập nhật HEADER (Dùng Field Symbol thay vì MODIFY WHERE)
    READ TABLE gt_mu_header ASSIGNING FIELD-SYMBOL(<fs_head>)
         WITH KEY temp_id = lv_temp_id.

    IF sy-subrc = 0.
      " 1. Thông tin Tổ chức & Khách hàng
      <fs_head>-order_type    = gs_mu_header-order_type.         " Sales Order Type
      <fs_head>-sales_org     = gs_mu_header-sales_org.         " Sales Org
      <fs_head>-sales_channel = gs_mu_header-sales_channel.         " Dist. Channel
      <fs_head>-sales_div     = gs_mu_header-sales_div.         " Division
      <fs_head>-sales_off     = gs_mu_header-sales_off.         " Sales Office
      <fs_head>-sales_grp     = gs_mu_header-sales_grp.         " Sales Group
      <fs_head>-sold_to_party = gs_mu_header-sold_to_party. " Sold-to Party (KUNNR)

      " 2. Thông tin Đơn hàng
      <fs_head>-cust_ref      = gs_mu_header-cust_ref.      " PO Number / Cust Ref
      <fs_head>-req_date      = gs_mu_header-req_date.      " Req. Delivery Date
      <fs_head>-price_date    = gs_mu_header-price_date.    " Pricing Date
      <fs_head>-order_date    = gs_mu_header-order_date.    " Document Date

      " 3. Thông tin Thanh toán & Giao hàng
      <fs_head>-pmnttrms      = gs_mu_header-pmnttrms.      " Payment Terms
      <fs_head>-incoterms     = gs_mu_header-incoterms.     " Incoterms 1
      <fs_head>-inco2         = gs_mu_header-inco2.         " Incoterms Location
      <fs_head>-currency      = gs_mu_header-currency.      " Currency

      lv_new_text = |{ <fs_head>-temp_id } - { <fs_head>-sold_to_party }|.

      IF go_mu_tree IS BOUND.
        go_mu_tree->node_set_text(
          node_key = gv_prev_node_key
          text     = lv_new_text ).
      ENDIF.
    ENDIF.

    " B. Cập nhật ALV ITEMS
    IF go_mu_alv_items IS BOUND.
      go_mu_alv_items->check_changed_data( ).

      LOOP AT gt_disp_items INTO DATA(ls_disp_item).
        " Tương tự, dùng Field Symbol cho Item
        READ TABLE gt_mu_item ASSIGNING FIELD-SYMBOL(<fs_item_in_head>)
             WITH KEY temp_id = ls_disp_item-temp_id
                      item_no = ls_disp_item-item_no.
        IF sy-subrc = 0.
          " Cập nhật các cột hiển thị trên lưới ALV Item
          <fs_item_in_head>-material   = ls_disp_item-material.
          <fs_item_in_head>-quantity   = ls_disp_item-quantity.
          <fs_item_in_head>-plant      = ls_disp_item-plant.
          <fs_item_in_head>-ship_point = ls_disp_item-ship_point.
          <fs_item_in_head>-store_loc  = ls_disp_item-store_loc.
          <fs_item_in_head>-req_date   = ls_disp_item-req_date.

          lv_item_node_key = 'I' && <fs_item_in_head>-temp_id && '_' && <fs_item_in_head>-item_no.
          lv_item_text     = |Item { <fs_item_in_head>-item_no ALPHA = OUT } - { <fs_item_in_head>-material }|.

          IF go_mu_tree IS BOUND.
            go_mu_tree->node_set_text( node_key = lv_item_node_key text = lv_item_text ).
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ===================================================================
    " 2. NODE CŨ LÀ ITEM
    " ===================================================================
  ELSEIF lv_type = 'I'.
    " Parse Key: I_H001_10 -> H001 và 10
    lv_str = gv_prev_node_key.
    SHIFT lv_str LEFT BY 1 PLACES. " Bỏ chữ I
    SPLIT lv_str AT '_' INTO lv_temp_id lv_item_no.

    " [QUAN TRỌNG] Ép kiểu số 0
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_temp_id
      IMPORTING
        output = lv_temp_id.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_item_no
      IMPORTING
        output = lv_item_no.

    " A. Cập nhật ITEM (Input Fields)
    READ TABLE gt_mu_item ASSIGNING FIELD-SYMBOL(<fs_item>)
         WITH KEY temp_id = lv_temp_id
                  item_no = lv_item_no.

    IF sy-subrc = 0.
      " 1. Thông tin Vật tư & Số lượng
      <fs_item>-material   = gs_mu_item-material.   " Material Number
      <fs_item>-quantity   = gs_mu_item-quantity.   " Order Quantity
      <fs_item>-unit       = gs_mu_item-unit.        " Unit of Measure (VRKME)
      <fs_item>-short_text = gs_mu_item-short_text. " Short Text (ARKTX)

      " 2. Thông tin Plant & Kho
      <fs_item>-plant      = gs_mu_item-plant.      " Plant
      <fs_item>-store_loc  = gs_mu_item-store_loc.  " Storage Location
      <fs_item>-ship_point = gs_mu_item-ship_point. " Shipping Point

      " 3. Thông tin ngày tháng
      <fs_item>-req_date   = gs_mu_item-req_date.   " Schedule Line Date

      lv_item_text = |Item { <fs_item>-item_no ALPHA = OUT } - { <fs_item>-material }|.

      IF go_mu_tree IS BOUND.
        go_mu_tree->node_set_text(
          node_key = gv_prev_node_key
          text     = lv_item_text ).
      ENDIF.
    ENDIF.

    " B. Cập nhật ALV CONDITIONS
    IF go_mu_alv_cond IS BOUND.
      go_mu_alv_cond->check_changed_data( ).

      LOOP AT gt_disp_cond INTO DATA(ls_disp_cond).
        READ TABLE gt_mu_cond ASSIGNING FIELD-SYMBOL(<fs_cond>)
             WITH KEY temp_id   = ls_disp_cond-temp_id
                      item_no   = ls_disp_cond-item_no
                      cond_type = ls_disp_cond-cond_type
                      counter   = ls_disp_cond-counter.
        IF sy-subrc = 0.
          <fs_cond>-amount    = ls_disp_cond-amount.
          <fs_cond>-currency  = ls_disp_cond-currency.
          <fs_cond>-per       = ls_disp_cond-per.
          <fs_cond>-uom       = ls_disp_cond-uom.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  EXECUTE_VALIDATION
*&---------------------------------------------------------------------*
*& Description: Validate data using ZCL_SD_MASS_VALIDATOR
*----------------------------------------------------------------------*
FORM execute_validation USING pv_req_id TYPE zsd_req_id.

  PERFORM save_current_data.

  " A. Khai báo bảng tạm đúng chuẩn DB (không có field thừa của UI)
  DATA: lt_enrich_hd TYPE STANDARD TABLE OF ztb_so_upload_hd,
        lt_enrich_it TYPE STANDARD TABLE OF ztb_so_upload_it,
        lt_enrich_pr TYPE STANDARD TABLE OF ztb_so_upload_pr.

  " B. Đổ dữ liệu từ UI sang bảng tạm
  lt_enrich_hd = CORRESPONDING #( gt_mu_header ).
  lt_enrich_it = CORRESPONDING #( gt_mu_item ).
  lt_enrich_pr = CORRESPONDING #( gt_mu_cond ).

  " C. Gọi Form Enrich trên bảng tạm (Lúc này cấu trúc khớp 100% nên Casting an toàn)
  PERFORM exec_enrich_raw_data
    CHANGING
      lt_enrich_hd
      lt_enrich_it
      lt_enrich_pr.

  " D. Update ngược dữ liệu đã Enrich về lại bảng UI (GT_MU_...)
  " -- Update Header
  LOOP AT lt_enrich_hd INTO DATA(ls_enr_hd).
    READ TABLE gt_mu_header ASSIGNING FIELD-SYMBOL(<fs_ui_hd>)
         WITH KEY temp_id = ls_enr_hd-temp_id.
    IF sy-subrc = 0.
      " Chỉ update các trường có khả năng được autofill
      <fs_ui_hd>-pmnttrms  = ls_enr_hd-pmnttrms.
      <fs_ui_hd>-incoterms = ls_enr_hd-incoterms.
      <fs_ui_hd>-inco2     = ls_enr_hd-inco2.
      <fs_ui_hd>-currency  = ls_enr_hd-currency.
      <fs_ui_hd>-req_date  = ls_enr_hd-req_date.
    ENDIF.
  ENDLOOP.

  " -- Update Item
  LOOP AT lt_enrich_it INTO DATA(ls_enr_it).
    READ TABLE gt_mu_item ASSIGNING FIELD-SYMBOL(<fs_ui_it>)
         WITH KEY temp_id = ls_enr_it-temp_id
                  item_no = ls_enr_it-item_no.
    IF sy-subrc = 0.
      <fs_ui_it>-short_text = ls_enr_it-short_text.
      <fs_ui_it>-unit       = ls_enr_it-unit.
      <fs_ui_it>-plant      = ls_enr_it-plant.
      <fs_ui_it>-store_loc  = ls_enr_it-store_loc.
      <fs_ui_it>-ship_point = ls_enr_it-ship_point.
      <fs_ui_it>-req_date   = ls_enr_it-req_date.
    ENDIF.
  ENDLOOP.

  " -- Update Condition
  LOOP AT lt_enrich_pr INTO DATA(ls_enr_pr).
    READ TABLE gt_mu_cond ASSIGNING FIELD-SYMBOL(<fs_ui_pr>)
         WITH KEY temp_id   = ls_enr_pr-temp_id
                  item_no   = ls_enr_pr-item_no
                  cond_type = ls_enr_pr-cond_type
                  counter   = ls_enr_pr-counter.

    IF sy-subrc = 0.
      <fs_ui_pr>-currency = ls_enr_pr-currency.
      <fs_ui_pr>-uom      = ls_enr_pr-uom.
      <fs_ui_pr>-per      = ls_enr_pr-per.
    ENDIF.
  ENDLOOP.

  PERFORM sync_memory_to_staging USING pv_req_id.

  UPDATE ztb_so_error_log
    SET status   = 'FIXED'
        log_date = sy-datum
        log_user = sy-uname
    WHERE req_id = pv_req_id
      AND status = 'UNFIXED'. " Chỉ xử lý những lỗi đang tồn tại

  COMMIT WORK AND WAIT. " Commit để DB cập nhật trạng thái FIXED

  CALL METHOD zcl_sd_mass_validator=>set_context( pv_req_id ).

  CALL METHOD zcl_sd_mass_validator=>clear_errors( ).

  DATA: lv_error_flag TYPE abap_bool.

  " Khai báo biến tạm để Validate
  DATA: ls_db_head TYPE ztb_so_upload_hd,
        ls_db_item TYPE ztb_so_upload_it,
        ls_db_cond TYPE ztb_so_upload_pr.

  " ====================================================================
  " A. VALIDATE HEADER
  " ====================================================================
  LOOP AT gt_mu_header ASSIGNING FIELD-SYMBOL(<fs_head>).
    MOVE-CORRESPONDING <fs_head> TO ls_db_head.

    CALL METHOD zcl_sd_mass_validator=>execute_validation_hdr
      CHANGING
        cs_header = ls_db_head.

    " Map lại kết quả về UI
    <fs_head>-status  = ls_db_head-status.
    <fs_head>-message = ls_db_head-message.

    " [FIX] Check Status thay vì Type
    IF <fs_head>-status = 'ERROR' OR <fs_head>-status = 'E'.
      <fs_head>-icon = icon_led_red.
      lv_error_flag  = abap_true.
    ELSE.
      <fs_head>-icon = icon_led_green.
      <fs_head>-status = 'SUCCESS'. " Hoặc 'S' tùy logic dự án
    ENDIF.

    " ==================================================================
    " B. VALIDATE ITEM
    " ==================================================================
    LOOP AT gt_mu_item ASSIGNING FIELD-SYMBOL(<fs_item>)
         WHERE temp_id = <fs_head>-temp_id.

      MOVE-CORRESPONDING <fs_item> TO ls_db_item.

      CALL METHOD zcl_sd_mass_validator=>execute_validation_itm
        EXPORTING
          is_header = ls_db_head
        CHANGING
          cs_item   = ls_db_item.

      <fs_item>-status  = ls_db_item-status.
      <fs_item>-message = ls_db_item-message.

      IF <fs_item>-status = 'ERROR' OR <fs_item>-status = 'E'.
        <fs_item>-icon = icon_led_red.
        <fs_head>-icon = icon_led_red.
      ELSE.
        <fs_item>-icon = icon_led_green.
        <fs_item>-status = 'SUCCESS'.
      ENDIF.

      " ================================================================
      " C. VALIDATE CONDITION
      " ================================================================
      LOOP AT gt_mu_cond ASSIGNING FIELD-SYMBOL(<fs_cond>)
           WHERE temp_id = <fs_item>-temp_id
             AND item_no = <fs_item>-item_no.

        MOVE-CORRESPONDING <fs_cond> TO ls_db_cond.

        CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
          CHANGING
            cs_pricing = ls_db_cond.

        <fs_cond>-status  = ls_db_cond-status.
        <fs_cond>-message = ls_db_cond-message.

        IF <fs_cond>-status = 'ERROR' OR <fs_cond>-status = 'E'.
          <fs_cond>-icon = icon_led_red.
          <fs_item>-icon = icon_led_red.
        ELSE.
          <fs_cond>-icon = icon_led_green.
          <fs_cond>-status = 'SUCCESS'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDLOOP.

  PERFORM sync_memory_to_staging USING pv_req_id.

  " Save Log (Giữ nguyên)
  DATA: lt_errors_total TYPE ztty_validation_error.
  lt_errors_total = zcl_sd_mass_validator=>get_errors( ).
  IF lt_errors_total IS NOT INITIAL.
    CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
      EXPORTING
        it_errors = lt_errors_total.
  ENDIF.
  COMMIT WORK AND WAIT.

  PERFORM update_tree_icons.
  PERFORM highlight_error_cells.
  PERFORM refresh_current_screen.

  IF lv_error_flag = abap_true.
    MESSAGE 'Validation completed with errors.' TYPE 'S' DISPLAY LIKE 'W'.
  ELSE.
    MESSAGE 'Validation successful!' TYPE 'S'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SYNC_MEMORY_TO_STAGING
*&---------------------------------------------------------------------*
*& Description: Push Data From Internal Tables To Z-Tables
*----------------------------------------------------------------------*
FORM sync_memory_to_staging USING pv_req_id TYPE zsd_req_id.

  " --- 1. Cập nhật Header ---
  IF gt_mu_header IS NOT INITIAL.
    " Khai báo bảng tạm đúng chuẩn DB (Flat structure)
    DATA: lt_db_head TYPE STANDARD TABLE OF ztb_so_upload_hd.

    LOOP AT gt_mu_header INTO DATA(ls_ui_head).
      " Move dữ liệu từ UI sang DB struct
      APPEND INITIAL LINE TO lt_db_head ASSIGNING FIELD-SYMBOL(<fs_db_head>).
      MOVE-CORRESPONDING ls_ui_head TO <fs_db_head>.
      <fs_db_head>-req_id = pv_req_id.
    ENDLOOP.

    " Update từ bảng Flat
    MODIFY ztb_so_upload_hd FROM TABLE lt_db_head.
  ENDIF.

  " --- 2. Cập nhật Item ---
  IF gt_mu_item IS NOT INITIAL.
    DATA: lt_db_item TYPE STANDARD TABLE OF ztb_so_upload_it.

    LOOP AT gt_mu_item INTO DATA(ls_ui_item).
      APPEND INITIAL LINE TO lt_db_item ASSIGNING FIELD-SYMBOL(<fs_db_item>).
      MOVE-CORRESPONDING ls_ui_item TO <fs_db_item>.
      <fs_db_item>-req_id = pv_req_id.
    ENDLOOP.

    MODIFY ztb_so_upload_it FROM TABLE lt_db_item.
  ENDIF.

  " --- 3. Cập nhật Condition ---
  IF gt_mu_cond IS NOT INITIAL.
    DATA: lt_db_cond TYPE STANDARD TABLE OF ztb_so_upload_pr.

    LOOP AT gt_mu_cond INTO DATA(ls_ui_cond).
      APPEND INITIAL LINE TO lt_db_cond ASSIGNING FIELD-SYMBOL(<fs_db_cond>).
      MOVE-CORRESPONDING ls_ui_cond TO <fs_db_cond>.
      <fs_db_cond>-req_id = pv_req_id.
    ENDLOOP.

    MODIFY ztb_so_upload_pr FROM TABLE lt_db_cond.
  ENDIF.

  COMMIT WORK AND WAIT.

ENDFORM.

FORM update_tree_icons.
  CHECK go_mu_tree IS BOUND.

  DATA: lv_node_key TYPE tv_nodekey.
  DATA: lv_has_error TYPE abap_bool. " [MỚI] Biến cờ kiểm tra lỗi

  " [FIX] Khai báo biến đúng type TV_IMAGE cho method của Tree
  DATA: lv_img_red   TYPE tv_image,
        lv_img_green TYPE tv_image,
        lv_img_doc   TYPE tv_image.

  " Gán giá trị icon vào biến
  lv_img_red   = icon_led_red.
  lv_img_green = icon_led_green.
  lv_img_doc   = icon_document.

  " Update Header Nodes
  LOOP AT gt_mu_header INTO DATA(ls_head).
    lv_node_key = 'H' && ls_head-temp_id.

    IF ls_head-status = 'ERROR' OR ls_head-status = 'E'.
*      go_mu_tree->node_set_exp_image( node_key = lv_node_key exp_image = lv_img_red ).
      CALL METHOD go_mu_tree->node_set_exp_image
        EXPORTING
          node_key             = lv_node_key
          exp_image            = lv_img_red " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed               = 1
          node_not_found       = 2
          cntl_system_error    = 3
          not_allowed_for_leaf = 4  " <--- Lỗi này xảy ra nếu set exp_image cho Node lá (Item)
          OTHERS               = 5.

      IF sy-subrc <> 0.
        " Xử lý lỗi (nếu cần)
        " sy-subrc = 2: Sai Node Key
        " sy-subrc = 4: Node này là lá (Item), không phải Folder nên không set được icon mở rộng
        " Tốt nhất là bỏ qua (không làm gì) để tránh dump
      ENDIF.
*      go_mu_tree->node_set_n_image(   node_key = lv_node_key n_image   = lv_img_red ).
      " Thay thế dòng gọi cũ bằng đoạn này:
      CALL METHOD go_mu_tree->node_set_n_image
        EXPORTING
          node_key          = lv_node_key
          n_image           = lv_img_red " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed            = 1
          node_not_found    = 2
          cntl_system_error = 3
          OTHERS            = 4.

      IF sy-subrc <> 0.
        " Nếu lỗi, ta có thể bỏ qua hoặc log lại, nhưng quan trọng là KHÔNG BỊ DUMP nữa.
        " Debug tại đây để xem sy-subrc bằng mấy.
        " Nếu sy-subrc = 2 nghĩa là NODE_NOT_FOUND (Sai Key).
      ENDIF.
    ELSE.
*      go_mu_tree->node_set_exp_image( node_key = lv_node_key exp_image = lv_img_green ).
      CALL METHOD go_mu_tree->node_set_exp_image
        EXPORTING
          node_key             = lv_node_key
          exp_image            = lv_img_green " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed               = 1
          node_not_found       = 2
          cntl_system_error    = 3
          not_allowed_for_leaf = 4  " <--- Lỗi này xảy ra nếu set exp_image cho Node lá (Item)
          OTHERS               = 5.

      IF sy-subrc <> 0.
        " Xử lý lỗi (nếu cần)
        " sy-subrc = 2: Sai Node Key
        " sy-subrc = 4: Node này là lá (Item), không phải Folder nên không set được icon mở rộng
        " Tốt nhất là bỏ qua (không làm gì) để tránh dump
      ENDIF.
*      go_mu_tree->node_set_n_image(   node_key = lv_node_key n_image   = lv_img_green ).
      CALL METHOD go_mu_tree->node_set_n_image
        EXPORTING
          node_key          = lv_node_key
          n_image           = lv_img_green " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed            = 1
          node_not_found    = 2
          cntl_system_error = 3
          OTHERS            = 4.

      IF sy-subrc <> 0.
        " Nếu lỗi, ta có thể bỏ qua hoặc log lại, nhưng quan trọng là KHÔNG BỊ DUMP nữa.
        " Debug tại đây để xem sy-subrc bằng mấy.
        " Nếu sy-subrc = 2 nghĩa là NODE_NOT_FOUND (Sai Key).
      ENDIF.
    ENDIF.
  ENDLOOP.

  " Update Item Nodes
  LOOP AT gt_mu_item INTO DATA(ls_item).

    READ TABLE gt_mu_header TRANSPORTING NO FIELDS
      WITH KEY temp_id = ls_item-temp_id.

    IF sy-subrc <> 0.
      " Item này bị mồ côi (Orphan Item), không có cha
      " -> Nó chắc chắn không được vẽ lên cây -> Bỏ qua update icon
      CONTINUE.
    ENDIF.

    lv_node_key = 'I' && ls_item-temp_id && '_' && ls_item-item_no.

*    IF ls_item-status = 'ERROR' OR ls_item-status = 'E'.
    " --- [LOGIC MỚI BẮT ĐẦU TỪ ĐÂY] ---
    lv_has_error = abap_false.

    " A. Kiểm tra chính bản thân Item có lỗi không
    IF ls_item-status = 'ERROR' OR ls_item-status = 'E'.
      lv_has_error = abap_true.
    ENDIF.

    " B. Kiểm tra xem CÓ Condition nào của Item này bị lỗi không?
    " (Chỉ kiểm tra nếu bản thân nó chưa lỗi, để tiết kiệm hiệu năng)
    IF lv_has_error = abap_false.
      LOOP AT gt_mu_cond TRANSPORTING NO FIELDS
           WHERE temp_id = ls_item-temp_id
             AND item_no = ls_item-item_no
             AND ( status = 'ERROR' OR status = 'E' ).
        " Tìm thấy ít nhất 1 condition lỗi -> Đánh dấu Item lỗi luôn
        lv_has_error = abap_true.
        EXIT. " Thoát vòng loop condition ngay
      ENDLOOP.
    ENDIF.

    IF lv_has_error = abap_true.
      CALL METHOD go_mu_tree->node_set_n_image
        EXPORTING
          node_key          = lv_node_key
          n_image           = lv_img_red " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed            = 1
          node_not_found    = 2
          cntl_system_error = 3
          OTHERS            = 4.

      IF sy-subrc <> 0.
        " Nếu lỗi, ta có thể bỏ qua hoặc log lại, nhưng quan trọng là KHÔNG BỊ DUMP nữa.
        " Debug tại đây để xem sy-subrc bằng mấy.
        " Nếu sy-subrc = 2 nghĩa là NODE_NOT_FOUND (Sai Key).
      ENDIF.
    ELSE.
*       go_mu_tree->node_set_n_image( node_key = lv_node_key n_image = lv_img_doc ).
      CALL METHOD go_mu_tree->node_set_n_image
        EXPORTING
          node_key          = lv_node_key
          n_image           = lv_img_doc " (Hoặc biến icon tương ứng)
        EXCEPTIONS
          failed            = 1
          node_not_found    = 2
          cntl_system_error = 3
          OTHERS            = 4.

      IF sy-subrc <> 0.
        " Nếu lỗi, ta có thể bỏ qua hoặc log lại, nhưng quan trọng là KHÔNG BỊ DUMP nữa.
        " Debug tại đây để xem sy-subrc bằng mấy.
        " Nếu sy-subrc = 2 nghĩa là NODE_NOT_FOUND (Sai Key).
      ENDIF.
    ENDIF.
  ENDLOOP.

  " Flush lệnh xuống GUI
  CALL METHOD cl_gui_cfw=>flush
    EXCEPTIONS
      cntl_system_error = 1
      cntl_error        = 2
      OTHERS            = 3.

  IF sy-subrc <> 0.
    " Xử lý lỗi nhẹ nhàng hơn thay vì để Dump
    " Có thể log lại lỗi hoặc bỏ qua nếu việc update icon không quá quan trọng
    MESSAGE 'Warning: Could not update tree icons completely.' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

FORM refresh_current_screen.
  DATA: ls_stable TYPE lvc_s_stbl.
  ls_stable-row = 'X'. ls_stable-col = 'X'.

  " 1. Refresh lại data cho ALV (Items hoặc Cond)
  " Logic này phụ thuộc vào user đang đứng ở màn hình nào
  IF gv_mu_subscreen = '0211'.
    " Đang ở Header -> Reload ALV Items
    PERFORM prepare_header_detail USING gv_prev_node_key.

    IF go_mu_alv_items IS BOUND.
      go_mu_alv_items->refresh_table_display( is_stable = ls_stable ).
    ENDIF.

  ELSEIF gv_mu_subscreen = '0212'.
    " Đang ở Item -> Reload ALV Conds
    PERFORM prepare_item_detail USING gv_prev_node_key.

    IF go_mu_alv_cond IS BOUND.
      go_mu_alv_cond->refresh_table_display( is_stable = ls_stable ).
    ENDIF.
  ENDIF.
ENDFORM.

FORM highlight_error_cells.
  INCLUDE <icon>. " Cần include này để dùng constant icon_message_information

  " 1. DỌN DẸP MÀU CŨ & ICON CŨ
  CLEAR gt_screen_err_fields.

  " Reset ALV Items
  IF gt_disp_items IS NOT INITIAL.
    LOOP AT gt_disp_items ASSIGNING FIELD-SYMBOL(<fs_disp_item>).
      CLEAR: <fs_disp_item>-celltab, <fs_disp_item>-err_btn. " <--- Clear cả Icon
    ENDLOOP.
  ENDIF.

  " Reset ALV Cond
  IF gt_disp_cond IS NOT INITIAL.
    LOOP AT gt_disp_cond ASSIGNING FIELD-SYMBOL(<fs_disp_cond>).
      CLEAR: <fs_disp_cond>-celltab, <fs_disp_cond>-err_btn. " <--- Clear cả Icon
    ENDLOOP.
  ENDIF.

  " 2. LẤY LOG TỪ DB
  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log.
  SELECT * FROM ztb_so_error_log INTO TABLE lt_error_log
    WHERE req_id = gv_current_req_id AND status = 'UNFIXED'.

  IF lt_error_log IS INITIAL. RETURN. ENDIF.

  " 3. MACRO TÔ MÀU & MAPPING
  DATA: ls_color TYPE lvc_s_scol.

  " Macro tô màu
  DEFINE _set_alv_color.
    CLEAR ls_color.
    ls_color-fname     = &1.
    ls_color-color-col = 6. " Đỏ
    ls_color-color-int = 1. " Đậm
    INSERT ls_color INTO TABLE &2-celltab.
  END-OF-DEFINITION.

  " Macro mapping tên trường (Fix lỗi không tô màu)
  DATA: lv_map_fname TYPE fieldname.
  DEFINE _map_field_name.
    lv_map_fname = &1.
    CASE &1.
      WHEN 'MATNR' OR 'MATERIAL'. lv_map_fname = 'MATERIAL'.
      WHEN 'WERKS' OR 'PLANT'.    lv_map_fname = 'PLANT'.
      WHEN 'UNIT'  OR 'UOM'.      lv_map_fname = 'UOM'.
      WHEN 'KBETR' OR 'AMOUNT'.   lv_map_fname = 'AMOUNT'.
      WHEN 'WAERS' OR 'CURRENCY'. lv_map_fname = 'CURRENCY'.
      WHEN 'KPEIN' OR 'PER'.      lv_map_fname = 'PER'.
      WHEN 'KSCHL' OR 'COND_TYPE'.lv_map_fname = 'COND_TYPE'.
      WHEN 'LGORT' OR 'STORE_LOC'.lv_map_fname = 'STORE_LOC'.
      WHEN 'VSTEL' OR 'SHIP_POINT'.lv_map_fname = 'SHIP_POINT'.
    ENDCASE.
  END-OF-DEFINITION.

  " 4. DUYỆT LỖI
  LOOP AT lt_error_log INTO DATA(ls_err).

    " ===============================================================
    " A. XỬ LÝ MÀN HÌNH 0211 (HEADER DETAIL & ALV ITEMS)
    " ===============================================================
    IF gv_mu_subscreen = '0211'.

      " 1. Lỗi Input Field (Header) - Giữ nguyên logic cũ của bạn
      IF ls_err-temp_id = gs_mu_header-temp_id AND ls_err-item_no IS INITIAL.
        CASE ls_err-fieldname.
          WHEN 'SOLD_TO'.    APPEND 'GS_MU_HEADER-SOLD_TO_PARTY' TO gt_screen_err_fields.
          WHEN 'REQ_DATE'.   APPEND 'GS_MU_HEADER-REQ_DATE'      TO gt_screen_err_fields.
          WHEN 'PO_NUMBER'.  APPEND 'GS_MU_HEADER-CUST_REF'      TO gt_screen_err_fields.
          WHEN OTHERS.
            DATA(lv_h_fname) = 'GS_MU_HEADER-' && ls_err-fieldname.
            APPEND lv_h_fname TO gt_screen_err_fields.
        ENDCASE.
      ENDIF.

      " 2. Lỗi ALV Items (Item con của Header đang chọn)
      IF ls_err-temp_id = gs_mu_header-temp_id AND ls_err-item_no IS NOT INITIAL.

        READ TABLE gt_disp_items ASSIGNING <fs_disp_item>
             WITH KEY temp_id = ls_err-temp_id item_no = ls_err-item_no.

        IF sy-subrc = 0.
          " [FIX 2] Gán Icon vào cột ERR_BTN để hiển thị lỗi
          <fs_disp_item>-err_btn = icon_protocol.

          " [FIX 1] Mapping tên trường trước khi tô màu
          _map_field_name ls_err-fieldname.

          " Tô màu
          _set_alv_color lv_map_fname <fs_disp_item>.
        ENDIF.
      ENDIF.

      " ===============================================================
      " B. XỬ LÝ MÀN HÌNH 0212 (ITEM DETAIL & ALV CONDITIONS)
      " ===============================================================
    ELSEIF gv_mu_subscreen = '0212'.

      IF ls_err-temp_id = gs_mu_item-temp_id AND ls_err-item_no = gs_mu_item-item_no.

        " Check xem lỗi thuộc Condition hay Input Field Item?
        IF ls_err-fieldname = 'COND_TYPE' OR ls_err-fieldname = 'AMOUNT' OR
           ls_err-fieldname = 'CURRENCY'  OR ls_err-fieldname = 'PER' OR
           ls_err-fieldname = 'KSCHL'     OR ls_err-fieldname = 'KBETR'.

          " -> Lỗi ALV Condition
          READ TABLE gt_disp_cond ASSIGNING <fs_disp_cond>
               WITH KEY temp_id = ls_err-temp_id item_no = ls_err-item_no. " + Cond Key nếu cần

          IF sy-subrc = 0.
            " [FIX 2] Gán Icon
            <fs_disp_cond>-err_btn = icon_protocol.

            " [FIX 1] Mapping
            _map_field_name ls_err-fieldname.

            " Tô màu
            _set_alv_color lv_map_fname <fs_disp_cond>.
          ENDIF.

        ELSE.
          " -> Lỗi Input Field (Item)
          CASE ls_err-fieldname.
            WHEN 'MATNR' OR 'MATERIAL'. APPEND 'GS_MU_ITEM-MATERIAL' TO gt_screen_err_fields.
            WHEN 'WERKS' OR 'PLANT'.    APPEND 'GS_MU_ITEM-PLANT'    TO gt_screen_err_fields.
            WHEN 'MENG13' OR 'QUANTITY'. APPEND 'GS_MU_ITEM-QUANTITY' TO gt_screen_err_fields.
            WHEN OTHERS.
              DATA(lv_i_fname) = 'GS_MU_ITEM-' && ls_err-fieldname.
              APPEND lv_i_fname TO gt_screen_err_fields.
          ENDCASE.
        ENDIF.
      ENDIF.

    ENDIF.
  ENDLOOP.

  " Refresh lại ALV để cập nhật màu và icon
  IF go_mu_alv_items IS BOUND. go_mu_alv_items->refresh_table_display( ). ENDIF.
  IF go_mu_alv_cond  IS BOUND. go_mu_alv_cond->refresh_table_display( ).  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PERFORM_CREATE_SALES_ORDERS
*&---------------------------------------------------------------------*
FORM perform_create_sales_orders.

  DATA: ls_header_in      TYPE bapisdhd1,
        ls_header_inx     TYPE bapisdhd1x,
        lt_items_in       TYPE TABLE OF bapisditm,
        lt_items_inx      TYPE TABLE OF bapisditmx,
        lt_partners       TYPE TABLE OF bapiparnr,
        lt_schedules_in   TYPE TABLE OF bapischdl,
        lt_schedules_inx  TYPE TABLE OF bapischdlx,
        lt_conditions_in  TYPE TABLE OF bapicond,
        lt_conditions_inx TYPE TABLE OF bapicondx,
        lt_return         TYPE TABLE OF bapiret2.

  DATA: lt_incomplete TYPE TABLE OF bapiincomp,
        ls_incomplete TYPE bapiincomp.

  DATA: lv_salesdocument   TYPE vbak-vbeln,
        lv_item_no         TYPE posnr_va,
        lt_bapi_errors     TYPE ztty_validation_error,
        lv_vbtyp           TYPE vbak-vbtyp,
        lv_bus_obj         TYPE char10,
        lv_has_child_error TYPE abap_bool.

  DATA: lv_block_creation TYPE abap_bool.

  DATA: lv_sold_to_party TYPE kunnr.

  " 1. Dùng Sorted Table để search (READ TABLE) cực nhanh
  DATA: lt_valid_item_nos TYPE SORTED TABLE OF posnr_va WITH UNIQUE KEY table_line.

  " --- LOOP QUA BẢNG MASTER (UI MỚI) ---
  LOOP AT gt_mu_header ASSIGNING FIELD-SYMBOL(<fs_hd>).

    " 1. CHỈ XỬ LÝ DÒNG ĐẠT YÊU CẦU & CHƯA TẠO SO
    " (Giả sử Status 'S' hoặc 'SUCCESS' là ok. Dòng 'E' bỏ qua)
    IF <fs_hd>-status <> 'S' AND <fs_hd>-status <> 'SUCCESS'.
      CONTINUE.
    ENDIF.

    " Nếu đã có số SO rồi thì bỏ qua (tránh tạo trùng)
    IF <fs_hd>-vbeln_so IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    lv_block_creation = abap_false.

    " A. Duyệt qua tất cả Item của Header này
    LOOP AT gt_mu_item INTO DATA(ls_check_item) WHERE temp_id = <fs_hd>-temp_id.

      " A1. Nếu Item bị lỗi -> CHẶN
      IF ls_check_item-status <> 'S' AND ls_check_item-status <> 'SUCCESS'.
        lv_block_creation = abap_true.
        <fs_hd>-message = |Skipped: Item { ls_check_item-item_no } has errors.|.
        EXIT. " Thoát vòng lặp Item ngay lập tức
      ENDIF.

      " A2. Nếu Item OK, check tiếp Condition của Item đó
      LOOP AT gt_mu_cond INTO DATA(ls_check_cond)
           WHERE temp_id = ls_check_item-temp_id
             AND item_no = ls_check_item-item_no.

        " Nếu Condition bị lỗi -> CHẶN
        IF ls_check_cond-status <> 'S' AND ls_check_cond-status <> 'SUCCESS'.
          lv_block_creation = abap_true.
          <fs_hd>-message = |Skipped: Condition { ls_check_cond-cond_type } in Item { ls_check_item-item_no } has errors.|.
          EXIT. " Thoát vòng lặp Condition
        ENDIF.
      ENDLOOP.

      " Nếu đã bị chặn ở trong vòng lặp Condition -> Thoát vòng lặp Item luôn
      IF lv_block_creation = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    " B. Xử lý kết quả Check
    IF lv_block_creation = abap_true.
      " Đánh dấu vàng để User biết dòng này bị bỏ qua do lỗi ở con/cháu
      <fs_hd>-icon = icon_led_yellow.
      CONTINUE. " >>> BỎ QUA HEADER NÀY, KHÔNG GỌI BAPI <<<
    ENDIF.

    " 2. INIT BAPI MEMORY (Quan trọng)
    CALL FUNCTION 'SD_SALES_DOCUMENT_INIT'
      EXPORTING
        status_buffer_refresh = 'X'
        refresh_v45i          = 'X'.

    CLEAR: ls_header_in, ls_header_inx, lv_salesdocument, lv_vbtyp, lv_bus_obj.
    REFRESH: lt_items_in, lt_items_inx, lt_partners, lt_schedules_in,
             lt_schedules_inx, lt_conditions_in, lt_conditions_inx,
             lt_return, lt_bapi_errors, lt_incomplete, lt_valid_item_nos.

    " 3. CHECK LẠI LOGIC CON (Nếu Header xanh nhưng Item đỏ -> Bỏ qua)
    lv_has_child_error = abap_false.
    LOOP AT gt_mu_item TRANSPORTING NO FIELDS
         WHERE temp_id = <fs_hd>-temp_id
           AND ( status = 'E' OR status = 'ERROR' ).
      lv_has_child_error = abap_true.
      EXIT.
    ENDLOOP.

    IF lv_has_child_error = abap_true.
      <fs_hd>-message = 'Skipped: Contains items with errors.'.
      <fs_hd>-icon    = icon_led_yellow.
      CONTINUE.
    ENDIF.

    " 4. CHECK LOẠI CHỨNG TỪ (Lấy VBTYP)
    DATA(lv_auart) = <fs_hd>-order_type. " Field name trên UI mới
    TRANSLATE lv_auart TO UPPER CASE.
    CONDENSE lv_auart NO-GAPS.

    SELECT SINGLE vbtyp FROM tvak INTO lv_vbtyp WHERE auart = lv_auart.
    IF sy-subrc <> 0.
      <fs_hd>-message = |Order Type { lv_auart } invalid|.
      <fs_hd>-status  = 'E'.
      <fs_hd>-icon    = icon_led_red.
      CONTINUE.
    ENDIF.

    " 5. MAPPING DỮ LIỆU
    " Header
    ls_header_in-doc_type   = lv_auart.
    ls_header_in-sales_org  = <fs_hd>-sales_org.
    ls_header_in-distr_chan = <fs_hd>-sales_channel.
    ls_header_in-division   = <fs_hd>-sales_div.
    ls_header_in-req_date_h = <fs_hd>-req_date.
    ls_header_in-price_date = <fs_hd>-price_date.
    ls_header_in-purch_no_c = <fs_hd>-cust_ref.
    ls_header_in-pmnttrms   = <fs_hd>-pmnttrms.
    ls_header_in-incoterms1 = <fs_hd>-incoterms.
    ls_header_in-incoterms2 = <fs_hd>-inco2.
    ls_header_in-currency   = <fs_hd>-currency.

    " Partners
    " 1. Gán giá trị từ bảng Header
    lv_sold_to_party = <fs_hd>-sold_to_party.

    " 2. Thêm số 0 vào đầu (Ví dụ: '1000011' -> '0001000011')
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_sold_to_party
      IMPORTING
        output = lv_sold_to_party.
    APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to_party ) TO lt_partners.
    APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to_party ) TO lt_partners.

    " Items (Lấy từ GT_MU_ITEM)
    LOOP AT gt_mu_item ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE temp_id = <fs_hd>-temp_id.
      lv_item_no = <fs_it>-item_no.

      APPEND VALUE #(
        itm_number = lv_item_no
        material   = <fs_it>-material
        target_qty = <fs_it>-quantity
        target_qu  = <fs_it>-unit
        plant      = <fs_it>-plant
        store_loc  = <fs_it>-store_loc
      ) TO lt_items_in.

      " 3. Chỉ những Item nào được đưa vào lt_items_in mới được có mặt ở đây
      INSERT lv_item_no INTO TABLE lt_valid_item_nos.

      " Schedule Lines (Nếu cần)
      IF lv_vbtyp = 'C' OR lv_vbtyp = 'H' OR lv_vbtyp = 'I'.
        APPEND VALUE #( itm_number = lv_item_no req_qty = <fs_it>-quantity ) TO lt_schedules_in.
      ENDIF.
    ENDLOOP.

    " Conditions (Lấy từ GT_MU_COND)
    LOOP AT gt_mu_cond ASSIGNING FIELD-SYMBOL(<fs_pr>) WHERE temp_id = <fs_hd>-temp_id.

      "      4. Kiểm tra Condition mồ côi
      READ TABLE lt_valid_item_nos TRANSPORTING NO FIELDS
           WITH KEY table_line = <fs_pr>-item_no.

      IF sy-subrc <> 0.
        " Đây là Condition mồ côi (Có TempID khớp nhưng Item No không khớp với bất kỳ Item nào đang xử lý)
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        itm_number = <fs_pr>-item_no
        cond_type  = <fs_pr>-cond_type
        cond_value = <fs_pr>-amount
        currency   = <fs_pr>-currency
        cond_unit  = <fs_pr>-uom
        cond_p_unt = <fs_pr>-per
      ) TO lt_conditions_in.
    ENDLOOP.

    " 6. GỌI BAPI TẠO SO
    CASE lv_vbtyp.
      WHEN 'C'. lv_bus_obj = 'BUS2032'.
      WHEN 'H'. lv_bus_obj = 'BUS2102'. " Returns
      WHEN 'I'. lv_bus_obj = 'BUS2032'.
      WHEN 'K'. lv_bus_obj = 'BUS2094'.
      WHEN 'L'. lv_bus_obj = 'BUS2096'.
      WHEN 'G'. lv_bus_obj = 'BUS2034'.
      WHEN OTHERS. lv_bus_obj = 'BUS2032'.
    ENDCASE.

    CALL FUNCTION 'SD_SALESDOCUMENT_CREATE'
      EXPORTING
        sales_header_in     = ls_header_in
        business_object     = lv_bus_obj
      IMPORTING
        salesdocument_ex    = lv_salesdocument
      TABLES
        return              = lt_return
        sales_items_in      = lt_items_in
        sales_partners      = lt_partners
        sales_schedules_in  = lt_schedules_in
        sales_conditions_in = lt_conditions_in
        incomplete_log      = lt_incomplete.

    " 7. XỬ LÝ KẾT QUẢ
    IF lv_salesdocument IS NOT INITIAL.
      " === SUCCESS ===
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

      <fs_hd>-status   = 'SUCCESS'.
      <fs_hd>-vbeln_so = lv_salesdocument.
      <fs_hd>-icon     = icon_led_green.

      " Xử lý Incomplete Log (Nếu có)
      IF lt_incomplete IS NOT INITIAL.
        <fs_hd>-message = |Created { lv_salesdocument } (Incomplete)|.
        <fs_hd>-icon    = icon_led_yellow.

        " Lưu log incomplete vào DB Log để user xem
        LOOP AT lt_incomplete INTO ls_incomplete.
          APPEND VALUE #(
            req_id = <fs_hd>-req_id temp_id = <fs_hd>-temp_id
            item_no = ls_incomplete-itm_number fieldname = ls_incomplete-field_name
            msg_type = 'W' message = |Incomplete: { ls_incomplete-field_text }|
          ) TO lt_bapi_errors.
        ENDLOOP.
      ELSE.
        <fs_hd>-message = |Created { lv_salesdocument } successfully|.

        " >>> GỌI AUTO DELIVERY & PICK <<<
        " (Chỉ gọi nếu là Order Type bán hàng chuẩn)
        IF lv_vbtyp = 'C' OR lv_vbtyp = 'I'.
          PERFORM perform_auto_delivery USING lv_salesdocument CHANGING <fs_hd>.
        ENDIF.
      ENDIF.

    ELSE.
      " === FAILED ===
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

      <fs_hd>-status = 'ERROR'. " Hoặc 'E'
      <fs_hd>-icon   = icon_led_red.

      " Lấy message lỗi đầu tiên
      LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
        <fs_hd>-message = ls_ret-message.

        " Thu thập lỗi BAPI để lưu Log
        APPEND VALUE #(
             req_id = <fs_hd>-req_id temp_id = <fs_hd>-temp_id
             item_no = '000000' " Header error
             fieldname = 'BAPI_ERROR'
             msg_type = 'E' message = ls_ret-message
        ) TO lt_bapi_errors.
      ENDLOOP.
    ENDIF.

    " 8. LƯU LOG LỖI VÀO DB (Thông qua Logger)
    IF lt_bapi_errors IS NOT INITIAL.
      CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
        EXPORTING
          it_errors = lt_bapi_errors.
    ENDIF.

  ENDLOOP.

  " 9. CẬP NHẬT TRẠNG THÁI MỚI XUỐNG DB STAGING
  PERFORM sync_memory_to_staging USING gv_current_req_id.

  COMMIT WORK AND WAIT.

  MESSAGE 'Sales Order creation process completed.' TYPE 'S'.

ENDFORM.

FORM perform_auto_delivery
  USING    iv_vbeln_so TYPE vbak-vbeln
  CHANGING cs_header   TYPE ty_mu_header_ext. " (Bao gồm ZTB_SO_UPLOAD_HD)

  DATA: lt_items    TYPE TABLE OF bapidlvreftosalesorder,
        ls_item     TYPE bapidlvreftosalesorder,
        lv_delivery TYPE likp-vbeln,
        lv_num_del  TYPE bapidlvcreateheader-num_deliveries,
        lt_return   TYPE TABLE OF bapiret2,
        lv_msg      TYPE string.

  DATA: lt_vbap TYPE TABLE OF vbap,
        ls_vbap TYPE vbap.

  " 1. Lấy thông tin Item từ SO vừa tạo (để lấy Shipping Point)
  SELECT vbeln, posnr, kwmeng, vrkme, vstel
    FROM vbap
    INTO CORRESPONDING FIELDS OF TABLE @lt_vbap
    WHERE vbeln = @iv_vbeln_so
      AND kwmeng > 0.

  IF sy-subrc <> 0.
    cs_header-message = |SO { iv_vbeln_so } created, but no items found for delivery.|.
    RETURN.
  ENDIF.

  " 2. Kiểm tra Shipping Point (Phải duy nhất)
  DATA(lt_vstel_check) = lt_vbap.
  SORT lt_vstel_check BY vstel.
  DELETE ADJACENT DUPLICATES FROM lt_vstel_check COMPARING vstel.

  IF lines( lt_vstel_check ) > 1.
    cs_header-message = |SO { iv_vbeln_so } created. ⚠️ Delivery skipped: Multiple Shipping Points.|.
    " (Status vẫn là SUCCESS vì SO đã tạo, chỉ có Delivery là fail)
    RETURN.
  ENDIF.

  READ TABLE lt_vstel_check INTO DATA(ls_vstel) INDEX 1.
  IF ls_vstel-vstel IS INITIAL.
    cs_header-message = |SO { iv_vbeln_so } created. ⚠️ Delivery skipped: No Shipping Point determined.|.
    RETURN.
  ENDIF.

  " 3. Chuẩn bị dữ liệu BAPI Delivery
  LOOP AT lt_vbap INTO ls_vbap.
    CLEAR ls_item.
    ls_item-ref_doc    = ls_vbap-vbeln.
    ls_item-ref_item   = ls_vbap-posnr.
    ls_item-dlv_qty    = ls_vbap-kwmeng.
    ls_item-sales_unit = ls_vbap-vrkme.
    APPEND ls_item TO lt_items.
  ENDLOOP.

  " 4. Gọi BAPI tạo Delivery
  CALL FUNCTION 'BAPI_OUTB_DELIVERY_CREATE_SLS'
    EXPORTING
      ship_point        = ls_vstel-vstel
      due_date          = sy-datum " (Mặc định giao ngay hôm nay)
    IMPORTING
      delivery          = lv_delivery
      num_deliveries    = lv_num_del
    TABLES
      sales_order_items = lt_items
      return            = lt_return.

  " 5. Xử lý kết quả
  IF lv_delivery IS NOT INITIAL.
    " === THÀNH CÔNG ===
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

    " Cập nhật vào Structure (để hiện lên ALV)
    cs_header-vbeln_dlv = lv_delivery.
    cs_header-message   = |SO { iv_vbeln_so } created. ✅ Delivery { lv_delivery } created.|.

    " --- [THÊM MỚI]: GỌI AUTO PICK ---
    PERFORM perform_auto_pick_delivery
      USING    lv_delivery
      CHANGING cs_header.
    " ---------------------------------

    " Cập nhật vào DB Staging (Header)
    UPDATE ztb_so_upload_hd
      SET vbeln_dlv = lv_delivery
          message   = cs_header-message
      WHERE req_id  = cs_header-req_id
        AND temp_id = cs_header-temp_id.

  ELSE.
    " === THẤT BẠI ===
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    " Lấy thông báo lỗi
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      lv_msg = ls_ret-message.
      EXIT.
    ENDLOOP.
    IF lv_msg IS INITIAL. lv_msg = 'Unknown error'. ENDIF.

    cs_header-message = |SO { iv_vbeln_so } created. ❌ Delivery Failed: { lv_msg }|.

    " Update Message vào DB Staging
    UPDATE ztb_so_upload_hd
    SET vbeln_dlv = lv_delivery   " <<< Quan trọng
           message   = cs_header-message
      WHERE req_id  = cs_header-req_id
        AND temp_id = cs_header-temp_id.
  ENDIF.

ENDFORM.

FORM perform_auto_pick_delivery
  USING    iv_vbeln_dlv TYPE likp-vbeln
  CHANGING cs_header    TYPE ty_mu_header_ext.

  DATA: lt_lips TYPE TABLE OF lips,
        ls_lips TYPE lips.
  DATA: lt_vbpok TYPE TABLE OF vbpok,
        ls_vbpok TYPE vbpok,
        ls_vbkok TYPE vbkok.
  DATA: lv_error_msg TYPE string.

  " 1. Đọc Delivery Items (LIPS)
  " (Cần đọc lại từ DB vì WS_DELIVERY_UPDATE cần đúng item của Delivery)
  SELECT * INTO TABLE lt_lips
    FROM lips
    WHERE vbeln = iv_vbeln_dlv.

  IF lt_lips IS INITIAL.
    cs_header-message = |{ cs_header-message } (⚠️ Pick failed: Delivery items not found in DB)|.
    RETURN.
  ENDIF.

  " 2. Xây dựng bảng VBPOK (Set Picked Qty = Delivery Qty)
  CLEAR lt_vbpok.
  LOOP AT lt_lips INTO ls_lips.
    CLEAR ls_vbpok.
    " Key
    ls_vbpok-vbeln_vl = ls_lips-vbeln.    " Delivery number
    ls_vbpok-posnr_vl = ls_lips-posnr.    " Delivery item

    " Reference (QUAN TRỌNG)
    ls_vbpok-vbeln    = ls_lips-vgbel.    " SO number
    ls_vbpok-posnn    = ls_lips-vgpos.    " SO item

    " Quantity (Copy LFIMG -> PIKMG)
    ls_vbpok-lfimg    = ls_lips-lfimg.    " Delivery Qty
    ls_vbpok-pikmg    = ls_lips-lfimg.    " Picked Qty = Delivery Qty
    ls_vbpok-meins    = ls_lips-meins.    " UoM
    ls_vbpok-kzpod    = 'X'.              " Confirmation flag

    APPEND ls_vbpok TO lt_vbpok.
  ENDLOOP.

  " 3. Header VBKOK
  CLEAR ls_vbkok.
  ls_vbkok-vbeln_vl = iv_vbeln_dlv.

  " 4. Gọi Function Module (WS_DELIVERY_UPDATE)
  " (Lưu ý: Tui set commit = 'X' để nó lưu luôn việc Pick)
  CALL FUNCTION 'WS_DELIVERY_UPDATE'
    EXPORTING
      vbkok_wa       = ls_vbkok
      delivery       = iv_vbeln_dlv
      update_picking = 'X'
      synchron       = 'X'
      commit         = 'X'
    TABLES
      vbpok_tab      = lt_vbpok
    EXCEPTIONS
      error_message  = 1
      OTHERS         = 2.

  " 5. Xử lý kết quả
  IF sy-subrc = 0.
    " Thành công: Nối thêm thông báo
    cs_header-message = |{ cs_header-message } ✅ Picked.|.
    " (Có thể update status riêng nếu muốn, ví dụ 'Picked')
  ELSE.
    " Thất bại: Lấy message lỗi hệ thống
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            INTO lv_error_msg.
    cs_header-message = |{ cs_header-message } ⚠️ Pick Error: { lv_error_msg }.|.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SHOW_CONTEXT_ERROR_LOG
*&---------------------------------------------------------------------*
* Form này được gọi từ MODULE user_command_0211 và 0212
*----------------------------------------------------------------------*
FORM show_context_error_log USING iv_req_id  TYPE zsd_req_id
                                  iv_temp_id TYPE ztb_so_upload_hd-temp_id
                                  iv_item_no TYPE ztb_so_upload_it-item_no.

  " Gọi thẳng vào Form chi tiết của bạn để hiện Popup màu mè
  PERFORM show_error_details_popup
    USING iv_req_id
          iv_temp_id
          iv_item_no.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SHOW_ERROR_DETAILS_POPUP
*&---------------------------------------------------------------------*
FORM show_error_details_popup
  USING VALUE(iv_req_id)  TYPE zsd_req_id
        VALUE(iv_temp_id) TYPE ztb_so_upload_it-temp_id
        VALUE(iv_item_no) TYPE ztb_so_upload_it-item_no.

  " 1. Định nghĩa cấu trúc hiển thị (Bao gồm bảng màu)
  TYPES: BEGIN OF ty_error_pop.
           INCLUDE TYPE ztb_so_error_log.
  TYPES:   row_color TYPE lvc_t_scol, " Bảng chứa thông tin màu sắc
         END OF ty_error_pop.

  DATA: lt_display TYPE TABLE OF ty_error_pop,
        ls_display TYPE ty_error_pop.
  DATA: lt_logs    TYPE TABLE OF ztb_so_error_log.

  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_column  TYPE REF TO cl_salv_column_table.

  DATA: ls_color   TYPE lvc_s_scol.
  DATA: lv_title   TYPE lvc_title.

  " 2. Lấy dữ liệu từ bảng Log
  " Logic:
  " - Nếu iv_item_no = '000000' (Header) -> Lấy các lỗi chung của Header này
  " - Nếu iv_item_no <> '000000' (Item)  -> Lấy lỗi của chính Item đó

  IF iv_item_no IS INITIAL OR iv_item_no = '000000'.
    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
      WHERE req_id  = iv_req_id
        AND temp_id = iv_temp_id
        AND status  = 'UNFIXED'
        AND ( item_no = '000000' OR item_no = '' ). " Chỉ lấy lỗi Header
  ELSE.
    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
      WHERE req_id  = iv_req_id
        AND temp_id = iv_temp_id
        AND item_no = iv_item_no " Chỉ lấy lỗi của Item/Condition này
        AND status  = 'UNFIXED'.
  ENDIF.

  IF lt_logs IS INITIAL.
    MESSAGE 'No error details found.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 3. Xử lý Tô màu (Loop để map dữ liệu và gán màu)
  LOOP AT lt_logs INTO DATA(ls_log).
    CLEAR ls_display.
    MOVE-CORRESPONDING ls_log TO ls_display.

    " Cấu hình màu sắc dựa trên Loại Lỗi (Msg Type)
    CLEAR ls_color.
    CASE ls_log-msg_type.
      WHEN 'E' OR 'A' OR 'X'.
        ls_color-color-col = 6. " Đỏ (Red)
        ls_color-color-int = 0. " 0: Nhạt, 1: Đậm
      WHEN 'W'.
        ls_color-color-col = 3. " Vàng (Yellow)
        ls_color-color-int = 0.
      WHEN 'S'.
        ls_color-color-col = 5. " Xanh lá (Green)
        ls_color-color-int = 0.
    ENDCASE.

    " Nếu có màu thì append vào bảng màu của dòng
    IF ls_color-color-col IS NOT INITIAL.
      APPEND ls_color TO ls_display-row_color.
    ENDIF.

    APPEND ls_display TO lt_display.
  ENDLOOP.

  SORT lt_display BY req_id temp_id item_no.

  " 4. Hiển thị SALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_display ).

      " A. Cấu hình Popup (Kích thước cửa sổ)
      lo_alv->set_screen_popup(
        start_column = 10  end_column = 100
        start_line   = 5   end_line   = 20 ).

      " B. Cấu hình Cột
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " [QUAN TRỌNG] Đăng ký cột nào chứa thông tin màu sắc
      lo_columns->set_color_column( 'ROW_COLOR' ).

      " C. Ẩn các cột kỹ thuật không cần thiết
      " Dùng TRY-CATCH để tránh Dump nếu cột không tồn tại
      TRY. lo_columns->get_column( 'MANDT' )->set_visible( abap_false ).     CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'REQ_ID' )->set_visible( abap_false ).    CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'ROW_COLOR' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'LOG_USER' )->set_visible( abap_false ).  CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'LOG_DATE' )->set_visible( abap_false ).  CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'LOG_TIME' )->set_visible( abap_false ).  CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'STATUS' )->set_visible( abap_false ).    CATCH cx_root. ENDTRY.

      " D. Đổi tên cột cho dễ hiểu
      TRY.
          lo_column ?= lo_columns->get_column( 'TEMP_ID' ).
          lo_column->set_long_text( 'Order Ref' ).
        CATCH cx_root.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'FIELDNAME' ).
          lo_column->set_long_text( 'Field' ).
          lo_column->set_medium_text( 'Field' ).
          lo_column->set_short_text( 'Field' ).
        CATCH cx_root.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MESSAGE' ).
          lo_column->set_long_text( 'Message Description' ).
        CATCH cx_root.
      ENDTRY.

      " E. Set Tiêu đề Popup
      IF iv_item_no = '000000' OR iv_item_no IS INITIAL.
        lv_title = |Error Logs: Header { iv_temp_id }|.
      ELSE.
        lv_title = |Error Logs: Item { iv_item_no } (Ref: { iv_temp_id })|.
      ENDIF.
      lo_alv->get_display_settings( )->set_list_header( lv_title ).

      " F. Hiển thị
      lo_alv->display( ).

    CATCH cx_salv_error INTO DATA(lx_error).
      MESSAGE lx_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.
