*&---------------------------------------------------------------------*
*& Include          ZSD4_SALES_ORDER_CENTERF01
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& Form pbo_modify_screen (ĐÃ SỬA LẠI LOGIC STATE 1 - CHUẨN)
*&---------------------------------------------------------------------*
FORM pbo_modify_screen.
  LOOP AT SCREEN.
    CASE screen-name.
      "--- LOGIC 1: KHÓA CÁC TRƯỜNG OUTPUT-ONLY ---
      WHEN 'GS_SO_HEDER_UI-SO_HDR_VBELN'       OR  " Document Number
           'GS_SO_HEDER_UI-SO_HDR_KAL_SM'        OR  " Pric. Procedure
           'GS_SO_HEDER_UI-SO_HDR_SOLD_ADRNR'  OR  " Tên Sold-to
           'GS_SO_HEDER_UI-SO_HDR_SHIP_ADRNR'  OR  " Tên Ship-to
           'GS_SO_HEDER_UI-SO_HDR_SALESAREA'.       " Sales Area (Text)
        screen-input = 0.
        MODIFY SCREEN.
        CONTINUE.
      "--- LOGIC 1B: Bỏ qua các control (Tabstrip) ---
      WHEN 'TS_MAIN_TAB1' OR 'TS_MAIN_TAB2' OR 'TS_MAIN_TAB3'.
        CONTINUE.
    ENDCASE.

    "--- LOGIC 2: XỬ LÝ CÁC TRƯỜNG CÓ THỂ INPUT (DYNAMIC) ---
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
          WHEN 'GS_SO_HEDER_UI-SO_HDR_BSTNK'      OR  " 1. Cust. Reference (Đúng tên HEDER)
               'GS_SO_HEDER_UI-SO_HDR_KETDAT'     OR  " 2. Req. Deliv. Date
               'GS_SO_HEDER_UI-SO_HDR_AUDAT'.         " 3. Document Date (Auto-fill nhưng vẫn cho SỬA)
            screen-input = 1. " Mở 3 trường này
          WHEN OTHERS.
            " Khóa TẤT CẢ các trường input còn lại
            " (Bao gồm Org Data, Sold-to, VÀ CÁC TRƯỜNG AUTO-FILL:
            "  WAERK, ZTERM, INCO1)
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
    EXPORTING input = lv_sold_to
    IMPORTING output = lv_sold_to.
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
  DATA: lv_folder     TYPE string,
        lv_full_path  TYPE rlgrap-filename,
        lv_objid      TYPE wwwdata-objid,
        lwa_data      TYPE wwwdatatab,
        lv_subrc      TYPE sy-subrc,
        lwa_rec       TYPE wwwdatatab.

  " --- 1. SỬA: Tên object SMW0 của program này ---
  lv_objid = 'ZSD4_FILE_TEMPLATE3'. " (Tên bạn đã upload ở Bước 1)

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

*&---------------------------------------------------------------------*
*& Form UPLOAD_FILE (ĐÃ MERGE: Mapping chi tiết + Lưu vào Z-Table)
*&---------------------------------------------------------------------*
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

*  " ====================================================================
*  " XỬ LÝ SHEET ITEM
*  " ====================================================================
*  CLEAR lo_data_ref. " Reset biến
*
*  PERFORM validate_template_structure
*    USING lo_excel_ref 'Item' 'ztb_so_upload_it'
*    CHANGING lo_data_ref.
*
*  " [QUAN TRỌNG]: Kiểm tra Bound
*  IF lo_data_ref IS NOT BOUND. RETURN. ENDIF.
*  ASSIGN lo_data_ref->* TO <gt_data_raw>.
*
*  IF <gt_data_raw> IS INITIAL. RETURN. ENDIF.
**  DELETE <gt_data_raw> INDEX 1.
*
*  LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
*    DATA(ls_item) = VALUE ztb_so_upload_it( ). " <<< TYPE MỚI (Z-Table)
*
*      ASSIGN COMPONENT 1 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<i_temp_id>).
*      ASSIGN COMPONENT 2 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<item_no>).
*      ASSIGN COMPONENT 3 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<matnr>).
*      ASSIGN COMPONENT 4 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<plant>).
*      ASSIGN COMPONENT 5 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<ship_point>).
*      ASSIGN COMPONENT 6 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<stloc>).
*      ASSIGN COMPONENT 7 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<qty>).
*
*
*    CHECK <i_temp_id> IS ASSIGNED AND <i_temp_id> IS NOT INITIAL.
*
**    " [THÊM LẠI] Convert ngày tháng Item
**    DATA: lv_req_dats_i TYPE dats.
**    IF <req_date_itm> IS ASSIGNED.
**       PERFORM convert_date_ddmmyyyy USING <req_date_itm> CHANGING lv_req_dats_i.
**    ENDIF.
*
*    ls_item-req_id      = iv_req_id.      " <<< REQ_ID
*    ls_item-status      = 'NEW'.          " <<< Status
*    ls_item-created_by  = sy-uname.
*    ls_item-created_on  = sy-datum.
*
*    ls_item-temp_id     = COND #( WHEN <i_temp_id> IS ASSIGNED THEN <i_temp_id> ).
*
*    " [FIX]: Khai báo biến chuyển đổi
*    DATA: lv_itm_in TYPE string, lv_itm_out TYPE posnr_va.
*
*    IF <item_no> IS ASSIGNED AND <item_no> IS NOT INITIAL.
*         lv_itm_in = <item_no>.
*         CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_itm_in IMPORTING output = lv_itm_out.
*         ls_item-item_no = lv_itm_out.
*      ELSE.
*         ls_item-item_no = '000010'.
*      ENDIF.
**    ls_item-item_no     = COND #( WHEN <item_no> IS ASSIGNED THEN <item_no> ).
*    ls_item-material       = COND #( WHEN <matnr> IS ASSIGNED THEN <matnr> ).
*    ls_item-plant       = COND #( WHEN <plant> IS ASSIGNED THEN <plant> ).
*    ls_item-ship_point  = COND #( WHEN <ship_point> IS ASSIGNED THEN <ship_point> ).
*    ls_item-store_loc   = COND #( WHEN <stloc> IS ASSIGNED THEN <stloc> ).
*    ls_item-quantity    = COND #( WHEN <qty> IS ASSIGNED THEN <qty> ).
*
*    APPEND ls_item TO ct_item.
*  ENDLOOP.
*
*  " ====================================================================
*  " C. XỬ LÝ CONDITION (MỚI - 7 Cột)
*  " ====================================================================
*  CLEAR lo_data_ref.
*  PERFORM validate_template_structure USING lo_excel_ref 'Condition' 'ZTB_SO_UPLOAD_PR' CHANGING lo_data_ref.
*
*  IF lo_data_ref IS NOT BOUND. RETURN. ENDIF..
*    ASSIGN lo_data_ref->* TO <gt_data_raw>.
*
*    IF <gt_data_raw> IS INITIAL. RETURN. ENDIF.
*
*    LOOP AT <gt_data_raw> ASSIGNING <fs_raw>.
*      DATA(ls_cond) = VALUE ztb_so_upload_pr( ).
*
*      ASSIGN COMPONENT 1 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_temp_id>).
*      ASSIGN COMPONENT 2 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_item_no>).
*      ASSIGN COMPONENT 3 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_type>).
*      ASSIGN COMPONENT 4 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_amount>).
*      ASSIGN COMPONENT 5 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_curr>).
*      ASSIGN COMPONENT 6 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_per>).
*      ASSIGN COMPONENT 7 OF STRUCTURE <fs_raw> TO FIELD-SYMBOL(<c_uom>).
*
*      CHECK <c_temp_id> IS ASSIGNED AND <c_temp_id> IS NOT INITIAL.
*
*      ls_cond-req_id     = iv_req_id.
*      ls_cond-status     = 'NEW'.
*      ls_cond-created_by = sy-uname.
*      ls_cond-created_on = sy-datum.
*      ls_cond-temp_id    = <c_temp_id>.
*
*      IF <c_item_no> IS ASSIGNED.
*         lv_itm_in = <c_item_no>.
*         CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_itm_in IMPORTING output = lv_itm_out.
*         ls_cond-item_no = lv_itm_out.
*      ENDIF.
*
*      ls_cond-cond_type  = COND #( WHEN <c_type> IS ASSIGNED THEN <c_type> ).
*      ls_cond-currency   = COND #( WHEN <c_curr> IS ASSIGNED THEN <c_curr> ).
*      ls_cond-uom        = COND #( WHEN <c_uom>  IS ASSIGNED THEN <c_uom> ).
*
*      IF <c_amount> IS ASSIGNED. TRY. ls_cond-amount = <c_amount>. CATCH cx_root. ENDTRY. ENDIF.
*      IF <c_per>    IS ASSIGNED. TRY. ls_cond-per    = <c_per>.    CATCH cx_root. ENDTRY. ENDIF.
*
*      APPEND ls_cond TO ct_cond.
*    ENDLOOP.

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
      IF <c_per>    IS ASSIGNED. TRY. ls_cond-per    = <c_per>.    CATCH cx_root. ENDTRY. ENDIF.

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
          EXPORTING date = cv_dats
          EXCEPTIONS OTHERS = 1.
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
    EXPORTING date = cv_dats
    EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0.
     CLEAR cv_dats. " Invalid date created
  ENDIF.

ENDFORM.
"--------------------------------------------------------------------------------------------------------
*&---------------------------------------------------------------------*
*& Form PERFORM_MASS_UPLOAD (ĐÃ SỬA: Nhận 2 tham số từ PAI)
*&---------------------------------------------------------------------*
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


*&---------------------------------------------------------------------*
*& Form validate_and_classify_data
*&---------------------------------------------------------------------*
*& Validates data in gt_so_header/item and moves rows to
*& _comp, _incomp, _err tables based on validation status.
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*FORM validate_and_classify_data CHANGING
*    cv_user_canceled TYPE abap_bool.
*
*  FIELD-SYMBOLS: <ls_header> LIKE LINE OF gt_so_header,
*                 <ls_item>   LIKE LINE OF gt_so_item.
*  DATA: lt_errors TYPE ty_t_validation_error. " <<< Use specific table type here too
*  DATA: lv_log_reqid TYPE zso_log_213-req_id VALUE 'VALIDATE_TMP'. " Temporary ID if needed
*
*  " --- 1. Validate Header Data (Calls V01 forms) ---
*  " Assumes V01 forms now call 'add_validation_error' on error
*  PERFORM validate_header_table
*                              CHANGING gt_so_header.
*
*  " --- 2. Validate Item Data (Calls V01 forms) ---
*  " Assumes V01 forms now call 'add_validation_error' on error
*  PERFORM validate_item_table
*                             CHANGING gt_so_item.
*
*  " --- CORRECTED: Get Detailed Errors using CHANGING ---
*  PERFORM get_validation_errors
*                                CHANGING lt_errors. " <<< CHANGE: Use CHANGING
*  " --- END CORRECTION ---
*
*
*  " --- NEW: Count Errors ---
*  DATA: lv_error_count TYPE i.
*  lv_error_count = lines( lt_errors ). " <<< CHANGE: Count from detailed error table
*  DATA: lv_warn_count TYPE i. " Count warnings too
*
*  LOOP AT gt_so_header ASSIGNING <ls_header> WHERE status_code = 'W'.
*    lv_warn_count = lv_warn_count + 1.
*  ENDLOOP.
*
*  LOOP AT gt_so_item   ASSIGNING <ls_item>   WHERE status_code = 'W'.
*    lv_warn_count = lv_warn_count + 1.
*  ENDLOOP.
*
*  LOOP AT gt_so_header ASSIGNING <ls_header> WHERE status_code = 'E'.
*    lv_error_count = lv_error_count + 1.
*  ENDLOOP.
*  LOOP AT gt_so_item ASSIGNING <ls_item> WHERE status_code = 'E'.
*    lv_error_count = lv_error_count + 1. " Count item errors too if needed, or just header errors
*  ENDLOOP.
*
*  " --- Log Validation Outcome ---
*  DATA: lv_log_status TYPE zso_log_213-status,
*        lv_log_msgty  TYPE zso_log_213-msgty,
*        lv_log_msg    TYPE zso_log_213-message.
*
*  IF lv_error_count > 0.
*    lv_log_status = 'FAILED'.
*    lv_log_msgty = 'E'.
*    lv_log_msg = |Validation failed: { lv_error_count } error(s) found.|.
*  ELSEIF lv_warn_count > 0.
*    lv_log_status = 'WARNING'.
*    lv_log_msgty = 'W'.
*    lv_log_msg = |Validation completed with { lv_warn_count } warning(s).|.
*  ELSE.
*    lv_log_status = 'SUCCESS'.
*    lv_log_msgty = 'S'.
*    lv_log_msg = |Validation successful for all records.|.
*  ENDIF.
*
*  zcl_mass_so_logger_213=>log_action(
*    " iv_reqid = lv_log_reqid " Optional: Pass REQ_ID if available
*    iv_action = 'VALIDATE_RUN'
*    iv_status = lv_log_status
*    iv_msgty  = lv_log_msgty
*    iv_msg    = lv_log_msg
*    iv_commit = abap_true ). " Commit validation summary log
*
*  " --- NEW: Check Error Count and Show Warning Popup ---
*  IF lv_error_count > 20.
*    DATA: lv_answer TYPE c.
*    CALL FUNCTION 'POPUP_TO_CONFIRM'
*      EXPORTING
*        titlebar              = 'Validation Warning'
*        text_question         = |Found { lv_error_count } errors. It's recommended to fix the Excel file and resubmit.|
*        text_button_1         = 'Continue Anyway' " Answer = 1
*        icon_button_1         = 'ICON_CONTINUE'
*        text_button_2         = 'Cancel' " Answer = 2
*        icon_button_2         = 'ICON_CANCEL'
*        default_button        = '2'
*        display_cancel_button = '' " Don't display separate cancel button
*        popup_type            = 'ICON_MESSAGE_WARNING'
*      IMPORTING
*        answer                = lv_answer
*      EXCEPTIONS
*        text_not_found        = 1
*        OTHERS                = 2.
*    IF sy-subrc <> 0 OR lv_answer = '2'. " If user cancels or popup fails
*
**     " <<< 2. PHẢI CÓ DÒNG NÀY >>>
**      cv_user_canceled = abap_true. " Báo cho FORM cha biết là đã cancel
*
*      " Option 1: Stay on screen 200 but clear classified data (forcing user action)
*       zcl_mass_so_logger_213=>log_action(
*          " iv_reqid = lv_log_reqid " Optional
*          iv_action = 'VALIDATE_ABORT'
*          iv_status = 'INFO'
*          iv_msg    = |Validation aborted by user due to >20 errors.|
*          iv_commit = abap_true ).
*
*        " <<< SỬA: CHỈ CẦN GÁN CỜ >>>
*      cv_user_canceled = abap_true.
*    ENDIF.
*    " If user chooses 'Continue Anyway' (lv_answer = '1'), processing continues below
*  ENDIF.
*  " --- END NEW SECTION ---
*
*  " --- 3. Classify and Move Data ---
*  " Clear target tables before filling
*  CLEAR: gt_so_header_comp, gt_so_item_comp,
*         gt_so_header_incomp, gt_so_item_incomp,
*         gt_so_header_err, gt_so_item_err.
*
*  DATA: lt_processed_headers TYPE HASHED TABLE OF ty_header WITH UNIQUE KEY temp_id.
*
*  LOOP AT gt_so_item ASSIGNING <ls_item>.
*    READ TABLE gt_so_header ASSIGNING <ls_header>
*                           WITH KEY temp_id = <ls_item>-temp_id BINARY SEARCH. " Assuming gt_so_header is sorted by temp_id
*    IF sy-subrc <> 0.
*      " Orphan item - Treat as Error or handle differently? For now, add to Error.
*      <ls_item>-status_code = 'E'.
*      <ls_item>-status_text = 'Error'.
*      <ls_item>-message = 'No corresponding Header found for this Item.'.
*      APPEND <ls_item> TO gt_so_item_err.
*      CONTINUE.
*    ENDIF.
*
*    " Determine Overall Status (Error > Warning > Success)
*    DATA(lv_overall_status) = 'S'. " Assume Success initially
*    IF <ls_header>-status_code = 'E' OR <ls_item>-status_code = 'E'.
*      lv_overall_status = 'E'.
*    ELSEIF <ls_header>-status_code = 'W' OR <ls_item>-status_code = 'W'.
*      lv_overall_status = 'W'.
*    ENDIF.
*
*    " Move based on overall status
*    CASE lv_overall_status.
*      WHEN 'E'. " Error
*        APPEND <ls_item> TO gt_so_item_err.
*        " Add header only once per Temp ID
*        READ TABLE lt_processed_headers WITH KEY temp_id = <ls_header>-temp_id TRANSPORTING NO FIELDS.
*        IF sy-subrc <> 0.
*           APPEND <ls_header> TO gt_so_header_err.
*           INSERT <ls_header> INTO TABLE lt_processed_headers.
*        ENDIF.
*      WHEN 'W'. " Warning -> Incomplete
*        APPEND <ls_item> TO gt_so_item_incomp.
*        READ TABLE lt_processed_headers WITH KEY temp_id = <ls_header>-temp_id TRANSPORTING NO FIELDS.
*        IF sy-subrc <> 0.
*           APPEND <ls_header> TO gt_so_header_incomp.
*           INSERT <ls_header> INTO TABLE lt_processed_headers.
*        ENDIF.
*      WHEN 'S'. " Success -> Complete
*        APPEND <ls_item> TO gt_so_item_comp.
*         READ TABLE lt_processed_headers WITH KEY temp_id = <ls_header>-temp_id TRANSPORTING NO FIELDS.
*        IF sy-subrc <> 0.
*           APPEND <ls_header> TO gt_so_header_comp.
*           INSERT <ls_header> INTO TABLE lt_processed_headers.
*        ENDIF.
*    ENDCASE.
*  ENDLOOP.
*
* " Optional: Handle Headers that had no items (e.g., add them to Error/Incomplete)
* LOOP AT gt_so_header ASSIGNING <ls_header>.
*    READ TABLE lt_processed_headers WITH KEY temp_id = <ls_header>-temp_id TRANSPORTING NO FIELDS.
*    IF sy-subrc <> 0. " This header wasn't processed (had no items)
*       CASE <ls_header>-status_code.
*          WHEN 'E'. APPEND <ls_header> TO gt_so_header_err.
*          WHEN 'W'. APPEND <ls_header> TO gt_so_header_incomp.
*          WHEN 'S'. APPEND <ls_header> TO gt_so_header_comp. " Or maybe incomplete if no items? Your choice.
*       ENDCASE.
*    ENDIF.
* ENDLOOP.
*
**  " --- >>> ADDITION 2: Call Highlighting <<< ---
**  PERFORM highlight_error_cells USING lt_errors. " Pass the collected errors
**  " --- >>> END ADDITION 2 <<< ---
*
*  " --- 4. (Optional but recommended) Update Icons based on final classification ---
*  PERFORM set_icons_classified_data.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_icons_classified_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*FORM set_icons_classified_data .
*  DATA: lv_icon_green TYPE icon-internal,
*        lv_icon_yellow TYPE icon-internal,
*        lv_icon_red   TYPE icon-internal.
*
*  SELECT SINGLE internal INTO lv_icon_green FROM icon WHERE name = gc_icon_green.
*  SELECT SINGLE internal INTO lv_icon_yellow FROM icon WHERE name = gc_icon_yellow.
*  SELECT SINGLE internal INTO lv_icon_red FROM icon WHERE name = gc_icon_red.
*
*  FIELD-SYMBOLS: <h> LIKE LINE OF gt_so_header,
*                 <i> LIKE LINE OF gt_so_item.
*
*  LOOP AT gt_so_header_comp ASSIGNING <h>. <h>-icon = lv_icon_green. ENDLOOP.
*  LOOP AT gt_so_item_comp   ASSIGNING <i>. <i>-icon = lv_icon_green. ENDLOOP.
*  LOOP AT gt_so_header_incomp ASSIGNING <h>. <h>-icon = lv_icon_yellow. ENDLOOP.
*  LOOP AT gt_so_item_incomp   ASSIGNING <i>. <i>-icon = lv_icon_yellow. ENDLOOP.
*  LOOP AT gt_so_header_err ASSIGNING <h>. <h>-icon = lv_icon_red. ENDLOOP.
*  LOOP AT gt_so_item_err   ASSIGNING <i>. <i>-icon = lv_icon_red. ENDLOOP.
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form REVALIDATE_DATA (Logic Staging: Sync -> Validate -> Load)
*&---------------------------------------------------------------------*
FORM revalidate_data.

  " 1. Log bắt đầu
  zcl_mass_so_logger_213=>log_action(

*    iv_reqid =  gv_current_req_id
    iv_action = 'REVALIDATE_START'
    iv_status = 'INFO'
    iv_msg = 'User triggered revalidation.'
    iv_commit = abap_true
  ).

*  " 2. Ép ALV nhả dữ liệu user vừa sửa vào bảng nội bộ
*  " (Chỉ cần check các tab cho phép Edit)
*  IF go_grid_hdr_incomp IS BOUND. go_grid_hdr_incomp->check_changed_data( ). ENDIF.
*  IF go_grid_item_incomp IS BOUND. go_grid_item_incomp->check_changed_data( ). ENDIF.
*  IF go_grid_hdr_err IS BOUND.    go_grid_hdr_err->check_changed_data( ). ENDIF.
*  IF go_grid_item_err IS BOUND.   go_grid_item_err->check_changed_data( ). ENDIF.

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

  " 5. Bật cờ để PBO vẽ lại màn hình
  gv_data_loaded = abap_true.

  MESSAGE 'Re-validation completed.' TYPE 'S'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form resubmit_file
*&---------------------------------------------------------------------*
*& Allows user to select a new file directly from Screen 200,
*& then uploads, validates, classifies, and refreshes the ALVs.
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*FORM resubmit_file .
*   zcl_mass_so_logger_213=>log_action( iv_action = 'RESUBMIT_START' iv_status = 'INFO' iv_msg = 'User triggered resubmit file.' ).
*   DATA: lv_filepath TYPE rlgrap-filename.
*
*  " Step 1: Ask user to select the new Excel file
*  PERFORM open_file_dialog CHANGING lv_filepath.
*
*  " Step 2: Check if a file was selected
*  IF lv_filepath IS INITIAL.
*    MESSAGE 'Resubmit cancelled by user or no file selected.' TYPE 'I'.
*    RETURN. " Stop processing if no file chosen
*  ENDIF.
*
*  " Step 3: Clear all existing data from internal tables
*  CLEAR: gt_so_header, gt_so_item,
*         gt_so_header_comp, gt_so_item_comp,
*         gt_so_header_incomp, gt_so_item_incomp,
*         gt_so_header_err, gt_so_item_err.
*  " Optional: Clear gt_staging if needed
*
*  " Step 5: Check if data was read from the new file
*  IF gt_so_header IS INITIAL AND gt_so_item IS INITIAL.
*    MESSAGE 'No data found in the newly selected file or file read failed.' TYPE 'W'.
*    " Still need to refresh ALVs to show they are empty now
*    PERFORM refresh_all_alvs.
*    RETURN.
*  ENDIF.
*
*  DATA: lv_user_canceled TYPE abap_bool. " <<< THÊM: Khai báo cờ
*
*  " Step 6: Validate and Classify the NEW data
*  PERFORM validate_and_classify_data CHANGING
*      lv_user_canceled. " This will refill _comp/_incomp/_err tables
*
*  " Step 7: Refresh all ALV displays with the new classified data
*  PERFORM refresh_all_alvs.
*
*  " Step 8: Show the summary popup for the NEW file
**  PERFORM show_validation_summary.
*   PERFORM update_status_counts.
*ENDFORM.
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
        titel        = 'Information'
        textline1    = 'No data available to save.'.
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
        titel        = 'Save Successful'
        textline1    = lv_success_msg.
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
        titel        = 'Save Failed'
        textline1    = 'An error occurred while saving the staging data.'
        textline2    = 'Operation has been rolled back.'
        textline3    = |(Details: SUBRC Header={ lv_subrc_h }, Item={ lv_subrc_i })|.
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

*&---------------------------------------------------------------------*
*& Form PERFORM_CREATE_SALES_ORDERS
*&---------------------------------------------------------------------*
*& Processes records from the 'Complete' internal tables
*& and calls BAPI_SALESORDER_CREATEFROMDAT2 to create Sales Orders.
*&---------------------------------------------------------------------*
*FORM perform_create_sales_orders.
*
*
*  " Check if there is data in the 'Complete' tables
*  IF gt_so_header_comp IS INITIAL.
*    MESSAGE 'No validated ("Complete") data available to create Sales Orders.' TYPE 'I'.
*    RETURN.
*  ENDIF.
*
*  " BAPI Structures & Tables
*  DATA: ls_header         TYPE bapisdhd1,
*        ls_headerx        TYPE bapisdhd1x,
*        lt_partner        TYPE STANDARD TABLE OF bapiparnr,
*        lt_item           TYPE STANDARD TABLE OF bapisditm,
*        lt_itemx          TYPE STANDARD TABLE OF bapisditmx,
*        lt_sched          TYPE STANDARD TABLE OF bapischdl,
*        lt_schedx         TYPE STANDARD TABLE OF bapischdlx,
*        lt_cond           TYPE STANDARD TABLE OF bapicond,
*        lt_condx          TYPE STANDARD TABLE OF bapicondx,
*        lt_return         TYPE STANDARD TABLE OF bapiret2,
*        lv_vbeln          TYPE vbak-vbeln, " Created Sales Document
*        lv_commit_needed  TYPE abap_bool,
*        lv_errors_occurred TYPE abap_bool.
*
*  " Summary Counters
*  DATA: lv_success_count TYPE i,
*        lv_error_count   TYPE i.
*
*  FIELD-SYMBOLS: <h_comp> LIKE LINE OF gt_so_header_comp,
*                 <i_comp> LIKE LINE OF gt_so_item_comp.
*
*  CLEAR gt_result. " <<< Xóa bảng kết quả cũ trước khi bắt đầu
*
*  " --- Loop through each validated Header record ---
*  LOOP AT gt_so_header_comp ASSIGNING <h_comp>.
*
*    CLEAR: ls_header, ls_headerx, lv_vbeln, lv_errors_occurred.
*    REFRESH: lt_partner, lt_item, lt_itemx, lt_sched, lt_schedx, lt_cond, lt_condx, lt_return.
*    lv_commit_needed = abap_false. " Reset flag for each SO attempt
*
*    " --- 3.3 Prepare BAPI Input ---
*    " --- Header Data ---
*    ls_header-doc_type   = <h_comp>-order_type.
*    ls_header-sales_org  = <h_comp>-sales_org.
*    ls_header-distr_chan = <h_comp>-sales_channel.
*    ls_header-division   = <h_comp>-sales_div.
*    ls_header-req_date_h = <h_comp>-request_dev_date.
*    ls_header-purch_no_c = <h_comp>-cust_ref.
*    ls_header-currency   = <h_comp>-currency.
*    ls_header-pmnttrms   = <h_comp>-pmnttrms.
**    ls_header-incoterms1 = <h_comp>-incoterms. " Field name for Incoterms
*    ls_header-ship_cond  = <h_comp>-ship_cond.
*    ls_header-price_date = <h_comp>-price_date.
*    ls_header-doc_date   = <h_comp>-order_date. " Document Date
*    ls_header-sales_off  = <h_comp>-sales_off.
*    ls_header-sales_grp  = <h_comp>-sales_grp.
*    " Add other relevant header fields if needed
*
**    " --- Header X-Flags (Mark fields to be updated) ---
**    ls_headerx = VALUE #( doc_type = 'X' sales_org = 'X' distr_chan = 'X' division = 'X'
**                          req_date_h = 'X' purch_no_c = 'X' currency = 'X'
**                          pmnttrms = 'X' incoterms1 = 'X' ship_cond = 'X'
**                          price_date = 'X' doc_date = 'X'
**                          sales_off = COND #( WHEN ls_header-sales_off IS NOT INITIAL THEN 'X' ) " Only if provided
**                          sales_grp = COND #( WHEN ls_header-sales_grp IS NOT INITIAL THEN 'X' ) " Only if provided
**                        ).
*
*     " --- Header X-Flags (Mark fields to be updated) ---
*    ls_headerx = VALUE #( doc_type = 'X' sales_org = 'X' distr_chan = 'X' division = 'X'
*                          req_date_h = 'X' purch_no_c = 'X' currency = 'X'
*                          pmnttrms = 'X' ship_cond = 'X'
*                          price_date = 'X' doc_date = 'X'
*                          sales_off = COND #( WHEN ls_header-sales_off IS NOT INITIAL THEN 'X' ) " Only if provided
*                          sales_grp = COND #( WHEN ls_header-sales_grp IS NOT INITIAL THEN 'X' ) " Only if provided
*                        ).
*
*
*    " --- Partner Data ---
*    DATA(lv_sold_to) = <h_comp>-sold_to_party.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
*    APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner.
*    APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner. " Assuming Ship-to = Sold-to
*    " Add other partners (PY, RE) if necessary and available
*
*    " --- Item Data Loop ---
*    LOOP AT gt_so_item_comp ASSIGNING <i_comp> WHERE temp_id = <h_comp>-temp_id.
*      DATA(lv_posnr) = <i_comp>-item_no.
*      IF lv_posnr IS INITIAL. lv_posnr = ( lines( lt_item ) + 1 ) * 10. ENDIF.
*
*      " --- Items ---
*      APPEND VALUE #( itm_number = lv_posnr
*                      material   = <i_comp>-matnr
*                      target_qty = <i_comp>-quantity
*                      target_qu  = <i_comp>-unit
*                      plant      = <i_comp>-plant
*                      store_loc  = <i_comp>-store_loc
*                      short_text = <i_comp>-short_text ) TO lt_item.
*      " --- Item X-Flags ---
*      APPEND VALUE #( itm_number = lv_posnr material = 'X' target_qty = 'X' target_qu = 'X'
*                      plant = 'X' store_loc = 'X'
*                      short_text = COND #( WHEN <i_comp>-short_text IS NOT INITIAL THEN 'X' )
*                    ) TO lt_itemx.
*
*      " --- Schedule Lines ---
*      APPEND VALUE #( itm_number = lv_posnr
*                      req_qty    = <i_comp>-quantity " Assuming full qty on req date
*                      req_date   = <i_comp>-req_date ) TO lt_sched.
*      APPEND VALUE #( itm_number = lv_posnr req_qty = 'X' req_date = 'X' ) TO lt_schedx.
*
*      " --- Conditions (Optional - if provided) ---
*      IF <i_comp>-cond_type IS NOT INITIAL AND <i_comp>-unit_price IS NOT INITIAL.
*        APPEND VALUE #( itm_number = lv_posnr
*                        cond_type  = <i_comp>-cond_type
*                        cond_value = <i_comp>-unit_price
*                        currency   = <h_comp>-currency ) " Use header currency
*                        TO lt_cond.
*        APPEND VALUE #( itm_number = lv_posnr cond_type = <i_comp>-cond_type
*                        cond_value = 'X' currency = 'X' ) TO lt_condx.
*      ENDIF.
*    ENDLOOP. " End Item Loop
*
*    " --- 3.4 Call BAPI Create SO ---
*    CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
*      EXPORTING
*        order_header_in    = ls_header
*        order_header_inx   = ls_headerx
*        behave_when_error  = 'P' " <<< Important: Process next order on error
** LOGIC_SWITCH       = VALUE bapisdls( pricing = 'G' ) " Optional: Suppress output determination
*      IMPORTING
*        salesdocument      = lv_vbeln
*      TABLES
*        return             = lt_return
*        order_items_in     = lt_item
*        order_items_inx    = lt_itemx
*        order_partners     = lt_partner
*        order_schedules_in = lt_sched
*        order_schedules_inx = lt_schedx
*        order_conditions_in = lt_cond
*        order_conditions_inx = lt_condx.
*
*    " --- 3.5 Process BAPI Return ---
*    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ret>) WHERE type CA 'AEX'. " Thêm ASSIGNING " Check for Abort, Error, Termination (X)
*      lv_errors_occurred = abap_true.
*      EXIT.
*    ENDLOOP.
*
*    "xong 1 cái
*    DATA: ls_result LIKE LINE OF gt_result.
*    MOVE-CORRESPONDING <h_comp> TO ls_result. " Điền thông tin cơ bản
*    " --- THÊM CÁC DÒNG GÁN DỮ LIỆU BỊ THIẾU ---
*    ls_result-temp_id = <h_comp>-temp_id.
*    ls_result-vkorg   = <h_comp>-sales_org.
*    ls_result-vtweg   = <h_comp>-sales_channel.
*    ls_result-spart   = <h_comp>-sales_div.
*    " --- KẾT THÚC THÊM ---
*    ls_result-sold_to  = lv_sold_to.
*    ls_result-ship_to  = lv_sold_to.
*    ls_result-qty      = lines( lt_item ).
*    ls_result-bstkd    = <h_comp>-cust_ref.
*    ls_result-req_date = <h_comp>-request_dev_date.
*
*    " --- 3.6 Commit/Rollback ---
*    IF lv_errors_occurred = abap_false AND lv_vbeln IS NOT INITIAL.
*      lv_commit_needed = abap_true. " Mark for commit
*      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
*        EXPORTING
*          wait = abap_true.
*      IF sy-subrc <> 0.
*         " Commit failed - treat as error
*         lv_errors_occurred = abap_true.
*         MESSAGE 'Critical Error: BAPI_TRANSACTION_COMMIT failed.' TYPE 'E'.
*         APPEND VALUE #( type = 'E' message = 'BAPI COMMIT failed after SO creation attempt.' ) TO lt_return.
*
*         " <<< SỬA LỖI: Điền kết quả LỖI COMMIT >>>
*         ls_result-vbeln   = lv_vbeln. " Vẫn có số SO nhưng bị lỗi commit
*         ls_result-status  = 'Failed (Commit)'.
*         ls_result-message = 'Critical Error: BAPI_TRANSACTION_COMMIT failed.'.
*         APPEND ls_result TO gt_result. " <<< APPEND LỖI COMMIT Ở ĐÂY
*      ELSE.
*        lv_success_count = lv_success_count + 1.
*        <h_comp>-sales_order = lv_vbeln. " Store SO number back
*        <h_comp>-status_code = 'P'.      " Mark as Processed
*        <h_comp>-status_text = 'Processed'.
*        <h_comp>-message     = |SO { lv_vbeln } created.|.
*        LOOP AT gt_so_item_comp ASSIGNING <i_comp> WHERE temp_id = <h_comp>-temp_id.
*            <i_comp>-sales_order = lv_vbeln. " Store SO number
*            <i_comp>-status_code = 'P'.      " Mark item as processed
*            <i_comp>-status_text = 'Processed'.
*        ENDLOOP.
*
*        " --- >>> ADD THIS CALL <<< ---
*        " Try to create outbound delivery automatically
*        PERFORM perform_auto_delivery USING lv_vbeln
*                                      CHANGING <h_comp>. " Pass <h_comp> to update status/message
*        " --- >>> END ADDITION <<< ---
*
*        " <<< SỬA LỖI: Điền kết quả THÀNH CÔNG (sau khi auto-delivery đã cập nhật <h_comp>) >>>
*        ls_result-vbeln   = lv_vbeln.
*        ls_result-status  = <h_comp>-status_text. " Sẽ là 'Delivered' hoặc 'Warning'
*        ls_result-message = <h_comp>-message.     " Sẽ là "SO... Deliv..." hoặc "SO... Deliv Failed..."
*        APPEND ls_result TO gt_result. " <<< APPEND THÀNH CÔNG Ở ĐÂY
*      ENDIF.
*    ELSE.
*      " Errors occurred OR BAPI didn't return a document number
*      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
*      lv_error_count = lv_error_count + 1.
*      <h_comp>-status_code = 'X'. " Mark as Failed
*      <h_comp>-status_text = 'Failed'.
*      " Concatenate error messages
*      CLEAR <h_comp>-message.
*      LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<fs_ret>) WHERE type CA 'AEXW'. " Show Errors/Warnings
*        <h_comp>-message = |{ <h_comp>-message } { <fs_ret>-message } / |. " <<< Sửa ở đây nữa
*      ENDLOOP.
*      CONDENSE <h_comp>-message.
*       LOOP AT gt_so_item_comp ASSIGNING <i_comp> WHERE temp_id = <h_comp>-temp_id.
*            <i_comp>-status_code = 'X'. " Mark item as failed
*            <i_comp>-status_text = 'Failed'.
*       ENDLOOP.
*      " <<< SỬA LỖI: Điền kết quả LỖI BAPI >>>
*       ls_result-vbeln   = ''. " Không có số SO
*       ls_result-status  = 'Failed (BAPI)'.
*       ls_result-message = <h_comp>-message. " Message lỗi BAPI
*       APPEND ls_result TO gt_result. " <<< APPEND LỖI BAPI Ở ĐÂY
*    ENDIF.
*
*    DATA: lv_log_reqid_param LIKE zso_log_213-req_id.
*    lv_log_reqid_param = <h_comp>-req_id.
*
*    " --- 3.8 Log Results ---
*    zcl_mass_so_logger_213=>log_bapiret2(
*        it_return = lt_return
*        iv_reqid  = lv_log_reqid_param " <<< Assumes REQ_ID exists!
*        iv_action = 'CREATE_SO'
*        iv_status = COND #( WHEN lv_errors_occurred = abap_true THEN 'FAILED' ELSE 'SUCCESS' )
*        iv_commit = abap_false ). " Commit happens explicitly above or not at all
*
**    " --- 3.7 Update Z Table (if REQ_ID exists) ---
**    IF <h_comp>-req_id IS NOT INITIAL.
**        UPDATE ztb_so_heder_213 SET proc_status = <h_comp>-status_code,
**                                    sales_order = <h_comp>-sales_order " Will be blank on failure
**                              WHERE req_id = @<h_comp>-req_id.
**        UPDATE ztb_so_item_213 SET proc_status = <h_comp>-status_code " Use header status for items
**                             WHERE req_id = @<h_comp>-req_id.
**        IF lv_commit_needed = abap_true.
**           COMMIT WORK. " Commit Z table update separately AFTER BAPI commit
**        ENDIF.
**    ENDIF.
*
*     " --- 3.7 Save/Update Staging Table Status ---
*    " We use MODIFY which handles both INSERT (if not saved before)
*    " and UPDATE (if saved before) based on the primary key (MANDT, REQ_ID)
*    DATA: ls_header_db TYPE ztb_so_heder_213, " <<< Use TYPE db_table_name
*          ls_item_db   TYPE ztb_so_item_213, " <<< Use TYPE db_table_name
*          lt_items_db  TYPE STANDARD TABLE OF ztb_so_item_213.
*
*    " Prepare header record for DB update/insert
*    MOVE-CORRESPONDING <h_comp> TO ls_header_db.
*    ls_header_db-proc_status = <h_comp>-status_code. " Should be 'P' or 'X'
*    ls_header_db-sales_order = <h_comp>-sales_order. " SO Number or blank
*
*    MODIFY ztb_so_heder_213 FROM ls_header_db.
*    IF sy-subrc <> 0.
*      " Log error updating header staging table
*       zcl_mass_so_logger_213=>log_action(
*          iv_reqid  = lv_log_reqid_param
*          iv_action = 'UPDATE_STG_HDR'
*          iv_status = 'ERROR'
*          iv_msgty  = 'E'
*          iv_msg    = |Error updating ZTB_SO_HEDER_213 for REQ_ID { <h_comp>-req_id }. SUBRC={ sy-subrc }| ).
*    ENDIF.
*
*    " Prepare item records for DB update/insert
*    CLEAR lt_items_db.
*    LOOP AT gt_so_item_comp ASSIGNING <i_comp> WHERE req_id = <h_comp>-req_id AND status_code = <h_comp>-status_code. " Items that just got processed/failed
*         MOVE-CORRESPONDING <i_comp> TO ls_item_db.
*         ls_item_db-proc_status = <i_comp>-status_code. " 'P' or 'X'
*         ls_item_db-sales_order = <i_comp>-sales_order. " SO Number or blank
*         APPEND ls_item_db TO lt_items_db.
*    ENDLOOP.
*    LOOP AT gt_so_item_err ASSIGNING <i_comp> WHERE req_id = <h_comp>-req_id AND status_code = 'X'. " Also update items moved to Error tab in this run
*        READ TABLE lt_items_db TRANSPORTING NO FIELDS WITH KEY item_no = <i_comp>-item_no.
*        IF sy-subrc <> 0. " Avoid duplicates if already added
*             MOVE-CORRESPONDING <i_comp> TO ls_item_db.
*             ls_item_db-proc_status = <i_comp>-status_code. " 'X'
*             ls_item_db-sales_order = <i_comp>-sales_order.
*             APPEND ls_item_db TO lt_items_db.
*        ENDIF.
*    ENDLOOP.
*
*    IF lt_items_db IS NOT INITIAL.
*       MODIFY ztb_so_item_213 FROM TABLE @lt_items_db.
*       IF sy-subrc <> 0.
*         " Log error updating item staging table
*         zcl_mass_so_logger_213=>log_action(
*            iv_reqid  = lv_log_reqid_param
*            iv_action = 'UPDATE_STG_ITM'
*            iv_status = 'ERROR'
*            iv_msgty  = 'E'
*            iv_msg    = |Error updating ZTB_SO_ITEM_213 for REQ_ID { <h_comp>-req_id }. SUBRC={ sy-subrc }| ).
*       ENDIF.
*    ENDIF.
*
*    " Commit the Z table update only if the BAPI itself was committed
*    IF lv_commit_needed = abap_true.
*       COMMIT WORK. " Commit Z table changes
*    ELSE.
*       " If BAPI failed and rolled back, maybe rollback Z table changes too?
*       " Or leave them as 'X' status? Current logic leaves them as 'X'.
*       COMMIT WORK. " Commit the 'X' status update to Z tables
*    ENDIF.
*
*
*  ENDLOOP. " End Header Loop
*
**  " --- 3.11 Display Summary ---
**  DATA lv_summary_msg TYPE string.
**  lv_summary_msg = |Processing finished: { lv_success_count } Sales Order(s) created, { lv_error_count } failed.|.
**  CALL FUNCTION 'POPUP_TO_DISPLAY_TEXT'
**    EXPORTING
**      titel     = 'Sales Order Creation Results'
**      textline1 = lv_summary_msg
**      textline2 = 'Check ALV and Log (Table ZSO_LOG_213) for details.'.
*
*   " --- 3.11 Display Summary ---
*   PERFORM display_result_popup_alv. " <<< GỌI FORM MỚI
*
*  " --- 3.12 Refresh ALV ---
*  " Move failed records from _comp to _err tables *before* refreshing
*  LOOP AT gt_so_header_comp ASSIGNING <h_comp> WHERE status_code = 'X'.
*     APPEND <h_comp> TO gt_so_header_err.
*  ENDLOOP.
*  DELETE gt_so_header_comp WHERE status_code = 'X'.
*
*  LOOP AT gt_so_item_comp ASSIGNING <i_comp> WHERE status_code = 'X'.
*     APPEND <i_comp> TO gt_so_item_err.
*  ENDLOOP.
*  DELETE gt_so_item_comp WHERE status_code = 'X'.
*
*  " Update Icons again for potentially moved/updated records
*  PERFORM set_icons_classified_data.
*
*  PERFORM refresh_all_alvs.
*
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form PERFORM_CREATE_SALES_ORDERS (Batch Processing)
*&---------------------------------------------------------------------*
FORM perform_create_sales_orders.

  " 1. Biến cục bộ
  DATA: ls_header_in     TYPE bapisdhd1,
        ls_header_inx    TYPE bapisdhd1x,
        lt_items_in      TYPE TABLE OF bapisditm,
        lt_items_inx     TYPE TABLE OF bapisditmx,
        lt_partners      TYPE TABLE OF bapiparnr,
        lt_schedules_in  TYPE TABLE OF bapischdl,
        lt_schedules_inx TYPE TABLE OF bapischdlx,
        lt_conditions_in TYPE TABLE OF bapicond,
        lt_conditions_inx TYPE TABLE OF bapicondx,
        lt_return        TYPE TABLE OF bapiret2.

  DATA: lv_vbtyp TYPE vbak-vbtyp.

  DATA: lv_salesdocument TYPE vbak-vbeln. " (Dùng biến đơn)
  DATA: lv_item_no       TYPE posnr_va.
  DATA: lt_bapi_errors   TYPE ztty_validation_error. " Bảng lỗi để gọi Logger

  " Cờ kiểm tra lỗi con
  DATA: lv_has_child_error TYPE abap_bool.

  " Check xem có dữ liệu để xử lý không
  IF gt_hd_val IS INITIAL.
    MESSAGE 'No data in Validated tab to process.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " --- 2. VÒNG LẶP XỬ LÝ HÀNG LOẠT (BATCH LOOP) ---
  " Chỉ xử lý các dòng có Status là READY hoặc INCOMP (Cảnh báo)
  " Bỏ qua các dòng ERROR hoặc NEW (chưa validate)

  LOOP AT gt_hd_val ASSIGNING FIELD-SYMBOL(<fs_hd>)
       WHERE status = 'READY' OR status = 'INCOMP'.

    " Clear biến cho vòng lặp mới
    CLEAR: ls_header_in, ls_header_inx, lv_salesdocument.
    REFRESH: lt_items_in, lt_items_inx, lt_partners, lt_schedules_in,
             lt_schedules_inx, lt_conditions_in, lt_conditions_inx, lt_return, lt_bapi_errors.

    " ========================================================
    " [LOGIC MỚI]: KIỂM TRA LỖI CỦA ITEM & CONDITION TRƯỚC
    " ========================================================

    " A. Kiểm tra Item con có lỗi không?
    LOOP AT gt_it_val TRANSPORTING NO FIELDS
         WHERE temp_id = <fs_hd>-temp_id
           AND status  = 'ERROR'.
      lv_has_child_error = abap_true.
      EXIT.
    ENDLOOP.

    " B. Kiểm tra Condition con có lỗi không?
    IF lv_has_child_error = abap_false.
      LOOP AT gt_pr_val TRANSPORTING NO FIELDS
           WHERE temp_id = <fs_hd>-temp_id
             AND status  = 'ERROR'.
        lv_has_child_error = abap_true.
        EXIT.
      ENDLOOP.
    ENDIF.

    " ==> NẾU CÓ LỖI CON -> BỎ QUA (SKIP) KHÔNG GỌI BAPI
    IF lv_has_child_error = abap_true.
      " (Tùy chọn: Cập nhật message cho Header để user biết tại sao không chạy)
      <fs_hd>-message = 'Skipped: Contains items or conditions with errors.'.

      " Cập nhật DB để lần sau load lên thấy message này (nhưng vẫn giữ status cũ)
      UPDATE ztb_so_upload_hd SET message = <fs_hd>-message
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      CONTINUE. " Nhảy sang Header tiếp theo
    ENDIF.

    " ========================================================
    " A. MAPPING DỮ LIỆU (Staging -> BAPI Structures)
    " ========================================================

    " --- Header ---
    ls_header_in-doc_type   = <fs_hd>-order_type.
    ls_header_in-sales_org  = <fs_hd>-sales_org.
    ls_header_in-distr_chan = <fs_hd>-sales_channel.
    ls_header_in-division   = <fs_hd>-sales_div.
    ls_header_in-sales_grp  = <fs_hd>-sales_grp.
    ls_header_in-sales_off  = <fs_hd>-sales_off.
    ls_header_in-req_date_h = <fs_hd>-req_date.
    ls_header_in-price_date = <fs_hd>-price_date.
    ls_header_in-purch_no_c = <fs_hd>-cust_ref.
    ls_header_in-pmnttrms   = <fs_hd>-pmnttrms.
    ls_header_in-incoterms1 = <fs_hd>-incoterms.
    ls_header_in-incoterms2 = <fs_hd>-inco2.
    ls_header_in-currency   = <fs_hd>-currency.
*    ls_header_in-ord_reason = <fs_hd>-order_reason. " [MỚI] Map Order Reason

    " Header X Flags
    ls_header_inx-doc_type   = 'X'.
    ls_header_inx-sales_org  = 'X'.
    ls_header_inx-distr_chan = 'X'.
    ls_header_inx-division   = 'X'.
    ls_header_inx-req_date_h = 'X'.
    ls_header_inx-purch_no_c = 'X'.
    ls_header_inx-updateflag = 'I'. " Insert
    IF <fs_hd>-sales_grp  IS NOT INITIAL. ls_header_inx-sales_grp  = 'X'. ENDIF.
    IF <fs_hd>-sales_off  IS NOT INITIAL. ls_header_inx-sales_off  = 'X'. ENDIF.
    IF <fs_hd>-price_date IS NOT INITIAL. ls_header_inx-price_date = 'X'. ENDIF.
    IF <fs_hd>-pmnttrms   IS NOT INITIAL. ls_header_inx-pmnttrms   = 'X'. ENDIF.
    IF <fs_hd>-incoterms  IS NOT INITIAL. ls_header_inx-incoterms1 = 'X'. ENDIF.
    IF <fs_hd>-inco2      IS NOT INITIAL. ls_header_inx-incoterms2 = 'X'. ENDIF.
    IF <fs_hd>-currency   IS NOT INITIAL. ls_header_inx-currency   = 'X'. ENDIF.
*    IF <fs_hd>-order_reason IS NOT INITIAL. ls_header_inx-ord_reason = 'X'. ENDIF. " [MỚI]

    " --- Partners ---
    APPEND VALUE #( partn_role = 'AG' partn_numb = <fs_hd>-sold_to_party ) TO lt_partners.
    APPEND VALUE #( partn_role = 'WE' partn_numb = <fs_hd>-sold_to_party ) TO lt_partners.

        " --- [FIX LỖI BAPI]: KIỂM TRA LOẠI CHỨNG TỪ ---
    " Lấy Category của Order Type (C = Order, K = Credit Memo, L = Debit Memo)
    SELECT SINGLE vbtyp FROM tvak INTO lv_vbtyp WHERE auart = <fs_hd>-order_type.

    " --- Items ---
    " (Lấy từ bảng gt_it_val tương ứng với Header này)
    LOOP AT gt_it_val ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE temp_id = <fs_hd>-temp_id.
      lv_item_no = <fs_it>-item_no.

      APPEND VALUE #( itm_number = lv_item_no material = <fs_it>-material plant = <fs_it>-plant store_loc = <fs_it>-store_loc target_qty = <fs_it>-quantity target_qu = <fs_it>-unit ) TO lt_items_in.
      APPEND VALUE #( itm_number = lv_item_no material = 'X' plant = 'X' store_loc = 'X' target_qty = 'X' target_qu = 'X' updateflag = 'I' ) TO lt_items_inx.

      " --- [LOGIC QUAN TRỌNG]: CHỈ TẠO SCHEDULE LINE NẾU LÀ STANDARD ORDER ---
      " (Debit/Credit Memo category K/L không dùng Schedule Line trong BAPI này)

      IF lv_vbtyp <> 'K' AND lv_vbtyp <> 'L'.
         APPEND VALUE #( itm_number = lv_item_no req_qty = <fs_it>-quantity ) TO lt_schedules_in.
         APPEND VALUE #( itm_number = lv_item_no req_qty = 'X' ) TO lt_schedules_inx.
      ENDIF.

*      " Schedule Line
*      APPEND VALUE #( itm_number = lv_item_no req_qty = <fs_it>-quantity ) TO lt_schedules_in.
*      APPEND VALUE #( itm_number = lv_item_no req_qty = 'X' ) TO lt_schedules_inx.
    ENDLOOP.

    " --- Conditions ---
    LOOP AT gt_pr_val ASSIGNING FIELD-SYMBOL(<fs_pr>) WHERE temp_id = <fs_hd>-temp_id.
       APPEND VALUE #( itm_number = <fs_pr>-item_no cond_type = <fs_pr>-cond_type cond_value = <fs_pr>-amount currency = <fs_pr>-currency cond_unit = <fs_pr>-uom cond_p_unt = <fs_pr>-per ) TO lt_conditions_in.
       APPEND VALUE #( itm_number = <fs_pr>-item_no cond_type = <fs_pr>-cond_type cond_value = 'X' currency = 'X' cond_unit = 'X' cond_p_unt = 'X' updateflag = 'I' ) TO lt_conditions_inx.
    ENDLOOP.

    " ========================================================
    " B. GỌI BAPI CREATE
    " ========================================================
    CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
      EXPORTING
        order_header_in     = ls_header_in
        order_header_inx    = ls_header_inx
      IMPORTING
        salesdocument       = lv_salesdocument
      TABLES
        return              = lt_return
        order_items_in      = lt_items_in
        order_items_inx     = lt_items_inx
        order_partners      = lt_partners
        order_schedules_in  = lt_schedules_in
        order_schedules_inx = lt_schedules_inx
        order_conditions_in = lt_conditions_in
        order_conditions_inx = lt_conditions_inx.

    " ========================================================
    " C. XỬ LÝ KẾT QUẢ & GHI LOG Z-TABLE
    " ========================================================

    IF lv_salesdocument IS NOT INITIAL.
      " === CASE 1: TẠO SO THÀNH CÔNG ===
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.

      " 1. Cập nhật Header Staging
      <fs_hd>-status   = 'SUCCESS'.
      <fs_hd>-vbeln_so = lv_salesdocument.
      <fs_hd>-message  = |Sales Order { lv_salesdocument } created.|.

      " 2. Gọi Auto-Delivery (Logic cũ của bạn)
      PERFORM perform_auto_delivery USING lv_salesdocument CHANGING <fs_hd>.
      " (Form trên sẽ update tiếp vbeln_dlv và message nếu delivery thành công/thất bại)

      " 3. Update DB Header
      UPDATE ztb_so_upload_hd SET status = 'SUCCESS' vbeln_so = lv_salesdocument vbeln_dlv = <fs_hd>-vbeln_dlv message = <fs_hd>-message
        WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      " 4. Update DB Item & Cond (Đồng bộ status Success)
      UPDATE ztb_so_upload_it SET status = 'SUCCESS' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_pr SET status = 'SUCCESS' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

      " 5. Xóa Log cũ trong bảng Error (vì đã thành công)
      DELETE FROM ztb_so_error_log WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

    ELSE.
      " === CASE 2: TẠO SO THẤT BẠI (FAILED) ===
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

      <fs_hd>-status = 'FAILED'.

*      " 1. Lọc message lỗi BAPI để hiển thị lên Header
*      LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
*        <fs_hd>-message = ls_ret-message. " Lấy lỗi đầu tiên
*
*        " 2. [QUAN TRỌNG] Map lỗi BAPI vào bảng ZTB_SO_ERROR_LOG
*        " Để tô màu ô lỗi và hiển thị chi tiết
*        APPEND VALUE #(
*           req_id    = <fs_hd>-req_id
*           temp_id   = <fs_hd>-temp_id
*           " Logic Map Item No (Nếu message trả về Row, cần map lại Item No thật)
*           " Ở đây tạm để 000000 nếu là lỗi chung
*           item_no   = COND #( WHEN ls_ret-parameter = 'ORDER_ITEMS_IN' THEN '000010' ELSE '000000' )
*           fieldname = 'BAPI_ERROR' " Hoặc map chi tiết nếu được
*           msg_type  = 'E'
*           message   = ls_ret-message
**           log_user  = sy-uname
**           log_date  = sy-datum
*        ) TO lt_bapi_errors.
*      ENDLOOP.
*
*      IF <fs_hd>-message IS INITIAL. <fs_hd>-message = 'BAPI Failed unknown'. ENDIF.
*
*      " 3. [SỬA LỖI]: Gọi Class Logger thay vì INSERT trực tiếp
*      IF lt_bapi_errors IS NOT INITIAL.
*        " Class Logger sẽ tự động điền User, Date, Status='UNFIXED' và Insert vào DB
*        CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
*          EXPORTING
*            it_errors = lt_bapi_errors.
*      ENDIF.


      " 1. Lọc message lỗi BAPI
      LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
        <fs_hd>-message = ls_ret-message. " Lấy lỗi đầu tiên hiển thị lên Header

        " 2. [SỬA LỖI]: Chỉ điền các trường có trong ZSTR_VALIDATION_ERROR
        APPEND VALUE #(
           req_id    = <fs_hd>-req_id
           temp_id   = <fs_hd>-temp_id
           item_no   = COND #( WHEN ls_ret-parameter = 'ORDER_ITEMS_IN' THEN '000010' ELSE '000000' )
           fieldname = 'BAPI_ERROR'
           msg_type  = 'E'
           message   = ls_ret-message
           " [ĐÃ XÓA]: log_user, log_date, status (Vì structure không có)
        ) TO lt_bapi_errors.
      ENDLOOP.

      IF <fs_hd>-message IS INITIAL. <fs_hd>-message = 'BAPI Failed unknown'. ENDIF.

      " 3. [SỬA LỖI]: Gọi Class Logger thay vì INSERT trực tiếp
      IF lt_bapi_errors IS NOT INITIAL.
        " Class Logger sẽ tự động điền User, Date, Status='UNFIXED' và Insert vào DB
        CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
          EXPORTING
            it_errors = lt_bapi_errors.
      ENDIF.


      " 4. Update DB Header/Item/Cond -> FAILED
      UPDATE ztb_so_upload_hd SET status = 'FAILED' message = <fs_hd>-message WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_it SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.
      UPDATE ztb_so_upload_pr SET status = 'FAILED' WHERE req_id = <fs_hd>-req_id AND temp_id = <fs_hd>-temp_id.

    ENDIF.

  ENDLOOP. " End Loop qua danh sách Validated

  " ========================================================
  " 3. REFRESH UI (Tự động chuyển Tab)
  " ========================================================
  " Sau khi loop xong, DB đã được cập nhật (READY -> SUCCESS/FAILED).
  " Ta gọi lại hàm load data, nó sẽ tự động chia bài lại vào các bảng gt_..._suc/fail.

  PERFORM load_data_from_staging USING gv_current_req_id.

  " Bật cờ để PBO vẽ lại (Status Bar & ALV)
  gv_data_loaded = abap_true.

  MESSAGE 'Processing completed. Please check Success/Failed tabs.' TYPE 'S'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PERFORM_AUTO_DELIVERY
*&---------------------------------------------------------------------*
*& Tries to create an outbound delivery for a single, successfully
*& created Sales Order.
*&---------------------------------------------------------------------*
*FORM perform_auto_delivery USING iv_vbeln_so TYPE vbak-vbeln
*                           CHANGING cs_header   TYPE ty_header. " Để cập nhật status
*
*  DATA lv_log_reqid_param LIKE zso_log_213-req_id. " <<< THÊM DÒNG NÀY
*  lv_log_reqid_param = cs_header-req_id.
*
*  DATA: lt_items        TYPE TABLE OF bapidlvreftosalesorder,
*        ls_item         TYPE bapidlvreftosalesorder,
*        lv_ship_point   TYPE vstel,
*        lv_due_date     TYPE dats,
*        lt_return       TYPE TABLE OF bapiret2,
*        ls_return       TYPE bapiret2,
*        lv_delivery     TYPE likp-vbeln,
*        lv_count        TYPE bapidlvcreateheader-num_deliveries,
*        lv_msg          TYPE string.
*
*  DATA: lt_vbap TYPE TABLE OF vbap,
*        ls_vbap LIKE LINE OF lt_vbap.
*
*  "--- Lấy thông tin item (đặc biệt là Shipping Point) từ SO vừa tạo
*  SELECT vbeln, posnr, kwmeng, vrkme, vstel
*  INTO CORRESPONDING FIELDS OF TABLE @lt_vbap  " <<< THÊM VÀO ĐÂY
*  FROM vbap
*  WHERE vbeln = @iv_vbeln_so AND kwmeng > 0.
*  IF sy-subrc <> 0 OR lt_vbap IS INITIAL.
*    cs_header-message = |SO { iv_vbeln_so } created, but no items found for delivery.|.
*    RETURN.
*  ENDIF.
*
*  "--- Kiểm tra logic nhiều shipping point (GIỐNG HỆT CODE CŨ) ---
*  DATA(lt_vstel_check) = lt_vbap.
*  SORT lt_vstel_check BY vstel.
*  DELETE ADJACENT DUPLICATES FROM lt_vstel_check COMPARING vstel.
*  IF lines( lt_vstel_check ) > 1.
*    cs_header-status_code = 'W'. " SO Created, but Delivery Failed
*    cs_header-status_text = 'Warning'.
*    cs_header-message     = |SO { iv_vbeln_so } created, but ❌ Delivery failed: Multiple shipping points in SO.|.
*    " Ghi log lỗi Delivery
*    zcl_mass_so_logger_213=>log_action(
*        iv_reqid  = lv_log_reqid_param " <<< SỬA Ở ĐÂY
*        iv_action = 'CREATE_DELIVERY' iv_status = 'FAILED' iv_msgty  = 'E'
*        iv_msg    = |SO { iv_vbeln_so }: Multiple shipping points.|
*        iv_commit = abap_true ).
*    RETURN.
*  ENDIF.
*
*  " Lấy Shipping Point (giờ đã chắc chắn là duy nhất)
*  READ TABLE lt_vstel_check INTO DATA(ls_vstel_line) INDEX 1.
*  lv_ship_point = ls_vstel_line-vstel.
*  IF lv_ship_point IS INITIAL.
*     cs_header-status_code = 'W'.
*     cs_header-status_text = 'Warning'.
*     cs_header-message     = |SO { iv_vbeln_so } created, but ❌ Delivery failed: No Shipping Point found.|.
*     RETURN.
*  ENDIF.
*
*  "--- Lấy delivery date (GIỐNG HỆT CODE CŨ) ---
*  SELECT MIN( edatu ) INTO @lv_due_date
*    FROM vbep WHERE vbeln = @iv_vbeln_so.
*  IF lv_due_date IS INITIAL.
*    lv_due_date = sy-datum.
*  ENDIF.
*
*  "--- Build item table for BAPI (GIỐNG HỆT CODE CŨ) ---
*  LOOP AT lt_vbap INTO ls_vbap.
*    CLEAR ls_item.
*    ls_item-ref_doc    = ls_vbap-vbeln.
*    ls_item-ref_item   = ls_vbap-posnr.
*    ls_item-dlv_qty    = ls_vbap-kwmeng. " Delivery Qty = Order Qty
*    ls_item-sales_unit = ls_vbap-vrkme.
*    APPEND ls_item TO lt_items.
*  ENDLOOP.
*
*  "--- Call BAPI to create Delivery ---
*  CALL FUNCTION 'BAPI_OUTB_DELIVERY_CREATE_SLS'
*    EXPORTING
*      ship_point      = lv_ship_point
*      due_date        = lv_due_date
*    IMPORTING
*      delivery        = lv_delivery
*      num_deliveries  = lv_count
*    TABLES
*      sales_order_items = lt_items
*      return          = lt_return.
*
*  "--- Build message log
*  LOOP AT lt_return INTO ls_return WHERE message IS NOT INITIAL.
*    CONCATENATE lv_msg ls_return-message INTO lv_msg SEPARATED BY ' | '.
*  ENDLOOP.
*
*  IF lv_delivery IS NOT INITIAL.
*    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.
*    WAIT UP TO 1 SECONDS. " Giữ lại WAIT của bạn
*
*    cs_header-status_code = 'D'. " 'Delivered'
*    cs_header-status_text = 'Delivered'.
*    cs_header-message = |SO { iv_vbeln_so } created. ✅ Delivery { lv_delivery } created.|.
*
*    PERFORM save_delivery_to_ztable
*      USING iv_vbeln_so             " SO Number
*            lv_delivery             " Delivery Number
*            lv_ship_point
*            lv_due_date
*            cs_header-sales_org
*            cs_header-sales_channel
*            cs_header-sales_div
*            cs_header-sold_to_party
*            cs_header-sold_to_party " Assuming Ship-to = Sold-to
*            cs_header-cust_ref
*            lv_msg.
*
*    " Ghi log thành công Delivery
*    zcl_mass_so_logger_213=>log_action(
*        iv_reqid  = lv_log_reqid_param " <<< SỬA Ở ĐÂY
*        iv_action = 'CREATE_DELIVERY' iv_status = 'SUCCESS' iv_msgty  = 'S'
*        iv_msg    = |SO { iv_vbeln_so }: Delivery { lv_delivery } created.|
*        iv_commit = abap_true ).
*  ELSE.
*    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
*    cs_header-status_code = 'W'. " SO Created, but Delivery Failed
*    cs_header-status_text = 'Warning'.
*    IF lv_msg IS INITIAL.
*      lv_msg = |❌ Failed to create delivery for SO { iv_vbeln_so }.|.
*    ENDIF.
*    cs_header-message = |SO { iv_vbeln_so } created. { lv_msg }|.
*
*    " Ghi log lỗi Delivery
*    zcl_mass_so_logger_213=>log_action(
*        iv_reqid  = lv_log_reqid_param " <<< SỬA Ở ĐÂY
*        iv_action = 'CREATE_DELIVERY' iv_status = 'FAILED' iv_msgty  = 'E'
*        iv_msg    = |SO { iv_vbeln_so }: { lv_msg }|
*        iv_commit = abap_true ).
*  ENDIF.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form PERFORM_AUTO_DELIVERY (Updated for Staging Architecture)
*&---------------------------------------------------------------------*
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

*&---------------------------------------------------------------------*
*& Form PERFORM_AUTO_PICK_DELIVERY (Logic từ ZSD4_AUTO_PICKED)
*&---------------------------------------------------------------------*
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

  CLEAR gt_tracking.

  " 1. Chuẩn hóa input (thêm số 0 vào trước nếu cần)
  PERFORM normalize_search_inputs.

  "=========================================================
  " [MỚI] LOGIC TÌM NGƯỢC SO TỪ DELIVERY/BILLING
  "=========================================================
  DATA: lr_so_range TYPE RANGE OF vbak-vbeln,
        ls_so_range LIKE LINE OF lr_so_range.

  DATA: lv_search_active TYPE abap_bool.

  " A. Nếu user nhập Sales Order -> Thêm vào Range
  IF gv_vbeln IS NOT INITIAL.
    ls_so_range-sign   = 'I'.
    ls_so_range-option = 'EQ'.
    ls_so_range-low    = gv_vbeln.
    APPEND ls_so_range TO lr_so_range.
    lv_search_active = abap_true.
  ENDIF.

  " B. Nếu user nhập Delivery -> Tìm SO cha trong VBFA
  IF gv_deliv IS NOT INITIAL.
    lv_search_active = abap_true.
    " Thêm @ trước biến gv_deliv
    SELECT SINGLE vbelv INTO @ls_so_range-low
      FROM vbfa
      WHERE vbeln   = @gv_deliv
        AND vbtyp_v = 'C'. " C = Order

    IF sy-subrc = 0.
      ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'.
      APPEND ls_so_range TO lr_so_range.
    ENDIF.
  ENDIF.

  " C. Nếu user nhập Billing -> Tìm SO (có thể qua trung gian Delivery)
  IF gv_bill IS NOT INITIAL.
    lv_search_active = abap_true.
    DATA: lv_pre_doc TYPE vbeln_von,
          lv_cat     TYPE vbtyp.

    " Tìm cha trực tiếp của Billing (SỬA LỖI Ở ĐÂY: Thêm @ toàn bộ)
    SELECT SINGLE vbelv, vbtyp_v
      INTO (@lv_pre_doc, @lv_cat)
      FROM vbfa
      WHERE vbeln   = @gv_bill
        AND vbtyp_n = 'M'. " M = Invoice

    IF sy-subrc = 0.
      IF lv_cat = 'C'.
        " Cha là Order -> Thêm luôn
        ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = lv_pre_doc.
        APPEND ls_so_range TO lr_so_range.
      ELSEIF lv_cat = 'J'.
        " Cha là Delivery -> Tìm tiếp ông nội (Order)
        " (SỬA LỖI Ở ĐÂY: Thêm @ trước biến lv_pre_doc)
        SELECT SINGLE vbelv INTO @ls_so_range-low
          FROM vbfa
          WHERE vbeln   = @lv_pre_doc
            AND vbtyp_v = 'C'.
        IF sy-subrc = 0.
          ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'.
          APPEND ls_so_range TO lr_so_range.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  " [QUAN TRỌNG] Nếu có nhập search key (SO/Del/Bill) mà không tìm thấy SO nào
  " -> Thì gán giá trị 'DUMMY' để Query không ra kết quả (tránh việc Select All)
  IF lv_search_active = abap_true AND lr_so_range IS INITIAL.
     ls_so_range-sign = 'I'. ls_so_range-option = 'EQ'. ls_so_range-low = '0000000000'.
     APPEND ls_so_range TO lr_so_range.
  ENDIF.

  "=========================================================
  " 2. KHAI BÁO RANGE CHO 3 SALES ORG (Logic cũ)
  "=========================================================
  DATA: lr_vkorg_project TYPE RANGE OF vkorg.
  lr_vkorg_project = VALUE #( sign = 'I' option = 'EQ'
                             ( low = 'CNSG' ) ( low = 'CNHN' ) ( low = 'CNDN' ) ).

  "=========================================================
  " 3. XỬ LÝ BIẾN SEARCH INPUT KHÁC
  "=========================================================
  CONDENSE: gv_vkorg, gv_vtweg, gv_spart, gv_ernam.
  TRANSLATE: gv_vkorg TO UPPER CASE, gv_vtweg TO UPPER CASE,
             gv_spart TO UPPER CASE, gv_ernam TO UPPER CASE.
  DATA(lv_vtweg_pattern) = |%{ gv_vtweg }|.
  DATA(lv_spart_pattern) = |%{ gv_spart }|.

  "=========================================================
  " 4. SELECT DỮ LIỆU CHÍNH
  "=========================================================
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
    LEFT JOIN vbep ON vbep~vbeln = vbap~vbeln
                  AND vbep~posnr = vbap~posnr
   WHERE ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
     AND vbak~vkorg IN @lr_vkorg_project  " Lọc cứng dự án
     AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
     AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
     AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
     AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
     AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
     " --- Range SO ---
     AND vbak~vbeln IN @lr_so_range
    INTO CORRESPONDING FIELDS OF TABLE @gt_tracking.

  " Sắp xếp và xóa trùng
  SORT gt_tracking BY document_date DESCENDING sales_document.
  DELETE ADJACENT DUPLICATES FROM gt_tracking COMPARING sales_document.

  "=========================================================
  " 5. LOGIC CHI TIẾT TRONG LOOP (Tìm lại Deliv/Bill/FI để hiển thị)
  "=========================================================
  FIELD-SYMBOLS: <fs_tracking> TYPE ty_tracking.

  LOOP AT gt_tracking ASSIGNING <fs_tracking>.
    DATA ls_vbfa_del TYPE vbfa.

    " Clear dữ liệu cũ
    CLEAR: <fs_tracking>-delivery_document, <fs_tracking>-billing_document,
           <fs_tracking>-fi_doc_billing, <fs_tracking>-bill_doc_cancel,
           <fs_tracking>-fi_doc_cancel, <fs_tracking>-release_flag.

    " --- LOGIC PHÂN LOẠI SALES ORDER TYPE ---
    CASE <fs_tracking>-order_type.

      " NHÓM 1 & 2: CÓ DELIV (Standard & Return)
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        CLEAR ls_vbfa_del.
        DATA(lv_vbtyp_target) = COND vbtyp( WHEN <fs_tracking>-order_type = 'ZRET' THEN 'T' ELSE 'J' ).

        SELECT SINGLE vbeln, vbtyp_n
          FROM vbfa
          INTO CORRESPONDING FIELDS OF @ls_vbfa_del
          WHERE vbelv   = @<fs_tracking>-sales_document
            AND vbtyp_n = @lv_vbtyp_target. " J hoặc T

        IF sy-subrc = 0.
          <fs_tracking>-delivery_document = ls_vbfa_del-vbeln.

          " Tìm Billing từ Delivery
          SELECT SINGLE vbeln
            FROM vbfa
            INTO @<fs_tracking>-billing_document
            WHERE vbelv   = @<fs_tracking>-delivery_document
              AND vbtyp_n IN ('M', 'O', 'P'). " M: Invoice, O: Credit, P: Debit
        ENDIF.

      " NHÓM 3: KHÔNG DELIVERY (Service, Debit, Credit...)
      WHEN OTHERS.
        " Tìm Billing TRỰC TIẾP từ SO
        SELECT SINGLE vbeln
          FROM vbfa
          INTO @<fs_tracking>-billing_document
          WHERE vbelv   = @<fs_tracking>-sales_document
            AND vbtyp_n IN ('M', 'O', 'P').

    ENDCASE.

    " --- LOGIC TÌM FI DOCUMENT & CANCEL ---
    IF <fs_tracking>-billing_document IS NOT INITIAL.

      DATA: lv_bill_doc_canc TYPE vbrk-vbeln.
      CLEAR: lv_bill_doc_canc.

      " 1. Lấy FI Doc từ BKPF
      SELECT SINGLE belnr FROM bkpf INTO @<fs_tracking>-fi_doc_billing
        WHERE awtyp = 'VBRK' AND awkey = @<fs_tracking>-billing_document.

      " 2. Lấy Billing Cancelled (N <- M)
      SELECT SINGLE vbeln FROM vbfa INTO @lv_bill_doc_canc
        WHERE vbelv = @<fs_tracking>-billing_document
          AND vbtyp_v = 'M' AND vbtyp_n = 'N'.

      IF sy-subrc = 0 AND lv_bill_doc_canc IS NOT INITIAL.
        <fs_tracking>-bill_doc_cancel = lv_bill_doc_canc.
        " 3. Lấy FI Cancel
        SELECT SINGLE belnr FROM bkpf INTO @<fs_tracking>-fi_doc_cancel
          WHERE awtyp = 'VBRK' AND awkey = @lv_bill_doc_canc.
      ENDIF.

      " Logic Release Flag
      IF <fs_tracking>-fi_doc_billing IS INITIAL.
        <fs_tracking>-release_flag = '@5C@'. " Icon đỏ/vàng tùy hệ thống
      ENDIF.
    ENDIF.

  ENDLOOP.
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

    CLEAR: <fs_phase>-process_phase, <fs_phase>-phase_icon.

    "=========================================================
    " LOGIC XÁC ĐỊNH PHASE THEO NHÓM
    "=========================================================
    CASE <fs_phase>-order_type.

      "-------------------------------------------------------
      " NHÓM 1 & 2: CÓ DELIVERY (ZORR, ZBB, ZFOC, ZRET)
      "-------------------------------------------------------
      WHEN 'ZORR' OR 'ZBB' OR 'ZFOC' OR 'ZRET'.

        " Check xem đã có Billing chưa (Ưu tiên cao nhất)
        IF <fs_phase>-billing_document IS NOT INITIAL.
             " Đã có Billing -> Check FI
             IF <fs_phase>-fi_doc_billing IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.
                <fs_phase>-process_phase = 'FI Doc created'.
                <fs_phase>-phase_icon    = icon_payment.
             ELSE.
                <fs_phase>-process_phase = 'Billing created'.
                <fs_phase>-phase_icon    = ICON_WD_TEXT_VIEW.
             ENDIF.

        ELSE.
             " Chưa có Billing -> Check Delivery Status
             IF <fs_phase>-delivery_document IS NOT INITIAL.

                " Lấy Status PGI/PGR
                CLEAR lv_wbstk.
                SELECT SINGLE wbstk FROM likp INTO lv_wbstk
                 WHERE vbeln = <fs_phase>-delivery_document.

                " Phân biệt text cho Return và Standard
                IF <fs_phase>-order_type = 'ZRET'.
                   " --- Logic cho ZRET (Return) ---
                   IF lv_wbstk = 'C'.
                      <fs_phase>-process_phase = 'PGR Posted, ready Billing'.
                      <fs_phase>-phase_icon    = ICON_WD_TEXT_VIEW.
                   ELSE.
                      <fs_phase>-process_phase = 'Return Del created, ready PGR'.
                      <fs_phase>-phase_icon    = icon_delivery.
                   ENDIF.
                ELSE.
                   " --- Logic cho ZORR (Standard) ---
                   IF lv_wbstk = 'C'.
                      <fs_phase>-process_phase = 'PGI Posted, ready Billing'.
                      <fs_phase>-phase_icon    = ICON_WD_TEXT_VIEW.
                   ELSE.
                      <fs_phase>-process_phase = 'Delivery created, ready PGI'.
                      <fs_phase>-phase_icon    = icon_delivery.
                   ENDIF.
                ENDIF.

             ELSE.
                " Chưa có Delivery
                <fs_phase>-process_phase = 'Order created'.
                <fs_phase>-phase_icon    = icon_order.
             ENDIF.
        ENDIF.

      "-------------------------------------------------------
      " NHÓM 3: KHÔNG DELIVERY (ZDR, ZCRR, ZTP, ZSC, ZRAS)
      "-------------------------------------------------------
      WHEN OTHERS.

        " Nhóm này không quan tâm Delivery, check thẳng Billing
        IF <fs_phase>-billing_document IS NOT INITIAL.
             " Đã có Billing -> Check FI
             IF <fs_phase>-fi_doc_billing IS NOT INITIAL AND <fs_phase>-bill_doc_cancel IS INITIAL.
                <fs_phase>-process_phase = 'FI Doc created'.
                <fs_phase>-phase_icon    = icon_payment.
             ELSE.
                <fs_phase>-process_phase = 'Billing created'.
                <fs_phase>-phase_icon    = ICON_WD_TEXT_VIEW.
             ENDIF.
        ELSE.
             " Chưa có Billing -> Trạng thái chờ Billing ngay
             <fs_phase>-process_phase = 'Ready Billing'.
             <fs_phase>-phase_icon    = icon_order.
        ENDIF.

    ENDCASE.

  ENDLOOP.

ENDFORM.
FORM filter_process_phase.

  " 1. Nếu không lọc (chọn 'All') hoặc bảng ALV rỗng thì thoát
  IF cb_phase IS INITIAL OR cb_phase = 'ALL' OR gt_tracking IS INITIAL.
    EXIT.
  ENDIF.

  DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
  CLEAR lt_keep.

  " 2. Lọc dữ liệu
  LOOP AT gt_tracking INTO gs_tracking.

    CASE cb_phase.
      " --- Order Created ---
      WHEN 'ORD'.
        IF gs_tracking-process_phase = 'Order created'.
           APPEND gs_tracking TO lt_keep.
        ENDIF.

      " --- Delivery Created (Bắt cả Standard & Return) ---
      WHEN 'DEL'.
        " Sửa lỗi: So khớp chính xác chuỗi đã gán ở apply_phase_logic
        IF gs_tracking-process_phase = 'Delivery created, ready PGI'      " Standard
        OR gs_tracking-process_phase = 'Return Del created, ready PGR'.   " Return
           APPEND gs_tracking TO lt_keep.
        ENDIF.

      " --- PGI/PGR Posted (Sửa lỗi Case Sensitive & thiếu PGR) ---
      WHEN 'INV'.
        " Sửa lỗi: Chữ 'P' hoa và thêm trường hợp PGR
        IF gs_tracking-process_phase = 'PGI Posted, ready Billing'        " Standard
        OR gs_tracking-process_phase = 'PGR Posted, ready Billing'        " Return
        OR gs_tracking-process_phase = 'Billing created'.                 " Trường hợp cũ chưa có FI
           APPEND gs_tracking TO lt_keep.
        ENDIF.

      " --- Accounting / FI ---
      WHEN 'ACC'.
        " Logic: Lấy cả 'FI Doc created' VÀ trạng thái mới 'Ready for FI'
        IF gs_tracking-process_phase = 'FI Doc created'
        OR gs_tracking-process_phase = 'Billing created, ready for FI doc'. " <== Phase mới
           APPEND gs_tracking TO lt_keep.
        ENDIF.

      WHEN OTHERS.
        " Giữ lại tất cả nếu key không khớp logic nào (fail-safe)
        APPEND gs_tracking TO lt_keep.
    ENDCASE.

  ENDLOOP.

  " 3. Gán kết quả lọc vào bảng ALV
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

    " 2. Lấy các biến pattern
    DATA: lv_vtweg_pattern TYPE string,
          lv_spart_pattern TYPE string.
    lv_vtweg_pattern = |%{ gv_vtweg }|.
    lv_spart_pattern = |%{ gv_spart }|.

    CASE cb_ddsta.

      "=========================================================
      " LOGIC 'PGI' (S/4HANA)
      "=========================================================
      WHEN 'PGI'.
        DATA: lt_gi_posted TYPE HASHED TABLE OF vbak-vbeln
                           WITH UNIQUE KEY table_line.
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
          INNER JOIN likp ON likp~vbeln = vbfa~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa~vbtyp_n = 'J'
         AND likp~wbstk   = 'C'
         AND likp~vbtyp   = 'J'
          INTO TABLE @DATA(lt_gi_posted_temp).

        IF sy-subrc = 0.
          lt_gi_posted = lt_gi_posted_temp.
        ENDIF.

        IF lt_gi_posted IS NOT INITIAL.
          LOOP AT gt_tracking INTO gs_tracking.
            DATA(lv_vbeln_gi) = |{ gs_tracking-sales_document ALPHA = IN }|.
            READ TABLE lt_gi_posted WITH TABLE KEY table_line = lv_vbeln_gi TRANSPORTING NO FIELDS.
            IF sy-subrc = 0.
              APPEND gs_tracking TO lt_keep.
            ENDIF.
          ENDLOOP.
        ENDIF.

      "=========================================================
      " LOGIC 'GRP' (S/4HANA)
      "=========================================================
      WHEN 'GRP'.
        DATA: lt_gr_posted TYPE HASHED TABLE OF vbak-vbeln
                           WITH UNIQUE KEY table_line.
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
          INNER JOIN likp ON likp~vbeln = vbfa~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa~vbtyp_n = 'T' " Link là 1 Returns Delivery
         AND likp~wbstk   = 'C' " Đã GR (Completed)
         AND likp~vbtyp   = 'T' " Là 1 Returns Delivery
          INTO TABLE @DATA(lt_gr_posted_temp_grp).

        IF sy-subrc = 0.
          lt_gr_posted = lt_gr_posted_temp_grp.
        ENDIF.

        IF lt_gr_posted IS NOT INITIAL.
          LOOP AT gt_tracking INTO gs_tracking.
            DATA(lv_vbeln_gr) = |{ gs_tracking-sales_document ALPHA = IN }|.
            READ TABLE lt_gr_posted WITH TABLE KEY table_line = lv_vbeln_gr TRANSPORTING NO FIELDS.
            IF sy-subrc = 0.
              APPEND gs_tracking TO lt_keep.
            ENDIF.
          ENDLOOP.
        ENDIF.

    ENDCASE. " <== SỬA LỖI CÚ PHÁP: THÊM DÒNG NÀY

    " 3. Gán kết quả lọc (lt_keep) vào bảng ALV (gt_tracking)
    gt_tracking = lt_keep.

  ENDFORM.

  FORM filter_billing_status.

    " 1. Nếu không lọc (chọn 'All') hoặc bảng ALV rỗng thì thoát
    IF cb_bdsta IS INITIAL OR cb_bdsta = 'ALL' OR gt_tracking IS INITIAL.
      EXIT.
    ENDIF.

    DATA: lt_keep TYPE STANDARD TABLE OF ty_tracking.
    CLEAR lt_keep.

    " 2. Lấy các biến pattern
    DATA: lv_vtweg_pattern TYPE string,
          lv_spart_pattern TYPE string.
    lv_vtweg_pattern = |%{ gv_vtweg }|.
    lv_spart_pattern = |%{ gv_spart }|.

    " Bảng tạm
    DATA: lt_billing_so TYPE HASHED TABLE OF vbak-vbeln
                        WITH UNIQUE KEY table_line.
    DATA: lt_temp_so    TYPE STANDARD TABLE OF vbak-vbeln.


    CASE cb_bdsta.

      "=========================================================
      " LOGIC 'COMPLETED'
      "=========================================================
      WHEN 'COMP'.
        LOOP AT gt_tracking INTO gs_tracking
            WHERE process_phase = 'Accounting'.
          APPEND gs_tracking TO lt_keep.
        ENDLOOP.

      "=========================================================
      " LOGIC 'CANCELLED'
      "=========================================================
      WHEN 'CANC'.
        " Path 1: Lấy SO -> Delivery -> Billing (Đã Hủy)
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa AS vbfa_so ON vbfa_so~vbelv = vbak~vbeln
          INNER JOIN vbfa AS vbfa_del ON vbfa_del~vbelv = vbfa_so~vbeln
          INNER JOIN vbrk ON vbrk~vbeln = vbfa_del~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa_so~vbtyp_n  = 'J'
         AND vbfa_del~vbtyp_n = 'M'
         AND vbrk~fksto       = 'X'
        INTO TABLE @lt_temp_so.

        " Path 2: Lấy SO -> Billing (Đã Hủy)
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
          INNER JOIN vbrk ON vbrk~vbeln = vbfa~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa~vbtyp_n = 'M'
         AND vbrk~fksto   = 'X'
        APPENDING TABLE @lt_temp_so.

        "--- So khớp logic 'CANC' ---
        IF lt_temp_so IS NOT INITIAL.
          SORT lt_temp_so.
          DELETE ADJACENT DUPLICATES FROM lt_temp_so.
          lt_billing_so = lt_temp_so.

          LOOP AT gt_tracking INTO gs_tracking.
            DATA(lv_vbeln_bil) = |{ gs_tracking-sales_document ALPHA = IN }|.
            READ TABLE lt_billing_so WITH TABLE KEY table_line = lv_vbeln_bil TRANSPORTING NO FIELDS.
            IF sy-subrc = 0.
              APPEND gs_tracking TO lt_keep.
            ENDIF.
          ENDLOOP.
        ENDIF.

      "=========================================================
      " LOGIC 'OPEN'
      "=========================================================
      WHEN 'OPEN'.
        " 1. Lấy danh sách 'Cancelled' (giống hệt 'WHEN CANC')
        " Path 1:
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa AS vbfa_so ON vbfa_so~vbelv = vbak~vbeln
          INNER JOIN vbfa AS vbfa_del ON vbfa_del~vbelv = vbfa_so~vbeln
          INNER JOIN vbrk ON vbrk~vbeln = vbfa_del~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa_so~vbtyp_n  = 'J'
         AND vbfa_del~vbtyp_n = 'M'
         AND vbrk~fksto       = 'X'
        INTO TABLE @lt_temp_so.

        " Path 2:
        SELECT DISTINCT vbak~vbeln
          FROM vbak
          INNER JOIN vbfa ON vbfa~vbelv = vbak~vbeln
          INNER JOIN vbrk ON vbrk~vbeln = vbfa~vbeln
          WHERE
             ( @gv_kunnr IS INITIAL OR vbak~kunnr = @gv_kunnr )
         AND ( @gv_vkorg IS INITIAL OR vbak~vkorg = @gv_vkorg )
         AND ( @gv_vtweg IS INITIAL OR vbak~vtweg LIKE @lv_vtweg_pattern )
         AND ( @gv_spart IS INITIAL OR vbak~spart LIKE @lv_spart_pattern )
         AND ( @gv_doc_date IS INITIAL OR vbak~erdat = @gv_doc_date )
         AND ( @gv_ernam IS INITIAL OR vbak~ernam = @gv_ernam )
         AND vbfa~vbtyp_n = 'M'
         AND vbrk~fksto   = 'X'
        APPENDING TABLE @lt_temp_so.

        " 2. Chuyển danh sách 'Cancelled' sang Hashed Table
        IF lt_temp_so IS NOT INITIAL.
          SORT lt_temp_so.
          DELETE ADJACENT DUPLICATES FROM lt_temp_so.
          lt_billing_so = lt_temp_so. " (lt_billing_so giờ là bảng Hủy)
        ENDIF.

        " 3. Lọc ALV
        LOOP AT gt_tracking INTO gs_tracking
            WHERE process_phase = 'Invoice processing'.

          " Kiểm tra xem nó có nằm trong bảng Hủy không
          DATA(lv_vbeln_open) = |{ gs_tracking-sales_document ALPHA = IN }|.
          READ TABLE lt_billing_so WITH TABLE KEY table_line = lv_vbeln_open
                     TRANSPORTING NO FIELDS.

          IF sy-subrc <> 0.
            " KHÔNG tìm thấy trong bảng Hủy (sy-subrc = 4)
            " => Nó là 'Open'
            APPEND gs_tracking TO lt_keep.
          ENDIF.
        ENDLOOP.

    ENDCASE.

    " Gán kết quả (dù rỗng hay có) vào bảng ALV
    gt_tracking = lt_keep.

  ENDFORM.

  FORM filter_pricing_procedure.

    "=========================================================
    " SỬA LỖI GỐC RỄ:
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

  " =========================================================
  " === LOGIC MỚI: Tách Sales Area gộp ra 3 biến cũ ===
  " =========================================================
  IF gv_sarea IS NOT INITIAL.
    " 1. Xóa các ký tự phân cách nếu user nhập (ví dụ 1000/10/00 -> 1000 10 00)
    REPLACE ALL OCCURRENCES OF '/' IN gv_sarea WITH space.
    REPLACE ALL OCCURRENCES OF '-' IN gv_sarea WITH space.

    " 2. Tách chuỗi vào 3 biến dùng để query DB
    SPLIT gv_sarea AT space INTO gv_vkorg gv_vtweg gv_spart.

    " 3. Xóa khoảng trắng thừa
    CONDENSE: gv_vkorg, gv_vtweg, gv_spart.
  ENDIF.
  " =========================================================

  "👉 Chuẩn hóa Sold-to Party (Giữ nguyên code cũ)
  IF gv_kunnr IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = gv_kunnr
      IMPORTING output = gv_kunnr.
  ENDIF.

  "👉 Chuẩn hóa Sales Doc (Giữ nguyên code cũ)
  IF gv_vbeln IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = gv_vbeln
      IMPORTING output = gv_vbeln.
  ENDIF.

  " 👉 3. [THÊM MỚI] Chuẩn hóa Delivery Doc
  IF gv_deliv IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = gv_deliv IMPORTING output = gv_deliv.
  ENDIF.

  " 👉 4. [THÊM MỚI] Chuẩn hóa Billing Doc
  IF gv_bill IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = gv_bill IMPORTING output = gv_bill.
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
*& Sửa lỗi cú pháp: Cấu trúc PROTT dùng MSGID và MSGNO
*& Sửa lỗi đồng bộ: Dùng SET UPDATE TASK LOCAL
*&---------------------------------------------------------------------*
FORM process_post_goods_issue
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  " --- 1. Khai báo biến ---
  DATA: ls_vbkok      TYPE vbkok,
        lt_vbpok      TYPE TABLE OF vbpok,
        ls_vbpok      TYPE vbpok,
        lt_prot       TYPE TABLE OF prott,
        ls_prot       TYPE prott,
        lv_vbeln      TYPE likp-vbeln,
        lt_lips       TYPE TABLE OF lipsvb,
        lv_vbeln_char(10) TYPE c.

  DATA: lv_full_message TYPE string.
  DATA: lv_subrc_char(4) TYPE c.
  DATA: lv_fm_subrc     TYPE sy-subrc.

  " 1. Lấy số delivery
  lv_vbeln = is_tracking_line-delivery_document.
  CLEAR cs_tracking_line-error_msg.

  IF lv_vbeln IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: Dòng này không có Delivery Document.'.
    EXIT.
  ENDIF.

  " 2. CHUẨN BỊ DỮ LIỆU
  " 2a. Lấy tất cả item của Delivery
  SELECT *
    FROM lips
    INTO TABLE @lt_lips
    WHERE vbeln = @lv_vbeln.
  IF sy-subrc <> 0 OR lt_lips IS INITIAL.
    cs_tracking_line-error_msg = 'LỖI: Không tìm thấy item (LIPS) cho Delivery.'.
    EXIT.
  ENDIF.

  " 2b. Chuẩn bị Header (VBKOK)
  ls_vbkok-vbeln_vl   = lv_vbeln.
  ls_vbkok-wabuc      = 'X'.
  ls_vbkok-wadat_ist  = sy-datum.

  " 2c. Chuẩn bị Items (VBPOK)
  CLEAR lt_vbpok.
  LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_lips>).
    CLEAR ls_vbpok.
    ls_vbpok-vbeln_vl = <fs_lips>-vbeln.
    ls_vbpok-posnr_vl = <fs_lips>-posnr.
    ls_vbpok-lfimg    = <fs_lips>-lfimg.
    ls_vbpok-lgmng    = <fs_lips>-lgmng.
    APPEND ls_vbpok TO lt_vbpok.
  ENDLOOP.

  "=========================================================
  "=== 3. (SỬA LỖI ĐỒNG BỘ) Ép FM chạy Đồng bộ
  "=========================================================
  SET UPDATE TASK LOCAL.
  "=========================================================

  " 4. GỌI FM CHUẨN 'WS_DELIVERY_UPDATE_2'
  CALL FUNCTION 'WS_DELIVERY_UPDATE_2'
    EXPORTING
      vbkok_wa      = ls_vbkok
      synchron      = 'X'
      commit        = ' '
      delivery      = lv_vbeln
    TABLES
      vbpok_tab     = lt_vbpok
      prot          = lt_prot
    EXCEPTIONS
      error_message = 1
      OTHERS        = 2.

  lv_fm_subrc = sy-subrc.

  " 5. KIỂM TRA BẢNG LỖI (PROT) TRƯỚC
  READ TABLE lt_prot INTO ls_prot WITH KEY msgty = 'A'.
  IF sy-subrc <> 0.
    READ TABLE lt_prot INTO ls_prot WITH KEY msgty = 'E'.
  ENDIF.

  IF sy-subrc = 0 OR lv_fm_subrc <> 0.
    " LỖI (Hoặc tìm thấy lỗi 'A'/'E' TRONG BẢNG PROT,
    "      hoặc FM bị DUMP (sy-subrc <> 0))
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    IF sy-subrc = 0.
      " Lỗi do nghiệp vụ (đã tìm thấy 'A'/'E' trong PROT)
      "=========================================================
      "=== SỬA LỖI CÚ PHÁP: Dùng MSGID và MSGNO cho PROTT
      "=========================================================
      MESSAGE ID ls_prot-msgid TYPE 'S' NUMBER ls_prot-msgno
         WITH ls_prot-msgv1 ls_prot-msgv2 ls_prot-msgv3 ls_prot-msgv4
         INTO lv_full_message.

      CONCATENATE 'LỖI (' ls_prot-msgid ' ' ls_prot-msgno '): ' lv_full_message
             INTO cs_tracking_line-error_msg SEPARATED BY space.
      "=========================================================
    ELSE.
      " Lỗi do FM DUMP (ví dụ, sy-subrc = 1 hoặc 2)
      WRITE lv_fm_subrc TO lv_subrc_char.
      CONDENSE lv_subrc_char.
      CONCATENATE 'LỖI: Post PGI thất bại (sy-subrc = ' lv_subrc_char ').'
             INTO cs_tracking_line-error_msg SEPARATED BY space.
    ENDIF.
  ELSE.
    " THÀNH CÔNG (Không có lỗi 'A'/'E' VÀ sy-subrc = 0)
    "=========================================================
    "=== (SỬA LỖI ĐỒNG BỘ) Dùng COMMIT WORK AND WAIT
    "=========================================================
    COMMIT WORK AND WAIT.
    "=========================================================

    WRITE lv_vbeln TO lv_vbeln_char.
    CONDENSE lv_vbeln_char.
    CONCATENATE 'PGI cho Delivery ' lv_vbeln_char ' thành công.'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form PROCESS_CREATE_BILLING
*& Sửa lỗi: 1. Dùng SET UPDATE TASK LOCAL để chạy đồng bộ.
*&         2. Sửa logic: Đọc message 'A'/'E' từ BAPIRET2.
*&         3. Sửa lỗi cú pháp: Dùng CONCATENATE.
*&---------------------------------------------------------------------*
FORM process_create_billing
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  DATA: lt_billingdata TYPE TABLE OF bapivbrk,
        ls_billingdata TYPE bapivbrk,
        lt_return      TYPE TABLE OF bapiret2,
        ls_return      TYPE bapiret2,
        lt_success     TYPE TABLE OF bapivbrksuccess,
        ls_success     TYPE bapivbrksuccess,
        lv_billdoc     TYPE vbrk-vbeln.
  DATA: lv_vbeln_alpha TYPE vbeln_vl.
  DATA: lt_lips TYPE STANDARD TABLE OF lips.

  " 1. Lấy số delivery
  CLEAR cs_tracking_line-error_msg.
  lv_vbeln_alpha = is_tracking_line-delivery_document.

  IF lv_vbeln_alpha IS INITIAL.
    cs_tracking_line-error_msg = 'ERROR: Dòng này không có Delivery Document.'.
    EXIT.
  ENDIF.

  " 2. Lấy các item từ LIPS
  SELECT *
    FROM lips
    INTO TABLE @lt_lips
    WHERE vbeln = @lv_vbeln_alpha.
  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = 'LỖI: Không tìm thấy item (LIPS) cho Delivery.'.
    EXIT.
  ENDIF.

  LOOP AT lt_lips ASSIGNING FIELD-SYMBOL(<fs_lips>).
    CLEAR ls_billingdata.
    ls_billingdata-ref_doc    = <fs_lips>-vbeln.
    ls_billingdata-ref_item   = <fs_lips>-posnr.
    ls_billingdata-doc_type   = 'ZSV'.
    ls_billingdata-ordbilltyp = 'F2'.
    ls_billingdata-ref_doc_ca = 'J'.
    APPEND ls_billingdata TO lt_billingdata.
  ENDLOOP.

  IF lt_billingdata IS INITIAL.
    cs_tracking_line-error_msg = 'Không tìm thấy item nào từ Delivery để tạo billing.'.
    EXIT.
  ENDIF.

  "=========================================================
  "=== 3. (SỬA LỖI ĐỒNG BỘ) Ép BAPI chạy Đồng bộ
  "=========================================================
  SET UPDATE TASK LOCAL.
  "=========================================================

  " 4. Gọi BAPI tạo Billing
  CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
    EXPORTING
      testrun       = abap_false
      posting       = abap_false
    TABLES
      billingdatain = lt_billingdata
      success       = lt_success
      return        = lt_return.

  " 5. Xử lý kết quả (Sửa logic)
  READ TABLE lt_return INTO ls_return WITH KEY type = 'A'.
  IF sy-subrc <> 0.
    READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
  ENDIF.

  IF sy-subrc = 0.
    " Lỗi
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    CONCATENATE 'LỖI (' ls_return-id ' ' ls_return-number '): ' ls_return-message
           INTO cs_tracking_line-error_msg SEPARATED BY space.
  ELSE.
    " Thành công
    "=========================================================
    "=== (SỬA LỖI ĐỒNG BỘ) Dùng COMMIT WORK AND WAIT
    "=========================================================
    COMMIT WORK AND WAIT.
    "=========================================================

    READ TABLE lt_success INTO ls_success INDEX 1.
    lv_billdoc = ls_success-bill_doc.

    CONCATENATE 'Billing ' lv_billdoc ' tạo thành công.'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
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

  " --- 1. Khai báo biến ---
  DATA: lt_mesg  TYPE STANDARD TABLE OF mesg,
        ls_mesg  TYPE mesg,
        lv_wbstk TYPE likp-wbstk,
        lv_subrc TYPE sy-subrc.
  DATA: lv_vbtyp TYPE likp-vbtyp.
  DATA: lv_delivery     TYPE vbeln_vl,
        lv_full_message TYPE string.
  DATA: lv_subrc_char(4) TYPE c.

  "=========================================================
  "=== SỬA LỖI GỐC RỄ (FIX STALE DATA & MEMORY)
  "=========================================================
  " 1. Xóa message cũ
  CLEAR cs_tracking_line-error_msg.

  " 2. Lấy Delivery & Convert
  lv_delivery = is_tracking_line-delivery_document.
  IF lv_delivery IS INITIAL.
    cs_tracking_line-error_msg = 'LỖI: Không có Delivery Document để Reverse.'.
    EXIT.
  ENDIF.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING input  = lv_delivery
    IMPORTING output = lv_delivery.

  "👉 THÊM MỚI: Xóa Buffer DB để đảm bảo đọc dữ liệu mới nhất
  CALL FUNCTION 'BUFFER_REFRESH_ALL'.

  "👉 THÊM MỚI: Xóa Global Memory của Function Group Delivery (Quan trọng nhất)
  " Nếu không có dòng này, hệ thống vẫn 'nhớ' Delivery đang có Billing
  CALL FUNCTION 'LE_DELIVERY_REFRESH_BUFFER'.

  "👉 THÊM MỚI: Chờ 1 giây để bảng VBFA cập nhật xong trạng thái Hủy Billing
  WAIT UP TO 1 SECONDS.
  "=========================================================

  " 3. CHECK 1: Đã PGI chưa?
  SELECT SINGLE wbstk
    FROM likp
    WHERE vbeln = @lv_delivery
    INTO @lv_wbstk
    BYPASSING BUFFER.

  IF lv_wbstk <> 'C'.
    cs_tracking_line-error_msg = 'LỖI: Delivery chưa PGI (WBSTK <> C).'.
    EXIT.
  ENDIF.

  " 4. CHECK 2: Đã Billing chưa? (Kiểm tra lại VBFA mới nhất)
  SELECT vbeln
    FROM vbfa
    WHERE vbelv   = @lv_delivery
      AND vbtyp_n = 'M'
    INTO TABLE @DATA(lt_bills)
    BYPASSING BUFFER.

  IF sy-subrc = 0.
    LOOP AT lt_bills ASSIGNING FIELD-SYMBOL(<fs_bill>).
      " Kiểm tra xem Bill này có còn Active không (FKSTO <> X)
      SELECT SINGLE vbeln
        FROM vbrk
        WHERE vbeln = @<fs_bill>-vbeln
          AND fksto <> 'X'
        INTO @DATA(lv_active_bill)
        BYPASSING BUFFER.

      IF sy-subrc = 0.
        CONCATENATE 'LỖI: Phải Hủy Billing Doc ' lv_active_bill ' trước khi Reverse PGI.'
               INTO cs_tracking_line-error_msg SEPARATED BY space.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDIF.

  " 4b. Lấy VBTYP thực tế
  SELECT SINGLE vbtyp
    FROM likp
    WHERE vbeln = @lv_delivery
    INTO @lv_vbtyp
    BYPASSING BUFFER.

  IF sy-subrc <> 0.
    lv_vbtyp = 'J'.
  ENDIF.

  " 5. Ép FM chạy Đồng bộ
  SET UPDATE TASK LOCAL.

  " 6. HÀNH ĐỘNG: Dùng FM 'WS_REVERSE_GOODS_ISSUE'
  CALL FUNCTION 'WS_REVERSE_GOODS_ISSUE'
    EXPORTING
      i_vbeln               = lv_delivery
      i_budat               = sy-datum
      i_tcode               = 'VL09'
      i_vbtyp               = lv_vbtyp
    TABLES
      t_mesg                = lt_mesg
    EXCEPTIONS
      error_reverse_posting = 1
      OTHERS                = 2.

  " 7. Xử lý kết quả
  lv_subrc = sy-subrc.

  IF lv_subrc = 0.
    COMMIT WORK AND WAIT.
    CONCATENATE 'Reverse PGI cho Delivery ' lv_delivery ' thành công.'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    READ TABLE lt_mesg INTO ls_mesg WITH KEY MSGTY = 'A'.
    IF sy-subrc <> 0.
      READ TABLE lt_mesg INTO ls_mesg WITH KEY MSGTY = 'E'.
    ENDIF.

    IF sy-subrc = 0.
      MESSAGE ID ls_mesg-ARBGB TYPE 'S' NUMBER ls_mesg-TXTNR
              WITH ls_mesg-MSGV1 ls_mesg-MSGV2 ls_mesg-MSGV3 ls_mesg-MSGV4
              INTO lv_full_message.
      CONCATENATE 'LỖI (' ls_mesg-ARBGB ' ' ls_mesg-TXTNR '): ' lv_full_message
             INTO cs_tracking_line-error_msg.
    ELSE.
      WRITE lv_subrc TO lv_subrc_char.
      CONDENSE lv_subrc_char.
      CONCATENATE 'LỖI: Reverse PGI thất bại (sy-subrc = ' lv_subrc_char '). Không có message chi tiết.'
             INTO cs_tracking_line-error_msg SEPARATED BY space.
    ENDIF.
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
        lv_fksto   TYPE vbrk-fksto.
  DATA: lt_success TYPE STANDARD TABLE OF bapivbrksuccess.

  " --- Biến tạm ---
  DATA: lv_billing    TYPE vbeln_vf.
  DATA: lv_cancel_doc TYPE vbeln_vf.

  " 1. Xóa message cũ
  CLEAR cs_tracking_line-error_msg.

  " 2. Lấy số Billing
  lv_billing = is_tracking_line-billing_document.
  IF lv_billing IS INITIAL.
    cs_tracking_line-error_msg = 'LỖI: Không có Billing Document để Hủy.'.
    EXIT.
  ENDIF.

  " 3. CHECK: Đã Hủy chưa?
  SELECT SINGLE fksto
    FROM vbrk
    WHERE vbeln = @lv_billing
    INTO @lv_fksto.

  IF sy-subrc <> 0.
    CONCATENATE 'LỖI: Không tìm thấy Billing Doc ' lv_billing ' trong VBRK.'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
    EXIT.
  ENDIF.

  IF lv_fksto = 'X'.
    CONCATENATE 'LỖI: Billing Doc ' lv_billing ' đã được Hủy trước đó.'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
    EXIT.
  ENDIF.

  "=========================================================
  "=== 4. Ép BAPI chạy Đồng bộ (Synchronous Update)
  "=========================================================
  SET UPDATE TASK LOCAL.

  " 5. HÀNH ĐỘNG: Gọi BAPI Hủy
  CALL FUNCTION 'BAPI_BILLINGDOC_CANCEL1'
    EXPORTING
      billingdocument = lv_billing
    TABLES
      return          = lt_ret
      success         = lt_success.

  " 6. Xử lý kết quả
  READ TABLE lt_ret INTO ls_ret WITH KEY type = 'A'.
  IF sy-subrc <> 0.
    READ TABLE lt_ret INTO ls_ret WITH KEY type = 'E'.
  ENDIF.

  IF sy-subrc = 0.
    " Lỗi
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    CONCATENATE 'LỖI (' ls_ret-id ' ' ls_ret-number '): ' ls_ret-message
           INTO cs_tracking_line-error_msg SEPARATED BY space.
  ELSE.
    " Thành công
    "=========================================================
    "=== (QUAN TRỌNG) Commit và Giải phóng khóa
    "=========================================================
    COMMIT WORK AND WAIT.

    "👉 THÊM MỚI: Giải phóng toàn bộ khóa để bước Reverse PGI không bị Lock
    CALL FUNCTION 'DEQUEUE_ALL'.
    "=========================================================

    " Lấy số chứng từ hủy
    READ TABLE lt_ret INTO ls_ret WITH KEY type = 'S'.
    IF sy-subrc = 0.
      lv_cancel_doc = ls_ret-message_v1.
    ENDIF.

    CONCATENATE 'Hủy Billing thành công (Doc mới: ' lv_cancel_doc ').'
           INTO cs_tracking_line-error_msg SEPARATED BY space.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_RELEASE_TO_ACCOUNT
*& Xử lý logic cho 1 DÒNG (được gọi từ PAI)
*& (ĐÃ SỬA LỖI DUMP 'CONFLICT_LENG' - Tham số XVBRK)
*&---------------------------------------------------------------------*
FORM process_release_to_account
  USING
    is_tracking_line TYPE ty_tracking
  CHANGING
    cs_tracking_line TYPE ty_tracking.

  DATA: lv_bill_doc     TYPE vbrk-vbeln,
        lv_subrc_check  TYPE sy-subrc,
        ls_vbrk_wa      TYPE vbrk.

  "===============================================
  "=== KHAI BÁO BẢNG (VỚI KIỂU DỮ LIỆU CHÍNH XÁC TỪ FM)
  "===============================================
  DATA:
    lt_vbrk_in  TYPE STANDARD TABLE OF vbrk,     " Dùng cho IT_VBRK
    " --- SỬA LỖI DUMP (XVBRK): ---
    lt_vbrk_out TYPE STANDARD TABLE OF vbrkvb,  " Dùng cho XVBRK (Kiểu đúng là VBRKVB)
    " --- KẾT THÚC SỬA LỖI ---
    lt_xkomfk   TYPE STANDARD TABLE OF komfk,
    lt_xkomv    TYPE STANDARD TABLE OF komv,
    lt_xthead   TYPE STANDARD TABLE OF theadvb,
    lt_xvbfs    TYPE STANDARD TABLE OF vbfs,
    lt_xvbpa    TYPE STANDARD TABLE OF vbpavb,
    lt_xvbrp    TYPE STANDARD TABLE OF vbrpvb,
    lt_xvbrl    TYPE STANDARD TABLE OF vbrlvb,
    lt_xvbss    TYPE STANDARD TABLE OF vbss.
  "===============================================
" 1. Xóa bộ đệm bảng (DB Buffer)
  CALL FUNCTION 'BUFFER_REFRESH_ALL'.

  "👉 2. QUAN TRỌNG NHẤT: Xóa bộ nhớ của Function Group Delivery (Global Memory)
  " Hàm này bắt buộc hệ thống quên các thông tin Delivery đã load trước đó
  CALL FUNCTION 'LE_DELIVERY_REFRESH_BUFFER'.

  "👉 3. Thêm Wait nhỏ để đảm bảo VBFA (Doc Flow) được DB cập nhật xong từ bước Cancel Bill
  WAIT UP TO 1 SECONDS.
  " 1. Xóa message lỗi cũ
  CLEAR cs_tracking_line-error_msg.

  " 2. Kiểm tra xem dòng này có Bill Doc và lá cờ không
  lv_bill_doc = is_tracking_line-billing_document.
  IF lv_bill_doc IS INITIAL OR is_tracking_line-release_flag IS INITIAL.
    " Bỏ qua nếu không có lá cờ (không cần release)
    EXIT.
  ENDIF.

  " 3. Ép chạy đồng bộ (Synchronous)
  SET UPDATE TASK LOCAL.

  REFRESH: lt_vbrk_in, lt_vbrk_out, lt_xkomfk, lt_xkomv,
           lt_xthead, lt_xvbfs, lt_xvbpa, lt_xvbrp, lt_xvbrl, lt_xvbss.
  CLEAR: ls_vbrk_wa.

  " 4. Chuẩn bị dữ liệu cho FM (chỉ 1 dòng)
  SELECT SINGLE *
    FROM vbrk
    INTO ls_vbrk_wa
    WHERE vbeln = lv_bill_doc.

  IF sy-subrc <> 0.
    cs_tracking_line-error_msg = 'LỖI: Không đọc được VBRK cho Bill Doc.'.
    EXIT.
  ENDIF.

  APPEND ls_vbrk_wa TO lt_vbrk_in.
  " (Bảng lt_vbrk_out được truyền vào rỗng để nhận kết quả)

  " 5. Gọi FM (với các kiểu bảng đã khai báo đúng)
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
      xvbrk        = lt_vbrk_out   " <== Bây giờ sẽ hết lỗi
      xvbrp        = lt_xvbrp
      xvbrl        = lt_xvbrl
      xvbss        = lt_xvbss.

  lv_subrc_check = sy-subrc.

  " 6. Kiểm tra kết quả
  READ TABLE lt_xvbfs WITH KEY msgty = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0 OR lv_subrc_check <> 0.
    " Lỗi
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    cs_tracking_line-error_msg = 'Lỗi Release. Kiểm tra trong VF02/VFX3.'.
  ELSE.
    " Thành công
    COMMIT WORK AND WAIT.
    cs_tracking_line-error_msg = 'Released to Accounting thành công!'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SETUP_JOB_SCHEDULE
*& Logic: Tính UTC + Tạo Spool (Kết quả in) cho Job Background
*&---------------------------------------------------------------------*
FORM setup_job_schedule.

  DATA: lv_start_date TYPE sy-datum,
        lv_start_time TYPE sy-uzeit,
        lv_jobcount   TYPE tbtcjob-jobcount.
  DATA: lt_fields TYPE TABLE OF sval,
        ls_field  TYPE sval,
        lv_rc     TYPE c.

*   --- 1. Biến xử lý thời gian (UTC) ---
  DATA: lv_tstmp_input TYPE timestamp,
        lv_tstmp_utc   TYPE timestamp,
        lv_tstmp_temp  TYPE timestamp,
        lv_date_server TYPE sy-datum,
        lv_time_server TYPE sy-uzeit.
  CONSTANTS: lc_seconds_vn_offset TYPE p VALUE 25200.

*   --- 2. Biến xử lý Spool (QUAN TRỌNG) ---
  DATA: ls_pri_params TYPE pri_params,
        lv_valid_pri  TYPE c.

*   =======================================================
*   PHẦN 1: TÍNH TOÁN & POPUP (Giữ nguyên)
*   =======================================================
  GET TIME STAMP FIELD lv_tstmp_utc.

  TRY.
      CALL METHOD cl_abap_tstmp=>add
        EXPORTING tstmp = lv_tstmp_utc secs = lc_seconds_vn_offset
        RECEIVING r_tstmp = lv_tstmp_temp.
    CATCH cx_root.
      lv_tstmp_temp = lv_tstmp_utc.
  ENDTRY.

  CONVERT TIME STAMP lv_tstmp_temp TIME ZONE 'UTC'
          INTO DATE lv_start_date TIME lv_start_time.
  lv_start_date = lv_start_date + 1.

  CLEAR: ls_field, lt_fields.
  ls_field-tabname = 'VBAK'. ls_field-fieldname = 'ERDAT'.
  ls_field-fieldtext = 'Ngày chạy (Giờ VN)'. ls_field-value = lv_start_date.
  APPEND ls_field TO lt_fields.

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING popup_title = 'Lên lịch Job (Có Spool)'
    IMPORTING returncode = lv_rc
    TABLES fields = lt_fields.

  IF lv_rc = 'A' OR sy-subrc <> 0. MESSAGE 'Đã hủy.' TYPE 'S'. RETURN. ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 1.
  lv_start_date = ls_field-value.
  lv_start_time = '000015'.

*   =======================================================
*   PHẦN 2: QUY ĐỔI GIỜ (Giữ nguyên)
*   =======================================================
  CONVERT DATE lv_start_date TIME lv_start_time
          INTO TIME STAMP lv_tstmp_input TIME ZONE 'UTC'.

  DATA: lv_seconds_minus TYPE p.
  lv_seconds_minus = 0 - lc_seconds_vn_offset.

  TRY.
      CALL METHOD cl_abap_tstmp=>add
        EXPORTING tstmp = lv_tstmp_input secs = lv_seconds_minus
        RECEIVING r_tstmp = lv_tstmp_utc.
    CATCH cx_root.
  ENDTRY.

  CONVERT TIME STAMP lv_tstmp_utc TIME ZONE sy-zonlo
          INTO DATE lv_date_server TIME lv_time_server.

*   =======================================================
*   PHẦN 3: CẤU HÌNH SPOOL (ĐÂY LÀ PHẦN BẠN ĐANG THIẾU)
*   =======================================================
  CALL FUNCTION 'GET_PRINT_PARAMETERS'
    EXPORTING
      no_dialog      = 'X'
      mode           = 'CURRENT'
      destination    = 'LP01'    " <== Bắt buộc có máy in ảo này
      line_count     = 65
      line_size      = 255       " Khổ rộng để in không bị cắt
      expiration     = 1
      release        = ' '       " Chỉ lưu Spool, không in ra giấy
      new_list_id    = 'X'
    IMPORTING
      out_parameters = ls_pri_params
      valid          = lv_valid_pri
    EXCEPTIONS OTHERS = 4.

  IF sy-subrc <> 0 OR lv_valid_pri <> 'X'.
    MESSAGE 'Lỗi: Không lấy được tham số in (Spool).' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*   =======================================================
*   PHẦN 4: SUBMIT JOB
*   =======================================================
  PERFORM delete_existing_released_job USING gv_jobname.

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING jobname = gv_jobname
    IMPORTING jobcount = lv_jobcount.

*   --- QUAN TRỌNG: TRUYỀN THAM SỐ IN VÀO ĐÂY ---
  CALL FUNCTION 'JOB_SUBMIT'
    EXPORTING
      jobname    = gv_jobname
      jobcount   = lv_jobcount
      report     = 'ZSD4_AUTO_DELIVERY_JOB'
      authcknam  = sy-uname
      priparams  = ls_pri_params   " <== Dòng này tạo ra Spool List
    EXCEPTIONS OTHERS = 1.

  IF sy-subrc <> 0. MESSAGE 'Lỗi Job_Submit' TYPE 'S'. RETURN. ENDIF.

  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobname   = gv_jobname
      jobcount  = lv_jobcount
      sdlstrtdt = lv_date_server
      sdlstrttm = lv_time_server
      prddays   = 1
    EXCEPTIONS OTHERS = 1.

  IF sy-subrc = 0.
    MESSAGE |Đã lên lịch & tạo Spool. (Server Time: { lv_time_server })| TYPE 'S'.
  ELSE.
    MESSAGE 'Lỗi Job_Close' TYPE 'S'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DELETE_EXISTING_RELEASED_JOB
*& Mục đích: Tìm và xóa các Job cũ đã lên lịch (trạng thái Released)
*& để tránh việc tạo trùng lặp nhiều Job chạy cùng lúc.
*&---------------------------------------------------------------------*
FORM delete_existing_released_job USING iv_jobname TYPE tbtcjob-jobname.

  DATA: lt_joblist TYPE TABLE OF bapixmjobs.
  DATA: ls_return_select TYPE bapiret2.
  DATA: ls_return_delete TYPE bapiret2.

  " 1. Chuẩn bị tham số tìm kiếm
  DATA: ls_job_param TYPE bapixmjsel.
  CLEAR ls_job_param.
  ls_job_param-jobname  = iv_jobname.
  ls_job_param-username = '*'.
  ls_job_param-schedul  = 'X'. " Chỉ lọc các Job đang chờ chạy (Released)

  DATA: lv_ext_user TYPE bapixmlogr-extuser.
  lv_ext_user = sy-uname.

  " 2. Tìm kiếm Job cũ
  CALL FUNCTION 'BAPI_XBP_JOB_SELECT'
    EXPORTING
      job_select_param   = ls_job_param
      external_user_name = lv_ext_user
    IMPORTING
      return             = ls_return_select
    TABLES
      selected_jobs      = lt_joblist.

  " 3. Nếu tìm thấy thì xóa
  LOOP AT lt_joblist ASSIGNING FIELD-SYMBOL(<fs_job>).
    CLEAR ls_return_delete.

    CALL FUNCTION 'BAPI_XBP_JOB_DELETE'
      EXPORTING
        jobname            = <fs_job>-jobname
        jobcount           = <fs_job>-jobcount
        external_user_name = lv_ext_user
      IMPORTING
        return             = ls_return_delete.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SHOW_JOB_MONITOR_POPUP
*& Mục đích: Hiển thị lịch sử chạy Job (Đọc từ JOB LOG - SM37)
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
           message     TYPE string,
           jobcount    TYPE tbtcjob-jobcount,
         END OF ty_job_report.

  DATA: lt_report TYPE TABLE OF ty_job_report,
        ls_report TYPE ty_job_report,
        lt_tbtco  TYPE TABLE OF tbtco.

  " --- Biến để đọc Job Log ---
  DATA: lt_joblog TYPE TABLE OF tbtc5,
        ls_joblog TYPE tbtc5.

  " ALV Objects
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_col     TYPE REF TO cl_salv_column.

  " 1. Lấy 20 Job gần nhất
  SELECT * FROM tbtco
    INTO TABLE lt_tbtco
    UP TO 20 ROWS
    WHERE jobname = 'Z_AUTO_DELIV_PROTOTYPE'
    ORDER BY sdlstrtdt DESCENDING sdlstrttm DESCENDING.

  IF lt_tbtco IS INITIAL.
    MESSAGE 'Chưa có lịch sử chạy Job nào.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 2. Xử lý từng dòng Job
  LOOP AT lt_tbtco INTO DATA(ls_job).
    CLEAR ls_report.
    ls_report-jobcount = ls_job-jobcount.

    " --- Phân loại trạng thái ---
    CASE ls_job-status.
      WHEN 'F'. " Finished
        ls_report-status_icon = '@5B@'. " Green
        ls_report-status_text = 'Finished'.
        ls_report-run_date    = ls_job-strtdate.
        ls_report-run_time    = ls_job-strttime.

        " ========================================================
        " [FIX LỖI DUMP] SỬA TÊN THAM SỐ TABLES
        " ========================================================
        REFRESH lt_joblog.
        CALL FUNCTION 'BP_JOBLOG_READ'
          EXPORTING
            jobname   = ls_job-jobname
            jobcount  = ls_job-jobcount
          TABLES
            joblogtbl = lt_joblog  " <== ĐÃ SỬA: joblog -> joblogtbl
          EXCEPTIONS
            cant_read_joblog = 1
            jobcount_missing = 2
            jobname_missing  = 3
            joblog_is_empty  = 4
            OTHERS           = 5.

        IF sy-subrc = 0.
          " Quét nội dung Log
          LOOP AT lt_joblog INTO ls_joblog.

            " 1. Đếm thành công (Tìm chữ 'THÀNH CÔNG')
            IF ls_joblog-text CS 'THÀNH CÔNG'.
              ADD 1 TO ls_report-success_cnt.
            ENDIF.

            " 2. Đếm lỗi (Tìm chữ 'LỖI')
            IF ls_joblog-text CS 'LỖI'.
              ADD 1 TO ls_report-error_cnt.
            ENDIF.

            " 3. Lấy số lượng tìm thấy (Tìm chữ 'Tìm thấy')
            IF ls_joblog-text CS 'Tìm thấy'.
              " Format: 'Tìm thấy 5 items...' -> Lấy số 5
              FIND REGEX '(\d+)' IN ls_joblog-text SUBMATCHES DATA(lv_num).
              ls_report-items_found = lv_num.
            ENDIF.

            " 4. Lấy ghi chú lỗi cuối cùng (nếu có)
            IF ls_report-message IS INITIAL AND ls_joblog-text CS 'LỖI'.
               ls_report-message = ls_joblog-text.
            ENDIF.
          ENDLOOP.
        ENDIF.
        " ========================================================

      WHEN 'R'. " Released
        ls_report-status_icon = '@5C@'. " Yellow
        ls_report-status_text = 'Planned'.
        ls_report-run_date    = ls_job-sdlstrtdt.
        ls_report-run_time    = ls_job-sdlstrttm.
        ls_report-message     = 'Đang chờ đến giờ...'.

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

  " 3. Hiển thị ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_report ).

      lo_alv->set_screen_popup(
        start_column = 10  end_column   = 110
        start_line   = 5   end_line     = 20 ).

      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( 'X' ).

      lo_col = lo_columns->get_column( 'STATUS_ICON' ). lo_col->set_long_text( 'Status' ).
      lo_col = lo_columns->get_column( 'RUN_DATE' ).    lo_col->set_long_text( 'Ngày' ).
      lo_col = lo_columns->get_column( 'RUN_TIME' ).    lo_col->set_long_text( 'Giờ' ).
      lo_col = lo_columns->get_column( 'ITEMS_FOUND' ). lo_col->set_long_text( 'SL Tìm' ).
      lo_col = lo_columns->get_column( 'SUCCESS_CNT' ). lo_col->set_long_text( 'Tạo OK' ).
      lo_col = lo_columns->get_column( 'ERROR_CNT' ).   lo_col->set_long_text( 'Lỗi' ).
      lo_col = lo_columns->get_column( 'MESSAGE' ).     lo_col->set_long_text( 'Ghi chú' ).
      lo_col = lo_columns->get_column( 'JOBCOUNT' ).    lo_col->set_visible( abap_false ).

      lo_alv->display( ).

    CATCH cx_salv_msg.
      MESSAGE 'Lỗi hiển thị ALV' TYPE 'S'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPDATE_STATUS_COUNTS
*&---------------------------------------------------------------------*
*& Calculates totals and updates global count variables for Screen 200
*&---------------------------------------------------------------------*
*FORM update_status_counts.
*  " --- Header ---
*  DESCRIBE TABLE gt_hd_val  LINES DATA(lv_h_val).  " Validated (Chờ xử lý)
*  DESCRIBE TABLE gt_hd_suc  LINES DATA(lv_h_suc).  " Success
*  DESCRIBE TABLE gt_hd_fail LINES DATA(lv_h_fail). " Failed
*
*  " --- Item ---
*  DESCRIBE TABLE gt_it_val  LINES DATA(lv_i_val).
*  DESCRIBE TABLE gt_it_suc  LINES DATA(lv_i_suc).
*  DESCRIBE TABLE gt_it_fail LINES DATA(lv_i_fail).
*
*  " --- Condition (Mới) ---
*  DESCRIBE TABLE gt_pr_val  LINES DATA(lv_c_val).
*  DESCRIBE TABLE gt_pr_suc  LINES DATA(lv_c_suc).
*  DESCRIBE TABLE gt_pr_fail LINES DATA(lv_c_fail).
*
*  " Gán vào biến toàn cục để FORM build_html dùng
*  gv_cnt_h_val = lv_h_val. gv_cnt_h_suc = lv_h_suc. gv_cnt_h_fail = lv_h_fail.
*  gv_cnt_i_val = lv_i_val. gv_cnt_i_suc = lv_i_suc. gv_cnt_i_fail = lv_i_fail.
*  gv_cnt_c_val = lv_c_val. gv_cnt_c_suc = lv_c_suc. gv_cnt_c_fail = lv_c_fail.
*
*  " Tính tổng
*  gv_cnt_h_tot = lv_h_val + lv_h_suc + lv_h_fail.
*  gv_cnt_i_tot = lv_i_val + lv_i_suc + lv_i_fail.
*  gv_cnt_c_tot = lv_c_val + lv_c_suc + lv_c_fail.
*ENDFORM.

*FORM update_status_counts.
*  CLEAR: gv_cnt_val_ready, gv_cnt_val_incomp, gv_cnt_val_err,
*         gv_cnt_suc_comp, gv_cnt_suc_incomp,
*         gv_cnt_fail_err.
*
*  " --- 1. Card VALIDATED (Dựa trên bảng gt_hd_val) ---
*  LOOP AT gt_hd_val INTO DATA(ls_val).
*    CASE ls_val-status.
*      WHEN 'READY'.  ADD 1 TO gv_cnt_val_ready.
*      WHEN 'INCOMP'. ADD 1 TO gv_cnt_val_incomp.
*      WHEN 'ERROR'.  ADD 1 TO gv_cnt_val_err.
*    ENDCASE.
*  ENDLOOP.
*
*  " --- 2. Card POSTED SUCCESS (Dựa trên bảng gt_hd_suc) ---
*  LOOP AT gt_hd_suc INTO DATA(ls_suc).
*    " Giả sử ta check field message hoặc status phụ để biết nó incomplete
*    IF ls_suc-message CS 'Incomplete' OR ls_suc-message CS 'Warning'.
*      ADD 1 TO gv_cnt_suc_incomp.
*    ELSE.
*      ADD 1 TO gv_cnt_suc_comp.
*    ENDIF.
*  ENDLOOP.
*
*  " --- 3. Card POSTED FAILED (Dựa trên bảng gt_hd_fail) ---
*  DESCRIBE TABLE gt_hd_fail LINES gv_cnt_fail_err.
*  " (Thường Failed là Error luôn, ít khi chia nhỏ, nhưng nếu muốn bạn có thể loop để đếm kỹ hơn)
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPDATE_STATUS_COUNTS (Logic: Error > Incomplete > Ready)
*&---------------------------------------------------------------------*
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
  " 2. TAB POSTED SUCCESS
  " =========================================================
  LOOP AT gt_hd_suc INTO DATA(ls_suc).
    lv_final_status = 'SUCCESS'.

    " Logic: Nếu thiếu Delivery -> Coi như Incomplete Success (Vàng)
    IF ls_suc-vbeln_dlv IS INITIAL.
       lv_final_status = 'INCOMP'.
    ENDIF.

    " (Tùy chọn) Kiểm tra thêm Item/Cond nếu muốn kỹ hơn
    " LOOP AT gt_it_suc ... WHERE status = 'W' ... -> lv_final_status = 'INCOMP'.

    IF lv_final_status = 'INCOMP'.
      ADD 1 TO gv_cnt_suc_incomp.
    ELSE.
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

*&---------------------------------------------------------------------*
*& Form PERFORM_CREATE_SINGLE_SO
*&---------------------------------------------------------------------*
FORM perform_create_single_so.

  " ========================================================================
  " [PHẦN 1] CHUẨN BỊ DỮ LIỆU TỪ ALV (GIỮ NGUYÊN)
  " ========================================================================
  IF go_grid_conditions IS BOUND.
    go_grid_conditions->check_changed_data( ).
  ENDIF.

  DATA: ls_manual_cond TYPE ty_cond_alv.
  READ TABLE gt_conditions_alv INTO ls_manual_cond WITH KEY kschl = 'ZPRQ'.

  IF sy-subrc = 0 AND ls_manual_cond-amount IS NOT INITIAL.
    FIELD-SYMBOLS: <fs_curr_item> LIKE LINE OF gt_item_details.
    IF gv_current_item_idx > 0.
      READ TABLE gt_item_details ASSIGNING <fs_curr_item> INDEX gv_current_item_idx.
      IF sy-subrc = 0.
         <fs_curr_item>-cond_type  = ls_manual_cond-kschl.
         <fs_curr_item>-unit_price = ls_manual_cond-amount.
         <fs_curr_item>-currency   = ls_manual_cond-waers.
      ENDIF.
    ENDIF.
  ENDIF.

  " ========================================================================
  " [PHẦN 2] KHAI BÁO BIẾN
  " ========================================================================
  DATA: ls_header_in       TYPE bapisdhd1,
        ls_header_inx      TYPE bapisdhd1x,
        lt_partner_in      TYPE TABLE OF bapiparnr,
        lt_item_in         TYPE TABLE OF bapisditm,
        lt_item_inx        TYPE TABLE OF bapisditmx,
        lt_sched_in        TYPE TABLE OF bapischdl,
        lt_sched_inx       TYPE TABLE OF bapischdlx,
        " Biến cho Bước 1 (Create)
        lt_return          TYPE TABLE OF bapiret2,
        lv_vbeln           TYPE vbak-vbeln,
        " Biến cho Bước 2 (Change)
        lt_cond_change     TYPE TABLE OF bapicond,
        lt_cond_change_x   TYPE TABLE OF bapicondx,
        ls_bapi_h_x        TYPE bapisdh1x,
        lt_return_change   TYPE TABLE OF bapiret2.

  " Cấu trúc lưu tạm giá để dùng cho bước 2
  TYPES: BEGIN OF ty_price_buffer,
           itm_number TYPE bapisditm-itm_number,
           cond_type  TYPE kscha,
           amount     TYPE p DECIMALS 2,
           currency   TYPE waers,
           unit       TYPE meins,
         END OF ty_price_buffer.
  DATA: lt_price_buffer TYPE TABLE OF ty_price_buffer.

  DATA: lv_cond_val_str TYPE char28,
        lv_amount_temp  TYPE p DECIMALS 2,
        lv_qty_str      TYPE string,
        lv_qty_p        TYPE p DECIMALS 3,
        lv_price_raw    TYPE string,
        lv_waers_check  TYPE tcurc-waers.

  FIELD-SYMBOLS: <fs_item> LIKE LINE OF gt_item_details.
  CLEAR gv_so_just_created.

  " --- Validate Header ---
  IF gs_so_heder_ui-so_hdr_sold_addr IS INITIAL OR gs_so_heder_ui-so_hdr_sold_addr = '0000000000'.
    MESSAGE 'Sold-to Party is required.' TYPE 'E'. EXIT.
  ENDIF.
  IF gs_so_heder_ui-so_hdr_bstnk IS INITIAL.
    MESSAGE 'Customer Reference is required.' TYPE 'E'. EXIT.
  ENDIF.

  " ========================================================================
  " [PHẦN 3] VALIDATE ITEM & PREPARE DATA
  " ========================================================================
  IF gt_item_details IS NOT INITIAL.
    LOOP AT gt_item_details ASSIGNING <fs_item>.
      IF <fs_item>-matnr IS NOT INITIAL.
        " Xử lý Quantity
        CLEAR lv_qty_p.
        lv_qty_str = <fs_item>-quantity.
        REPLACE ALL OCCURRENCES OF ',' IN lv_qty_str WITH '.'.
        TRY. lv_qty_p = lv_qty_str. CATCH cx_root. lv_qty_p = 0. ENDTRY.
        IF lv_qty_p <= 0. MESSAGE |Item { sy-tabix }: Quantity required.| TYPE 'E'. EXIT. ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.

  " ========================================================================
  " [PHẦN 4] MAPPING BAPI HEADER
  " ========================================================================
  " 1. Làm sạch Header Currency
  CONDENSE gs_so_heder_ui-so_hdr_waerk NO-GAPS.
  TRANSLATE gs_so_heder_ui-so_hdr_waerk TO UPPER CASE.
  IF gs_so_heder_ui-so_hdr_waerk = 'EA'. gs_so_heder_ui-so_hdr_waerk = 'VND'. ENDIF.
  IF gs_so_heder_ui-so_hdr_waerk IS INITIAL. gs_so_heder_ui-so_hdr_waerk = 'VND'. ENDIF.

  " Check Tồn Tại Trong Hệ Thống (TCURC)
  SELECT SINGLE waers INTO lv_waers_check FROM tcurc WHERE waers = gs_so_heder_ui-so_hdr_waerk.
  IF sy-subrc <> 0. MESSAGE |Lỗi Header Currency: { gs_so_heder_ui-so_hdr_waerk } không tồn tại.| TYPE 'E'. EXIT. ENDIF.

  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.
  ls_header_in-purch_no_c = gs_so_heder_ui-so_hdr_bstnk.
  ls_header_in-doc_date   = gs_so_heder_ui-so_hdr_audat.
  ls_header_in-currency   = gs_so_heder_ui-so_hdr_waerk.
  ls_header_in-pmnttrms   = gs_so_heder_ui-so_hdr_zterm.

  ls_header_inx = VALUE #( doc_type = 'X' sales_org = 'X' distr_chan = 'X' division = 'X'
                           purch_no_c = 'X' doc_date = 'X' currency = 'X' pmnttrms = 'X' ).

  DATA(lv_sold_to_save) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to_save IMPORTING output = lv_sold_to_save.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to_save ) TO lt_partner_in.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to_save ) TO lt_partner_in.

  " ========================================================================
  " [PHẦN 5] MAPPING ITEMS (LƯU Ý: KHÔNG MAP CONDITION VÀO BAPI 1)
  " ========================================================================
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    IF <fs_item>-matnr IS NOT INITIAL.

      DATA(lv_posnr) = sy-tabix * 10.
      DATA(lv_matnr_bapi) = <fs_item>-matnr.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.

      " Re-calculate Quantity
      CLEAR lv_qty_p.
      lv_qty_str = <fs_item>-quantity.
      REPLACE ALL OCCURRENCES OF ',' IN lv_qty_str WITH '.'.
      TRY. lv_qty_p = lv_qty_str. CATCH cx_root. lv_qty_p = 0. ENDTRY.

      APPEND VALUE #( itm_number = lv_posnr material = lv_matnr_bapi
                      target_qty = lv_qty_p target_qu = <fs_item>-unit
                      plant = <fs_item>-plant store_loc = <fs_item>-store_loc ) TO lt_item_in.

      APPEND VALUE #( itm_number = lv_posnr material = 'X' target_qty = 'X' target_qu = 'X'
                      plant = 'X' store_loc = 'X' ) TO lt_item_inx.

      APPEND VALUE #( itm_number = lv_posnr req_qty = lv_qty_p req_date = <fs_item>-req_date ) TO lt_sched_in.
      APPEND VALUE #( itm_number = lv_posnr req_qty = 'X' req_date = 'X' ) TO lt_sched_inx.

      " ------------------------------------------------------------------
      " [QUAN TRỌNG] LƯU GIÁ VÀO BUFFER ĐỂ DÙNG CHO BƯỚC 2 (CHANGE)
      " KHÔNG append vào lt_cond_in ở đây nữa!
      " ------------------------------------------------------------------
      IF <fs_item>-cond_type IS NOT INITIAL AND <fs_item>-unit_price IS NOT INITIAL.

         " Validate Currency
         CONDENSE <fs_item>-currency NO-GAPS.
         TRANSLATE <fs_item>-currency TO UPPER CASE.
         IF <fs_item>-currency = 'EA'. <fs_item>-currency = 'VND'. ENDIF.
         IF <fs_item>-currency IS INITIAL. <fs_item>-currency = gs_so_heder_ui-so_hdr_waerk. ENDIF.

         " Validate Amount
         lv_price_raw = <fs_item>-unit_price.
         DATA(lv_last_dot) = -1. DATA(lv_last_comma) = -1.
         FIND ALL OCCURRENCES OF '.' IN lv_price_raw MATCH OFFSET lv_last_dot.
         FIND ALL OCCURRENCES OF ',' IN lv_price_raw MATCH OFFSET lv_last_comma.
         IF lv_last_dot > lv_last_comma. REPLACE ALL OCCURRENCES OF ',' IN lv_price_raw WITH ''.
         ELSEIF lv_last_comma > lv_last_dot. REPLACE ALL OCCURRENCES OF '.' IN lv_price_raw WITH ''. REPLACE ALL OCCURRENCES OF ',' IN lv_price_raw WITH '.'. ENDIF.
         TRY. lv_amount_temp = lv_price_raw. CATCH cx_root. lv_amount_temp = 0. ENDTRY.

         " Lưu vào buffer
         APPEND VALUE #( itm_number = lv_posnr
                         cond_type  = <fs_item>-cond_type
                         amount     = lv_amount_temp
                         currency   = <fs_item>-currency
                         unit       = <fs_item>-unit ) TO lt_price_buffer.
      ENDIF.

    ENDIF.
  ENDLOOP.

  " ========================================================================
  " [BƯỚC 1] TẠO SO (CREATE - KHÔNG CÓ GIÁ)
  " ========================================================================
  CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
    EXPORTING order_header_in = ls_header_in order_header_inx = ls_header_inx
    IMPORTING salesdocument = lv_vbeln
    TABLES return = lt_return order_items_in = lt_item_in order_items_inx = lt_item_inx
           order_partners = lt_partner_in order_schedules_in = lt_sched_in order_schedules_inx = lt_sched_inx.

  " Check Lỗi Bước 1
  DATA: lv_err_step1 TYPE abap_bool.
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ret>) WHERE type CA 'AEX'.
    lv_err_step1 = abap_true. EXIT.
  ENDLOOP.

  IF lv_err_step1 = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    " ... (Code hiển thị lỗi giữ nguyên như cũ) ...
    MESSAGE 'Lỗi khi tạo SO (Bước 1).' TYPE 'E'.
    EXIT. " Thoát luôn nếu không tạo được SO
  ENDIF.

  " *** BẮT BUỘC COMMIT ĐỂ CÓ VBELN TRONG DATABASE CHO BƯỚC 2 ***
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.


  " ========================================================================
  " [BƯỚC 2] CẬP NHẬT GIÁ (CHANGE - UPDATE GIÁ)
  " ========================================================================
  IF lv_vbeln IS NOT INITIAL AND lt_price_buffer IS NOT INITIAL.

    " Map dữ liệu từ Buffer vào cấu trúc BAPI CHANGE
    LOOP AT lt_price_buffer INTO DATA(ls_buff).

       CLEAR lv_cond_val_str.
       WRITE ls_buff-amount TO lv_cond_val_str CURRENCY ls_buff-currency NO-GROUPING.
       IF lv_cond_val_str CS ','. REPLACE ALL OCCURRENCES OF ',' IN lv_cond_val_str WITH '.'. ENDIF.
       CONDENSE lv_cond_val_str NO-GAPS.

       APPEND VALUE #( itm_number = ls_buff-itm_number
                       cond_type  = ls_buff-cond_type
                       cond_value = lv_cond_val_str
                       currency   = ls_buff-currency
                       cond_unit  = ls_buff-unit
                       cond_p_unt = 1 ) TO lt_cond_change.

       " Dùng 'I' ở đây (trong Change mode) sẽ hoạt động như Manual Entry
       APPEND VALUE #( itm_number = ls_buff-itm_number
                       cond_type  = ls_buff-cond_type
                       updateflag = 'I'
                       cond_value = 'X'
                       currency   = 'X'
                       cond_unit  = 'X'
                       cond_p_unt = 'X' ) TO lt_cond_change_x.
    ENDLOOP.

    ls_bapi_h_x-updateflag = 'U'. " Cờ báo update Header

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = lv_vbeln
        order_header_inx = ls_bapi_h_x
      TABLES
        return           = lt_return_change
        conditions_in    = lt_cond_change
        conditions_inx   = lt_cond_change_x.

    " Check Lỗi Bước 2
    DATA: lv_err_step2 TYPE abap_bool.
    LOOP AT lt_return_change ASSIGNING FIELD-SYMBOL(<ret2>) WHERE type CA 'AEX'.
      lv_err_step2 = abap_true.
    ENDLOOP.

    IF lv_err_step2 = abap_true.
       " Nếu lỗi Update giá -> Rollback phần giá, nhưng SO đã tạo ở Bước 1 vẫn còn
       " Tùy nghiệp vụ: Có thể để nguyên SO giá 0 hoặc xóa SO.
       " Ở đây ta chỉ báo lỗi.
       MESSAGE |SO { lv_vbeln } đã tạo nhưng LỖI cập nhật giá! Vui lòng kiểm tra lại.| TYPE 'W'.
    ELSE.
       " Commit lần cuối để lưu giá
       CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.

       " --- THÀNH CÔNG TOÀN DIỆN ---
       gs_so_heder_ui-so_hdr_vbeln = lv_vbeln.
       " ... (Tiếp tục logic lưu ZTable và tạo Delivery như cũ) ...

       " Code Save Ztable (Giữ nguyên)
       IF gt_item_details IS NOT INITIAL.
          DATA lt_items_to_save TYPE TABLE OF ztb_so_item_sing.
          FIELD-SYMBOLS <fs_item_alv> LIKE LINE OF gt_item_details.
          LOOP AT gt_item_details ASSIGNING <fs_item_alv> WHERE matnr IS NOT INITIAL.
            <fs_item_alv>-req_id = gs_so_heder_ui-req_id.
            <fs_item_alv>-sales_order = lv_vbeln.
            <fs_item_alv>-proc_status = 'P'.
            APPEND CORRESPONDING #( <fs_item_alv> ) TO lt_items_to_save.
          ENDLOOP.
          IF lt_items_to_save IS NOT INITIAL.
            MODIFY ztb_so_item_sing FROM TABLE @lt_items_to_save. COMMIT WORK.
          ENDIF.
       ENDIF.

       " Code tạo Delivery (Giữ nguyên)
       DATA: ls_temp_header_for_deliv TYPE ty_header.
       ls_temp_header_for_deliv-req_id        = gs_so_heder_ui-req_id.
       ls_temp_header_for_deliv-temp_id       = gs_so_heder_ui-temp_id.
       ls_temp_header_for_deliv-VBELN_SO   = lv_vbeln.
       ls_temp_header_for_deliv-sales_org     = gs_so_heder_ui-so_hdr_vkorg.
       ls_temp_header_for_deliv-sales_channel = gs_so_heder_ui-so_hdr_vtweg.
       ls_temp_header_for_deliv-sales_div     = gs_so_heder_ui-so_hdr_spart.
       ls_temp_header_for_deliv-sold_to_party = gs_so_heder_ui-so_hdr_sold_addr.
       ls_temp_header_for_deliv-cust_ref      = gs_so_heder_ui-so_hdr_bstnk.

       IF lt_item_in IS NOT INITIAL.
         PERFORM perform_auto_delivery USING lv_vbeln CHANGING ls_temp_header_for_deliv.
       ELSE.
         ls_temp_header_for_deliv-message = |SO { lv_vbeln } created (no items).|.
       ENDIF.

       gs_so_heder_ui-so_hdr_message = ls_temp_header_for_deliv-message.
       IF gs_so_heder_ui-so_hdr_message IS INITIAL.
         gs_so_heder_ui-so_hdr_message = |Sales Order { lv_vbeln } created successfully.|.
       ENDIF.
       MESSAGE gs_so_heder_ui-so_hdr_message TYPE 'S'.

       gv_so_just_created = abap_true.
       PERFORM reset_single_entry_screen.
    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form PERFORM_CREATE_SINGLE_SO
*&---------------------------------------------------------------------*
*FORM perform_create_single_so.
*
*   1. Khai báo biến cho BAPI
*  DATA: ls_header_in      TYPE bapisdhd1,
*        ls_header_inx     TYPE bapisdhd1x,
*        lt_items_in       TYPE TABLE OF bapisditm,
*        lt_items_inx      TYPE TABLE OF bapisditmx,
*        lt_partners       TYPE TABLE OF bapiparnr,
*        lt_schedules_in   TYPE TABLE OF bapischdl,
*        lt_schedules_inx  TYPE TABLE OF bapischdlx,
*        lt_conditions_in  TYPE TABLE OF bapicond,   " Quan trọng
*        lt_conditions_inx TYPE TABLE OF bapicondx,  " Quan trọng
*        lt_return         TYPE TABLE OF bapiret2,
*        lv_salesdocument  TYPE vbak-vbeln.
*
*  DATA: lv_item_no TYPE posnr_va.
*
*   --- 2. CHUẨN BỊ HEADER ---
*  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
*  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
*  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
*  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.
*  ls_header_in-req_date_h = gs_so_heder_ui-so_hdr_ketdat. " Ngày giao hàng
*
*  ls_header_inx-doc_type   = 'X'.
*  ls_header_inx-sales_org  = 'X'.
*  ls_header_inx-distr_chan = 'X'.
*  ls_header_inx-division   = 'X'.
*  ls_header_inx-req_date_h = 'X'.
*  ls_header_inx-updateflag = 'I'. " Insert
*
*   --- 3. CHUẨN BỊ PARTNER (Sold-to) ---
*  APPEND VALUE #( partn_role = 'AG' partn_numb = gs_so_heder_ui-so_hdr_sold_addr ) TO lt_partners.
*
*   --- 4. CHUẨN BỊ ITEMS & CONDITIONS ---
*   Duyệt qua bảng Item Details (dữ liệu chính)
*  LOOP AT gt_item_details ASSIGNING FIELD-SYMBOL(<fs_item>).
*    lv_item_no = <fs_item>-item_no.
*    IF lv_item_no IS INITIAL. lv_item_no = sy-tabix * 10. ENDIF. " Tự sinh số nếu thiếu
*
*     A. Map Item Data
*    APPEND VALUE #(
*      itm_number = lv_item_no
*      material   = <fs_item>-matnr
*      plant      = <fs_item>-plant
*      target_qty = <fs_item>-quantity
*      target_qu  = <fs_item>-unit
*    ) TO lt_items_in.
*
*    APPEND VALUE #(
*      itm_number = lv_item_no
*      material   = 'X'
*      plant      = 'X'
*      target_qty = 'X'
*      target_qu  = 'X'
*      updateflag = 'I'
*    ) TO lt_items_inx.
*
*     B. Map Condition (Giá) - Lấy từ bảng Condition ALV
*     Đây là phần KHÁC BIỆT quan trọng. Bạn cần lấy giá từ bảng gt_conditions_alv
*     tương ứng với Item này.
*    LOOP AT gt_conditions_alv ASSIGNING FIELD-SYMBOL(<fs_cond>)
*                              WHERE item_no = lv_item_no       " Khớp theo Item No
*                                AND amount  IS NOT INITIAL.    " Chỉ lấy dòng có tiền
*
*      APPEND VALUE #(
*        itm_number = lv_item_no
*        cond_type  = <fs_cond>-kschl   " Ví dụ: PR00
*        cond_value = <fs_cond>-amount  " Ví dụ: 100000
*        currency   = <fs_cond>-waers   " Ví dụ: VND
*      ) TO lt_conditions_in.
*
*      APPEND VALUE #(
*        itm_number = lv_item_no
*        cond_type  = <fs_cond>-kschl
*        cond_value = 'X'
*        currency   = 'X'
*        updateflag = 'I'
*      ) TO lt_conditions_inx.
*    ENDLOOP.
*
*     (Fallback) Nếu trong gt_conditions_alv không có, thử lấy từ gt_item_details
*     Dành cho trường hợp nhập nhanh trên grid Item mà không mở tab Condition
*    IF sy-subrc <> 0 AND <fs_item>-unit_price IS NOT INITIAL.
*       APPEND VALUE #(
*        itm_number = lv_item_no
*        cond_type  = 'PR00'              " Mặc định PR00 nếu nhập nhanh
*        cond_value = <fs_item>-unit_price
*        currency   = <fs_item>-currency
*      ) TO lt_conditions_in.
*
*      APPEND VALUE #(
*        itm_number = lv_item_no
*        cond_type  = 'PR00'
*        cond_value = 'X'
*        currency   = 'X'
*        updateflag = 'I'
*      ) TO lt_conditions_inx.
*    ENDIF.
*
*  ENDLOOP.
*
*   --- 5. GỌI BAPI ---
*  CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
*    EXPORTING
*      order_header_in      = ls_header_in
*      order_header_inx     = ls_header_inx
*    IMPORTING
*      salesdocument        = lv_salesdocument
*    TABLES
*      return               = lt_return
*      order_items_in       = lt_items_in
*      order_items_inx      = lt_items_inx
*      order_partners       = lt_partners
*      order_conditions_in  = lt_conditions_in   " <--- Đừng quên
*      order_conditions_inx = lt_conditions_inx. " <--- Đừng quên
*
*   --- 6. XỬ LÝ KẾT QUẢ ---
*  IF lv_salesdocument IS NOT INITIAL.
*    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
*    MESSAGE |Sales Order { lv_salesdocument } created successfully.| TYPE 'S'.
*
*     Reset màn hình hoặc chuyển trang
*    gv_so_just_created = abap_true.
*    CLEAR: gt_item_details, gt_conditions_alv. " Xóa data cũ
*  ELSE.
*    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
*     Hiển thị lỗi BAPI
*    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
*      MESSAGE ID ls_ret-id TYPE 'S' NUMBER ls_ret-number
*              WITH ls_ret-message_v1 ls_ret-message_v2 ls_ret-message_v3 ls_ret-message_v4
*              DISPLAY LIKE 'E'.
*      EXIT. " Chỉ hiện lỗi đầu tiên
*    ENDLOOP.
*  ENDIF.
*
*ENDFORM.

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
         gs_so_heder_ui-SO_HDR_KALSM,
         gs_so_heder_ui-so_hdr_waerk,
         gs_so_heder_ui-so_hdr_zterm,
         gs_so_heder_ui-so_hdr_inco1,
         gs_so_heder_ui-SO_HDR_MESSAGE.

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

*&---------------------------------------------------------------------*
*& Form PERFORM_SINGLE_ITEM_SIMULATE (Sửa lỗi Type BAPISDHEDU)
*&---------------------------------------------------------------------*
FORM perform_single_item_simulate. " <<< ĐÃ XÓA 'USING ir_data_changed...'

  " === 1. Khai báo (ĐÃ SỬA LẠI CHO ĐÚNG BAPI) ===
  DATA: ls_header_in  TYPE bapisdhead,
        lt_item_in    TYPE TABLE OF bapiitemin,
        lt_partner_in TYPE TABLE OF bapipartnr,
        lt_sched_in   TYPE TABLE OF bapischdl.

  " Các bảng OUTPUT (Sửa lại cho đúng tên)
  DATA: lt_item_out        TYPE TABLE OF bapiitemex,
        lt_sched_out       TYPE TABLE OF bapisdhedu,  " <<< SỬA LỖI: ĐÚNG LÀ BAPISDHEDU
        lt_cond_out        TYPE TABLE OF bapicond,
        lt_return          TYPE TABLE OF bapiret2,
        lt_incomplete      TYPE TABLE OF bapiincomp,
        lv_errors_occurred TYPE abap_bool.

  FIELD-SYMBOLS: <fs_item>      LIKE LINE OF gt_item_details,
                 <fs_item_out>  LIKE LINE OF lt_item_out,
                 <fs_sched_out> LIKE LINE OF lt_sched_out, " (Giờ đã là kiểu BAPISDHEDU)
                 <fs_cond_out>  LIKE LINE OF lt_cond_out.

  " --- 2. Chuẩn bị Header & Item BAPI ---
  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.
  DATA(lv_sold_to) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner_in.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner_in.

  LOOP AT gt_item_details ASSIGNING <fs_item>.
    IF <fs_item>-matnr IS INITIAL. CONTINUE. ENDIF.
    DATA(lv_posnr) = sy-tabix * 10.
    DATA(lv_matnr_bapi) = <fs_item>-matnr.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.

    APPEND VALUE #( itm_number = lv_posnr
                    material   = lv_matnr_bapi
                    plant      = <fs_item>-plant
                    store_loc  = <fs_item>-store_loc
                  ) TO lt_item_in.

    DATA lv_sched_date TYPE dats.
    IF <fs_item>-req_date IS NOT INITIAL AND <fs_item>-req_date <> '00000000'.
      lv_sched_date = <fs_item>-req_date.
    ELSE.
      lv_sched_date = gs_so_heder_ui-so_hdr_ketdat.
    ENDIF.

    APPEND VALUE #( itm_number = lv_posnr
                    req_qty    = <fs_item>-quantity
                    req_date   = lv_sched_date
                  ) TO lt_sched_in.
  ENDLOOP.
  IF lt_item_in IS INITIAL. RETURN. ENDIF.

  " --- 3. Gọi BAPI SIMULATE (Đã sửa) ---
  CALL FUNCTION 'BAPI_SALESORDER_SIMULATE'
    EXPORTING
      order_header_in    = ls_header_in
    TABLES
      order_items_in     = lt_item_in
      order_partners     = lt_partner_in
      order_schedule_in  = lt_sched_in
      order_items_out    = lt_item_out
      order_schedule_ex  = lt_sched_out   " (Tên đúng là ORDER_SCHEDULE_EX)
      order_condition_ex = lt_cond_out    " (Tên đúng là ORDER_CONDITION_EX)
      order_incomplete   = lt_incomplete
      messagetable       = lt_return.

  " --- 4. Cập nhật BẢNG NỘI BỘ ALV ---
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    lv_posnr = sy-tabix * 10.
    READ TABLE lt_item_out ASSIGNING <fs_item_out> WITH KEY itm_number = lv_posnr.
    IF sy-subrc <> 0.
      CLEAR: <fs_item>-description, <fs_item>-itca,
             <fs_item>-ship_point, <fs_item>-currency,
             <fs_item>-conf_qty, <fs_item>-net_price, <fs_item>-net_value,
             <fs_item>-tax.
      CONTINUE.
    ENDIF.

    <fs_item>-item_no     = <fs_item_out>-itm_number.
    <fs_item>-description = <fs_item_out>-short_text.
    <fs_item>-itca        = <fs_item_out>-item_categ.
    <fs_item>-currency    = gs_so_heder_ui-so_hdr_waerk.
    <fs_item>-plant       = <fs_item_out>-plant.       " <<< THÊM MỚI (Sửa lỗi Plant)
    <fs_item>-unit        = <fs_item_out>-sales_unit.  " <<< THÊM MỚI (Sửa lỗi Sales Unit)
*    <fs_item>-net_price   = <fs_item_out>-net_price.  " Gán Net Price
*    <fs_item>-unit_price  = <fs_item_out>-net_price.  " Gán Net Price vào cột "Amount"
*    <fs_item>-net_value   = <fs_item_out>-net_value.
*    <fs_item>-tax         = <fs_item_out>-tax_val.    " <<< Lấy thuế
*    <fs_item>-per         = <fs_item_out>-cond_p_unt. " <<< Lấy "Per"

    " <<< SỬA: Đọc từ BAPISDHEDU (Tên trường khác) >>>
    READ TABLE lt_sched_out ASSIGNING <fs_sched_out> WITH KEY itm_number = lv_posnr.
    IF sy-subrc = 0.
      <fs_item>-conf_qty = <fs_sched_out>-req_qty. " <<< SỬA: Tên trường là SCHED_QTY
      IF <fs_item>-req_date IS INITIAL OR <fs_item>-req_date = '00000000'.
        <fs_item>-req_date = <fs_sched_out>-req_date. " <<< SỬA: Tên trường là DELIV_DATE
      ENDIF.
    ENDIF.

    LOOP AT lt_cond_out ASSIGNING <fs_cond_out> WHERE itm_number = lv_posnr.
      <fs_item>-cond_type  = <fs_cond_out>-cond_type.  " Gán tên 'ZPT0'
    ENDLOOP.

  ENDLOOP.

  " --- 5. Tính tổng và cập nhật 2 TRƯỜNG HEADER (Giữ nguyên) ---
  DATA: lv_total_net TYPE vbap-netwr,
        lv_total_tax TYPE vbap-mwsbp.
  CLEAR: lv_total_net, lv_total_tax.
  LOOP AT gt_item_details ASSIGNING <fs_item>.
    lv_total_net = lv_total_net + <fs_item>-net_value.
    lv_total_tax = lv_total_tax + <fs_item>-tax.
  ENDLOOP.

  gs_so_heder_ui-so_hdr_total_net = lv_total_net.
  gs_so_heder_ui-so_hdr_total_tax = lv_total_tax.

  " --- 6. Xử lý lỗi (Giữ nguyên) ---
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ret>) WHERE type CA 'AEX'.
    lv_errors_occurred = abap_true.
    MESSAGE <ret>-message TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDLOOP.

  IF lv_errors_occurred = abap_false.
    MESSAGE 'Item details simulated successfully. Totals updated.' TYPE 'S'.
  ENDIF.
ENDFORM.


***---------------------------------------------------------------------*
*** Form AUTO_FILL_ON_DATA_CHANGED (Final Version - Single Entry)
***---------------------------------------------------------------------*
*** Mô phỏng hành vi VA01 (rút gọn)
*** - Khi nhập Material: auto Description, Unit, ItemCat, ReqDate, Plant
*** - Khi nhập Quantity: auto Currency, NetPrice, NetValue, Conf.Qty
***---------------------------------------------------------------------*
*FORM auto_fill_on_data_changed
*  USING ir_data_changed TYPE REF TO cl_alv_changed_data_protocol.
*
*  FIELD-SYMBOLS: <ls_modi_cell> LIKE LINE OF ir_data_changed->mt_mod_cells,
*                 <fs_item>      LIKE LINE OF gt_item_details.
*
*  DATA: lv_matnr_internal TYPE matnr,
*        lv_unit           TYPE meins,
*        lv_maktx          TYPE maktx,
*        lv_curr           TYPE waers.
*
*  LOOP AT ir_data_changed->mt_mod_cells ASSIGNING <ls_modi_cell>.
*
*    "=============================================================
*    " 🛡️ Check row validity trước khi đọc dòng (tránh dump)
*    "=============================================================
*    IF <ls_modi_cell>-row_id > LINES( gt_item_details ) OR <ls_modi_cell>-row_id <= 0.
*      CONTINUE.
*    ENDIF.
*
*    READ TABLE gt_item_details ASSIGNING <fs_item> INDEX <ls_modi_cell>-row_id.
*    IF sy-subrc <> 0.
*      CONTINUE.
*    ENDIF.
*
*    "=============================================================
*    " CASE 1️⃣: User nhập MATERIAL → auto-fill thông tin cơ bản
*    "=============================================================
*    IF <ls_modi_cell>-fieldname = 'MATERIAL'.
*
*      "--- 2. Lấy Description (MAKT) ---
*      SELECT SINGLE maktx
*        FROM makt
*        INTO @lv_maktx
*        WHERE matnr = @lv_matnr_internal
*          AND spras = @sy-langu.
*      IF sy-subrc = 0.
*        <fs_item>-description = lv_maktx.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'DESCRIPTION'
*          i_value     = lv_maktx ).
*      ENDIF.
*
*      "--- 3. Lấy Sales Unit (MVKE/MARA) ---
*      CLEAR lv_unit.
*      SELECT SINGLE vrkme
*        FROM mvke
*        INTO @lv_unit
*        WHERE matnr = @lv_matnr_internal
*          AND vkorg = @gs_so_heder_ui-so_hdr_vkorg
*          AND vtweg = @gs_so_heder_ui-so_hdr_vtweg.
*      IF sy-subrc <> 0.
*        SELECT SINGLE meins
*          FROM mara
*          INTO @lv_unit
*          WHERE matnr = @lv_matnr_internal.
*      ENDIF.
*      IF lv_unit IS NOT INITIAL.
*        <fs_item>-unit = lv_unit.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'UNIT'
*          i_value     = lv_unit ).
*      ENDIF.
*
*      "--- 4. Gán Item Category mặc định (mô phỏng TAN) ---
*      IF <fs_item>-itca IS INITIAL.
*        <fs_item>-itca = 'TAN'.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'ITCA'
*          i_value     = 'TAN' ).
*      ENDIF.
*
*      "--- 5. Gán Delivery Date = Req.Deliv.Date từ Header ---
*      IF <fs_item>-req_date IS INITIAL
*         AND gs_so_heder_ui-so_hdr_ketdat IS NOT INITIAL.
*        <fs_item>-req_date = gs_so_heder_ui-so_hdr_ketdat.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'REQ_DATE'
*          i_value     = gs_so_heder_ui-so_hdr_ketdat ).
*      ENDIF.
*
*      "--- 6. Gán Plant mặc định (demo, nếu có thể) ---
*      IF <fs_item>-plant IS INITIAL.
*        <fs_item>-plant = '1000'. " ← Tạm thời hardcode, sau này có thể derive
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'PLANT'
*          i_value     = '1000' ).
*      ENDIF.
*
*    ENDIF. " end MATERIAL case
*
*
*    "=============================================================
*    " CASE 2️⃣: User nhập QUANTITY → auto-fill giá trị định lượng
*    "=============================================================
*    IF <ls_modi_cell>-fieldname = 'QUANTITY'.
*
*      "--- 1. Gán Confirmed Qty = Quantity ---
*      IF <fs_item>-quantity IS NOT INITIAL.
*        <fs_item>-conf_qty = <fs_item>-quantity.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'CONF_QTY'
*          i_value     = <fs_item>-conf_qty ).
*      ENDIF.
*
*      "--- 2. Currency lấy từ Header ---
*      lv_curr = gs_so_heder_ui-so_hdr_waerk.
*      IF lv_curr IS NOT INITIAL.
*        <fs_item>-currency = lv_curr.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'CURRENCY'
*          i_value     = lv_curr ).
*      ENDIF.
*
*      "--- 3. Net Price / Per (demo: copy Unit Price) ---
*      IF <fs_item>-unit_price IS NOT INITIAL.
*        <fs_item>-net_price = <fs_item>-unit_price.
*        ir_data_changed->modify_cell(
*          i_row_id    = <ls_modi_cell>-row_id
*          i_fieldname = 'NET_PRICE'
*          i_value     = <fs_item>-unit_price ).
*      ENDIF.
**
*
*    ENDIF. " end QUANTITY case
*
*  ENDLOOP.
*
*  "=============================================================
*  " 🔁 Refresh lại ALV sau khi auto-fill
*  "=============================================================
*  IF go_grid_item_single IS BOUND.
*    go_grid_item_single->refresh_table_display( ).
*  ENDIF.
*
*ENDFORM.
*
*
**&---------------------------------------------------------------------*
**& Form PERFORM_SINGLE_ITEM_SIMULATE (Sửa lỗi Type BAPISDHEDU)
**&---------------------------------------------------------------------*
*FORM perform_single_item_simulate. " <<< ĐÃ XÓA 'USING ir_data_changed...'
*
*  " === 1. Khai báo (ĐÃ SỬA LẠI CHO ĐÚNG BAPI) ===
*  DATA: ls_header_in  TYPE bapisdhead,
*        lt_item_in    TYPE TABLE OF bapiitemin,
*        lt_partner_in TYPE TABLE OF bapipartnr,
*        lt_sched_in   TYPE TABLE OF bapischdl.
*
*  " Các bảng OUTPUT (Sửa lại cho đúng tên)
*  DATA: lt_item_out    TYPE TABLE OF bapiitemex,
*        lt_sched_out   TYPE TABLE OF BAPISDHEDU,  " <<< SỬA LỖI: ĐÚNG LÀ BAPISDHEDU
*        lt_cond_out    TYPE TABLE OF bapicond,
*        lt_return      TYPE TABLE OF bapiret2,
*        lt_incomplete  TYPE TABLE OF bapiincomp,
*        lv_errors_occurred TYPE abap_bool.
*
*  FIELD-SYMBOLS: <fs_item>      LIKE LINE OF gt_item_details,
*                 <fs_item_out>  LIKE LINE OF lt_item_out,
*                 <fs_sched_out> LIKE LINE OF lt_sched_out, " (Giờ đã là kiểu BAPISDHEDU)
*                 <fs_cond_out>  LIKE LINE OF lt_cond_out.
*
*  " --- 2. Chuẩn bị Header & Item BAPI ---
*  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
*  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
*  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
*  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.
*  DATA(lv_sold_to) = gs_so_heder_ui-so_hdr_sold_addr.
*  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
*  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner_in.
*  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner_in.
*
*  LOOP AT gt_item_details ASSIGNING <fs_item>.
*    IF <fs_item>-matnr IS INITIAL. CONTINUE. ENDIF.
*    DATA(lv_posnr) = sy-tabix * 10.
*    DATA(lv_matnr_bapi) = <fs_item>-matnr.
*
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.
*
*    APPEND VALUE #( itm_number = lv_posnr
*                    material   = lv_matnr_bapi
*                    plant      = <fs_item>-plant
*                    store_loc  = <fs_item>-store_loc
*                  ) TO lt_item_in.
*
*    DATA lv_sched_date TYPE dats.
*    IF <fs_item>-req_date IS NOT INITIAL AND <fs_item>-req_date <> '00000000'.
*      lv_sched_date = <fs_item>-req_date.
*    ELSE.
*      lv_sched_date = gs_so_heder_ui-so_hdr_ketdat.
*    ENDIF.
*
*    APPEND VALUE #( itm_number = lv_posnr
*                    req_qty    = <fs_item>-quantity
*                    req_date   = lv_sched_date
*                  ) TO lt_sched_in.
*  ENDLOOP.
*  IF lt_item_in IS INITIAL. RETURN. ENDIF.
*
*  " --- 3. Gọi BAPI SIMULATE (Đã sửa) ---
*  CALL FUNCTION 'BAPI_SALESORDER_SIMULATE'
*    EXPORTING
*      order_header_in    = ls_header_in
*    TABLES
*      order_items_in     = lt_item_in
*      order_partners     = lt_partner_in
*      order_schedule_in = lt_sched_in
*      order_items_out    = lt_item_out
*      order_schedule_ex  = lt_sched_out   " (Tên đúng là ORDER_SCHEDULE_EX)
*      order_condition_ex = lt_cond_out    " (Tên đúng là ORDER_CONDITION_EX)
*      order_incomplete   = lt_incomplete
*      messagetable       = lt_return.
*
*  " --- 4. Cập nhật BẢNG NỘI BỘ ALV ---
*  LOOP AT gt_item_details ASSIGNING <fs_item>.
*    lv_posnr = sy-tabix * 10.
*    READ TABLE lt_item_out ASSIGNING <fs_item_out> WITH KEY itm_number = lv_posnr.
*    IF sy-subrc <> 0.
*      CLEAR: <fs_item>-description, <fs_item>-itca,
*             <fs_item>-ship_point, <fs_item>-currency,
*             <fs_item>-conf_qty, <fs_item>-net_price, <fs_item>-net_value,
*             <fs_item>-tax.
*      CONTINUE.
*    ENDIF.
*
*    <fs_item>-item_no     = <fs_item_out>-ITM_NUMBER.
*    <fs_item>-description = <fs_item_out>-short_text.
*    <fs_item>-itca        = <fs_item_out>-item_categ.
*    <fs_item>-currency    = gs_so_heder_ui-so_hdr_waerk.
*    <fs_item>-plant       = <fs_item_out>-plant.       " <<< THÊM MỚI (Sửa lỗi Plant)
*    <fs_item>-unit        = <fs_item_out>-sales_unit.  " <<< THÊM MỚI (Sửa lỗi Sales Unit)
**    <fs_item>-net_price   = <fs_item_out>-net_price.  " Gán Net Price
**    <fs_item>-unit_price  = <fs_item_out>-net_price.  " Gán Net Price vào cột "Amount"
**    <fs_item>-net_value   = <fs_item_out>-net_value.
**    <fs_item>-tax         = <fs_item_out>-tax_val.    " <<< Lấy thuế
**    <fs_item>-per         = <fs_item_out>-cond_p_unt. " <<< Lấy "Per"
*
*    " <<< SỬA: Đọc từ BAPISDHEDU (Tên trường khác) >>>
*    READ TABLE lt_sched_out ASSIGNING <fs_sched_out> WITH KEY itm_number = lv_posnr.
*    IF sy-subrc = 0.
*      <fs_item>-conf_qty = <fs_sched_out>-REQ_QTY. " <<< SỬA: Tên trường là SCHED_QTY
*      IF <fs_item>-req_date IS INITIAL OR <fs_item>-req_date = '00000000'.
*        <fs_item>-req_date = <fs_sched_out>-REQ_DATE. " <<< SỬA: Tên trường là DELIV_DATE
*      ENDIF.
*    ENDIF.
*
*   LOOP AT lt_cond_out ASSIGNING <fs_cond_out> WHERE itm_number = lv_posnr.
*     <fs_item>-cond_type  = <fs_cond_out>-COND_TYPE.  " Gán tên 'ZPT0'
*   ENDLOOP.
*
*
**    " (Logic LOOP AT lt_cond_out... lấy giá... giữ nguyên)
**    <fs_item>-net_price = 0.
**    <fs_item>-net_value = 0.
**    <fs_item>-tax       = 0.
**    LOOP AT lt_cond_out ASSIGNING <fs_cond_out> WHERE itm_number = lv_posnr.
**      CASE <fs_cond_out>-cond_type.
**        WHEN 'NETP' OR 'PR00'.
**          <fs_item>-net_price = <fs_cond_out>-cond_value.
**        WHEN 'NETW'.
**          <fs_item>-net_value = <fs_cond_out>-cond_value.
**        WHEN 'MWST'.
**          <fs_item>-tax = <fs_item>-tax + <fs_cond_out>-cond_value.
**      ENDCASE.
**    ENDLOOP.
*    " (Xóa các lệnh 'ir_data_changed->modify_cell' khỏi đây)
*
*
*  ENDLOOP.
*
*  " --- 5. Tính tổng và cập nhật 2 TRƯỜNG HEADER (Giữ nguyên) ---
*  DATA: lv_total_net TYPE vbap-netwr,
*        lv_total_tax TYPE vbap-mwsbp.
*  CLEAR: lv_total_net, lv_total_tax.
*  LOOP AT gt_item_details ASSIGNING <fs_item>.
*    lv_total_net = lv_total_net + <fs_item>-net_value.
*    lv_total_tax = lv_total_tax + <fs_item>-tax.
*  ENDLOOP.
*
*  gs_so_heder_ui-SO_HDR_TOTAL_NET = lv_total_net.
*  gs_so_heder_ui-SO_HDR_TOTAL_TAX = lv_total_tax.
*
*  " --- 6. Xử lý lỗi (Giữ nguyên) ---
*  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ret>) WHERE type CA 'AEX'.
*    lv_errors_occurred = abap_true.
*    MESSAGE <ret>-message TYPE 'S' DISPLAY LIKE 'E'.
*    EXIT.
*  ENDLOOP.
*
*  IF lv_errors_occurred = abap_false.
*    MESSAGE 'Item details simulated successfully. Totals updated.' TYPE 'S'.
*  ENDIF.
*ENDFORM.


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

  DATA: lt_knvv        TYPE STANDARD TABLE OF knvv,
        ls_knvv        TYPE knvv,
        lt_f4_data     TYPE STANDARD TABLE OF ty_sales_area_f4,
        ls_f4_data     TYPE ty_sales_area_f4,
        lt_fieldcat    TYPE slis_t_fieldcat_alv, " Dùng SLIS
        ls_fieldcat    TYPE slis_fieldcat_alv, " Dùng SLIS
        ls_selfield    TYPE slis_selfield.

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

*&---------------------------------------------------------------------*
*& Form DISPLAY_CONDITIONS_FOR_ITEM (SỬA LỖI ICON - DÙNG LOGIC CỦA BẠN)
*&---------------------------------------------------------------------*
FORM display_conditions_for_item USING iv_item_index TYPE sy-tabix.

  FIELD-SYMBOLS <fs_item> TYPE ty_item_details.
  DATA: ls_header_in  TYPE bapisdhead,
        lt_item_in    TYPE TABLE OF bapiitemin,
        lt_partner_in TYPE TABLE OF bapipartnr,
        lt_sched_in   TYPE TABLE OF bapischdl,
        lt_item_out   TYPE TABLE OF bapiitemex,
        lt_sched_out  TYPE TABLE OF bapisdhedu,
        lt_cond_out   TYPE TABLE OF bapicond,
        lt_return     TYPE TABLE OF bapiret2,
        lt_incomplete TYPE TABLE OF bapiincomp.

  " 1. Đọc Item hiện tại
  READ TABLE gt_item_details ASSIGNING <fs_item> INDEX iv_item_index.
  IF sy-subrc <> 0.
    CLEAR: gs_so_heder_ui-so_hdr_matnr, gs_so_heder_ui-so_hdr_maktx,
           gs_so_heder_ui-so_hdr_fkdat,
           gs_so_heder_ui-so_hdr_total_net, gs_so_heder_ui-so_hdr_total_tax.
    REFRESH gt_conditions_alv.
    IF go_grid_conditions IS BOUND.
      go_grid_conditions->refresh_table_display( ).
    ENDIF.
    EXIT.
  ENDIF.

  " 2. Cập nhật các trường Header
  gs_so_heder_ui-so_hdr_matnr = <fs_item>-matnr.
  gs_so_heder_ui-so_hdr_maktx = <fs_item>-description.
  gs_so_heder_ui-so_hdr_fkdat = sy-datum.
  gs_so_heder_ui-so_hdr_total_net = <fs_item>-net_value.
  gs_so_heder_ui-so_hdr_total_tax = <fs_item>-tax.

  " 3. Chuẩn bị BAPI
  ls_header_in-doc_type   = gs_so_heder_ui-so_hdr_auart.
  ls_header_in-sales_org  = gs_so_heder_ui-so_hdr_vkorg.
  ls_header_in-distr_chan = gs_so_heder_ui-so_hdr_vtweg.
  ls_header_in-division   = gs_so_heder_ui-so_hdr_spart.
  DATA(lv_sold_to) = gs_so_heder_ui-so_hdr_sold_addr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_sold_to IMPORTING output = lv_sold_to.
  APPEND VALUE #( partn_role = 'AG' partn_numb = lv_sold_to ) TO lt_partner_in.
  APPEND VALUE #( partn_role = 'WE' partn_numb = lv_sold_to ) TO lt_partner_in.

  DATA(lv_matnr_bapi) = <fs_item>-matnr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_matnr_bapi IMPORTING output = lv_matnr_bapi.
  APPEND VALUE #( itm_number = <fs_item>-item_no
                  material   = lv_matnr_bapi
                  plant      = <fs_item>-plant
                  store_loc  = <fs_item>-store_loc
                ) TO lt_item_in.
  APPEND VALUE #( itm_number = <fs_item>-item_no
                  req_qty    = <fs_item>-quantity
                  req_date   = <fs_item>-req_date
                ) TO lt_sched_in.

*   " === THÊM LẠI: Gửi giá trị thủ công (từ "bộ nhớ") đến BAPI ===
*  REFRESH lt_cond_in.
*  IF <fs_item>-cond_type IS NOT INITIAL AND <fs_item>-unit_price IS NOT INITIAL.
*    APPEND VALUE #(
*      itm_number = <fs_item>-item_no
*      cond_type  = <fs_item>-cond_type
*      cond_value = <fs_item>-unit_price " Gửi giá 200
*      currency   = <fs_item>-currency
*    ) TO lt_cond_in.
*  ENDIF.
*  " === KẾT THÚC THÊM ===

  " 5. Gọi BAPI (Đã xóa order_conditions_in)
  CALL FUNCTION 'BAPI_SALESORDER_SIMULATE'
    EXPORTING
      order_header_in     = ls_header_in
    TABLES
      order_items_in      = lt_item_in
      order_partners      = lt_partner_in
      order_schedule_in  = lt_sched_in
      order_items_out     = lt_item_out
      order_schedule_ex   = lt_sched_out
      order_condition_ex  = lt_cond_out
      order_incomplete    = lt_incomplete
      messagetable        = lt_return.


    " 6. Xử lý kết quả (Chỉ LOOP lt_cond_out)
  REFRESH gt_conditions_alv.
  DATA: ls_cond_alv TYPE ty_cond_alv.
  DATA: lv_icon_active   TYPE icon-internal,
        lv_icon_inactive TYPE icon-internal.
  SELECT SINGLE internal INTO lv_icon_active FROM icon WHERE name = gc_icon_green.
  SELECT SINGLE internal INTO lv_icon_inactive FROM icon WHERE name = gc_icon_red.

  DATA: lv_base_value TYPE kwert, " (Biến tạm lưu Cond. Value của ZPRQ)
        lv_tax_rate   TYPE bapicond-cond_value.

  " --- [LOGIC ĐƠN GIẢN MỚI] ---
  LOOP AT lt_cond_out ASSIGNING FIELD-SYMBOL(<fs_cond_out>).
    " (Chỉ hiển thị ZPRQ và ZTAX như bug11.png)
    IF <fs_cond_out>-cond_type <> 'ZPRQ' AND <fs_cond_out>-cond_type <> 'ZTAX'.
      CONTINUE.
    ENDIF.

    CLEAR ls_cond_alv.
    ls_cond_alv-kschl = <fs_cond_out>-cond_type.

    " Lấy Description (VTEXT)
    SELECT SINGLE vtext FROM t685t INTO ls_cond_alv-vtext
      WHERE spras = sy-langu AND kschl = <fs_cond_out>-cond_type.

    " === SỬA LỖI HIỂN THỊ (Lỗi 1, 2 - bug9.png vs bug11.png) ===
    ls_cond_alv-amount     = <fs_cond_out>-cond_value. " (8.00)
    ls_cond_alv-waers      = <fs_cond_out>-currency.   " (VND)
    IF <fs_cond_out>-cond_unit IS NOT INITIAL.
       ls_cond_alv-waers = <fs_cond_out>-cond_unit. " Gán '%'
    ENDIF.
    ls_cond_alv-kpein      = <fs_cond_out>-cond_p_unt. " (1)
    ls_cond_alv-kmein      = <fs_cond_out>-cond_unit.  " (EA)
    " (Không gán cond_value từ BAPI nữa)
    " === KẾT THÚC SỬA ===

    IF <fs_cond_out>-condisacti = 'X'.
      ls_cond_alv-icon = lv_icon_inactive.
    ELSE.
      ls_cond_alv-icon = lv_icon_active.
    ENDIF.

    " === LOGIC TÍNH TOÁN & HIỂN THỊ (Yêu cầu 3) ===

    " (A) Xử lý ZPRQ (Giá chính)
    IF ls_cond_alv-kschl = 'ZPRQ'. " (Hoặc ZPT0)
      IF <fs_item>-cond_type = ls_cond_alv-kschl.
         " User đã nhập tay -> Ưu tiên
         ls_cond_alv-amount = <fs_item>-unit_price.
         ls_cond_alv-icon = lv_icon_active.
      ENDIF.
      " Tính Cond. Value (Qty * Amount)
      ls_cond_alv-cond_value = <fs_item>-quantity * ls_cond_alv-amount.
      lv_base_value = ls_cond_alv-cond_value. " Lưu lại (ví dụ 40,000)
    ENDIF.

    " (B) Xử lý ZTAX (Thuế)
    IF ls_cond_alv-kschl = 'ZTAX'.
      lv_tax_rate = ls_cond_alv-amount / 100. " (8.00% -> 0.08)
      " Tính Cond. Value (Base * Tax Rate)
      ls_cond_alv-cond_value = lv_base_value * lv_tax_rate. " (40,000 * 0.08 = 3,200)
      ls_cond_alv-icon = lv_icon_active.
    ENDIF.

    APPEND ls_cond_alv TO gt_conditions_alv.
  ENDLOOP.

  " 7. Refresh ALV
  IF go_grid_conditions IS BOUND.
    go_grid_conditions->refresh_table_display( ).
  ENDIF.

  " 8. [SỬA] Cập nhật Tiêu đề ALV (Lỗi "0 rows")
  IF go_grid_conditions IS BOUND.
    DATA(lv_rows) = lines( gt_conditions_alv ).
    go_grid_conditions->set_gridtitle( |Pricing Elements ({ lv_rows } rows)| ).
  ENDIF.

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

  DATA: lt_join   TYPE STANDARD TABLE OF zsd4_so_monitoring,
        ls_join   TYPE zsd4_so_monitoring,
        ls_vbuk   TYPE vbuk,
        lv_name1  TYPE kna1-name1,
        ls_data   TYPE zsd4_so_monitoring.

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
           vbeln TYPE vbak-vbeln,
           auart TYPE vbak-auart,
           erdat TYPE vbak-erdat,
           vdatu TYPE vbak-vdatu,
           vkorg TYPE vbak-vkorg,
           vtweg TYPE vbak-vtweg,
           spart TYPE vbak-spart,
           kunnr TYPE vbak-kunnr,
           name1 TYPE kna1-name1,
           posnr TYPE vbap-posnr,
           matnr TYPE vbap-matnr,
           kwmeng TYPE vbap-kwmeng,
           vrkme TYPE vbap-vrkme,
           netwr TYPE vbap-netwr,
           waerk TYPE vbak-waerk,
           abgru TYPE vbap-abgru, " Reason for rejection (Item)
         END OF ty_join_result.

  DATA: lt_join_result TYPE STANDARD TABLE OF ty_join_result.
  DATA: ls_monitoring  TYPE zsd4_so_monitoring.

  " --- 1. Xóa dữ liệu cũ & Reset tổng ---
  REFRESH gt_monitoring_data.
  CLEAR: toso, to_val, to_sta. " (Dùng tên biến global từ Screen 600)

  " --- 2. Xây dựng WHERE clause (Dynamic) ---
  DATA: lt_range_erdat  TYPE RANGE OF vbak-erdat,
        lt_range_vbeln  TYPE RANGE OF vbak-vbeln,
        lt_range_kunnr  TYPE RANGE OF vbak-kunnr,
        lt_range_matnr  TYPE RANGE OF vbap-matnr,
        lt_range_vkorg  TYPE RANGE OF vbak-vkorg,
        lt_range_vtweg  TYPE RANGE OF vbak-vtweg,
        lt_range_spart  TYPE RANGE OF vbak-spart.

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
      EXPORTING input = sales_ord IMPORTING output = sales_ord.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = sales_ord ) TO lt_range_vbeln.
  ENDIF.
  IF sold_to IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = sold_to IMPORTING output = sold_to.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = sold_to ) TO lt_range_kunnr.
  ENDIF.
  IF material IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = material IMPORTING output = material.
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
  DATA: ls_gm_header  TYPE bapi2017_gm_head_01,
        ls_gm_code    TYPE bapi2017_gm_code,
        lt_gm_item    TYPE TABLE OF bapi2017_gm_item_create,
        ls_gm_item    TYPE bapi2017_gm_item_create,
        lv_gm_docno   TYPE mblnr,
        lv_gm_docyear TYPE mjahr,
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

*&---------------------------------------------------------------------*
*& Form DISPLAY_ERROR_LOG_POPUP (Hiển thị lỗi PGI)
*&---------------------------------------------------------------------*
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
      ( col_idx = 10 col_name = '*REQUESTED DELIVERY DATE' )
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

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DEFINE_GOLDEN_TEMPLATES (Task 3.3 - Đã thêm Schedule Line Date)
*&---------------------------------------------------------------------*
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

  " Convert số sang text để nối chuỗi
  WRITE gv_cnt_val_ready   TO txt_val_rdy.   CONDENSE txt_val_rdy.
  WRITE gv_cnt_val_incomp  TO txt_val_inc.   CONDENSE txt_val_inc.
  WRITE gv_cnt_val_err     TO txt_val_err.   CONDENSE txt_val_err.
  WRITE gv_cnt_suc_comp    TO txt_suc_comp.  CONDENSE txt_suc_comp.
  WRITE gv_cnt_suc_incomp  TO txt_suc_inc.   CONDENSE txt_suc_inc.
  WRITE gv_cnt_fail_err    TO txt_fail_err.  CONDENSE txt_fail_err.

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

*&---------------------------------------------------------------------*
*& Form SAVE_RAW_TO_STAGING (Đã sửa lỗi DELETE và Tên Bảng)
*&---------------------------------------------------------------------*
FORM save_raw_to_staging
  USING
    iv_mode       TYPE c
    iv_req_id_new TYPE zsd_req_id
    it_header_raw TYPE STANDARD TABLE
    it_item_raw   TYPE STANDARD TABLE
    it_cond_raw   TYPE STANDARD TABLE. " [MỚI]

  " (SỬA: Dùng tên bảng đúng HD/IT)
  DATA: ls_header TYPE ztb_so_upload_hd,
        ls_item   TYPE ztb_so_upload_it,
        lt_header_db TYPE TABLE OF ztb_so_upload_hd,
        lt_item_db   TYPE TABLE OF ztb_so_upload_it.
  DATA: ls_cond TYPE ztb_so_upload_pr,
        lt_cond_db TYPE TABLE OF ztb_so_upload_pr.

  DATA: lt_req_ids_to_delete TYPE TABLE OF zsd_req_id.
  " (THÊM: Biến Range để xóa dữ liệu)
  DATA: lr_req_id TYPE RANGE OF zsd_req_id,
        ls_req_range LIKE LINE OF lr_req_id.

  " 1. Chuẩn bị dữ liệu Header
  LOOP AT it_header_raw ASSIGNING FIELD-SYMBOL(<fs_h>).
    MOVE-CORRESPONDING <fs_h> TO ls_header.

    IF iv_mode = 'NEW'.
      ls_header-req_id = iv_req_id_new.
    ELSE.
      " Resubmit: Lấy ID từ file, đưa vào danh sách xóa
      APPEND ls_header-req_id TO lt_req_ids_to_delete.
    ENDIF.

    ls_header-status = 'NEW'.
    ls_header-created_by = sy-uname.
    ls_header-created_on = sy-datum.
    APPEND ls_header TO lt_header_db.
  ENDLOOP.

  " 2. Chuẩn bị dữ liệu Item
  LOOP AT it_item_raw ASSIGNING FIELD-SYMBOL(<fs_i>).
    MOVE-CORRESPONDING <fs_i> TO ls_item.

    IF iv_mode = 'NEW'.
      ls_item-req_id = iv_req_id_new.
    ELSE.
      APPEND ls_item-req_id TO lt_req_ids_to_delete.
    ENDIF.

    ls_item-status = 'NEW'.
    ls_item-created_by = sy-uname.
    ls_item-created_on = sy-datum.
    APPEND ls_item TO lt_item_db.
  ENDLOOP.

  " --- 3. Chuẩn bị dữ liệu Condition ---
  LOOP AT it_cond_raw ASSIGNING FIELD-SYMBOL(<fs_c>).
    MOVE-CORRESPONDING <fs_c> TO ls_cond.
    IF iv_mode = 'NEW'.
       ls_cond-req_id = iv_req_id_new.
    ENDIF.
    ls_cond-status = 'NEW'.
    ls_cond-created_by = sy-uname.
    ls_cond-created_on = sy-datum.
    APPEND ls_cond TO lt_cond_db.
  ENDLOOP.

  " --- 4. Xóa data cũ (Resubmit) ---
  IF iv_mode = 'RESUBMIT'.
    SORT lt_req_ids_to_delete.
    DELETE ADJACENT DUPLICATES FROM lt_req_ids_to_delete.

    IF lt_req_ids_to_delete IS NOT INITIAL.
      " Tạo Range Table (WHERE req_id IN ...)
      REFRESH lr_req_id.
      ls_req_range-sign   = 'I'.
      ls_req_range-option = 'EQ'.
      LOOP AT lt_req_ids_to_delete INTO DATA(lv_del_id).
        ls_req_range-low = lv_del_id.
        APPEND ls_req_range TO lr_req_id.
      ENDLOOP.

      " Thực hiện xóa bằng Range (Cú pháp chuẩn)
      DELETE FROM ztb_so_upload_hd WHERE req_id IN @lr_req_id.
      DELETE FROM ztb_so_upload_it WHERE req_id IN @lr_req_id.
      DELETE FROM ztb_so_upload_pr WHERE req_id IN @lr_req_id.
      DELETE FROM ztb_so_error_log WHERE req_id IN @lr_req_id.
    ENDIF.
  ENDIF.

  " 4. Insert mới (SỬA: Tên bảng HD/IT)
  INSERT ztb_so_upload_hd FROM TABLE @lt_header_db.
  INSERT ztb_so_upload_it FROM TABLE @lt_item_db.
  INSERT ztb_so_upload_pr FROM TABLE @lt_cond_db. " [MỚI]

  COMMIT WORK.

  MESSAGE |Data saved to Staging. { lines( lt_header_db ) } Headers, { lines( lt_item_db ) } Items.| TYPE 'S'.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM 6: VALIDATE_STAGING_DATA (Final Corrected Version)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form VALIDATE_STAGING_DATA (Header + Item + Pricing)
*&---------------------------------------------------------------------*
FORM validate_staging_data USING iv_req_id TYPE zsd_req_id.

  DATA: lt_header TYPE TABLE OF ztb_so_upload_hd,
        lt_item   TYPE TABLE OF ztb_so_upload_it,
        lt_cond   TYPE TABLE OF ztb_so_upload_pr. " [MỚI] Bảng Pricing

  DATA: lt_errors_total TYPE ztty_validation_error.

  " --- 1. Đọc dữ liệu từ Staging ---
  SELECT * FROM ztb_so_upload_hd INTO TABLE lt_header WHERE req_id = iv_req_id.

  IF sy-subrc <> 0.
    MESSAGE 'No data found in Staging table to validate.' TYPE 'S' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

  SELECT * FROM ztb_so_upload_it INTO TABLE lt_item WHERE req_id = iv_req_id.
  SELECT * FROM ztb_so_upload_pr INTO TABLE lt_cond WHERE req_id = iv_req_id. " [MỚI]

  " --- 2. Thiết lập Class Validator ---
  " Truyền REQ_ID vào context và xóa lỗi cũ
  CALL METHOD zcl_sd_mass_validator=>set_context( iv_req_id ).
  CALL METHOD zcl_sd_mass_validator=>clear_errors.

  " ====================================================================
  " A. VALIDATE HEADER
  " ====================================================================
  LOOP AT lt_header ASSIGNING FIELD-SYMBOL(<fs_header>).
    CALL METHOD zcl_sd_mass_validator=>execute_validation_hdr
      CHANGING cs_header = <fs_header>.

    UPDATE ztb_so_upload_hd FROM <fs_header>.
  ENDLOOP.

  " ====================================================================
  " B. VALIDATE ITEM
  " ====================================================================
  LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).

    " Tìm Header cha
    READ TABLE lt_header ASSIGNING FIELD-SYMBOL(<fs_header_parent>)
      WITH KEY temp_id = <fs_item>-temp_id.

    IF sy-subrc <> 0.
      " Mất Header -> Lỗi Item
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
  " C. VALIDATE CONDITION [MỚI]
  " ====================================================================
  LOOP AT lt_cond ASSIGNING FIELD-SYMBOL(<fs_cond>).

    " (Tùy chọn: Kiểm tra xem Item cha có tồn tại không, tương tự như Item check Header)
    " Ở đây ta gọi validate trực tiếp

    CALL METHOD zcl_sd_mass_validator=>execute_validation_prc
      CHANGING cs_pricing = <fs_cond>.

    UPDATE ztb_so_upload_pr FROM <fs_cond>.
  ENDLOOP.

  " ====================================================================
  " D. LƯU LOG & COMMIT
  " ====================================================================
  " Lấy TẤT CẢ lỗi (Header + Item + Condition) từ Class
  lt_errors_total = zcl_sd_mass_validator=>get_errors( ).

  " Lưu vào bảng ZTB_SO_ERROR_LOG
  CALL METHOD zcl_sd_mass_logger=>save_errors_to_db
    EXPORTING
      it_errors = lt_errors_total.

  COMMIT WORK.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form LOAD_STAGING_FROM_DB (Logic RESUME - Sửa lỗi tham số)
*&---------------------------------------------------------------------*
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


      " === TAB 2: SUCCESS ===
      WHEN 'SUCCESS' OR 'POSTED'.
        " Logic Delivery Check
        IF ls_hd_db-vbeln_dlv IS NOT INITIAL.
          ls_hd_alv-icon = icon_led_green.
        ELSE.
          ls_hd_alv-icon = icon_led_yellow.
        ENDIF.
        ls_hd_alv-err_btn = ' '. " Success không có lỗi

        APPEND ls_hd_alv TO gt_hd_suc.

        LOOP AT lt_it INTO ls_it_db WHERE temp_id = ls_hd_db-temp_id.
           MOVE-CORRESPONDING ls_it_db TO ls_it_alv.
           ls_it_alv-icon = icon_led_green.
           ls_it_alv-err_btn = ' '.
           APPEND ls_it_alv TO gt_it_suc.
        ENDLOOP.
        LOOP AT lt_pr INTO ls_pr_db WHERE temp_id = ls_hd_db-temp_id.
           MOVE-CORRESPONDING ls_pr_db TO ls_pr_alv.
           ls_pr_alv-icon = icon_led_green.
           ls_pr_alv-err_btn = ' '.
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

  ls_spopli-varoption = '2. Resubmit error file'.
  APPEND ls_spopli TO lt_spopli.

  ls_spopli-varoption = '3. Resume unfinished upload'.
  APPEND ls_spopli TO lt_spopli.

  " 2. Gọi Popup chuẩn (Giống nhóm CRP)
  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel          = 'Select Upload Mode'
      textline1      = 'Please choose how you want to proceed:'
      cursorline     = 1
      display_only   = space
    IMPORTING
      answer         = lv_answer
    TABLES
      t_spopli       = lt_spopli
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_many_lines     = 3
      others             = 4.

  " 3. Xử lý kết quả trả về
  IF sy-subrc = 0 AND lv_answer <> 'A'. " 'A' là Cancel
    CASE lv_answer.
      WHEN '1'. cv_mode = 'N'. " New
      WHEN '2'. cv_mode = 'R'. " Resubmit
      WHEN '3'. cv_mode = 'C'. " Continue (Resume)
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
  ls_spopli-varoption = '3. Search & Process Orders'.
  APPEND ls_spopli TO lt_spopli.

  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      titel      = 'Manage Sales Order'
      textline1  = 'Please select an action:'
      cursorline = 1
      display_only = space
    IMPORTING
      answer     = cv_answer
    TABLES
      t_spopli   = lt_spopli
    EXCEPTIONS
      others     = 1.
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
      others     = 1.
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
      others     = 1.
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
  " Ensure the container & HTML viewer are created
  "--------------------------------------------------------------------
  IF go_summary_container IS INITIAL.
    CREATE OBJECT go_summary_container
      EXPORTING
        container_name = 'CC_SUMMARY'.      " Custom Control name on screen 0200
  ENDIF.

  IF go_html_viewer IS INITIAL.
    CREATE OBJECT go_html_viewer
      EXPORTING
        parent = go_summary_container.
  ENDIF.

  "--------------------------------------------------------------------
  " 1. Build Premium HTML for Welcome Screen
  "--------------------------------------------------------------------
  CLEAR lv_html.

  CONCATENATE lv_html
    '<html><head><meta charset="UTF-8"><style>'

    'body { font-family: Segoe UI, Arial; padding:16px; background-color:#fafafa; }'
    'h2 { color:#1a73e8; margin-bottom:8px; font-size:20px; font-weight:600; }'
    'p.subtitle { color:#555; font-size:13px; margin-top:0; margin-bottom:14px; }'

    '.welcome-card { background:#ffffff; padding:14px 18px;'
      'border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,0.10);'
      'border:1px solid #e3e3e3; max-width:520px; }'

    '.row { display:flex; gap:10px; margin-top:8px; }'
    '.step { flex:1; background:#f8f9fb; padding:8px 10px; border-radius:8px;'
      'border:1px solid #e1e4ea; }'

    '.step-title { font-size:13px; font-weight:600; color:#333; margin-bottom:4px; }'
    '.step-text { font-size:12px; color:#555; margin:0; }'

    '.hint { font-size:12px; color:#777; margin-top:10px; }'
    '.badge { display:inline-block; padding:2px 6px; border-radius:8px;'
      'font-size:11px; background:#e8f0fe; color:#1a73e8; margin-right:4px; }'

    '</style></head><body>'

    '<h2>Mass Sales Order Upload</h2>'

    '<div class="welcome-card">'
      '<p class="subtitle">No data has been uploaded yet. Please follow the 3 simple steps below to start the Mass Sales Order Upload process.</p>'

      '<div class="row">'

        '<div class="step">'
          '<div class="step-title">① Upload Excel File</div>'
          '<p class="step-text">Choose a mode (<b>NEW</b>, <b>RESUBMIT</b>, <b>RESUME</b>) and upload your completed Excel template.</p>'
        '</div>'

        '<div class="step">'
          '<div class="step-title">② Validate &amp; Correct Data</div>'
          '<p class="step-text">The system will load data into staging tables, validate each record and highlight <b>Incomplete</b> or <b>Error</b> rows.</p>'
        '</div>'

        '<div class="step">'
          '<div class="step-title">③ Create Sales Orders &amp; Deliveries</div>'
          '<p class="step-text">All <b>Complete</b> records will be used to generate Sales Orders, Deliveries and Billing documents.</p>'
        '</div>'

      '</div>'

      '<p class="hint">'
        '<span class="badge">Tip</span>'
        'Click the <b>Upload</b> button in the Application Bar to start. '
        'Once uploaded, the Validation Summary and 3 result tabs will appear.'
      '</p>'

    '</div>'

    '</body></html>'
  INTO lv_html SEPARATED BY space.

  "--------------------------------------------------------------------
  " 2. Convert STRING → W3HTML safely (no FM, supports all SAP systems)
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
  " 3. Display HTML content in the viewer
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

ENDFORM.                    " display_welcome_screen
      " display_welcome_screen

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

  " 3. Sync Condition
  LOOP AT gt_pr_val INTO DATA(ls_val_p).
    MOVE-CORRESPONDING ls_val_p TO ls_pr_db.
    UPDATE ztb_so_upload_pr FROM ls_pr_db.
  ENDLOOP.
  LOOP AT gt_pr_fail INTO DATA(ls_fail_p).
    MOVE-CORRESPONDING ls_fail_p TO ls_pr_db.
    UPDATE ztb_so_upload_pr FROM ls_pr_db.
  ENDLOOP.

  COMMIT WORK.
ENDFORM.

**&---------------------------------------------------------------------*
**& Form EXPORT_ERROR_FIXPACK (Fixed Version)
**&---------------------------------------------------------------------*
*FORM export_error_fixpack.
*  " --- 1. Khai báo biến ---
*  DATA: lo_excel      TYPE REF TO zcl_excel,
*        lo_worksheet  TYPE REF TO zcl_excel_worksheet,
*        lo_writer     TYPE REF TO zif_excel_writer,
*        lv_xstring    TYPE xstring,
*        lv_path       TYPE string,
*        lv_action     TYPE i.
*
*  " Style Objects
*  DATA: lo_style_hdr  TYPE REF TO zcl_excel_style,
*        lo_style_err  TYPE REF TO zcl_excel_style,
*        lo_style_warn TYPE REF TO zcl_excel_style,
*        lo_style_lock TYPE REF TO zcl_excel_style.
*
*  " Comment Object
*  DATA: lo_comment    TYPE REF TO zcl_excel_comment.
*
*  DATA: lt_error_log TYPE TABLE OF ztb_so_error_log.
*
*  " --- 2. Lấy dữ liệu Log ---
*  SELECT * FROM ztb_so_error_log
*    INTO TABLE lt_error_log
*    WHERE req_id = gv_current_req_id.
*
*  IF lt_error_log IS INITIAL.
*    MESSAGE 'No errors found to export.' TYPE 'S' DISPLAY LIKE 'W'.
*    RETURN.
*  ENDIF.
*
*  " --- 3. Khởi tạo Excel Object ---
*  CREATE OBJECT lo_excel.
*
*  " --- 4. Định nghĩa Styles (Dùng mã màu trực tiếp để tránh lỗi) ---
*
*  " Style 1: Header Row (Xanh đậm, Chữ trắng)
*  lo_style_hdr = lo_excel->add_new_style( ).
*  lo_style_hdr->font->bold = abap_true.
*  lo_style_hdr->font->color-rgb = 'FFFFFFFF'.
*  lo_style_hdr->fill->filltype = 'solid'.
*  lo_style_hdr->fill->fgcolor-rgb = 'FF0070C0'.
*
*  " Style 2: Error Cell (Đỏ nhạt)
*  lo_style_err = lo_excel->add_new_style( ).
*  lo_style_err->fill->filltype = 'solid'.
*  lo_style_err->fill->fgcolor-rgb = 'FFFFCCCC'.
*
*  " Style 3: Warning/Incomplete Cell (Vàng nhạt)
*  lo_style_warn = lo_excel->add_new_style( ).
*  lo_style_warn->fill->filltype = 'solid'.
*  lo_style_warn->fill->fgcolor-rgb = 'FFFFFFCC'.
*
*  " Style 4: Locked Column (Xám nhạt)
*  lo_style_lock = lo_excel->add_new_style( ).
*  lo_style_lock->fill->filltype = 'solid'.
*  " [SỬA LỖI]: Dùng mã Hex thay vì hằng số C_GRAY_25_PERCENT
*  lo_style_lock->fill->fgcolor-rgb = 'FFC0C0C0'.
*  lo_style_lock->protection->locked = abap_true.
*
*  " ====================================================================
*  " SHEET 1: HEADER ERRORS
*  " ====================================================================
*
*  " 1. Lấy Worksheet đầu tiên
*  lo_worksheet = lo_excel->get_active_worksheet( ).
*  lo_worksheet->set_title( 'Header Errors' ).
*
*  " [SỬA LỖI]: Dùng method SET_TABCOLOR
*  lo_worksheet->set_tabcolor( 'FFFF0000' ). " Màu đỏ
*
*  " 2. Lấy dữ liệu Header bị lỗi
*  SELECT * FROM ztb_so_upload_hd
*    INTO TABLE @DATA(lt_hd_err)
*    WHERE req_id = @gv_current_req_id
*      AND ( status = 'ERROR' OR status = 'INCOMP' OR status = 'FAILED' ).
*
*  " 3. Định nghĩa Cấu trúc Cột (Mapping)
*  TYPES: BEGIN OF ty_map,
*           col_idx   TYPE i,
*           col_name  TYPE string,
*           fieldname TYPE fieldname,
*         END OF ty_map.
*  DATA: lt_map_hdr TYPE TABLE OF ty_map.
*
*  " (Cấu trúc này phải khớp với Template Header mới của bạn)
*  lt_map_hdr = VALUE #(
*    ( col_idx = 1  col_name = 'TEMP ID'                  fieldname = 'TEMP_ID' )
*    ( col_idx = 2  col_name = '*SALES ORDER TYPE'        fieldname = 'ORDER_TYPE' )
*    ( col_idx = 3  col_name = '*SALES ORG.'              fieldname = 'SALES_ORG' )
*    ( col_idx = 4  col_name = '*DIST. CHNL'              fieldname = 'SALES_CHANNEL' )
*    ( col_idx = 5  col_name = '*DIVISION'                fieldname = 'SALES_DIV' )
*    ( col_idx = 6  col_name = 'SALES OFFICE'             fieldname = 'SALES_OFF' )
*    ( col_idx = 7  col_name = 'SALES GROUP'              fieldname = 'SALES_GRP' )
*    ( col_idx = 8  col_name = '*SOLD-TO PARTY'           fieldname = 'SOLD_TO_PARTY' )
*    ( col_idx = 9  col_name = '*CUST. REF.'              fieldname = 'CUST_REF' )
*    ( col_idx = 10 col_name = '*REQUESTED DELIVERY DATE' fieldname = 'REQ_DATE' )
*    ( col_idx = 11 col_name = 'PAYT. TERM'               fieldname = 'PMNTTRMS' )
*    ( col_idx = 12 col_name = 'INCOTERM'                 fieldname = 'INCOTERMS' )
*    ( col_idx = 13 col_name = 'INCOTERM-LOCATION'        fieldname = 'INCO2' )
*  ).
*
*  " 4. Vẽ Dòng Tiêu Đề
*  LOOP AT lt_map_hdr INTO DATA(ls_map).
*    lo_worksheet->set_cell( ip_row = 1 ip_column = ls_map-col_idx ip_value = ls_map-col_name ip_style = lo_style_hdr->get_guid( ) ).
*    lo_worksheet->set_column_width( ip_column = ls_map-col_idx ip_width_fix = 20 ).
*  ENDLOOP.
*
*  " [SỬA LỖI]: Dùng IP_NUM_ROWS thay vì IP_ROW
*  lo_worksheet->freeze_panes( ip_num_rows = 1 ip_num_columns = 1 ).
*
*  " 5. Đổ Dữ liệu & Tô Màu Lỗi
*  DATA: lv_row_idx TYPE i VALUE 2.
*
*  LOOP AT lt_hd_err INTO DATA(ls_hd_row).
*
*    LOOP AT lt_map_hdr INTO ls_map.
*      " A. Gán Giá trị
*      ASSIGN COMPONENT ls_map-fieldname OF STRUCTURE ls_hd_row TO FIELD-SYMBOL(<fv_val>).
*      IF <fv_val> IS ASSIGNED.
*        lo_worksheet->set_cell( ip_row = lv_row_idx ip_column = ls_map-col_idx ip_value = <fv_val> ).
*      ENDIF.
*
*      " B. Check Lỗi & Tô màu
*      READ TABLE lt_error_log ASSIGNING FIELD-SYMBOL(<fs_log>)
*        WITH KEY req_id    = ls_hd_row-req_id
*                 temp_id   = ls_hd_row-temp_id
*                 item_no   = '000000'            " Header
*                 fieldname = ls_map-fieldname.
*
*      IF sy-subrc = 0.
*        " 1. Set Style (Đỏ/Vàng)
*        IF <fs_log>-msg_type = 'E'.
*          lo_worksheet->set_cell_style( ip_row = lv_row_idx ip_column = ls_map-col_idx ip_style = lo_style_err->get_guid( ) ).
*        ELSE.
*          lo_worksheet->set_cell_style( ip_row = lv_row_idx ip_column = ls_map-col_idx ip_style = lo_style_warn->get_guid( ) ).
*        ENDIF.
*
*        " 2. [SỬA LỖI]: Thêm Comment đúng cách
*        CREATE OBJECT lo_comment.
*        " [SỬA LỖI]: Convert sang string để khớp type
*        lo_comment->set_text( ip_text = CONV string( <fs_log>-message ) ).
*
*        " [SỬA LỖI]: Dùng ADD_COMMENT thay vì ADD_COMMENT_AT_CELL
*        lo_worksheet->add_comment(
*            ip_row     = lv_row_idx
*            ip_column  = ls_map-col_idx
*            ip_comment = lo_comment ).
*
*        " (Bỏ set_height/width để tránh lỗi version)
*      ENDIF.
*
*    ENDLOOP.
*    lv_row_idx = lv_row_idx + 1.
*  ENDLOOP.
*
*  " --- 6. Xuất File (Download) ---
*  CREATE OBJECT lo_writer TYPE zcl_excel_writer_2007.
*  lv_xstring = lo_writer->write_file( lo_excel ).
*
*  CALL METHOD cl_gui_frontend_services=>file_save_dialog
*    EXPORTING
*      default_extension = 'xlsx'
*      default_file_name = 'SO_Error_FixPack.xlsx'
*    CHANGING
*      fullpath          = lv_path
*      user_action       = lv_action
*    EXCEPTIONS OTHERS   = 4.
*
*  IF lv_action <> cl_gui_frontend_services=>action_cancel.
*    " Convert & Download
*    DATA: lt_raw TYPE solix_tab, lv_len TYPE i.
*    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
*      EXPORTING buffer = lv_xstring
*      IMPORTING output_length = lv_len
*      TABLES binary_tab = lt_raw.
*
*    CALL METHOD cl_gui_frontend_services=>gui_download
*      EXPORTING bin_filesize = lv_len filename = lv_path filetype = 'BIN'
*      TABLES data_tab = lt_raw.
*  ENDIF.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form SHOW_ERROR_DETAILS_POPUP
*&---------------------------------------------------------------------*
*FORM show_error_details_popup USING iv_temp_id TYPE char10
*                                    iv_item_no TYPE posnr_va.
*
*  DATA: lt_logs TYPE TABLE OF ztb_so_error_log.
*  DATA: lo_alv  TYPE REF TO cl_salv_table.
*
*  " 1. Tìm lỗi trong DB (Dựa vào Key dòng đang chọn)
*  " (Lấy cả lỗi Header và lỗi Item nếu cần, hoặc chỉ lỗi của dòng đó)
*
*  IF iv_item_no = '000000'. " Nếu click ở Header
*    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
*      WHERE req_id  = gv_current_req_id
*        AND temp_id = iv_temp_id
*        AND item_no = '000000'. " Chỉ lấy lỗi Header
*  ELSE. " Nếu click ở Item
*    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
*      WHERE req_id  = gv_current_req_id
*        AND temp_id = iv_temp_id
*        AND item_no = iv_item_no.
*  ENDIF.
*
*  " 2. Xử lý nếu không có lỗi
*  IF lt_logs IS INITIAL.
*    MESSAGE 'No errors found for this row.' TYPE 'S'.
*    RETURN.
*  ENDIF.
*
*  " 3. Hiển thị Popup bằng SALV (Gọn nhẹ, đẹp)
*  TRY.
*      cl_salv_table=>factory(
*        IMPORTING r_salv_table = lo_alv
*        CHANGING  t_table      = lt_logs ).
*
*      " Cấu hình Popup
*      lo_alv->set_screen_popup(
*        start_column = 10
*        end_column   = 100
*        start_line   = 5
*        end_line     = 20 ).
*
*      " Tối ưu cột (Chỉ hiện Field và Message)
*      DATA(lo_cols) = lo_alv->get_columns( ).
*      lo_cols->set_optimize( abap_true ).
*
*      " Ẩn các cột không cần thiết (ReqID, TempID...) cho gọn
*      lo_cols->get_column( 'MANDT' )->set_visible( abap_false ).
*      lo_cols->get_column( 'REQ_ID' )->set_visible( abap_false ).
*      lo_cols->get_column( 'TEMP_ID' )->set_visible( abap_false ).
*      lo_cols->get_column( 'ITEM_NO' )->set_visible( abap_false ).
*      lo_cols->get_column( 'LOG_USER' )->set_visible( abap_false ).
*      lo_cols->get_column( 'LOG_DATE' )->set_visible( abap_false ).
*      lo_cols->get_column( 'STATUS' )->set_visible( abap_false ).
*
*      " Đổi tên cột cho dễ hiểu
*      lo_cols->get_column( 'FIELDNAME' )->set_long_text( 'Field Name' ).
*      lo_cols->get_column( 'MSG_TYPE' )->set_long_text( 'Type' ).
*      lo_cols->get_column( 'MESSAGE' )->set_long_text( 'Error Message Description' ).
*
*      lo_alv->display( ).
*
*    CATCH cx_salv_msg.
*  ENDTRY.
*
*ENDFORM.
*FORM show_error_details_popup
*  USING iv_req_id  TYPE zsd_req_id
*        iv_temp_id TYPE char10
*        iv_item_no TYPE posnr_va.
*
*  DATA: lt_logs TYPE TABLE OF ztb_so_error_log.
*  DATA: lo_alv  TYPE REF TO cl_salv_table.
*
*  " 1. Tìm lỗi trong DB
*  " [CẢI TIẾN]: Nếu click vào Header (000000), ta hiển thị TẤT CẢ lỗi của đơn hàng đó
*  " (Bao gồm cả lỗi Header và lỗi của các Item con) -> Giúp user dễ debug hơn.
*
*  IF iv_item_no = '000000' OR iv_item_no IS INITIAL.
*    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
*      WHERE req_id  = iv_req_id
*        AND temp_id = iv_temp_id.
*        " (Bỏ điều kiện item_no để lấy hết cả con)
*  ELSE.
*    " Nếu click vào Item cụ thể -> Chỉ hiện lỗi của Item đó
*    SELECT * FROM ztb_so_error_log INTO TABLE lt_logs
*      WHERE req_id  = iv_req_id
*        AND temp_id = iv_temp_id
*        AND item_no = iv_item_no.
*  ENDIF.
*
*  " 2. Xử lý nếu không có lỗi (Debug Trap)
*  IF lt_logs IS INITIAL.
*    " Hiển thị thông báo chi tiết để biết tại sao không tìm thấy (giúp debug)
*    MESSAGE |No errors found for Key: { iv_req_id }-{ iv_temp_id }-{ iv_item_no }| TYPE 'S' DISPLAY LIKE 'W'.
*    RETURN.
*  ENDIF.
*
*  " 3. Hiển thị Popup (ALV)
*  TRY.
*      cl_salv_table=>factory(
*        IMPORTING r_salv_table = lo_alv
*        CHANGING  t_table      = lt_logs ).
*
*      lo_alv->set_screen_popup(
*        start_column = 10 end_column = 110
*        start_line   = 5  end_line   = 20 ).
*
*      DATA(lo_cols) = lo_alv->get_columns( ).
*      lo_cols->set_optimize( abap_true ).
*
*      " Ẩn bớt cột thừa
*      lo_cols->get_column( 'MANDT' )->set_visible( abap_false ).
*      lo_cols->get_column( 'REQ_ID' )->set_visible( abap_false ).
*      lo_cols->get_column( 'STATUS' )->set_visible( abap_false ).
*
*      " Đổi tên cột
*      lo_cols->get_column( 'TEMP_ID' )->set_long_text( 'Temp ID' ).
*      lo_cols->get_column( 'ITEM_NO' )->set_long_text( 'Item' ).
*      lo_cols->get_column( 'FIELDNAME' )->set_long_text( 'Field' ).
*      lo_cols->get_column( 'MESSAGE' )->set_long_text( 'Error Description' ).
*
*      lo_alv->display( ).
*
*    CATCH cx_salv_msg.
*  ENDTRY.
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form SHOW_ERROR_DETAILS_POPUP (Show All & Highlight Context)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form SHOW_ERROR_DETAILS_POPUP (Fixed: LVC_T_SCOL Color)
*&---------------------------------------------------------------------*
FORM show_error_details_popup
  USING iv_req_id  TYPE zsd_req_id
        iv_temp_id TYPE char10
        iv_item_no TYPE posnr_va.

  " 1. Cấu trúc hiển thị (SỬA LỖI: Dùng LVC_T_SCOL)
  TYPES: BEGIN OF ty_error_pop.
           INCLUDE TYPE ztb_so_error_log.
    TYPES: row_color TYPE lvc_t_scol, " <<< SỬA: Đổi từ CHAR4 sang Table Type
         END OF ty_error_pop.

  DATA: lt_display TYPE TABLE OF ty_error_pop,
        ls_display TYPE ty_error_pop.

  DATA: lt_logs    TYPE TABLE OF ztb_so_error_log.
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table.

  " Biến màu sắc
  DATA: ls_color TYPE lvc_s_scol.

  " 2. Lấy TOÀN BỘ lỗi của Temp ID này
  SELECT * FROM ztb_so_error_log
    INTO TABLE lt_logs
    WHERE req_id  = iv_req_id
      AND temp_id = iv_temp_id.

  IF lt_logs IS INITIAL.
    MESSAGE |No errors found for Order { iv_temp_id }| TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " 3. Xử lý Tô màu (Logic Mới cho LVC_T_SCOL)
  LOOP AT lt_logs INTO DATA(ls_log).
    CLEAR ls_display.
    MOVE-CORRESPONDING ls_log TO ls_display.

    " Logic tô màu:
    " Nếu Item No của dòng lỗi khớp với ngữ cảnh click -> Tô màu Xanh
    IF ls_log-item_no = iv_item_no.

       CLEAR ls_color.
       ls_color-color-col = 5. " 5 = Green
       ls_color-color-int = 0.
       ls_color-color-inv = 0.
       ls_color-fname     = space. " Để trống = Tô cả dòng (Row Color)

       APPEND ls_color TO ls_display-row_color.

    ENDIF.

    APPEND ls_display TO lt_display.
  ENDLOOP.

  " 4. Hiển thị SALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_display ).

      " Cấu hình Popup
      lo_alv->set_screen_popup(
        start_column = 10 end_column = 120
        start_line   = 5  end_line   = 25 ).

      " Cấu hình Cột Màu (Bây giờ sẽ chạy OK vì type đã đúng)
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_color_column( 'ROW_COLOR' ).
      lo_columns->set_optimize( abap_true ).

      " Ẩn bớt cột thừa
      TRY.
          lo_columns->get_column( 'MANDT' )->set_visible( abap_false ).
          lo_columns->get_column( 'REQ_ID' )->set_visible( abap_false ).
          lo_columns->get_column( 'ROW_COLOR' )->set_visible( abap_false ). " Ẩn cột kỹ thuật này đi
          lo_columns->get_column( 'LOG_USER' )->set_visible( abap_false ).
          lo_columns->get_column( 'LOG_DATE' )->set_visible( abap_false ).
          lo_columns->get_column( 'STATUS' )->set_visible( abap_false ).

          lo_columns->get_column( 'TEMP_ID' )->set_long_text( 'Order ID' ).
          lo_columns->get_column( 'ITEM_NO' )->set_long_text( 'Item No' ).
          lo_columns->get_column( 'FIELDNAME' )->set_long_text( 'Field Error' ).
          lo_columns->get_column( 'MESSAGE' )->set_long_text( 'Error Description' ).
          lo_columns->get_column( 'MSG_TYPE' )->set_long_text( 'Type' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Tiêu đề Popup
      DATA: lv_title TYPE lvc_title.
      IF iv_item_no = '000000'.
        lv_title = |Error Logs for Order { iv_temp_id } (Header Selected)|.
      ELSE.
        lv_title = |Error Logs for Order { iv_temp_id } (Item { iv_item_no } Selected)|.
      ENDIF.
      lo_alv->get_display_settings( )->set_list_header( lv_title ).

      lo_alv->display( ).

    CATCH cx_salv_msg.
      MESSAGE 'Error displaying ALV Popup' TYPE 'E'.
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
  " 1. KPI: Total Sales Orders (Today)
  SELECT COUNT( * ) FROM vbak INTO gv_hc_total_so
    WHERE erdat = sy-datum AND vbtyp = 'C'.

  " 2. KPI: Pending Orders (Status A or B)
  SELECT COUNT( * ) FROM vbak INTO gv_hc_pending
    WHERE gbstk IN ('A','B') AND vbtyp = 'C' AND erdat >= sy-datum.

  " 3. KPI: Net Value (Today)
  SELECT SUM( netwr ) FROM vbak INTO gv_hc_net_val
    WHERE erdat = sy-datum AND vbtyp = 'C'.

  " Format Net Value (Billions/Millions)
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

  " 4. KPI: PGI Completed (Status C)
  SELECT COUNT( * ) FROM vbak INTO gv_hc_pgi
     WHERE erdat = sy-datum AND vbtyp = 'C' AND gbstk = 'C'.

  " 5. ALV Data: Recent Orders (Today)
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

    " Map Status Text (No Icon)
    CASE ls_raw-gbstk.
      WHEN 'C'. ls_alv-gbstk_txt = 'Completed'.
      WHEN 'B'. ls_alv-gbstk_txt = 'In Process'.
      WHEN OTHERS. ls_alv-gbstk_txt = 'Open'.
    ENDCASE.

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
      " 1. Overall Status (No Color, Full Text)
      ( fieldname = 'GBSTK_TXT'   coltext = 'Overall Status' outputlen = 15 just = 'C' )
      " 2. Sales Document (Clickable)
      ( fieldname = 'VBELN'       coltext = 'Sales Document' hotspot = 'X' outputlen = 15 just = 'C' )
      " 3. Created By
      ( fieldname = 'ERNAM'       coltext = 'Created By'     outputlen = 15 )
      " 4. Time
      ( fieldname = 'ERZET'       coltext = 'Time'           outputlen = 10 just = 'C' )
      " 5. Type
      ( fieldname = 'AUART'       coltext = 'Type'           outputlen = 8 just = 'C' )
      " 6. Sales Area (Wider)
      ( fieldname = 'SALES_AREA'  coltext = 'Sales Area' outputlen = 25 )
      " 7. Net Value (Right Aligned)
      ( fieldname = 'NETWR'       coltext = 'Net Value'      do_sum = 'X' outputlen = 18 )
      " 8. Currency (Left Aligned next to value)
      ( fieldname = 'WAERK'       coltext = 'Curr.'          outputlen = 5 just = 'L' )
  ).

  " --- LAYOUT ---
  ls_layo-zebra      = 'X'.
  ls_layo-sel_mode   = 'A'.
  ls_layo-grid_title = 'Recent Sales Documents (Today)'.
  ls_layo-no_toolbar = 'X'.

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

  PERFORM calculate_kpi_sd4.
  PERFORM prepare_chart_data_sd4.
  PERFORM process_alv_color_sd4.
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

  " Tính lại KPI/Chart theo data mới
  PERFORM calculate_kpi_sd4.
  PERFORM prepare_chart_data_sd4.
  PERFORM process_alv_color_sd4.
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
*& Form PREPARE_CHART_DATA_SD4
*&---------------------------------------------------------------------*
FORM prepare_chart_data_sd4.
  CLEAR: gt_chart_sd4.
  DATA: lv_vkorg TYPE vbak-vkorg.
  SORT gt_alv_sd4 BY vbeln.

  LOOP AT gt_alv_sd4 INTO DATA(ls_row).
    lv_vkorg = ls_row-vkorg.
    AT NEW vbeln.
      IF lv_vkorg = 'CNSG' OR lv_vkorg = 'CNHN' OR lv_vkorg = 'CNDN'.
        READ TABLE gt_chart_sd4 ASSIGNING FIELD-SYMBOL(<fs_chart>)
             WITH KEY vkorg = lv_vkorg.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO gt_chart_sd4 ASSIGNING <fs_chart>.
          <fs_chart>-vkorg = lv_vkorg.
        ENDIF.
        <fs_chart>-total_orders = <fs_chart>-total_orders + 1.
      ENDIF.
    ENDAT.
  ENDLOOP.
  SORT gt_chart_sd4 BY vkorg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_ALV_COLOR_SD4
*&---------------------------------------------------------------------*
FORM process_alv_color_sd4.
  DATA: ls_color TYPE lvc_s_scol.
  LOOP AT gt_alv_sd4 ASSIGNING FIELD-SYMBOL(<fs_data>).
    REFRESH <fs_data>-t_color.
    CASE <fs_data>-gbstk.
      WHEN 'C'.
        <fs_data>-gbstk_txt = 'Completed'.
        ls_color-fname = 'GBSTK_TXT'. ls_color-color-col = 5. ls_color-color-int = 0.
      WHEN 'B'.
        <fs_data>-gbstk_txt = 'In Process'.
        ls_color-fname = 'GBSTK_TXT'. ls_color-color-col = 3. ls_color-color-int = 0.
      WHEN 'A'.
        <fs_data>-gbstk_txt = 'Open'.
        ls_color-fname = 'GBSTK_TXT'. ls_color-color-col = 6. ls_color-color-int = 0.
      WHEN OTHERS.
        <fs_data>-gbstk_txt = 'Not Relevant'.
        ls_color-fname = 'GBSTK_TXT'. ls_color-color-col = 2.
    ENDCASE.
    APPEND ls_color TO <fs_data>-t_color.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPDATE_DASHBOARD_UI_SD4
*&---------------------------------------------------------------------*
FORM update_dashboard_ui_sd4.
  PERFORM draw_kpi_header_sd4.
  PERFORM draw_chart_bar_sd4.
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
*& Form DRAW_CHART_BAR_SD4
*&---------------------------------------------------------------------*
FORM draw_chart_bar_sd4.
  DATA: lt_html TYPE TABLE OF char255, ls_html TYPE char255, lv_url TYPE char255.
  DATA: lv_val_str TYPE string, lv_color TYPE string, lv_row_js TYPE string.
  DATA: lv_org_name TYPE string.

  IF go_html_cht_sd4 IS INITIAL.
    CREATE OBJECT go_html_cht_sd4 EXPORTING parent = go_c_mid_sd4.
  ENDIF.

  DEFINE add_c. ls_html = &1. APPEND ls_html TO lt_html. END-OF-DEFINITION.

  " (Giữ nguyên phần HTML/JS Chart Google cũ của bạn)
  add_c '<html><head>'.
  add_c '<script src="https://www.gstatic.com/charts/loader.js"></script>'.
  add_c '<style>html,body{height:100%;margin:0;padding:5px;overflow:hidden;font-family: "Segoe UI", Arial, sans-serif;} #chart_div{height:100%;}</style>'.
  add_c '<script>'.
  add_c 'google.charts.load("current", {packages:["corechart"]});'.
  add_c 'google.charts.setOnLoadCallback(drawChart);'.
  add_c 'window.onresize = drawChart;'.
  add_c 'function drawChart() {'.
  add_c '  var data = new google.visualization.DataTable();'.
  add_c '  data.addColumn("string", "Branch Name");'.
  add_c '  data.addColumn("number", "Orders");'.
  add_c '  data.addColumn({type: "string", role: "style"});'.
  add_c '  data.addColumn({type: "number", role: "annotation"});'.
  add_c '  data.addRows(['.

  LOOP AT gt_chart_sd4 INTO DATA(ls_d).
    lv_val_str = |{ ls_d-total_orders NUMBER = RAW }|.
    CONDENSE lv_val_str NO-GAPS.
    CASE ls_d-vkorg.
      WHEN 'CNSG'. lv_org_name = 'CN Hồ Chí Minh'. lv_color = '#5C6BC0'.
      WHEN 'CNHN'. lv_org_name = 'CN Hà Nội'.      lv_color = '#EF5350'.
      WHEN 'CNDN'. lv_org_name = 'CN Đà Nẵng'.     lv_color = '#FFCA28'.
      WHEN OTHERS. lv_org_name = ls_d-vkorg.       lv_color = '#BDBDBD'.
    ENDCASE.
    lv_row_js = |['{ lv_org_name }', { lv_val_str }, '{ lv_color }', { lv_val_str }],|.
    add_c lv_row_js.
  ENDLOOP.

  add_c '  ]);'.

  " 4. Cấu hình Chart tinh tế hơn
  add_c '  var options = {'.
  add_c '    title: "Sales Order Volume by Branch",'.
  add_c '    titleTextStyle: { color: "#444", fontSize: 16, bold: true },'.
  add_c '    legend: { position: "none" },'.
  add_c '    chartArea: { width: "85%", height: "75%", top: 40 },'.

  " Trục hoành: Chữ đậm nhẹ, màu xám đen
  add_c '    hAxis: { textStyle: { color: "#333", fontSize: 11, bold: true } },'.

  " Trục tung: Gridlines nhạt để chart thoáng hơn
  add_c '    vAxis: { format: "#", gridlines: { color: "#f0f0f0" }, minValue: 0 },'.

  add_c '    bar: { groupWidth: "55%" },'.
  add_c '    animation: { startup: true, duration: 1200, easing: "out" }'.
  add_c '  };'.

  add_c '  var chart = new google.visualization.ColumnChart(document.getElementById("chart_div"));'.
  add_c '  chart.draw(data, options);'.
  add_c '}'.
  add_c '</script></head>'.
  add_c '<body><div id="chart_div"></div></body></html>'.

  go_html_cht_sd4->load_data( IMPORTING assigned_url = lv_url CHANGING data_table = lt_html ).
  go_html_cht_sd4->show_url( url = lv_url ).
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
    IF &1 = 'NETWR_I'.
      ls_fcat-do_sum = 'X'.
      ls_fcat-cfieldname = 'WAERK'. " Gắn Currency
    ENDIF.
    APPEND ls_fcat TO lt_fcat.
  END-OF-DEFINITION.

  add_col 'GBSTK_TXT'  'Overall Stat.'   12.
  add_col 'VBELN'      'Sales Doc'       10.
  add_col 'AUART'      'Order Type'      5.
  add_col 'AUDAT'      'Doc. Date'       12.
  add_col 'VDATU'      'Req. Del. Date'  10.
  add_col 'VKORG'      'Sales Org.'      6.
  add_col 'VTWEG'      'Dis. Channel'    3.
  add_col 'SPART'      'Division'        2.
  add_col 'KUNNR'      'Sold-to'         10.
  add_col 'NAME1'      'Customer Name'   30.
  add_col 'POSNR'      'Item'            6.
  add_col 'MATNR'      'Material'        18.
  add_col 'KWMENG'     'Quantity'        10.
  add_col 'VRKME'      'Unit'            3.
  add_col 'NETWR_I'    'Net Value'       15.
  add_col 'WAERK'      'Currency'        5.

  DATA: ls_layout TYPE lvc_s_layo.
  ls_layout-zebra      = 'X'.
  ls_layout-sel_mode   = 'A'.
  ls_layout-ctab_fname = 'T_COLOR'.

  go_alv_sd4->set_table_for_first_display(
    EXPORTING is_layout       = ls_layout
    CHANGING  it_outtab       = gt_alv_sd4
              it_fieldcatalog = lt_fcat ).
ENDFORM.
