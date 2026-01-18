*&---------------------------------------------------------------------*
*& Include          ZSD4_SALES_ORDER_CENTERF01
*&---------------------------------------------------------------------*


"chú ý 2
FORM pbo_modify_screen.
  LOOP AT SCREEN.
    CASE screen-name.
      "--- LOGIC 1: KHÓA CÁC TRƯỜNG OUTPUT-ONLY (DÙNG CHUNG CHO CẢ EDIT VÀ CREATE) ---
      WHEN 'GS_SO_HEDER_UI-SO_HDR_VBELN'       OR  " Document Number
           'GS_SO_HEDER_UI-SO_HDR_KAL_SM'        OR  " Pric. Procedure
           'GS_SO_HEDER_UI-SO_HDR_SOLD_ADRNR'  OR  " Tên Sold-to
           'GS_SO_HEDER_UI-SO_HDR_SHIP_ADRNR'  OR  " Tên Ship-to
           'GS_SO_HEDER_UI-SO_HDR_SALESAREA'.       " Sales Area (Text)
        screen-input = 0.
        MODIFY SCREEN.
        CONTINUE. " Xử lý xong dòng này, qua vòng lặp tiếp theo
      "--- LOGIC 1B: Bỏ qua các control (Tabstrip) ---
      WHEN 'TS_MAIN_TAB1' OR 'TS_MAIN_TAB2' OR 'TS_MAIN_TAB3'.
        CONTINUE.
    ENDCASE.

    " ========================================================================
    " [THÊM MỚI] LOGIC RIÊNG CHO CHẾ ĐỘ 'EDIT' (TỪ MASS UPLOAD SANG)
    " ========================================================================
    IF gv_single_mode = 'EDIT'.

       CASE screen-name.
          " 1. KHÓA CÁC TRƯỜNG KHÓA (KEY FIELDS) - KHÔNG ĐƯỢC SỬA
          WHEN 'GS_SO_HEDER_UI-SO_HDR_AUART'     OR  " Order Type
               'GS_SO_HEDER_UI-SO_HDR_SOLD_ADDR' OR  " Sold-to Party
               'GS_SO_HEDER_UI-SO_HDR_VKORG'     OR  " Sales Org
               'GS_SO_HEDER_UI-SO_HDR_VTWEG'     OR  " Distr Channel
               'GS_SO_HEDER_UI-SO_HDR_SPART'.        " Division
             screen-input = 0.

          " 2. MỞ CÁC TRƯỜNG DỮ LIỆU CÓ THỂ SỬA (EDITABLE FIELDS)
          WHEN 'GS_SO_HEDER_UI-SO_HDR_BSTNK'     OR  " PO Number
               'GS_SO_HEDER_UI-SO_HDR_KETDAT'     OR  " Req Deliv Date
               'GS_SO_HEDER_UI-SO_HDR_AUDAT'      OR  " Document Date
               'GS_SO_HEDER_UI-SO_HDR_ZTERM'      OR  " Payment Term (Nếu cần)
               'GS_SO_HEDER_UI-SO_HDR_INCO1'.        " Incoterms (Nếu cần)
             screen-input = 1.

          " 3. CÁC TRƯỜNG CÒN LẠI -> GIỮ NGUYÊN HOẶC KHÓA (TÙY Ý)
          " Ở đây mặc định ta để theo thuộc tính màn hình gốc, hoặc khóa cho an toàn
       ENDCASE.

       MODIFY SCREEN.
       CONTINUE. " [QUAN TRỌNG] Bỏ qua Logic 2 bên dưới để không bị ghi đè
    ENDIF.

    " ========================================================================
    " LOGIC 2: CHẾ ĐỘ 'CREATE' (LOGIC CŨ CỦA BẠN - GIỮ NGUYÊN)
    " ========================================================================
    CASE gv_screen_state.
      "--- STATE '0': MỚI VÀO (HOẶC NHẬP SAI SOLD-TO) ---
      WHEN '0'.
        CASE screen-name.
          WHEN 'GS_SO_HEDER_UI-SO_HDR_AUART'     OR
               'GS_SO_HEDER_UI-SO_HDR_SOLD_ADDR'   OR
               'GS_SO_HEDER_UI-SO_HDR_VKORG'     OR
               'GS_SO_HEDER_UI-SO_HDR_VTWEG'     OR
               'GS_SO_HEDER_UI-SO_HDR_SPART'.
            screen-input = 1. " Chỉ cho nhập 5 trường Org Data + Sold-to
          WHEN OTHERS.
            screen-input = 0. " Khóa các trường (input) còn lại
        ENDCASE.

      "--- STATE '1': ĐÃ NHẬP XONG SOLD-TO ---
      WHEN '1'.
        CASE screen-name.
          " SỬA LẠI: CHỈ MỞ CÁC TRƯỜNG CẦN NHẬP TIẾP
          WHEN 'GS_SO_HEDER_UI-SO_HDR_BSTNK'      OR  " 1. Cust. Reference
               'GS_SO_HEDER_UI-SO_HDR_KETDAT'     OR  " 2. Req. Deliv. Date
               'GS_SO_HEDER_UI-SO_HDR_AUDAT'.         " 3. Document Date
            screen-input = 1. " Mở 3 trường này
          WHEN OTHERS.
            " Khóa TẤT CẢ các trường input còn lại (Org Data, Sold-to...)
            screen-input = 0.
        ENDCASE.
    ENDCASE.

    MODIFY SCREEN.
  ENDLOOP.
ENDFORM.
*
*&---------------------------------------------------------------------*
*& Form pbo_default_data
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
*& Form pai_auto_populate
*&---------------------------------------------------------------------*
*& Screen 0111 PAI - Tự động điền dữ liệu theo logic nghiệp vụ
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM pai_auto_populate .
  " Logic tự động điền Ship-to từ Sold-to (như bạn yêu cầu)
  IF gs_so_heder_ui-so_hdr_ship_addr IS INITIAL AND
     gs_so_heder_ui-so_hdr_sold_addr IS NOT INITIAL.

    gs_so_heder_ui-so_hdr_ship_addr = gs_so_heder_ui-so_hdr_sold_addr.
  ENDIF.

  " Logic tự động điền Payer từ Sold-to
  IF gs_so_heder_ui-so_hdr_payer IS INITIAL AND
     gs_so_heder_ui-so_hdr_sold_addr IS NOT INITIAL.

    gs_so_heder_ui-so_hdr_payer = gs_so_heder_ui-so_hdr_sold_addr.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form pai_validate_input
*&---------------------------------------------------------------------*
*& Kiểm tra dữ liệu bắt buộc trước khi tra cứu
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM pai_validate_input.
  " Ví dụ kiểm tra các trường bắt buộc
  IF gs_so_heder_ui-so_hdr_auart IS INITIAL.
    MESSAGE 'Please enter a Document Type' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

  IF gs_so_heder_ui-so_hdr_sold_addr IS INITIAL.
    MESSAGE 'Please enter a Sold-to Party' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

  " ... (thêm các check khác cho Cust. Ref, Req. Deliv. Date...) ...
ENDFORM.

*&---------------------------------------------------------------------*
*& Form pai_derive_data (ĐÃ SỬA CHO AUTO-FILL ĐẦY ĐỦ)
*&---------------------------------------------------------------------*
FORM pai_derive_data.
  DATA: lv_sold_to TYPE kunnr,
        lv_ship_to TYPE kunnr.

  " --- 1. KIỂM TRA SOLD-TO-PARTY ---
  IF gs_so_heder_ui-so_hdr_sold_addr IS INITIAL.
    CLEAR: gs_so_heder_ui-so_hdr_sold_adrnr,
           gs_so_heder_ui-so_hdr_ship_adrnr.
    gv_screen_state = '0'.
    EXIT.
  ENDIF.

  " Chuẩn hóa Sold-to (CHỈ DÙNG CHO BIẾN LOCAL)
  lv_sold_to = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_sold_to
    IMPORTING
      output = lv_sold_to.
  " <<< XÓA DÒNG GÁN NGƯỢC: gs_so_heder_ui-so_hdr_sold_addr = lv_sold_to >>>

  " --- 2. LẤY TÊN (KNA1) ---
  SELECT SINGLE name1 FROM kna1
    INTO gs_so_heder_ui-so_hdr_sold_adrnr
    WHERE kunnr = lv_sold_to.
  IF sy-subrc <> 0.
    CLEAR gs_so_heder_ui-so_hdr_sold_adrnr.
    gv_screen_state = '0'.
    MESSAGE 'Sold-to Party not found' TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

  PERFORM pai_auto_populate.

  " --- 3. KIỂM TRA VÀ LẤY SALES AREA (LOGIC MỚI) ---
  IF gs_so_heder_ui-so_hdr_vkorg IS INITIAL OR
     gs_so_heder_ui-so_hdr_vtweg IS INITIAL OR
     gs_so_heder_ui-so_hdr_spart IS INITIAL.

    " Sales Area chưa đủ, gọi FORM popup
    PERFORM get_sales_area_from_popup
      USING    lv_sold_to " Dùng biến local đã convert
      CHANGING gs_so_heder_ui-so_hdr_vkorg
               gs_so_heder_ui-so_hdr_vtweg
               gs_so_heder_ui-so_hdr_spart.

    IF sy-subrc <> 0.
      gv_screen_state = '0'.
      EXIT.
    ENDIF.
  ENDIF.

  " --- 4. AUTO-FILL HEADER DATA (LOGIC CŨ) ---
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
    PERFORM get_and_set_derived_fields USING lv_sold_to.
    gv_screen_state = '1'.
    PERFORM default_dates_after_soldto.
  ELSE.
    gv_screen_state = '0'.
    " Đây là lỗi trong pop4.png
    MESSAGE |Customer { gs_so_heder_ui-so_hdr_sold_addr } not defined for Sales Area| TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.


ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_AND_SET_DERIVED_FIELDS
*&---------------------------------------------------------------------*
*& Fills the Pricing Proc and Sales Area text after KNVV is found.
*&---------------------------------------------------------------------*
FORM get_and_set_derived_fields USING iv_kunnr TYPE kunnr.

  " --- 1. Xác định Pricing Procedure (KAL_SM) ---
  " Lấy KALVG (Doc. Pricing Proc) từ Order Type (TVAK)
  SELECT SINGLE kalvg INTO @DATA(lv_kalvg) FROM tvak
    WHERE auart = @gs_so_heder_ui-so_hdr_auart.

  " Lấy KALKS (Cust. Pricing Proc) từ KNVV (Đã có trong SELECT ở pai_derive_data, nhưng SELECT lại cho an toàn)
  SELECT SINGLE kalks INTO @DATA(lv_kalks) FROM knvv
    WHERE kunnr = @iv_kunnr
      AND vkorg = @gs_so_heder_ui-so_hdr_vkorg.

  " Tra cứu trong T683V
  SELECT SINGLE kalsm INTO @gs_so_heder_ui-so_hdr_kalsm " <<< ĐIỀN KAL_SM
    FROM t683v
    WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg
      AND vtweg = @gs_so_heder_ui-so_hdr_vtweg
      AND spart = @gs_so_heder_ui-so_hdr_spart
      AND kalvg = @lv_kalvg
      AND kalks = @lv_kalks.

  " --- 2. Sales Area Text ---
  SELECT SINGLE vtext INTO @DATA(lv_vkorg_txt) FROM tvkot
    WHERE vkorg = @gs_so_heder_ui-so_hdr_vkorg.
  SELECT SINGLE vtext INTO @DATA(lv_vtweg_txt) FROM tvtwt
    WHERE vtweg = @gs_so_heder_ui-so_hdr_vtweg.
  SELECT SINGLE vtext INTO @DATA(lv_spart_txt) FROM tspat
    WHERE spart = @gs_so_heder_ui-so_hdr_spart.

  " ĐIỀN SALES AREA TEXT (FIELD output only)
  gs_so_heder_ui-so_hdr_salesarea = |{ gs_so_heder_ui-so_hdr_vkorg }/{ gs_so_heder_ui-so_hdr_vtweg }/{ gs_so_heder_ui-so_hdr_spart } ({ lv_vkorg_txt } - { lv_vtweg_txt } - { lv_spart_txt })|.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form default_dates_after_soldto
*&---------------------------------------------------------------------*
*& Gán ngày mặc định SAU KHI Sold-to hợp lệ
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


"---------------------------------------------------------------------------------------------------
"---------------------------------THANGNB TRANSFER CODE FROM ZPG_UPLOAD_213I01TEST6_2------------------------
*----------------------------------------------------------------------*
* Logic chuyển từ ZPG_UPLOAD_213F01TEST6_2
*----------------------------------------------------------------------*


"-----------------------------------PART 1: LOGIC EXCEL READ AND UPLOAD--------------------------
*&---------------------------------------------------------------------*
*& Form DOWNLOAD_TEMPLATE (Dựa trên code ZPG của bạn)
*&---------------------------------------------------------------------*
FORM download_template.
  DATA: lv_folder    TYPE string,
        lv_full_path TYPE rlgrap-filename,
        lv_objid     TYPE wwwdata-objid,
        lwa_data     TYPE wwwdatatab,
        lv_subrc     TYPE sy-subrc,
        lwa_rec      TYPE wwwdatatab.

  " --- 1. SỬA: Tên object SMW0 của program này ---
  lv_objid = 'ZSD4_FILE_TEMPLATE4'. " (Tên bạn đã upload ở Bước 1)

  "--- 2. Hiển thị dialog chọn thư mục (Giữ nguyên) ---
  CALL METHOD cl_gui_frontend_services=>directory_browse
    EXPORTING
      window_title         = 'Chọn thư mục để lưu file mẫu'
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.
  IF sy-subrc <> 0 OR lv_folder IS INITIAL.
    MESSAGE 'Đã hủy.' TYPE 'I'.
    EXIT.
  ENDIF.

  "--- 3. SỬA: Tên file mẫu download ---
  CONCATENATE lv_folder '\ZSD4_TEMPLATE_MASS.xlsx' INTO lv_full_path.

  "--- 4. Lấy object SMW0 (Giữ nguyên) ---
  SELECT SINGLE relid, objid INTO CORRESPONDING FIELDS OF @lwa_rec
    FROM wwwdata
    WHERE srtf2 = 0
      AND relid = 'MI'
      AND objid = @lv_objid.
  IF sy-subrc <> 0.
    MESSAGE |Không tìm thấy template '{ lv_objid }' trong SMW0!| TYPE 'E'.
    EXIT.
  ENDIF.
  lwa_data = CORRESPONDING #( lwa_rec ).

  "--- 5. Tải file (Giữ nguyên) ---
  CALL FUNCTION 'DOWNLOAD_WEB_OBJECT'
    EXPORTING
      key         = lwa_data
      destination = lv_full_path
    IMPORTING
      rc          = lv_subrc.

  IF lv_subrc = 0.
    MESSAGE |Tải file mẫu thành công: { lv_full_path }| TYPE 'S'.
  ELSE.
    MESSAGE 'Lỗi khi tải file từ SMW0!' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form open_file_dialog
*&---------------------------------------------------------------------*
FORM open_file_dialog CHANGING c_gv_lpath TYPE rlgrap-filename.
  DATA: lv_rc        TYPE i,
        lt_filetable TYPE filetable.
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title = 'Select File'
      file_filter  = 'Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*'
    CHANGING
      file_table   = lt_filetable
      rc           = lv_rc
    EXCEPTIONS
      OTHERS       = 1.
  IF sy-subrc = 0 AND lines( lt_filetable ) > 0.
    c_gv_lpath = lt_filetable[ 1 ]-filename.
  ENDIF.
ENDFORM.

"chú ý 2
FORM upload_file
  USING
    iv_path   TYPE string
    iv_req_id TYPE zsd_req_id       " (Nhận REQ_ID từ FORM cha)
  CHANGING
    ct_header TYPE STANDARD TABLE     " (Type ztb_so_upload_hd)
    ct_item   TYPE STANDARD TABLE    " (Type ztb_so_upload_it)
    ct_cond   TYPE STANDARD TABLE. " [MỚI]

  DATA: lo_excel_ref TYPE REF TO cl_fdt_xl_spreadsheet,
        lv_xstring   TYPE xstring,
        lv_len       TYPE i,
        lt_bin       TYPE solix_tab.

  " [SỬA]: Dùng REF TO DATA thay vì Field Symbol trực tiếp
  DATA: lo_data_ref TYPE REF TO data.
  FIELD-SYMBOLS: <gt_data_raw> TYPE STANDARD TABLE,
                 <fs_raw>      TYPE any.

  " --- 1. Đọc File (Giữ nguyên logic chuẩn) ---
  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING filename = iv_path filetype = 'BIN'
    IMPORTING filelength = lv_len
    TABLES data_tab = lt_bin
    EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0. MESSAGE 'Cannot read file.' TYPE 'E'. ENDIF.

  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING input_length = lv_len
    IMPORTING buffer = lv_xstring
    TABLES binary_tab = lt_bin.

  TRY.
*      CREATE OBJECT lo_excel_ref EXPORTING xdocument = lv_xstring.
      CREATE OBJECT lo_excel_ref
        EXPORTING
          xdocument     = lv_xstring
          document_name = CONV string( iv_path ). " <<< THÊM DÒNG NÀY
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

   " [QUAN TRỌNG]: Kiểm tra Bound trước khi Assign
  IF lo_data_ref IS NOT BOUND.
    RETURN. " (Lỗi đã được báo trong form con, thoát luôn để tránh Dump)
  ENDIF.

  ASSIGN lo_data_ref->* TO <gt_data_raw>.
  IF <gt_data_raw> IS INITIAL. RETURN. ENDIF.

  " --- 3. Mapping Header ---
*  DELETE <gt_data_raw> INDEX 1. " Xóa tiêu đề

  LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
    DATA(ls_header) = VALUE ztb_so_upload_hd( ). " <<< TYPE MỚI (Z-Table)

    " Mapping MỚI (13 Cột)
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
    ASSIGN COMPONENT 13 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<inco2>). " [MỚI] Location
    " [THÊM MỚI]
*    ASSIGN COMPONENT 17 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<order_reason>).

    CHECK <h_temp_id> IS ASSIGNED AND <h_temp_id> IS NOT INITIAL.

    DATA: lv_req_dats TYPE dats.
    IF <req_date> IS ASSIGNED. PERFORM convert_date_ddmmyyyy USING <req_date> CHANGING lv_req_dats. ENDIF.
    " (Gán vào Structure Z-Table)
    ls_header-req_id           = iv_req_id.      " <<< REQ_ID từ tham số
    ls_header-status           = 'NEW'.          " <<< Status mặc định
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
    ls_header-REQ_DATE = lv_req_dats.
    ls_header-pmnttrms         = COND #( WHEN <pmnttrms>   IS ASSIGNED THEN <pmnttrms> ).
    ls_header-incoterms        = COND #( WHEN <incoterms>  IS ASSIGNED THEN <incoterms> ).
    ls_header-inco2            = COND #( WHEN <inco2>      IS ASSIGNED THEN <inco2> ).
*    ls_header-order_reason = COND #( WHEN <order_reason> IS ASSIGNED THEN <order_reason> ).

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

    " [FIX]: Khai báo biến chuyển đổi
    DATA: lv_itm_in TYPE string, lv_itm_out TYPE posnr_va.

    IF <item_no> IS ASSIGNED AND <item_no> IS NOT INITIAL.
       lv_itm_in = <item_no>.
       CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_itm_in IMPORTING output = lv_itm_out.
       ls_item-item_no = lv_itm_out.
    ELSE.
       ls_item-item_no = '000010'.
    ENDIF.

    ls_item-material    = COND #( WHEN <matnr> IS ASSIGNED THEN <matnr> ). " [FIX]: Dùng MATERIAL
    ls_item-plant       = COND #( WHEN <plant> IS ASSIGNED THEN <plant> ).
    ls_item-ship_point  = COND #( WHEN <ship_point> IS ASSIGNED THEN <ship_point> ).
    ls_item-store_loc   = COND #( WHEN <stloc> IS ASSIGNED THEN <stloc> ).
    ls_item-quantity    = COND #( WHEN <qty> IS ASSIGNED THEN <qty> ).

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

      " [FIX]: Tái sử dụng biến convert item no
      IF <c_item_no> IS ASSIGNED.
         lv_itm_in = <c_item_no>.
         CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_itm_in IMPORTING output = lv_itm_out.
         ls_cond-item_no = lv_itm_out.
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
*& Form CONVERT_DATE_DDMMYYYY (Improved Version - Handles Excel Serial)
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
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_raw WITH ''.

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

"chú ý 2
FORM perform_mass_upload
  USING
    iv_mode   TYPE c             " Tham số 1: Chế độ ('NEW'/'RESUBMIT')
    iv_req_id TYPE zsd_req_id.   " Tham số 2: ID (Đã được tạo ở PAI)

  DATA: lv_file_path    TYPE string,
        lv_rc           TYPE i,
        lt_filetab      TYPE filetable.

  DATA: lv_log_reqid    TYPE zso_log_213-req_id,
        lv_filename_log TYPE zso_log_213-filename.

  " 1. Tạo ID Log (Log hệ thống, không phải REQ_ID dữ liệu)
  lv_log_reqid = |UPL{ sy-uname+0(3) }{ sy-datum+2(6) }{ sy-uzeit(6) }|.
  REPLACE ALL OCCURRENCES OF '-' IN lv_log_reqid WITH ''.

  zcl_mass_so_logger_213=>log_action(
    iv_reqid  = lv_log_reqid
    iv_action = 'UPLOAD_START'
    iv_status = 'INFO'
    iv_msg    = |User { sy-uname } initiated mass upload ({ iv_mode }).|
    iv_commit = abap_true ).

  " 2. Mở File Dialog
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title      = 'Select Mass Upload File'
      default_extension = 'xlsx'
      file_filter       = 'Excel Files (*.xlsx)|*.xlsx'
    CHANGING
      file_table        = lt_filetab
      rc                = lv_rc
    EXCEPTIONS
      OTHERS            = 4.

  IF sy-subrc <> 0 OR lv_rc = 0.
    MESSAGE 'File selection cancelled.' TYPE 'S'.
    zcl_mass_so_logger_213=>log_action(
      iv_reqid  = lv_log_reqid
      iv_action = 'UPLOAD_CANCEL'
      iv_status = 'W'
      iv_msg    = 'User cancelled file selection.'
      iv_commit = abap_true ).
    RETURN.
  ENDIF.

  READ TABLE lt_filetab INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_file>).
  lv_file_path = <fs_file>-filename.
  lv_filename_log = lv_file_path.

  " 3. Khai báo bảng tạm
  DATA: lt_header_raw TYPE STANDARD TABLE OF ztb_so_upload_hd,
        lt_item_raw   TYPE STANDARD TABLE OF ztb_so_upload_it,
        lt_cond_raw   TYPE STANDARD TABLE OF ztb_so_upload_pr. " [MỚI]

  " --- 4. Đọc File Excel ---
  PERFORM upload_file
    USING    lv_file_path
             iv_req_id
    CHANGING lt_header_raw
             lt_item_raw
             lt_cond_raw. " [MỚI]

*  IF lt_header_raw IS INITIAL.
*    MESSAGE 'No valid data read from file.' TYPE 'W'.
*    zcl_mass_so_logger_213=>log_action(
*      iv_reqid    = lv_log_reqid
*      iv_action   = 'UPLOAD_FAIL'
*      iv_status   = 'FAILED'
*      iv_msg      = 'Empty or invalid file structure.'
*      iv_filename = lv_filename_log
*      iv_commit   = abap_true ).
*    RETURN.
*  ENDIF.

  " 5. Log thành công
  zcl_mass_so_logger_213=>log_action(
    iv_reqid    = lv_log_reqid
    iv_action   = 'UPLOAD_READ_OK'
    iv_status   = 'SUCCESS'
    iv_msg      = |Read { lines( lt_header_raw ) } Headers. Staging ID: { iv_req_id }|
    iv_filename = lv_filename_log
    iv_commit   = abap_true ).

  " --- 5. Lưu vào Z-Table (Staging) ---
  PERFORM save_raw_to_staging
    USING
      iv_mode
      iv_req_id
      lt_header_raw
      lt_item_raw
      lt_cond_raw. " [MỚI] Truyền bảng Condition vào để lưu chung

  " 7. Validate & Phân loại (Logic Mới)
  PERFORM validate_staging_data USING iv_req_id.

  " 8. Load dữ liệu lên ALV
  PERFORM load_data_from_staging USING iv_req_id.

  " 9. Bật cờ hiển thị
  gv_data_loaded = abap_true.

ENDFORM.

"chú ý 2
FORM revalidate_data.

  " 1. Log bắt đầu
  zcl_mass_so_logger_213=>log_action(

*    iv_reqid =  gv_current_req_id
    iv_action = 'REVALIDATE_START'
    iv_status = 'INFO'
    iv_msg = 'User triggered revalidation.'
    iv_commit = abap_true
  ).

  " 1. Ép ALV nhả dữ liệu user vừa sửa vào bảng nội bộ
  " (Chỉ cần gọi cho các Tab đang hiển thị hoặc có thể sửa)
  IF go_grid_hdr_val IS BOUND. go_grid_hdr_val->check_changed_data( ). ENDIF.
  IF go_grid_itm_val IS BOUND. go_grid_itm_val->check_changed_data( ). ENDIF.
  IF go_grid_cnd_val IS BOUND. go_grid_cnd_val->check_changed_data( ). ENDIF.

  IF go_grid_hdr_fail IS BOUND. go_grid_hdr_fail->check_changed_data( ). ENDIF.
  IF go_grid_itm_fail IS BOUND. go_grid_itm_fail->check_changed_data( ). ENDIF.
  IF go_grid_cnd_fail IS BOUND. go_grid_cnd_fail->check_changed_data( ). ENDIF.

" 2. [QUAN TRỌNG] Đồng bộ từ Bảng nội bộ (GT_...) xuống Database (ZTB_...)
  " Nếu thiếu bước này, dữ liệu mới chỉ nằm trên RAM, validate sẽ lấy dữ liệu cũ từ DB!
  PERFORM sync_alv_to_staging_tables.

  " 3. Chạy lại Validate (Dựa trên dữ liệu mới trong DB)
  PERFORM validate_staging_data USING gv_current_req_id.

  " 4. Load lại dữ liệu (Để cập nhật màu sắc và chuyển Tab)
  PERFORM load_data_from_staging USING gv_current_req_id.

  " 6. [BỔ SUNG QUAN TRỌNG]: Vẽ lại ALV để thấy sự thay đổi (Màu sắc, Icon)
  " Nếu không có dòng này, màn hình sẽ không đổi màu dù dữ liệu bên dưới đã đổi.
  PERFORM refresh_all_alvs.

  " 5. Bật cờ để PBO vẽ lại màn hình
  gv_data_loaded = abap_true.

  MESSAGE 'Data saved & re-validated.' TYPE 'S'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form clear_displayed_data
*&---------------------------------------------------------------------*
*& Clears all data from the ALV grids and internal tables.
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM clear_displayed_data .
  zcl_mass_so_logger_213=>log_action( iv_action = 'CLEAR_DATA_UI' iv_status = 'INFO' iv_msg = 'User cleared displayed data.' ).
  " Clear all relevant internal tables
  CLEAR: gt_so_header, gt_so_item,
         gt_so_header_comp, gt_so_item_comp,
         gt_so_header_incomp, gt_so_item_incomp,
         gt_so_header_err, gt_so_item_err.
  " Optional: Clear staging or result tables if applicable
  " CLEAR: gt_staging, gt_result.

  PERFORM update_status_counts.

  " Refresh the ALV displays to show they are empty
  PERFORM refresh_all_alvs.

  MESSAGE 'All displayed data has been cleared.' TYPE 'S'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form PERFORM_SAVE_STAGING
*&---------------------------------------------------------------------*
FORM perform_save_staging.

  DATA: lt_header_to_save TYPE STANDARD TABLE OF ztb_so_heder_213,
        lt_item_to_save   TYPE STANDARD TABLE OF ztb_so_item_213,
        ls_header_db      LIKE LINE OF lt_header_to_save,
        ls_item_db        LIKE LINE OF lt_item_to_save.

  FIELD-SYMBOLS: <h> LIKE LINE OF gt_so_header_comp,
                 <i> LIKE LINE OF gt_so_item_comp.

  " --- Step 1: Gather data and assign status ---

  " Complete Data
  LOOP AT gt_so_header_comp ASSIGNING <h>.
    MOVE-CORRESPONDING <h> TO ls_header_db.
    ls_header_db-proc_status = 'C'. " Status Complete
    APPEND ls_header_db TO lt_header_to_save.
  ENDLOOP.
  LOOP AT gt_so_item_comp ASSIGNING <i>.
    MOVE-CORRESPONDING <i> TO ls_item_db.
    ls_item_db-proc_status = 'C'.   " Status Complete
    APPEND ls_item_db TO lt_item_to_save.
  ENDLOOP.

  " Incomplete Data
  LOOP AT gt_so_header_incomp ASSIGNING <h>.
    MOVE-CORRESPONDING <h> TO ls_header_db.
    ls_header_db-proc_status = 'I'. " Status Incomplete
    APPEND ls_header_db TO lt_header_to_save.
  ENDLOOP.
  LOOP AT gt_so_item_incomp ASSIGNING <i>.
    MOVE-CORRESPONDING <i> TO ls_item_db.
    ls_item_db-proc_status = 'I'.   " Status Incomplete
    APPEND ls_item_db TO lt_item_to_save.
  ENDLOOP.

  " Error Data
  LOOP AT gt_so_header_err ASSIGNING <h>.
    MOVE-CORRESPONDING <h> TO ls_header_db.
    ls_header_db-proc_status = 'E'. " Status Error
    APPEND ls_header_db TO lt_header_to_save.
  ENDLOOP.
  LOOP AT gt_so_item_err ASSIGNING <i>.
    MOVE-CORRESPONDING <i> TO ls_item_db.
    ls_item_db-proc_status = 'E'.   " Status Error
    APPEND ls_item_db TO lt_item_to_save.
  ENDLOOP.

  " --- Step 2: Save to Database ---
  IF lt_header_to_save IS INITIAL AND lt_item_to_save IS INITIAL.
    " Use popup for no data message too
    CALL FUNCTION 'POPUP_TO_DISPLAY_TEXT'
      EXPORTING
        titel     = 'Information'
        textline1 = 'No data available to save.'.
*        popup_type   = 'ICON_INFORMATION'.
    RETURN.
  ENDIF.

  MODIFY ztb_so_heder_213 FROM TABLE @lt_header_to_save.
  DATA(lv_subrc_h) = sy-subrc. DATA(lv_dbcnt_h) = sy-dbcnt.

  MODIFY ztb_so_item_213 FROM TABLE @lt_item_to_save.
  DATA(lv_subrc_i) = sy-subrc. DATA(lv_dbcnt_i) = sy-dbcnt.

  " --- Step 3: Commit, Log, and Show Popup ---
  IF lv_subrc_h = 0 AND lv_subrc_i = 0.
    COMMIT WORK AND WAIT.

    " --- Success Popup ---
    DATA(lv_success_msg) = |Saved { lv_dbcnt_h } header(s) and { lv_dbcnt_i } item(s) to staging tables successfully.|.
    CALL FUNCTION 'POPUP_TO_DISPLAY_TEXT'
      EXPORTING
        titel     = 'Save Successful'
        textline1 = lv_success_msg.
*        popup_type   = 'ICON_INFORMATION'. " Or ICON_MESSAGE_SUCCESS

    " --- Log Success ---
    zcl_mass_so_logger_213=>log_action(
      " iv_reqid = ??? " Need REQ_ID determination
      iv_action = 'SAVE_STAGING'
      iv_status = 'SUCCESS'
      iv_msgty  = 'S'
      iv_msg    = |Saved { lv_dbcnt_h } Headers / { lv_dbcnt_i } Items.|
      iv_commit = abap_true ).

  ELSE.
    ROLLBACK WORK.

    " --- Error Popup ---
    DATA(lv_error_msg) = |Error saving data to staging tables! Operation rolled back. (SUBRC H={ lv_subrc_h } / I={ lv_subrc_i })|.
    CALL FUNCTION 'POPUP_TO_DISPLAY_TEXT'
      EXPORTING
        titel     = 'Save Failed'
        textline1 = 'An error occurred while saving the staging data.'
        textline2 = 'Operation has been rolled back.'
        textline3 = |(Details: SUBRC Header={ lv_subrc_h }, Item={ lv_subrc_i })|.
*        popup_type   = 'ICON_MESSAGE_ERROR'.

    " --- Log Error ---
    zcl_mass_so_logger_213=>log_action(
      " iv_reqid = ??? "
      iv_action = 'SAVE_STAGING'
      iv_status = 'FAILED'
      iv_msgty  = 'E'
      iv_msg    = |Save failed. Subrc H={ lv_subrc_h }, I={ lv_subrc_i }|
      iv_commit = abap_true ).

  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form GENERATE_REQUEST_ID (Logic số tăng dần cho CHAR10)
*&---------------------------------------------------------------------*
FORM generate_request_id CHANGING cv_req_id TYPE zsd_req_id. " (Dùng đúng Type CHAR10 của bạn)
  DATA: lv_max_id TYPE zsd_req_id,
        lv_num    TYPE n LENGTH 7. " 7 số (vì 'REQ' chiếm 3 ký tự)

  " 1. Tìm mã ID lớn nhất hiện có trong bảng Header
  SELECT MAX( req_id )
    FROM ztb_so_upload_hd
    INTO lv_max_id.

  " 2. Tính toán ID mới
  IF lv_max_id IS INITIAL.
    " Trường hợp chưa có dữ liệu nào: Bắt đầu từ 1
    lv_num = 1.
  ELSE.
    " Lấy phần số (bỏ chữ 'REQ' ở đầu) và cộng 1
    " Ví dụ: 'REQ0000015' -> Lấy '0000015' -> Cộng 1 = 16
    lv_num = lv_max_id+3(7).
    lv_num = lv_num + 1.
  ENDIF.

  " 3. Gép thành chuỗi hoàn chỉnh (Ví dụ: REQ0000016)
  cv_req_id = |REQ{ lv_num }|.

  " (Tùy chọn: Nếu bạn muốn chắc chắn hơn, có thể check lại trong bảng Item)
ENDFORM.

"chú ý 2
FORM perform_create_sales_orders.

  " 1. Khai báo biến
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

  DATA: lt_incomplete     TYPE TABLE OF bapiincomp,
        ls_incomplete     TYPE bapiincomp.

  DATA: lv_salesdocument   TYPE vbak-vbeln,
        lv_item_no         TYPE posnr_va,
        lt_bapi_errors     TYPE ztty_validation_error,
        lv_vbtyp           TYPE vbak-vbtyp,
        lv_bus_obj         TYPE char10,
        lv_has_child_error TYPE abap_bool.

  IF gt_hd_val IS INITIAL.
    MESSAGE 'No validated data available to process.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " --- 2. LOOP XỬ LÝ ---
  LOOP AT gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_hd>)
       WHERE status = 'READY' OR status = 'INCOMP'.

    " [FIX]: Dọn dẹp bộ nhớ triệt để trước khi xử lý đơn mới
    CALL FUNCTION 'SD_SALES_DOCUMENT_INIT'
      EXPORTING
        status_buffer_refresh = 'X'
        refresh_v45i          = 'X'.
              .
    CLEAR: ls_header_in, ls_header_inx, lv_salesdocument, lv_vbtyp, lv_bus_obj, lv_has_child_error.
    REFRESH: lt_items_in, lt_items_inx, lt_partners, lt_schedules_in,
             lt_schedules_inx, lt_conditions_in, lt_conditions_inx,
             lt_return, lt_bapi_errors, lt_incomplete.

    " A. CHECK LỖI CON
    LOOP AT gt_it_val TRANSPORTING NO FIELDS WHERE temp_id = <fs_hd>-temp_id AND status = 'ERROR'.
      lv_has_child_error = abap_true. EXIT.
    ENDLOOP.
    IF lv_has_child_error = abap_false.
      LOOP AT gt_pr_val TRANSPORTING NO FIELDS WHERE temp_id = <fs_hd>-temp_id AND status = 'ERROR'.
        lv_has_child_error = abap_true. EXIT.
      ENDLOOP.
    ENDIF.
    IF lv_has_child_error = abap_true.
      <fs_hd>-message = 'Skipped: Contains items/conditions with errors.'.
      UPDATE ztb_so_upload_hd SET message = <fs_hd>-message
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      CONTINUE.
    ENDIF.

    " B. CHECK LOẠI CHỨNG TỪ
    DATA(lv_auart) = <fs_hd>-order_type.
    TRANSLATE lv_auart TO UPPER CASE.
    CONDENSE lv_auart NO-GAPS.

    SELECT SINGLE vbtyp FROM tvak INTO lv_vbtyp WHERE auart = lv_auart.

    " [FIX GOTO]: Xử lý lỗi ngay tại đây thay vì nhảy label
    IF sy-subrc <> 0.
      <fs_hd>-message = |Order Type { lv_auart } not found in TVAK|.
      <fs_hd>-status  = 'FAILED'.
      <fs_hd>-icon    = icon_led_red.

      " [FIX ICON]: Bỏ cột ICON ra khỏi câu lệnh UPDATE
      UPDATE ztb_so_upload_hd
        SET status = 'FAILED'
            message = <fs_hd>-message
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      " Update Item/Cond con thành Failed
      UPDATE ztb_so_upload_it SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_pr SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      CONTINUE. " Bỏ qua, sang dòng tiếp theo
    ENDIF.

    " C. MAPPING DỮ LIỆU
    " ... (Các logic Mapping giữ nguyên) ...
    ls_header_in-doc_type = lv_auart.
    ls_header_in-sales_org = <fs_hd>-sales_org.
    ls_header_in-distr_chan = <fs_hd>-sales_channel.
    ls_header_in-division = <fs_hd>-sales_div.
*    ls_header_in-ord_reason = <fs_hd>-order_reason.
    ls_header_in-req_date_h = <fs_hd>-req_date.
    ls_header_in-price_date = <fs_hd>-price_date.
    ls_header_in-purch_no_c = <fs_hd>-cust_ref.
    ls_header_in-pmnttrms   = <fs_hd>-pmnttrms.
    ls_header_in-incoterms1 = <fs_hd>-incoterms.
    ls_header_in-incoterms2 = <fs_hd>-inco2.
    ls_header_in-currency   = <fs_hd>-currency.

    APPEND VALUE #( partn_role = 'AG' partn_numb = <fs_hd>-sold_to_party ) TO lt_partners.
    APPEND VALUE #( partn_role = 'WE' partn_numb = <fs_hd>-sold_to_party ) TO lt_partners.

    LOOP AT gt_it_val ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE temp_id = <fs_hd>-temp_id.
       lv_item_no = <fs_it>-item_no.
       APPEND VALUE #( itm_number = lv_item_no material = <fs_it>-material target_qty = <fs_it>-quantity target_qu = <fs_it>-unit plant = <fs_it>-plant store_loc = <fs_it>-store_loc ) TO lt_items_in.
       IF lv_vbtyp = 'C' OR lv_vbtyp = 'H' OR lv_vbtyp = 'I'.
         APPEND VALUE #( itm_number = lv_item_no req_qty = <fs_it>-quantity ) TO lt_schedules_in.
       ENDIF.
    ENDLOOP.

    LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_pr>) WHERE temp_id = <fs_hd>-temp_id.
       APPEND VALUE #( itm_number = <fs_pr>-item_no cond_type = <fs_pr>-cond_type cond_value = <fs_pr>-amount currency = <fs_pr>-currency cond_unit = <fs_pr>-uom cond_p_unt = <fs_pr>-per ) TO lt_conditions_in.
    ENDLOOP.

    " D. GỌI HÀM (Unified)
    CASE lv_vbtyp.
      WHEN 'C'. lv_bus_obj = 'BUS2032'.
      WHEN 'H'. lv_bus_obj = 'BUS2102'.
      WHEN 'I'. lv_bus_obj = 'BUS2032'.
      WHEN 'K'. lv_bus_obj = 'BUS2094'.
      WHEN 'L'. lv_bus_obj = 'BUS2096'.
      WHEN 'G'. lv_bus_obj = 'BUS2034'.
      WHEN OTHERS. lv_bus_obj = 'BUS2032'.
    ENDCASE.

    CALL FUNCTION 'SD_SALESDOCUMENT_CREATE'
      EXPORTING sales_header_in = ls_header_in business_object = lv_bus_obj
      IMPORTING salesdocument_ex = lv_salesdocument
      TABLES return = lt_return sales_items_in = lt_items_in sales_partners = lt_partners sales_schedules_in = lt_schedules_in sales_conditions_in = lt_conditions_in incomplete_log = lt_incomplete
      EXCEPTIONS others = 1.

    " E. XỬ LÝ KẾT QUẢ
    IF lv_salesdocument IS NOT INITIAL.
      " === SUCCESS ===
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

      <fs_hd>-status   = 'SUCCESS'.
      <fs_hd>-vbeln_so = lv_salesdocument.

      IF lt_incomplete IS NOT INITIAL.
         <fs_hd>-message = |Doc { lv_salesdocument } created (Incomplete). Check Log.|.
         <fs_hd>-icon    = icon_led_yellow.

         DELETE FROM ztb_so_error_log WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

         LOOP AT lt_incomplete INTO ls_incomplete.
            CALL METHOD zcl_sd_mass_logger=>save_single_error
              EXPORTING
                iv_req_id    = <fs_hd>-req_id
                iv_temp_id   = <fs_hd>-temp_id
                iv_item_no   = COND #( WHEN ls_incomplete-itm_number IS INITIAL THEN '000000' ELSE ls_incomplete-itm_number )
                iv_fieldname = ls_incomplete-field_name
                iv_msg_type  = 'W'
                iv_message   = |Field { ls_incomplete-field_text } is missing|.
         ENDLOOP.
      ELSE.
         <fs_hd>-message = |Doc { lv_salesdocument } created successfully.|.
         <fs_hd>-icon    = icon_led_green.
         DELETE FROM ztb_so_error_log WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

         IF <fs_hd>-icon = icon_led_green AND ( lv_vbtyp = 'C' OR lv_vbtyp = 'I' OR lv_vbtyp = 'H' ).
            PERFORM perform_auto_delivery USING lv_salesdocument CHANGING <fs_hd>.
         ENDIF.
      ENDIF.

      " [FIX ICON]: Xóa cột ICON trong câu lệnh UPDATE
      UPDATE ztb_so_upload_hd
        SET status = 'SUCCESS'
            vbeln_so = lv_salesdocument
            vbeln_dlv = <fs_hd>-vbeln_dlv
            message = <fs_hd>-message
*            icon      = <fs_hd>-icon  " <<< Nhớ update cột này
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      UPDATE ztb_so_upload_it SET status = 'SUCCESS' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_pr SET status = 'SUCCESS' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

       " [FIX]: Commit lần nữa cho chắc chắn việc update bảng Z (Dù BAPI Commit đã chạy)
      COMMIT WORK.
    ELSE.
      " === FAILED ===
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      <fs_hd>-status = 'FAILED'.
      <fs_hd>-icon   = icon_led_red.

      " [THÊM MỚI]: Xóa sạch log lỗi CŨ của riêng dòng này trước khi ghi lỗi MỚI
      " Để tránh việc lỗi cũ (đã sửa) vẫn còn tồn tại lai rai
      DELETE FROM ztb_so_error_log
        WHERE req_id  = <fs_hd>-req_id
          AND temp_id = <fs_hd>-temp_id.

      LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
        <fs_hd>-message = ls_ret-message.

        " [FIX LOGIC MAPPING]: Map trường BAPI sang trường Z để tô màu được
        DATA: lv_z_fieldname TYPE fieldname.

        CASE ls_ret-parameter.
           WHEN 'ORDER_HEADER_IN'.
              IF ls_ret-field = 'DOC_TYPE'.   lv_z_fieldname = 'ORDER_TYPE'. ENDIF.
              IF ls_ret-field = 'SALES_ORG'.  lv_z_fieldname = 'SALES_ORG'.  ENDIF.
              IF ls_ret-field = 'DISTR_CHAN'. lv_z_fieldname = 'DIST_CHNL'.  ENDIF.
              IF ls_ret-field = 'DIVISION'.   lv_z_fieldname = 'DIVISION'.   ENDIF.
              IF ls_ret-field = 'REQ_DATE_H'. lv_z_fieldname = 'REQ_DATE'.   ENDIF.
              " ... Thêm các trường khác ...
           WHEN 'ORDER_ITEMS_IN'.
              IF ls_ret-field = 'MATERIAL'.   lv_z_fieldname = 'MATERIAL'.   ENDIF.
              IF ls_ret-field = 'TARGET_QTY'. lv_z_fieldname = 'QUANTITY'.   ENDIF.
              IF ls_ret-field = 'PLANT'.      lv_z_fieldname = 'PLANT'.      ENDIF.
           WHEN OTHERS.
              lv_z_fieldname = 'BAPI_ERROR'. " Không tô màu cụ thể, chỉ báo đỏ dòng
        ENDCASE.


*        APPEND VALUE #( req_id = <fs_hd>-req_id temp_id = <fs_hd>-temp_id item_no = '000000' fieldname = 'BAPI_ERROR' msg_type = 'E' message = ls_ret-message ) TO lt_bapi_errors.
          APPEND VALUE #(
           req_id    = <fs_hd>-req_id
           temp_id   = <fs_hd>-temp_id
           item_no   = COND #( WHEN ls_ret-parameter CS 'ITEM' THEN '000010' ELSE '000000' ) " (Cần logic map Row index chuẩn hơn nếu nhiều item)
           fieldname = lv_z_fieldname " <-- Dùng tên đã map
           msg_type  = 'E'
           message   = ls_ret-message
        ) TO lt_bapi_errors.

      ENDLOOP.
      IF <fs_hd>-message IS INITIAL. <fs_hd>-message = 'Creation Failed'. ENDIF.
      IF lt_bapi_errors IS NOT INITIAL.
        CALL METHOD zcl_sd_mass_logger=>save_errors_to_db EXPORTING it_errors = lt_bapi_errors.
      ENDIF.

      " [FIX ICON]: Xóa cột ICON trong câu lệnh UPDATE
      UPDATE ztb_so_upload_hd
        SET status = 'FAILED'
            message = <fs_hd>-message
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      UPDATE ztb_so_upload_it SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_pr SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      " [FIX 2]: QUAN TRỌNG NHẤT - COMMIT WORK
      " Phải Commit để lưu trạng thái FAILED và Log Lỗi vào DB ngay lập tức.
      " Nếu không có dòng này, khi vòng lặp bị crash ở dòng sau, lỗi này sẽ mất.
      COMMIT WORK.
    ENDIF.

  ENDLOOP.

  PERFORM load_data_from_staging USING gv_current_req_id.
  gv_data_loaded = abap_true.
  MESSAGE 'Processing completed.' TYPE 'S'.

ENDFORM.

"chú ý 2
FORM perform_auto_delivery
  USING    iv_vbeln_so TYPE vbak-vbeln
  CHANGING cs_header   TYPE ty_header. " (Bao gồm ZTB_SO_UPLOAD_HD)

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

    " (Tùy chọn: Gọi FORM lưu vào ZTB_DELIVERY_213 cũ nếu bạn muốn giữ bảng đó)
    " PERFORM save_delivery_to_ztable ...

  ELSE.
    " === THẤT BẠI ===
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    " Lấy thông báo lỗi
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      lv_msg = ls_ret-message.
      EXIT.
    ENDLOOP.
    if lv_msg is initial. lv_msg = 'Unknown error'. endif.

    cs_header-message = |SO { iv_vbeln_so } created. ❌ Delivery Failed: { lv_msg }|.

    " Update Message vào DB Staging
    UPDATE ztb_so_upload_hd
    SET vbeln_dlv = lv_delivery   " <<< Quan trọng
           message   = cs_header-message
      WHERE req_id  = cs_header-req_id
        AND temp_id = cs_header-temp_id.
  ENDIF.

ENDFORM.

"chú ý 2
FORM perform_auto_pick_delivery
  USING    iv_vbeln_dlv TYPE likp-vbeln
  CHANGING cs_header    TYPE ty_header.

  DATA: lt_lips  TYPE TABLE OF lips,
        ls_lips  TYPE lips.
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
*& Form SAVE_DELIVERY_TO_ZTABLE (Copied from ZPG_..._F01)
*&---------------------------------------------------------------------*
*& Save created Outbound Delivery info into ZTB_DELIVERY_213
*&---------------------------------------------------------------------*
FORM save_delivery_to_ztable
  USING iv_vbeln_so    TYPE vbak-vbeln
        iv_vbeln_dlv   TYPE likp-vbeln
        iv_ship_point  TYPE vstel
        iv_due_date    TYPE dats
        iv_vkorg       TYPE vkorg
        iv_vtweg       TYPE vtweg
        iv_spart       TYPE spart
        iv_kunnr_sold  TYPE kunnr
        iv_kunnr_ship  TYPE kunnr
        iv_bstkd       TYPE bstnk
        iv_message     TYPE string.

  DATA: ls_dlv TYPE ztb_delivery_213.

  " Giả định bạn đã thêm 'TABLES ztb_delivery_213.' vào ...TOP
  CLEAR ls_dlv.
  ls_dlv-vbeln_so   = iv_vbeln_so.
  ls_dlv-vbeln_dlv  = iv_vbeln_dlv.
  ls_dlv-vkorg      = iv_vkorg.
  ls_dlv-vtweg      = iv_vtweg.
  ls_dlv-spart      = iv_spart.
  ls_dlv-kunnr_sold = iv_kunnr_sold.
  ls_dlv-kunnr_ship = iv_kunnr_ship.
  ls_dlv-bstkd      = iv_bstkd.
  ls_dlv-lfart      = 'LF'.       " Default delivery type
  ls_dlv-erdat      = sy-datum.
  ls_dlv-ernam      = sy-uname.
  ls_dlv-status     = 'DELIVERED'.
  ls_dlv-message    = iv_message.

  MODIFY ztb_delivery_213 FROM ls_dlv.
  " COMMIT WORK.  <<< !!! ĐÃ XÓA BỎ COMMIT WORK Ở ĐÂY !!!
  " (COMMIT sẽ được gọi bởi BAPI_TRANSACTION_COMMIT bên ngoài)

ENDFORM.


FORM load_tracking_data.

  CALL FUNCTION 'BUFFER_REFRESH_ALL'.

  CLEAR gt_tracking.

  " 1. Chuẩn hóa input
  PERFORM normalize_search_inputs.

  " =========================================================
  " [LOGIC] TÌM NGƯỢC SO TỪ DELIVERY/BILLING
  " =========================================================
  DATA: lr_so_range TYPE RANGE OF vbak-vbeln,
        ls_so_range LIKE LINE OF lr_so_range.
  DATA: lv_search_active TYPE abap_bool.

  " A. Nếu user nhập Sales Order
  IF gv_vbeln IS NOT INITIAL.
    ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = gv_vbeln.
    APPEND ls_so_range TO lr_so_range.
    lv_search_active = abap_true.
  ENDIF.

  " ---------------------------------------------------------
  " B. Nếu user nhập Delivery
  " ---------------------------------------------------------
  IF gv_deliv IS NOT INITIAL.
    lv_search_active = abap_true.

    " Điều kiện: vbtyp_n IN ('J', 'T') để đảm bảo input đúng là Delivery hoặc Return Delivery.
    SELECT SINGLE vbelv INTO @ls_so_range-low FROM vbfa
      WHERE vbeln   = @gv_deliv
        AND vbtyp_n IN ('J', 'T').

    IF sy-subrc = 0.
      ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'.
      APPEND ls_so_range TO lr_so_range.
    ENDIF.
  ENDIF.

  " C. Nếu user nhập Billing
  IF gv_bill IS NOT INITIAL.
    lv_search_active = abap_true.
    DATA: lv_pre_doc TYPE vbeln_von,
          lv_cat     TYPE vbtyp.

    SELECT SINGLE vbelv, vbtyp_v INTO (@lv_pre_doc, @lv_cat) FROM vbfa
      WHERE vbeln = @gv_bill AND vbtyp_n = 'M'.

    IF sy-subrc = 0.
      IF lv_cat = 'C'.
        ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = lv_pre_doc.
        APPEND ls_so_range TO lr_so_range.
      ELSEIF lv_cat = 'J'.
        SELECT SINGLE vbelv INTO @ls_so_range-low FROM vbfa
          WHERE vbeln = @lv_pre_doc AND vbtyp_v = 'C'.
        IF sy-subrc = 0.
          ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'.
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

  " =========================================================
  " 2. KHAI BÁO RANGE CHO 3 SALES ORG
  " =========================================================
  DATA: lr_vkorg_project TYPE RANGE OF vkorg.
  lr_vkorg_project = VALUE #( sign = 'I' option = 'EQ' ( low = 'CNSG' ) ( low = 'CNHN' ) ( low = 'CNDN' ) ).

  " =========================================================
  " 3. XỬ LÝ BIẾN SEARCH INPUT
  " =========================================================
  CONDENSE: gv_vkorg, gv_vtweg, gv_spart, gv_ernam.
  TRANSLATE: gv_vkorg TO UPPER CASE, gv_vtweg TO UPPER CASE,
             gv_spart TO UPPER CASE, gv_ernam TO UPPER CASE.
  DATA(lv_vtweg_pattern) = |%{ gv_vtweg }|.
  DATA(lv_spart_pattern) = |%{ gv_spart }|.

  " =========================================================
  " 4. SELECT DỮ LIỆU CHÍNH
  " =========================================================
  SELECT DISTINCT
         vbak~vbeln   AS sales_document,
         vbak~auart   AS order_type,
         vbak~erdat   AS document_date,
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

  " Sắp xếp SO mới nhất lên đầu (document_date DESC, sales_document DESC)
  SORT gt_tracking BY document_date DESCENDING sales_document DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_tracking COMPARING sales_document.

  " =========================================================
  " 5. LOGIC CHI TIẾT TRONG LOOP
  " =========================================================
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
        " -------------------------------------------------------
        " NHÓM ZRAS: LOGIC PLAN-CENTRIC
        " -------------------------------------------------------
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

        " Sắp xếp Billing theo ngày tạo để map dần vào Plan (FIFO)
        SORT lt_bill_sort BY erdat ASCENDING vbeln ASCENDING.

        " --- LẤY TOÀN BỘ PLAN ---
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

            " --- Logic FIFO: Lấy bill có sẵn gán vào ---
            READ TABLE lt_bill_sort INTO ls_bill_sort INDEX 1.
            IF sy-subrc = 0.
              ls_row-billing_document = ls_bill_sort-vbeln.

              IF ls_bill_sort-erdat <> ls_plan-afdat.
                ls_row-process_phase = |Billing Created ({ ls_bill_sort-erdat DATE = USER })|.
              ELSE.
                ls_row-process_phase = 'Billing Created'.
              ENDIF.

              ls_row-phase_icon = icon_wd_text_view.

              PERFORM get_fi_status CHANGING ls_row.

              DELETE lt_bill_sort INDEX 1.
            ELSE.
              " Không còn bill nào
              IF ls_plan-fksaf = 'C'.
                ls_row-process_phase = 'Completed (No Doc Found)'.
                ls_row-phase_icon    = icon_green_light.
              ELSEIF ls_plan-faksp IS NOT INITIAL.
                ls_row-process_phase = |Blocked Plan: { ls_plan-afdat DATE = USER }|.
                ls_row-phase_icon    = icon_red_light.
              ELSE.
* ls_row-process_phase = |Ready Billing: { ls_plan-afdat DATE = USER }|.
                ls_row-process_phase = |Order created, ready billing: { ls_plan-afdat DATE = USER }|.
                ls_row-phase_icon    = icon_create.
              ENDIF.
            ENDIF.

            APPEND ls_row TO lt_tracking_final.
            lv_has_entry = abap_true.
          ENDLOOP.
        ENDIF.

        IF lv_has_entry = abap_false.
          ls_row-process_phase = 'Ready / No Plan'.
          APPEND ls_row TO lt_tracking_final.
        ENDIF.

        " -------------------------------------------------------
        " NHÓM CÓ DELIVERY (ZORR, ZBB, ZFOC, ZRET)
        " -------------------------------------------------------
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.
        CLEAR ls_vbfa_del.
        DATA(lv_vbtyp_target) = COND vbtyp( WHEN ls_row-order_type = 'ZRET' THEN 'T' ELSE 'J' ).

        SELECT SINGLE vbeln, vbtyp_n FROM vbfa INTO CORRESPONDING FIELDS OF @ls_vbfa_del
          WHERE vbelv = @ls_row-sales_document AND vbtyp_n = @lv_vbtyp_target.

        IF sy-subrc = 0.
          ls_row-delivery_document = ls_vbfa_del-vbeln.
        ENDIF.

        IF ls_row-order_type = 'ZRET'.
          " ZRET: Tìm từ SO
          SELECT vbeln FROM vbfa INTO @ls_row-billing_document
            WHERE vbelv   = @ls_row-sales_document
              AND vbtyp_n IN ('M', 'O', 'P')
            ORDER BY vbeln DESCENDING. " <--- Lấy số lớn nhất (Mới nhất)
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

        " -------------------------------------------------------
        " NHÓM KHÁC (ZDR, ZCRR, ZTP, ZSC...)
        " -------------------------------------------------------
      WHEN OTHERS.
        " Lấy Bill mới nhất cho nhóm Others
        SELECT vbeln FROM vbfa INTO @ls_row-billing_document
          WHERE vbelv = @ls_row-sales_document
            AND vbtyp_n IN ('M', 'O', 'P')
          ORDER BY vbeln DESCENDING. " <--- Lấy số lớn nhất
          EXIT.
        ENDSELECT.

        PERFORM get_fi_status CHANGING ls_row.
        APPEND ls_row TO lt_tracking_final.

    ENDCASE.
  ENDLOOP.

  gt_tracking = lt_tracking_final.
  PERFORM denormalize_search_inputs.
ENDFORM.

" =========================================================
" FORM LẤY FI & CANCEL
" =========================================================
FORM get_fi_status CHANGING cs_row TYPE ty_tracking.

  IF cs_row-billing_document IS INITIAL.
    RETURN.
  ENDIF.

  DATA: lv_bill_doc_canc TYPE vbrk-vbeln.
  CLEAR: lv_bill_doc_canc.

  " 1. Lấy FI Doc từ BKPF (Dùng AWKEY)
  SELECT SINGLE belnr FROM bkpf INTO @cs_row-fi_doc_billing
    WHERE awtyp = 'VBRK' AND awkey = @cs_row-billing_document.

  " 2. Lấy Billing Cancelled (N)
  SELECT SINGLE vbeln FROM vbfa INTO @lv_bill_doc_canc
    WHERE vbelv   = @cs_row-billing_document
      AND vbtyp_v IN ('M', 'O', 'P')
      AND vbtyp_n = 'N'.

  IF sy-subrc = 0 AND lv_bill_doc_canc IS NOT INITIAL.
    cs_row-bill_doc_cancel = lv_bill_doc_canc.

    " 3. Lấy FI Cancel
    SELECT SINGLE belnr FROM bkpf INTO @cs_row-fi_doc_cancel
      WHERE awtyp = 'VBRK' AND awkey = @lv_bill_doc_canc.
  ENDIF.

  " === [FIX MỚI]: Logic Release Flag (Cờ báo chưa có FI) ===
  IF cs_row-fi_doc_billing IS INITIAL.

    " Nếu là ZFOC thì KHÔNG báo lỗi (vì ZFOC xong ở Billing)
    IF cs_row-order_type = 'ZFOC'.
       CLEAR cs_row-release_flag.
    ELSE.
       " Các loại khác: Thiếu FI -> Báo cờ vàng
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
    " Không clear <fs_phase>-process_phase ngay vì ZRAS cần giữ giá trị cũ nếu chưa có Bill

    CASE <fs_phase>-order_type.

      "-------------------------------------------------------
      " NHÓM ZRAS: BILLING PLAN
      "-------------------------------------------------------
      WHEN 'ZRAS'.

        " Check Billing trước
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

           IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
              <fs_phase>-process_phase = 'FI Doc created'.
              <fs_phase>-phase_icon    = icon_payment.
           ELSE.
              <fs_phase>-process_phase = 'Billing created'.
              <fs_phase>-phase_icon    = icon_wd_text_view.
           ENDIF.

        ELSE.
           " Nếu chưa có Billing -> Giữ nguyên logic Plan cũ
           IF <fs_phase>-process_phase IS INITIAL.
              <fs_phase>-process_phase = 'Ready / No Plan'.
           ENDIF.

           " Gán icon cho ZRAS
           IF <fs_phase>-phase_icon IS INITIAL.
             IF <fs_phase>-process_phase CP 'Completed*'.
               <fs_phase>-phase_icon = icon_green_light.
             ELSEIF <fs_phase>-process_phase CP 'Blocked*'.
               <fs_phase>-phase_icon = icon_red_light.
             ELSE.
               <fs_phase>-phase_icon = icon_create.
             ENDIF.
           ENDIF.
        ENDIF.

      "-------------------------------------------------------
      " NHÓM 1 & 2: CÓ DELIVERY (ZORR, ZBB, ZFOC, ZRET)
      "-------------------------------------------------------
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        CLEAR <fs_phase>-process_phase.

        " 1. Check Billing trước
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

          " === Logic ZFOC ===
          IF <fs_phase>-order_type = 'ZFOC'.
            <fs_phase>-process_phase = 'Billing created (Completed)'.
            <fs_phase>-phase_icon    = icon_green_light.
          ELSE.
            " Các loại khác: Phải có FI mới Xanh
            IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
              <fs_phase>-process_phase = 'FI Doc created'.
              <fs_phase>-phase_icon    = icon_payment.
            ELSE.
              <fs_phase>-process_phase = 'Billing created'.
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
               <fs_phase>-process_phase = 'PGI/PGR Posted, ready Billing'.
               <fs_phase>-phase_icon    = icon_wd_text_view.

            " --- Chưa Post kho (Chờ PGI/PGR) ---
            ELSE.
               <fs_phase>-process_phase = 'Delivery created, ready PGI/PGR'.
               <fs_phase>-phase_icon    = icon_delivery.
            ENDIF.

          ELSE.
            " 3. Chưa có Delivery -> Trạng thái: Order created
            <fs_phase>-process_phase = 'Order created'.
            <fs_phase>-phase_icon    = icon_order.
          ENDIF.
        ENDIF.

      "-------------------------------------------------------
      " NHÓM 3: KHÔNG DELIVERY (ZDR, ZCRR, ZTP, ZSC...)
      "-------------------------------------------------------
      WHEN OTHERS.

        CLEAR <fs_phase>-process_phase.

        " Nhóm này không quan tâm Delivery, check thẳng Billing
        IF <fs_phase>-billing_document IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.

          IF <fs_phase>-fi_doc_billing IS NOT INITIAL.
            <fs_phase>-process_phase = 'FI Doc created'.
            <fs_phase>-phase_icon    = icon_payment.
          ELSE.
            <fs_phase>-process_phase = 'Billing created'.
            <fs_phase>-phase_icon    = icon_wd_text_view.
          ENDIF.

        ELSE.
          " Chưa có Billing -> Trạng thái: Order created
          <fs_phase>-process_phase = 'Order created'.
          <fs_phase>-phase_icon    = icon_order.
        ENDIF.

    ENDCASE.

  ENDLOOP.

ENDFORM.

FORM filter_process_phase.

  IF cb_phase IS INITIAL OR cb_phase = 'ALL' OR gt_tracking IS INITIAL.
    EXIT.
  ENDIF.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
  CLEAR lt_keep.

  LOOP AT gt_tracking INTO gs_tracking.

    CASE cb_phase.
      WHEN 'ORD'.

        IF gs_tracking-process_phase = 'Order created'.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN 'DEL'.
        IF gs_tracking-process_phase CP 'Delivery created*'.
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
       AND vbak~netwr = 0
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

      "--- COM (Giữ nguyên) ---
    WHEN 'COM'.
      DATA: lt_complete TYPE STANDARD TABLE OF vbak-vbeln.
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
       AND vbak~uvall = 'C'
        INTO TABLE @lt_complete.

      IF sy-subrc = 0.
        SORT lt_complete.
        LOOP AT gt_tracking INTO gs_tracking.
          DATA(lv_vbeln_cmp) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_complete WITH KEY table_line = lv_vbeln_cmp
                     BINARY SEARCH TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.
      ENDIF.

      "--- BLK (Giữ nguyên) ---
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

      "==================================================================
      " SỬA LỖI S/4HANA: ABSTK CHỈ CÓ Ở HEADER (VBAK)
      "==================================================================
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

      " Tìm Delivery (J/T) mà WBSTK KHÁC 'C'
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

  " =========================================================
  " BƯỚC A: NẾU LỌC 'CANC' HOẶC 'OPEN' -> CẦN TÌM LIST ĐÃ HỦY TRƯỚC
  " =========================================================
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

  " =========================================================
  " BƯỚC B: LỌC DỮ LIỆU CHÍNH
  " =========================================================
  LOOP AT gt_tracking INTO gs_tracking.

    CASE cb_bdsta.

        " --- 1. COMPLETED ---
      WHEN 'COMP'.
        " Logic: Đã có FI Document HOẶC (Là ZFOC và đã có Billing)
        IF gs_tracking-fi_doc_billing IS NOT INITIAL.
          APPEND gs_tracking TO lt_keep.
        ELSEIF gs_tracking-order_type = 'ZFOC' AND gs_tracking-billing_document IS NOT INITIAL.
          " [FIX]: ZFOC có Billing là tính Completed
          APPEND gs_tracking TO lt_keep.
        ENDIF.

        " --- 2. CANCELLED ---
      WHEN 'CANC'.
        DATA(lv_vbeln_canc) = |{ gs_tracking-sales_document ALPHA = IN }|.
        READ TABLE lt_canceled_so WITH TABLE KEY table_line = lv_vbeln_canc
                                  TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND gs_tracking TO lt_keep.
        ENDIF.

        " --- 3. OPEN: Billing created, no FI doc (CHỈ LẤY LỖI ĐỎ) ---
      WHEN 'OPEN'.
        DATA(lv_vbeln_open) = |{ gs_tracking-sales_document ALPHA = IN }|.

        " A. Loại bỏ nếu nó nằm trong danh sách Hủy
        READ TABLE lt_canceled_so WITH TABLE KEY table_line = lv_vbeln_open
                                  TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.

          " B. Logic: Đã có Billing + Chưa có FI + KHÔNG PHẢI ZFOC
          IF gs_tracking-billing_document IS NOT INITIAL
             AND gs_tracking-fi_doc_billing IS INITIAL
             AND gs_tracking-order_type <> 'ZFOC'. " <--- [FIX]: Loại bỏ ZFOC khỏi danh sách lỗi
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDIF.

    ENDCASE.
  ENDLOOP.

  " 3. Gán kết quả lọc vào bảng ALV
  gt_tracking = lt_keep.

ENDFORM.

FORM filter_pricing_procedure.

  "=========================================================
  " Nếu user đang lọc 'Incomplete', KHÔNG được lọc pricing.
  " (Vì SO Incomplete sẽ không có pricing và sẽ bị xóa)
  "=========================================================
  IF cb_sosta = 'INC'.
    EXIT. " Thoát khỏi FORM này, không làm gì cả
  ENDIF.

  " Nếu không có data thì thoát (cho các bộ lọc khác)
  CHECK gt_tracking IS NOT INITIAL.

  DATA: lt_filtered TYPE STANDARD TABLE OF ty_tracking.

  " 1. Lấy dữ liệu TVAK (Document Pricing)
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

  " 2. Lấy dữ liệu KNVV (Customer Pricing)
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

  " 3. Lấy dữ liệu T683V (Pricing Procedure Determination)
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
*  ---------------------------------------------------------------------*
*    Chuẩn hóa input
*  ---------------------------------------------------------------------*
FORM normalize_search_inputs.

  IF gv_sarea IS NOT INITIAL.
    REPLACE ALL OCCURRENCES OF '/' IN gv_sarea WITH space.
    REPLACE ALL OCCURRENCES OF '-' IN gv_sarea WITH space.

    " 2. Tách chuỗi vào 3 biến dùng để query DB
    SPLIT gv_sarea AT space INTO gv_vkorg gv_vtweg gv_spart.

    " 3. Xóa khoảng trắng thừa
    CONDENSE: gv_vkorg, gv_vtweg, gv_spart.
  ENDIF.

  " =========================================================
  " 2. XÓA SỐ 0 ĐẰNG TRƯỚC (SHIFT LEFT DELETING LEADING '0')
  " =========================================================

  " --- A. Sold-to Party ---
  IF gv_kunnr IS NOT INITIAL.
    SHIFT gv_kunnr LEFT DELETING LEADING '0'.
  ENDIF.

  " --- B. Sales Document ---
  IF gv_vbeln IS NOT INITIAL.
    SHIFT gv_vbeln LEFT DELETING LEADING '0'.
  ENDIF.

  " --- C. Delivery Document ---
  IF gv_deliv IS NOT INITIAL.
    SHIFT gv_deliv LEFT DELETING LEADING '0'.
  ENDIF.

  " --- D. Billing Document ---
  IF gv_bill IS NOT INITIAL.
    SHIFT gv_bill LEFT DELETING LEADING '0'.
  ENDIF.
  "👉 Chuẩn hóa Sold-to Party (Giữ nguyên code cũ)
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

  " 👉 3. [THÊM MỚI] Chuẩn hóa Delivery Doc
  IF gv_deliv IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_deliv
      IMPORTING
        output = gv_deliv.
  ENDIF.

  " 👉 4. [THÊM MỚI] Chuẩn hóa Billing Doc
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
*& Xóa số 0 ở đầu để hiển thị lên màn hình cho đẹp (User Friendly)
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


*  ---------------------------------------------------------------------*
*    Lọc dữ liệu theo input search
*  ---------------------------------------------------------------------*
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

  " 2. Prepare Data
  " 2a. Get items
  SELECT * FROM lips INTO TABLE @lt_lips WHERE vbeln = @lv_vbeln.
  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = 'ERROR: Delivery items (LIPS) not found.'.
    EXIT.
  ENDIF.

  " 2b. Header
  ls_vbkok-vbeln_vl  = lv_vbeln.
  ls_vbkok-wabuc     = 'X'.        " Post Goods Issue
  ls_vbkok-wadat_ist = sy-datum.   " Actual GI Date

  " 2c. Items
  LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_lips>).
    CLEAR ls_vbpok.
    ls_vbpok-vbeln_vl = <fs_lips>-vbeln.
    ls_vbpok-posnr_vl = <fs_lips>-posnr.
    ls_vbpok-lfimg    = <fs_lips>-lfimg. " Quantity
    ls_vbpok-lgmng    = <fs_lips>-lgmng. " Quantity Base
    APPEND ls_vbpok TO lt_vbpok.
  ENDLOOP.

  " 3. Call FM
  " Lưu ý: Không dùng SET UPDATE TASK LOCAL để tránh lỗi bộ nhớ khi chạy Mass
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

  " 4. Analyze Result
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
  " =========================================================
  " [STEP 0] PREPARATION & CLEANUP
  " =========================================================
  " Xóa thông báo lỗi cũ
  CLEAR cs_tracking_line-error_msg.
  " phải xóa sạch các thông tin của Billing cũ/Cancel cũ trên giao diện ALV.
  " Nếu không xóa, ALV vẫn lưu số Cancel cũ -> Gây lỗi khi thực hiện Cancel tiếp.
  CLEAR: cs_tracking_line-billing_document,
         cs_tracking_line-bill_doc_cancel,  " <--- Xóa số Cancel cũ
         cs_tracking_line-fi_doc_billing,   " <--- Xóa số FI cũ
         cs_tracking_line-fi_doc_cancel.    " <--- Xóa số FI Cancel cũ

  " =========================================================
  " [STEP 1] DETERMINE BILLING TYPE
  " =========================================================
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

  " =========================================================
  " [STEP 2] PREPARE DATA
  " =========================================================
  CASE is_tracking_line-order_type.

      " -------------------------------------------------------
      " GROUP 1: DELIVERY-RELATED BILLING (ZORR, ZFOC)
      " -------------------------------------------------------
    WHEN 'ZORR' OR 'ZFOC'.

      lv_vbeln_vl = is_tracking_line-delivery_document.
      IF lv_vbeln_vl IS INITIAL.
        cs_tracking_line-error_msg = 'ERROR: Delivery Document is required.'.
        EXIT.
      ENDIF.

      " Check PGI Status (Chỉ check nhanh 1 lần)
      SELECT SINGLE wbstk FROM likp INTO lv_wbstk WHERE vbeln = lv_vbeln_vl.
      IF lv_wbstk <> 'C'.
        cs_tracking_line-error_msg = 'ERROR: PGI not completed (WBSTK <> C).'.
        EXIT.
      ENDIF.

      " Get LIPS Items
      SELECT * FROM lips INTO TABLE @lt_lips WHERE vbeln = @lv_vbeln_vl.
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

      " -------------------------------------------------------
      " GROUP 2: ORDER-RELATED BILLING
      " -------------------------------------------------------
    WHEN 'ZTP' OR 'ZSC' OR 'ZRAS' OR 'ZDR' OR 'ZCRR' OR 'ZRET'.

      " --- ZRET Specific Logic ---
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

      SELECT * FROM vbap INTO TABLE @lt_vbap
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

  " =========================================================
  " [STEP 3] CALL BAPI
  " =========================================================
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

  " =========================================================
  " [STEP 4] HANDLE RESULT
  " =========================================================
  READ TABLE lt_success INTO ls_success INDEX 1.

  IF sy-subrc = 0 AND ls_success-bill_doc IS NOT INITIAL.
    " --- SUCCESS ---
    lv_billdoc = ls_success-bill_doc.

    " 1. Commit Work AND WAIT (Quan trọng cho Mass processing)
    " WAIT = 'X' đảm bảo DB ghi xong trước khi trả về
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.

    " 2. Thông báo thành công
    cs_tracking_line-billing_document = lv_billdoc.
    cs_tracking_line-error_msg = |Success: Created { lv_billdoc }.|.

  ELSE.
    " --- FAILURE ---
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
    AND RETURN.

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

  SELECT SINGLE * FROM vbrk INTO ls_vbrk_wa WHERE vbeln = lv_bill_doc.
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
      xvbss        = lt_xvbss.

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

  IF lv_rc = 'A' OR sy-subrc <> 0. MESSAGE 'Cancelled.' TYPE 'S'. RETURN. ENDIF.

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
         icon(4)       TYPE c,
         level         TYPE i,
         doc_category  TYPE char35,
         doc_number    TYPE char20,
         doc_date      TYPE datum,
         doc_time      TYPE uzeit,
         status        TYPE char50,
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

  SELECT SINGLE * FROM vbak INTO ls_vbak WHERE vbeln = ls_tracking-sales_document.

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
  SELECT * FROM vbfa INTO TABLE lt_vbfa
    WHERE vbelv = pv_parent_vbeln.

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

  DATA: ls_bkpf   TYPE bkpf,
        ls_fi_node TYPE ty_flow_display,
        lv_awkey  TYPE string.

  DATA: lv_augbl TYPE bsad-augbl,
        lv_augdt TYPE bsad-augdt.

  CONCATENATE pv_billing_doc '%' INTO lv_awkey.

  SELECT SINGLE * FROM bkpf INTO ls_bkpf
    WHERE awtyp = 'VBRK' AND awkey LIKE lv_awkey.

  IF sy-subrc = 0.
    ls_fi_node-level        = pv_level + 1. " Thụt vào 1 cấp
    ls_fi_node-icon         = '@0Z@'.
    ls_fi_node-doc_category = 'Journal Entry'.
    CONCATENATE ls_bkpf-belnr '/' ls_bkpf-gjahr INTO ls_fi_node-doc_number.
    ls_fi_node-doc_date     = ls_bkpf-bldat.
    ls_fi_node-doc_time     = ls_bkpf-cputm.

    " Check Cleared
    CLEAR: lv_augbl, lv_augdt.
    SELECT SINGLE augbl augdt FROM bsad INTO (lv_augbl, lv_augdt)
      WHERE bukrs = ls_bkpf-bukrs
        AND belnr = ls_bkpf-belnr
        AND gjahr = ls_bkpf-gjahr.

    IF sy-subrc = 0.
      ls_fi_node-status = 'Cleared'.
    ELSE.
      ls_fi_node-status = 'Not Cleared'.
    ENDIF.

    APPEND ls_fi_node TO gt_flow_display.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV_FLOW
*&---------------------------------------------------------------------*
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
      lo_col = lo_columns->get_column( 'DOC_TIME' ). lo_col->set_visible( ' ' ). " Ẩn cột giờ đi cho đẹp

      lo_alv->display( ).
    CATCH cx_salv_msg.
  ENDTRY.
ENDFORM.

"chú ý 2
FORM update_status_counts.
  CLEAR: gv_cnt_val_ready, gv_cnt_val_incomp, gv_cnt_val_err,
         gv_cnt_suc_comp,  gv_cnt_suc_incomp,
         gv_cnt_fail_err.

  DATA: lv_final_status TYPE char15.

  " =========================================================
  " 1. TAB VALIDATED (QUAN TRỌNG NHẤT)
  " =========================================================
  LOOP AT gt_hd_val INTO DATA(ls_hd).
    " Mặc định lấy status của Header
    lv_final_status = ls_hd-status.

    " A. Kiểm tra Item con (Nếu Header chưa Error)
    IF lv_final_status <> 'ERROR'.
      LOOP AT gt_it_val TRANSPORTING NO FIELDS
           WHERE temp_id = ls_hd-temp_id
             AND status  = 'ERROR'.
        lv_final_status = 'ERROR'.
        EXIT. " Gặp 1 lỗi là dừng, phán Error luôn
      ENDLOOP.
    ENDIF.

    IF lv_final_status <> 'ERROR'.
      LOOP AT gt_it_val TRANSPORTING NO FIELDS
           WHERE temp_id = ls_hd-temp_id
             AND ( status = 'INCOMP' OR status = 'W' ).
        lv_final_status = 'INCOMP'.
        EXIT. " Gặp Incomplete thì hạ mức xuống Incomplete
      ENDLOOP.
    ENDIF.

    " B. Kiểm tra Condition con (Nếu Header chưa Error)
    IF lv_final_status <> 'ERROR'.
      LOOP AT gt_pr_val TRANSPORTING NO FIELDS
           WHERE temp_id = ls_hd-temp_id
             AND status  = 'ERROR'.
        lv_final_status = 'ERROR'.
        EXIT.
      ENDLOOP.
    ENDIF.

    IF lv_final_status <> 'ERROR' AND lv_final_status <> 'INCOMP'.
       LOOP AT gt_pr_val TRANSPORTING NO FIELDS
            WHERE temp_id = ls_hd-temp_id
              AND ( status = 'INCOMP' OR status = 'W' ).
         lv_final_status = 'INCOMP'.
         EXIT.
       ENDLOOP.
    ENDIF.

    " C. Tăng biến đếm tương ứng
    CASE lv_final_status.
      WHEN 'ERROR'.             ADD 1 TO gv_cnt_val_err.
      WHEN 'INCOMP' OR 'W'.     ADD 1 TO gv_cnt_val_incomp.
      WHEN OTHERS.              ADD 1 TO gv_cnt_val_ready. " (Ready / New)
    ENDCASE.
  ENDLOOP.

    " =========================================================
  " 2. TAB POSTED SUCCESS (Sửa Logic: Dựa vào ICON)
  " =========================================================
  " Vì FORM load_data đã tính toán kỹ logic Icon (Vàng nếu có Warning Log, Xanh nếu sạch)
  " Nên ở đây ta chỉ cần đếm theo Icon là chính xác nhất.

  LOOP AT gt_hd_suc INTO DATA(ls_suc).

    IF ls_suc-icon = icon_led_yellow.
      " Icon Vàng -> Có Incomplete Log hoặc Warning -> Đếm vào Incomplete
      ADD 1 TO gv_cnt_suc_incomp.
    ELSE.
      " Icon Xanh (hoặc khác) -> Hoàn hảo -> Đếm vào Complete
      ADD 1 TO gv_cnt_suc_comp.
    ENDIF.

  ENDLOOP.

  " =========================================================
  " 3. TAB POSTED FAILED
  " =========================================================
  " Failed thì chắc chắn là Error hết
  DESCRIBE TABLE gt_hd_fail LINES gv_cnt_fail_err.

  " Tổng hợp (Cho Header Summary HTML)
  gv_cnt_h_tot = gv_cnt_val_ready + gv_cnt_val_incomp + gv_cnt_val_err +
                 gv_cnt_suc_comp  + gv_cnt_suc_incomp +
                 gv_cnt_fail_err.

  " Tổng hợp Item/Cond (Dùng hàm Lines đơn giản)
  gv_cnt_i_tot = lines( gt_it_val ) + lines( gt_it_suc ) + lines( gt_it_fail ).
  gv_cnt_c_tot = lines( gt_pr_val ) + lines( gt_pr_suc ) + lines( gt_pr_fail ).

  " Lưu ý: Bạn cần gán các biến Item/Cond chi tiết (gv_cnt_i_val...)
  " nếu FORM build_html_summary của bạn có hiển thị chi tiết cho Item/Cond.
  gv_cnt_i_val  = lines( gt_it_val ).
  gv_cnt_i_suc  = lines( gt_it_suc ).
  gv_cnt_i_fail = lines( gt_it_fail ).

  gv_cnt_c_val  = lines( gt_pr_val ).
  gv_cnt_c_suc  = lines( gt_pr_suc ).
  gv_cnt_c_fail = lines( gt_pr_fail ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form PBO_SCREEN_0111
*&---------------------------------------------------------------------*
*& Xử lý logic PBO cho Screen 0111 (Ẩn/hiện nút 'SAVE' / 'TRCK')
*&---------------------------------------------------------------------*
FORM pbo_screen_0111.

  " Khai báo bảng nội bộ (cú pháp cũ) để chứa các nút cần ẩn
  DATA: lt_exclude TYPE TABLE OF sy-ucomm.

  IF gv_so_just_created = abap_true.
    " --- Vừa Save xong ---
    " Ẩn nút 'SAVE'
    APPEND 'SAVE' TO lt_exclude.
    " Ẩn các nút không cần thiết khác nếu muốn, ví dụ nút Item
    " APPEND 'ADD_ITEM' TO lt_exclude.
    " APPEND 'DEL_ITEM' TO lt_exclude.

    " Set lại PF-STATUS với bảng EXCLUDING đã điền
    SET PF-STATUS 'ST0111' EXCLUDING lt_exclude.

  ELSE.
    " --- Trạng thái nhập liệu bình thường ---
    " Ẩn nút 'Go to Monitor'
    APPEND 'TRCK' TO lt_exclude.

    " Set lại PF-STATUS với bảng EXCLUDING đã điền
    SET PF-STATUS 'ST0111' EXCLUDING lt_exclude.
  ENDIF.

ENDFORM.

"chú ý 2
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
  DATA: lt_cond_change    TYPE TABLE OF bapicond,
        lt_cond_change_x  TYPE TABLE OF bapicondx,
        ls_header_chg_x   TYPE bapisdh1x,
        lt_return_chg     TYPE TABLE OF bapiret2.

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

*         " [QUAN TRỌNG] Nếu là %, BAPI cần đơn vị tiền tệ rỗng hoặc '%'
*         IF ls_cond_ui-waers = '%'.
*            lv_curr_itm = space.
*         ENDIF.

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
      sales_header_in      = ls_header_crt
      sales_header_inx     = ls_header_crtx
      business_object      = lv_bus_obj
    IMPORTING
      salesdocument_ex     = lv_salesdocument_ex
    TABLES
      return               = lt_return_crt
      sales_items_in       = lt_items_crt
      sales_items_inx      = lt_items_crtx
      sales_partners       = lt_partners_crt
      sales_schedules_in   = lt_schedules_crt
      sales_schedules_inx  = lt_schedules_crtx
    EXCEPTIONS
      OTHERS               = 1.

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
      DATA: ls_temp_header_for_deliv TYPE ty_header.
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
*& Form RESET_SINGLE_ENTRY_SCREEN
*&---------------------------------------------------------------------*
*& Xóa dữ liệu giao dịch khỏi Screen 0111 (giữ lại Org Data)
*&---------------------------------------------------------------------*
FORM reset_single_entry_screen.
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
*& Form TOGGLE_EDIT_MODE
*&---------------------------------------------------------------------*
FORM toggle_edit_mode.
  " 1. Đảo cờ (Toggle)
  IF gs_edit = abap_true.
    gs_edit = abap_false.
    MESSAGE 'Switched to Display Mode' TYPE 'S'.
  ELSE.
    gs_edit = abap_true.
    MESSAGE 'Switched to Change Mode' TYPE 'S'.
  ENDIF.

  " 2. Cập nhật Layout (gs_layout)
  " (FORM alv_layout đã được thiết kế để đọc gs_edit)
  " Chúng ta cần gọi lại nó, nhưng không gọi set_table_for_first_display

  " 3. Cập nhật trạng thái "Ready for Input" cho TẤT CẢ 6 grids
  DATA(lv_ready_input) = COND i( WHEN gs_edit = abap_true THEN 1 ELSE 0 ).

  IF go_grid_hdr IS BOUND.
    go_grid_hdr->set_ready_for_input( lv_ready_input ).
  ENDIF.
  IF go_grid_item IS BOUND.
    go_grid_item->set_ready_for_input( lv_ready_input ).
  ENDIF.
  IF go_grid_hdr_incomp IS BOUND.
    go_grid_hdr_incomp->set_ready_for_input( lv_ready_input ).
  ENDIF.
  IF go_grid_item_incomp IS BOUND.
    go_grid_item_incomp->set_ready_for_input( lv_ready_input ).
  ENDIF.
  IF go_grid_hdr_err IS BOUND.
    go_grid_hdr_err->set_ready_for_input( lv_ready_input ).
  ENDIF.
  IF go_grid_item_err IS BOUND.
    go_grid_item_err->set_ready_for_input( lv_ready_input ).
  ENDIF.

  " 4. Cập nhật Field Catalogs (để bật/tắt edit cho từng cột)
  " (Điều này cần thiết nếu bạn muốn kiểm soát cột nào được edit)
  " (Tạm thời bỏ qua bước này vì set_ready_for_input là đủ)

  " 5. Refresh ALVs
  PERFORM refresh_all_alvs.

ENDFORM.

**---------------------------------------------------------------------*
** Form AUTO_FILL_ON_DATA_CHANGED (Final Version - Single Entry)
**---------------------------------------------------------------------*
** Mô phỏng hành vi VA01 (rút gọn)
** - Khi nhập Material: auto Description, Unit, ItemCat, ReqDate, Plant
** - Khi nhập Quantity: auto Currency, NetPrice, NetValue, Conf.Qty
**---------------------------------------------------------------------*
FORM auto_fill_on_data_changed
  USING ir_data_changed TYPE REF TO cl_alv_changed_data_protocol.

  FIELD-SYMBOLS: <ls_modi_cell> LIKE LINE OF ir_data_changed->mt_mod_cells,
                 <fs_item>      LIKE LINE OF gt_item_details.

  DATA: lv_matnr_internal TYPE matnr,
        lv_unit           TYPE meins,
        lv_maktx          TYPE maktx,
        lv_curr           TYPE waers.

  LOOP AT ir_data_changed->mt_mod_cells ASSIGNING <ls_modi_cell>.

    "=============================================================
    " 🛡️ Check row validity trước khi đọc dòng (tránh dump)
    "=============================================================
    IF <ls_modi_cell>-row_id > lines( gt_item_details ) OR <ls_modi_cell>-row_id <= 0.
      CONTINUE.
    ENDIF.

    READ TABLE gt_item_details ASSIGNING <fs_item> INDEX <ls_modi_cell>-row_id.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    "=============================================================
    " CASE 1️⃣: User nhập MATERIAL → auto-fill thông tin cơ bản
    "=============================================================
    IF <ls_modi_cell>-fieldname = 'MATERIAL'.

      "--- 2. Lấy Description (MAKT) ---
      SELECT SINGLE maktx
        FROM makt
        INTO @lv_maktx
        WHERE matnr = @lv_matnr_internal
          AND spras = @sy-langu.
      IF sy-subrc = 0.
        <fs_item>-description = lv_maktx.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'DESCRIPTION'
          i_value     = lv_maktx ).
      ENDIF.

      "--- 3. Lấy Sales Unit (MVKE/MARA) ---
      CLEAR lv_unit.
      SELECT SINGLE vrkme
        FROM mvke
        INTO @lv_unit
        WHERE matnr = @lv_matnr_internal
          AND vkorg = @gs_so_heder_ui-so_hdr_vkorg
          AND vtweg = @gs_so_heder_ui-so_hdr_vtweg.
      IF sy-subrc <> 0.
        SELECT SINGLE meins
          FROM mara
          INTO @lv_unit
          WHERE matnr = @lv_matnr_internal.
      ENDIF.
      IF lv_unit IS NOT INITIAL.
        <fs_item>-unit = lv_unit.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'UNIT'
          i_value     = lv_unit ).
      ENDIF.

      "--- 4. Gán Item Category mặc định (mô phỏng TAN) ---
      IF <fs_item>-itca IS INITIAL.
        <fs_item>-itca = 'TAN'.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'ITCA'
          i_value     = 'TAN' ).
      ENDIF.

      "--- 5. Gán Delivery Date = Req.Deliv.Date từ Header ---
      IF <fs_item>-req_date IS INITIAL
         AND gs_so_heder_ui-so_hdr_ketdat IS NOT INITIAL.
        <fs_item>-req_date = gs_so_heder_ui-so_hdr_ketdat.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'REQ_DATE'
          i_value     = gs_so_heder_ui-so_hdr_ketdat ).
      ENDIF.

      "--- 6. Gán Plant mặc định (demo, nếu có thể) ---
      IF <fs_item>-plant IS INITIAL.
        <fs_item>-plant = '1000'. " ← Tạm thời hardcode, sau này có thể derive
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'PLANT'
          i_value     = '1000' ).
      ENDIF.

    ENDIF. " end MATERIAL case


    "=============================================================
    " CASE 2️⃣: User nhập QUANTITY → auto-fill giá trị định lượng
    "=============================================================
    IF <ls_modi_cell>-fieldname = 'QUANTITY'.

      "--- 1. Gán Confirmed Qty = Quantity ---
      IF <fs_item>-quantity IS NOT INITIAL.
        <fs_item>-conf_qty = <fs_item>-quantity.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'CONF_QTY'
          i_value     = <fs_item>-conf_qty ).
      ENDIF.

      "--- 2. Currency lấy từ Header ---
      lv_curr = gs_so_heder_ui-so_hdr_waerk.
      IF lv_curr IS NOT INITIAL.
        <fs_item>-currency = lv_curr.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'CURRENCY'
          i_value     = lv_curr ).
      ENDIF.

      "--- 3. Net Price / Per (demo: copy Unit Price) ---
      IF <fs_item>-unit_price IS NOT INITIAL.
        <fs_item>-net_price = <fs_item>-unit_price.
        ir_data_changed->modify_cell(
          i_row_id    = <ls_modi_cell>-row_id
          i_fieldname = 'NET_PRICE'
          i_value     = <fs_item>-unit_price ).
      ENDIF.
*
    ENDIF. " end QUANTITY case

  ENDLOOP.

  "=============================================================
  " 🔁 Refresh lại ALV sau khi auto-fill
  "=============================================================
  IF go_grid_item_single IS BOUND.
    go_grid_item_single->refresh_table_display( ).
  ENDIF.

ENDFORM.

"chú ý 2
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
                 WHEN 'Z100'. <fs_cond>-kwert = ( lv_order_val * <fs_cond>-amount ) / 100.
                              lv_z100_val     = <fs_cond>-kwert.
                 WHEN 'NETW'. <fs_cond>-kwert = lv_order_val + ( ( lv_order_val * lv_zdrp_pct ) / 100 ) + lv_z100_val.
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
                 WHEN 'NET1'. <fs_cond>-kwert = v_net1_foc.
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
                       IF lv_new_qty <> 0. <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
                       ELSE. <fs_cond>-amount = 0. ENDIF.
                    WHEN 'ZTAX'.
                       <fs_cond>-kwert = ( lv_order_val * lv_tax_pct ) / 100.
                    WHEN 'GROS'.
                       <fs_cond>-kwert = lv_order_val + ( ( lv_order_val * lv_tax_pct ) / 100 ).
                       IF lv_new_qty <> 0. <fs_cond>-amount = <fs_cond>-kwert / lv_new_qty.
                       ELSE. <fs_cond>-amount = 0. ENDIF.
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

*&---------------------------------------------------------------------*
*& Form GET_SALES_AREA_FROM_POPUP (SỬA LỖI SY-SUBRC = 1)
*&---------------------------------------------------------------------*
FORM get_sales_area_from_popup
  USING    iv_kunnr TYPE kunnr
  CHANGING cv_vkorg TYPE vkorg
           cv_vtweg TYPE vtweg
           cv_spart TYPE spart.

  " 1. Định nghĩa cấu trúc cho popup
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
        lt_fieldcat TYPE slis_t_fieldcat_alv, " Dùng SLIS
        ls_fieldcat TYPE slis_fieldcat_alv, " Dùng SLIS
        ls_selfield TYPE slis_selfield.

  " 2. Tìm tất cả Sales Area (Giữ nguyên)
  SELECT vkorg, vtweg, spart
    FROM knvv
    INTO CORRESPONDING FIELDS OF TABLE @lt_knvv
    WHERE kunnr = @iv_kunnr.
  IF sy-subrc <> 0.
    MESSAGE |Customer { gs_so_heder_ui-so_hdr_sold_addr } is not assigned to any Sales Area.| TYPE 'S' DISPLAY LIKE 'E'.
    sy-subrc = 4.
    EXIT.
  ENDIF.
  SORT lt_knvv BY vkorg vtweg spart.
  DELETE ADJACENT DUPLICATES FROM lt_knvv COMPARING vkorg vtweg spart.

  " 3. Xử lý kết quả
  IF lines( lt_knvv ) = 1.
    " --- Case A: Chỉ có 1 Sales Area -> Tự động chọn (Giữ nguyên) ---
    READ TABLE lt_knvv INDEX 1 INTO ls_knvv.
    cv_vkorg = ls_knvv-vkorg.
    cv_vtweg = ls_knvv-vtweg.
    cv_spart = ls_knvv-spart.
    sy-subrc = 0.
  ELSE.
    " --- Case B: Có > 1 Sales Area -> Hiển thị Popup ---

    " 3a. Build bảng hiển thị (Giữ nguyên)
    LOOP AT lt_knvv INTO ls_knvv.
      CLEAR: ls_f4_data.
      ls_f4_data-vkorg = ls_knvv-vkorg.
      ls_f4_data-vtweg = ls_knvv-vtweg.
      ls_f4_data-spart = ls_knvv-spart.
      SELECT SINGLE vtext INTO @DATA(lv_t1) FROM tvkot WHERE vkorg = @ls_knvv-vkorg AND spras = @sy-langu.
      SELECT SINGLE vtext INTO @DATA(lv_t2) FROM tvtwt WHERE vtweg = @ls_knvv-vtweg AND spras = @sy-langu.
      SELECT SINGLE vtext INTO @DATA(lv_t3) FROM tspat WHERE spart = @ls_knvv-spart AND spras = @sy-langu.
      ls_f4_data-vtext = |{ lv_t1 } / { lv_t2 } / { lv_t3 }|.
      APPEND ls_f4_data TO lt_f4_data.
    ENDLOOP.

    " 3b. [SỬA] Build Field Catalog THỦ CÔNG (Giống code demo I_P0001)
    REFRESH lt_fieldcat.
    ls_fieldcat-fieldname = 'VKORG'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'. " Tên bảng nội bộ
    ls_fieldcat-seltext_m = 'SORG'.
    APPEND ls_fieldcat TO lt_fieldcat.
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'VTWEG'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'DC'.
    APPEND ls_fieldcat TO lt_fieldcat.
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'SPART'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'Dv'.
    APPEND ls_fieldcat TO lt_fieldcat.
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = 'VTEXT'.
    ls_fieldcat-tabname   = 'LT_F4_DATA'.
    ls_fieldcat-seltext_m = 'Description'.
    ls_fieldcat-outputlen = 60.
    APPEND ls_fieldcat TO lt_fieldcat.

    " 3c. Gọi REUSE_ALV_POPUP_TO_SELECT (Giữ nguyên)
    CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
      EXPORTING
        i_title               = 'Sales area for customer'
        i_selection           = 'X' " <<< CHỌN 1 DÒNG (Không dùng checkbox)
        i_zebra               = 'X'
        i_scroll_to_sel_line  = 'X'
        i_screen_start_column = 15
        i_screen_start_line   = 5
        i_screen_end_column   = 100
        i_screen_end_line     = 10
        it_fieldcat           = lt_fieldcat     " (Catalog thủ công)
        i_tabname             = 'LT_F4_DATA'  " (Tên bảng nội bộ)
        i_callback_program    = sy-repid
      IMPORTING
        es_selfield           = ls_selfield
      TABLES
        t_outtab              = lt_f4_data
      EXCEPTIONS
        program_error         = 1
        OTHERS                = 2.

    IF sy-subrc = 0 AND ls_selfield-tabindex > 0.
      " --- User đã chọn (Giữ nguyên) ---
      READ TABLE lt_f4_data INDEX ls_selfield-tabindex INTO ls_f4_data.
      IF sy-subrc = 0.
        cv_vkorg = ls_f4_data-vkorg.
        cv_vtweg = ls_f4_data-vtweg.
        cv_spart = ls_f4_data-spart.
        sy-subrc = 0.
      ELSE.
        MESSAGE 'Error reading popup selection.' TYPE 'S' DISPLAY LIKE 'E'.
        sy-subrc = 4.
      ENDIF.
    ELSE.
      " --- User nhấn Cancel (Giữ nguyên) ---
      MESSAGE 'No Sales Area selected. Pricing cannot be determined.' TYPE 'S' DISPLAY LIKE 'E'.
      sy-subrc = 4.
    ENDIF.
  ENDIF.
ENDFORM.


*&---------------------------------------------------------------------*
*& Form PERFORM_EXIT_CONFIRMATION (SỬA LỖI KHAI BÁO)
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
      OTHERS         = 1.

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
            OTHERS         = 1.

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
*& Form PERFORM_INCOMPLETION_CHECK (SỬA LỖI KHAI BÁO)
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
*& Form DISPLAY_INCOMPLETION_POPUP (SỬA LỖI KHAI BÁO)
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
      i_scroll_to_sel_line  = 'X'
      i_screen_start_column = 10
      i_screen_start_line   = 5
      i_screen_end_column   = 90
      i_screen_end_line     = 10
      it_fieldcat           = lt_fieldcat
      i_tabname             = 'IT_INCOMP_LOG'
      i_callback_program    = sy-repid
    IMPORTING
      es_selfield           = ls_selfield
    TABLES
      t_outtab              = it_incomp_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
ENDFORM.

"chú ý 2
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

FORM build_conditions_zorr USING pv_price TYPE kbetr
                                 pv_tax   TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl,
        lv_net_val TYPE kwert.

  " --- 1. ZPRQ (Unit Price) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Unit Price'.
  ls_cond-amount = pv_price.      " Giá từ BAPI hoặc User nhập
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " Tính Value: Giá * Qty
  ls_cond-kwert  = ls_cond-amount * pv_qty.
  lv_net_val     = ls_cond-kwert. " Lưu lại Net Value tổng

  " [THÊM MỚI] Gán đèn xanh cho dòng này
  ls_cond-icon   = icon_green_light.

  " Set Editable cho ô Amount
  ls_style-fieldname = 'AMOUNT'.
  ls_style-style     = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  " --- 2. NET VALUE (Read-only) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.       " Mã ảo
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.     " Copy đơn giá
  ls_cond-kwert  = lv_net_val.   " Copy tổng tiền
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " [THÊM MỚI] Gán đèn xanh
  ls_cond-icon   = icon_green_light.

  APPEND ls_cond TO gt_conditions_alv.

  " --- 3. ZTAX (Read-only) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZTAX'.
  ls_cond-vtext  = 'Output Tax'.
  ls_cond-amount = pv_tax.       " Thuế suất từ BAPI (VD: 8 hoặc 10)
  ls_cond-waers  = '%'.
  " Tính tiền thuế: Net Value * (Tax% / 100)
  ls_cond-kwert  = ( lv_net_val * pv_tax ) / 100.

  " [THÊM MỚI] Gán đèn xanh
  ls_cond-icon   = icon_green_light.

  APPEND ls_cond TO gt_conditions_alv.

  " --- 4. GROSS VALUE (Read-only) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'GROS'.
  ls_cond-vtext  = 'Gross Value'.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " Tính Đơn giá Gross: Price + (Price * Tax%)
  ls_cond-amount = pv_price + ( ( pv_price * pv_tax ) / 100 ).

  " Tính Tổng Gross: Amount Gross * Qty
  ls_cond-kwert  = ls_cond-amount * pv_qty.

  " [THÊM MỚI] Gán đèn xanh
  ls_cond-icon   = icon_green_light.

  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

FORM build_conditions_zdr USING pv_price TYPE kbetr
                              pv_curr  TYPE waers
                              pv_per   TYPE kpein
                              pv_uom   TYPE kmein
                              pv_qty   TYPE zquantity.

  DATA: ls_cond TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  DATA: lv_order_val TYPE kwert, " Biến tạm Order Value
        lv_zdrp_val  TYPE kwert, " Biến tạm ZDRP
        lv_z100_val  TYPE kwert. " Biến tạm Z100

  " --- DÒNG 1: ZPRQ (Quantity/Price) - CHO PHÉP NHẬP ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = ls_cond-amount * pv_qty. " Value = Price * Qty
  ls_cond-icon   = icon_green_light.

  " Mở khóa Amount cho ZPRQ
  ls_style-fieldname = 'AMOUNT'.
  ls_style-style     = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  lv_order_val = ls_cond-kwert. " Lưu Order Value

  " --- DÒNG 2: ORDER VALUE (Read Only) ---
  CLEAR ls_cond.
  ls_cond-vtext  = 'Order Value'.
  ls_cond-amount = pv_price.      " Copy Price
  ls_cond-kwert  = lv_order_val.  " Copy Value từ ZPRQ
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-icon   = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  " --- DÒNG 3: ZDRP (Percentage - Debit) - CHO PHÉP NHẬP ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZDRP'.
  ls_cond-vtext  = 'Percentage - Debit'.
  ls_cond-waers  = '%'. " Quan trọng: Để ALV format 3 số thập phân (20.000)
  ls_cond-amount = 0.
  ls_cond-kwert  = 0.
  ls_cond-icon   = icon_green_light.

  " Mở khóa Amount cho ZDRP
  ls_style-fieldname = 'AMOUNT'.
  ls_style-style     = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  " --- DÒNG 4: Z100 (-100% price) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-waers  = '%'.
  ls_cond-amount = -100. " [FIX]: Gán cứng -100

  " Tính Value Z100 = Order Value * (-100%)
  ls_cond-kwert  = ( lv_order_val * ls_cond-amount ) / 100.
  lv_z100_val    = ls_cond-kwert.
  ls_cond-icon   = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  " --- DÒNG 5: NET VALUES (Tổng cộng) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Values'.
  ls_cond-waers  = pv_curr. " Đơn vị tiền tệ (VND)
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " [1] Tính Tổng tiền (Condition Value)
  " Công thức: Order Value + ZDRP (đang là 0) + Z100
  ls_cond-kwert  = lv_order_val + 0 + lv_z100_val.

  " [2] [FIX LỖI AMOUNT = 0]
  " Tính Đơn giá ròng (Net Price) = Tổng tiền / Số lượng
  IF pv_qty <> 0.
     ls_cond-amount = ls_cond-kwert / pv_qty.
  ELSE.
     ls_cond-amount = 0.
  ENDIF.

  ls_cond-icon   = icon_green_light.
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

  " 1. ZPRQ (Quantity)
  CLEAR ls_cond.
  ls_cond-kschl = 'ZPRQ'. ls_cond-vtext = 'Quantity'.
  ls_cond-amount = pv_price. " Đơn giá vẫn hiển thị Dương (2.000)
  ls_cond-waers = pv_curr.
  ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.

  " [QUAN TRỌNG] Giá trị KWERT phải là ÂM cho Credit Memo
  ls_cond-kwert = ( pv_price * pv_qty ) * -1.

  ls_cond-icon = icon_green_light.
  " Enable Edit
  ls_style-fieldname = 'AMOUNT'. ls_style-style = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  lv_base_val = ls_cond-kwert. " Lưu giá trị âm (-40.000)

  " 2. Net Value (Subtotal)
  CLEAR ls_cond.
  ls_cond-kschl = 'NETW'. ls_cond-vtext = 'Net Value'.
  ls_cond-amount = pv_price. ls_cond-kwert = lv_base_val.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  " --- DÒNG 3: ZCRP (Percentage - Credit) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZCRP'.
  ls_cond-vtext  = 'Percentage - Credit'.

  " [FIX 1]: KHÔNG LOAD SẴN SỐ (ĐỂ = 0 GIỐNG ZDRP)
  ls_cond-amount = 0.

  ls_cond-waers  = '%'.

  " Value = 0 (Vì Amount = 0)
  ls_cond-kwert  = 0.

  ls_cond-icon   = icon_green_light.

  " Enable Edit
  ls_style-fieldname = 'AMOUNT'.
  ls_style-style     = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  lv_zcrp_val = ls_cond-kwert.

  " 4. Net Value 1 (Base + Credit) -> (-40.000 + -8.000 = -48.000)
  CLEAR ls_cond.
  ls_cond-kschl = 'NET1'. ls_cond-vtext = 'Net Value 1'.
  ls_cond-kwert = lv_base_val + lv_zcrp_val.

  IF pv_qty <> 0. ls_cond-amount = abs( ls_cond-kwert / pv_qty ). ENDIF. " Amount hiển thị dương
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  lv_net1_val = ls_cond-kwert.

  " 5. Z100 (-100% price)
  CLEAR ls_cond.
  ls_cond-kschl = 'Z100'. ls_cond-vtext = '-100% price'.
  ls_cond-amount = -100. ls_cond-waers = '%'.

  " Value = Base(Âm) * -100% = DƯƠNG (-40.000 * -1 = 40.000) -> Giống hình
  ls_cond-kwert = ( lv_base_val * ls_cond-amount ) / 100.

  APPEND ls_cond TO gt_conditions_alv.

  lv_z100_val = ls_cond-kwert.

  " 6. Net Value 2 (Final Result) -> (-48.000 + 40.000 = -8.000)
  CLEAR ls_cond.
  ls_cond-kschl = 'NET2'. ls_cond-vtext = 'Net Value 2'.
  ls_cond-kwert = lv_net1_val + lv_z100_val.

  IF pv_qty <> 0. ls_cond-amount = abs( ls_cond-kwert / pv_qty ). ENDIF.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_CONDITIONS_ZRET
*&---------------------------------------------------------------------*
* Build Condition ALV cho ZRET (Giống hình: ZPRQ -> Net Value)
*----------------------------------------------------------------------*
FORM build_conditions_zret USING pv_price TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv,
        ls_style TYPE lvc_s_styl.

  " --- DÒNG 1: ZPRQ (Quantity/Price) - CHO PHÉP NHẬP ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'ZPRQ'.
  ls_cond-vtext  = 'Quantity'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = ls_cond-amount * pv_qty. " Value = Price * Qty
  ls_cond-icon   = icon_green_light.

  " Mở khóa Amount cho ZPRQ
  ls_style-fieldname = 'AMOUNT'.
  ls_style-style     = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  " --- DÒNG 2: NET VALUE (Tổng cộng) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'. " Mã ảo
  ls_cond-vtext  = 'Net Value'.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.

  " Value = Giá trị của ZPRQ (Vì không có Tax)
  ls_cond-kwert  = pv_price * pv_qty.

  " Amount = Đơn giá ròng (Net Price)
  ls_cond-amount = pv_price.

  ls_cond-icon   = icon_green_light.
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

  " 1. ZPRQ (Quantity)
  CLEAR ls_cond.
  ls_cond-kschl = 'ZPRQ'. ls_cond-vtext = 'Quantity'.
  ls_cond-amount = pv_price. ls_cond-waers = pv_curr.
  ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-kwert = pv_price * pv_qty.
  ls_cond-icon = icon_green_light.
  " Enable Edit
  ls_style-fieldname = 'AMOUNT'. ls_style-style = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  lv_base_val = ls_cond-kwert. " Lưu Base

  " 2. Net Value (Copy ZPRQ)
  CLEAR ls_cond.
  ls_cond-kschl = 'NETW'. ls_cond-vtext = 'Net Value'.
  ls_cond-amount = pv_price. ls_cond-kwert = lv_base_val.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  " 3. ZCF1 (Commission fee)
  CLEAR ls_cond.
  ls_cond-kschl = 'ZCF1'. ls_cond-vtext = 'Commission fee'.
  ls_cond-amount = 20. ls_cond-waers = '%'. " Mặc định 20% hoặc load từ BAPI
  ls_cond-kwert = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon = icon_green_light.
  " Enable Edit
  ls_style-fieldname = 'AMOUNT'. ls_style-style = cl_gui_alv_grid=>mc_style_enabled.
  INSERT ls_style INTO TABLE ls_cond-cell_style.
  APPEND ls_cond TO gt_conditions_alv.

  lv_zcf1_val = ls_cond-kwert.

  " 4. Net Value 1 (Base + Commission)
  CLEAR ls_cond.
  ls_cond-kschl = 'NET1'. ls_cond-vtext = 'Net Value 1'.
  ls_cond-kwert = lv_base_val + lv_zcf1_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  APPEND ls_cond TO gt_conditions_alv.

  lv_net1_val = ls_cond-kwert.

  " 5. Z100 (-100% price)
  CLEAR ls_cond.
  ls_cond-kschl = 'Z100'. ls_cond-vtext = '-100% price'.
  ls_cond-amount = -100. ls_cond-waers = '%'.
  ls_cond-kwert = ( lv_base_val * ls_cond-amount ) / 100. " Tính trên Base ZPRQ
  APPEND ls_cond TO gt_conditions_alv.

  lv_z100_val = ls_cond-kwert.

  " 6. Net Value 2 (Net 1 + Z100)
  CLEAR ls_cond.
  ls_cond-kschl = 'NET2'. ls_cond-vtext = 'Net Value 2'.
  ls_cond-kwert = lv_net1_val + lv_z100_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  lv_net2_val = ls_cond-kwert.

  " 7. ZTAX (Output Tax)
  CLEAR ls_cond.
  ls_cond-kschl = 'ZTAX'. ls_cond-vtext = 'Output Tax'.
  ls_cond-amount = 8. ls_cond-waers = '%'. " Mặc định 8%
  ls_cond-kwert = ( lv_net2_val * ls_cond-amount ) / 100. " Tính trên Net 2
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  lv_tax_val = ls_cond-kwert.

  " 8. Gross Value (Net 2 + Tax)
  CLEAR ls_cond.
  ls_cond-kschl = 'GROS'. ls_cond-vtext = 'Gross Value (After Tax)'.
  ls_cond-kwert = lv_net2_val + lv_tax_val.
  IF pv_qty <> 0. ls_cond-amount = ls_cond-kwert / pv_qty. ENDIF.
  ls_cond-waers = pv_curr. ls_cond-kpein = pv_per. ls_cond-kmein = pv_uom.
  ls_cond-icon = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_CONDITIONS_ZFOC
*&---------------------------------------------------------------------*
* Build Condition ALV cho ZFOC (Net Value -> Z100 -> Net Value 1)
* Tất cả đều Read-Only
*----------------------------------------------------------------------*
FORM build_conditions_zfoc USING pv_price TYPE kbetr
                                 pv_curr  TYPE waers
                                 pv_per   TYPE kpein
                                 pv_uom   TYPE kmein
                                 pv_qty   TYPE zquantity.

  DATA: ls_cond  TYPE ty_cond_alv.

  DATA: lv_base_val TYPE kwert,
        lv_z100_val TYPE kwert,
        lv_net1_val TYPE kwert.

  " --- DÒNG 1: NET VALUE (Lấy từ Price) ---
  " Lưu ý: Ở ZFOC, dòng đầu tiên thường hiển thị là 'Net Value' luôn
  CLEAR ls_cond.
  ls_cond-kschl  = 'NETW'.
  ls_cond-vtext  = 'Net Value'.
  ls_cond-amount = pv_price.
  ls_cond-waers  = pv_curr.
  ls_cond-kpein  = pv_per.
  ls_cond-kmein  = pv_uom.
  ls_cond-kwert  = pv_price * pv_qty.
  ls_cond-icon   = icon_green_light.
  " [QUAN TRỌNG]: KHÔNG mở khóa Amount (Read-only)
  APPEND ls_cond TO gt_conditions_alv.

  lv_base_val = ls_cond-kwert.

  " --- DÒNG 2: Z100 (-100% price) ---
  CLEAR ls_cond.
  ls_cond-kschl  = 'Z100'.
  ls_cond-vtext  = '-100% price'.
  ls_cond-amount = -100.
  ls_cond-waers  = '%'.

  " Value = Base * -100%
  ls_cond-kwert  = ( lv_base_val * ls_cond-amount ) / 100.
  ls_cond-icon   = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

  lv_z100_val = ls_cond-kwert.

  " --- DÒNG 3: NET VALUE 1 (Tổng sau chiết khấu) ---
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
  ls_cond-icon   = icon_green_light.
  APPEND ls_cond TO gt_conditions_alv.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form REFRESH_CONDITIONS_ON_ENTER (Sự kiện Enter trên ALV Conditions)
*&---------------------------------------------------------------------*
FORM refresh_conditions_on_enter.
  " Khi user nhấn Enter trên ALV Conditions,
  " chỉ cần gọi lại logic PBO
  PERFORM display_conditions_for_item USING gv_current_item_idx.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data
*&---------------------------------------------------------------------*
*& SCREEN 0600 - GET DATA FOR CC_ALV
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data.

  DATA: lt_join  TYPE STANDARD TABLE OF zsd4_so_monitoring,
        ls_join  TYPE zsd4_so_monitoring,
        ls_vbuk  TYPE vbuk,
        lv_name1 TYPE kna1-name1,
        ls_data  TYPE zsd4_so_monitoring.

*-- Bước 1: Lấy dữ liệu từ VBAK + VBAP
  SELECT a~vbeln, a~auart, a~erdat, a~vdatu,
         a~vkorg, a~vtweg, a~spart, a~waerk,
         b~posnr, b~matnr, b~kwmeng, b~vrkme, b~netwr
    INTO CORRESPONDING FIELDS OF TABLE @lt_join
    FROM vbak AS a
    INNER JOIN vbap AS b ON a~vbeln = b~vbeln.

  CLEAR gt_data.

*-- Bước 2: Mapping dữ liệu
  LOOP AT lt_join INTO ls_join.

    SELECT SINGLE * INTO @ls_vbuk FROM vbuk
      WHERE vbeln = @ls_join-vbeln.

    SELECT SINGLE name1 INTO @lv_name1
      FROM kna1
      WHERE kunnr = @ls_join-sold_to(10). "sold_to chứa KUNNR ở đầu

    CLEAR ls_data.
    MOVE-CORRESPONDING ls_join TO ls_data.

    ls_data-sold_to = ls_join-sold_to(10) && ' - ' && lv_name1.

*-- Status logic
    IF ls_vbuk-fkstk = 'C'.
      ls_data-status = 'Completed'.
    ELSEIF ls_vbuk-wbstk = 'C' AND ls_vbuk-lfstk = 'C' AND ls_vbuk-fkstk <> 'C'.
      ls_data-status = 'In Process'.
    ELSE.
      ls_data-status = 'Open'.
    ENDIF.

    APPEND ls_data TO gt_data.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form LOAD_MONITORING_DATA (Sửa lỗi cú pháp VALUE)
*&---------------------------------------------------------------------*
FORM load_monitoring_data.

  " Khai báo cấu trúc cho kết quả SELECT
  TYPES: BEGIN OF ty_join_result,
           vbeln  TYPE vbak-vbeln,
           auart  TYPE vbak-auart,
           erdat  TYPE vbak-erdat,
           vdatu  TYPE vbak-vdatu,
           vkorg  TYPE vbak-vkorg,
           vtweg  TYPE vbak-vtweg,
           spart  TYPE vbak-spart,
           kunnr  TYPE vbak-kunnr,
           name1  TYPE kna1-name1,
           posnr  TYPE vbap-posnr,
           matnr  TYPE vbap-matnr,
           kwmeng TYPE vbap-kwmeng,
           vrkme  TYPE vbap-vrkme,
           netwr  TYPE vbap-netwr,
           waerk  TYPE vbak-waerk,
           abgru  TYPE vbap-abgru, " Reason for rejection (Item)
         END OF ty_join_result.

  DATA: lt_join_result TYPE STANDARD TABLE OF ty_join_result.
  DATA: ls_monitoring  TYPE zsd4_so_monitoring.

  " --- 1. Xóa dữ liệu cũ & Reset tổng ---
  REFRESH gt_monitoring_data.
  CLEAR: toso, to_val, to_sta. " (Dùng tên biến global từ Screen 600)

  " --- 2. Xây dựng WHERE clause (Dynamic) ---
  DATA: lt_range_erdat TYPE RANGE OF vbak-erdat,
        lt_range_vbeln TYPE RANGE OF vbak-vbeln,
        lt_range_kunnr TYPE RANGE OF vbak-kunnr,
        lt_range_matnr TYPE RANGE OF vbap-matnr,
        lt_range_vkorg TYPE RANGE OF vbak-vkorg,
        lt_range_vtweg TYPE RANGE OF vbak-vtweg,
        lt_range_spart TYPE RANGE OF vbak-spart.

  " Build range cho Date (SỬA LỖI CÚ PHÁP)
  IF from_dat IS NOT INITIAL OR to_dat IS NOT INITIAL.
    " <<< SỬA: Khai báo ls_range_erdat riêng rẽ >>>
    DATA ls_range_erdat LIKE LINE OF lt_range_erdat.
    ls_range_erdat = VALUE #(
      sign   = 'I'
      option = 'BT'
      low    = COND #( WHEN from_dat IS INITIAL THEN '19000101' ELSE from_dat )
      high   = COND #( WHEN to_dat IS INITIAL THEN '99991231' ELSE to_dat )
    ).
    APPEND ls_range_erdat TO lt_range_erdat.
  ENDIF.

  " (Code build range cho các trường khác giữ nguyên)
  IF sales_ord IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = sales_ord
      IMPORTING
        output = sales_ord.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = sales_ord ) TO lt_range_vbeln.
  ENDIF.
  IF sold_to IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = sold_to
      IMPORTING
        output = sold_to.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = sold_to ) TO lt_range_kunnr.
  ENDIF.
  IF material IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = material
      IMPORTING
        output = material.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = material ) TO lt_range_matnr.
  ENDIF.
  IF sale_org IS NOT INITIAL.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = sale_org ) TO lt_range_vkorg.
  ENDIF.
  IF dist_chan IS NOT INITIAL.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = dist_chan ) TO lt_range_vtweg.
  ENDIF.
  IF divi IS NOT INITIAL.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = divi ) TO lt_range_spart.
  ENDIF.

  " --- 3. [SỬA LỖI] Tạo các biến cờ (Flag) ---
  DATA: lv_check_erdat TYPE abap_bool VALUE abap_true,
        lv_check_vbeln TYPE abap_bool VALUE abap_true,
        lv_check_kunnr TYPE abap_bool VALUE abap_true,
        lv_check_vkorg TYPE abap_bool VALUE abap_true,
        lv_check_vtweg TYPE abap_bool VALUE abap_true,
        lv_check_spart TYPE abap_bool VALUE abap_true,
        lv_check_matnr TYPE abap_bool VALUE abap_true.

  " Nếu bảng KHÔNG rỗng, xóa cờ (để bật filter)
  IF lt_range_erdat IS NOT INITIAL. CLEAR lv_check_erdat. ENDIF.
  IF lt_range_vbeln IS NOT INITIAL. CLEAR lv_check_vbeln. ENDIF.
  IF lt_range_kunnr IS NOT INITIAL. CLEAR lv_check_kunnr. ENDIF.
  IF lt_range_vkorg IS NOT INITIAL. CLEAR lv_check_vkorg. ENDIF.
  IF lt_range_vtweg IS NOT INITIAL. CLEAR lv_check_vtweg. ENDIF.
  IF lt_range_spart IS NOT INITIAL. CLEAR lv_check_spart. ENDIF.
  IF lt_range_matnr IS NOT INITIAL. CLEAR lv_check_matnr. ENDIF.


  " --- 4. SELECT dữ liệu (SỬA LỖI: Dùng biến cờ) ---
  SELECT
    vbak~vbeln, vbak~auart, vbak~erdat, vbak~vdatu,
    vbak~vkorg, vbak~vtweg, vbak~spart, vbak~kunnr,
    kna1~name1,
    vbap~posnr, vbap~matnr, vbap~kwmeng, vbap~vrkme, vbap~netwr, vbak~waerk,
    vbap~abgru
  FROM vbak
  JOIN vbap ON vbak~vbeln = vbap~vbeln
  JOIN kna1 ON vbak~kunnr = kna1~kunnr
  WHERE ( @lv_check_erdat = @abap_true OR vbak~erdat IN @lt_range_erdat )
    AND ( @lv_check_vbeln = @abap_true OR vbak~vbeln IN @lt_range_vbeln )
    AND ( @lv_check_kunnr = @abap_true OR vbak~kunnr IN @lt_range_kunnr )
    AND ( @lv_check_vkorg = @abap_true OR vbak~vkorg IN @lt_range_vkorg )
    AND ( @lv_check_vtweg = @abap_true OR vbak~vtweg IN @lt_range_vtweg )
    AND ( @lv_check_spart = @abap_true OR vbak~spart IN @lt_range_spart )
    AND ( @lv_check_matnr = @abap_true OR vbap~matnr IN @lt_range_matnr )
  INTO TABLE @lt_join_result.

  IF sy-subrc <> 0.
    MESSAGE 'No data found for selected criteria.' TYPE 'S'.
    to_sta = 'No data found'. " Gán vào biến output
    EXIT.
  ENDIF.

  " --- 4. LOOP để xử lý Status và Tính tổng (Giữ nguyên) ---
  DATA: lt_processed_so TYPE HASHED TABLE OF vbak-vbeln WITH UNIQUE KEY table_line.

  LOOP AT lt_join_result ASSIGNING FIELD-SYMBOL(<fs_join>).
    CLEAR ls_monitoring.

    " a. Lấy Status (Logic mới của bạn)
    PERFORM get_document_status
      USING    <fs_join>-vbeln
               <fs_join>-posnr
               <fs_join>-abgru
      CHANGING ls_monitoring-status.

    " b. Lọc (Filter) theo Status (nếu user có chọn)
    IF status IS NOT INITIAL AND status <> 'ALL'.
      DATA lv_status_text TYPE char20.
      CASE status.
        WHEN 'COMP'. lv_status_text = 'Completed'.
        WHEN 'OPEN'. lv_status_text = 'Open/ In Process'.
        WHEN 'REJ'.  lv_status_text = 'Rejected'.
      ENDCASE.
      CHECK ls_monitoring-status = lv_status_text.
    ENDIF.

    " c. Gán giá trị vào bảng ALV (ZSD4_SO_MONITORING)
    ls_monitoring-vbeln  = <fs_join>-vbeln.
    ls_monitoring-auart  = <fs_join>-auart.
    ls_monitoring-erdat  = <fs_join>-erdat.
    ls_monitoring-vdatu  = <fs_join>-vdatu.
    ls_monitoring-vkorg  = <fs_join>-vkorg.
    ls_monitoring-vtweg  = <fs_join>-vtweg.
    ls_monitoring-spart  = <fs_join>-spart.
    ls_monitoring-sold_to = |{ <fs_join>-kunnr } { <fs_join>-name1 }|.
    ls_monitoring-posnr  = <fs_join>-posnr.
    ls_monitoring-matnr  = <fs_join>-matnr.
    ls_monitoring-kwmeng = <fs_join>-kwmeng.
    ls_monitoring-vrkme  = <fs_join>-vrkme.
    ls_monitoring-netwr  = <fs_join>-netwr.
    ls_monitoring-waerk  = <fs_join>-waerk.

    " d. Tính tổng (Cộng dồn tất cả các item)
    to_val = to_val + <fs_join>-netwr.

    " Đếm số SO (chỉ đếm 1 lần)
    READ TABLE lt_processed_so WITH KEY table_line = <fs_join>-vbeln TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      INSERT <fs_join>-vbeln INTO TABLE lt_processed_so.
      toso = toso + 1. " Tăng biến Total SO
    ENDIF.

    APPEND ls_monitoring TO gt_monitoring_data.
  ENDLOOP.

  " e. Gán Status (cuối màn hình)
  IF toso = 0.
    to_sta = 'No data matching filter'.
  ELSE.
    to_sta = |Found { toso } Order(s)|.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_DOCUMENT_STATUS (Helper FORM cho logic Status)
*&---------------------------------------------------------------------*
FORM get_document_status
  USING
    iv_vbeln TYPE vbak-vbeln
    iv_posnr TYPE vbap-posnr
    iv_abgru TYPE vbap-abgru
  CHANGING
    cv_status TYPE char20.

  " 1. Check REJECTED (Ưu tiên cao nhất)
  IF iv_abgru IS NOT INITIAL.
    cv_status = 'Rejected'.
    EXIT.
  ENDIF.

  " 2. Check COMPLETED (Đã có Billing Doc)
  SELECT SINGLE 'X'
    FROM vbfa
    INTO @DATA(lv_x)
    WHERE vbelv = @iv_vbeln  " Preceding Doc (SO)
      AND posnv = @iv_posnr  " Preceding Item (SO Item)
      AND vbtyp_n = 'M'.   " Subsequent Doc Type = 'M' (Invoice)
  IF sy-subrc = 0.
    cv_status = 'Completed'.
    EXIT.
  ENDIF.

  " 3. Nếu không Rejected và không Completed -> OPEN
  cv_status = 'Open/ In Process'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form LOAD_PGI_DETAILS (Nạp data cho Screen 300 - Hoàn chỉnh)
*&---------------------------------------------------------------------*
FORM load_pgi_details.
  DATA: lv_vbeln TYPE vbeln_vl.

  " 1. Lấy số Delivery (VBELN)
  GET PARAMETER ID 'VL' FIELD lv_vbeln.
  IF lv_vbeln IS INITIAL.
    MESSAGE 'No Delivery number passed to PGI Details.' TYPE 'E'.
    LEAVE TO SCREEN 0.
    EXIT.
  ENDIF.

  " 2. Xóa dữ liệu cũ
  REFRESH: gt_pgi_all_items, lt_lips_global. " (Clear bảng ALV và bảng global)
  CLEAR: gs_pgi_detail_ui, gs_pgi_process_ui.

  " 3. SELECT dữ liệu Header (LIKP)
  DATA ls_likp TYPE likp.
  SELECT SINGLE * FROM likp INTO @ls_likp
    WHERE vbeln = @lv_vbeln.
  IF sy-subrc <> 0.
    MESSAGE |Delivery { lv_vbeln } not found.| TYPE 'E'.
    LEAVE TO SCREEN 0.
    EXIT.
  ENDIF.

  " 4. SELECT dữ liệu Item (LIPS)
  SELECT * FROM lips INTO TABLE @lt_lips_global " (Fill vào bảng global)
    WHERE vbeln = @lv_vbeln.

  " 5. Fill dữ liệu vào Header UI (gs_pgi_detail_ui)
  MOVE-CORRESPONDING ls_likp TO gs_pgi_detail_ui.
  gs_pgi_detail_ui-uzeit = ls_likp-lfuhr. " Gán Time (LFUHR)
  gs_pgi_detail_ui-kouhr = ls_likp-kouhr. " Gán Pick Time (KOUHR)

  " Lấy tên Ship-to (KNA1)
  SELECT SINGLE name1 INTO gs_pgi_detail_ui-name1
    FROM kna1 WHERE kunnr = ls_likp-kunnr.

  " Lấy Sales Area (VTWEG, SPART) từ Sales Order gốc
  READ TABLE lt_lips_global ASSIGNING FIELD-SYMBOL(<fs_first_item>) INDEX 1.
  IF sy-subrc = 0.
    SELECT SINGLE vtweg, spart
      FROM vbak
      INTO (@gs_pgi_detail_ui-vtweg, @gs_pgi_detail_ui-spart)
      WHERE vbeln = @<fs_first_item>-vgbel. " VGBEL = SO Gốc
  ENDIF.

  " 6. Fill dữ liệu vào ALV "All Items" (gt_pgi_all_items)
  LOOP AT lt_lips_global ASSIGNING FIELD-SYMBOL(<fs_lips>).
    APPEND INITIAL LINE TO gt_pgi_all_items ASSIGNING FIELD-SYMBOL(<fs_all>).
    MOVE-CORRESPONDING <fs_lips> TO <fs_all>.
    <fs_all>-arktx = <fs_lips>-arktx.
  ENDLOOP.

  " 7. Set item index mặc định là 1 (dòng đầu tiên)
  gv_current_item_idx = 1.

ENDFORM.


**&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form FILL_PROCESSING_TAB (Nạp data cho Subscreen 302 - Hoàn chỉnh)
*&---------------------------------------------------------------------*
FORM fill_processing_tab USING iv_index TYPE sy-tabix.

  FIELD-SYMBOLS: <fs_lips> TYPE lips.

  " 1. Đọc data item từ bảng LIPS global
  READ TABLE lt_lips_global ASSIGNING <fs_lips> INDEX iv_index.
  IF sy-subrc <> 0.
    " Nếu không có item (ví dụ: Delivery rỗng), xóa structure
    CLEAR gs_pgi_process_ui.
    EXIT.
  ENDIF.

  " 2. Gán dữ liệu vào structure của Subscreen 302
  MOVE-CORRESPONDING <fs_lips> TO gs_pgi_process_ui.

  " 3. Gán các trường tên khác
  gs_pgi_process_ui-arktx = <fs_lips>-arktx.
  gs_pgi_process_ui-vtweg = gs_pgi_detail_ui-vtweg.
  gs_pgi_process_ui-spart = gs_pgi_detail_ui-spart.

  " (Trường TEXT sẽ được load sau nếu cần)

ENDFORM.
*&---------------------------------------------------------------------*
*& Form TOGGLE_PGI_EDIT_MODE (Xử lý nút Display/Change)
*&---------------------------------------------------------------------*
FORM toggle_pgi_edit_mode.

  " 1. Đảo cờ (Toggle)
  IF gv_pgi_edit_mode = abap_true.
    gv_pgi_edit_mode = abap_false.
    MESSAGE 'Switched to Display Mode' TYPE 'S'.
  ELSE.
    gv_pgi_edit_mode = abap_true.
    MESSAGE 'Switched to Change Mode' TYPE 'S'.
  ENDIF.

  " 2. Refresh lại 2 ALV (để áp dụng chế độ Mở/Khóa)
  PERFORM refresh_pgi_alvs .

ENDFORM.


*&---------------------------------------------------------------------*
*& Form PERFORM_POST_GOODS_ISSUE (Logic PGI)
*&---------------------------------------------------------------------*
FORM perform_post_goods_issue.

  " <<< SỬA: Dùng kiểu GLOBAL (từ ...TOP) >>>
  DATA: lt_error_log TYPE ty_t_error_log,
        ls_error_log TYPE ty_error_log.


  " Khai báo BAPI
  DATA: ls_gm_header   TYPE bapi2017_gm_head_01,
        ls_gm_code     TYPE bapi2017_gm_code,
        lt_gm_item     TYPE TABLE OF bapi2017_gm_item_create,
        ls_gm_item     TYPE bapi2017_gm_item_create,
        lv_gm_docno    TYPE mblnr,
        lv_gm_docyear  TYPE mjahr,
        lt_bapi_return TYPE TABLE OF bapiret2.

  FIELD-SYMBOLS: <fs_lips>     TYPE lips,
                 <fs_alv_item> TYPE ty_pgi_all_items.

  " --- 1. ĐỒNG BỘ (SYNC) DATA TỪ UI ---
  " 1a. Sync Tab "Processing" (S.Loc)
  " (Lưu S.Loc user vừa nhập ở Tab 2 vào bảng data chính)
  READ TABLE lt_lips_global ASSIGNING <fs_lips> INDEX gv_current_item_idx.
  IF sy-subrc = 0.
    <fs_lips>-lgort = gs_pgi_process_ui-lgort.
  ENDIF.

  " 1b. Sync Tab "All Items" (Qty)
  " (Lưu Qty user vừa nhập ở Tab 1 vào bảng data chính)
  LOOP AT gt_pgi_all_items ASSIGNING <fs_alv_item>.
    READ TABLE lt_lips_global ASSIGNING <fs_lips> INDEX sy-tabix.
    IF sy-subrc = 0.
      <fs_lips>-lfimg = <fs_alv_item>-lfimg. " Delivery Qty
      <fs_lips>-pikmg_wh = <fs_alv_item>-pikmg. " Picked Qty
    ENDIF.
  ENDLOOP.

  " --- 2. VALIDATE (KIỂM TRA) DATA TRƯỚC KHI GỌI BAPI ---
  LOOP AT lt_lips_global ASSIGNING <fs_lips>.
    " Chỉ xử lý item có Delivery Qty (Bỏ qua item 0)
    IF <fs_lips>-lfimg = 0.
      CONTINUE.
    ENDIF.

    " 2a. Check 1 (Giống pgi1.png)
    IF <fs_lips>-pikmg_wh > <fs_lips>-lfimg.
      ls_error_log-msgty = 'E'.
      ls_error_log-message = |Item { <fs_lips>-posnr }: Picked Qty ({ <fs_lips>-pikmg_wh }) is larger than Delivery Qty ({ <fs_lips>-lfimg }).|.
      APPEND ls_error_log TO lt_error_log.
    ENDIF.

    " 2b. Check 2 (Giống pgi2.png)
    IF <fs_lips>-lgort IS INITIAL.
      ls_error_log-msgty = 'E'.
      ls_error_log-message = |Item { <fs_lips>-posnr }: Storage Location is required for PGI.|.
      APPEND ls_error_log TO lt_error_log.
    ENDIF.

    " 2c. Check 3 (Giống errorlog1.png)
    IF <fs_lips>-pikmg_wh IS INITIAL OR <fs_lips>-pikmg_wh = 0.
      " (Chúng ta bỏ qua kịch bản 1 của bạn - "vẫn call BAPI")
      " (Vì BAPI sẽ báo lỗi "Delivery has not yet been picked" - VL 030)
      ls_error_log-msgty = 'E'.
      ls_error_log-message = |Item { <fs_lips>-posnr }: Picked Quantity must be entered.|.
      APPEND ls_error_log TO lt_error_log.
    ENDIF.
  ENDLOOP.

  " 3. Hiển thị lỗi (nếu có) và Dừng
  IF lt_error_log IS NOT INITIAL.
    PERFORM display_error_log_popup TABLES lt_error_log.
    EXIT.
  ENDIF.

  " --- 4. CHUẨN BỊ BAPI (Nếu không có lỗi) ---
  ls_gm_header-pstng_date = sy-datum.
  ls_gm_header-doc_date = sy-datum.
  ls_gm_header-header_txt = 'PGI via ZSD4 Sales Center'.
  ls_gm_code-gm_code = '01'. " (Mã GM cho BAPI)

  LOOP AT lt_lips_global ASSIGNING <fs_lips>
      WHERE pikmg_wh IS NOT INITIAL AND pikmg_wh > 0.

    CLEAR ls_gm_item.
    ls_gm_item-material    = <fs_lips>-matnr.
    ls_gm_item-plant       = <fs_lips>-werks.
    ls_gm_item-stge_loc    = <fs_lips>-lgort.
    ls_gm_item-batch       = <fs_lips>-charg.
    ls_gm_item-move_type   = '601'. " (PGI cho Delivery)
    ls_gm_item-entry_qnt   = <fs_lips>-pikmg_wh.
    ls_gm_item-entry_uom   = <fs_lips>-meins.
    ls_gm_item-deliv_numb_to_search = <fs_lips>-vbeln.
    ls_gm_item-deliv_item_to_search = <fs_lips>-posnr.
    APPEND ls_gm_item TO lt_gm_item.
  ENDLOOP.

  IF lt_gm_item IS INITIAL.
    MESSAGE 'No items found with Picked Quantity > 0.' TYPE 'W'.
    EXIT.
  ENDIF.

  " --- 5. GỌI BAPI PGI ---
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
    EXPORTING
      goodsmvt_header  = ls_gm_header
      goodsmvt_code    = ls_gm_code
    IMPORTING
      materialdocument = lv_gm_docno
      matdocumentyear  = lv_gm_docyear
    TABLES
      goodsmvt_item    = lt_gm_item
      return           = lt_bapi_return.

  " 6. Xử lý kết quả BAPI
  DATA(lv_bapi_error) = abap_false.

  " <<< SỬA LỖI: Dùng 'TYPE' thay vì 'MSGTY' >>>
  LOOP AT lt_bapi_return ASSIGNING FIELD-SYMBOL(<fs_ret>)
      WHERE type = 'E' OR type = 'A'.
    lv_bapi_error = abap_true.
    CLEAR ls_error_log.

    " <<< SỬA LỖI: Gán thủ công (vì tên trường khác nhau) >>>
    " (Không dùng MOVE-CORRESPONDING)
    ls_error_log-msgty = <fs_ret>-type.
    ls_error_log-msgno = <fs_ret>-number.
    ls_error_log-msgv1 = <fs_ret>-message_v1.
    ls_error_log-msgv2 = <fs_ret>-message_v2.
    ls_error_log-msgv3 = <fs_ret>-message_v3.
    ls_error_log-msgv4 = <fs_ret>-message_v4.
    ls_error_log-message = <fs_ret>-message.
    APPEND ls_error_log TO lt_error_log.
  ENDLOOP.

  IF lv_bapi_error = abap_true.
    " --- LỖI: Hiển thị Error Log (giống pgi2.png) ---
    PERFORM display_error_log_popup TABLES lt_error_log.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  ELSE.
    " --- THÀNH CÔNG ---
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.
    MESSAGE |PGI posted successfully. Material Doc: { lv_gm_docno }| TYPE 'S'.

    " Nạp lại data (để cập nhật WBSTK = 'C')
    PERFORM load_pgi_details.
    " Refresh lại ALV
    PERFORM refresh_pgi_alvs .
  ENDIF.

ENDFORM.

"chú ý 2
FORM display_error_log_popup
  TABLES
    it_error_log TYPE ty_t_error_log. " <<< SỬA: Dùng kiểu global

  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_fieldcat TYPE slis_fieldcat_alv,
        ls_selfield TYPE slis_selfield.

  " 1. Build Field Catalog thủ công
  REFRESH lt_fieldcat.
  ls_fieldcat-fieldname = 'ICON'.
  ls_fieldcat-tabname   = 'IT_ERROR_LOG'.
  ls_fieldcat-icon      = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'MESSAGE'.
  ls_fieldcat-tabname   = 'IT_ERROR_LOG'.
  ls_fieldcat-seltext_m = 'Message Text'.
  ls_fieldcat-outputlen = 255.
  APPEND ls_fieldcat TO lt_fieldcat.

  " 2. (Tùy chọn) Thêm Icon vào bảng lỗi
  LOOP AT it_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
    IF <fs_err>-msgty = 'E' OR <fs_err>-msgty = 'A'.
      CALL FUNCTION 'ICON_CREATE'
        EXPORTING name = 'ICON_LED_RED'
        IMPORTING result = <fs_err>-icon.
    ENDIF.
  ENDLOOP.

  " 3. Gọi ALV Popup
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = 'Goods movement: Error log'
      i_zebra               = 'X'
      it_fieldcat           = lt_fieldcat
      i_tabname             = 'IT_ERROR_LOG'
      i_callback_program    = sy-repid
    TABLES
      t_outtab              = it_error_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form VALIDATE_TEMPLATE_STRUCTURE (Phiên bản REF TO DATA - Final)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form VALIDATE_TEMPLATE_STRUCTURE (Fixed Type Conflict)
*&---------------------------------------------------------------------*
*FORM validate_template_structure
*  USING
*    io_excel      TYPE REF TO cl_fdt_xl_spreadsheet
*    iv_sheet      TYPE string
*    iv_tabname    TYPE tabname
*  CHANGING
*    co_data_ref   TYPE REF TO data. " <<< [SỬA QUAN TRỌNG]: Đổi từ STANDARD TABLE sang REF TO DATA
*
*  FIELD-SYMBOLS: <fs_data_raw> TYPE STANDARD TABLE,
*                 <fs_row_1>    TYPE any,
*                 <lv_cell>     TYPE any.
*
*  " --- 1. Định nghĩa Khuôn mẫu (Golden Template) ---
*  TYPES: BEGIN OF ty_golden,
*           col_idx  TYPE i,
*           col_name TYPE string,
*         END OF ty_golden.
*  DATA: lt_golden TYPE TABLE OF ty_golden.
*
*  IF iv_tabname = 'ZTB_SO_UPLOAD_HD'.
*    lt_golden = VALUE #(
*      ( col_idx = 1  col_name = 'TEMP ID' )
*      ( col_idx = 2  col_name = '*SALES ORDER TYPE' )
*      ( col_idx = 3  col_name = '*SALES ORG.' )
*      ( col_idx = 4  col_name = '*DIST. CHNL' )
*      ( col_idx = 5  col_name = '*DIVISION' )
*      ( col_idx = 6  col_name = 'SALES OFFICE' )
*      ( col_idx = 7  col_name = 'SALES GROUP' )
*      ( col_idx = 8  col_name = '*SOLD-TO PARTY' )
*      ( col_idx = 9  col_name = '*CUST. REF.' )
*      ( col_idx = 10 col_name = '*REQUESTED DELIVERY DATE' )
*      ( col_idx = 11 col_name = '*PAYT. TERM' )
*      ( col_idx = 12 col_name = 'INCOTERM' )
*      ( col_idx = 13 col_name = 'INCOTERM-LOCATION' )
*    ).
*  ELSEIF iv_tabname = 'ZTB_SO_UPLOAD_IT'.
*    lt_golden = VALUE #(
*      ( col_idx = 1  col_name = 'TEMP ID' )
*      ( col_idx = 2  col_name = 'ITEM NO' )
*      ( col_idx = 3  col_name = '*MATERIAL' )
*      ( col_idx = 4  col_name = 'PLANT' )
*      ( col_idx = 5  col_name = 'SHIPPING POINT' )
*      ( col_idx = 6  col_name = 'STORAGE LOC.' )
*      ( col_idx = 7  col_name = '*ORDER QUANTITY' )
*    ).
*  ELSEIF iv_tabname = 'ZTB_SO_UPLOAD_PR'.
*    lt_golden = VALUE #(
*      ( col_idx = 1  col_name = 'TEMP ID' )
*      ( col_idx = 2  col_name = 'ITEM NO' )
*      ( col_idx = 3  col_name = 'COND. TYPE' )
*      ( col_idx = 4  col_name = 'AMOUNT' )
*      ( col_idx = 5  col_name = 'CURRENCY' )
*      ( col_idx = 6  col_name = 'PER' )
*      ( col_idx = 7  col_name = 'UOM' )
*    ).
*  ENDIF.
*
*  " --- 2. Lấy dữ liệu thô từ Excel ---
*  TRY.
*      " [SỬA]: Lấy tham chiếu trực tiếp vào biến CHANGING
*      co_data_ref = io_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet( iv_sheet ).
*      ASSIGN co_data_ref->* TO <fs_data_raw>.
*    CATCH cx_fdt_excel.
*      MESSAGE |Sheet '{ iv_sheet }' not found in template.| TYPE 'S' DISPLAY LIKE 'E'.
*      CLEAR co_data_ref.
*      RETURN.
*  ENDTRY.
*
*  " --- 3. Đọc dòng tiêu đề (Row 1) ---
*  READ TABLE <fs_data_raw> ASSIGNING <fs_row_1> INDEX 1.
*  IF sy-subrc <> 0.
*    MESSAGE |Sheet '{ iv_sheet }' is empty.| TYPE 'S' DISPLAY LIKE 'E'.
*    CLEAR co_data_ref. RETURN.
*  ENDIF.
*
*  " --- 4. So sánh với Khuôn mẫu ---
*  LOOP AT lt_golden INTO DATA(ls_golden).
*    ASSIGN COMPONENT ls_golden-col_idx OF STRUCTURE <fs_row_1> TO <lv_cell>.
*
*    IF <lv_cell> IS NOT ASSIGNED.
*      MESSAGE |Invalid Template: Column { ls_golden-col_idx } missing in sheet { iv_sheet }.| TYPE 'S' DISPLAY LIKE 'E'.
*      CLEAR co_data_ref. RETURN.
*    ENDIF.
*
*    DATA(lv_user_col) = |{ <lv_cell> }|.
*    CONDENSE lv_user_col.
*    TRANSLATE lv_user_col TO UPPER CASE.
*
*    IF lv_user_col <> ls_golden-col_name.
*      MESSAGE |Template Error ({ iv_sheet }): Column { ls_golden-col_idx } should be '{ ls_golden-col_name }' but found '{ lv_user_col }'.|
*        TYPE 'S' DISPLAY LIKE 'E'.
*      CLEAR co_data_ref. RETURN.
*    ENDIF.
*  ENDLOOP.
*
*  " --- 5. Xóa dòng tiêu đề ---
*  DELETE <fs_data_raw> INDEX 1.
*  " (Biến co_data_ref trỏ vào <fs_data_raw> nên dữ liệu trả về đã sạch)
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form DEFINE_GOLDEN_TEMPLATES (Task 3.3 - Đã thêm Schedule Line Date)
*&---------------------------------------------------------------------*
*FORM define_golden_templates
*  TABLES
*    ct_golden_header TYPE ty_t_excel_column
*    ct_golden_item   TYPE ty_t_excel_column.
*
*  " --- 1. Định nghĩa khuôn mẫu "Header" ---
*  REFRESH ct_golden_header.
*  APPEND VALUE #( col_id = 'A' col_name = 'TEMP ID' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'B' col_name = '*SALES ORDER TYPE' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'C' col_name = '*SALES ORG.' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'D' col_name = '*DIST. CHNL' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'E' col_name = '*DIVISION' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'F' col_name = 'SALES OFFICE' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'G' col_name = 'SALES GROUP' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'H' col_name = '*SOLD-TO PARTY' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'I' col_name = '*CUST. REF.' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'J' col_name = '*REQUESTED DELIVERY DATE' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'K' col_name = 'PRICE DATE' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'L' col_name = '*PAYT. TERM' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'M' col_name = 'INCOTERM' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'N' col_name = 'CURRENCY' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'O' col_name = 'ORDER DATE' ) TO ct_golden_header.
*  APPEND VALUE #( col_id = 'P' col_name = 'SHIP. COND.' ) TO ct_golden_header.
*
*  " --- 2. Định nghĩa khuôn mẫu "Item" ---
*  REFRESH ct_golden_item.
*  APPEND VALUE #( col_id = 'A' col_name = 'TEMP ID' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'B' col_name = 'PRICING PROCEDURE' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'C' col_name = 'ITEM NO' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'D' col_name = '*MATERIAL' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'E' col_name = 'SHORT TEXT' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'F' col_name = 'PLANT' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'G' col_name = 'SHIPPING POINT' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'H' col_name = '*STORAGE LOC.' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'I' col_name = '*ORDER QUANTITY' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'J' col_name = 'UNIT PRICE' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'K' col_name = 'PER' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'L' col_name = 'UOM' ) TO ct_golden_item.
*  APPEND VALUE #( col_id = 'M' col_name = 'COND. TYPE' ) TO ct_golden_item.
*
*  " [GIỮ LẠI THEO YÊU CẦU] Cột N
*  APPEND VALUE #( col_id = 'N' col_name = 'SCHEDULE LINE DATE' ) TO ct_golden_item.
*
*ENDFORM.

FORM validate_template_structure
  USING
    io_excel      TYPE REF TO cl_fdt_xl_spreadsheet
    iv_sheet      TYPE string
    iv_tabname    TYPE tabname
  CHANGING
    co_data_ref   TYPE REF TO data. " <<< [SỬA QUAN TRỌNG]: Đổi từ STANDARD TABLE sang REF TO DATA

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
      ( col_idx = 1  col_name = 'TEMP ID' )
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
      ( col_idx = 1  col_name = 'TEMP ID' )
      ( col_idx = 2  col_name = 'ITEM NO' )
      ( col_idx = 3  col_name = '*MATERIAL' )
      ( col_idx = 4  col_name = 'PLANT' )
      ( col_idx = 5  col_name = 'SHIPPING POINT' )
      ( col_idx = 6  col_name = 'STORAGE LOC.' )
      ( col_idx = 7  col_name = '*ORDER QUANTITY' )
    ).
  ELSEIF iv_tabname = 'ZTB_SO_UPLOAD_PR'.
    lt_golden = VALUE #(
      ( col_idx = 1  col_name = 'TEMP ID' )
      ( col_idx = 2  col_name = 'ITEM NO' )
      ( col_idx = 3  col_name = 'COND. TYPE' )
      ( col_idx = 4  col_name = 'AMOUNT' )
      ( col_idx = 5  col_name = 'CURRENCY' )
      ( col_idx = 6  col_name = 'PER' )
      ( col_idx = 7  col_name = 'UOM' )
    ).
  ENDIF.

  " --- 2. Lấy dữ liệu thô từ Excel ---
  TRY.
      " [SỬA]: Lấy tham chiếu trực tiếp vào biến CHANGING
      co_data_ref = io_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet( iv_sheet ).
      ASSIGN co_data_ref->* TO <fs_data_raw>.
    CATCH cx_fdt_excel.
      MESSAGE |Sheet '{ iv_sheet }' not found in template.| TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref.
      RETURN.
  ENDTRY.

  " --- 3. Đọc dòng tiêu đề (Row 1) ---
  READ TABLE <fs_data_raw> ASSIGNING <fs_row_1> INDEX 1.
  IF sy-subrc <> 0.
    MESSAGE |Sheet '{ iv_sheet }' is empty.| TYPE 'S' DISPLAY LIKE 'E'.
    CLEAR co_data_ref. RETURN.
  ENDIF.

  " --- 4. So sánh với Khuôn mẫu ---
  LOOP AT lt_golden INTO DATA(ls_golden).
    ASSIGN COMPONENT ls_golden-col_idx OF STRUCTURE <fs_row_1> TO <lv_cell>.

    IF <lv_cell> IS NOT ASSIGNED.
      MESSAGE |Invalid Template: Column { ls_golden-col_idx } missing in sheet { iv_sheet }.| TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref. RETURN.
    ENDIF.

    DATA(lv_user_col) = |{ <lv_cell> }|.
    CONDENSE lv_user_col.
    TRANSLATE lv_user_col TO UPPER CASE.

    IF lv_user_col <> ls_golden-col_name.
      MESSAGE |Template Error ({ iv_sheet }): Column { ls_golden-col_idx } should be '{ ls_golden-col_name }' but found '{ lv_user_col }'.|
        TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR co_data_ref. RETURN.
    ENDIF.
  ENDLOOP.

  " --- 5. Xóa dòng tiêu đề ---
  DELETE <fs_data_raw> INDEX 1.
  " (Biến co_data_ref trỏ vào <fs_data_raw> nên dữ liệu trả về đã sạch)

*    " --- 4. So sánh Chặt chẽ (Strict Comparison) ---
*  DATA: lv_str_golden TYPE string,
*        lv_str_file   TYPE string.
*
*  LOOP AT lt_golden INTO DATA(ls_golden).
*    ASSIGN COMPONENT ls_golden-col_idx OF STRUCTURE <fs_row_1> TO <lv_cell>.
*
*    IF <lv_cell> IS NOT ASSIGNED.
*      MESSAGE |Template Error: Column { ls_golden-col_idx } is missing.| TYPE 'S' DISPLAY LIKE 'E'.
*      CLEAR co_data_ref. RETURN.
*    ENDIF.
*
*    " --- LOGIC CHUẨN HÓA CHUỖI ---
*    " 1. Lấy giá trị
*    lv_str_file = |{ <lv_cell> }|.
*    lv_str_golden = ls_golden-col_name.
*
*    " 2. Chuyển chữ hoa
*    TRANSLATE lv_str_file TO UPPER CASE.
*    TRANSLATE lv_str_golden TO UPPER CASE.
*
*    " 3. Loại bỏ ký tự đặc biệt (*, ., khoảng trắng) để so sánh cốt lõi
*    " (Ví dụ: '*Sales Org.' sẽ thành 'SALESORG')
*    REPLACE ALL OCCURRENCES OF '*' IN lv_str_file WITH ''.
*    REPLACE ALL OCCURRENCES OF '.' IN lv_str_file WITH ''.
*    CONDENSE lv_str_file NO-GAPS.
*
*    REPLACE ALL OCCURRENCES OF '*' IN lv_str_golden WITH ''.
*    REPLACE ALL OCCURRENCES OF '.' IN lv_str_golden WITH ''.
*    CONDENSE lv_str_golden NO-GAPS.
*
*    " 4. So sánh
*    IF lv_str_file <> lv_str_golden.
*      MESSAGE |Template Error ({ iv_sheet }): Column { ls_golden-col_idx } should be '{ ls_golden-col_name }' but found '{ <lv_cell> }'.|
*        TYPE 'S' DISPLAY LIKE 'E'.
*
*      " [QUAN TRỌNG]: Clear tham chiếu để bên ngoài biết là lỗi
*      CLEAR co_data_ref.
*      RETURN.
*    ENDIF.
*  ENDLOOP.
*
*  " --- 5. Xóa dòng tiêu đề ---
*  DELETE <fs_data_raw> INDEX 1.

ENDFORM.

FORM define_golden_templates
  TABLES
    ct_golden_header TYPE ty_t_excel_column
    ct_golden_item   TYPE ty_t_excel_column.

  " --- 1. Định nghĩa khuôn mẫu "Header" ---
  REFRESH ct_golden_header.
  APPEND VALUE #( col_id = 'A' col_name = 'TEMP ID' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'B' col_name = '*SALES ORDER TYPE' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'C' col_name = '*SALES ORG.' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'D' col_name = '*DIST. CHNL' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'E' col_name = '*DIVISION' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'F' col_name = 'SALES OFFICE' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'G' col_name = 'SALES GROUP' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'H' col_name = '*SOLD-TO PARTY' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'I' col_name = '*CUST. REF.' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'J' col_name = '*REQUESTED DELIVERY DATE' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'K' col_name = 'PRICE DATE' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'L' col_name = '*PAYT. TERM' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'M' col_name = 'INCOTERM' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'N' col_name = 'CURRENCY' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'O' col_name = 'ORDER DATE' ) TO ct_golden_header.
  APPEND VALUE #( col_id = 'P' col_name = 'SHIP. COND.' ) TO ct_golden_header.

  " --- 2. Định nghĩa khuôn mẫu "Item" ---
  REFRESH ct_golden_item.
  APPEND VALUE #( col_id = 'A' col_name = 'TEMP ID' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'B' col_name = 'PRICING PROCEDURE' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'C' col_name = 'ITEM NO' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'D' col_name = '*MATERIAL' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'E' col_name = 'SHORT TEXT' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'F' col_name = 'PLANT' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'G' col_name = 'SHIPPING POINT' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'H' col_name = '*STORAGE LOC.' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'I' col_name = '*ORDER QUANTITY' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'J' col_name = 'UNIT PRICE' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'K' col_name = 'PER' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'L' col_name = 'UOM' ) TO ct_golden_item.
  APPEND VALUE #( col_id = 'M' col_name = 'COND. TYPE' ) TO ct_golden_item.

  " [GIỮ LẠI THEO YÊU CẦU] Cột N
  APPEND VALUE #( col_id = 'N' col_name = 'SCHEDULE LINE DATE' ) TO ct_golden_item.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_INCOTERM (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_incoterm
  USING
    iv_sold_to TYPE kunnr
    iv_vkorg TYPE vkorg
    iv_vtweg TYPE vtweg
    iv_spart TYPE spart
  CHANGING
    cv_incoterms TYPE inco1.

  SELECT SINGLE inco1 FROM knvv
    INTO cv_incoterms
    WHERE kunnr = iv_sold_to
      AND vkorg = iv_vkorg
      AND vtweg = iv_vtweg
      AND spart = iv_spart.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_CURRENCY (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_currency
  USING
    iv_sold_to TYPE kunnr
    iv_vkorg TYPE vkorg
    iv_vtweg TYPE vtweg
    iv_spart TYPE spart
  CHANGING
    cv_currency TYPE waerk.

  SELECT SINGLE waers FROM knvv
    INTO cv_currency
    WHERE kunnr = iv_sold_to
      AND vkorg = iv_vkorg
      AND vtweg = iv_vtweg
      AND spart = iv_spart.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_PRICE_DATE (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_price_date
  USING
    iv_req_date TYPE dats
  CHANGING
    cv_price_date TYPE dats.

  cv_price_date = iv_req_date. " Mặc định = Req. Date
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_ORDER_DATE (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_order_date
  CHANGING
    cv_order_date TYPE dats.

  cv_order_date = sy-datum. " Mặc định = Hôm nay
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_ITEM_BASICS (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_item_basics
  USING
    iv_matnr TYPE matnr
  CHANGING
    cv_short_text TYPE arktx
    cv_unit       TYPE meins
    cv_per        TYPE char5 " (Kiểu của bạn là char5)
    cv_status     TYPE c
    cv_message    TYPE string.

  " 1. Lấy Base UOM (PER mặc định là 1)
  SELECT SINGLE meins FROM mara
    INTO cv_unit
    WHERE matnr = iv_matnr.
  cv_per = '1'. " Mặc định

  " 2. Lấy Description
  SELECT SINGLE maktx FROM makt
    INTO cv_short_text
    WHERE matnr = iv_matnr
      AND spras = sy-langu.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_PLANT (SỬA LỖI: Dùng MVKE-DWERK)
*&---------------------------------------------------------------------*
FORM auto_fill_plant
  USING
    iv_matnr TYPE matnr
    iv_vkorg TYPE vkorg
  CHANGING
    cv_plant TYPE werks_d.

  " Lấy Plant (DWERK) từ MVKE (Sales View)
  SELECT SINGLE dwerk FROM mvke
    INTO cv_plant
    WHERE matnr = iv_matnr
      AND vkorg = iv_vkorg.

  " (Nếu không tìm thấy ở MVKE, bạn có thể thêm logic dự phòng
  "  để tìm trong MARC, nhưng MVKE là ưu tiên)
ENDFORM.

*&---------------------------------------------------------------------*
*& Form AUTO_FILL_SHIP_POINT (Shell)
*&---------------------------------------------------------------------*
FORM auto_fill_ship_point
  USING
    iv_plant TYPE werks_d
  CHANGING
    cv_ship_point TYPE vstel.

  " TODO: Logic auto-fill Shipping Point (ví dụ: từ T001W)
  " Lấy Shipping Point từ Plant
  SELECT SINGLE vstel FROM t001w
    INTO cv_ship_point
    WHERE werks = iv_plant.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_html_summary
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*FORM build_html_summary .
*     DATA: lv_html TYPE string,
*        lt_html TYPE STANDARD TABLE OF w3html,
*        ls_html TYPE w3html,
*        lv_url  TYPE char1024.
*
*  "--- Convert INT → CHAR (vì CONCATENATE cần char-like)
*  DATA: lv_h_tot     TYPE c LENGTH 20,
*        lv_h_comp    TYPE c LENGTH 20,
*        lv_h_incomp  TYPE c LENGTH 20,
*        lv_h_err     TYPE c LENGTH 20,
*        lv_i_tot     TYPE c LENGTH 20,
*        lv_i_comp    TYPE c LENGTH 20,
*        lv_i_incomp  TYPE c LENGTH 20,
*        lv_i_err     TYPE c LENGTH 20.
*
*  WRITE gv_cnt_h_tot     TO lv_h_tot.
*  WRITE gv_cnt_h_comp    TO lv_h_comp.
*  WRITE gv_cnt_h_incomp  TO lv_h_incomp.
*  WRITE gv_cnt_h_err     TO lv_h_err.
*
*  WRITE gv_cnt_i_tot     TO lv_i_tot.
*  WRITE gv_cnt_i_comp    TO lv_i_comp.
*  WRITE gv_cnt_i_incomp  TO lv_i_incomp.
*  WRITE gv_cnt_i_err     TO lv_i_err.
*
*  CLEAR lv_html.
*
*CONCATENATE lv_html
*  '<html><head><meta charset="UTF-8"><style>'
*
*  'body { font-family: Segoe UI, Arial; padding:6px; background-color:#fafafa; }'
*  'h2 { color:#1a73e8; margin-bottom:10px; font-size:19px; font-weight:600; }'
*
*  '.container { display:flex; gap:12px; align-items:flex-start; }'
*
*  '.card { background:#ffffff; width:230px; padding:10px 12px;'
*    'border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,0.10);'
*    'border:1px solid #e3e3e3; }'
*
*  '.title { font-size:15px; font-weight:700; margin-bottom:6px;'
*    'color:#333; display:flex; gap:6px; align-items:center; }'
*
*  '.row { font-size:13px; margin:3px 0; }'
*
*  '.ok{ color:#0f9d58; font-weight:500; }'
*  '.warn{ color:#f4b400; font-weight:500; }'
*  '.err{ color:#db4437; font-weight:500; }'
*  '.total{ color:#212121; font-weight:500; }'
*
*  '</style></head><body>'
*
*  '<h2>Validation Summary</h2>'
*  '<div class="container">'
*INTO lv_html SEPARATED BY space.
*
*
*    CONCATENATE lv_html
*  '<div class="card">'
*
*    '<div class="title">📁 Headers Summary</div>'
*
*    '<div class="row total">📄 Total: '      lv_h_tot '</div>'
*    '<div class="row ok">✔ Complete: '       lv_h_comp '</div>'
*    '<div class="row warn">⚠ Incomplete: '   lv_h_incomp '</div>'
*    '<div class="row err">✖ Error: '         lv_h_err '</div>'
*
*  '</div>'
*INTO lv_html SEPARATED BY space.
*
*  CONCATENATE lv_html
*  '<div class="card">'
*
*    '<div class="title">🧾 Items Summary</div>'
*
*    '<div class="row total">📄 Total: '      lv_i_tot '</div>'
*    '<div class="row ok">✔ Complete: '       lv_i_comp '</div>'
*    '<div class="row warn">⚠ Incomplete: '   lv_i_incomp '</div>'
*    '<div class="row err">✖ Error: '         lv_i_err '</div>'
*
*  '</div>'
*
*  '</div></body></html>'
*INTO lv_html SEPARATED BY space.
*
*
*  "-------------------------------------------------------------------
*  " 2. STRING → W3HTML (tự cắt 255 ký tự, tránh out-of-bounds)
*  "-------------------------------------------------------------------
*  CLEAR lt_html.
*
*  DATA: lv_len      TYPE i,
*        lv_off      TYPE i,
*        lv_chunklen TYPE i.
*
*  lv_len = strlen( lv_html ).
*  lv_off = 0.
*
*  WHILE lv_off < lv_len.
*    lv_chunklen = lv_len - lv_off.
*    IF lv_chunklen > 255.
*      lv_chunklen = 255.
*    ENDIF.
*
*    CLEAR ls_html.
*    ls_html-line = lv_html+lv_off(lv_chunklen).
*    APPEND ls_html TO lt_html.
*
*    lv_off = lv_off + lv_chunklen.
*  ENDWHILE.
*
*  "-------------------------------------------------------------------
*  " 3. Load HTML vào viewer
*  "-------------------------------------------------------------------
*  go_html_viewer->load_data(
*    EXPORTING
*      type = 'text/html'
*    IMPORTING
*      assigned_url = lv_url
*    CHANGING
*      data_table   = lt_html
*  ).
*
*  go_html_viewer->show_url( lv_url ).
*ENDFORM.
*FORM build_html_summary.
*  DATA: lv_html TYPE string,
*        lt_html TYPE STANDARD TABLE OF w3html,
*        ls_html TYPE w3html,
*        lv_url  TYPE char1024.
*
*  " --- Biến chứa text số lượng ---
*  DATA: txt_val_rdy  TYPE c LENGTH 10,
*        txt_val_inc  TYPE c LENGTH 10,
*        txt_val_err  TYPE c LENGTH 10,
*        txt_suc_comp TYPE c LENGTH 10,
*        txt_suc_inc  TYPE c LENGTH 10,
*        txt_fail_err TYPE c LENGTH 10.
*
*  " Convert số sang text để nối chuỗi
*  WRITE gv_cnt_val_ready   TO txt_val_rdy.   CONDENSE txt_val_rdy.
*  WRITE gv_cnt_val_incomp  TO txt_val_inc.   CONDENSE txt_val_inc.
*  WRITE gv_cnt_val_err     TO txt_val_err.   CONDENSE txt_val_err.
*  WRITE gv_cnt_suc_comp    TO txt_suc_comp.  CONDENSE txt_suc_comp.
*  WRITE gv_cnt_suc_incomp  TO txt_suc_inc.   CONDENSE txt_suc_inc.
*  WRITE gv_cnt_fail_err    TO txt_fail_err.  CONDENSE txt_fail_err.
*
*  CLEAR lv_html.
*
*  " --- START HTML & CSS ---
*  CONCATENATE lv_html
*    '<html><head><meta charset="UTF-8"><style>'
*    'body { font-family: Segoe UI, Arial, sans-serif; padding: 5px; background-color: #f2f2f2; margin: 0; }'
*
*    'h2 { color: #333; margin: 0 0 10px 0; font-size: 16px; border-bottom: 1px solid #ccc; padding-bottom: 5px; }'
*
*    '.container { display: flex; gap: 15px; }'
*
*    '.card { background: #fff; width: 220px; border-radius: 6px;'
*      'box-shadow: 0 2px 5px rgba(0,0,0,0.1); border: 1px solid #dcdcdc; overflow: hidden; }'
*
*    '.card-head { padding: 8px 12px; font-weight: bold; font-size: 13px; color: #fff; }'
*    '.head-val  { background-color: #0078d4; }'
*    '.head-suc  { background-color: #107c10; }'
*    '.head-fail { background-color: #d13438; }'
*
*    '.card-body { padding: 10px; }'
*
*    '.row { display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 13px; }'
*    '.label { color: #555; }'
*    '.value { font-weight: bold; }'
*
*    '.st-ready { color: #107c10; }'
*    '.st-warn  { color: #d83b01; }'
*    '.st-err   { color: #d13438; }'
*
*    '</style></head><body>'
*
*    '<h2>Validation & Processing Summary</h2>'
*    '<div class="container">'
*
*  INTO lv_html SEPARATED BY space.
*
*  " --- CARD 1: VALIDATED (Pending) ---
*  CONCATENATE lv_html
*    '<div class="card">'
*      '<div class="card-head head-val">📝 Validated (Pending)</div>'
*      '<div class="card-body">'
*        '<div class="row"><span class="label">Ready:</span><span class="value st-ready">'      txt_val_rdy '</span></div>'
*        '<div class="row"><span class="label">Incomplete:</span><span class="value st-warn">' txt_val_inc '</span></div>'
*        '<div class="row"><span class="label">Error:</span><span class="value st-err">'       txt_val_err '</span></div>'
*      '</div>'
*    '</div>'
*  INTO lv_html SEPARATED BY space.
*
*  " --- CARD 2: POSTED SUCCESSFULLY ---
*  CONCATENATE lv_html
*    '<div class="card">'
*      '<div class="card-head head-suc">🚀 Posted Success</div>'
*      '<div class="card-body">'
*        '<div class="row"><span class="label">Complete SO:</span><span class="value st-ready">'   txt_suc_comp '</span></div>'
*        '<div class="row"><span class="label">Incomplete SO:</span><span class="value st-warn">' txt_suc_inc  '</span></div>'
*      '</div>'
*    '</div>'
*  INTO lv_html SEPARATED BY space.
*
*  " --- CARD 3: POSTED FAILED ---
*  CONCATENATE lv_html
*    '<div class="card">'
*      '<div class="card-head head-fail">💥 Posted Failed</div>'
*      '<div class="card-body">'
*        '<div class="row"><span class="label">Failed (Error):</span><span class="value st-err">' txt_fail_err '</span></div>'
*        " (Bạn có thể thêm dòng Failed Incomplete nếu logic BAPI có trả về)
*      '</div>'
*    '</div>'
*  INTO lv_html SEPARATED BY space.
*
*  CONCATENATE lv_html '</div></body></html>' INTO lv_html.
*
*  " --- Convert & Display (Giữ nguyên code cũ) ---
*  CLEAR lt_html.
*  DATA: lv_len   TYPE i, lv_off TYPE i, lv_chunk TYPE i.
*  lv_len = strlen( lv_html ).
*  lv_off = 0.
*  WHILE lv_off < lv_len.
*    lv_chunk = lv_len - lv_off.
*    IF lv_chunk > 255. lv_chunk = 255. ENDIF.
*    ls_html-line = lv_html+lv_off(lv_chunk).
*    APPEND ls_html TO lt_html.
*    lv_off = lv_off + lv_chunk.
*  ENDWHILE.
*
*  go_html_viewer->load_data( EXPORTING type = 'text/html' IMPORTING assigned_url = lv_url CHANGING data_table = lt_html ).
*  go_html_viewer->show_url( lv_url ).
*
*ENDFORM.

"chú ý 2
FORM build_html_summary.
  DATA: lv_html TYPE string,
        lt_html TYPE STANDARD TABLE OF w3html,
        ls_html TYPE w3html,
        lv_url  TYPE char1024.

  " --- Biến chứa text số lượng ---
  DATA: txt_val_rdy   TYPE c LENGTH 10,
        txt_val_inc   TYPE c LENGTH 10,
        txt_val_err   TYPE c LENGTH 10,
        txt_suc_comp  TYPE c LENGTH 10,
        txt_suc_inc   TYPE c LENGTH 10,
        txt_fail_err  TYPE c LENGTH 10.

*  " Convert số sang text để nối chuỗi
*  WRITE gv_cnt_val_ready   TO txt_val_rdy.   CONDENSE txt_val_rdy.
*  WRITE gv_cnt_val_incomp  TO txt_val_inc.   CONDENSE txt_val_inc.
*  WRITE gv_cnt_val_err     TO txt_val_err.   CONDENSE txt_val_err.
*  WRITE gv_cnt_suc_comp    TO txt_suc_comp.  CONDENSE txt_suc_comp.
*  WRITE gv_cnt_suc_incomp  TO txt_suc_inc.   CONDENSE txt_suc_inc.
*  WRITE gv_cnt_fail_err    TO txt_fail_err.  CONDENSE txt_fail_err.

    " Convert số sang text và XÓA KHOẢNG TRẮNG
  WRITE gv_cnt_val_ready   TO txt_val_rdy.   CONDENSE txt_val_rdy NO-GAPS.
  WRITE gv_cnt_val_incomp  TO txt_val_inc.   CONDENSE txt_val_inc NO-GAPS.
  WRITE gv_cnt_val_err     TO txt_val_err.   CONDENSE txt_val_err NO-GAPS.

  " [FIX LỖI LỆCH SỐ]: Thêm NO-GAPS
  WRITE gv_cnt_suc_comp    TO txt_suc_comp.  CONDENSE txt_suc_comp NO-GAPS.
  WRITE gv_cnt_suc_incomp  TO txt_suc_inc.   CONDENSE txt_suc_inc NO-GAPS.
  WRITE gv_cnt_fail_err    TO txt_fail_err.  CONDENSE txt_fail_err NO-GAPS.

  CLEAR lv_html.

  " --- START HTML & CSS ---
  CONCATENATE lv_html
    '<html><head><meta charset="UTF-8"><style>'
    'body { font-family: Segoe UI, Arial, sans-serif; padding: 5px; background-color: #f2f2f2; margin: 0; }'

    'h2 { color: #333; margin: 0 0 10px 0; font-size: 16px; border-bottom: 1px solid #ccc; padding-bottom: 5px; }'

    '.container { display: flex; gap: 15px; }'

    '.card { background: #fff; width: 220px; border-radius: 6px;'
      'box-shadow: 0 2px 5px rgba(0,0,0,0.1); border: 1px solid #dcdcdc; overflow: hidden; }'

    '.card-head { padding: 8px 12px; font-weight: bold; font-size: 13px; color: #fff; }'
    '.head-val  { background-color: #0078d4; }'
    '.head-suc  { background-color: #107c10; }'
    '.head-fail { background-color: #d13438; }'

    '.card-body { padding: 10px; }'

    '.row { display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 13px; }'
    '.label { color: #555; }'
    '.value { font-weight: bold; }'

    '.st-ready { color: #107c10; }'
    '.st-warn  { color: #d83b01; }'
    '.st-err   { color: #d13438; }'

    '</style></head><body>'

    '<h2>Validation & Processing Summary</h2>'
    '<div class="container">'

  INTO lv_html SEPARATED BY space.

  " --- CARD 1: VALIDATED (Pending) ---
  CONCATENATE lv_html
    '<div class="card">'
      '<div class="card-head head-val">📝 Validated (Pending)</div>'
      '<div class="card-body">'
        '<div class="row"><span class="label">Ready:</span><span class="value st-ready">'      txt_val_rdy '</span></div>'
        '<div class="row"><span class="label">Incomplete:</span><span class="value st-warn">' txt_val_inc '</span></div>'
        '<div class="row"><span class="label">Error:</span><span class="value st-err">'       txt_val_err '</span></div>'
      '</div>'
    '</div>'
  INTO lv_html SEPARATED BY space.

  " --- CARD 2: POSTED SUCCESSFULLY ---
  CONCATENATE lv_html
    '<div class="card">'
      '<div class="card-head head-suc">🚀 Posted Success</div>'
      '<div class="card-body">'
        '<div class="row"><span class="label">Complete SO:</span><span class="value st-ready">'   txt_suc_comp '</span></div>'
        '<div class="row"><span class="label">Incomplete SO:</span><span class="value st-warn">' txt_suc_inc  '</span></div>'
      '</div>'
    '</div>'
  INTO lv_html SEPARATED BY space.

  " --- CARD 3: POSTED FAILED ---
  CONCATENATE lv_html
    '<div class="card">'
      '<div class="card-head head-fail">💥 Posted Failed</div>'
      '<div class="card-body">'
        '<div class="row"><span class="label">Failed (Error):</span><span class="value st-err">' txt_fail_err '</span></div>'
        " (Bạn có thể thêm dòng Failed Incomplete nếu logic BAPI có trả về)
      '</div>'
    '</div>'
  INTO lv_html SEPARATED BY space.

  CONCATENATE lv_html '</div></body></html>' INTO lv_html.

  " --- Convert & Display (Giữ nguyên code cũ) ---
  CLEAR lt_html.
  DATA: lv_len TYPE i, lv_off TYPE i, lv_chunk TYPE i.
  lv_len = strlen( lv_html ).
  lv_off = 0.
  WHILE lv_off < lv_len.
    lv_chunk = lv_len - lv_off.
    IF lv_chunk > 255. lv_chunk = 255. ENDIF.
    ls_html-line = lv_html+lv_off(lv_chunk).
    APPEND ls_html TO lt_html.
    lv_off = lv_off + lv_chunk.
  ENDWHILE.

  go_html_viewer->load_data( EXPORTING type = 'text/html' IMPORTING assigned_url = lv_url CHANGING data_table = lt_html ).
  go_html_viewer->show_url( lv_url ).

ENDFORM.

**&---------------------------------------------------------------------*
**& Form HIGHLIGHT_ERROR_CELLS (Tô màu ô Lỗi/Thiếu)
**&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy danh sách lỗi từ Database (cho REQ_ID hiện tại)
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Định nghĩa Macro để tô màu cho gọn
*  DEFINE _set_color.
*    CLEAR ls_color.
*    ls_color-fname = &1. " Tên cột bị lỗi (ví dụ: MATNR)
*    IF lv_fname_alv = 'MATERIAL'.
*       lv_fname_alv = 'MATNR'. " Đổi tên cho khớp với ALV Fieldcat
*    ENDIF.
*    IF lv_fname_alv = 'REQUEST_DEV_DATE'.
*       lv_fname_alv = 'REQ_DATE'. " Đổi tên cho khớp với ALV Fieldcat
*    ENDIF.
*    " Chọn màu: 'E' -> Đỏ (6), 'W' -> Vàng (3)
*    IF &2 = 'E'.
*      ls_color-color-col = 6. " Red
*      ls_color-color-int = 1.
*    ELSE.
*      ls_color-color-col = 3. " Yellow
*      ls_color-color-int = 1.
*    ENDIF.
*
*    " Thêm vào bảng CELLTAB của dòng ALV
*    INSERT ls_color INTO TABLE &3-celltab.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt qua từng lỗi và tô màu
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*      " === A. XỬ LÝ LỖI HEADER ===
*
*      " A1. Tìm trong bảng Header ERROR
*      READ TABLE gt_so_header_err ASSIGNING FIELD-SYMBOL(<fs_h_err>)
*        WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_err>.
*      ENDIF.
*
*      " A2. Tìm trong bảng Header INCOMPLETE (Có thể dòng đó chỉ bị Incomplete nhưng có Warning)
*      READ TABLE gt_so_header_incomp ASSIGNING FIELD-SYMBOL(<fs_h_inc>)
*        WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_inc>.
*      ENDIF.
*
*    ELSE.
*      " === B. XỬ LÝ LỖI ITEM ===
*
*      " B1. Tìm trong bảng Item ERROR
*      READ TABLE gt_so_item_err ASSIGNING FIELD-SYMBOL(<fs_i_err>)
*        WITH KEY temp_id = <fs_err>-temp_id
*                 item_no = <fs_err>-item_no.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_err>.
*      ENDIF.
*
*      " B2. Tìm trong bảng Item INCOMPLETE
*      READ TABLE gt_so_item_incomp ASSIGNING FIELD-SYMBOL(<fs_i_inc>)
*        WITH KEY temp_id = <fs_err>-temp_id
*                 item_no = <fs_err>-item_no.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_inc>.
*      ENDIF.
*    ENDIF.
*
*  ENDLOOP.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (FIXED: Macro Logic)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy danh sách lỗi
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Định nghĩa Macro (SỬA LỖI LOGIC GÁN BIẾN)
*  DEFINE _set_color.
*    CLEAR ls_color.
*
*    " [QUAN TRỌNG]: Gán giá trị tham số vào biến cục bộ TRƯỚC
*    lv_fname_alv = &1.
*
*    " [LOGIC MAPPING]: Đổi tên trường nếu cần
*    IF lv_fname_alv = 'MATERIAL'.
*       lv_fname_alv = 'MATNR'. " Đổi tên cho khớp với ALV Fieldcat Item
*    ENDIF.
*    IF lv_fname_alv = 'REQUEST_DEV_DATE'.
*       lv_fname_alv = 'REQ_DATE'. " Đổi tên cho khớp với ALV Fieldcat Header
*    ENDIF.
*
*    " Gán tên trường (đã chuẩn hóa) vào cấu trúc màu
*    ls_color-fname = lv_fname_alv.
*
*    " Chọn màu: 'E' -> Đỏ (6), 'W' -> Vàng (3)
*    IF &2 = 'E'.
*      ls_color-color-col = 6. " Red
*      ls_color-color-int = 1.
*    ELSE.
*      ls_color-color-col = 3. " Yellow
*      ls_color-color-int = 1.
*    ENDIF.
*
*    " Thêm vào bảng CELLTAB của dòng ALV
*    INSERT ls_color INTO TABLE &3-celltab.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt qua từng lỗi và tô màu
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*      " === HEADER ===
*      " (Lưu ý: Sử dụng đúng bảng Header mới gt_hd_val / gt_hd_fail)
*      " Code cũ dùng gt_so_header_err là chưa cập nhật theo kiến trúc mới
*      " Hãy kiểm tra xem bạn đang dùng bảng nào
*
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_fail>.
*      ENDIF.
*
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_val>.
*      ENDIF.
*
*    ELSE.
*      " === ITEM ===
*      READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_fail>.
*      ENDIF.
*
*      READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0.
*        _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_val>.
*      ENDIF.
*    ENDIF.
*
*  ENDLOOP.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Fix Mapping & Logic)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy log của đợt này
*  SELECT * FROM ztb_so_error_log INTO TABLE lt_error_log WHERE req_id = gv_current_req_id.
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Macro tô màu
*  DEFINE _set_color.
*    CLEAR ls_color.
*    " [FIX MAPPING]: Chuẩn hóa tên trường từ Log sang ALV
*    lv_fname_alv = &1.
*
*    " -- Mapping Header --
*    IF lv_fname_alv = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'.      ENDIF.
*    IF lv_fname_alv = 'SALES_CHANNEL'.    lv_fname_alv = 'SALES_CHANNEL'. ENDIF. " (Check kỹ xem ALV dùng DIST_CHNL hay SALES_CHANNEL)
*
*    " -- Mapping Item --
*    " Nếu ALV dùng MATERIAL thì giữ nguyên, nếu dùng MATNR thì đổi.
*    " Tốt nhất là kiểm tra Fieldcat của bạn. Ở đây ta map phòng hờ:
*    IF lv_fname_alv = 'MATERIAL'.         lv_fname_alv = 'MATERIAL'.      ENDIF.
*
*    " Gán tên
*    ls_color-fname = lv_fname_alv.
*
*    " Chọn màu: E=Đỏ(6), W=Vàng(3)
*    IF &2 = 'E'.
*      ls_color-color-col = 6.
*    ELSE.
*      ls_color-color-col = 3.
*    ENDIF.
*    ls_color-color-int = 1.
*
*    " Insert vào bảng màu (Tránh trùng lặp)
*    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
*    IF sy-subrc <> 0.
*       INSERT ls_color INTO TABLE &3-celltab.
*    ENDIF.
*  END-OF-DEFINITION.
*
*  " 3. Loop lỗi
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    " === A. HEADER ===
*    IF <fs_err>-item_no = '000000'.
*      " Tìm trong bảng Failed
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_fail>. ENDIF.
*
*      " Tìm trong bảng Validated (Ready/Incomp)
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_val>. ENDIF.
*
*    " === B. ITEM ===
*    ELSE.
*      " Tìm trong bảng Failed
*      READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_fail>. ENDIF.
*
*      " Tìm trong bảng Validated
*      READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_val>. ENDIF.
*    ENDIF.
*
*    " === C. CONDITION (Tùy chọn, nếu có lỗi Pricing) ===
*    " (Logic tương tự Item, thêm IF check Item No nếu cần phân biệt)
*
*  ENDLOOP.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Header, Item & Condition)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy danh sách lỗi
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Macro tô màu (Dùng chung cho mọi bảng)
*  DEFINE _set_color.
*    CLEAR ls_color.
*    lv_fname_alv = &1.
*
*    " --- Mapping Tên Trường (Log -> ALV) ---
*    IF lv_fname_alv = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'. ENDIF.
*    IF lv_fname_alv = 'MATERIAL'.         lv_fname_alv = 'MATERIAL'. ENDIF.
*    " (Thêm mapping khác nếu cần, ví dụ COND_TYPE -> CONDITION_TYPE nếu lệch)
*
*    ls_color-fname = lv_fname_alv.
*
*    " Chọn màu
*    IF &2 = 'E'.
*      ls_color-color-col = 6. " Red
*      ls_color-color-int = 1.
*    ELSE.
*      ls_color-color-col = 3. " Yellow
*      ls_color-color-int = 1.
*    ENDIF.
*
*    " Insert vào CELLTAB (Tránh trùng)
*    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
*    IF sy-subrc <> 0.
*       INSERT ls_color INTO TABLE &3-celltab.
*    ENDIF.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt qua từng lỗi và phân phối màu
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*      " =================================================
*      " CASE A: LỖI THUỘC VỀ HEADER (Hoặc Header Condition)
*      " =================================================
*
*      " 1. Tô màu Header Grid (Validated & Failed)
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_val>. ENDIF.
*
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_h_fail>. ENDIF.
*
*      " 2. Tô màu Condition Grid (Nếu lỗi này thuộc về Pricing Header)
*      " (Dùng LOOP vì có thể có nhiều dòng condition cho header này)
*      LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_p_val>) WHERE temp_id = <fs_err>-temp_id AND item_no = '000000'.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_p_val>.
*      ENDLOOP.
*
*      LOOP AT gt_pr_fail ASSIGNING FIELD-SYMBOL(<fs_p_fail>) WHERE temp_id = <fs_err>-temp_id AND item_no = '000000'.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_p_fail>.
*      ENDLOOP.
*
*    ELSE.
*      " =================================================
*      " CASE B: LỖI THUỘC VỀ ITEM (Hoặc Item Condition)
*      " =================================================
*
*      " 1. Tô màu Item Grid
*      READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_val>. ENDIF.
*
*      READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*           WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*      IF sy-subrc = 0. _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_i_fail>. ENDIF.
*
*      " 2. Tô màu Condition Grid [QUAN TRỌNG]
*      " (Lỗi có thể là 'AMOUNT', 'COND_TYPE'... nằm ở bảng Condition)
*      " Vì 1 Item có thể có nhiều dòng Condition -> Phải Loop
*
*      LOOP AT gt_pr_val ASSIGNING <fs_p_val>
*           WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*         " Nếu tên trường (ví dụ AMOUNT) có trong bảng Condition -> Nó sẽ được tô đỏ
*         " Nếu tên trường (ví dụ MATERIAL) không có -> ALV tự bỏ qua, không sao cả.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_p_val>.
*      ENDLOOP.
*
*      LOOP AT gt_pr_fail ASSIGNING <fs_p_fail>
*           WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*         _set_color <fs_err>-fieldname <fs_err>-msg_type <fs_p_fail>.
*      ENDLOOP.
*
*    ENDIF.
*  ENDLOOP.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Precise Logic: Header vs Item vs Cond)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy danh sách lỗi
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Định nghĩa Macro Tô màu (Dùng chung)
*  DEFINE _set_color_target.
*    CLEAR ls_color.
*    ls_color-fname = &1. " Tên cột trên ALV
*
*    " Chọn màu: E=Đỏ(6), W=Vàng(3)
*    IF &2 = 'E'.
*      ls_color-color-col = 6.
*    ELSE.
*      ls_color-color-col = 3.
*    ENDIF.
*    ls_color-color-int = 1.
*
*    " Insert vào CELLTAB của bảng đích (&3)
*    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
*    IF sy-subrc <> 0.
*       INSERT ls_color INTO TABLE &3-celltab.
*    ENDIF.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt qua từng lỗi
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    " =================================================
*    " CASE A: LỖI HEADER (Item No = 000000)
*    " =================================================
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*
*      " Map tên trường Header (Log -> ALV)
*      lv_fname_alv = <fs_err>-fieldname.
*      IF lv_fname_alv = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'.      ENDIF.
*      IF lv_fname_alv = 'SALES_CHANNEL'.    lv_fname_alv = 'SALES_CHANNEL'. ENDIF. " (Check lại Fieldcat Header)
*
*      " Tô màu Header Grid (Tìm trong cả Validated và Failed)
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color_target lv_fname_alv <fs_err>-msg_type <fs_h_fail>. ENDIF.
*
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color_target lv_fname_alv <fs_err>-msg_type <fs_h_val>. ENDIF.
*
*    " =================================================
*    " CASE B: LỖI CHI TIẾT (Item No <> 0)
*    " -> Cần phân biệt là lỗi Item hay lỗi Condition
*    " =================================================
*    ELSE.
*       lv_fname_alv = <fs_err>-fieldname.
*
*       " --- B1. Kiểm tra xem đây có phải trường của CONDITION không? ---
*       " (Danh sách các trường thuộc bảng Condition)
*       IF lv_fname_alv = 'COND_TYPE' OR lv_fname_alv = 'AMOUNT'   OR
*          lv_fname_alv = 'CURRENCY'  OR lv_fname_alv = 'PER'      OR
*          lv_fname_alv = 'UOM'. " (Lưu ý: Validator Pricing dùng 'UOM', Item dùng 'UNIT')
*
*          " => TÔ MÀU BẢNG CONDITION
*          " (Vì 1 Item có thể có nhiều dòng Condition, ta phải Loop để tô hết các dòng của Item đó,
*          "  hoặc chính xác hơn là tô dòng bị lỗi nếu Log có lưu thêm khóa phụ.
*          "  Nhưng hiện tại Log chỉ có ItemNo, nên ta tô các Condition của ItemNo đó).
*
*          LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_p_val>)
*               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*             _set_color_target lv_fname_alv <fs_err>-msg_type <fs_p_val>.
*          ENDLOOP.
*
*          LOOP AT gt_pr_fail ASSIGNING FIELD-SYMBOL(<fs_p_fail>)
*               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*             _set_color_target lv_fname_alv <fs_err>-msg_type <fs_p_fail>.
*          ENDLOOP.
*
*       " --- B2. Nếu không phải Condition -> Chắc chắn là lỗi ITEM ---
*       ELSE.
*          " Map tên trường Item (Log -> ALV)
*          IF lv_fname_alv = 'MATERIAL'. lv_fname_alv = 'MATERIAL'. ENDIF. " (Hoặc MATNR tùy fieldcat)
*          IF lv_fname_alv = 'UNIT'.     lv_fname_alv = 'UNIT'.     ENDIF. " (Validator Item dùng 'UNIT')
*
*          " => TÔ MÀU BẢNG ITEM
*          READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*          IF sy-subrc = 0.
*            _set_color_target lv_fname_alv <fs_err>-msg_type <fs_i_fail>.
*          ENDIF.
*
*          READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*          IF sy-subrc = 0.
*            _set_color_target lv_fname_alv <fs_err>-msg_type <fs_i_val>.
*          ENDIF.
*
*       ENDIF.
*
*    ENDIF.
*  ENDLOOP.
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Precise Logic: Header vs Item vs Cond)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*  DATA: lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy danh sách lỗi
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Định nghĩa Macro Tô màu (Dùng chung)
*  DEFINE _set_color_target.
*    CLEAR ls_color.
*    ls_color-fname = &1. " Tên cột trên ALV
*
*    " Chọn màu: E=Đỏ(6), W=Vàng(3)
*    IF &2 = 'E'.
*      ls_color-color-col = 6.
*    ELSE.
*      ls_color-color-col = 3.
*    ENDIF.
*    ls_color-color-int = 1.
*
*    " Insert vào CELLTAB của bảng đích (&3)
*    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
*    IF sy-subrc <> 0.
*       INSERT ls_color INTO TABLE &3-celltab.
*    ENDIF.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt qua từng lỗi
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*    " =================================================
*    " CASE A: LỖI HEADER (Item No = 000000)
*    " =================================================
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*
*      " Map tên trường Header (Log -> ALV)
*      lv_fname_alv = <fs_err>-fieldname.
*      IF lv_fname_alv = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'.      ENDIF.
*      IF lv_fname_alv = 'SALES_CHANNEL'.    lv_fname_alv = 'SALES_CHANNEL'. ENDIF. " (Check lại Fieldcat Header)
*
*      " Tô màu Header Grid (Tìm trong cả Validated và Failed)
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color_target lv_fname_alv <fs_err>-msg_type <fs_h_fail>. ENDIF.
*
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color_target lv_fname_alv <fs_err>-msg_type <fs_h_val>. ENDIF.
*
*    " =================================================
*    " CASE B: LỖI CHI TIẾT (Item No <> 0)
*    " -> Cần phân biệt là lỗi Item hay lỗi Condition
*    " =================================================
*    ELSE.
*       lv_fname_alv = <fs_err>-fieldname.
*
*       " --- B1. Kiểm tra xem đây có phải trường của CONDITION không? ---
*       " (Danh sách các trường thuộc bảng Condition)
*       IF lv_fname_alv = 'COND_TYPE' OR lv_fname_alv = 'AMOUNT'   OR
*          lv_fname_alv = 'CURRENCY'  OR lv_fname_alv = 'PER'      OR
*          lv_fname_alv = 'UOM'. " (Lưu ý: Validator Pricing dùng 'UOM', Item dùng 'UNIT')
*
*          " => TÔ MÀU BẢNG CONDITION
*          " (Vì 1 Item có thể có nhiều dòng Condition, ta phải Loop để tô hết các dòng của Item đó,
*          "  hoặc chính xác hơn là tô dòng bị lỗi nếu Log có lưu thêm khóa phụ.
*          "  Nhưng hiện tại Log chỉ có ItemNo, nên ta tô các Condition của ItemNo đó).
*
*          LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_p_val>)
*               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*             _set_color_target lv_fname_alv <fs_err>-msg_type <fs_p_val>.
*          ENDLOOP.
*
*          LOOP AT gt_pr_fail ASSIGNING FIELD-SYMBOL(<fs_p_fail>)
*               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*             _set_color_target lv_fname_alv <fs_err>-msg_type <fs_p_fail>.
*          ENDLOOP.
*
*       " --- B2. Nếu không phải Condition -> Chắc chắn là lỗi ITEM ---
*       ELSE.
*          " Map tên trường Item (Log -> ALV)
*          IF lv_fname_alv = 'MATERIAL'. lv_fname_alv = 'MATERIAL'. ENDIF. " (Hoặc MATNR tùy fieldcat)
*          IF lv_fname_alv = 'UNIT'.     lv_fname_alv = 'UNIT'.     ENDIF. " (Validator Item dùng 'UNIT')
*
*          " => TÔ MÀU BẢNG ITEM
*          READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*          IF sy-subrc = 0.
*            _set_color_target lv_fname_alv <fs_err>-msg_type <fs_i_fail>.
*          ENDIF.
*
*          READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*          IF sy-subrc = 0.
*            _set_color_target lv_fname_alv <fs_err>-msg_type <fs_i_val>.
*          ENDIF.
*
*       ENDIF.
*
*    ENDIF.
*  ENDLOOP.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Logic Phân tách: Header / Item / Cond)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form HIGHLIGHT_ERROR_CELLS (Fix Mapping & Separation)
*&---------------------------------------------------------------------*
*FORM highlight_error_cells.
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
*        ls_color     TYPE lvc_s_scol.
*  DATA: lv_fname_log TYPE fieldname,
*        lv_fname_alv TYPE fieldname.
*
*  " 1. Lấy log
*  SELECT * FROM ztb_so_error_log INTO TABLE lt_error_log WHERE req_id = gv_current_req_id.
*  IF lt_error_log IS INITIAL. RETURN. ENDIF.
*
*  " 2. Macro Tô màu
*  DEFINE _set_color.
*    CLEAR ls_color.
*    ls_color-fname = &1.
*    IF &2 = 'E'.
*      ls_color-color-col = 6. " Đỏ
*    ELSE.
*      ls_color-color-col = 3. " Vàng
*    ENDIF.
*    ls_color-color-int = 1.
*
*    " Insert vào CELLTAB (Tránh trùng)
*    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
*    IF sy-subrc <> 0.
*       INSERT ls_color INTO TABLE &3-celltab.
*    ENDIF.
*  END-OF-DEFINITION.
*
*  " 3. Duyệt lỗi
*  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
*    lv_fname_log = <fs_err>-fieldname.
*
*    " [QUAN TRỌNG]: Reset tên ALV về giống tên Log trước
*    lv_fname_alv = lv_fname_log.
*
*    " =========================================================
*    " A. XỬ LÝ MAPPING TÊN TRƯỜNG (Sửa lỗi Material không đỏ)
*    " =========================================================
*    IF lv_fname_log = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'.      ENDIF.
*    IF lv_fname_log = 'SALES_CHANNEL'.    lv_fname_alv = 'SALES_CHANNEL'. ENDIF.
*
*    " [FIX LỖI 1]: Không đổi MATERIAL thành MATNR nữa (vì ALV giờ dùng MATERIAL)
*    IF lv_fname_log = 'MATERIAL'.         lv_fname_alv = 'MATERIAL'.      ENDIF.
*
*    IF lv_fname_log = 'UNIT'.             lv_fname_alv = 'UOM'.           ENDIF.
*
*    " =========================================================
*    " B. PHÂN LOẠI BẢNG CẦN TÔ MÀU (Sửa lỗi Condition bị tô oan)
*    " =========================================================
*
*    " CASE 1: Lỗi HEADER (Item = 000000)
*    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
*      " Chỉ tô màu bảng Header (Validated & Failed)
*      READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_h_val>. ENDIF.
*
*      READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
*      IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_h_fail>. ENDIF.
*
*      " CASE 2: Lỗi ITEM/CONDITION (Item <> 0)
*    ELSE.
*      " Kiểm tra xem tên trường thuộc nhóm nào?
*      IF lv_fname_log = 'COND_TYPE' OR lv_fname_log = 'AMOUNT' OR
*         lv_fname_log = 'CURRENCY'  OR lv_fname_log = 'PER'    OR
*         lv_fname_log = 'UOM'.
*
*        " >>> ĐÂY LÀ LỖI CONDITION <<<
*        " Chỉ tô màu bảng Condition
*        LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_p_val>)
*             WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*          _set_color lv_fname_alv <fs_err>-msg_type <fs_p_val>.
*        ENDLOOP.
*
*        LOOP AT gt_pr_fail ASSIGNING FIELD-SYMBOL(<fs_p_fail>)
*             WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
*          _set_color lv_fname_alv <fs_err>-msg_type <fs_p_fail>.
*        ENDLOOP.
*
*      ELSE.
*        " >>> ĐÂY LÀ LỖI ITEM (Material, Qty, Plant...) <<<
*        " Chỉ tô màu bảng Item (TUYỆT ĐỐI KHÔNG ĐỤNG VÀO CONDITION)
*
*        READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
*             WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*        IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_i_val>. ENDIF.
*
*        READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
*             WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
*        IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_i_fail>. ENDIF.
*
*      ENDIF.
*    ENDIF.
*  ENDLOOP.
*ENDFORM.

"chú ý 2
FORM highlight_error_cells.
  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log,
        ls_color     TYPE lvc_s_scol.
  DATA: lv_fname_log TYPE fieldname,
        lv_fname_alv TYPE fieldname.

  " 1. Lấy log
  SELECT * FROM ztb_so_error_log INTO TABLE lt_error_log WHERE req_id = gv_current_req_id.
  IF lt_error_log IS INITIAL. RETURN. ENDIF.

  " 2. Macro Tô màu
  DEFINE _set_color.
    CLEAR ls_color.
    ls_color-fname = &1.
    IF &2 = 'E'.
      ls_color-color-col = 6. " Đỏ
    ELSE.
      ls_color-color-col = 3. " Vàng
    ENDIF.
    ls_color-color-int = 1.

    " Insert vào CELLTAB (Tránh trùng)
    READ TABLE &3-celltab TRANSPORTING NO FIELDS WITH KEY fname = ls_color-fname.
    IF sy-subrc <> 0.
       INSERT ls_color INTO TABLE &3-celltab.
    ENDIF.
  END-OF-DEFINITION.

  " 3. Duyệt lỗi
  LOOP AT lt_error_log ASSIGNING FIELD-SYMBOL(<fs_err>).
    lv_fname_log = <fs_err>-fieldname.

    " [QUAN TRỌNG]: Reset tên ALV về giống tên Log trước
    lv_fname_alv = lv_fname_log.

    " =========================================================
    " A. XỬ LÝ MAPPING TÊN TRƯỜNG (Sửa lỗi Material không đỏ)
    " =========================================================
    IF lv_fname_log = 'REQUEST_DEV_DATE'. lv_fname_alv = 'REQ_DATE'.      ENDIF.
    IF lv_fname_log = 'SALES_CHANNEL'.    lv_fname_alv = 'SALES_CHANNEL'. ENDIF.

    " [FIX LỖI 1]: Không đổi MATERIAL thành MATNR nữa (vì ALV giờ dùng MATERIAL)
    IF lv_fname_log = 'MATERIAL'.         lv_fname_alv = 'MATERIAL'.      ENDIF.

    IF lv_fname_log = 'UNIT'.             lv_fname_alv = 'UOM'.           ENDIF.

    " =========================================================
    " B. PHÂN LOẠI BẢNG CẦN TÔ MÀU (Sửa lỗi Condition bị tô oan)
    " =========================================================

    " CASE 1: Lỗi HEADER (Item = 000000)
    IF <fs_err>-item_no = '000000' OR <fs_err>-item_no IS INITIAL.
       " Chỉ tô màu bảng Header (Validated & Failed)
       READ TABLE gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_h_val>) WITH KEY temp_id = <fs_err>-temp_id.
       IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_h_val>. ENDIF.

       READ TABLE gt_hd_fail ASSIGNING FIELD-SYMBOL(<fs_h_fail>) WITH KEY temp_id = <fs_err>-temp_id.
       IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_h_fail>. ENDIF.

    " CASE 2: Lỗi ITEM/CONDITION (Item <> 0)
    ELSE.
       " Kiểm tra xem tên trường thuộc nhóm nào?
       IF lv_fname_log = 'COND_TYPE' OR lv_fname_log = 'AMOUNT' OR
          lv_fname_log = 'CURRENCY'  OR lv_fname_log = 'PER'    OR
          lv_fname_log = 'UOM'.

          " >>> ĐÂY LÀ LỖI CONDITION <<<
          " Chỉ tô màu bảng Condition
          LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_p_val>)
               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
             _set_color lv_fname_alv <fs_err>-msg_type <fs_p_val>.
          ENDLOOP.

          LOOP AT gt_pr_fail ASSIGNING FIELD-SYMBOL(<fs_p_fail>)
               WHERE temp_id = <fs_err>-temp_id AND item_no = <fs_err>-item_no.
             _set_color lv_fname_alv <fs_err>-msg_type <fs_p_fail>.
          ENDLOOP.

       ELSE.
          " >>> ĐÂY LÀ LỖI ITEM (Material, Qty, Plant...) <<<
          " Chỉ tô màu bảng Item (TUYỆT ĐỐI KHÔNG ĐỤNG VÀO CONDITION)

          READ TABLE gt_it_val ASSIGNING FIELD-SYMBOL(<fs_i_val>)
               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
          IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_i_val>. ENDIF.

          READ TABLE gt_it_fail ASSIGNING FIELD-SYMBOL(<fs_i_fail>)
               WITH KEY temp_id = <fs_err>-temp_id item_no = <fs_err>-item_no.
          IF sy-subrc = 0. _set_color lv_fname_alv <fs_err>-msg_type <fs_i_fail>. ENDIF.

       ENDIF.
    ENDIF.
  ENDLOOP.
ENDFORM.

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
*& Form SAVE_RAW_TO_STAGING (Đã sửa lỗi DELETE và Tên Bảng)
*&---------------------------------------------------------------------*
*FORM save_raw_to_staging
*  USING
*    iv_mode       TYPE c
*    iv_req_id_new TYPE zsd_req_id
*    it_header_raw TYPE STANDARD TABLE
*    it_item_raw   TYPE STANDARD TABLE
*    it_cond_raw   TYPE STANDARD TABLE. " [MỚI]
*
*  " (SỬA: Dùng tên bảng đúng HD/IT)
*  DATA: ls_header    TYPE ztb_so_upload_hd,
*        ls_item      TYPE ztb_so_upload_it,
*        lt_header_db TYPE TABLE OF ztb_so_upload_hd,
*        lt_item_db   TYPE TABLE OF ztb_so_upload_it.
*  DATA: ls_cond    TYPE ztb_so_upload_pr,
*        lt_cond_db TYPE TABLE OF ztb_so_upload_pr.
*
*  DATA: lt_req_ids_to_delete TYPE TABLE OF zsd_req_id.
*  " (THÊM: Biến Range để xóa dữ liệu)
*  DATA: lr_req_id    TYPE RANGE OF zsd_req_id,
*        ls_req_range LIKE LINE OF lr_req_id.
*
*  " 1. Chuẩn bị dữ liệu Header
*  LOOP AT it_header_raw ASSIGNING FIELD-SYMBOL(<fs_h>).
*    MOVE-CORRESPONDING <fs_h> TO ls_header.
*
*    IF iv_mode = 'NEW'.
*      ls_header-req_id = iv_req_id_new.
*    ELSE.
*      " Resubmit: Lấy ID từ file, đưa vào danh sách xóa
*      APPEND ls_header-req_id TO lt_req_ids_to_delete.
*    ENDIF.
*
*    ls_header-status = 'NEW'.
*    ls_header-created_by = sy-uname.
*    ls_header-created_on = sy-datum.
*    APPEND ls_header TO lt_header_db.
*  ENDLOOP.
*
*  " 2. Chuẩn bị dữ liệu Item
*  LOOP AT it_item_raw ASSIGNING FIELD-SYMBOL(<fs_i>).
*    MOVE-CORRESPONDING <fs_i> TO ls_item.
*
*    IF iv_mode = 'NEW'.
*      ls_item-req_id = iv_req_id_new.
*    ELSE.
*      APPEND ls_item-req_id TO lt_req_ids_to_delete.
*    ENDIF.
*
*    ls_item-status = 'NEW'.
*    ls_item-created_by = sy-uname.
*    ls_item-created_on = sy-datum.
*    APPEND ls_item TO lt_item_db.
*  ENDLOOP.
*
*  " --- 3. Chuẩn bị dữ liệu Condition ---
*  LOOP AT it_cond_raw ASSIGNING FIELD-SYMBOL(<fs_c>).
*    MOVE-CORRESPONDING <fs_c> TO ls_cond.
*    IF iv_mode = 'NEW'.
*      ls_cond-req_id = iv_req_id_new.
*    ENDIF.
*    ls_cond-status = 'NEW'.
*    ls_cond-created_by = sy-uname.
*    ls_cond-created_on = sy-datum.
*    APPEND ls_cond TO lt_cond_db.
*  ENDLOOP.
*
*  " --- 4. Xóa data cũ (Resubmit) ---
*  IF iv_mode = 'RESUBMIT'.
*    SORT lt_req_ids_to_delete.
*    DELETE ADJACENT DUPLICATES FROM lt_req_ids_to_delete.
*
*    IF lt_req_ids_to_delete IS NOT INITIAL.
*      " Tạo Range Table (WHERE req_id IN ...)
*      REFRESH lr_req_id.
*      ls_req_range-sign   = 'I'.
*      ls_req_range-option = 'EQ'.
*      LOOP AT lt_req_ids_to_delete INTO DATA(lv_del_id).
*        ls_req_range-low = lv_del_id.
*        APPEND ls_req_range TO lr_req_id.
*      ENDLOOP.
*
*      " Thực hiện xóa bằng Range (Cú pháp chuẩn)
*      DELETE FROM ztb_so_upload_hd WHERE req_id IN @lr_req_id.
*      DELETE FROM ztb_so_upload_it WHERE req_id IN @lr_req_id.
*      DELETE FROM ztb_so_upload_pr WHERE req_id IN @lr_req_id.
*      DELETE FROM ztb_so_error_log WHERE req_id IN @lr_req_id.
*    ENDIF.
*  ENDIF.
*
*  " 4. Insert mới (SỬA: Tên bảng HD/IT)
*  INSERT ztb_so_upload_hd FROM TABLE @lt_header_db.
*  INSERT ztb_so_upload_it FROM TABLE @lt_item_db.
*  INSERT ztb_so_upload_pr FROM TABLE @lt_cond_db. " [MỚI]
*
*  COMMIT WORK.
*
*  MESSAGE |Data saved to Staging. { lines( lt_header_db ) } Headers, { lines( lt_item_db ) } Items.| TYPE 'S'.
*ENDFORM.

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

    " [FIX QUAN TRỌNG]: Tự động đánh số Counter theo thứ tự vòng lặp
    " Đảm bảo mỗi dòng có 1 số duy nhất (1, 2, 3...) -> Không bao giờ trùng khóa
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

  " --- 4. Lưu xuống DB (Dùng MODIFY để tránh Dump) ---
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
*& FORM 6: VALIDATE_STAGING_DATA (Final Corrected Version)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form VALIDATE_STAGING_DATA (Header + Item + Pricing)
*&---------------------------------------------------------------------*
*FORM validate_staging_data USING iv_req_id TYPE zsd_req_id.
*
*  DATA: lt_header TYPE TABLE OF ztb_so_upload_hd,
*        lt_item   TYPE TABLE OF ztb_so_upload_it,
*        lt_cond   TYPE TABLE OF ztb_so_upload_pr. " [MỚI] Bảng Pricing
*
*  DATA: lt_errors_total TYPE ztty_validation_error.
*
*  " --- 1. Đọc dữ liệu từ Staging ---
*  SELECT * FROM ztb_so_upload_hd INTO TABLE lt_header WHERE req_id = iv_req_id.
*
*  IF sy-subrc <> 0.
*    MESSAGE 'No data found in Staging table to validate.' TYPE 'S' DISPLAY LIKE 'E'.
*    EXIT.
*  ENDIF.
*
*  SELECT * FROM ztb_so_upload_it INTO TABLE lt_item WHERE req_id = iv_req_id.
*  SELECT * FROM ztb_so_upload_pr INTO TABLE lt_cond WHERE req_id = iv_req_id. " [MỚI]
*
*  " --- 2. Thiết lập Class Validator ---
*  " Truyền REQ_ID vào context và xóa lỗi cũ
*  CALL METHOD zcl_sd_mass_validator=>set_context( iv_req_id ).
*  CALL METHOD zcl_sd_mass_validator=>clear_errors.
*
*  " ====================================================================
*  " A. VALIDATE HEADER
*  " ====================================================================
*  LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<fs_header>).
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_hdr
*      CHANGING cs_header = <fs_header>.
*
*    UPDATE ztb_so_upload_hd FROM <fs_header>.
*  ENDLOOP.
*
*  " ====================================================================
*  " B. VALIDATE ITEM
*  " ====================================================================
*  LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).
*
*    " Tìm Header cha
*    READ TABLE lt_header ASSIGNING FIELD-SYMBOL(<fs_header_parent>)
*      WITH KEY temp_id = <fs_item>-temp_id.
*
*    IF sy-subrc <> 0.
*      " Mất Header -> Lỗi Item
*      <fs_item>-status  = 'ERROR'.
*      <fs_item>-message = 'Parent Header missing.'.
*
*      CALL METHOD zcl_sd_mass_validator=>add_error
*        EXPORTING
*          iv_temp_id   = <fs_item>-temp_id
*          iv_item_no   = <fs_item>-item_no
*          iv_fieldname = 'TEMP_ID'
*          iv_msg_type  = 'E'
*          iv_message   = 'Parent Header missing.'.
*
*      UPDATE ztb_so_upload_it FROM <fs_item>.
*      CONTINUE.
*    ENDIF.
*
*    " Gọi Validate Item
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_itm
*       EXPORTING is_header = <fs_header_parent>
*       CHANGING  cs_item   = <fs_item>.
*
*    UPDATE ztb_so_upload_it FROM <fs_item>.
*  ENDLOOP.
*
*  " ====================================================================
*  " C. VALIDATE CONDITION [MỚI]
*  " ====================================================================
*  LOOP AT lt_cond ASSIGNING FIELD-SYMBOL(<fs_cond>).
*
*    " (Tùy chọn: Kiểm tra xem Item cha có tồn tại không, tương tự như Item check Header)
*    " Ở đây ta gọi validate trực tiếp
*
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
*      CHANGING cs_pricing = <fs_cond>.
*
*    UPDATE ztb_so_upload_pr FROM <fs_cond>.
*  ENDLOOP.
*
*  " ====================================================================
*  " D. LƯU LOG & COMMIT
*  " ====================================================================
*  " Lấy TẤT CẢ lỗi (Header + Item + Condition) từ Class
*  lt_errors_total = zcl_sd_mass_validator=>get_errors( ).
*
*  " Lưu vào bảng ZTB_SO_ERROR_LOG
*  CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
*    EXPORTING
*      it_errors = lt_errors_total.
*
*  COMMIT WORK.
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form VALIDATE_STAGING_DATA (Fix: Skip SUCCESS records)
*&---------------------------------------------------------------------*
*FORM validate_staging_data USING iv_req_id TYPE zsd_req_id.
*
*  DATA: lt_header TYPE TABLE OF ztb_so_upload_hd,
*        lt_item   TYPE TABLE OF ztb_so_upload_it,
*        lt_cond   TYPE TABLE OF ztb_so_upload_pr.
*
*  DATA: lt_errors_total TYPE ztty_validation_error.
*
*  " --- 1. Đọc dữ liệu từ Staging ---
*  SELECT * FROM ztb_so_upload_hd INTO TABLE lt_header WHERE req_id = iv_req_id.
*  IF sy-subrc <> 0. EXIT. ENDIF.
*
*  SELECT * FROM ztb_so_upload_it INTO TABLE lt_item WHERE req_id = iv_req_id.
*  SELECT * FROM ztb_so_upload_pr INTO TABLE lt_cond WHERE req_id = iv_req_id.
*
*  " --- 2. Thiết lập Class Validator ---
*  CALL METHOD zcl_sd_mass_validator=>set_context( iv_req_id ).
*  CALL METHOD zcl_sd_mass_validator=>clear_errors.
*
*  " ====================================================================
*  " A. VALIDATE HEADER
*  " ====================================================================
*  LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<fs_header>).
*
*    " [FIX QUAN TRỌNG]: Nếu đã thành công rồi thì BỎ QUA, không validate lại
*    IF <fs_header>-status = 'SUCCESS'.
*      CONTINUE.
*    ENDIF.
*
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_hdr
*      CHANGING
*        cs_header = <fs_header>.
*
*    UPDATE ztb_so_upload_hd FROM <fs_header>.
*  ENDLOOP.
*
*  " ====================================================================
*  " B. VALIDATE ITEM
*  " ====================================================================
*  LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).
*
*    " Tìm Header cha
*    READ TABLE lt_header ASSIGNING FIELD-SYMBOL(<fs_header_parent>)
*      WITH KEY temp_id = <fs_item>-temp_id.
*
*    " [FIX QUAN TRỌNG]: Nếu Header cha đã SUCCESS -> Item con cũng BỎ QUA
*    IF sy-subrc = 0 AND <fs_header_parent>-status = 'SUCCESS'.
*      CONTINUE.
*    ENDIF.
*
*    " Xử lý mất Header
*    IF sy-subrc <> 0.
*      <fs_item>-status  = 'ERROR'.
*      <fs_item>-message = 'Parent Header missing.'.
*      CALL METHOD zcl_sd_mass_validator=>add_error
*        EXPORTING
*          iv_temp_id   = <fs_item>-temp_id
*          iv_item_no   = <fs_item>-item_no
*          iv_fieldname = 'TEMP_ID'
*          iv_msg_type  = 'E'
*          iv_message   = 'Parent Header missing.'.
*      UPDATE ztb_so_upload_it FROM <fs_item>.
*      CONTINUE.
*    ENDIF.
*
*    " Gọi Validate Item
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_itm
*      EXPORTING
*        is_header = <fs_header_parent>
*      CHANGING
*        cs_item   = <fs_item>.
*
*    UPDATE ztb_so_upload_it FROM <fs_item>.
*  ENDLOOP.
*
*  " ====================================================================
*  " C. VALIDATE CONDITION
*  " ====================================================================
*  LOOP AT lt_cond ASSIGNING FIELD-SYMBOL(<fs_cond>).
*
*    " [FIX QUAN TRỌNG]: Tìm Header cha để check status SUCCESS
*    READ TABLE lt_header ASSIGNING <fs_header_parent>
*      WITH KEY temp_id = <fs_cond>-temp_id.
*
*    IF sy-subrc = 0 AND <fs_header_parent>-status = 'SUCCESS'.
*      CONTINUE. " Bỏ qua dòng này
*    ENDIF.
*
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
*      CHANGING
*        cs_pricing = <fs_cond>.
*
*    UPDATE ztb_so_upload_pr FROM <fs_cond>.
*  ENDLOOP.
*
*  " ====================================================================
*  " D. LƯU LOG & COMMIT
*  " ====================================================================
*  lt_errors_total = zcl_sd_mass_validator=>get_errors( ).
*
*  CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
*    EXPORTING
*      it_errors = lt_errors_total.
*
*  COMMIT WORK.
*
*ENDFORM.

"chú ý 2
FORM validate_staging_data USING iv_req_id TYPE zsd_req_id.

  DATA: lt_header TYPE TABLE OF ztb_so_upload_hd,
        lt_item   TYPE TABLE OF ztb_so_upload_it,
        lt_cond   TYPE TABLE OF ztb_so_upload_pr.

  DATA: lt_errors_total TYPE ztty_validation_error.
  DATA: lr_temp_id_reval TYPE RANGE OF char10.

  " --- 1. Đọc dữ liệu từ Staging ---
  SELECT * FROM ztb_so_upload_hd INTO TABLE lt_header WHERE req_id = iv_req_id.
  IF sy-subrc <> 0. EXIT. ENDIF.

  SELECT * FROM ztb_so_upload_it INTO TABLE lt_item WHERE req_id = iv_req_id.
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
      CHANGING cs_header = <fs_header>.

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
       EXPORTING is_header = <fs_header_parent>
       CHANGING  cs_item   = <fs_item>.

    UPDATE ztb_so_upload_it FROM <fs_item>.
  ENDLOOP.

  " ====================================================================
  " C. VALIDATE CONDITION
  " ====================================================================
*  LOOP AT lt_cond ASSIGNING FIELD-SYMBOL(<fs_cond>).
*    READ TABLE lt_header ASSIGNING <fs_header_parent>
*      WITH KEY temp_id = <fs_cond>-temp_id.
*
*    IF sy-subrc = 0 AND <fs_header_parent>-status = 'SUCCESS'.
*       CONTINUE.
*    ENDIF.
*
*    CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
*      CHANGING cs_pricing = <fs_cond>.
*
*    UPDATE ztb_so_upload_pr FROM <fs_cond>.
*  ENDLOOP.

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
      CHANGING cs_pricing = <fs_cond>.

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
*& Form LOAD_STAGING_FROM_DB (Logic RESUME - Sửa lỗi tham số)
*&---------------------------------------------------------------------*
*FORM load_staging_from_db USING iv_uname TYPE sy-uname.
*
*  DATA: lv_latest_req_id TYPE zsd_req_id.
*
*  " 1. Tìm Request ID mới nhất của User này mà CHƯA HOÀN THÀNH
*  " (Status khác 'POSTED' - tức là NEW, READY, INCOMP, ERROR)
*  SELECT MAX( req_id )
*    FROM ztb_so_upload_hd
*    INTO lv_latest_req_id
*    WHERE created_by = iv_uname
*      AND status    <> 'POSTED'. " Chỉ lấy cái chưa xong
*
*  " 2. Kiểm tra kết quả
*  IF lv_latest_req_id IS INITIAL.
*    MESSAGE 'No unfinished upload found for your user.' TYPE 'S' DISPLAY LIKE 'E'.
*
*    " Reset biến toàn cục để không hiển thị bậy
*    CLEAR gv_current_req_id.
*    gv_data_loaded = abap_false.
*    RETURN.
*  ENDIF.
*
*  " 3. Gán ID tìm được vào biến toàn cục
*  " (Để FORM 'load_data_from_staging' sau đó sẽ dùng ID này để lấy dữ liệu chi tiết)
*  gv_current_req_id = lv_latest_req_id.
*
*  MESSAGE |Resumed unfinished session: { gv_current_req_id }| TYPE 'S'.
*
*ENDFORM.

FORM load_staging_from_db USING iv_uname TYPE sy-uname.

  DATA: lv_latest_req_id TYPE zsd_req_id.

  " 1. Tìm Request ID mới nhất của User này mà CHƯA HOÀN THÀNH
  " (Status khác 'POSTED' - tức là NEW, READY, INCOMP, ERROR)
  SELECT MAX( req_id )
    FROM ztb_so_upload_hd
    INTO lv_latest_req_id
    WHERE created_by = iv_uname
      AND status    <> 'POSTED'. " Chỉ lấy cái chưa xong

  " 2. Kiểm tra kết quả
  IF lv_latest_req_id IS INITIAL.
    MESSAGE 'No unfinished upload found for your user.' TYPE 'S' DISPLAY LIKE 'E'.

    " Reset biến toàn cục để không hiển thị bậy
    CLEAR gv_current_req_id.
    gv_data_loaded = abap_false.
    RETURN.
  ENDIF.

  " 3. Gán ID tìm được vào biến toàn cục
  " (Để FORM 'load_data_from_staging' sau đó sẽ dùng ID này để lấy dữ liệu chi tiết)
  gv_current_req_id = lv_latest_req_id.

  MESSAGE |Resumed unfinished session: { gv_current_req_id }| TYPE 'S'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form LOAD_DATA_FROM_STAGING (Task 5.4 - Hoàn chỉnh)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form LOAD_DATA_FROM_STAGING (Logic 3 Tab Mới + Condition)
*&---------------------------------------------------------------------*
*FORM load_data_from_staging USING iv_req_id TYPE zsd_req_id.
*  " 1. Refresh toàn bộ bảng nội bộ
*  REFRESH: gt_hd_val, gt_it_val, gt_pr_val,   " Tab 1
*           gt_hd_suc, gt_it_suc, gt_pr_suc,   " Tab 2
*           gt_hd_fail, gt_it_fail, gt_pr_fail. " Tab 3
*
*  " 2. Đọc dữ liệu từ DB
*  SELECT * FROM ztb_so_upload_hd INTO TABLE @DATA(lt_hd) WHERE req_id = @iv_req_id.
*  SELECT * FROM ztb_so_upload_it INTO TABLE @DATA(lt_it) WHERE req_id = @iv_req_id.
*  SELECT * FROM ztb_so_upload_pr INTO TABLE @DATA(lt_pr) WHERE req_id = @iv_req_id.
*
*  IF lt_hd IS INITIAL. RETURN. ENDIF.
*
*  " Biến tạm cho cấu trúc ALV
*  DATA: ls_hd_alv TYPE ty_header,
*        ls_it_alv TYPE ty_item,
*        ls_pr_alv TYPE ty_condition.
*
*  " 3. Phân loại HEADER và các con của nó
*  LOOP AT lt_hd INTO DATA(ls_hd_db).
*    CLEAR ls_hd_alv.
*    MOVE-CORRESPONDING ls_hd_db TO ls_hd_alv. " (Nhớ map tay các field lệch tên như trước)
*
*    " --- Logic Phân Tab ---
*    CASE ls_hd_db-status.
*
*      " === TAB 1: VALIDATED (Chờ xử lý, đang sửa lỗi) ===
*      WHEN 'NEW' OR 'READY' OR 'INCOMP' OR 'ERROR'.
*
*        " Set Icon
*        IF ls_hd_db-status = 'ERROR'.
*          ls_hd_alv-icon = icon_led_red.
*        ELSEIF ls_hd_db-status = 'INCOMP'.
*          ls_hd_alv-icon = icon_led_yellow.
*        ELSE.
*          ls_hd_alv-icon = icon_led_green.
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_val.
*
*        " Lấy Item con của Header này đưa vào Tab Validated
*        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-matnr = ls_it_db-material. " Map tay
*           " Set Icon Item...
*           APPEND ls_it_alv TO gt_it_val.
*        ENDLOOP.
*
*        " Lấy Condition con của Header này đưa vào Tab Validated
*        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = icon_led_green. " (Condition thường xanh nếu format đúng)
*           APPEND ls_pr_alv TO gt_pr_val.
*        ENDLOOP.
*
*
*      " === TAB 2: POSTED SUCCESS (Thành công) ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*        ls_hd_alv-icon = icon_led_green.
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " Lấy Item/Cond tương ứng bỏ vào bảng _SUC
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-matnr = ls_it_db-material.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.
*
*
*      " === TAB 3: POSTED FAILED (Thất bại khi gọi BAPI) ===
*      WHEN 'FAILED'.
*        ls_hd_alv-icon = icon_led_red.
*        APPEND ls_hd_alv TO gt_hd_fail.
*
*        " Lấy Item/Cond tương ứng bỏ vào bảng _FAIL
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-matnr = ls_it_db-material.
*           APPEND ls_it_alv TO gt_it_fail.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           APPEND ls_pr_alv TO gt_pr_fail.
*        ENDLOOP.
*
*    ENDCASE.
*  ENDLOOP.
*
*  " 4. Tô màu lỗi (Chỉ cần tô cho Tab Validated và Failed)
*  PERFORM highlight_error_cells IN PROGRAM zsd4_sales_order_center.
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form LOAD_DATA_FROM_STAGING
*&---------------------------------------------------------------------*
*FORM load_data_from_staging USING iv_req_id TYPE zsd_req_id.
*
*  " 1. Refresh toàn bộ bảng nội bộ
*  REFRESH: gt_hd_val, gt_it_val, gt_pr_val,   " Tab 1: Validated
*           gt_hd_suc, gt_it_suc, gt_pr_suc,   " Tab 2: Success
*           gt_hd_fail, gt_it_fail, gt_pr_fail. " Tab 3: Failed
*
*  " 2. Đọc dữ liệu từ DB
*  SELECT * FROM ztb_so_upload_hd INTO TABLE @DATA(lt_hd) WHERE req_id = @iv_req_id.
*
*  IF lt_hd IS INITIAL. RETURN. ENDIF.
*
*  SELECT * FROM ztb_so_upload_it INTO TABLE @DATA(lt_it) WHERE req_id = @iv_req_id.
*
*  " [SỬA]: Dùng đúng tên bảng ZTB_SO_UPLOAD_PR
*  SELECT * FROM ztb_so_upload_pr INTO TABLE @DATA(lt_pr) WHERE req_id = @iv_req_id.
*
*  " Biến tạm
*  DATA: ls_hd_alv TYPE ty_header,
*        ls_it_alv TYPE ty_item,
*        ls_pr_alv TYPE ty_condition.
*
*  " 3. Phân loại HEADER và các con của nó
*  LOOP AT lt_hd INTO DATA(ls_hd_db).
*    CLEAR ls_hd_alv.
*    MOVE-CORRESPONDING ls_hd_db TO ls_hd_alv.
*
*    " --- Logic Phân Tab ---
*    CASE ls_hd_db-status.
*
*      " === TAB 1: VALIDATED (Chờ xử lý, đang sửa lỗi) ===
*      WHEN 'NEW' OR 'READY' OR 'INCOMP' OR 'ERROR'.
*
*        " Set Icon Header
*        IF ls_hd_db-status = 'ERROR'.
*          ls_hd_alv-icon = icon_led_red.
*          ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*        ELSEIF ls_hd_db-status = 'INCOMP'.
*          ls_hd_alv-icon = icon_led_yellow.
*          ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*        ELSE.
*          ls_hd_alv-icon = icon_led_green.
*          ls_header_alv-err_btn = ' '. " Hoặc icon_led_green nếu muốn
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_val.
*
*        " --- Lấy Item con (Tab Validated) ---
*        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*
*           " Set Icon Item
*           IF ls_it_db-status = 'ERROR'.
*             ls_it_alv-icon = icon_led_red.
*             ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           ELSEIF ls_it_db-status = 'INCOMP' OR ls_it_db-status = 'W'.
*             ls_it_alv-icon = icon_led_yellow.
*             ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           ELSE.
*             ls_it_alv-icon = icon_led_green.
*             ls_header_alv-err_btn = ' '. " Hoặc icon_led_green nếu muốn
*           ENDIF.
*
*           APPEND ls_it_alv TO gt_it_val.
*        ENDLOOP.
*
*        " --- Lấy Condition con (Tab Validated) ---
*        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*
*           " Set Icon Condition
*           IF ls_pr_db-status = 'ERROR'.
*              ls_pr_alv-icon = icon_led_red.
*              ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           ELSEIF ls_pr_db-status = 'INCOMP'.
*              ls_pr_alv-icon = icon_led_yellow.
*              ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           ELSE.
*              ls_pr_alv-icon = icon_led_green.
*              ls_header_alv-err_btn = ' '. " Hoặc icon_led_green nếu muốn
*           ENDIF.
*
*           APPEND ls_pr_alv TO gt_pr_val.
*        ENDLOOP.
*
*
**      " === TAB 2: POSTED SUCCESS (Thành công) ===
**      WHEN 'SUCCESS' OR 'POSTED'.
**        ls_hd_alv-icon = icon_led_green.
**        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " === TAB 2: POSTED SUCCESS (Đã tạo được SO) ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*
*        " [LOGIC MỚI]: Kiểm tra Delivery để gán màu
*        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
*          " Case 1: Có cả SO và Delivery -> XANH (Hoàn hảo)
*          ls_hd_alv-icon = icon_led_green.
*        ELSE.
*          " Case 2: Có SO nhưng thiếu Delivery -> VÀNG (Cảnh báo)
*          ls_hd_alv-icon = icon_led_yellow.
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " Item
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = icon_led_green.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*        " Condition
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = icon_led_green.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.
*
*
*      " === TAB 3: POSTED FAILED (Thất bại khi gọi BAPI) ===
*      WHEN 'FAILED'.
*        ls_hd_alv-icon = icon_led_red.
*        ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*        APPEND ls_hd_alv TO gt_hd_fail.
*
*        " Item
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = icon_led_red. " (Hoặc logic icon riêng)
*           ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           APPEND ls_it_alv TO gt_it_fail.
*        ENDLOOP.
*        " Condition
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = icon_led_red.
*           ls_header_alv-err_btn = icon_protocol. " Icon hình tờ giấy log
*           APPEND ls_pr_alv TO gt_pr_fail.
*        ENDLOOP.
*
*    ENDCASE.
*  ENDLOOP.
*
*  " 4. Tô màu lỗi
*  PERFORM highlight_error_cells IN PROGRAM ZSD4_SALES_ORDER_CENTER_LM.
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form LOAD_DATA_FROM_STAGING
*&---------------------------------------------------------------------*
*FORM load_data_from_staging USING iv_req_id TYPE zsd_req_id.
*
*  " 1. Refresh
*  REFRESH: gt_hd_val, gt_it_val, gt_pr_val,
*           gt_hd_suc, gt_it_suc, gt_pr_suc,
*           gt_hd_fail, gt_it_fail, gt_pr_fail.
*
*  " 2. Read DB
*  SELECT * FROM ztb_so_upload_hd INTO TABLE @DATA(lt_hd) WHERE req_id = @iv_req_id.
*  IF lt_hd IS INITIAL. RETURN. ENDIF.
*
*  SELECT * FROM ztb_so_upload_it INTO TABLE @DATA(lt_it) WHERE req_id = @iv_req_id.
*  SELECT * FROM ztb_so_upload_pr INTO TABLE @DATA(lt_pr) WHERE req_id = @iv_req_id.
*
*  " Biến tạm
*  DATA: ls_hd_alv TYPE ty_header,
*        ls_it_alv TYPE ty_item,
*        ls_pr_alv TYPE ty_condition.
*
*  " 3. Phân loại
*  LOOP AT lt_hd INTO DATA(ls_hd_db).
*    CLEAR ls_hd_alv.
*    MOVE-CORRESPONDING ls_hd_db TO ls_hd_alv.
*
*    CASE ls_hd_db-status.
*
*        " === TAB 1: VALIDATED ===
*      WHEN 'NEW' OR 'READY' OR 'INCOMP' OR 'ERROR'.
*
*        " Icon & Err Btn cho Header
*        IF ls_hd_db-status = 'ERROR'.
*          ls_hd_alv-icon    = icon_led_red.
*          ls_hd_alv-err_btn = icon_protocol. " [SỬA]: Dùng ls_hd_alv
*        ELSEIF ls_hd_db-status = 'INCOMP'.
*          ls_hd_alv-icon    = icon_led_yellow.
*          ls_hd_alv-err_btn = icon_protocol. " [SỬA]
*        ELSE.
*          ls_hd_alv-icon    = icon_led_green.
*          ls_hd_alv-err_btn = ' '.
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_val.
*
*        " --- Item ---
*        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
*          CLEAR ls_it_alv.
*          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*
*          " Icon & Err Btn cho Item
*          IF ls_it_db-status = 'ERROR'.
*            ls_it_alv-icon    = icon_led_red.
*            ls_it_alv-err_btn = icon_protocol. " [MỚI]: Gán cho Item
*          ELSEIF ls_it_db-status = 'INCOMP' OR ls_it_db-status = 'W'.
*            ls_it_alv-icon    = icon_led_yellow.
*            ls_it_alv-err_btn = icon_protocol. " [MỚI]
*          ELSE.
*            ls_it_alv-icon    = icon_led_green.
*            ls_it_alv-err_btn = ' '.
*          ENDIF.
*
*          APPEND ls_it_alv TO gt_it_val.
*        ENDLOOP.
*
*        " --- Condition ---
*        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
*          CLEAR ls_pr_alv.
*          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*
*          " Icon & Err Btn cho Condition
*          IF ls_pr_db-status = 'ERROR'.
*            ls_pr_alv-icon    = icon_led_red.
*            ls_pr_alv-err_btn = icon_protocol. " [MỚI]
*          ELSEIF ls_pr_db-status = 'INCOMP'.
*            ls_pr_alv-icon    = icon_led_yellow.
*            ls_pr_alv-err_btn = icon_protocol. " [MỚI]
*          ELSE.
*            ls_pr_alv-icon    = icon_led_green.
*            ls_pr_alv-err_btn = ' '.
*          ENDIF.
*
*          APPEND ls_pr_alv TO gt_pr_val.
*        ENDLOOP.
*
*
**      " === TAB 2: SUCCESS ===
**      WHEN 'SUCCESS' OR 'POSTED'.
**        " Logic Delivery Check
**        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
**          ls_hd_alv-icon = icon_led_green.
**        ELSE.
**          ls_hd_alv-icon = icon_led_yellow.
**        ENDIF.
**        ls_hd_alv-err_btn = ' '. " Success không có lỗi
**
**        APPEND ls_hd_alv TO gt_hd_suc.
**
**        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
**           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
**           ls_it_alv-icon = icon_led_green.
**           ls_it_alv-err_btn = ' '.
**           APPEND ls_it_alv TO gt_it_suc.
**        ENDLOOP.
**        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
**           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
**           ls_pr_alv-icon = icon_led_green.
**           ls_pr_alv-err_btn = ' '.
**           APPEND ls_pr_alv TO gt_pr_suc.
**        ENDLOOP.
*
*        " === TAB 2: SUCCESS ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*        " Logic Delivery Check
*        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
*          ls_hd_alv-icon = icon_led_green.
*          ls_hd_alv-err_btn = ' '. " Hoàn hảo -> Không cần log
*        ELSE.
*          " Incomplete (Thiếu Delivery hoặc SO Incomplete) -> Vàng
*          ls_hd_alv-icon = icon_led_yellow.
*          ls_hd_alv-err_btn = icon_protocol. " [SỬA]: Hiện nút để xem Incomplete Log
*        ENDIF.
*
*        " (Nếu bạn muốn check kỹ hơn trường message xem có chữ 'Incomplete' không thì check thêm ở đây)
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*          ls_it_alv-icon = icon_led_green. " Item thường xanh khi Header Success
*          ls_it_alv-err_btn = ' '.
*          APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*          ls_pr_alv-icon = icon_led_green.
*          ls_pr_alv-err_btn = ' '.
*          APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.
*
*
**        " === TAB 2: POSTED SUCCESS ===
**      WHEN 'SUCCESS' OR 'POSTED'.
**
**        " 1. Xác định màu đèn dựa trên DB (Do perform_create đã lưu vào DB)
**        " (Nếu trong DB đã lưu icon vàng thì lấy vàng, nếu không thì xanh)
**        ls_hd_alv-icon = ls_hd_db-icon.
**        IF ls_hd_alv-icon IS INITIAL. ls_hd_alv-icon = icon_led_green. ENDIF.
**
**        " [FIX 1]: Hiển thị nút Log nếu bị Incomplete (Vàng)
**        IF ls_hd_alv-icon = icon_led_yellow.
**           ls_hd_alv-err_btn = icon_protocol. " Hiện icon tờ giấy
**
**           " [FIX 2]: Tô màu Vàng cho ô Sales Order Number
**           CLEAR ls_color_cell.
**           ls_color_cell-fname     = 'VBELN_SO'.
**           ls_color_cell-color-col = 3. " Vàng
**           ls_color_cell-color-int = 1.
**           INSERT ls_color_cell INTO TABLE ls_hd_alv-celltab.
**        ELSE.
**           ls_hd_alv-err_btn = ' '. " Xanh thì ẩn nút log
**        ENDIF.
**
**        " (Logic kiểm tra Delivery cũ nếu muốn giữ kết hợp)
**        " IF ls_hd_db-vbeln_dlv IS INITIAL AND ... -> Có thể set Vàng ở đây nếu muốn
**
**        APPEND ls_hd_alv TO gt_hd_suc.
**
**        " Xử lý Item/Cond con
**        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
**           CLEAR ls_it_alv.
**           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
**           ls_it_alv-icon = ls_hd_alv-icon. " Item ăn theo màu Header
**           APPEND ls_it_alv TO gt_it_suc.
**        ENDLOOP.
**
**        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
**           CLEAR ls_pr_alv.
**           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
**           ls_pr_alv-icon = ls_hd_alv-icon.
**           APPEND ls_pr_alv TO gt_pr_suc.
**        ENDLOOP.
*
*
*        " === TAB 3: FAILED ===
*      WHEN 'FAILED'.
*        ls_hd_alv-icon    = icon_led_red.
*        ls_hd_alv-err_btn = icon_protocol. " [SỬA]
*        APPEND ls_hd_alv TO gt_hd_fail.
*
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*          MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*          ls_it_alv-icon    = icon_led_red.
*          ls_it_alv-err_btn = icon_protocol. " [SỬA]: Nên hiện lỗi nếu có
*          APPEND ls_it_alv TO gt_it_fail.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*          MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*          ls_pr_alv-icon    = icon_led_red.
*          ls_pr_alv-err_btn = icon_protocol. " [SỬA]
*          APPEND ls_pr_alv TO gt_pr_fail.
*        ENDLOOP.
*
*    ENDCASE.
*  ENDLOOP.
*
*  PERFORM highlight_error_cells.
*
*ENDFORM.

"chú ý 2
FORM load_data_from_staging USING iv_req_id TYPE zsd_req_id.

  " 1. Refresh
  REFRESH: gt_hd_val, gt_it_val, gt_pr_val,
           gt_hd_suc, gt_it_suc, gt_pr_suc,
           gt_hd_fail, gt_it_fail, gt_pr_fail.

  " 2. Read DB
  SELECT * FROM ztb_so_upload_hd INTO TABLE @DATA(lt_hd) WHERE req_id = @iv_req_id.
  IF lt_hd IS INITIAL. RETURN. ENDIF.

  SELECT * FROM ztb_so_upload_it INTO TABLE @DATA(lt_it) WHERE req_id = @iv_req_id.
  SELECT * FROM ztb_so_upload_pr INTO TABLE @DATA(lt_pr) WHERE req_id = @iv_req_id.

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


*      " === TAB 2: SUCCESS ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*        " Logic Delivery Check
*        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
*          ls_hd_alv-icon = icon_led_green.
*        ELSE.
*          ls_hd_alv-icon = icon_led_yellow.
*        ENDIF.
*        ls_hd_alv-err_btn = ' '. " Success không có lỗi
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = icon_led_green.
*           ls_it_alv-err_btn = ' '.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = icon_led_green.
*           ls_pr_alv-err_btn = ' '.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.

*        " === TAB 2: SUCCESS ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*        " Logic Delivery Check
*        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
*          ls_hd_alv-icon = icon_led_green.
*          ls_hd_alv-err_btn = ' '. " Hoàn hảo -> Không cần log
*        ELSE.
*          " Incomplete (Thiếu Delivery hoặc SO Incomplete) -> Vàng
*          ls_hd_alv-icon = icon_led_yellow.
*          ls_hd_alv-err_btn = icon_protocol. " [SỬA]: Hiện nút để xem Incomplete Log
*        ENDIF.
*
*        " (Nếu bạn muốn check kỹ hơn trường message xem có chữ 'Incomplete' không thì check thêm ở đây)
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = icon_led_green. " Item thường xanh khi Header Success
*           ls_it_alv-err_btn = ' '.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = icon_led_green.
*           ls_pr_alv-err_btn = ' '.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.

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

*        " === TAB 2: POSTED SUCCESS ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*
*        " 1. Lấy Icon chuẩn từ DB (Nguồn sự thật duy nhất)
*        ls_hd_alv-icon = ls_hd_db-icon.
*
*        " Fallback: Nếu dữ liệu cũ chưa có icon thì mặc định xanh
*        IF ls_hd_alv-icon IS INITIAL. ls_hd_alv-icon = icon_led_green. ENDIF.
*
*        " 2. Quyết định hiện nút Log dựa trên Icon
*        IF ls_hd_alv-icon = icon_led_yellow.
*           " Chỉ hiện nút Log nếu thực sự là Incomplete (Vàng)
*           ls_hd_alv-err_btn = icon_protocol.
*        ELSE.
*           " Xanh (Success hoàn toàn) -> Ẩn nút Log
*           ls_hd_alv-err_btn = ' '.
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " Xử lý Item/Cond (Ăn theo màu Header)
*        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = ls_hd_alv-icon.
*           ls_it_alv-err_btn = ' '.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*
*        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = ls_hd_alv-icon.
*           ls_pr_alv-err_btn = ' '.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.


*         " =========================================================
*      " TAB 2: POSTED SUCCESS (Logic Màu & Icon Chính Xác)
*      " =========================================================
*      WHEN 'SUCCESS' OR 'POSTED'.
*
*        " 1. Mặc định là Xanh (Success)
*        ls_hd_alv-icon = icon_led_green.
*
*        " 2. Kiểm tra xem có phải là Success nhưng Incomplete không?
*        " (Dựa vào MESSAGE hoặc STATUS cũ nếu bạn có lưu status phụ)
*        " Hoặc đơn giản là check xem có log Warning trong bảng Error Log không
*
*        DATA: lv_has_warning TYPE abap_bool.
*        SELECT SINGLE @abap_true FROM ztb_so_error_log
*          INTO @lv_has_warning
*          WHERE req_id = @ls_hd_db-req_id
*            AND temp_id = @ls_hd_db-temp_id
*            AND msg_type = 'W'.
*
*        IF lv_has_warning = abap_true.
*           " Có Warning -> Icon Vàng, Hiện nút Log
*           ls_hd_alv-icon    = icon_led_yellow.
*           ls_hd_alv-err_btn = icon_protocol.
*
*           " Tô màu Vàng ô Sales Doc để gây chú ý
*           CLEAR ls_color_cell.
*           ls_color_cell-fname     = 'VBELN_SO'.
*           ls_color_cell-color-col = 3.
*           ls_color_cell-color-int = 1.
*           INSERT ls_color_cell INTO TABLE ls_hd_alv-celltab.
*
*        ELSE.
*           " Hoàn hảo -> Icon Xanh, Ẩn nút Log
*           ls_hd_alv-icon    = icon_led_green.
*           ls_hd_alv-err_btn = ' '.
*
*           " Tô màu Xanh ô Sales Doc & Delivery (nếu có)
*           CLEAR ls_color_cell.
*           ls_color_cell-fname     = 'VBELN_SO'.
*           ls_color_cell-color-col = 5.
*           ls_color_cell-color-int = 1.
*           INSERT ls_color_cell INTO TABLE ls_hd_alv-celltab.
*
*           IF ls_hd_alv-vbeln_dlv IS NOT INITIAL.
*             ls_color_cell-fname = 'VBELN_DLV'.
*             INSERT ls_color_cell INTO TABLE ls_hd_alv-celltab.
*           ENDIF.
*        ENDIF.
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " Item/Cond ăn theo màu Header
*        LOOP AT lt_it INTO DATA(ls_it_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = ls_hd_alv-icon.
*           ls_it_alv-err_btn = ' '.
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*
*        LOOP AT lt_pr INTO DATA(ls_pr_db) WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = ls_hd_alv-icon.
*           ls_pr_alv-err_btn = ' '.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.


*        " === TAB 2: POSTED SUCCESS ===
*      WHEN 'SUCCESS' OR 'POSTED'.
*
*        " 1. Xác định màu đèn dựa trên DB (Do perform_create đã lưu vào DB)
*        " (Nếu trong DB đã lưu icon vàng thì lấy vàng, nếu không thì xanh)
*        ls_hd_alv-icon = ls_hd_db-icon.
*        IF ls_hd_alv-icon IS INITIAL. ls_hd_alv-icon = icon_led_green. ENDIF.
*
*        " [FIX 1]: Hiển thị nút Log nếu bị Incomplete (Vàng)
*        IF ls_hd_alv-icon = icon_led_yellow.
*           ls_hd_alv-err_btn = icon_protocol. " Hiện icon tờ giấy
*
*           " [FIX 2]: Tô màu Vàng cho ô Sales Order Number
*           CLEAR ls_color_cell.
*           ls_color_cell-fname     = 'VBELN_SO'.
*           ls_color_cell-color-col = 3. " Vàng
*           ls_color_cell-color-int = 1.
*           INSERT ls_color_cell INTO TABLE ls_hd_alv-celltab.
*        ELSE.
*           ls_hd_alv-err_btn = ' '. " Xanh thì ẩn nút log
*        ENDIF.
*
*        " (Logic kiểm tra Delivery cũ nếu muốn giữ kết hợp)
*        " IF ls_hd_db-vbeln_dlv IS INITIAL AND ... -> Có thể set Vàng ở đây nếu muốn
*
*        APPEND ls_hd_alv TO gt_hd_suc.
*
*        " Xử lý Item/Cond con
*        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_it_alv.
*           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
*           ls_it_alv-icon = ls_hd_alv-icon. " Item ăn theo màu Header
*           APPEND ls_it_alv TO gt_it_suc.
*        ENDLOOP.
*
*        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
*           CLEAR ls_pr_alv.
*           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
*           ls_pr_alv-icon = ls_hd_alv-icon.
*           APPEND ls_pr_alv TO gt_pr_suc.
*        ENDLOOP.


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

*  " 2. [THÊM MỚI] Tô màu Success (Cho tab Success) - Cái mới
  PERFORM highlight_success_cells.

*  " 1. Cấu hình Sort & Merge cho ITEM ALV
*  DATA: lt_sort_it TYPE lvc_t_sort,
*        ls_sort_it TYPE lvc_s_sort.
*
*  " Merge cột TEMP_ID
*  ls_sort_it-fieldname = 'TEMP_ID'.
*  ls_sort_it-up        = 'X'.   " Sắp xếp tăng dần
*  ls_sort_it-group     = 'UL'.  " [QUAN TRỌNG]: UL = Underline (Merge ô và gạch chân ngăn cách)
*  APPEND ls_sort_it TO lt_sort_it.
*
*  " Đẩy cấu hình Sort vào Grid Item
*  IF go_grid_itm_val IS BOUND.
*    go_grid_itm_val->set_sort_criteria( lt_sort_it ).
*  ENDIF.
*  IF go_grid_itm_fail IS BOUND.
*    go_grid_itm_fail->set_sort_criteria( lt_sort_it ).
*  ENDIF.
*
*  " 2. Cấu hình Sort & Merge cho CONDITION ALV
*  DATA: lt_sort_pr TYPE lvc_t_sort,
*        ls_sort_pr TYPE lvc_s_sort.
*
*  " Merge cột TEMP_ID
*  ls_sort_pr-fieldname = 'TEMP_ID'.
*  ls_sort_pr-up        = 'X'.
*  ls_sort_pr-group     = 'UL'.
*  APPEND ls_sort_pr TO lt_sort_pr.
*
*  " Merge cột ITEM_NO (Để biết Condition nào thuộc Item nào)
*  ls_sort_pr-fieldname = 'ITEM_NO'.
*  ls_sort_pr-up        = 'X'.
*  ls_sort_pr-group     = 'UL'.
*  APPEND ls_sort_pr TO lt_sort_pr.
*
*  " Đẩy cấu hình Sort vào Grid Condition
*  IF go_grid_cnd_val IS BOUND.
*    go_grid_cnd_val->set_sort_criteria( lt_sort_pr ).
*  ENDIF.
*  IF go_grid_cnd_fail IS BOUND.
*    go_grid_cnd_fail->set_sort_criteria( lt_sort_pr ).
*  ENDIF.
*
*  " Refresh lại để thấy hiệu ứng
*  PERFORM refresh_all_alvs.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_SELECT_UPLOAD_MODE
*&---------------------------------------------------------------------*
FORM popup_select_upload_mode CHANGING cv_mode TYPE c.
  DATA: lt_spopli TYPE TABLE OF spopli,
        ls_spopli TYPE spopli,
        lv_answer TYPE c.

  CLEAR cv_mode.

  " 1. Định nghĩa 3 lựa chọn (Options)
  ls_spopli-varoption = '1. Upload new file'.
  APPEND ls_spopli TO lt_spopli.

*  ls_spopli-varoption = '2. Resubmit error file'.
*  APPEND ls_spopli TO lt_spopli.
*
*  ls_spopli-varoption = '3. Resume unfinished upload'.
*  APPEND ls_spopli TO lt_spopli.

  " 2. Gọi Popup chuẩn (Giống nhóm CRP)
  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel              = 'Select Upload Mode'
      textline1          = 'Please choose how you want to proceed:'
      cursorline         = 1
      display_only       = space
    IMPORTING
      answer             = lv_answer
    TABLES
      t_spopli           = lt_spopli
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_many_lines     = 3
      OTHERS             = 4.

  " 3. Xử lý kết quả trả về
  IF sy-subrc = 0 AND lv_answer <> 'A'. " 'A' là Cancel
    CASE lv_answer.
      WHEN '1'. cv_mode = 'N'. " New
*      WHEN '2'. cv_mode = 'R'. " Resubmit
*      WHEN '3'. cv_mode = 'C'. " Continue (Resume)
    ENDCASE.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_SELECT_SO_ACTION
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
*  ls_spopli-varoption = '3. Search & Process Orders'.
*  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel        = 'Manage Sales Order'
      textline1    = 'Please select an action:'
      cursorline   = 1
      display_only = space
    IMPORTING
      answer       = cv_answer
    TABLES
      t_spopli     = lt_spopli
    EXCEPTIONS
      OTHERS       = 1.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_SELECT_BILLING_ACTION
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
      titel      = 'Manage Billing'
      textline1  = 'Please select an action:'
      cursorline = 1
    IMPORTING
      answer     = cv_answer
    TABLES
      t_spopli   = lt_spopli
    EXCEPTIONS
      OTHERS     = 1.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_SELECT_OVERVIEW_ACTION
*&---------------------------------------------------------------------*
FORM popup_select_overview_action CHANGING cv_answer TYPE c.
  DATA: lt_spopli TYPE TABLE OF spopli,
        ls_spopli TYPE spopli.

  CLEAR cv_answer.

  ls_spopli-varoption = '1. Track Sales Order (Details Status)'.
  APPEND ls_spopli TO lt_spopli.
  ls_spopli-varoption = '2. Report Monitoring (General View)'.
  APPEND ls_spopli TO lt_spopli.
*  ls_spopli-varoption = '3. Change Log (History)'.
*  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel      = 'Overview & Reports'
      textline1  = 'Please select a report:'
      cursorline = 1
    IMPORTING
      answer     = cv_answer
    TABLES
      t_spopli   = lt_spopli
    EXCEPTIONS
      OTHERS     = 1.
ENDFORM.

FORM display_welcome_screen .

  DATA: lv_html TYPE string,
        lt_html TYPE STANDARD TABLE OF w3html,
        ls_html TYPE w3html,
        lv_url  TYPE char1024,
        lv_len      TYPE i,
        lv_off      TYPE i,
        lv_chunklen TYPE i.

  "--------------------------------------------------------------------
  " 1. Tạo Container & HTML Viewer (Chỉ tạo nếu chưa có)
  "--------------------------------------------------------------------
  IF go_summary_container IS INITIAL.
    CREATE OBJECT go_summary_container
      EXPORTING
        container_name = 'CC_SUMMARY'.      " Tên Custom Control trên màn hình 0200
  ENDIF.

  IF go_html_viewer IS INITIAL.
    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = go_summary_container.
  ENDIF.

  "--------------------------------------------------------------------
  " 2. Xây dựng nội dung HTML (Phiên bản Rộng & To hơn)
  "--------------------------------------------------------------------
  CLEAR lv_html.

  CONCATENATE lv_html
    '<html><head><meta charset="UTF-8"><style>'

    " --- Tăng cỡ chữ cơ bản lên 14px ---
    'body { font-family: "Segoe UI", Arial, sans-serif; padding: 20px; background-color: #fafafa; font-size: 14px; }'

    'h2 { color: #1a73e8; margin-bottom: 12px; font-size: 24px; font-weight: 600; }'
    'p.subtitle { color: #555; font-size: 15px; margin-top: 0; margin-bottom: 20px; line-height: 1.5; }'

    " --- Tăng chiều rộng card lên 850px (hoặc 95%) để không bị chật ---
    '.welcome-card { background: #ffffff; padding: 25px 30px;'
      'border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);'
      'border: 1px solid #e3e3e3; max-width: 850px; width: 95%; }'

    '.row { display: flex; gap: 20px; margin-top: 15px; flex-wrap: wrap; }'

    " --- Chỉnh lại các ô Step cho thoáng hơn ---
    '.step { flex: 1; background: #f8f9fb; padding: 15px; border-radius: 8px;'
      'border: 1px solid #e1e4ea; min-width: 200px; }'

    '.step-title { font-size: 15px; font-weight: 700; color: #202124; margin-bottom: 8px; }'
    '.step-text { font-size: 13px; color: #444; margin: 0; line-height: 1.4; }'

    '.hint { font-size: 13px; color: #666; margin-top: 20px; background: #fff8e1; padding: 10px; border-radius: 6px; border: 1px solid #ffe082; }'
    '.badge { display: inline-block; padding: 3px 8px; border-radius: 12px;'
      'font-size: 12px; background: #e8f0fe; color: #1a73e8; margin-right: 6px; font-weight: bold; }'

    'b { color: #000; }'

    '</style></head><body>'

    '<h2>Mass Sales Order Upload</h2>'

    '<div class="welcome-card">'
      '<p class="subtitle">Welcome! No data has been uploaded yet. Please follow the standard process below to create Sales Orders in bulk.</p>'

      '<div class="row">'

        " --- STEP 1 ---
        '<div class="step">'
          '<div class="step-title">1. Upload Excel File</div>'
          '<p class="step-text">Click the <b>Upload File</b> button to select your Excel template. Ensure the file format matches the standard template.</p>'
        '</div>'

        " --- STEP 2 ---
        '<div class="step">'
          '<div class="step-title">2. Validate Data</div>'
          '<p class="step-text">The system will validate logic automatically. Check the <b>Validated</b> tab to fix any <b>Incomplete</b> or <b>Error</b> rows.</p>'
        '</div>'

        " --- STEP 3 ---
        '<div class="step">'
          '<div class="step-title">3. Create Sales Orders</div>'
          '<p class="step-text">Click <b>Create Sales Order</b>. Successful orders will move to the <b>Posted Success</b> tab, while errors go to <b>Posted Failed</b>.</p>'
        '</div>'

      '</div>'

      '<p class="hint">'
        '<b>Tip:</b> Start by clicking the <b>Upload File</b> button in the toolbar above.'
      '</p>'

    '</div>'

    '</body></html>'
  INTO lv_html SEPARATED BY space.

  "--------------------------------------------------------------------
  " 3. Convert STRING -> W3HTML (Chia nhỏ string để load vào Viewer)
  "--------------------------------------------------------------------
  CLEAR lt_html.
  lv_len = strlen( lv_html ).
  lv_off = 0.

  WHILE lv_off < lv_len.
    lv_chunklen = lv_len - lv_off.
    IF lv_chunklen > 255.
      lv_chunklen = 255.
    ENDIF.

    CLEAR ls_html.
    ls_html-line = lv_html+lv_off(lv_chunklen).
    APPEND ls_html TO lt_html.

    lv_off = lv_off + lv_chunklen.
  ENDWHILE.

  "--------------------------------------------------------------------
  " 4. Hiển thị lên màn hình
  "--------------------------------------------------------------------
  go_html_viewer->load_data(
    EXPORTING
      type = 'text/html'
    IMPORTING
      assigned_url = lv_url
    CHANGING
      data_table   = lt_html
  ).

  go_html_viewer->show_url( lv_url ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SYNC_ALV_TO_STAGING_TABLES
*&---------------------------------------------------------------------*
*FORM sync_alv_to_staging_tables.
*  DATA: ls_header_db TYPE ztb_so_upload_hd,
*        ls_item_db   TYPE ztb_so_upload_it.
*
*  " --- 1. Đồng bộ Header (Tab Incomplete & Error) ---
*  " (Tab Complete bị khóa nên không cần sync)
*
*  LOOP AT gt_so_header_incomp ASSIGNING FIELD-SYMBOL(<fs_h_inc>).
*    MOVE-CORRESPONDING <fs_h_inc> TO ls_header_db.
*    ls_header_db-req_date = <fs_h_inc>-request_dev_date.
*    " Lưu ý: Nếu tên trường ALV khác Z-table, phải gán thủ công ở đây giống lúc Load
*    " Ví dụ: ls_header_db-order_type = <fs_h_inc>-order_type.
*
*    UPDATE ztb_so_upload_hd FROM ls_header_db.
*  ENDLOOP.
*
*  LOOP AT gt_so_header_err ASSIGNING FIELD-SYMBOL(<fs_h_err>).
*    MOVE-CORRESPONDING <fs_h_err> TO ls_header_db.
*    UPDATE ztb_so_upload_hd FROM ls_header_db.
*  ENDLOOP.
*
*  " --- 2. Đồng bộ Item (Tab Incomplete & Error) ---
*
*  LOOP AT gt_so_item_incomp ASSIGNING FIELD-SYMBOL(<fs_i_inc>).
*    MOVE-CORRESPONDING <fs_i_inc> TO ls_item_db.
*    " Map thủ công nếu tên khác: ls_item_db-material = <fs_i_inc>-matnr.
*    ls_item_db-material = <fs_i_inc>-matnr.
*
*    UPDATE ztb_so_upload_it FROM ls_item_db.
*  ENDLOOP.
*
*  LOOP AT gt_so_item_err ASSIGNING FIELD-SYMBOL(<fs_i_err>).
*    MOVE-CORRESPONDING <fs_i_err> TO ls_item_db.
**    ls_item_db-material = <fs_i_err>-matnr.
*    UPDATE ztb_so_upload_it FROM ls_item_db.
*  ENDLOOP.
*
*  COMMIT WORK.
*ENDFORM.
*FORM sync_alv_to_staging_tables.
*  DATA: ls_hd_db TYPE ztb_so_upload_hd,
*        ls_it_db TYPE ztb_so_upload_it,
*        ls_pr_db TYPE ztb_so_upload_pr.
*
*  " 1. Sync Header (Validated & Failed)
*  LOOP AT gt_hd_val INTO DATA(ls_val_h).
*    MOVE-CORRESPONDING ls_val_h TO ls_hd_db.
*    UPDATE ztb_so_upload_hd FROM ls_hd_db.
*  ENDLOOP.
*  LOOP AT gt_hd_fail INTO DATA(ls_fail_h).
*    MOVE-CORRESPONDING ls_fail_h TO ls_hd_db.
*    UPDATE ztb_so_upload_hd FROM ls_hd_db.
*  ENDLOOP.
*
*  " 2. Sync Item
*  LOOP AT gt_it_val INTO DATA(ls_val_i).
*    MOVE-CORRESPONDING ls_val_i TO ls_it_db.
*    " [LƯU Ý]: Map tay nếu tên trường lệch
*    ls_it_db-material = ls_val_i-material.
*    UPDATE ztb_so_upload_it FROM ls_it_db.
*  ENDLOOP.
*  LOOP AT gt_it_fail INTO DATA(ls_fail_i).
*    MOVE-CORRESPONDING ls_fail_i TO ls_it_db.
*    ls_it_db-material = ls_fail_i-material.
*    UPDATE ztb_so_upload_it FROM ls_it_db.
*  ENDLOOP.
*
*  " 3. Sync Condition
*  LOOP AT gt_pr_val INTO DATA(ls_val_p).
*    MOVE-CORRESPONDING ls_val_p TO ls_pr_db.
*    UPDATE ztb_so_upload_pr FROM ls_pr_db.
*  ENDLOOP.
*  LOOP AT gt_pr_fail INTO DATA(ls_fail_p).
*    MOVE-CORRESPONDING ls_fail_p TO ls_pr_db.
*    UPDATE ztb_so_upload_pr FROM ls_pr_db.
*  ENDLOOP.
*
*  COMMIT WORK.
*ENDFORM.

"chú ý 2
FORM sync_alv_to_staging_tables.
  DATA: ls_hd_db TYPE ztb_so_upload_hd,
        ls_it_db TYPE ztb_so_upload_it,
        ls_pr_db TYPE ztb_so_upload_pr.

  " 1. Sync Header (Validated & Failed)
  LOOP AT gt_hd_val INTO DATA(ls_val_h).
    MOVE-CORRESPONDING ls_val_h TO ls_hd_db.
    UPDATE ztb_so_upload_hd FROM ls_hd_db.
  ENDLOOP.
  LOOP AT gt_hd_fail INTO DATA(ls_fail_h).
    MOVE-CORRESPONDING ls_fail_h TO ls_hd_db.
    UPDATE ztb_so_upload_hd FROM ls_hd_db.
  ENDLOOP.

  " 2. Sync Item
  LOOP AT gt_it_val INTO DATA(ls_val_i).
    MOVE-CORRESPONDING ls_val_i TO ls_it_db.
    " [LƯU Ý]: Map tay nếu tên trường lệch
    ls_it_db-material = ls_val_i-material.
    UPDATE ztb_so_upload_it FROM ls_it_db.
  ENDLOOP.
  LOOP AT gt_it_fail INTO DATA(ls_fail_i).
    MOVE-CORRESPONDING ls_fail_i TO ls_it_db.
    ls_it_db-material = ls_fail_i-material.
    UPDATE ztb_so_upload_it FROM ls_it_db.
  ENDLOOP.

*  " 3. Sync Condition
*  LOOP AT gt_pr_val INTO DATA(ls_val_p).
*    MOVE-CORRESPONDING ls_val_p TO ls_pr_db.
*    UPDATE ztb_so_upload_pr FROM ls_pr_db.
*  ENDLOOP.
*  LOOP AT gt_pr_fail INTO DATA(ls_fail_p).
*    MOVE-CORRESPONDING ls_fail_p TO ls_pr_db.
*    UPDATE ztb_so_upload_pr FROM ls_pr_db.
*  ENDLOOP.

  " ===================================================================
  " 3. SYNC CONDITION (Chiến thuật: Xóa & Nạp lại)
  " ===================================================================

  DATA: lr_temp_id_del TYPE RANGE OF char10,
        lt_pr_insert   TYPE TABLE OF ztb_so_upload_pr.

  " [FIX LỖI]: Khai báo biến tạm cho Range để dùng lệnh COLLECT
  DATA: ls_range LIKE LINE OF lr_temp_id_del.

  " A. Gom tất cả Temp_ID (Dùng biến ls_range để COLLECT)
  LOOP AT gt_pr_val INTO DATA(ls_val_p).
    " Build Range Line
    ls_range-sign   = 'I'.
    ls_range-option = 'EQ'.
    ls_range-low    = ls_val_p-temp_id.
    COLLECT ls_range INTO lr_temp_id_del.

    " Chuẩn bị dữ liệu Insert
    MOVE-CORRESPONDING ls_val_p TO ls_pr_db.
    APPEND ls_pr_db TO lt_pr_insert.
  ENDLOOP.

  LOOP AT gt_pr_fail INTO DATA(ls_fail_p).
    " Build Range Line
    ls_range-sign   = 'I'.
    ls_range-option = 'EQ'.
    ls_range-low    = ls_fail_p-temp_id.
    COLLECT ls_range INTO lr_temp_id_del.

    MOVE-CORRESPONDING ls_fail_p TO ls_pr_db.
    APPEND ls_pr_db TO lt_pr_insert.
  ENDLOOP.

  " B. Thực hiện Xóa & Chèn
  IF lr_temp_id_del IS NOT INITIAL.

    " 1. Xóa sạch Condition cũ của các Temp ID này trong DB
    DELETE FROM ztb_so_upload_pr
      WHERE req_id = gv_current_req_id
        AND temp_id IN lr_temp_id_del.

*    " 2. Chèn lại dữ liệu mới từ màn hình
*    IF lt_pr_insert IS NOT INITIAL.
*      INSERT ztb_so_upload_pr FROM TABLE lt_pr_insert.
*    ENDIF.

    " 2. Chèn lại dữ liệu mới từ màn hình
    IF lt_pr_insert IS NOT INITIAL.

      " [FIX DUMP]: Sắp xếp và Xóa các dòng trùng khóa trong bảng nội bộ trước khi Insert
      SORT lt_pr_insert BY req_id temp_id item_no cond_type.
      DELETE ADJACENT DUPLICATES FROM lt_pr_insert COMPARING req_id temp_id item_no cond_type.

      " Bây giờ bảng đã sạch (Unique), Insert sẽ không bị Dump
      INSERT ztb_so_upload_pr FROM TABLE lt_pr_insert.
    ENDIF.

  ENDIF.

  COMMIT WORK.
ENDFORM.

"chú ý 2
FORM show_error_details_popup
  USING VALUE(iv_req_id)  TYPE zsd_req_id
        VALUE(iv_temp_id) TYPE char10
        VALUE(iv_item_no) TYPE posnr_va.

  " 1. Cấu trúc hiển thị
  TYPES: BEGIN OF ty_error_pop.
           INCLUDE TYPE ztb_so_error_log.
    TYPES: row_color TYPE lvc_t_scol, " Cột màu
         END OF ty_error_pop.

  DATA: lt_display TYPE TABLE OF ty_error_pop,
        ls_display TYPE ty_error_pop.
  DATA: lt_logs    TYPE TABLE OF ztb_so_error_log.
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table.
  DATA: ls_color   TYPE lvc_s_scol.
  DATA: lv_has_error TYPE abap_bool.

  " 2. Lấy TOÀN BỘ lỗi
  SELECT * FROM ztb_so_error_log INTO TABLE @lt_logs
    WHERE req_id  = @iv_req_id
      AND temp_id = @iv_temp_id.

  IF sy-subrc <> 0.
    MESSAGE |No logs found for { iv_temp_id }| TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 3. Xử lý Tô màu
  LOOP AT lt_logs INTO DATA(ls_log).
    CLEAR ls_display.
    MOVE-CORRESPONDING ls_log TO ls_display.

    " Check Error
    IF ls_log-msg_type = 'E' OR ls_log-msg_type = 'A' OR ls_log-msg_type = 'X'.
       lv_has_error = abap_true.
    ENDIF.

    " Highlight dòng được chọn
    IF ls_log-item_no = iv_item_no.
       CLEAR ls_color.
       ls_color-color-col = 5. " Green
       ls_color-fname     = space.
       APPEND ls_color TO ls_display-row_color.
    ENDIF.

    APPEND ls_display TO lt_display.
  ENDLOOP.

  " 4. Hiển thị SALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_display ).

      lo_alv->set_screen_popup(
        start_column = 10 end_column = 120
        start_line   = 5  end_line   = 25 ).

      lo_columns = lo_alv->get_columns( ).

      " Cấu hình cột màu (Chỉ cần dòng này là đủ, không cần get_column)
      lo_columns->set_color_column( 'ROW_COLOR' ).
      lo_columns->set_optimize( abap_true ).

      " Ẩn cột thừa (Dùng helper macro hoặc try catch từng dòng để an toàn)
      TRY. lo_columns->get_column( 'MANDT' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'REQ_ID' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.
      " [FIX]: KHÔNG GỌI get_column('ROW_COLOR') VÌ NÓ GÂY DUMP

      TRY. lo_columns->get_column( 'LOG_USER' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'LOG_DATE' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'STATUS' )->set_visible( abap_false ). CATCH cx_root. ENDTRY.

      TRY. lo_columns->get_column( 'TEMP_ID' )->set_long_text( 'Order ID' ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'ITEM_NO' )->set_long_text( 'Item No' ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'FIELDNAME' )->set_long_text( 'Field Name' ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'MESSAGE' )->set_long_text( 'Description' ). CATCH cx_root. ENDTRY.
      TRY. lo_columns->get_column( 'MSG_TYPE' )->set_long_text( 'Type' ). CATCH cx_root. ENDTRY.

      " Tiêu đề
      DATA: lv_title TYPE lvc_title.
      IF lv_has_error = abap_true. lv_title = |Error Logs: { iv_temp_id }|.
      ELSE.                        lv_title = |Incomplete Logs: { iv_temp_id }|. ENDIF.

      IF iv_item_no = '000000'.    lv_title = |{ lv_title } (Header)|.
      ELSE.                        DATA(lv_it) = iv_item_no. SHIFT lv_it LEFT DELETING LEADING '0'.
                                   lv_title = |{ lv_title } (Item { lv_it })|. ENDIF.

      lo_alv->get_display_settings( )->set_list_header( lv_title ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.


*----------------------------------------------------------------------*
* HOME CENTER EVENT HANDLER.
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*
* CLASS IMPLEMENTATION: HC Event Handler
*----------------------------------------------------------------------*
CLASS lcl_hc_event_handler IMPLEMENTATION.
  METHOD on_sapevent.
    CASE action.
      WHEN 'NAVIGATE'.
        IF getdata = 'CREDIT'.
          MESSAGE i000(pz) WITH 'Opening Credit Release (VKM1)...'.
          " CALL TRANSACTION 'VKM1'.
        ENDIF.
    ENDCASE.
    " Clear global ok_code to prevent loop
    CLEAR ok_code.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* FORM: HC_DISPLAY_DASHBOARD
* Desc: Main entry point to render Home Center
*----------------------------------------------------------------------*
FORM hc_display_dashboard.
  " Singleton check to prevent re-rendering
  CHECK go_hc_container IS INITIAL.

  " 1. Fetch Real Data from DB
  PERFORM hc_fetch_data.

  " 2. Initialize Main Container (Must match Layout Name 'CC_HOME')
  go_hc_container = NEW #( container_name = 'CC_HOME' ).

  " 3. Initialize Splitter (2 Rows, 1 Column)
  go_hc_splitter = NEW #( parent  = go_hc_container
                          rows    = 2
                          columns = 1 ).

  " Get sub-containers
  go_hc_cont_top = go_hc_splitter->get_container( row = 1 column = 1 ).
  go_hc_cont_bot = go_hc_splitter->get_container( row = 2 column = 1 ).

  " Splitter Settings: Top height 20% (Compact KPI), No Border
  go_hc_splitter->set_row_height( id = 1 height = 20 ).
  go_hc_splitter->set_border( border = abap_false ).

  " --- TOP: HTML VIEWER (KPI) ---
  go_hc_html = NEW #( parent = go_hc_cont_top ).

  " Register Events for HTML
  DATA: lt_events TYPE cntl_simple_events,
        ls_event  TYPE cntl_simple_event.
  ls_event-eventid    = go_hc_html->m_id_sapevent.
  ls_event-appl_event = abap_true.
  APPEND ls_event TO lt_events.
  go_hc_html->set_registered_events( events = lt_events ).

  " Assign Handler
  IF go_hc_handler IS INITIAL.
    go_hc_handler = NEW #( ).
  ENDIF.
  SET HANDLER go_hc_handler->on_sapevent FOR go_hc_html.

  " Render HTML Content
  PERFORM hc_load_html_kpi.

  " --- BOTTOM: ALV GRID ---
  go_hc_alv = NEW #( i_parent = go_hc_cont_bot ).
  PERFORM hc_display_alv.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: HC_FETCH_DATA
* Desc: Select data from VBAK/LIKP for KPIs and ALV
*----------------------------------------------------------------------*
FORM hc_fetch_data.
  " --- KPI Logic ---
  SELECT COUNT( * ) FROM vbak INTO gv_hc_total_so WHERE erdat = sy-datum AND vbtyp = 'C'.
  SELECT COUNT( * ) FROM vbak INTO gv_hc_pending WHERE gbstk IN ('A','B') AND vbtyp = 'C' AND erdat >= sy-datum.
  SELECT SUM( netwr ) FROM vbak INTO gv_hc_net_val WHERE erdat = sy-datum AND vbtyp = 'C'.

  DATA: lv_temp_val TYPE p DECIMALS 2.
  IF gv_hc_net_val >= 1000000000.
    lv_temp_val = gv_hc_net_val / 1000000000.
    gv_hc_net_disp = |{ lv_temp_val NUMBER = USER DECIMALS = 2 } B|.
  ELSEIF gv_hc_net_val >= 1000000.
    lv_temp_val = gv_hc_net_val / 1000000.
    gv_hc_net_disp = |{ lv_temp_val NUMBER = USER DECIMALS = 2 } M|.
  ELSE.
    gv_hc_net_disp = |{ gv_hc_net_val NUMBER = USER }|.
  ENDIF.

  SELECT COUNT( * ) FROM vbak INTO gv_hc_pgi WHERE erdat = sy-datum AND vbtyp = 'C' AND gbstk = 'C'.

  " --- ALV Logic ---
  REFRESH gt_hc_alv_data.

  SELECT vbeln, erzet, ernam, gbstk, auart, vkorg, vtweg, spart, netwr, waerk
    FROM vbak
    INTO TABLE @DATA(lt_raw_so)
    WHERE erdat = @sy-datum
    ORDER BY erzet DESCENDING.

  LOOP AT lt_raw_so INTO DATA(ls_raw).
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

    " --- LOGIC STATUS ---
    DATA: lv_is_delivery_group TYPE abap_bool.

    " [FIXED] Dùng CASE thay vì IF ... IN (...)
    CASE ls_raw-auart.
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.
        lv_is_delivery_group = abap_true.  " Nhom 1
      WHEN OTHERS.
        lv_is_delivery_group = abap_false. " Nhom 2
    ENDCASE.

    " >> B1: CHECK BILLING & FI
    DATA: lv_billing_doc TYPE vbrk-vbeln,
          lv_fi_status   TYPE vbrk-rfbsk.
    CLEAR: lv_billing_doc, lv_fi_status.

    SELECT SINGLE vbrk~vbeln, vbrk~rfbsk
      FROM vbfa
      INNER JOIN vbrk ON vbrk~vbeln = vbfa~vbeln
      INTO (@lv_billing_doc, @lv_fi_status)
      WHERE vbfa~vbelv   = @ls_raw-vbeln
        AND vbfa~vbtyp_n = 'M'
        AND vbrk~fksto   = @space.

    IF sy-subrc = 0.
      IF lv_fi_status = 'C'.
        ls_alv-gbstk_txt   = 'FI Doc created'.
        ls_alv-status_icon = icon_payment.        " @15@ Payment
      ELSE.
        ls_alv-gbstk_txt   = 'Billing created'.
        ls_alv-status_icon = icon_select_detail.  " [FIXED] @0T@ Text View
      ENDIF.

      APPEND ls_alv TO gt_hc_alv_data.
      CONTINUE.
    ENDIF.

    " >> B2: CHECK DELIVERY
    IF lv_is_delivery_group = abap_true.
      DATA: lv_deliv_doc TYPE likp-vbeln,
            lv_gm_status TYPE likp-wbstk.
      CLEAR: lv_deliv_doc, lv_gm_status.

      SELECT SINGLE likp~vbeln, likp~wbstk
        FROM vbfa
        INNER JOIN likp ON likp~vbeln = vbfa~vbeln
        INTO (@lv_deliv_doc, @lv_gm_status)
        WHERE vbfa~vbelv   = @ls_raw-vbeln
          AND vbfa~vbtyp_n IN ('J', 'T').

      IF sy-subrc = 0.
        IF ls_raw-auart = 'ZRET'. " Return
          IF lv_gm_status = 'C'.
            ls_alv-gbstk_txt   = 'PGR Posted, ready Billing'.
            ls_alv-status_icon = icon_select_detail. " [FIXED] @0T@
          ELSE.
            ls_alv-gbstk_txt   = 'Return Del created, ready PGR'.
            ls_alv-status_icon = icon_delivery.      " @49@ Delivery
          ENDIF.
        ELSE. " Sales
          IF lv_gm_status = 'C'.
            ls_alv-gbstk_txt   = 'PGI Posted, ready Billing'.
            ls_alv-status_icon = icon_select_detail. " [FIXED] @0T@
          ELSE.
            ls_alv-gbstk_txt   = 'Delivery created, ready PGI'.
            ls_alv-status_icon = icon_delivery.      " @49@ Delivery
          ENDIF.
        ENDIF.

        APPEND ls_alv TO gt_hc_alv_data.
        CONTINUE.
      ENDIF.

      " -- Chua co Delivery --
      ls_alv-gbstk_txt   = 'Order created'.
      ls_alv-status_icon = icon_order. " @4A@ Order

    ELSE.
      " >> B3: DEFAULT NON-DELIVERY
      ls_alv-gbstk_txt   = 'Ready Billing'.
      ls_alv-status_icon = icon_order. " @4A@ Order
    ENDIF.

    APPEND ls_alv TO gt_hc_alv_data.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: HC_DISPLAY_ALV
* Desc: Configures and displays the ALV Grid
*----------------------------------------------------------------------*
FORM hc_display_alv.
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_layo TYPE lvc_s_layo.

  " --- FIELD CATALOG (Optimized for Fullscreen) ---
  lt_fcat = VALUE #(
      ( fieldname = 'STATUS_ICON' coltext = 'Sts'      icon = 'X' outputlen = 4 just = 'C' )
      " 1. Overall Status (No Color, Full Text)
      ( fieldname = 'GBSTK_TXT'   coltext = 'Overall Status' outputlen = 25 just = 'L' )
      " 2. Sales Document (Clickable)
      ( fieldname = 'VBELN'       coltext = 'Sales Document' hotspot = 'X' outputlen = 15 just = 'L' convexit = 'ALPHA' )
      " 3. Created By
      ( fieldname = 'ERNAM'       coltext = 'Created By'     outputlen = 15 )
      " 4. Time
      ( fieldname = 'ERZET'       coltext = 'Time'           outputlen = 10 just = 'C' )
      " 5. Type
      ( fieldname = 'AUART'       coltext = 'Type'           outputlen = 8 just = 'C' )
      " 6. Sales Area (Wider)
      ( fieldname = 'SALES_AREA'  coltext = 'Sales Area' outputlen = 25 )
      " 7. Net Value (Right Aligned)
      "( fieldname = 'NETWR'       coltext = 'Net Value'      do_sum = 'X' outputlen = 18 )
      " 7. Net Value [FIX 2: STANDARD FORMATTING]
    ( fieldname = 'NETWR'
      coltext    = 'Net Value'
      do_sum     = 'X'
      outputlen  = 15
      cfieldname = 'WAERK'   " Liên kết đơn vị tiền tệ
      ref_table  = 'VBAK'
      ref_field  = 'NETWR' )
      " 8. Currency (Left Aligned next to value)
      ( fieldname = 'WAERK'       coltext = 'Curr.'          outputlen = 5 just = 'L' )
  ).

  " --- LAYOUT ---
  ls_layo-zebra      = 'X'.
  ls_layo-sel_mode   = 'A'.
  ls_layo-grid_title = 'Recent Sales Documents (Today)'.
  ls_layo-no_toolbar = 'X'.
  ls_layo-no_rowmark = 'X'.

  " IMPORTANT: Disable optimize to allow columns to stretch
  " ls_layo-cwidth_opt = 'X'.

  go_hc_alv->set_table_for_first_display(
    EXPORTING is_layout       = ls_layo
    CHANGING  it_outtab       = gt_hc_alv_data
              it_fieldcatalog = lt_fcat
  ).

ENDFORM.

*----------------------------------------------------------------------*
* FORM: HC_LOAD_HTML_KPI
* Desc: Renders HTML/CSS for top area
*----------------------------------------------------------------------*
FORM hc_load_html_kpi.
  DATA: lt_data TYPE solix_tab, lv_url TYPE c LENGTH 255.

  " Calculate % Completion
  DATA: lv_pct TYPE p DECIMALS 1.
  IF gv_hc_total_so > 0.
    lv_pct = ( gv_hc_pgi / gv_hc_total_so ) * 100.
  ELSE.
    lv_pct = 0.
  ENDIF.

  " CSS Styles
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

  " HTML Body
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

  " Convert & Load
  DATA(lv_html) = `<!DOCTYPE html><html><head>` && lv_css && `</head>` && lv_body && `</html>`.
  DATA(lv_raw) = cl_abap_codepage=>convert_to( source = lv_html ).
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY' EXPORTING buffer = lv_raw TABLES binary_tab = lt_data.

  go_hc_html->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_data ).
  go_hc_html->show_url( url = lv_url ).
ENDFORM.

*----------------------------------------------------------------------*
* FORM: HC_REFRESH_DASHBOARD (NEW)
* Desc: Reload data without destroying containers
*----------------------------------------------------------------------*
FORM hc_refresh_dashboard.
  " 1. Lấy lại dữ liệu mới nhất từ DB
  PERFORM hc_fetch_data.

  " 2. Cập nhật lại HTML (KPIs)
  " Form này đã bao gồm logic tính toán lại % và đẩy vào Viewer
  PERFORM hc_load_html_kpi.

  " 3. Cập nhật lại ALV (List)
  IF go_hc_alv IS BOUND.
    " Cấu trúc giữ vị trí cuộn chuột (Stable Refresh)
    DATA: ls_stable TYPE lvc_s_stbl.
    ls_stable-row = 'X'. " Giữ dòng đang chọn
    ls_stable-col = 'X'. " Giữ cột đang chọn

    " ALV tự động nhận diện gt_hc_alv_data đã thay đổi ở bước 1
    go_hc_alv->refresh_table_display(
      EXPORTING
        is_stable = ls_stable
      EXCEPTIONS
        finished  = 1
        OTHERS    = 2
    ).
  ENDIF.

  MESSAGE s094(zsd4_msg).
ENDFORM.

*&---------------------------------------------------------------------*
*&                     REPORTING MONITORING FORM
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form GET_INITIAL_DATA_SD4
*&---------------------------------------------------------------------*
FORM get_initial_data_sd4.
  REFRESH: gt_static_sd4, gt_alv_sd4.

  SELECT a~vbeln, a~auart, a~audat, a~vdatu, a~vkorg, a~vtweg, a~spart,
         a~kunnr, a~bstnk, a~waerk, a~gbstk,
         c~name1,
         b~posnr, b~matnr, b~kwmeng, b~vrkme, b~netwr AS netwr_i
    FROM vbak AS a
    INNER JOIN vbap AS b ON a~vbeln = b~vbeln
    LEFT JOIN kna1  AS c ON a~kunnr = c~kunnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_static_sd4
    WHERE a~vkorg IN ( 'CNSG', 'CNHN', 'CNDN' ).

  " Gán sang bảng ALV TRƯỚC khi tính toán
  gt_alv_sd4 = gt_static_sd4.

  PERFORM determine_custom_status_sd4.

  PERFORM calculate_kpi_sd4.

  SORT gt_alv_sd4 BY audat DESCENDING vbeln DESCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_FILTERED_DATA_SD4
*&---------------------------------------------------------------------*
FORM get_filtered_data_sd4.
  REFRESH: gt_alv_sd4.

  SELECT a~vbeln, a~auart, a~audat, a~vdatu, a~vkorg, a~vtweg, a~spart,
         a~kunnr, a~bstnk, a~waerk, a~gbstk,
         c~name1,
         b~posnr, b~matnr, b~kwmeng, b~vrkme, b~netwr AS netwr_i
    FROM vbak AS a
    INNER JOIN vbap AS b ON a~vbeln = b~vbeln
    LEFT JOIN kna1  AS c ON a~kunnr = c~kunnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_alv_sd4
    WHERE a~vkorg IN ( 'CNSG', 'CNHN', 'CNDN' )
      AND a~vbeln IN @s_vbeln
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

  PERFORM determine_custom_status_sd4.

  " Tính lại KPI/Chart theo data mới
  PERFORM calculate_kpi_sd4.
  SORT gt_alv_sd4 BY audat DESCENDING vbeln DESCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CALCULATE_KPI_SD4
*&---------------------------------------------------------------------*
FORM calculate_kpi_sd4.
  CLEAR: gv_kpi_total_sd4, gv_kpi_rev_sd4.
  SORT gt_alv_sd4 BY vbeln.

  LOOP AT gt_alv_sd4 INTO DATA(ls_row).
    gv_kpi_rev_sd4 = gv_kpi_rev_sd4 + ls_row-netwr_i.
    AT NEW vbeln.
      gv_kpi_total_sd4 = gv_kpi_total_sd4 + 1.
    ENDAT.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DETERMINE_CUSTOM_STATUS_SD4
*&---------------------------------------------------------------------*
* Xử lý Logic Overall Status phức tạp dựa trên Document Flow
*----------------------------------------------------------------------*
FORM determine_custom_status_sd4.
  DATA: lt_vbeln TYPE RANGE OF vbak-vbeln, ls_rng LIKE LINE OF lt_vbeln.

  " 1. GOM DANH SÁCH SO ĐỂ SELECT (Tối ưu Performance)
  LOOP AT gt_alv_sd4 INTO DATA(ls_alv).
    ls_rng-sign = 'I'. ls_rng-option = 'EQ'. ls_rng-low = ls_alv-vbeln.
    COLLECT ls_rng INTO lt_vbeln.
  ENDLOOP.
  IF lt_vbeln IS INITIAL. RETURN. ENDIF.

  " 2. LẤY DỮ LIỆU LUỒNG CHỨNG TỪ (DOCUMENT FLOW)
  TYPES: BEGIN OF ty_flow,
           vbelv   TYPE vbfa-vbelv, " Preceding (SO/Del)
           vbeln   TYPE vbfa-vbeln, " Subsequent (Del/Bill)
           vbtyp_n TYPE vbfa-vbtyp_n,
         END OF ty_flow.
  DATA: lt_flow TYPE TABLE OF ty_flow.

  " A. Lấy Delivery (J) và Invoice (M) từ Order
  SELECT vbelv, vbeln, vbtyp_n
    FROM vbfa
    INTO TABLE @lt_flow
    WHERE vbelv IN @lt_vbeln
      AND vbtyp_n IN ( 'J', 'M' ).

  " B. Lấy tiếp Invoice (M) từ Delivery (J) vừa tìm được
  IF lt_flow IS NOT INITIAL.
    SELECT vbelv, vbeln, vbtyp_n
      FROM vbfa
      APPENDING TABLE @lt_flow
      FOR ALL ENTRIES IN @lt_flow
      WHERE vbelv = @lt_flow-vbeln " Lấy tiếp theo Delivery
        AND vbtyp_n = 'M'.
  ENDIF.

  " 3. LẤY CHI TIẾT TRẠNG THÁI (HEADER STATUS)
  " A. Billing Status (VBRK)
  TYPES: BEGIN OF ty_bill_st,
           vbeln TYPE vbrk-vbeln,
           sfakn TYPE vbrk-sfakn, " Cancelled Billing
           rfbsk TYPE vbrk-rfbsk, " Posting Status (C = Posted FI)
         END OF ty_bill_st.
  DATA: lt_bill_st TYPE HASHED TABLE OF ty_bill_st WITH UNIQUE KEY vbeln.

  " B. Delivery Status (LIKP)
  TYPES: BEGIN OF ty_del_st,
           vbeln TYPE likp-vbeln,
           wbstk TYPE likp-wbstk, " Goods Movement Status
         END OF ty_del_st.
  DATA: lt_del_st TYPE HASHED TABLE OF ty_del_st WITH UNIQUE KEY vbeln.

  " Collect IDs để select chi tiết
  DATA: lr_bill TYPE RANGE OF vbrk-vbeln, lr_del TYPE RANGE OF likp-vbeln.
  CLEAR ls_rng. ls_rng-sign = 'I'. ls_rng-option = 'EQ'.

  LOOP AT lt_flow INTO DATA(ls_f).
    IF ls_f-vbtyp_n = 'M'. " Billing
      ls_rng-low = ls_f-vbeln. COLLECT ls_rng INTO lr_bill.
    ELSEIF ls_f-vbtyp_n = 'J'. " Delivery
      ls_rng-low = ls_f-vbeln. COLLECT ls_rng INTO lr_del.
    ENDIF.
  ENDLOOP.

  " Select Status chi tiết
  IF lr_bill IS NOT INITIAL.
    SELECT vbeln, sfakn, rfbsk FROM vbrk INTO TABLE @lt_bill_st WHERE vbeln IN @lr_bill.
  ENDIF.
  IF lr_del IS NOT INITIAL.
    SELECT vbeln, wbstk FROM likp INTO TABLE @lt_del_st WHERE vbeln IN @lr_del.
  ENDIF.

  " 4. XỬ LÝ LOGIC CHÍNH (LOOP ALV)
  LOOP AT gt_alv_sd4 ASSIGNING FIELD-SYMBOL(<fs_data>).
    DATA: lv_has_fi   TYPE char1,
          lv_has_bill TYPE char1,
          lv_has_del  TYPE char1,
          lv_wbstk    TYPE likp-wbstk.

    CLEAR: lv_has_fi, lv_has_bill, lv_has_del, lv_wbstk.

    " --- [FIX] CHECK BILLING & FI (Tách vòng lặp để tránh lỗi Syntax) ---

    " Trường hợp 1: Billing tạo trực tiếp từ Order (SO -> Bill)
    LOOP AT lt_flow INTO ls_f WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'M'.
      READ TABLE lt_bill_st INTO DATA(ls_bst) WITH TABLE KEY vbeln = ls_f-vbeln.
      IF sy-subrc = 0 AND ls_bst-sfakn IS INITIAL. " Có Bill & Chưa hủy
        lv_has_bill = 'X'.
        IF ls_bst-rfbsk = 'C'. lv_has_fi = 'X'. EXIT. ENDIF. " Đã có FI -> Ưu tiên nhất, thoát luôn
      ENDIF.
    ENDLOOP.

    " Trường hợp 2: Billing tạo qua Delivery (SO -> Del -> Bill)
    " Chỉ tìm tiếp nếu chưa thấy FI Document ở trường hợp 1
    IF lv_has_fi IS INITIAL.
      " Tìm các Delivery của SO này trước
      LOOP AT lt_flow INTO DATA(ls_del_ref) WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'J'.
        " Với mỗi Delivery, tìm Billing của nó
        LOOP AT lt_flow INTO ls_f WHERE vbelv = ls_del_ref-vbeln AND vbtyp_n = 'M'.
          READ TABLE lt_bill_st INTO ls_bst WITH TABLE KEY vbeln = ls_f-vbeln.
          IF sy-subrc = 0 AND ls_bst-sfakn IS INITIAL.
            lv_has_bill = 'X'.
            IF ls_bst-rfbsk = 'C'. lv_has_fi = 'X'. EXIT. ENDIF.
          ENDIF.
        ENDLOOP.
        IF lv_has_fi = 'X'. EXIT. ENDIF. " Tìm thấy FI rồi thì thoát hết
      ENDLOOP.
    ENDIF.

    " --- CHECK DELIVERY (Để lấy trạng thái Goods Movement) ---
    IF lv_has_bill IS INITIAL.
      LOOP AT lt_flow INTO ls_f WHERE vbelv = <fs_data>-vbeln AND vbtyp_n = 'J'.
        lv_has_del = 'X'.
        READ TABLE lt_del_st INTO DATA(ls_dst) WITH TABLE KEY vbeln = ls_f-vbeln.
        IF sy-subrc = 0.
          lv_wbstk = ls_dst-wbstk. " Lấy trạng thái Goods Movement
        ENDIF.
        EXIT. " Lấy Delivery đầu tiên tìm thấy
      ENDLOOP.
    ENDIF.

    " --- MAPPING STATUS TEXT & ICON (Logic hiển thị) ---
    CASE <fs_data>-auart.
        " === NHÓM 1: GIAO NHẬN (ZORR, ZBB, ZFOC, ZRET) ===
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        IF lv_has_fi = 'X'.
          <fs_data>-gbstk_txt = 'FI Doc created'.
          <fs_data>-status_icon = icon_payment.
        ELSEIF lv_has_bill = 'X'.
          <fs_data>-gbstk_txt = 'Billing created'.
          <fs_data>-status_icon = icon_display_text.

        ELSEIF lv_has_del = 'X'.
          IF <fs_data>-auart = 'ZRET'. " Đơn trả hàng
            IF lv_wbstk = 'C'.
              <fs_data>-gbstk_txt = 'PGI Posted, ready Billing'.
              <fs_data>-status_icon = icon_display_text.
            ELSE.
              <fs_data>-gbstk_txt = 'Return Del created, ready PGI'.
              <fs_data>-status_icon = icon_delivery.
            ENDIF.
          ELSE. " Đơn bán hàng
            IF lv_wbstk = 'C'.
              <fs_data>-gbstk_txt = 'PGI Posted, ready Billing'.
              <fs_data>-status_icon = icon_display_text.
            ELSE.
              <fs_data>-gbstk_txt = 'Delivery created, ready PGI'.
              <fs_data>-status_icon = icon_delivery.
            ENDIF.
          ENDIF.

        ELSE.
          <fs_data>-gbstk_txt = 'Order created'.
          <fs_data>-status_icon = icon_order.
        ENDIF.

        " === NHÓM 2: DỊCH VỤ (ZDR, ZCRR, ZTP...) ===
      WHEN OTHERS.
        IF lv_has_fi = 'X'.
          <fs_data>-gbstk_txt = 'FI Doc created'.
          <fs_data>-status_icon = icon_payment.
        ELSEIF lv_has_bill = 'X'.
          <fs_data>-gbstk_txt = 'Billing created'.
          <fs_data>-status_icon = icon_display_text.
        ELSE.
          <fs_data>-gbstk_txt = 'Ready Billing'.
          <fs_data>-status_icon = icon_order.
        ENDIF.

    ENDCASE.
  ENDLOOP.

ENDFORM.



*&---------------------------------------------------------------------*
*& Form UPDATE_DASHBOARD_UI_SD4
*&---------------------------------------------------------------------*
FORM update_dashboard_ui_sd4.
  " --- 1. KHỞI TẠO CONTAINER & SPLITTER (CHỈ LÀM 1 LẦN) ---
  IF go_split_sd4 IS INITIAL.
    " Tạo Custom Container chính
    CREATE OBJECT go_cc_report
      EXPORTING
        container_name = 'CC_REPORT'.

    " Tạo Splitter: Chia làm 2 dòng (Row 1: KPI, Row 2: ALV)
    CREATE OBJECT go_split_sd4
      EXPORTING
        parent  = go_cc_report
        rows    = 2
        columns = 1.

    " Lấy tham chiếu 2 vùng container con
    go_c_top_sd4 = go_split_sd4->get_container( row = 1 column = 1 ).
    go_c_bot_sd4 = go_split_sd4->get_container( row = 2 column = 1 ).

    " Thiết lập chiều cao cho Header (KPI): 15%
    go_split_sd4->set_row_height( id = 1 height = 15 ).

    " (Optional) Tắt đường viền cho đẹp
    go_split_sd4->set_border( border = space ).
  ENDIF.

  " --- 2. VẼ CÁC THÀNH PHẦN ---
  PERFORM draw_kpi_header_sd4.
  PERFORM draw_alv_grid_sd4.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DRAW_KPI_HEADER_SD4
*&---------------------------------------------------------------------*
FORM draw_kpi_header_sd4.
  DATA: lt_html TYPE TABLE OF char255, ls_html TYPE char255, lv_url TYPE char255.
  DATA: lv_str_total TYPE string, lv_str_val TYPE string.
  DATA: lv_html_content TYPE string.

  lv_str_total = |{ gv_kpi_total_sd4 NUMBER = USER }|.
  lv_str_val   = |{ gv_kpi_rev_sd4   NUMBER = USER }|.

  IF go_html_kpi_sd4 IS INITIAL.
    CREATE OBJECT go_html_kpi_sd4 EXPORTING parent = go_c_top_sd4.
  ENDIF.

  DEFINE add_h. ls_html = &1. APPEND ls_html TO lt_html. END-OF-DEFINITION.

  " (Giữ nguyên phần HTML/CSS như cũ của bạn)
  add_h '<html><head><style>'.
  add_h 'body { margin: 0; padding: 10px; font-family: Arial, sans-serif; background: #f5f7fa; overflow: hidden; }'.
  add_h '.kpi-box { display: flex; gap: 20px; justify-content: flex-start; }'.
  add_h '.card { background: white; padding: 10px 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); width: 250px; border-left: 5px solid #007bff; }'.
  add_h '.card.success { border-left-color: #28a745; }'.
  add_h '.title { font-size: 12px; color: #666; text-transform: uppercase; margin-bottom: 5px; }'.
  add_h '.value { font-size: 24px; font-weight: bold; color: #333; }'.
  add_h '</style></head><body>'.

  add_h '<div class="kpi-box">'.
  add_h '<div class="card"><div class="title">Total Orders</div>'.
  lv_html_content = |<div class="value">{ lv_str_total }</div>|.
  add_h lv_html_content.
  add_h '</div>'.
  add_h '<div class="card success"><div class="title">Total Revenue</div>'.
  lv_html_content = |<div class="value">{ lv_str_val }</div>|.
  add_h lv_html_content.
  add_h '</div></div></body></html>'.

  go_html_kpi_sd4->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_html ).
  go_html_kpi_sd4->show_url( url = lv_url ).
ENDFORM.


*&---------------------------------------------------------------------*
*& Form DRAW_ALV_GRID_SD4
*&---------------------------------------------------------------------*
FORM draw_alv_grid_sd4.
  IF go_alv_sd4 IS BOUND.
    DATA: ls_stable TYPE lvc_s_stbl.
    ls_stable-row = 'X'. ls_stable-col = 'X'.
    go_alv_sd4->refresh_table_display( EXPORTING is_stable = ls_stable ).
    RETURN.
  ENDIF.

  CREATE OBJECT go_alv_sd4 EXPORTING i_parent = go_c_bot_sd4.

  DATA: lt_fcat TYPE lvc_t_fcat, ls_fcat TYPE lvc_s_fcat.
  DEFINE add_col.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-scrtext_m = &2.
    ls_fcat-outputlen = &3.
    IF &1 = 'NETWR_I'. ls_fcat-do_sum = 'X'. ls_fcat-cfieldname = 'WAERK'. ENDIF.

    " [NEW] Nếu là cột Icon thì căn giữa
    IF &1 = 'STATUS_ICON'.
       ls_fcat-icon = 'X'.
       ls_fcat-just = 'C'.
       ls_fcat-scrtext_m = ''. " Icon không cần tiêu đề hoặc để ngắn
    ENDIF.

    IF &1 = 'AUDAT' OR &1 = 'VDATU'.
      ls_fcat-ref_table = 'VBAK'.
      ls_fcat-ref_field = &1.
    ENDIF.

    APPEND ls_fcat TO lt_fcat.
  END-OF-DEFINITION.

  add_col 'STATUS_ICON' ''              4.  " Cột Icon
  add_col 'GBSTK_TXT'   'Overall Stat.' 22. " Cột Text (tăng độ rộng)
  add_col 'VBELN'       'Sales Doc'     10.
  add_col 'AUART'      'Order Type'      5.
  add_col 'AUDAT'      'Doc. Date'       12.
  add_col 'VDATU'      'Req. Del. Date'  10.
  add_col 'VKORG'      'Sales Org.'      6.
  add_col 'VTWEG'      'Dis. Channel'    3.
  add_col 'SPART'      'Division'        2.
  add_col 'KUNNR'      'Sold-to'         10.
  add_col 'NAME1'      'Customer Name'   20.
  add_col 'POSNR'      'Item'            6.
  add_col 'MATNR'      'Material'        11.
  add_col 'KWMENG'     'Quantity'        12.
  add_col 'VRKME'      'Unit'            3.
  add_col 'NETWR_I'    'Net Value'       15.
  add_col 'WAERK'      'Currency'        5.

  DATA: ls_layout TYPE lvc_s_layo.
  ls_layout-zebra      = 'X'.
  ls_layout-sel_mode   = 'A'.
  "ls_layout-ctab_fname = 'T_COLOR'.

  go_alv_sd4->set_table_for_first_display(
    EXPORTING is_layout       = ls_layout
    CHANGING  it_outtab       = gt_alv_sd4
              it_fieldcatalog = lt_fcat ).
ENDFORM.

*&---------------------------------------------------------------------*
*&             SCREEN 0900 - REPORT DASHBOARD.
*&---------------------------------------------------------------------*

" --- [1] CLASS IMPLEMENTATION ---
CLASS lcl_event_handler_0900 IMPLEMENTATION.
  METHOD on_sapevent.
    DATA: lv_action  TYPE string,
          lv_p1      TYPE string,
          lv_p2      TYPE string,
          lv_payload TYPE string.

    " Tách action để lấy dữ liệu Filter (nếu có)
    SPLIT action AT '|' INTO lv_action lv_p1 lv_p2.

    CASE lv_action.
      WHEN 'FILTER'.
        CONCATENATE lv_p1 lv_p2 INTO lv_payload SEPARATED BY '|'.
        IF lv_payload IS INITIAL OR lv_payload = '|'.
           lv_payload = 'ALL'.
        ENDIF.
        PERFORM refresh_data_0900 USING lv_payload.

      WHEN 'CUSTOMER_CLICK'.
        " --- ĐOẠN SỬA LỖI Ở ĐÂY ---
        DATA: lv_cust_data TYPE string.
        lv_cust_data = getdata.
        PERFORM handle_customer_click_0900 USING lv_cust_data.

    ENDCASE.
    cl_gui_cfw=>flush( ).
  ENDMETHOD.
ENDCLASS.

" --- [2] FORM INIT ---
FORM init_dashboard_0900.
  IF go_cc_dashboard_0900 IS INITIAL.
    CREATE OBJECT go_cc_dashboard_0900
      EXPORTING container_name = 'CC_DASHBOARD_0900'.

    CREATE OBJECT go_viewer_0900
      EXPORTING parent = go_cc_dashboard_0900.

    DATA: lt_events TYPE cntl_simple_events, ls_event TYPE cntl_simple_event.
    ls_event-eventid = go_viewer_0900->m_id_sapevent.
    ls_event-appl_event = 'X'.
    APPEND ls_event TO lt_events.
    go_viewer_0900->set_registered_events( events = lt_events ).
    SET HANDLER lcl_event_handler_0900=>on_sapevent FOR go_viewer_0900.

    PERFORM refresh_data_0900 USING 'ALL'.
  ENDIF.
ENDFORM.

" --- [3] FORM REFRESH DATA ---
*&---------------------------------------------------------------------*
*&      Form  REFRESH_DATA_0900
*&---------------------------------------------------------------------*
FORM refresh_data_0900 USING p_filter_payload TYPE string.

  " --- [1] TYPE DECLARATION ---
  TYPES: BEGIN OF ty_chart_item,
           label TYPE string,
           value TYPE netwr,
         END OF ty_chart_item.
  TYPES: tt_chart_data TYPE STANDARD TABLE OF ty_chart_item WITH EMPTY KEY.

  TYPES: BEGIN OF ty_finance_json,
           total_sales  TYPE netwr,
           billed_val   TYPE netwr,
           total_ar     TYPE netwr,
           clearing_val TYPE netwr,
           bill_rate    TYPE string,
           clear_pct    TYPE string,
           trend_sales  TYPE tt_netwr,
           trend_bill   TYPE tt_netwr,
           trend_clear  TYPE tt_netwr,
           trend_ar     TYPE tt_netwr,
           trend_labels TYPE tt_string,
         END OF ty_finance_json.

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

  " --- [2] DATE PARSING ---
  DATA: lv_date_from_raw TYPE string, lv_date_to_raw TYPE string,
        lv_date_from_html TYPE string, lv_date_to_html TYPE string,
        lv_datum_low TYPE sy-datum, lv_datum_high TYPE sy-datum.

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

  " --- [3] DATA TABLES ---
  DATA: lt_orders TYPE TABLE OF ty_sales_raw.
  DATA: lt_flow_del TYPE SORTED TABLE OF ty_doc_flow WITH NON-UNIQUE KEY vbelv,
        lt_flow_bil TYPE SORTED TABLE OF ty_doc_flow WITH NON-UNIQUE KEY vbelv.

  TYPES: BEGIN OF ty_fi_item, kunnr TYPE kunnr, bukrs TYPE bukrs, dmbtr TYPE dmbtr, END OF ty_fi_item.
  DATA: lt_bsid TYPE TABLE OF ty_fi_item, lt_bsad TYPE TABLE OF ty_fi_item.
  TYPES: BEGIN OF ty_tvko, vkorg TYPE vkorg, bukrs TYPE bukrs, END OF ty_tvko.
  DATA: lt_tvko TYPE TABLE OF ty_tvko.

  TYPES: BEGIN OF ty_agg_fin_trend,
           erdat TYPE vbak-erdat,
           sales TYPE netwr,
           bill  TYPE netwr,
           clear TYPE netwr,
           ar    TYPE netwr,
         END OF ty_agg_fin_trend.
  DATA: lt_fin_trend TYPE SORTED TABLE OF ty_agg_fin_trend WITH UNIQUE KEY erdat,
        ls_fin_trend TYPE ty_agg_fin_trend.

  TYPES: BEGIN OF ty_agg_cust, kunnr TYPE vbak-kunnr, netwr TYPE netwr, END OF ty_agg_cust.
  DATA: lt_cust_data TYPE SORTED TABLE OF ty_agg_cust WITH UNIQUE KEY kunnr, ls_cust_row TYPE ty_agg_cust.

  DATA: lt_status_agg TYPE HASHED TABLE OF ty_chart_item WITH UNIQUE KEY label,
        lt_region_agg TYPE HASHED TABLE OF ty_chart_item WITH UNIQUE KEY label,
        ls_agg_item   TYPE ty_chart_item.

  DATA: lv_sales_sum TYPE netwr, lv_ret_sum TYPE netwr, lv_open_cnt TYPE i.
  DATA: lv_billed_sum TYPE netwr, lv_ar_sum TYPE netwr, lv_clearing_sum TYPE netwr.
  RANGES: r_kunnr FOR vbak-kunnr, r_bukrs FOR t001-bukrs, r_augdt FOR bsad-augdt.

  " --- [4] SELECT SALES DATA ---
  REFRESH r_vkorg. r_vkorg-sign = 'I'. r_vkorg-option = 'EQ'.
  r_vkorg-low = 'CNSG'. APPEND r_vkorg. r_vkorg-low = 'CNHN'. APPEND r_vkorg. r_vkorg-low = 'CNDN'. APPEND r_vkorg.
  REFRESH r_erdat. r_erdat-sign = 'I'. r_erdat-option = 'BT'. r_erdat-low = lv_datum_low. r_erdat-high = lv_datum_high. APPEND r_erdat.

  SELECT vbeln, auart, erdat, netwr, kunnr, vkorg
    INTO CORRESPONDING FIELDS OF TABLE @lt_orders
    FROM vbak WHERE vkorg IN @r_vkorg AND erdat IN @r_erdat.

  IF lt_orders IS NOT INITIAL.
    SELECT vkorg, bukrs INTO CORRESPONDING FIELDS OF TABLE @lt_tvko FROM tvko FOR ALL ENTRIES IN @lt_orders WHERE vkorg = @lt_orders-vkorg.
    SELECT a~vbelv, a~vbeln, a~vbtyp_n, b~rfbsk, b~fksto INTO CORRESPONDING FIELDS OF TABLE @lt_flow_bil
      FROM vbfa AS a INNER JOIN vbrk AS b ON a~vbeln = b~vbeln FOR ALL ENTRIES IN @lt_orders WHERE a~vbelv = @lt_orders-vbeln AND a~vbtyp_n = 'M' AND b~fksto = @space.
    SELECT a~vbelv, a~vbeln, a~vbtyp_n, b~wbstk INTO CORRESPONDING FIELDS OF TABLE @lt_flow_del
      FROM vbfa AS a INNER JOIN likp AS b ON a~vbeln = b~vbeln FOR ALL ENTRIES IN @lt_orders WHERE a~vbelv = @lt_orders-vbeln AND a~vbtyp_n = 'J'.

    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_o>).
      r_kunnr-sign = 'I'. r_kunnr-option = 'EQ'. r_kunnr-low = <ls_o>-kunnr. COLLECT r_kunnr.
      READ TABLE lt_tvko INTO DATA(ls_tvko) WITH KEY vkorg = <ls_o>-vkorg.
      IF sy-subrc = 0. r_bukrs-sign = 'I'. r_bukrs-option = 'EQ'. r_bukrs-low = ls_tvko-bukrs. COLLECT r_bukrs. ENDIF.
    ENDLOOP.

    IF r_kunnr[] IS NOT INITIAL AND r_bukrs[] IS NOT INITIAL.
      SELECT kunnr, bukrs, dmbtr INTO CORRESPONDING FIELDS OF TABLE @lt_bsid FROM bsid WHERE kunnr IN @r_kunnr AND bukrs IN @r_bukrs.
      r_augdt = r_erdat.
      SELECT kunnr, bukrs, dmbtr INTO CORRESPONDING FIELDS OF TABLE @lt_bsad FROM bsad WHERE kunnr IN @r_kunnr AND bukrs IN @r_bukrs AND augdt IN @r_augdt.
    ENDIF.
  ENDIF. " <--- ĐÃ SỬA: Dùng ENDIF thay vì ENDLOOP

  " --- [5] LOGIC PROCESSING ---
  DATA: ls_bill_info LIKE LINE OF lt_flow_bil, ls_del_info  LIKE LINE OF lt_flow_del.

  LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_ord>).
    CLEAR: <ls_ord>-status_txt.
    CLEAR: ls_fin_trend. ls_fin_trend-erdat = <ls_ord>-erdat.

    READ TABLE lt_flow_bil INTO ls_bill_info WITH TABLE KEY vbelv = <ls_ord>-vbeln.
    IF sy-subrc = 0.
      IF ls_bill_info-rfbsk = 'C'.
         <ls_ord>-status_txt = 'FI Doc created'.
         ls_fin_trend-clear = <ls_ord>-netwr.
      ELSE.
         <ls_ord>-status_txt = 'Billing created'.
      ENDIF.
      ls_fin_trend-bill = <ls_ord>-netwr.
      ADD <ls_ord>-netwr TO lv_billed_sum.
    ELSE.
      IF <ls_ord>-auart = 'ZORR' OR <ls_ord>-auart = 'ZBB' OR <ls_ord>-auart = 'ZFOC' OR <ls_ord>-auart = 'ZRET'.
         READ TABLE lt_flow_del INTO ls_del_info WITH TABLE KEY vbelv = <ls_ord>-vbeln.
         IF sy-subrc = 0.
           IF <ls_ord>-auart = 'ZRET'.
             IF ls_del_info-wbstk = 'C'. <ls_ord>-status_txt = 'PGR Posted, ready Billing'. ELSE. <ls_ord>-status_txt = 'Return Del created, ready PGR'. ENDIF.
           ELSE.
             IF ls_del_info-wbstk = 'C'. <ls_ord>-status_txt = 'PGI Posted, ready Billing'. ELSE. <ls_ord>-status_txt = 'Delivery created, ready PGI'. ENDIF.
           ENDIF.
         ELSE. <ls_ord>-status_txt = 'Order created'. ENDIF.
      ELSE. <ls_ord>-status_txt = 'Ready Billing'. ENDIF.
      ls_fin_trend-ar = <ls_ord>-netwr.
    ENDIF.

    IF <ls_ord>-auart = 'ZRET'. ADD <ls_ord>-netwr TO lv_ret_sum. ELSE. ADD <ls_ord>-netwr TO lv_sales_sum. ENDIF.
    IF <ls_ord>-status_txt NP 'FI Doc*' AND <ls_ord>-status_txt NP 'Billing*'. ADD 1 TO lv_open_cnt. ENDIF.

    ls_fin_trend-sales = <ls_ord>-netwr.
    COLLECT ls_fin_trend INTO lt_fin_trend.

    IF <ls_ord>-auart <> 'ZRET'.
       ls_cust_row-kunnr = <ls_ord>-kunnr. ls_cust_row-netwr = <ls_ord>-netwr. COLLECT ls_cust_row INTO lt_cust_data.
    ENDIF.
    CLEAR ls_agg_item. ls_agg_item-label = <ls_ord>-status_txt. ls_agg_item-value = 1. COLLECT ls_agg_item INTO lt_status_agg.
    CLEAR ls_agg_item.
    CASE <ls_ord>-vkorg. WHEN 'CNSG'. ls_agg_item-label = 'Ho Chi Minh'. WHEN 'CNHN'. ls_agg_item-label = 'Ha Noi'. WHEN 'CNDN'. ls_agg_item-label = 'Da Nang'. WHEN OTHERS. ls_agg_item-label = <ls_ord>-vkorg. ENDCASE.
    ls_agg_item-value = <ls_ord>-netwr. COLLECT ls_agg_item INTO lt_region_agg.
  ENDLOOP.

  " Finance Sums
  LOOP AT lt_bsid INTO DATA(ls_bsid). ADD ls_bsid-dmbtr TO lv_ar_sum. ENDLOOP.
  LOOP AT lt_bsad INTO DATA(ls_bsad). ADD ls_bsad-dmbtr TO lv_clearing_sum. ENDLOOP.

  " --- [6] MAPPING JSON ---
  ls_json_ext-kpi-sales   = |{ lv_sales_sum / 1000000 DECIMALS = 2 }M|.
  ls_json_ext-kpi-returns = |{ lv_ret_sum / 1000000 DECIMALS = 2 }M|.
  ls_json_ext-kpi-orders  = |{ lv_open_cnt }|.

  ls_json_ext-finance-total_sales  = lv_sales_sum.
  ls_json_ext-finance-billed_val   = lv_billed_sum.
  ls_json_ext-finance-total_ar     = lv_ar_sum.
  ls_json_ext-finance-clearing_val = lv_clearing_sum.

  IF lv_sales_sum > 0.
    DATA(lv_rate) = ( lv_billed_sum / lv_sales_sum ) * 100.
    ls_json_ext-finance-bill_rate = |{ lv_rate DECIMALS = 1 }|.
  ELSE. ls_json_ext-finance-bill_rate = '0.0'. ENDIF.

  IF ( lv_clearing_sum + lv_ar_sum ) > 0.
    DATA(lv_pct) = ( lv_clearing_sum / ( lv_clearing_sum + lv_ar_sum ) ) * 100.
    ls_json_ext-finance-clear_pct = |{ lv_pct DECIMALS = 1 }|.
  ELSE. ls_json_ext-finance-clear_pct = '0.0'. ENDIF.

  " Map Sparklines Data
  LOOP AT lt_fin_trend INTO ls_fin_trend.
    APPEND ls_fin_trend-sales TO ls_json_ext-finance-trend_sales.
    APPEND ls_fin_trend-bill  TO ls_json_ext-finance-trend_bill.
    APPEND ls_fin_trend-clear TO ls_json_ext-finance-trend_clear.
    APPEND ls_fin_trend-ar    TO ls_json_ext-finance-trend_ar.

    DATA(lv_d) = |{ ls_fin_trend-erdat+6(2) }/{ ls_fin_trend-erdat+4(2) }|.
    APPEND lv_d TO ls_json_ext-finance-trend_labels.

    " Default Sales Trend
    APPEND ls_fin_trend-sales TO ls_json_ext-trend_values.
    APPEND lv_d TO ls_json_ext-trend_labels.
  ENDLOOP.

  LOOP AT lt_status_agg INTO ls_agg_item. APPEND ls_agg_item TO ls_json_ext-status_data. ENDLOOP.
  LOOP AT lt_region_agg INTO ls_agg_item. APPEND ls_agg_item TO ls_json_ext-region_data. ENDLOOP.

  DATA: lt_cust_std TYPE STANDARD TABLE OF ty_agg_cust. lt_cust_std = lt_cust_data. SORT lt_cust_std BY netwr DESCENDING.
  DATA: lv_c TYPE i VALUE 0, lv_nm TYPE kna1-name1.
  LOOP AT lt_cust_std INTO ls_cust_row.
    lv_c = lv_c + 1. IF lv_c > 10. EXIT. ENDIF.
    SELECT SINGLE name1 INTO lv_nm FROM kna1 WHERE kunnr = ls_cust_row-kunnr. IF sy-subrc <> 0. lv_nm = ls_cust_row-kunnr. ENDIF.
    APPEND ls_cust_row-netwr TO ls_json_ext-top_customers. APPEND lv_nm TO ls_json_ext-top_cust_names.
  ENDLOOP.

  DATA(lv_js_data) = /ui2/cl_json=>serialize( data = ls_json_ext compress = abap_true pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  IF lv_js_data IS INITIAL. lv_js_data = '{}'. ENDIF.

  PERFORM render_html_0900 USING lv_js_data lv_date_from_html lv_date_to_html.
ENDFORM.

" --- [4] FORM RENDER HTML (SỬ DỤNG NHÁY ĐƠN ĐỂ TRÁNH LỖI SYNTAX) ---
*&---------------------------------------------------------------------*
*&      Form  RENDER_HTML_0900
*&---------------------------------------------------------------------*
FORM render_html_0900 USING p_json_data TYPE string
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
  '              color:#666;text-transform:uppercase">Top 5 Customers</div>' &&
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
    EXPORTING text = lv_html TABLES ftext_tab = lt_html_tab.

  DATA: lv_url TYPE c LENGTH 255.
  go_viewer_0900->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_html_tab ).
  go_viewer_0900->show_url( url = lv_url ).
  cl_gui_cfw=>flush( ).
ENDFORM.

" --- [5] FORM HANDLE CLICK ---
FORM handle_customer_click_0900 USING p_cust_name TYPE string.
  DATA: lv_kunnr TYPE kunnr.
  SELECT SINGLE kunnr INTO lv_kunnr FROM kna1 WHERE name1 = p_cust_name.
  IF sy-subrc <> 0.
     lv_kunnr = p_cust_name.
     CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_kunnr IMPORTING output = lv_kunnr.
  ENDIF.
  SET PARAMETER ID 'KUN' FIELD lv_kunnr.
  CALL TRANSACTION 'VA05' AND SKIP FIRST SCREEN.
ENDFORM.

FORM perform_save_data.

  " 1. Ép ALV nhả dữ liệu mới nhất vào bảng nội bộ
  " (Chỉ cần làm cho các Grid cho phép sửa: Validated & Failed)

  " --- Tab Validated ---
  IF go_grid_hdr_val IS BOUND. go_grid_hdr_val->check_changed_data( ). ENDIF.
  IF go_grid_itm_val IS BOUND. go_grid_itm_val->check_changed_data( ). ENDIF.
  IF go_grid_cnd_val IS BOUND. go_grid_cnd_val->check_changed_data( ). ENDIF.

  " --- Tab Failed ---
  IF go_grid_hdr_fail IS BOUND. go_grid_hdr_fail->check_changed_data( ). ENDIF.
  IF go_grid_itm_fail IS BOUND. go_grid_itm_fail->check_changed_data( ). ENDIF.
  IF go_grid_cnd_fail IS BOUND. go_grid_cnd_fail->check_changed_data( ). ENDIF.

  " 2. Gọi hàm đồng bộ xuống DB
  " (Hàm này bạn đã có rồi: sync_alv_to_staging_tables)
  PERFORM sync_alv_to_staging_tables.

  " 3. Thông báo
  MESSAGE 'Data saved successfully to Staging.' TYPE 'S'.

ENDFORM.
