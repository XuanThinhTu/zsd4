*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_F03
*&---------------------------------------------------------------------*
FORM load_tracking_data.

  CALL FUNCTION 'BUFFER_REFRESH_ALL'.

  CLEAR gt_tracking.
  PERFORM normalize_search_inputs.

  DATA: lr_so_range TYPE RANGE OF vbak-vbeln,
        ls_so_range LIKE LINE OF lr_so_range.
  DATA: lv_search_active TYPE abap_bool.

  " A. Nếu user nhập Sales Order
  IF gv_vbeln IS NOT INITIAL.
    ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = gv_vbeln.
    APPEND ls_so_range TO lr_so_range.
    lv_search_active = abap_true.
  ENDIF.

  IF gv_deliv IS NOT INITIAL.
    lv_search_active = abap_true.
    SELECT vgbel
      FROM lips
      WHERE vbeln = @gv_deliv
      ORDER BY posnr ASCENDING
      INTO @ls_so_range-low
      UP TO 1 ROWS.
    ENDSELECT.

    IF sy-subrc = 0.
      ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'.
      APPEND ls_so_range TO lr_so_range.
    ENDIF.
  ENDIF.

  IF gv_bill IS NOT INITIAL.
    lv_search_active = abap_true.
    DATA: lv_pre_doc TYPE vbeln_von,
          lv_cat     TYPE vbtyp.

    SELECT vgbel, vgtyp
          FROM vbrp
          WHERE vbeln = @gv_bill
          ORDER BY posnr ASCENDING  " Lấy item đầu tiên để tìm ngược về
          INTO (@lv_pre_doc, @lv_cat)
          UP TO 1 ROWS.
    ENDSELECT.

    IF sy-subrc = 0.
      " Trường hợp 1: Billing được tạo từ Sales Order (VD: Order-related billing)
      IF lv_cat = 'C'.
        ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = lv_pre_doc.
        APPEND ls_so_range TO lr_so_range.

      ELSEIF lv_cat = 'J'.

        DATA: lv_so_from_del TYPE vbeln_von.
        SELECT vgbel
          FROM lips
          WHERE vbeln = @lv_pre_doc
          ORDER BY posnr ASCENDING " Lấy item đầu tiên để đảm bảo tính duy nhất
          INTO @lv_so_from_del
          UP TO 1 ROWS.
        ENDSELECT.
        IF sy-subrc = 0.
          ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = lv_so_from_del.
          APPEND ls_so_range TO lr_so_range.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.


  " Nếu có nhập Search (SO/Del/Bill) mà tìm không ra -> Gán số ảo để List rỗng
  IF lv_search_active = abap_true AND lr_so_range IS INITIAL.
    ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = '0000000000'.
    APPEND ls_so_range TO lr_so_range.
  ENDIF.

  DATA: lr_vkorg_project TYPE RANGE OF vkorg.
  lr_vkorg_project = VALUE #( sign = 'I' option = 'EQ' ( low = 'CNSG' ) ( low = 'CNHN' ) ( low = 'CNDN' ) ).

  CONDENSE: gv_vkorg, gv_vtweg, gv_spart, gv_ernam.
  TRANSLATE: gv_vkorg TO UPPER CASE, gv_vtweg TO UPPER CASE,
             gv_spart TO UPPER CASE, gv_ernam TO UPPER CASE.
  DATA(lv_vtweg_pattern) = |%{ gv_vtweg }|.
  DATA(lv_spart_pattern) = |%{ gv_spart }|.

  SELECT DISTINCT
         vbak~vbeln   AS sales_document,
         vbak~auart   AS order_type,
         vbak~erdat   AS document_date,
         vbak~erzet   AS creation_time,
         vbak~ernam   AS created_by,
         vbak~vkorg   AS sales_org,
         vbak~vtweg   AS distr_chan,
         vbak~spart   AS division,
         vbak~kunnr   AS sold_to_party,
         vbak~netwr   AS net_value,
         vbak~waerk   AS currency,
         vbep~edatu   AS req_delivery_date
    FROM vbak
    LEFT JOIN vbap ON vbap~vbeln = vbak~vbeln
    LEFT JOIN vbep ON vbep~vbeln = vbap~vbeln AND vbep~posnr = vbap~posnr
   WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
     AND vbak~vkorg IN @lr_vkorg_project
     AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
     AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
     AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
     AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
     AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
     AND vbak~vbeln IN @lr_so_range
    INTO CORRESPONDING FIELDS OF TABLE @gt_tracking.

*  SORT gt_tracking BY document_date DESCENDING sales_document DESCENDING.
  SORT gt_tracking BY document_date DESCENDING creation_time DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_tracking COMPARING sales_document.

  DATA: lt_tracking_final TYPE STANDARD TABLE OF ty_tracking,
        ls_row            TYPE ty_tracking,
        ls_vbfa_del       TYPE vbfa.

  CLEAR lt_tracking_final.

  LOOP AT gt_tracking INTO ls_row.
    " Clear sạch các biến output
    CLEAR: ls_row-delivery_document, ls_row-billing_document,
           ls_row-fi_doc_billing, ls_row-bill_doc_cancel,
           ls_row-fi_doc_cancel, ls_row-release_flag.

    CASE ls_row-order_type.
      WHEN 'ZRAS'.
        DATA: lv_has_entry TYPE abap_bool.
        lv_has_entry = abap_false.

        TYPES: BEGIN OF ty_bill_sort,
                 vbeln TYPE vbeln_vf,
                 erdat TYPE erdat,
               END OF ty_bill_sort.

        DATA: lt_bill_sort TYPE STANDARD TABLE OF ty_bill_sort,
              ls_bill_sort TYPE ty_bill_sort.

        REFRESH lt_bill_sort.
        SELECT vbeln, erdat
          INTO CORRESPONDING FIELDS OF TABLE @lt_bill_sort
          FROM vbfa
          WHERE vbelv   = @ls_row-sales_document
            AND vbtyp_n IN ('M', 'O', 'P').

        SORT lt_bill_sort BY erdat ASCENDING vbeln ASCENDING.

        TYPES: BEGIN OF ty_plan_data,
                 afdat TYPE fplt-afdat, " Plan Date
                 nfdat TYPE fplt-nfdat, " Billing date
                 fksaf TYPE fplt-fksaf, " Billing status
                 faksp TYPE fplt-faksp, " Billing block
                 fpltr TYPE fplt-fpltr, " Item number
               END OF ty_plan_data.

        DATA: lt_fplt TYPE STANDARD TABLE OF ty_plan_data,
              ls_plan TYPE ty_plan_data.

        SELECT c~afdat, c~nfdat, c~fksaf, c~faksp, c~fpltr
          INTO CORRESPONDING FIELDS OF TABLE @lt_fplt
          FROM vbkd AS a
          INNER JOIN fpla AS b ON b~fplnr = a~fplnr
          INNER JOIN fplt AS c ON c~fplnr = b~fplnr
          WHERE a~vbeln = @ls_row-sales_document
            AND a~posnr = '000000'.

        IF sy-subrc = 0.
          SORT lt_fplt BY afdat fpltr.

          LOOP AT lt_fplt INTO ls_plan.
            CLEAR: ls_row-delivery_document, ls_row-billing_document,
                   ls_row-fi_doc_billing, ls_row-bill_doc_cancel,
                   ls_row-fi_doc_cancel, ls_row-release_flag.

            ls_row-req_delivery_date = ls_plan-afdat.

            READ TABLE lt_bill_sort INTO ls_bill_sort INDEX 1.
            IF sy-subrc = 0.
              ls_row-billing_document = ls_bill_sort-vbeln.

              IF ls_bill_sort-erdat <> ls_plan-afdat.
                ls_row-process_phase = |Billing Created ({ ls_bill_sort-erdat DATE = USER })|.
              ELSE.
                ls_row-process_phase = TEXT-006.
              ENDIF.

              ls_row-phase_icon = icon_wd_text_view.

              PERFORM get_fi_status CHANGING ls_row.

              DELETE lt_bill_sort INDEX 1.
            ELSE.
              " Không còn bill nào
              IF ls_plan-fksaf = 'C'.
                ls_row-process_phase = TEXT-030.
                ls_row-phase_icon    = icon_green_light.
              ELSEIF ls_plan-faksp IS NOT INITIAL.
                ls_row-process_phase = |Blocked Plan: { ls_plan-afdat DATE = USER }|.
                ls_row-phase_icon    = icon_red_light.
              ELSE.
                ls_row-process_phase = |Order created, ready billing: { ls_plan-afdat DATE = USER }|.
                ls_row-phase_icon    = icon_create.
              ENDIF.
            ENDIF.

            APPEND ls_row TO lt_tracking_final.
            lv_has_entry = abap_true.
          ENDLOOP.
        ENDIF.

        IF lv_has_entry = abap_false.
          ls_row-process_phase = TEXT-031.
          APPEND ls_row TO lt_tracking_final.
        ENDIF.

      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.
        CLEAR ls_vbfa_del.
        DATA(lv_vbtyp_target) = COND vbtyp( WHEN ls_row-order_type = 'ZRET' THEN 'T' ELSE 'J' ).
        SELECT vbeln, vbtyp_n
          FROM vbfa
          WHERE vbelv   = @ls_row-sales_document
            AND vbtyp_n = @lv_vbtyp_target
          ORDER BY vbeln ASCENDING
          INTO CORRESPONDING FIELDS OF @ls_vbfa_del
          UP TO 1 ROWS.
        ENDSELECT.
        IF sy-subrc = 0.
          ls_row-delivery_document = ls_vbfa_del-vbeln.
        ENDIF.

        IF ls_row-order_type = 'ZRET'.
          " ZRET: Tìm từ SO
          SELECT vbeln FROM vbfa INTO @ls_row-billing_document
            WHERE vbelv   = @ls_row-sales_document
              AND vbtyp_n IN ('M', 'O', 'P')
            ORDER BY vbeln DESCENDING.
            EXIT. " Chỉ lấy 1 dòng
          ENDSELECT.
        ELSE.
          " ZORR/ZFOC: Tìm từ Delivery
          IF ls_row-delivery_document IS NOT INITIAL.
            SELECT vbeln FROM vbfa INTO @ls_row-billing_document
              WHERE vbelv   = @ls_row-delivery_document
                AND vbtyp_n IN ('M', 'O', 'P')
              ORDER BY vbeln DESCENDING. " <--- Lấy số lớn nhất (Mới nhất)
              EXIT. " Chỉ lấy 1 dòng
            ENDSELECT.
          ENDIF.
        ENDIF.

        PERFORM get_fi_status CHANGING ls_row.
        APPEND ls_row TO lt_tracking_final.

      WHEN OTHERS.
        SELECT vbeln FROM vbfa INTO @ls_row-billing_document
          WHERE vbelv = @ls_row-sales_document
            AND vbtyp_n IN ('M', 'O', 'P')
          ORDER BY vbeln DESCENDING.
          EXIT.
        ENDSELECT.

        PERFORM get_fi_status CHANGING ls_row.
        APPEND ls_row TO lt_tracking_final.

    ENDCASE.
  ENDLOOP.

  gt_tracking = lt_tracking_final.
  PERFORM denormalize_search_inputs.
ENDFORM.

FORM get_fi_status CHANGING cs_row TYPE ty_tracking.

  IF cs_row-billing_document IS INITIAL.
    RETURN.
  ENDIF.

  DATA: lv_bill_doc_canc TYPE vbrk-vbeln.
  CLEAR: lv_bill_doc_canc.

  SELECT belnr
      FROM bkpf
      WHERE awtyp = 'VBRK'
        AND awkey = @cs_row-billing_document
      ORDER BY belnr ASCENDING  " <--- Quan trọng: Xác định dòng cần lấy
      INTO @cs_row-fi_doc_billing
      UP TO 1 ROWS.
  ENDSELECT.
  SELECT vbeln
      FROM vbfa
      WHERE vbelv   = @cs_row-billing_document
        AND vbtyp_v IN ('M', 'O', 'P')
        AND vbtyp_n = 'N'
      ORDER BY vbeln
      INTO @lv_bill_doc_canc
      UP TO 1 ROWS.
  ENDSELECT.
  IF sy-subrc = 0 AND lv_bill_doc_canc IS NOT INITIAL.
    cs_row-bill_doc_cancel = lv_bill_doc_canc.
    SELECT belnr
          FROM bkpf
          WHERE awtyp = 'VBRK'
            AND awkey = @lv_bill_doc_canc
          ORDER BY belnr ASCENDING
          INTO @cs_row-fi_doc_cancel
          UP TO 1 ROWS.
    ENDSELECT.
  ENDIF.

  IF cs_row-fi_doc_billing IS INITIAL.

    IF cs_row-order_type = 'ZFOC'.
      CLEAR cs_row-release_flag.
    ELSE.
      cs_row-release_flag = '@5C@'.
    ENDIF.

  ENDIF.

ENDFORM.

FORM apply_phase_logic.

  "--- 1. Khai báo (Giữ nguyên)
  TYPES: BEGIN OF ty_vbfa_link,
           vbelv   TYPE vbfa-vbelv,
           vbeln   TYPE vbfa-vbeln,
           vbtyp_n TYPE vbfa-vbtyp_n,
         END OF ty_vbfa_link.

  DATA: lt_delv TYPE TABLE OF ty_vbfa_link,
        ls_delv TYPE ty_vbfa_link,
        lt_bil  TYPE TABLE OF ty_vbfa_link,
        ls_bil  TYPE ty_vbfa_link.

  DATA: lv_wbstk TYPE likp-wbstk. " Biến check status kho

  FIELD-SYMBOLS: <fs_phase> TYPE ty_tracking.

  LOOP AT gt_tracking ASSIGNING <fs_phase>.

    CLEAR: <fs_phase>-phase_icon.

    CASE <fs_phase>-order_type.
      WHEN 'ZRAS'.

        " Check Billing trước
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

          IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
            <fs_phase>-process_phase = TEXT-007.
            <fs_phase>-phase_icon    = icon_payment.
          ELSE.
            <fs_phase>-process_phase = TEXT-006.
            <fs_phase>-phase_icon    = icon_wd_text_view.
          ENDIF.

        ELSE.
          " Nếu chưa có Billing -> Giữ nguyên logic Plan cũ
          IF <fs_phase>-process_phase IS INITIAL.
            <fs_phase>-process_phase = TEXT-031.
          ENDIF.

          " Gán icon cho ZRAS
          IF <fs_phase>-phase_icon IS INITIAL.
            IF <fs_phase>-process_phase CP TEXT-012.
              <fs_phase>-phase_icon = icon_green_light.
            ELSEIF <fs_phase>-process_phase CP TEXT-033.
              <fs_phase>-phase_icon = icon_red_light.
            ELSE.
              <fs_phase>-phase_icon = icon_create.
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        CLEAR <fs_phase>-process_phase.

        " 1. Check Billing trước
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

          " === Logic ZFOC ===
          IF <fs_phase>-order_type = 'ZFOC'.
            <fs_phase>-process_phase = TEXT-032.
            <fs_phase>-phase_icon    = icon_green_light.
          ELSE.
            " Các loại khác: Phải có FI mới Xanh
            IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
              <fs_phase>-process_phase = TEXT-007.
              <fs_phase>-phase_icon    = icon_payment.
            ELSE.
              <fs_phase>-process_phase = TEXT-006.
              <fs_phase>-phase_icon    = icon_wd_text_view.
            ENDIF.
          ENDIF.

        ELSE.
          " 2. Nếu chưa có Bill -> Check Delivery
          IF <fs_phase>-delivery_document IS NOT INITIAL.

            CLEAR lv_wbstk.
            SELECT SINGLE wbstk FROM likp INTO lv_wbstk
              WHERE vbeln = <fs_phase>-delivery_document.

            " --- Đã Post kho (PGI/PGR Xong) ---
            IF lv_wbstk = 'C'.
              <fs_phase>-process_phase = TEXT-005.
              <fs_phase>-phase_icon    = icon_wd_text_view.

              " --- Chưa Post kho (Chờ PGI/PGR) ---
            ELSE.
              <fs_phase>-process_phase = TEXT-008.
              <fs_phase>-phase_icon    = icon_delivery.
            ENDIF.

          ELSE.
            " 3. Chưa có Delivery -> Trạng thái: Order created
            <fs_phase>-process_phase = TEXT-003.
            <fs_phase>-phase_icon    = icon_order.
          ENDIF.
        ENDIF.

      WHEN OTHERS.

        CLEAR <fs_phase>-process_phase.

        " Nhóm này không quan tâm Delivery, check thẳng Billing
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

          IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
            <fs_phase>-process_phase = TEXT-007.
            <fs_phase>-phase_icon    = icon_payment.
          ELSE.
            <fs_phase>-process_phase = TEXT-006.
            <fs_phase>-phase_icon    = icon_wd_text_view.
          ENDIF.

        ELSE.
          <fs_phase>-process_phase = TEXT-003.
          <fs_phase>-phase_icon    = icon_order.
        ENDIF.

    ENDCASE.

  ENDLOOP.

ENDFORM.


FORM filter_process_phase.

  IF cb_phase IS INITIAL OR cb_phase = 'ALL' OR gt_tracking IS INITIAL.
*    EXIT.
  ENDIF.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
  CLEAR lt_keep.

  LOOP AT gt_tracking INTO gs_tracking.

    CASE cb_phase.
      WHEN 'ORD'.
        IF gs_tracking-process_phase = TEXT-003.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN 'DEL'.
        IF gs_tracking-process_phase CP TEXT-008.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN 'INV'.
        IF gs_tracking-process_phase CP 'PGI/PGR Posted*'. " (Hoặc CP 'PGI*' OR CP 'PGR*')
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN 'BIL'.
        IF gs_tracking-process_phase CP 'Billing*'.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN 'ACC'.
        IF gs_tracking-process_phase = 'FI Doc created'.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN OTHERS.
        APPEND gs_tracking TO lt_keep.
    ENDCASE.

  ENDLOOP.

  gt_tracking = lt_keep.

ENDFORM.
FORM filter_tracking_data.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.

  TYPES: BEGIN OF ty_vbeln,
           vbeln TYPE vbak-vbeln,
         END OF ty_vbeln.

  DATA: lv_vtweg_pattern TYPE string,
        lv_spart_pattern TYPE string.

  IF cb_sosta IS INITIAL OR cb_sosta = 'ALL' OR gt_tracking IS INITIAL.
    EXIT.
  ENDIF.

  CLEAR lt_keep.
  lv_vtweg_pattern = |%{ gv_vtweg }|.
  lv_spart_pattern = |%{ gv_spart }|.


  CASE cb_sosta.

      "--- INC (Giữ nguyên) ---
    WHEN 'INC'.
      DATA: lt_incomplete TYPE STANDARD TABLE OF vbak-vbeln.
      SELECT vbak~vbeln
        FROM vbak
        WHERE
           ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
       AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
       AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
       AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
       AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
       AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
       AND vbak~netwr = 0 "Giá tri don hàng = 0
       AND ( vbak~uvall = 'A' OR vbak~uvall = 'B' OR vbak~uvall = ' ' )
        INTO TABLE @lt_incomplete.

      IF sy-subrc = 0 AND lt_incomplete IS NOT INITIAL.
        SORT lt_incomplete.
        DELETE ADJACENT DUPLICATES FROM lt_incomplete.
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_inc) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_incomplete
               WITH KEY table_line = lv_vbeln_inc
               BINARY SEARCH TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.


    WHEN 'COM'.
      DATA: lt_complete TYPE STANDARD TABLE OF vbak-vbeln.

      " 1. Lấy danh sách SO hợp lệ (UVALL = 'C') từ DB
      SELECT DISTINCT vbak~vbeln
        FROM vbak
        INNER JOIN vbap ON vbap~vbeln = vbak~vbeln
        WHERE
           ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
       AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
       AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
       AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
       AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
       AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
       AND vbak~uvall = 'C'  " Chỉ lấy đơn Không có log chưa hoàn thiện
        INTO TABLE @lt_complete.

      IF sy-subrc = 0.
        SORT lt_complete.

        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_cmp) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_complete WITH KEY table_line = lv_vbeln_cmp
                             BINARY SEARCH TRANSPORTING NO FIELDS.

          IF sy-subrc = 0.
            IF gs_tracking-delivery_document IS INITIAL
               AND gs_tracking-billing_document IS INITIAL.

              APPEND gs_tracking TO lt_keep.

            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDIF.
    WHEN 'BLK'.
      DATA: lt_billing_block TYPE STANDARD TABLE OF vbak-vbeln.
      SELECT vbak~vbeln
        FROM vbak
        WHERE
           ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
       AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
       AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
       AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
       AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
       AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
       AND vbak~faksk IS NOT INITIAL
        INTO TABLE @lt_billing_block.

      SELECT DISTINCT vbak~vbeln
        FROM vbak
        INNER JOIN vbap ON vbap~vbeln = vbak~vbeln
        WHERE
           ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
       AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
       AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
       AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
       AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
       AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
       AND vbap~faksp IS NOT INITIAL
        APPENDING TABLE @lt_billing_block.

      IF lt_billing_block IS NOT INITIAL.
        SORT lt_billing_block.
        DELETE ADJACENT DUPLICATES FROM lt_billing_block.
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_blk) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_billing_block
               WITH KEY table_line = lv_vbeln_blk
               BINARY SEARCH TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.
    WHEN 'REJ'.
      DATA: lt_reject_so TYPE STANDARD TABLE OF vbak-vbeln.

      " 1. Lấy SO bị reject ở Header (VBAK-ABSTK)
      SELECT vbak~vbeln
        FROM vbak
        WHERE
           ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
       AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
       AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
       AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
       AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
       AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
       AND vbak~abstk IS NOT INITIAL " <== CHỈ KIỂM TRA VBAK
        INTO TABLE @lt_reject_so.

      " 2. So khớp với ALV
      IF lt_reject_so IS NOT INITIAL.
        SORT lt_reject_so.
        DELETE ADJACENT DUPLICATES FROM lt_reject_so.
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_rej) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_reject_so
               WITH KEY table_line = lv_vbeln_rej
               BINARY SEARCH TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.

  ENDCASE.

  " Gán kết quả lọc vào bảng ALV
  gt_tracking = lt_keep.
ENDFORM.

FORM filter_delivery_status.
  " 1. Nếu không lọc (chọn 'All') hoặc bảng ALV rỗng thì thoát
  IF cb_ddsta IS INITIAL OR cb_ddsta = 'ALL' OR gt_tracking IS INITIAL.
    EXIT.
  ENDIF.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
  CLEAR lt_keep.

  " 2. Lấy các biến pattern cho search
  DATA: lv_vtweg_pattern TYPE string,
        lv_spart_pattern TYPE string.
  lv_vtweg_pattern = |%{ gv_vtweg }|.
  lv_spart_pattern = |%{ gv_spart }|.

  CASE cb_ddsta.
      " =========================================================
      " [MỚI]: DELIVERY CREATED, READY PGI (Chưa Post kho)
      " =========================================================
    WHEN 'READY'.
      DATA: lt_gm_ready TYPE HASHED TABLE OF vbak-vbeln
                         WITH UNIQUE KEY table_line.

      " Logic: Tìm Delivery (J/T) mà WBSTK KHÁC 'C'
      SELECT DISTINCT vbak~vbeln
       FROM vbak
       INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
       INNER JOIN likp ON likp~vbeln = vbfa~vbeln
       WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa~vbtyp_n IN ('J', 'T')   " Delivery hoặc Return Delivery
         AND likp~wbstk   <> 'C'          " <--- KHÁC C (Chưa xong)
         INTO TABLE @lt_gm_ready.

      IF sy-subrc = 0.
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_ready) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_gm_ready WITH TABLE KEY table_line = lv_vbeln_ready TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.
      " =========================================================
      " LOGIC GỘP: GI/GR POSTED
      " =========================================================
    WHEN 'POST'.
      DATA: lt_gm_posted TYPE HASHED TABLE OF vbak-vbeln
                         WITH UNIQUE KEY table_line.

      " Logic: Tìm SO có Delivery (J hoặc T) mà trạng thái kho (WBSTK) là 'C' (Complete)
      SELECT DISTINCT vbak~vbeln
        FROM vbak
        INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
        INNER JOIN likp ON likp~vbeln = vbfa~vbeln
        WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
          AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
          AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
          AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
          AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
          AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
          AND vbfa~vbtyp_n IN ('J', 'T')   " J = Xuất hàng (GI), T = Trả hàng (GR)
          AND likp~wbstk   = 'C'           " Trạng thái Completed (Đã Post)
          INTO TABLE @lt_gm_posted.

      IF sy-subrc = 0.
        " Lọc lại bảng ALV dựa trên kết quả tìm được
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_gm) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_gm_posted WITH TABLE KEY table_line = lv_vbeln_gm TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.

  ENDCASE.

  " 3. Gán kết quả lọc vào bảng ALV
  gt_tracking = lt_keep.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FILTER_BILLING_STATUS
*&---------------------------------------------------------------------*
FORM filter_billing_status.

  " 1. Nếu không lọc (chọn 'All') hoặc bảng ALV rỗng thì thoát
  IF cb_bdsta IS INITIAL OR cb_bdsta = 'ALL' OR gt_tracking IS INITIAL.
    EXIT.
  ENDIF.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
  CLEAR lt_keep.

  " 2. Biến hỗ trợ tìm kiếm DB (cho CANC và OPEN)
  DATA: lv_vtweg_pattern TYPE string,
        lv_spart_pattern TYPE string.

  lv_vtweg_pattern = |%{ gv_vtweg }|.
  lv_spart_pattern = |%{ gv_spart }|.

  DATA: lt_canceled_so TYPE HASHED TABLE OF vbak-vbeln
                       WITH UNIQUE KEY table_line.
  DATA: lt_temp_so     TYPE STANDARD TABLE OF vbak-vbeln.

  IF cb_bdsta = 'CANC' OR cb_bdsta = 'OPEN'.

    CLEAR: lt_temp_so, lt_canceled_so.

    " Path 1: Lấy SO -> Delivery -> Billing (Đã Hủy)
    SELECT DISTINCT vbak~vbeln
      FROM vbak
      INNER JOIN vbfa AS vbfa_so  ON vbfa_so~vbelv  = vbak~vbeln
      INNER JOIN vbfa AS vbfa_del ON vbfa_del~vbelv = vbfa_so~vbeln
      INNER JOIN vbrk             ON vbrk~vbeln     = vbfa_del~vbeln
      WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
        AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
        AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
        AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
        AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
        AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
        AND vbfa_so~vbtyp_n  = 'J'    " Delivery
        AND vbfa_del~vbtyp_n = 'M'    " Billing
        AND vbrk~fksto       = 'X'    " Đã Hủy
      INTO TABLE @lt_temp_so.

    " Path 2: Lấy SO -> Billing (Đã Hủy - cho ZDR/ZCRR)
    SELECT DISTINCT vbak~vbeln
      FROM vbak
      INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
      INNER JOIN vbrk ON vbrk~vbeln = vbfa~vbeln
      WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
        AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
        AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
        AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
        AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
        AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
        AND vbfa~vbtyp_n = 'M'        " Billing
        AND vbrk~fksto   = 'X'        " Đã Hủy
      APPENDING TABLE @lt_temp_so.

    " Chuyển sang bảng Hashed để search nhanh
    IF lt_temp_so IS NOT INITIAL.
      SORT lt_temp_so.
      DELETE ADJACENT DUPLICATES FROM lt_temp_so.
      lt_canceled_so = lt_temp_so.
    ENDIF.

  ENDIF.
  LOOP AT gt_tracking INTO gs_tracking.

    CASE cb_bdsta.
      WHEN 'COMP'.
        IF gs_tracking-fi_doc_billing IS NOT INITIAL.
          APPEND gs_tracking TO lt_keep.
        ELSEIF gs_tracking-order_type = 'ZFOC' AND gs_tracking-billing_document IS NOT INITIAL.
          " [FIX]: ZFOC có Billing là tính Completed
          APPEND gs_tracking TO lt_keep.
        ENDIF.
      WHEN 'CANC'.
        DATA(lv_vbeln_canc) = |{ gs_tracking-sales_document ALPHA = IN }|.
        READ TABLE lt_canceled_so WITH TABLE KEY table_line = lv_vbeln_canc
                                  TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND gs_tracking TO lt_keep.
        ENDIF.
      WHEN 'OPEN'.
        DATA(lv_vbeln_open) = |{ gs_tracking-sales_document ALPHA = IN }|.
        READ TABLE lt_canceled_so WITH TABLE KEY table_line = lv_vbeln_open
                                  TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          IF gs_tracking-billing_document IS NOT INITIAL
             AND gs_tracking-fi_doc_billing IS INITIAL
             AND gs_tracking-order_type <> 'ZFOC'.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDIF.

    ENDCASE.
  ENDLOOP.
  gt_tracking = lt_keep.

ENDFORM.

FORM filter_pricing_procedure.

  IF cb_sosta = 'INC'.
    EXIT.
  ENDIF.

  CHECK gt_tracking IS NOT INITIAL.

  DATA: lt_filtered TYPE STANDARD TABLE OF ty_tracking.

  TYPES: BEGIN OF ty_tvak,
           auart TYPE tvak-auart,
           kalvg TYPE tvak-kalvg,
         END OF ty_tvak.
  DATA: lt_tvak TYPE HASHED TABLE OF ty_tvak WITH UNIQUE KEY auart.
  SELECT auart, kalvg
    FROM tvak
    FOR ALL ENTRIES IN @gt_tracking
    WHERE auart = @gt_tracking-order_type
    INTO TABLE @lt_tvak.
  TYPES: BEGIN OF ty_knvv,
           kunnr TYPE knvv-kunnr,
           vkorg TYPE knvv-vkorg,
           vtweg TYPE knvv-vtweg,
           spart TYPE knvv-spart,
           kalks TYPE knvv-kalks,
         END OF ty_knvv.
  DATA: lt_knvv TYPE HASHED TABLE OF ty_knvv
    WITH UNIQUE KEY kunnr vkorg vtweg spart.
  SELECT kunnr, vkorg, vtweg, spart, kalks
    FROM knvv
    FOR ALL ENTRIES IN @gt_tracking
    WHERE kunnr = @gt_tracking-sold_to_party
      AND vkorg = @gt_tracking-sales_org
      AND vtweg = @gt_tracking-distr_chan
      AND spart = @gt_tracking-division
    INTO TABLE @lt_knvv.

  TYPES: BEGIN OF ty_t683v,
           vkorg TYPE t683v-vkorg,
           vtweg TYPE t683v-vtweg,
           spart TYPE t683v-spart,
           kalvg TYPE t683v-kalvg,
           kalks TYPE t683v-kalks,
           kalsm TYPE t683v-kalsm,
         END OF ty_t683v.
  DATA: lt_t683v TYPE HASHED TABLE OF ty_t683v
    WITH UNIQUE KEY vkorg vtweg spart kalvg kalks.

  IF lt_knvv IS NOT INITIAL AND lt_tvak IS NOT INITIAL.
    DATA: lt_kalvg TYPE RANGE OF t683v-kalvg.
    LOOP AT lt_tvak INTO DATA(ls_tvak_filter).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_tvak_filter-kalvg ) TO lt_kalvg.
    ENDLOOP.
    SORT lt_kalvg.
    DELETE ADJACENT DUPLICATES FROM lt_kalvg.

    IF lt_kalvg IS NOT INITIAL.
      SELECT vkorg, vtweg, spart, kalvg, kalks, kalsm
        FROM t683v
        FOR ALL ENTRIES IN @lt_knvv
        WHERE vkorg = @lt_knvv-vkorg
          AND vtweg = @lt_knvv-vtweg
          AND spart = @lt_knvv-spart
          AND kalks = @lt_knvv-kalks
          AND kalvg IN @lt_kalvg
        INTO TABLE @lt_t683v.
    ENDIF.
  ENDIF.

  " 4. LOOP tại bộ nhớ (rất nhanh)
  LOOP AT gt_tracking INTO gs_tracking.
    READ TABLE lt_tvak WITH TABLE KEY auart = gs_tracking-order_type
      INTO DATA(ls_tvak).
    IF sy-subrc <> 0. CONTINUE. ENDIF.

    READ TABLE lt_knvv WITH TABLE KEY
      kunnr = gs_tracking-sold_to_party
      vkorg = gs_tracking-sales_org
      vtweg = gs_tracking-distr_chan
      spart = gs_tracking-division
      INTO DATA(ls_knvv).
    IF sy-subrc <> 0. CONTINUE. ENDIF.

    READ TABLE lt_t683v WITH TABLE KEY
      vkorg = gs_tracking-sales_org
      vtweg = gs_tracking-distr_chan
      spart = gs_tracking-division
      kalvg = ls_tvak-kalvg
      kalks = ls_knvv-kalks
      TRANSPORTING NO FIELDS.

    IF sy-subrc = 0.
      APPEND gs_tracking TO lt_filtered.
    ENDIF.
  ENDLOOP.
  gt_tracking = lt_filtered.
ENDFORM.
FORM normalize_search_inputs.

  IF gv_sarea IS NOT INITIAL.

    REPLACE ALL OCCURRENCES OF '/' IN gv_sarea WITH space.
    REPLACE ALL OCCURRENCES OF '-' IN gv_sarea WITH space.

    SPLIT gv_sarea AT space INTO gv_vkorg gv_vtweg gv_spart.

    CONDENSE: gv_vkorg, gv_vtweg, gv_spart.
  ENDIF.


  IF gv_kunnr IS NOT INITIAL.
    SHIFT gv_kunnr LEFT DELETING LEADING '0'.
  ENDIF.


  IF gv_vbeln IS NOT INITIAL.
    SHIFT gv_vbeln LEFT DELETING LEADING '0'.
  ENDIF.


  IF gv_deliv IS NOT INITIAL.
    SHIFT gv_deliv LEFT DELETING LEADING '0'.
  ENDIF.

  IF gv_bill IS NOT INITIAL.
    SHIFT gv_bill LEFT DELETING LEADING '0'.
  ENDIF.

  IF gv_kunnr IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_kunnr
      IMPORTING
        output = gv_kunnr.
  ENDIF.

  "👉 Chuẩn hóa Sales Doc (Giữ nguyên code cũ)
  IF gv_vbeln IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_vbeln
      IMPORTING
        output = gv_vbeln.
  ENDIF.

  IF gv_deliv IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_deliv
      IMPORTING
        output = gv_deliv.
  ENDIF.

  IF gv_bill IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_bill
      IMPORTING
        output = gv_bill.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DENORMALIZE_SEARCH_INPUTS
*&---------------------------------------------------------------------*
FORM denormalize_search_inputs.

  " 1. Sales Document
  IF gv_vbeln IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = gv_vbeln
      IMPORTING
        output = gv_vbeln.
  ENDIF.

  " 2. Delivery Document
  IF gv_deliv IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = gv_deliv
      IMPORTING
        output = gv_deliv.
  ENDIF.

  " 3. Billing Document
  IF gv_bill IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = gv_bill
      IMPORTING
        output = gv_bill.
  ENDIF.

  " 4. Sold-to Party (Nếu muốn xóa cả số 0 của khách hàng)
  IF gv_kunnr IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = gv_kunnr
      IMPORTING
        output = gv_kunnr.
  ENDIF.

ENDFORM.

FORM filter_by_search.

  DATA lt_filtered TYPE STANDARD TABLE OF ty_tracking.

  PERFORM normalize_search_inputs.

  LOOP AT gt_tracking INTO gs_tracking.

    "1️.Document Date (chỉ 1 field)
    IF gv_doc_date IS NOT INITIAL AND gs_tracking-document_date <> gv_doc_date.
      CONTINUE.
    ENDIF.

    "2️.Sold-to Party
    IF gv_kunnr IS NOT INITIAL AND gs_tracking-sold_to_party <> gv_kunnr.
      CONTINUE.
    ENDIF.

    "3️.Created By
    IF gv_ernam IS NOT INITIAL AND gs_tracking-created_by <> gv_ernam.
      CONTINUE.
    ENDIF.

    "4️.Sales Org / Distr. Channel / Division
    IF gv_vkorg IS NOT INITIAL AND gs_tracking-sales_org  <> gv_vkorg.  CONTINUE. ENDIF.
    IF gv_vtweg IS NOT INITIAL AND gs_tracking-distr_chan <> gv_vtweg.  CONTINUE. ENDIF.
    IF gv_spart IS NOT INITIAL AND gs_tracking-division  <> gv_spart.   CONTINUE. ENDIF.

    "👉 Nếu qua hết điều kiện => giữ lại
    APPEND gs_tracking TO lt_filtered.

  ENDLOOP.

  gt_tracking = lt_filtered.
  CALL METHOD go_alv->refresh_table_display( ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_POST_GOODS_ISSUE
*&---------------------------------------------------------------------*
FORM process_post_goods_issue
  USING    is_tracking_line TYPE ty_tracking
  CHANGING cs_tracking_line TYPE ty_tracking.

  " --- Data Declaration ---
  DATA: ls_vbkok        TYPE vbkok,
        lt_vbpok        TYPE TABLE OF vbpok,
        ls_vbpok        TYPE vbpok,
        lt_prot         TYPE TABLE OF prott,
        ls_prot         TYPE prott,
        lv_vbeln        TYPE likp-vbeln,
        lt_lips         TYPE TABLE OF lipsvb,
        lv_full_message TYPE string.

  " 1. Validation
  lv_vbeln = is_tracking_line-delivery_document.
  CLEAR cs_tracking_line-error_msg.

  IF lv_vbeln IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: No Delivery Document found.'.
    EXIT.
  ENDIF.
  SELECT vbeln, posnr, lfimg, lgmng
    FROM lips
    INTO CORRESPONDING FIELDS OF TABLE @lt_lips
    WHERE vbeln = @lv_vbeln.
  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = 'ERROR: Delivery items (LIPS) not found.'.
    EXIT.
  ENDIF.


  ls_vbkok-vbeln_vl  = lv_vbeln.
  ls_vbkok-wabuc     = 'X'.        " Post Goods Issue
  ls_vbkok-wadat_ist = sy-datum.   " Actual GI Date


  LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_lips>).
    CLEAR ls_vbpok.
    ls_vbpok-vbeln_vl = <fs_lips>-vbeln.
    ls_vbpok-posnr_vl = <fs_lips>-posnr.
    ls_vbpok-lfimg    = <fs_lips>-lfimg. " Quantity
    ls_vbpok-lgmng    = <fs_lips>-lgmng. " Quantity Base
    APPEND ls_vbpok TO lt_vbpok.
  ENDLOOP.

  CALL FUNCTION 'WS_DELIVERY_UPDATE_2'
    EXPORTING
      vbkok_wa  = ls_vbkok
      synchron  = 'X'     " Synchronous update (Quan trọng cho Mass)
      commit    = ' '     " Không commit trong FM
      delivery  = lv_vbeln
    TABLES
      vbpok_tab = lt_vbpok
      prot      = lt_prot
    EXCEPTIONS
      OTHERS    = 1.


  IF sy-subrc <> 0.
    " Technical Error
    cs_tracking_line-error_msg = 'ERROR: WS_DELIVERY_UPDATE_2 failed (Exception).'.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    EXIT.
  ENDIF.

  " Check Business Error in PROT table (Quan trọng!)
  READ TABLE lt_prot INTO ls_prot WITH KEY msgty = 'E'.
  IF sy-subrc <> 0.
    READ TABLE lt_prot INTO ls_prot WITH KEY msgty = 'A'.
  ENDIF.

  IF sy-subrc = 0.
    " --- FAILURE ---
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    MESSAGE ID ls_prot-msgid TYPE 'S' NUMBER ls_prot-msgno
            WITH ls_prot-msgv1 ls_prot-msgv2 ls_prot-msgv3 ls_prot-msgv4
            INTO lv_full_message.

    cs_tracking_line-error_msg = |ERROR: { lv_full_message }|.
  ELSE.
    " --- SUCCESS ---
    " Commit & Wait để đảm bảo DB update xong trước khi trả về UI
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.

    cs_tracking_line-error_msg = |Success: PGI Posted for { lv_vbeln }.|.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_CREATE_BILLING
*&---------------------------------------------------------------------*
FORM process_create_billing
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  " --- Data Declaration ---
  DATA: lt_billingdata TYPE TABLE OF bapivbrk,
        ls_billingdata TYPE bapivbrk,
        lt_return      TYPE TABLE OF bapiret2,
        ls_return      TYPE bapiret2,
        lt_success     TYPE TABLE OF bapivbrksuccess,
        ls_success     TYPE bapivbrksuccess,
        lv_billdoc     TYPE vbrk-vbeln.

  DATA: lt_lips             TYPE STANDARD TABLE OF lips.
  DATA: lt_vbap             TYPE TABLE OF vbap.
  DATA: lv_vbeln_vl         TYPE vbeln_vl.
  DATA: lv_wbstk            TYPE likp-wbstk.

  " Config Variables
  DATA: lv_target_bill_type TYPE fkart.
  DATA: lv_error_found      TYPE abap_bool.
  CLEAR cs_tracking_line-error_msg.

  CLEAR: cs_tracking_line-billing_document,
         cs_tracking_line-bill_doc_cancel,
         cs_tracking_line-fi_doc_billing,
         cs_tracking_line-fi_doc_cancel.

  CASE is_tracking_line-order_type.
    WHEN 'ZORR' OR 'ZTP' OR 'ZSC' OR 'ZRAS' OR 'ZFOC'.
      lv_target_bill_type = 'ZFF'.
    WHEN 'ZRET'.
      lv_target_bill_type = 'ZRE'.
    WHEN 'ZDR'.
      lv_target_bill_type = 'ZLL2'.
    WHEN 'ZCRR'.
      lv_target_bill_type = 'ZGG2'.
    WHEN OTHERS.
      cs_tracking_line-error_msg = |ERROR: Order type { is_tracking_line-order_type } not configured.|.
      EXIT.
  ENDCASE.

  CASE is_tracking_line-order_type.

    WHEN 'ZORR' OR 'ZFOC'.

      lv_vbeln_vl = is_tracking_line-delivery_document.
      IF lv_vbeln_vl IS INITIAL.
        cs_tracking_line-error_msg = 'ERROR: Delivery Document is required.'.
        EXIT.
      ENDIF.

      SELECT SINGLE wbstk FROM likp INTO lv_wbstk WHERE vbeln = lv_vbeln_vl.
      IF lv_wbstk <> 'C'.
        cs_tracking_line-error_msg = 'ERROR: PGI not completed (WBSTK <> C).'.
        EXIT.
      ENDIF.


      SELECT vbeln, posnr, matnr, lfimg, vrkme
        FROM lips
        INTO CORRESPONDING FIELDS OF TABLE @lt_lips
        WHERE vbeln = @lv_vbeln_vl.

      IF sy-subrc <> 0.
        cs_tracking_line-error_msg = 'ERROR: Delivery items not found.'.
        EXIT.
      ENDIF.

      LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_lips>).
        CLEAR ls_billingdata.
        ls_billingdata-ref_doc    = <fs_lips>-vbeln.
        ls_billingdata-ref_item   = <fs_lips>-posnr.
        ls_billingdata-doc_type   = is_tracking_line-order_type.
        ls_billingdata-ordbilltyp = lv_target_bill_type.
        ls_billingdata-ref_doc_ca = 'J'. " Ref to Delivery
        APPEND ls_billingdata TO lt_billingdata.
      ENDLOOP.

    WHEN 'ZTP' OR 'ZSC' OR 'ZRAS' OR 'ZDR' OR 'ZCRR' OR 'ZRET'.

      IF is_tracking_line-order_type = 'ZRET'.
        IF is_tracking_line-delivery_document IS INITIAL.
          cs_tracking_line-error_msg = 'ERROR ZRET: Returns Delivery missing.'.
          EXIT.
        ENDIF.

        SELECT SINGLE wbstk FROM likp INTO @lv_wbstk
           WHERE vbeln = @is_tracking_line-delivery_document.
        IF lv_wbstk <> 'C'.
          cs_tracking_line-error_msg = 'ERROR ZRET: PGR not posted.'.
          EXIT.
        ENDIF.
      ENDIF.

      SELECT vbeln, posnr, abgru, faksp, kwmeng, zmeng, vrkme
        FROM vbap
        INTO CORRESPONDING FIELDS OF TABLE @lt_vbap
        WHERE vbeln = @is_tracking_line-sales_document.
      IF sy-subrc <> 0.
        cs_tracking_line-error_msg = 'ERROR: Sales Order items not found.'.
        EXIT.
      ENDIF.

      LOOP AT lt_vbap ASSIGNING FIELD-SYMBOL(<fs_vbap>).
        " Check Reject
        IF <fs_vbap>-abgru IS NOT INITIAL. CONTINUE. ENDIF.
        " Check Billing Block
        IF <fs_vbap>-faksp IS NOT INITIAL. CONTINUE. ENDIF.

        " Quantity Logic
        DATA: lv_qty_bill TYPE vbap-kwmeng.
        lv_qty_bill = <fs_vbap>-kwmeng.
        IF lv_qty_bill <= 0.
          lv_qty_bill = <fs_vbap>-zmeng.
        ENDIF.

        " --- FILL DATA ---
        CLEAR ls_billingdata.
        ls_billingdata-ref_doc    = <fs_vbap>-vbeln.
        ls_billingdata-ref_item   = <fs_vbap>-posnr.
        ls_billingdata-doc_type   = is_tracking_line-order_type.
        ls_billingdata-ordbilltyp = lv_target_bill_type.
        ls_billingdata-ref_doc_ca = 'C'. " Ref to Order

        " ZRAS Milestone Logic
        IF is_tracking_line-order_type = 'ZRAS'.
          CLEAR: ls_billingdata-req_qty, ls_billingdata-sales_unit.
          ls_billingdata-bill_date  = is_tracking_line-req_delivery_date.
          ls_billingdata-price_date = is_tracking_line-req_delivery_date.
        ELSE.
          ls_billingdata-req_qty    = lv_qty_bill.
          ls_billingdata-sales_unit = <fs_vbap>-vrkme.
        ENDIF.

        APPEND ls_billingdata TO lt_billingdata.
      ENDLOOP.

      IF lt_billingdata IS INITIAL.
        cs_tracking_line-error_msg = 'ERROR: No valid items found (Check Rejection/Block).'.
        EXIT.
      ENDIF.

  ENDCASE.

  IF lt_billingdata IS NOT INITIAL.
    CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
      EXPORTING
        testrun       = abap_false
        posting       = abap_false
      TABLES
        billingdatain = lt_billingdata
        success       = lt_success
        return        = lt_return.
  ENDIF.

  READ TABLE lt_success INTO ls_success INDEX 1.

  IF sy-subrc = 0 AND ls_success-bill_doc IS NOT INITIAL.
    " --- SUCCESS ---
    lv_billdoc = ls_success-bill_doc.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.

    " 2. Thông báo thành công
    cs_tracking_line-billing_document = lv_billdoc.
    cs_tracking_line-error_msg = |Success: Created { lv_billdoc }.|.

  ELSE.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    CLEAR cs_tracking_line-billing_document. " Xóa nếu tạo thất bại

    " 1. Tìm lỗi cụ thể
    LOOP AT lt_return INTO ls_return WHERE type = 'E' OR type = 'A'.
      IF ls_return-id = 'VU'.
        cs_tracking_line-error_msg = |Data Incomplete: { ls_return-message }|.
      ELSE.
        cs_tracking_line-error_msg = |ERROR: { ls_return-message }|.
      ENDIF.
      EXIT.
    ENDLOOP.

    " 2. Fallback nếu không thấy type E
    IF cs_tracking_line-error_msg IS INITIAL.
      LOOP AT lt_return INTO ls_return WHERE type = 'W' OR type = 'I'.
        cs_tracking_line-error_msg = |WARNING: { ls_return-message }|.
        EXIT.
      ENDLOOP.
    ENDIF.

    IF cs_tracking_line-error_msg IS INITIAL.
      cs_tracking_line-error_msg = 'ERROR: Failed (Unknown reason).'.
    ENDIF.

  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form PROCESS_REVERSE_PGI
*&---------------------------------------------------------------------*
FORM process_reverse_pgi
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  DATA: lv_delivery TYPE vbeln_vl.
  DATA: lv_result_raw TYPE string.
  DATA: lv_msg_type   TYPE c LENGTH 1.
  DATA: lv_msg_content TYPE string.

  " 1. Get Delivery
  lv_delivery = is_tracking_line-delivery_document.
  IF lv_delivery IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: No Delivery Document found.'.
    EXIT.
  ENDIF.

  " 2. Ensure previous data committed
  COMMIT WORK AND WAIT.

  " 3. Clear memory
  FREE MEMORY ID 'Z_PGI_RESULT'.

  " 4. CALL WORKER REPORT
  SUBMIT zpg_reverse_pgi_worker
    WITH p_vbeln = lv_delivery
    AND RETURN."#EC CI_SUBMIT.

  " 5. Receive result
  IMPORT result = lv_result_raw FROM MEMORY ID 'Z_PGI_RESULT'.
  FREE MEMORY ID 'Z_PGI_RESULT'.

  " 6. Analyze result
  IF lv_result_raw IS NOT INITIAL.
    SPLIT lv_result_raw AT ':' INTO lv_msg_type lv_msg_content.

    IF lv_msg_type = 'S'.
      " Success
      cs_tracking_line-error_msg = lv_msg_content.
    ELSE.
      " Failure
      CONCATENATE 'ERROR FROM WORKER:' lv_msg_content INTO cs_tracking_line-error_msg SEPARATED BY space.
    ENDIF.
  ELSE.
    cs_tracking_line-error_msg = 'Unknown Error: Worker did not return a result.'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_CANCEL_BILLING
*&---------------------------------------------------------------------*
FORM process_cancel_billing
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  DATA: lt_ret     TYPE STANDARD TABLE OF bapiret2,
        ls_ret     TYPE bapiret2,
        lv_fksto   TYPE vbrk-fksto,
        ls_success TYPE bapivbrksuccess.
  DATA: lt_success TYPE STANDARD TABLE OF bapivbrksuccess.

  " --- Temp Vars ---
  DATA: lv_billing    TYPE vbeln_vf,
        lv_cancel_doc TYPE vbeln_vf.

  CLEAR cs_tracking_line-error_msg.

  " 1. Get Billing
  lv_billing = is_tracking_line-billing_document.

  IF lv_billing IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: No Billing Document to Cancel.'.
    EXIT.
  ENDIF.

  " 2. CHECK STATUS
  SELECT SINGLE fksto
    FROM vbrk
    INTO @lv_fksto
    WHERE vbeln = @lv_billing.

  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = |ERROR: Billing Doc { lv_billing } not found in system.|.
    EXIT.
  ENDIF.

  IF lv_fksto = 'X'.
    cs_tracking_line-error_msg = |ERROR: Billing Doc { lv_billing } was already cancelled.|.
    EXIT.
  ENDIF.

  " 3. CALL BAPI (Synchronous)
  SET UPDATE TASK LOCAL.

  CALL FUNCTION 'BAPI_BILLINGDOC_CANCEL1'
    EXPORTING
      billingdocument = lv_billing
    TABLES
      return          = lt_ret
      success         = lt_success.

  " 4. HANDLE RESULT
  READ TABLE lt_success INTO ls_success INDEX 1.

  IF sy-subrc = 0.
    " --- SUCCESS ---

    " Get cancellation doc number from Message V1
    READ TABLE lt_ret INTO ls_ret WITH KEY type = 'S'.
    IF sy-subrc = 0.
      lv_cancel_doc = ls_ret-message_v1.
    ENDIF.

    " Commit & Wait
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.

    " Dequeue
    CALL FUNCTION 'DEQUEUE_ALL'.

    " Check DB
    DATA: lv_db_exist TYPE abap_bool.
    DO 5 TIMES.
      SELECT SINGLE vbeln FROM vbrk INTO @DATA(lv_check)
        WHERE vbeln = @lv_billing
          AND fksto = 'X'.

      IF sy-subrc = 0.
        lv_db_exist = abap_true.
        EXIT.
      ELSE.
        WAIT UP TO '0.5' SECONDS.
      ENDIF.
    ENDDO.

    IF lv_db_exist = abap_true.
      CONCATENATE 'Cancellation successful. Cancel Doc:' lv_cancel_doc
        INTO cs_tracking_line-error_msg SEPARATED BY space.
    ELSE.
      cs_tracking_line-error_msg = |WARNING: Cancellation sent for { lv_billing } but DB update is slow.|.
    ENDIF.

  ELSE.
    " --- FAILURE ---
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    CALL FUNCTION 'DEQUEUE_ALL'.

    " Find Error
    LOOP AT lt_ret INTO ls_ret WHERE type = 'E' OR type = 'A'.
      CONCATENATE 'CANCELLATION ERROR:' ls_ret-message
        INTO cs_tracking_line-error_msg SEPARATED BY space.
      EXIT.
    ENDLOOP.

    " Specific Check (VF 009)
    IF cs_tracking_line-error_msg IS INITIAL.
      READ TABLE lt_ret INTO ls_ret WITH KEY id = 'VF' number = '009'.
      IF sy-subrc = 0.
        cs_tracking_line-error_msg = 'ERROR: Accounting document is Cleared. Reverse Clearing required first.'.
      ELSE.
        cs_tracking_line-error_msg = 'ERROR: Cancellation failed (Unknown cause, check log).'.
      ENDIF.
    ENDIF.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_RELEASE_TO_ACCOUNT
*&---------------------------------------------------------------------*
FORM process_release_to_account
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  DATA: lv_bill_doc    TYPE vbrk-vbeln,
        lv_subrc_check TYPE sy-subrc,
        ls_vbrk_wa     TYPE vbrk.

  " --- Variables (Table declarations kept same) ---
  DATA:
    lt_vbrk_in  TYPE STANDARD TABLE OF vbrk,
    lt_vbrk_out TYPE STANDARD TABLE OF vbrkvb,
    lt_xkomfk   TYPE STANDARD TABLE OF komfk,
    lt_xkomv    TYPE STANDARD TABLE OF komv,
    lt_xthead   TYPE STANDARD TABLE OF theadvb,
    lt_xvbfs    TYPE STANDARD TABLE OF vbfs,
    lt_xvbpa    TYPE STANDARD TABLE OF vbpavb,
    lt_xvbrp    TYPE STANDARD TABLE OF vbrpvb,
    lt_xvbrl    TYPE STANDARD TABLE OF vbrlvb,
    lt_xvbss    TYPE STANDARD TABLE OF vbss.

  " 1. Refresh Buffers
  CALL FUNCTION 'BUFFER_REFRESH_ALL'.
  CALL FUNCTION 'LE_DELIVERY_REFRESH_BUFFER'.
  CLEAR cs_tracking_line-error_msg.

  lv_bill_doc = is_tracking_line-billing_document.

  " 2. CHECKS
  IF lv_bill_doc IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: No Billing Document number found.'.
    EXIT.
  ENDIF.

  " Check RFBSK (Accounting Status)
  DATA: lv_rfbsk TYPE vbrk-rfbsk.
  SELECT SINGLE rfbsk FROM vbrk INTO lv_rfbsk WHERE vbeln = lv_bill_doc.

  IF lv_rfbsk = 'C'.
    cs_tracking_line-error_msg = |WARNING: Billing { lv_bill_doc } already Released (FI Posted).|.
    EXIT.
  ENDIF.

  " Check Cancelled
  DATA: lv_fksto TYPE vbrk-fksto.
  SELECT SINGLE fksto FROM vbrk INTO lv_fksto WHERE vbeln = lv_bill_doc.
  IF lv_fksto = 'X'.
    cs_tracking_line-error_msg = |ERROR: Billing { lv_bill_doc } is Cancelled. Cannot Release.|.
    EXIT.
  ENDIF.

  " 3. PREPARE & CALL FM
  SET UPDATE TASK LOCAL.

  REFRESH: lt_vbrk_in, lt_vbrk_out, lt_xkomfk, lt_xkomv,
           lt_xthead, lt_xvbfs, lt_xvbpa, lt_xvbrp, lt_xvbrl, lt_xvbss.
  CLEAR: ls_vbrk_wa.

  SELECT SINGLE * FROM vbrk INTO ls_vbrk_wa WHERE vbeln = lv_bill_doc."#EC CI_ALL_FIELDS_NEEDED
  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = 'ERROR: Could not read VBRK data.'.
    EXIT.
  ENDIF.

  APPEND ls_vbrk_wa TO lt_vbrk_in.

  CALL FUNCTION 'SD_INVOICE_RELEASE_TO_ACCOUNT'
    EXPORTING
      with_posting = 'B'
    TABLES
      it_vbrk      = lt_vbrk_in
      xkomfk       = lt_xkomfk
      xkomv        = lt_xkomv
      xthead       = lt_xthead
      xvbfs        = lt_xvbfs
      xvbpa        = lt_xvbpa
      xvbrk        = lt_vbrk_out
      xvbrp        = lt_xvbrp
      xvbrl        = lt_xvbrl
      xvbss        = lt_xvbss
  EXCEPTIONS
      OTHERS       = 1.

  lv_subrc_check = sy-subrc.

  " 4. CHECK RESULTS
  READ TABLE lt_xvbfs INTO DATA(ls_err) WITH KEY msgty = 'E'.
  IF sy-subrc = 0.
    " SAP Business Error
    MESSAGE ID ls_err-msgid TYPE 'S' NUMBER ls_err-msgno
            WITH ls_err-msgv1 ls_err-msgv2 ls_err-msgv3 ls_err-msgv4
            INTO cs_tracking_line-error_msg.

    CONCATENATE 'RELEASE ERROR: ' cs_tracking_line-error_msg INTO cs_tracking_line-error_msg.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    EXIT.
  ENDIF.

  IF lv_subrc_check <> 0.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    cs_tracking_line-error_msg = 'Technical error calling Release FM (Subrc <> 0).'.
  ELSE.
    COMMIT WORK AND WAIT.
    cs_tracking_line-error_msg = |Success: Billing { lv_bill_doc } released to Accounting.|.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SETUP_JOB_SCHEDULE
*&---------------------------------------------------------------------*
FORM setup_job_schedule.

  " --- KHAI BÁO BIẾN ---
  DATA: lv_start_date TYPE sy-datum,
        lv_start_time TYPE sy-uzeit,
        lv_jobcount   TYPE tbtcjob-jobcount.
  DATA: lt_fields TYPE TABLE OF sval,
        ls_field  TYPE sval,
        lv_rc     TYPE c.

  " Time Vars (Sử dụng TIMESTAMPL để tránh Warning rounding)
  DATA: lv_tstmp_vn      TYPE timestampl,
        lv_tstmp_current TYPE timestampl,
        lv_date_server   TYPE sy-datum,
        lv_time_server   TYPE sy-uzeit.

  " Spool Vars
  DATA: ls_pri_params TYPE pri_params,
        lv_valid_pri  TYPE c.

  CONSTANTS: lc_jobname TYPE tbtcjob-jobname VALUE 'Z_AUTO_DELIV_PROTOTYPE'.

  " --- 1. POPUP CHỌN NGÀY (Mặc định Ngày mai) ---
  GET TIME STAMP FIELD lv_tstmp_current.

  " Convert Server Time -> UTC+7 để hiển thị default date cho user
  TRY.
      CONVERT TIME STAMP lv_tstmp_current TIME ZONE 'UTC+7'
              INTO DATE lv_start_date TIME lv_start_time.
    CATCH cx_root.
      lv_start_date = sy-datum.
  ENDTRY.

  lv_start_date = lv_start_date + 1. " Default: Ngày mai

  CLEAR: ls_field, lt_fields.
  ls_field-tabname = 'VBAK'. ls_field-fieldname = 'ERDAT'.
  ls_field-fieldtext = 'Run Date (VN Time)'. ls_field-value = lv_start_date.
  APPEND ls_field TO lt_fields.

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title = 'Schedule Job (VN Time 00:15)'
    IMPORTING
      returncode  = lv_rc
    TABLES
      fields      = lt_fields.

  IF lv_rc = 'A' . MESSAGE 'Cancelled.' TYPE 'S'. RETURN. ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 1.
  lv_start_date = ls_field-value.
  lv_start_time = '000015'. " Cố định 0h15 sáng

  " --- 2. TÍNH TOÁN THỜI GIAN SERVER ---

  " A. Tạo Timestamp từ input của User (Giờ VN)
  CONVERT DATE lv_start_date TIME lv_start_time
          INTO TIME STAMP lv_tstmp_vn TIME ZONE 'UTC+7'.

  " B. Kiểm tra quá khứ: Nếu thời gian user chọn <= thời gian hiện tại
  "    => Cộng thêm 1 ngày (86400 giây) để tránh job chạy ngay lập tức.
  IF lv_tstmp_vn <= lv_tstmp_current.
    TRY.
        CALL METHOD cl_abap_tstmp=>add
          EXPORTING
            tstmp   = lv_tstmp_vn
            secs    = 86400
          RECEIVING
            r_tstmp = lv_tstmp_vn.
      CATCH cx_root.
    ENDTRY.
    MESSAGE 'Time passed inside logic. Moved to next day.' TYPE 'S'.
  ENDIF.

  " C. Convert Timestamp chuẩn về lại Ngày/Giờ của Server để gọi Job
  CONVERT TIME STAMP lv_tstmp_vn TIME ZONE sy-zonlo
          INTO DATE lv_date_server TIME lv_time_server.

  " --- 3. SPOOL CONFIG ---
  CALL FUNCTION 'GET_PRINT_PARAMETERS'
    EXPORTING
      no_dialog      = 'X'
      mode           = 'CURRENT'
      destination    = 'LP01'
      line_count     = 65
      line_size      = 255
      expiration     = 1
      new_list_id    = 'X'
    IMPORTING
      out_parameters = ls_pri_params
      valid          = lv_valid_pri
    EXCEPTIONS
      OTHERS         = 4.

  IF sy-subrc <> 0 OR lv_valid_pri <> 'X'.
    MESSAGE 'Error: Spool parameters failed.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " --- 4. SUBMIT JOB ---
  PERFORM delete_existing_released_job USING lc_jobname.

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING
      jobname  = lc_jobname
    IMPORTING
      jobcount = lv_jobcount.

  CALL FUNCTION 'JOB_SUBMIT'
    EXPORTING
      jobname   = lc_jobname
      jobcount  = lv_jobcount
      report    = 'ZSD4_AUTO_DELIVERY_JOB'
      authcknam = sy-uname
      priparams = ls_pri_params
    EXCEPTIONS
      OTHERS    = 1.

  IF sy-subrc <> 0. MESSAGE 'Error Job_Submit' TYPE 'S'. RETURN. ENDIF.

  " --- 5. JOB CLOSE ---
  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobname   = lc_jobname
      jobcount  = lv_jobcount
      sdlstrtdt = lv_date_server
      sdlstrttm = lv_time_server
      prddays   = 1    " Lặp lại hàng ngày
    EXCEPTIONS
      OTHERS    = 1.

  IF sy-subrc = 0.
    MESSAGE |Scheduled OK. Next run (Server Time): { lv_date_server } { lv_time_server }| TYPE 'S'.
  ELSE.
    MESSAGE 'Error Job_Close' TYPE 'S'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DELETE_EXISTING_RELEASED_JOB
*&---------------------------------------------------------------------*
FORM delete_existing_released_job USING iv_jobname TYPE tbtcjob-jobname.

  DATA: lt_joblist TYPE TABLE OF bapixmjobs.
  DATA: ls_return_select TYPE bapiret2.
  DATA: ls_return_delete TYPE bapiret2.

  " 1. Search Params
  DATA: ls_job_param TYPE bapixmjsel.
  CLEAR ls_job_param.
  ls_job_param-jobname  = iv_jobname.
  ls_job_param-username = '*'.
  ls_job_param-schedul  = 'X'. " Only Released jobs

  DATA: lv_ext_user TYPE bapixmlogr-extuser.
  lv_ext_user = sy-uname.

  " 2. Search
  CALL FUNCTION 'BAPI_XBP_JOB_SELECT'
    EXPORTING
      job_select_param   = ls_job_param
      external_user_name = lv_ext_user
    IMPORTING
      return             = ls_return_select
    TABLES
      selected_jobs      = lt_joblist.

  " 3. Delete
  LOOP AT lt_joblist ASSIGNING FIELD-SYMBOL(<fs_job>).
    CLEAR ls_return_delete.

    CALL FUNCTION 'BAPI_XBP_JOB_DELETE'
      EXPORTING
        jobname            = <fs_job>-jobname
        jobcount           = <fs_job>-jobcount
        external_user_name = lv_ext_user
      IMPORTING
        return             = ls_return_delete.

    MESSAGE |Found and deleted old schedule (ID: { <fs_job>-jobcount })| TYPE 'S'.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SHOW_JOB_MONITOR_POPUP
*&---------------------------------------------------------------------*
FORM show_job_monitor_popup.

  TYPES: BEGIN OF ty_job_report,
           status_icon TYPE icon_d,
           run_date    TYPE sy-datum,
           run_time    TYPE sy-uzeit,
           status_text TYPE char20,
           items_found TYPE i,
           success_cnt TYPE i,
           error_cnt   TYPE i,
           message     TYPE string, " Cột Note
           jobcount    TYPE tbtcjob-jobcount,
         END OF ty_job_report.

  DATA: lt_report TYPE TABLE OF ty_job_report,
        ls_report TYPE ty_job_report,
        lt_tbtco  TYPE TABLE OF tbtco.

  " Job Log Vars
  DATA: lt_joblog TYPE TABLE OF tbtc5,
        ls_joblog TYPE tbtc5.

  " Biến mới để xử lý list thành công
  DATA: lv_created_doc  TYPE string,
        lv_success_list TYPE string,
        lv_first_error  TYPE string.

  " ALV Objects
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_col     TYPE REF TO cl_salv_column.

  " 1. Get last 20 jobs
  SELECT * FROM tbtco
    INTO TABLE lt_tbtco
    UP TO 20 ROWS
    WHERE jobname = 'Z_AUTO_DELIV_PROTOTYPE'
    ORDER BY sdlstrtdt DESCENDING sdlstrttm DESCENDING.

  IF lt_tbtco IS INITIAL.
    MESSAGE 'No Job history found.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 2. Process Logs
  LOOP AT lt_tbtco INTO DATA(ls_job).
    CLEAR: ls_report, lv_success_list, lv_first_error.
    ls_report-jobcount = ls_job-jobcount.

    CASE ls_job-status.
      WHEN 'F'. " Finished
        ls_report-status_icon = '@5B@'. " Green
        ls_report-status_text = 'Finished'.
        ls_report-run_date    = ls_job-strtdate.
        ls_report-run_time    = ls_job-strttime.

        REFRESH lt_joblog.
        CALL FUNCTION 'BP_JOBLOG_READ'
          EXPORTING
            jobname   = ls_job-jobname
            jobcount  = ls_job-jobcount
          TABLES
            joblogtbl = lt_joblog
          EXCEPTIONS
            OTHERS    = 5.

        IF sy-subrc = 0.
          LOOP AT lt_joblog INTO ls_joblog.

            " --- [LOGIC MỚI: Tách số chứng từ] ---
            IF ls_joblog-text CS 'SUCCESS'.
              ADD 1 TO ls_report-success_cnt.

              " Tìm số chứng từ trong log (Format: Created Delivery XXXXX)

              FIND PCRE 'Delivery\s+(\d+)' IN ls_joblog-text SUBMATCHES lv_created_doc.

              IF sy-subrc = 0.
                IF lv_success_list IS INITIAL.
                  lv_success_list = lv_created_doc.
                ELSE.
                  " Nối chuỗi các số tìm được, cách nhau dấu phẩy
                  lv_success_list = |{ lv_success_list }, { lv_created_doc }|.
                ENDIF.
              ENDIF.
            ENDIF.

            IF ls_joblog-text CS 'ERROR'.
              ADD 1 TO ls_report-error_cnt.
              " Lưu lỗi đầu tiên tìm thấy để backup
              IF lv_first_error IS INITIAL.
                lv_first_error = ls_joblog-text.
              ENDIF.
            ENDIF.

            " Tìm số lượng items Found
            IF ls_joblog-text CS 'Found' OR ls_joblog-text CS 'Tìm thấy'.
              FIND PCRE '(\d+)' IN ls_joblog-text SUBMATCHES DATA(lv_num).
              ls_report-items_found = lv_num.
            ENDIF.

          ENDLOOP.

          " --- [GÁN KẾT QUẢ VÀO CỘT NOTE] ---
          IF lv_success_list IS NOT INITIAL.
            " Nếu có thành công, hiện list số
            IF ls_report-error_cnt > 0.

              ls_report-message = |Created: { lv_success_list }|.
            ELSE.
              ls_report-message = |Created: { lv_success_list }|.
            ENDIF.
          ELSE.
            " Nếu không có thành công nào, hiện lỗi (nếu có)
            ls_report-message = lv_first_error.
          ENDIF.

        ENDIF.

      WHEN 'R'. " Released
        ls_report-status_icon = '@5C@'. " Yellow
        ls_report-status_text = 'Planned'.
        ls_report-run_date    = ls_job-sdlstrtdt.
        ls_report-run_time    = ls_job-sdlstrttm.
        ls_report-message     = 'Waiting for schedule...'.

      WHEN 'A'. " Active
        ls_report-status_icon = '@5D@'. " Red
        ls_report-status_text = 'Running'.
        ls_report-run_date    = ls_job-strtdate.
        ls_report-run_time    = ls_job-strttime.

      WHEN OTHERS.
        ls_report-status_text = 'Cancelled'.
        ls_report-status_icon = '@5D@'.
    ENDCASE.

    APPEND ls_report TO lt_report.
  ENDLOOP.

  " 3. Display ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_report ).

      lo_alv->set_screen_popup(
        start_column = 10  end_column   = 120  " Tăng độ rộng popup để nhìn rõ list
        start_line   = 5   end_line     = 20 ).

      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( 'X' ).

      lo_col = lo_columns->get_column( 'STATUS_ICON' ). lo_col->set_long_text( 'Status' ).
      lo_col = lo_columns->get_column( 'RUN_DATE' ).    lo_col->set_long_text( 'Date' ).
      lo_col = lo_columns->get_column( 'RUN_TIME' ).    lo_col->set_long_text( 'Time' ).
      lo_col = lo_columns->get_column( 'ITEMS_FOUND' ). lo_col->set_long_text( 'Found' ).
      lo_col = lo_columns->get_column( 'SUCCESS_CNT' ). lo_col->set_long_text( 'Success' ).
      lo_col = lo_columns->get_column( 'ERROR_CNT' ).   lo_col->set_long_text( 'Error' ).

      " Đổi tên cột Note thành List/Note cho rõ nghĩa
      lo_col = lo_columns->get_column( 'MESSAGE' ).     lo_col->set_long_text( 'Created Docs / Note' ).

      lo_col = lo_columns->get_column( 'JOBCOUNT' ).    lo_col->set_visible( abap_false ).

      lo_alv->display( ).

    CATCH cx_salv_msg.
      MESSAGE 'ALV Display Error (Generic)' TYPE 'S'.
    CATCH cx_salv_not_found.
      MESSAGE 'ALV Error: Column not found' TYPE 'S'.
    CATCH cx_salv_data_error.
      MESSAGE 'ALV Error: Data Problem' TYPE 'S'.
    CATCH cx_salv_existing.
      MESSAGE 'ALV Error: Existing' TYPE 'S'.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SHOW_DOCUMENT_FLOW_POPUP
*&---------------------------------------------------------------------*
*& Hiển thị Document Flow theo cấu trúc Cây (Sales -> Del -> PGI -> Inv -> FI)
*& Sử dụng thuật toán Đệ quy (Recursive) để đảm bảo đúng thứ tự.
*&---------------------------------------------------------------------*

" 1. Khai báo Types Global cho Form
TYPES: BEGIN OF ty_flow_display,
         icon(4)      TYPE c,
         level        TYPE i,
         doc_category TYPE char35,
         doc_number   TYPE char20,
         doc_date     TYPE datum,
         doc_time     TYPE uzeit,
         status       TYPE char50,
       END OF ty_flow_display.

DATA: gt_flow_display TYPE TABLE OF ty_flow_display,
      gt_processed    TYPE SORTED TABLE OF vbeln_vf WITH UNIQUE KEY table_line.

FORM show_document_flow_popup USING pv_row_index TYPE i.

  DATA: ls_tracking TYPE ty_tracking,
        ls_root     TYPE ty_flow_display,
        ls_vbak     TYPE vbak.

  " --- Reset dữ liệu toàn cục ---
  CLEAR: gt_flow_display, gt_processed.

  " 1. Lấy Sales Order gốc
  READ TABLE gt_tracking INTO ls_tracking INDEX pv_row_index.
  IF sy-subrc <> 0 OR ls_tracking-sales_document IS INITIAL. RETURN. ENDIF.

*  SELECT SINGLE * FROM vbak INTO ls_vbak WHERE vbeln = ls_tracking-sales_document.
  SELECT SINGLE erdat, erzet, gbstk
    FROM vbak
    INTO CORRESPONDING FIELDS OF @ls_vbak
    WHERE vbeln = @ls_tracking-sales_document.
  " 2. Thêm Root (Sales Order) vào list
  ls_root-level        = 1.
  ls_root-icon         = '@49@'. " Order Icon
  ls_root-doc_category = 'Sales Order'.
  ls_root-doc_number   = ls_tracking-sales_document.
  ls_root-doc_date     = ls_vbak-erdat.
  ls_root-doc_time     = ls_vbak-erzet.
  IF ls_vbak-gbstk = 'C'. ls_root-status = 'Completed'. ELSE. ls_root-status = 'In Process'. ENDIF.

  APPEND ls_root TO gt_flow_display.
  INSERT ls_tracking-sales_document INTO TABLE gt_processed.

  " 3. Bắt đầu đệ quy tìm con
  PERFORM find_children_recursive USING ls_tracking-sales_document 1.

  " 4. Hiển thị ALV
  PERFORM display_alv_flow.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form FIND_CHILDREN_RECURSIVE
*&---------------------------------------------------------------------*
*& Đệ quy tìm con - Đã FIX hiển thị Reversal Goods Issue (h)
*&---------------------------------------------------------------------*
FORM find_children_recursive USING pv_parent_vbeln TYPE vbeln_vf
                                   pv_parent_level TYPE i.

  DATA: lt_vbfa TYPE TABLE OF vbfa,
        ls_vbfa TYPE vbfa,
        ls_node TYPE ty_flow_display.

  DATA: lv_current_level TYPE i.
  lv_current_level = pv_parent_level + 1.

  " 1. Tìm tất cả con trực tiếp (Sort theo ngày giờ để đúng thứ tự xảy ra)
*  SELECT * FROM vbfa INTO TABLE lt_vbfa
*    WHERE vbelv = pv_parent_vbeln.
  SELECT vbeln, vbtyp_n, erdat, erzet
    FROM vbfa
    INTO CORRESPONDING FIELDS OF TABLE @lt_vbfa
    WHERE vbelv = @pv_parent_vbeln.
  SORT lt_vbfa BY erdat ASCENDING erzet ASCENDING.

  LOOP AT lt_vbfa INTO ls_vbfa.
    " Check trùng lặp
    READ TABLE gt_processed WITH TABLE KEY table_line = ls_vbfa-vbeln TRANSPORTING NO FIELDS.
    IF sy-subrc = 0. CONTINUE. ENDIF.
    INSERT ls_vbfa-vbeln INTO TABLE gt_processed.

    " 2. Cấu hình hiển thị
    CLEAR ls_node.
    ls_node-level      = lv_current_level.
    ls_node-doc_number = ls_vbfa-vbeln.
    ls_node-doc_date   = ls_vbfa-erdat.
    ls_node-doc_time   = ls_vbfa-erzet.

    CASE ls_vbfa-vbtyp_n.
        " --- Delivery ---
      WHEN 'J' OR 'T'.
        ls_node-doc_category = 'Outbound Delivery'.
        ls_node-icon         = '@1X@'.
        IF ls_vbfa-vbtyp_n = 'T'. ls_node-doc_category = 'Return Delivery'. ENDIF.

        " --- Picking ---
      WHEN 'Q'.
        ls_node-doc_category = 'Picking Request'.
        ls_node-icon         = '@0Q@'.
        ls_node-status       = 'Completed'.

        " --- Goods Issue (Xuất kho) ---
      WHEN 'R'.
        ls_node-doc_category = 'GD goods issue'.
        ls_node-icon         = '@0Q@'.
        ls_node-status       = 'Complete'. " SAP chuẩn dùng 'Complete'

      WHEN 'h'.
        ls_node-doc_category = 'RE goods deliv. rev.'. "
        ls_node-icon         = '@0Q@'.
        ls_node-status       = 'Complete'.

        " --- Invoice ---
      WHEN 'M' OR 'O' OR 'P'.
        ls_node-doc_category = 'Invoice'.
        ls_node-icon         = '@0W@'.
        SELECT SINGLE vbeln FROM vbfa INTO @DATA(lv_x) WHERE vbelv = @ls_vbfa-vbeln AND vbtyp_n = 'N'.
        IF sy-subrc = 0. ls_node-status = 'Cancelled'. ELSE. ls_node-status = 'Completed'. ENDIF.

        " --- Invoice Cancellation ---
      WHEN 'N' OR 'S'.
        ls_node-doc_category = 'Cancel Invoice'.
        ls_node-icon         = '@11@'.
        ls_node-status       = 'Completed'.

      WHEN OTHERS.
        ls_node-doc_category = 'Subsequent Doc'.
        ls_node-icon         = '@0O@'.
    ENDCASE.

    APPEND ls_node TO gt_flow_display.

    " === 3. TÌM FI (JOURNAL ENTRY) ===
    " Chỉ tìm FI cho Invoice (M,O,P) hoặc Cancel Invoice (N,S)
    IF ls_vbfa-vbtyp_n CA 'MOPNS'.
      PERFORM find_fi_document USING ls_vbfa-vbeln lv_current_level.
    ENDIF.

    " === 4. ĐỆ QUY TIẾP (Tìm con cháu) ===

    IF ls_vbfa-vbtyp_n NE 'N' AND ls_vbfa-vbtyp_n NE 'S'.
      PERFORM find_children_recursive USING ls_vbfa-vbeln lv_current_level.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form FIND_FI_DOCUMENT
*&---------------------------------------------------------------------*
FORM find_fi_document USING pv_billing_doc TYPE vbeln_vf
                            pv_level       TYPE i.

  DATA: ls_bkpf    TYPE bkpf,
        ls_fi_node TYPE ty_flow_display,
        lv_awkey   TYPE string.

  DATA: lv_augbl TYPE bsad_view-augbl,
        lv_augdt TYPE bsad_view-augdt.


  CONCATENATE pv_billing_doc '%' INTO lv_awkey.
  SELECT belnr, gjahr, bldat, cputm, bukrs
    FROM bkpf
    WHERE awtyp = 'VBRK'
      AND awkey LIKE @lv_awkey
    ORDER BY belnr, gjahr       " Sắp xếp để đảm bảo tính duy nhất
    INTO CORRESPONDING FIELDS OF @ls_bkpf
    UP TO 1 ROWS.
  ENDSELECT.

  IF sy-subrc = 0.
    ls_fi_node-level        = pv_level + 1.
    ls_fi_node-icon         = '@0Z@'.
    ls_fi_node-doc_category = 'Journal Entry'.
    CONCATENATE ls_bkpf-belnr '/' ls_bkpf-gjahr INTO ls_fi_node-doc_number.
    ls_fi_node-doc_date     = ls_bkpf-bldat.
    ls_fi_node-doc_time     = ls_bkpf-cputm.

    " Check Cleared
    CLEAR: lv_augbl, lv_augdt.

    " Select bảng BSAD_VIEW (Đã chuẩn Strict SQL)
    SELECT SINGLE augbl, augdt
      FROM bsad_view
      INTO (@lv_augbl, @lv_augdt)
      WHERE bukrs = @ls_bkpf-bukrs
        AND belnr = @ls_bkpf-belnr
        AND gjahr = @ls_bkpf-gjahr.

    IF sy-subrc = 0.
      ls_fi_node-status = 'Cleared'.
    ELSE.
      ls_fi_node-status = 'Not Cleared'.
    ENDIF.

    APPEND ls_fi_node TO gt_flow_display.
  ENDIF.

ENDFORM.

FORM display_alv_flow.
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_col     TYPE REF TO cl_salv_column.

  IF gt_flow_display IS INITIAL.
    MESSAGE 'No document flow found.' TYPE 'S'. RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                              CHANGING  t_table      = gt_flow_display ).

      lo_alv->set_screen_popup( start_column = 10 end_column = 100 start_line = 5 end_line = 25 ).
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( 'X' ).

      lo_col = lo_columns->get_column( 'ICON' ). lo_col->set_medium_text( ' ' ).
      lo_col = lo_columns->get_column( 'LEVEL' ). lo_col->set_medium_text( 'Lvl' ).
      lo_col = lo_columns->get_column( 'DOC_CATEGORY' ). lo_col->set_medium_text( 'Document' ).
      lo_col = lo_columns->get_column( 'DOC_NUMBER' ). lo_col->set_medium_text( 'Doc. Number' ).
      lo_col = lo_columns->get_column( 'DOC_TIME' ). lo_col->set_visible( ' ' ).

      lo_alv->display( ).

    CATCH cx_salv_not_found.
      MESSAGE 'ALV Error: Column not found' TYPE 'S'.
    CATCH cx_salv_msg.
      MESSAGE 'ALV Error: Generic' TYPE 'S'.
  ENDTRY.
ENDFORM.
