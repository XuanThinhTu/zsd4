*&---------------------------------------------------------------------*
*& Include          ZSD4_PROGRAM_F00
*&---------------------------------------------------------------------*
*& Description:     Local Class Definitions
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* CLASS lcl_hc_event_handler DEFINITION
*----------------------------------------------------------------------*
* Description: Handles events for Home Center Screen (0100)
*----------------------------------------------------------------------*
CLASS lcl_hc_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      " Handle HTML Viewer 'sapevent' (e.g. click on metrics)
      on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
        IMPORTING action getdata.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_mu_event_handler DEFINITION
*----------------------------------------------------------------------*
* Description: Handles events for Mass Upload Screen (0210)
*----------------------------------------------------------------------*
CLASS lcl_mu_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      handle_node_double_click
        FOR EVENT node_double_click OF cl_gui_simple_tree
        IMPORTING node_key.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_mu_event_handler DEFINITION
*----------------------------------------------------------------------*
* Description: Handles events for Mass Upload Screen (0211 and 0212)
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING
          io_grid  TYPE REF TO cl_gui_alv_grid
          it_table TYPE REF TO data,
*      handle_user_command
*        FOR EVENT user_command OF cl_gui_alv_grid
*        IMPORTING e_ucomm,
*      handle_toolbar
*        FOR EVENT toolbar OF cl_gui_alv_grid
*        IMPORTING e_object e_interactive,
      handle_data_changed
        FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING
          er_data_changed,
      handle_data_changed_finished
        FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING
          e_modified
          et_good_cells,
      handle_hotspot_click
        FOR EVENT hotspot_click OF cl_gui_alv_grid
        IMPORTING e_row_id e_column_id es_row_no sender.
  PRIVATE SECTION.
    DATA:
      mo_grid  TYPE REF TO cl_gui_alv_grid,
      mt_table TYPE REF TO data.
ENDCLASS.

*&---------------------------------------------------------------------*
*& SCR0430
*&---------------------------------------------------------------------*
CLASS lcl_event_handler_0430 DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
        IMPORTING action frame getdata postdata query_table.
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

  " 1. XÁC ĐỊNH CHẾ ĐỘ EDIT (Giữ nguyên logic cũ)
  DATA: lv_edit TYPE abap_bool.
  IF pv_grid_nm = 'GO_GRID_ITEM_SINGLE' OR pv_grid_nm = 'GO_GRID_CONDITIONS'.
    lv_edit = abap_true.
  ELSEIF pv_grid_nm = 'GO_MU_ALV_ITEMS' OR pv_grid_nm = 'GO_MU_ALV_COND'.
    lv_edit = abap_true.
  ELSE.
    lv_edit = gs_edit.
  ENDIF.

  " 2. CẤU HÌNH LAYOUT RIÊNG BIỆT CHO TỪNG GRID
  CASE pv_grid_nm.

      " ---------------------------------------------------------------------
      " CASE A: ALV ITEM SINGLE (Yêu cầu: Bỏ hết Style, Color, Celltab)
      " ---------------------------------------------------------------------
    WHEN 'GO_GRID_ITEM_SINGLE'.
      gs_layout = VALUE #(
          sel_mode   = 'A'
          cwidth_opt = 'X'
          stylefname = 'CELL_STYLE'
          ctab_fname = space  " Không dùng Cell Color
          info_fname = space  " Không dùng Row Color
          zebra      = abap_true
          edit       = lv_edit
          grid_title = gv_grid_title
          smalltitle = abap_true
          no_rowmark = space
      ).

      " ---------------------------------------------------------------------
      " CASE B: ALV CONDITIONS (Yêu cầu: Dùng CELL_STYLE để Lock dòng)
      " ---------------------------------------------------------------------
    WHEN 'GO_GRID_CONDITIONS'.
      gs_layout = VALUE #(
          sel_mode   = 'A'
          stylefname = 'CELL_STYLE' " <--- Tên trường đặc biệt của Condition
          ctab_fname = 'CELLTAB'    " (Giữ lại nếu có dùng màu ô)
          info_fname = 'ROWCOLOR'   " (Giữ lại nếu có dùng màu dòng)
          cwidth_opt = 'X'
          zebra      = abap_true
          edit       = lv_edit
          grid_title = gv_grid_title
          smalltitle = abap_true
          no_rowmark = space
      ).

   WHEN 'GO_MU_ALV_ITEMS'.
      gs_layout = VALUE #(
          sel_mode   = 'A'
          stylefname = 'CELL_STYLE' " <--- Tên trường đặc biệt của Condition
          ctab_fname = 'CELLTAB'    " (Giữ lại nếu có dùng màu ô)
          info_fname = 'ROWCOLOR'   " (Giữ lại nếu có dùng màu dòng)
          cwidth_opt = 'X'
          zebra      = abap_true
          edit       = lv_edit
          grid_title = gv_grid_title
          smalltitle = abap_true
          no_rowmark = space
      ).

   WHEN 'GO_MU_ALV_COND'.
      gs_layout = VALUE #(
          sel_mode   = 'A'
          stylefname = 'CELL_STYLE' " <--- Tên trường đặc biệt của Condition
          ctab_fname = 'CELLTAB'    " (Giữ lại nếu có dùng màu ô)
          info_fname = 'ROWCOLOR'   " (Giữ lại nếu có dùng màu dòng)
          cwidth_opt = 'X'
          zebra      = abap_true
          edit       = lv_edit
          grid_title = gv_grid_title
          smalltitle = abap_true
          no_rowmark = space
      ).

      " ---------------------------------------------------------------------
      " CASE C: CÁC GRID CÒN LẠI (Mass Upload, v.v...) - Dùng chuẩn
      " ---------------------------------------------------------------------
    WHEN OTHERS.
      gs_layout = VALUE #(
          sel_mode   = 'A'
          stylefname = 'STYLE'
          ctab_fname = 'CELLTAB'    " Dùng màu ô
          info_fname = 'ROWCOLOR'   " Dùng màu dòng
          cwidth_opt = 'X'
          zebra      = abap_true
          edit       = lv_edit
          grid_title = gv_grid_title
          smalltitle = abap_true
          no_rowmark = space
      ).

  ENDCASE.

ENDFORM.

FORM alv_set_gridtitle USING pv_grid_nm TYPE fieldname.
  DATA: lv_entry TYPE i,
        lv_title TYPE string.

  " 1. TÍNH TOÁN TIÊU ĐỀ (Logic tính toán của bạn)
  CASE pv_grid_nm.
    " ... (Các case cũ giữ nguyên) ...

    WHEN 'GO_MU_ALV_ITEMS'.
      IF gs_mu_header-temp_id IS NOT INITIAL.
        lv_title = |Items of Header { gs_mu_header-temp_id }|.
      ELSE.
        lv_title = 'Items List'.
      ENDIF.
      lv_entry = lines( gt_disp_items ).

    WHEN 'GO_MU_ALV_COND'.
      IF gs_mu_item-item_no IS NOT INITIAL.
        lv_title = |Conditions of Item { gs_mu_item-item_no ALPHA = OUT }|.
      ELSE.
        lv_title = 'Pricing Elements'.
      ENDIF.
      lv_entry = lines( gt_disp_cond ).

    WHEN OTHERS.
      lv_title = 'ALV Grid'.
      lv_entry = 0.
  ENDCASE.

  " 2. GÁN VÀO BIẾN TOÀN CỤC (Cho lần đầu khởi tạo)
  gv_grid_title = |{ lv_title } ({ lv_entry } rows)|.

  " 3. [QUAN TRỌNG] ÉP GRID CẬP NHẬT NGAY LẬP TỨC (Cho trường hợp Refresh)
  CASE pv_grid_nm.
    WHEN 'GO_MU_ALV_ITEMS'.
      IF go_mu_alv_items IS BOUND.
        go_mu_alv_items->set_gridtitle( gv_grid_title ).
      ENDIF.

    WHEN 'GO_MU_ALV_COND'.
      IF go_mu_alv_cond IS BOUND.
        go_mu_alv_cond->set_gridtitle( gv_grid_title ).
      ENDIF.
  ENDCASE.

ENDFORM.

FORM alv_variant USING pv_grid_nm TYPE fieldname.
  CLEAR gs_variant.

  gs_variant-report   = sy-repid.
  gs_variant-username = sy-uname.

  " Gán Handle riêng biệt cho từng Grid (Để lưu Layout riêng)
  CASE pv_grid_nm.

    WHEN 'GO_GRID_ITEM_SINGLE'. gs_variant-handle = '07'.
    WHEN 'GO_GRID_CONDITIONS'.  gs_variant-handle = '08'.
    WHEN 'GO_MU_ALV_ITEMS'.  gs_variant-handle = 'M1'. " M1: Mass Item
    WHEN 'GO_MU_ALV_COND'.   gs_variant-handle = 'M2'. " M2: Mass Condition

    WHEN OTHERS.                gs_variant-handle = 'XX'.
  ENDCASE.
ENDFORM.

FORM alv_toolbar USING pv_grid_nm TYPE fieldname.

  " 1. Xóa sạch danh sách loại trừ cũ
  REFRESH gt_exclude.

  " 2. Định nghĩa danh sách các nút CẦN ẨN cho Mass Upload (Edit nhưng không đổi cấu trúc)
  DATA: lt_exclude_mass TYPE ui_functions.

  lt_exclude_mass = VALUE #(
    ( cl_gui_alv_grid=>mc_fc_loc_insert_row )    " Chèn dòng
    ( cl_gui_alv_grid=>mc_fc_loc_append_row )    " Thêm dòng cuối
    ( cl_gui_alv_grid=>mc_fc_loc_delete_row )    " Xóa dòng
    ( cl_gui_alv_grid=>mc_fc_loc_copy )          " Copy
    ( cl_gui_alv_grid=>mc_fc_loc_copy_row )      " Copy dòng
    ( cl_gui_alv_grid=>mc_fc_loc_cut )           " Cắt
    ( cl_gui_alv_grid=>mc_fc_loc_paste )         " Dán
    ( cl_gui_alv_grid=>mc_fc_loc_paste_new_row ) " Dán dòng mới
    ( cl_gui_alv_grid=>mc_fc_loc_undo )          " Undo
    ( cl_gui_alv_grid=>mc_fc_graph )             " Đồ thị (thường không cần)
    ( cl_gui_alv_grid=>mc_fc_info )              " Info
  ).

  " 3. Phân loại Grid để ẩn nút tương ứng
  CASE pv_grid_nm.

    WHEN 'GO_MU_ALV_ITEMS' OR 'GO_MU_ALV_COND'.
      APPEND LINES OF lt_exclude_mass TO gt_exclude.

    WHEN 'GO_GRID_ITEM_SINGLE'.
      APPEND LINES OF lt_exclude_mass TO gt_exclude.

    WHEN 'GO_GRID_CONDITIONS'.
      APPEND LINES OF lt_exclude_mass TO gt_exclude.

    WHEN OTHERS.

  ENDCASE.
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

FORM alv_fieldcatalog USING pv_grid_nm TYPE fieldname.
  CASE pv_grid_nm.
    WHEN 'GO_GRID_ITEM_SINGLE'.
      PERFORM alv_fieldcatalog_single_item CHANGING gt_fieldcat_item_single.

    WHEN 'GO_GRID_CONDITIONS'.
      PERFORM alv_fieldcatalog_conditions CHANGING gt_fieldcat_conds.

    WHEN 'GO_MU_ALV_ITEMS'.
      PERFORM alv_fieldcatalog_02 USING 'VAL' CHANGING gt_fcat_item.

    WHEN 'GO_MU_ALV_COND'.
      PERFORM alv_fieldcatalog_cond USING 'VAL' CHANGING gt_fcat_cond.

    WHEN OTHERS.
      MESSAGE |Field catalog logic not defined for grid: { pv_grid_nm }| TYPE 'W'.
  ENDCASE.
ENDFORM.

*FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
*  DATA ls_fcat TYPE lvc_s_fcat.
*  DATA lv_pos  TYPE i.
*
*  REFRESH pt_fieldcat.
*  lv_pos = 0.
*
*  " --- Macro ĐỒNG BỘ ---
*  DEFINE _add_fieldcat.
*    ADD 1 TO lv_pos.
*    CLEAR ls_fcat.
*    ls_fcat-col_pos     = lv_pos.
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
*
*    " [CHÚ Ý] Nếu bạn đã revert về TYPES cũ thì dùng 'ZTB_SO_ITEM_SING'
*    " Nếu đang dùng Structure mới thì dùng 'ZSTR_SU_ALV_ITEM'
*    ls_fcat-ref_table   = 'ZSTR_SU_ALV_ITEM'.
*
*    ls_fcat-ref_field   = &1.
*    ls_fcat-edit_mask   = &6.
*
*    " [1] Tắt Conversion Exit cho MATNR
*    IF &1 = 'MATNR'.
*      ls_fcat-no_convext = 'X'.
*    ENDIF.
*
*    " [THÊM MỚI] Set độ rộng tối thiểu để màn hình ban đầu đẹp hơn
*    CASE &1.
*       WHEN 'MATNR'.       ls_fcat-outputlen = 18.
*       WHEN 'DESCRIPTION'. ls_fcat-outputlen = 40.
*       WHEN 'QUANTITY'.    ls_fcat-outputlen = 15.
*       WHEN 'UNIT'.        ls_fcat-outputlen = 5.
*       WHEN 'REQ_DATE'.    ls_fcat-outputlen = 12.
*    ENDCASE.
*
*    " ... (Giữ nguyên logic Logic IF gv_order_type ... của bạn) ...
*    IF gs_so_heder_ui-so_hdr_auart = 'ZDR' OR gs_so_heder_ui-so_hdr_auart = 'ZCRR'.
*       IF &1 = 'QUANTITY'.
*          ls_fcat-coltext   = 'Target Quantity'.
*          ls_fcat-scrtext_l = 'Target Quantity'.
*          ls_fcat-scrtext_m = 'Tgt Qty'.
*          ls_fcat-scrtext_s = 'Tgt Qty'.
*       ENDIF.
*       IF &1 = 'REQ_SEGMENT'. ls_fcat-no_out = space. ENDIF.
*    ELSE.
*       IF &1 = 'REQ_SEGMENT'. ls_fcat-no_out = 'X'. ENDIF.
*    ENDIF.
*
*    " ... (Giữ nguyên Logic Editable của bạn) ...
*    CASE &1.
*      WHEN 'MATNR' OR 'UNIT' OR 'QUANTITY' OR 'COND_TYPE' OR
*           'REQ_DATE' OR 'PLANT' OR 'STORE_LOC' OR
*           'UNIT_PRICE' OR 'PER' OR 'REQ_SEGMENT'.
*        ls_fcat-edit = abap_true.
*      WHEN OTHERS.
*        ls_fcat-edit = abap_false.
*    ENDCASE.
*
*    APPEND ls_fcat TO pt_fieldcat.
*  END-OF-DEFINITION.
*  " --- DANH SÁCH CỘT (Code của bạn) ---
*  _add_fieldcat:
*    'ITEM_NO'         'R'   abap_on   'Item'                 abap_off  '',
*    'MATNR'           'L'   abap_on   'Material'             abap_off  '',
*    'REQ_SEGMENT'     'L'   abap_on   'Req. Segment'         abap_off  '',
*    'QUANTITY'        'R'   abap_on   'Order Quantity'       abap_off  '',
*    'UNIT'            'L'   abap_on   'Sales Unit'           abap_off  '',
*    'NET_VALUE'       'R'   abap_on   'Net Value'            abap_off  '',
*    'CURRENCY'        'L'   abap_on   'Currency'             abap_off  '',
*    'DESCRIPTION'     'L'   abap_on   'Description'          abap_off  '',
*    'ITCA'            'L'   abap_on   'Item Category'        abap_off  '',
*    'PLANT'           'L'   abap_on   'Plant'                abap_off  '',
*    'SHIP_POINT'      'L'   abap_on   'Shipping point'       abap_off  '',
*    'STORE_LOC'       'L'   abap_on   'Storage location'     abap_off  '',
*    'OVERALL_STATUS'  'L'   abap_on   'Overall status'       abap_off  '',
*    'CONF_QTY'        'R'   abap_on   'Confirmed quantity'   abap_off  '',
*    'COND_TYPE'       'L'   abap_on   'Cond. Type'           abap_off  '',
*    'REQ_DATE'        'C'   abap_on   'Delivery date'        abap_off  '__.__.____',
*    'UNIT_PRICE'      'R'   abap_on   'Amount'               abap_off  '',
*    'PER'             'R'   abap_on   'Per'                  abap_off  '',
*    'TAX'             'R'   abap_on   'Tax Amount'           abap_off  '',
*    'NET_PRICE'       'R'   abap_on   'Net price'            abap_off  '',
*    'HI_LVL_ITEM'     'R'   abap_on   'Higher-level item'    abap_off  ''.
*
*ENDFORM.

FORM alv_fieldcatalog_single_item CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  DATA lv_pos  TYPE i.

  REFRESH pt_fieldcat.
  lv_pos = 0.

  DEFINE _add_fieldcat.
    ADD 1 TO lv_pos.
    CLEAR ls_fcat.
    ls_fcat-col_pos     = lv_pos.
    ls_fcat-fieldname   = &1.
    ls_fcat-just        = &2.
    ls_fcat-col_opt     = &3.
    ls_fcat-coltext     = &4.
    ls_fcat-scrtext_l   = &4.
    ls_fcat-scrtext_m   = &4.
    ls_fcat-scrtext_s   = &4.
    ls_fcat-fix_column  = &5.

    " [1] QUAN TRỌNG: Trỏ về Structure để lấy Search Help & Validate
    ls_fcat-ref_table   = 'ZSTR_SU_ALV_ITEM'.
    ls_fcat-ref_field   = &1.

    ls_fcat-edit_mask   = &6.

    " [2] QUAN TRỌNG: Gán thủ công tham chiếu để TRÁNH DUMP
    " (Dù trong SE11 có gán rồi, gán lại ở đây để chắc chắn 100%)
    CASE &1.
      WHEN 'NET_VALUE' OR 'UNIT_PRICE' OR 'TAX' OR 'NET_PRICE'.
         ls_fcat-cfieldname = 'CURRENCY'.
      WHEN 'QUANTITY' OR 'CONF_QTY'.
         ls_fcat-qfieldname = 'UNIT'.
    ENDCASE.

    " [3] Tắt Conversion Exit cho MATNR (Để gõ 123 không thành 00...123 nếu không muốn)
    IF &1 = 'MATNR'.
      ls_fcat-no_convext = 'X'.
    ENDIF.

    " [4] Set độ rộng mặc định (Cho đẹp)
*    CASE &1.
*       WHEN 'MATNR'.       ls_fcat-outputlen = 18.
*       WHEN 'DESCRIPTION'. ls_fcat-outputlen = 40.
*       WHEN 'QUANTITY'.    ls_fcat-outputlen = 15.
*       WHEN 'UNIT'.        ls_fcat-outputlen = 5.
*       WHEN 'REQ_DATE'.    ls_fcat-outputlen = 12.
*    ENDCASE.

    " ====================================================================
    " [4] SET ĐỘ RỘNG MẶC ĐỊNH (OUTPUTLEN) - ĐÃ CẬP NHẬT
    " ====================================================================
*    CASE &1.
*       WHEN 'MATNR'.       ls_fcat-outputlen = 20. " Vật tư (Rộng)
*       WHEN 'DESCRIPTION'. ls_fcat-outputlen = 40. " Mô tả (Rất rộng)
*
*       WHEN 'REQ_SEGMENT'. ls_fcat-outputlen = 16. " Req Segment
*
*       WHEN 'QUANTITY'.    ls_fcat-outputlen = 15. " Số lượng
*       WHEN 'CONF_QTY'.    ls_fcat-outputlen = 15.
*
*       WHEN 'UNIT'.        ls_fcat-outputlen = 6.  " ĐVT
*       WHEN 'REQ_DATE'.    ls_fcat-outputlen = 12. " Ngày
*
*       WHEN 'PLANT'.       ls_fcat-outputlen = 6.  " Plant
*       WHEN 'STORE_LOC'.   ls_fcat-outputlen = 6.  " SLOC
*
*       WHEN 'UNIT_PRICE'.  ls_fcat-outputlen = 15. " Giá tiền
*       WHEN 'NET_VALUE'.   ls_fcat-outputlen = 15.
*       WHEN 'TAX'.         ls_fcat-outputlen = 12.
*
*       WHEN 'COND_TYPE'.   ls_fcat-outputlen = 6.
*
*       WHEN OTHERS.
*         " Các cột khác (Item No, Status...) mặc định 10 cho đẹp
*         ls_fcat-outputlen = 10.
*    ENDCASE.

    " [5] Logic Ẩn/Hiện cột (Giữ nguyên)
    IF gs_so_heder_ui-so_hdr_auart = 'ZDR' OR gs_so_heder_ui-so_hdr_auart = 'ZCRR'.
       IF &1 = 'QUANTITY'.
          ls_fcat-coltext = 'Target Quantity'.
          ls_fcat-scrtext_l = 'Target Quantity'.
          ls_fcat-scrtext_m = 'Tgt Qty'.
       ENDIF.
       IF &1 = 'REQ_SEGMENT'. ls_fcat-no_out = space. ENDIF.
    ELSE.
       IF &1 = 'REQ_SEGMENT'. ls_fcat-no_out = 'X'. ENDIF.
    ENDIF.

    " [6] Logic Editable (Các cột cho phép nhập)
    CASE &1.
      WHEN 'MATNR' OR 'UNIT' OR 'QUANTITY' OR 'COND_TYPE' OR
           'REQ_DATE' OR 'PLANT' OR 'STORE_LOC' OR
           'UNIT_PRICE' OR 'PER' OR 'REQ_SEGMENT'.
        ls_fcat-edit = abap_true.
      WHEN OTHERS.
        ls_fcat-edit = abap_false.
    ENDCASE.

    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " --- DANH SÁCH CỘT (Giữ nguyên của bạn) ---
  _add_fieldcat:
    'ITEM_NO'         'R'   abap_on   'Item'                 abap_off  '',
    'MATNR'           'L'   abap_on   'Material'             abap_off  '',
    'REQ_SEGMENT'     'L'   abap_on   'Req. Segment'         abap_off  '',
    'QUANTITY'        'R'   abap_on   'Order Quantity'       abap_off  '',
    'UNIT'            'L'   abap_on   'Sales Unit'           abap_off  '',
    'CURRENCY'        'L'   abap_on   'Currency'             abap_off  '',
    'DESCRIPTION'     'L'   abap_on   'Description'          abap_off  '',
    'ITCA'            'L'   abap_on   'Item Category'        abap_off  '',
    'PLANT'           'L'   abap_on   'Plant'                abap_off  '',
    'SHIP_POINT'      'L'   abap_on   'Shipping point'       abap_off  '',
    'STORE_LOC'       'L'   abap_on   'Storage location'     abap_off  '',
    'CONF_QTY'        'R'   abap_on   'Confirmed quantity'   abap_off  '',
    'COND_TYPE'       'L'   abap_on   'Cond. Type'           abap_off  '',
    'REQ_DATE'        'C'   abap_on   'Delivery date'        abap_off  '__.__.____'.

ENDFORM.

FORM alv_fieldcatalog_conditions CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  " ==============================================================================
  " 1. CỘT ICON (STATUS) - Cấu hình giống Mass Upload
  " ==============================================================================
  CLEAR ls_fcat.
  ls_fcat-fieldname  = 'ICON'.
  ls_fcat-coltext    = 'Status'.
  ls_fcat-icon       = abap_true. " Hiển thị dạng Icon
  ls_fcat-fix_column = abap_true. " Cố định cột bên trái
  ls_fcat-just       = 'C'.       " Canh giữa
  ls_fcat-outputlen  = 4.
  APPEND ls_fcat TO pt_fieldcat.

  " ==============================================================================
  " 2. MACRO CÁC CỘT DỮ LIỆU
  " ==============================================================================
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
    ls_fcat-edit_mask   = &6.

    " Tham chiếu Structure
    ls_fcat-ref_table   = 'ZSTR_SO_COND_UI'.
    ls_fcat-ref_field   = &1.

*    " Xử lý logic riêng
*    CASE &1.
*      WHEN 'AMOUNT' OR 'KWERT'.
*        ls_fcat-cfieldname = 'WAERS'.
*        IF &1 = 'KWERT'.
*          CLEAR: ls_fcat-ref_table, ls_fcat-ref_field.
*        ENDIF.
*        ls_fcat-edit       = 'X'.
*      WHEN OTHERS.
*    ENDCASE.

   CASE &1.
      " 1. Cột AMOUNT (Số tiền)
      WHEN 'AMOUNT'.
        ls_fcat-cfieldname = 'WAERS'.
        ls_fcat-edit       = 'X'.

      " 2. Các cột tham số khác (Tiền tệ, Đơn vị giá, ĐVT)
      WHEN 'WAERS' OR 'KPEIN' OR 'KMEIN'.
        ls_fcat-edit       = 'X'.

      " 3. Cột KWERT (Giá trị)
      WHEN 'KWERT'.
        ls_fcat-cfieldname = 'WAERS'.
        ls_fcat-edit       = 'X'.
        CLEAR: ls_fcat-ref_table, ls_fcat-ref_field.

      WHEN OTHERS.
        " Các cột khác (KSCHL, VTEXT...) mặc định Read-only
    ENDCASE.

    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  " ==============================================================================
  " 3. GỌI MACRO (Đã bỏ dòng ICON ở đây vì đã add thủ công ở trên)
  " ==============================================================================
  " Fieldname        Just   Opt       Coltext              FixCol      EditMask
  _add_fieldcat:
    'KSCHL'          'L'    abap_on   'Cond. Type'         abap_false  '',
    'VTEXT'          'L'    abap_on   'Description'        abap_false  '',
    'AMOUNT'         'R'    abap_on   'Amount'             abap_false  '',
    'WAERS'          'L'    abap_on   'Curr.'              abap_false  '',
    'KPEIN'          'R'    abap_on   'Per'                abap_false  '',
    'KMEIN'          'L'    abap_on   'UoM'                abap_false  '',
    'KWERT'          'R'    abap_on   'Cond. Value'        abap_false  ''.

ENDFORM.

FORM alv_fieldcatalog_02
  USING    iv_tab_type    TYPE char10
  CHANGING pt_fieldcat    TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

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
    ls_fcat-ref_table  = 'ZSTR_MU_ITEM'.
    ls_fcat-ref_field  = &1.
    ls_fcat-edit_mask  = &6.
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

  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERR_BTN'.
  ls_fcat-coltext   = 'Error Log'.
  ls_fcat-icon      = abap_true.
  ls_fcat-hotspot   = abap_true.
  ls_fcat-outputlen = 4.
  ls_fcat-just      = 'C'.
  ls_fcat-fix_column = 'X'.

  IF iv_tab_type = 'SUC'.
    ls_fcat-coltext   = 'Inc.Log'.       " Tên cột: Incomplete
    ls_fcat-tooltip   = 'Incompletion Log'.
  ELSE.
    ls_fcat-coltext   = 'Err.Log'.       " Tên cột: Error
    ls_fcat-tooltip   = 'Error Details'.
  ENDIF.

  APPEND ls_fcat TO pt_fieldcat.
  _add_fieldcat:
    'PRICE_PROC'         'L' abap_on 'Pricing Procedure'    abap_off '',
    'ITEM_NO'            'L' abap_on 'Item No'              abap_off '',
    'MATERIAL'              'L' abap_on 'Material'             abap_off '',
    'SHORT_TEXT'         'L' abap_on 'Short Text'           abap_off '',
    'PLANT'              'L' abap_on 'Plant'                abap_off '',
    'SHIP_POINT'         'L' abap_on 'Shipping Point'       abap_off '',
    'STORE_LOC'          'L' abap_on 'Storage Loc.'         abap_off '',
    'QUANTITY'           'R' abap_on 'Order Quantity'       abap_off '',
    'REQ_DATE'           'C' abap_on 'Schedule Line Date'   abap_off '__.__.____'.

ENDFORM.

FORM alv_fieldcatalog_cond
  USING    iv_tab_type    TYPE char10
  CHANGING pt_fieldcat    TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  REFRESH pt_fieldcat.

  DEFINE _add_fcat_cond.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-ref_table = 'ZSTR_MU_COND'.
    ls_fcat-ref_field = &1.
    APPEND ls_fcat TO pt_fieldcat.
  END-OF-DEFINITION.

  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ICON'.
  ls_fcat-coltext   = 'Status'.
  ls_fcat-icon      = abap_true.
  ls_fcat-fix_column = abap_true.
  APPEND ls_fcat TO pt_fieldcat.

  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERR_BTN'.
  ls_fcat-coltext   = 'Error Log'.
  ls_fcat-icon      = abap_true.
  ls_fcat-hotspot   = abap_true.
  ls_fcat-outputlen = 4.
  ls_fcat-just      = 'C'.
  ls_fcat-fix_column = 'X'.

  IF iv_tab_type = 'SUC'.
    ls_fcat-coltext   = 'Inc.Log'.
    ls_fcat-tooltip   = 'Incompletion Log'.
  ELSE.
    ls_fcat-coltext   = 'Err.Log'.
    ls_fcat-tooltip   = 'Error Details'.
  ENDIF.
  APPEND ls_fcat TO pt_fieldcat.

  _add_fcat_cond 'ITEM_NO'    'Item No'.
  _add_fcat_cond 'COND_TYPE'  'Condition Type'.
  _add_fcat_cond 'AMOUNT'     'Amount'.
  _add_fcat_cond 'CURRENCY'   'Currency'.
  _add_fcat_cond 'PER'        'Pricing Unit'.
  _add_fcat_cond 'UOM'        'UoM'.

ENDFORM.

FORM alv_event USING pv_grid_nm TYPE fieldname.

  CASE pv_grid_nm.

    WHEN 'GO_GRID_ITEM_SINGLE'.
      CHECK go_grid_item_single IS BOUND.
      IF go_event_handler_single IS INITIAL.
        CREATE OBJECT go_event_handler_single
          EXPORTING
            io_grid  = go_grid_item_single
            it_table = REF #( gt_item_details ).
      ENDIF.
      SET HANDLER:
*        go_event_handler_single->handle_user_command       FOR go_grid_item_single,
*        go_event_handler_single->handle_toolbar            FOR go_grid_item_single,
        go_event_handler_single->handle_data_changed       FOR go_grid_item_single,
        go_event_handler_single->handle_data_changed_finished FOR go_grid_item_single.

    WHEN 'GO_GRID_CONDITIONS'.
      CHECK go_grid_conditions IS BOUND.
      IF go_event_handler_conds IS INITIAL.
        CREATE OBJECT go_event_handler_conds
          EXPORTING
            io_grid  = go_grid_conditions
            it_table = REF #( gt_conditions_alv ).
      ENDIF.

      " === UI TREE MỚI (ITEMS) ===
    WHEN 'GO_MU_ALV_ITEMS'.
      CHECK go_mu_alv_items IS BOUND.

      " Nếu chưa có Event Handler -> Tạo mới (Dùng chung class handler cũ nếu logic giống)
      " Giả sử bạn tái sử dụng LCL_EVENT_HANDLER cũ cho logic Data Changed
      IF go_event_mu_items IS INITIAL.
        CREATE OBJECT go_event_mu_items
          EXPORTING
            io_grid  = go_mu_alv_items
            it_table = REF #( gt_disp_items ).
      ENDIF.

      " Đăng ký sự kiện sửa đổi dữ liệu
*      SET HANDLER go_event_mu_items->handle_data_changed FOR go_mu_alv_items.

      " Đăng ký Enter để trigger check data
      go_mu_alv_items->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).

      " === UI TREE MỚI (CONDITIONS) ===
    WHEN 'GO_MU_ALV_COND'.
      CHECK go_mu_alv_cond IS BOUND.

      IF go_event_mu_cond IS INITIAL.
        CREATE OBJECT go_event_mu_cond
          EXPORTING
            io_grid  = go_mu_alv_cond
            it_table = REF #( gt_disp_cond ).
      ENDIF.

*      SET HANDLER go_event_mu_cond->handle_data_changed FOR go_mu_alv_cond.
      go_mu_alv_cond->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).

    WHEN OTHERS.

  ENDCASE.
ENDFORM.

FORM alv_outtab_display USING pv_grid_nm TYPE fieldname.
  FIELD-SYMBOLS: <lfs_grid> TYPE REF TO cl_gui_alv_grid.
  DATA: lt_fcat TYPE lvc_t_fcat,
        lt_data TYPE REF TO data.

  ASSIGN (pv_grid_nm) TO <lfs_grid>.
  CHECK <lfs_grid> IS BOUND.

  CASE pv_grid_nm.
    WHEN 'GO_GRID_ITEM_SINGLE'.
      lt_data = REF #( gt_item_details ).
      lt_fcat = gt_fieldcat_item_single.

    WHEN 'GO_GRID_CONDITIONS'.
      lt_data = REF #( gt_conditions_alv ).
      lt_fcat = gt_fieldcat_conds.

    WHEN 'GO_MU_ALV_ITEMS'.
      lt_data = REF #( gt_disp_items ).
      lt_fcat = gt_fcat_item.

    WHEN 'GO_MU_ALV_COND'.
      lt_data = REF #( gt_disp_cond ).
      lt_fcat = gt_fcat_cond.
    WHEN OTHERS.
      MESSAGE |ALV display logic not defined for grid: { pv_grid_nm }| TYPE 'W'.
      RETURN.
  ENDCASE.

  <lfs_grid>->set_table_for_first_display(
    EXPORTING
      i_buffer_active    = abap_true
      i_bypassing_buffer = abap_true
      i_save             = 'A'
      is_layout          = gs_layout
      it_toolbar_excluding = gt_exclude
    CHANGING
      it_outtab          = lt_data->*
      it_fieldcatalog    = lt_fcat
  ).

  cl_gui_control=>set_focus( control = <lfs_grid> ).
  cl_gui_cfw=>flush( ).
ENDFORM.

FORM show_alv_items.
  DATA: ls_stable TYPE lvc_s_stbl.
  DATA: ls_disp_item TYPE ty_mu_item_ext. " [QUAN TRỌNG] Dùng Type mở rộng có err_btn/celltab
  DATA: ls_style     TYPE lvc_s_styl.     " [MỚI] Biến cấu trúc style

  DEFINE _lock_field.
    ls_style-fieldname = &1.
    ls_style-style     = cl_gui_alv_grid=>mc_style_disabled. " Style Disable (Read-only)
    INSERT ls_style INTO TABLE ls_disp_item-cell_style.      " Chèn vào bảng style của dòng hiện tại
  END-OF-DEFINITION.

  " 1. Lọc dữ liệu & Map sang bảng hiển thị
  CLEAR gt_disp_items.

  IF gs_mu_header-temp_id IS NOT INITIAL.
    LOOP AT gt_mu_item INTO DATA(ls_item) WHERE temp_id = gs_mu_header-temp_id.
      CLEAR ls_disp_item.

      " A. Map dữ liệu gốc
      MOVE-CORRESPONDING ls_item TO ls_disp_item.

      REFRESH ls_disp_item-cell_style.

      IF gs_mu_header-vbeln_so IS NOT INITIAL.

         ls_style-fieldname = space. " Space = Apply cho cả dòng
         ls_style-style     = cl_gui_alv_grid=>mc_style_disabled.
         INSERT ls_style INTO TABLE ls_disp_item-cell_style.

      ELSE.

      " Gọi Macro để khóa các trường không cho user nhập
      _lock_field 'ICON'.     " <--- Khóa Status Icon
      _lock_field 'ITEM_NO'.  " <--- Khóa Item No
      _lock_field 'PRICE_PROC'.  " Pricing Procedure
      _lock_field 'SHORT_TEXT'.  " Short Text (Tự lấy từ Material)
      _lock_field 'REQ_DATE'.    " Schedule Line Date (Tự lấy từ Header)

      ENDIF.

      " B. Xử lý Icon trạng thái & Nút Error Log
      CASE ls_item-status.
        WHEN 'ERROR' OR 'FAILED'.
          ls_disp_item-icon    = icon_led_red.
          ls_disp_item-err_btn = icon_protocol. " Hiện nút xem lỗi
        WHEN 'INCOMP'.
          ls_disp_item-icon    = icon_led_yellow.
          ls_disp_item-err_btn = icon_protocol.
        WHEN 'SUCCESS'.
          ls_disp_item-icon    = icon_led_green.
          ls_disp_item-err_btn = ' '.
        WHEN OTHERS. " NEW / READY
          ls_disp_item-icon    = icon_led_green.
          ls_disp_item-err_btn = ' '.
      ENDCASE.

      APPEND ls_disp_item TO gt_disp_items.
    ENDLOOP.
  ENDIF.

  " 1.5. [MỚI] Gọi tô màu ô lỗi (Cell Color)
  " Form này sẽ đọc bảng Log và update cột CELLTAB trong GT_DISP_ITEMS
  PERFORM highlight_error_cells.

  PERFORM alv_set_gridtitle USING 'GO_MU_ALV_ITEMS'.

  " 2. Kiểm tra nếu Grid đã có -> Refresh
  IF go_mu_alv_items IS BOUND.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.
    go_mu_alv_items->refresh_table_display( is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " 3. Khởi tạo lần đầu
  IF go_mu_cont_head IS INITIAL.
    CREATE OBJECT go_mu_cont_head
      EXPORTING
        container_name = 'CC_ALV_ITEMS'.

    CREATE OBJECT go_mu_alv_items
      EXPORTING
        i_parent = go_mu_cont_head.
  ENDIF.

  " 4. Gọi bộ Form chuẩn để hiển thị
  " [LƯU Ý]: Trong FORM ALV_GRID_DISPLAY, bạn nhớ set Layout-stylefname = 'CELLTAB'
  PERFORM alv_grid_display   USING 'GO_MU_ALV_ITEMS'.
  PERFORM alv_outtab_display USING 'GO_MU_ALV_ITEMS'.

  " 5. Đăng ký sự kiện Edit
  IF go_event_mu_items IS INITIAL.
    CREATE OBJECT go_event_mu_items
      EXPORTING
        io_grid  = go_mu_alv_items
        it_table = REF #( gt_disp_items ).
  ENDIF.

  " Đăng ký Handler
  SET HANDLER go_event_mu_items->handle_hotspot_click FOR go_mu_alv_items.
  go_mu_alv_items->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).

ENDFORM.

FORM show_alv_conditions.
  DATA: ls_stable TYPE lvc_s_stbl.
  DATA: ls_disp_cond TYPE ty_mu_cond_ext. " [QUAN TRỌNG] Dùng Type mở rộng
  DATA: ls_style     TYPE lvc_s_styl.     " [MỚI] Biến để gán style

  DEFINE _lock_field.
    ls_style-fieldname = &1.
    ls_style-style     = cl_gui_alv_grid=>mc_style_disabled. " Khóa (Read-only)
    INSERT ls_style INTO TABLE ls_disp_cond-cell_style.
  END-OF-DEFINITION.

  " 1. Lọc dữ liệu vào GT_DISP_COND
  CLEAR gt_disp_cond.

  IF gs_mu_item-temp_id IS NOT INITIAL.

    DATA: ls_header_check TYPE ztb_so_upload_hd.
    READ TABLE gt_mu_header INTO ls_header_check
         WITH KEY temp_id = gs_mu_item-temp_id.

    LOOP AT gt_mu_cond INTO DATA(ls_cond)
         WHERE temp_id = gs_mu_item-temp_id
           AND item_no = gs_mu_item-item_no.

      CLEAR ls_disp_cond.

      " A. Map dữ liệu gốc
      MOVE-CORRESPONDING ls_cond TO ls_disp_cond.

      REFRESH ls_disp_cond-cell_style.

      " Gọi Macro để khóa các trường cố định
      IF ls_header_check-vbeln_so IS NOT INITIAL.

         ls_style-fieldname = space. " Space = Apply cho cả dòng
         ls_style-style     = cl_gui_alv_grid=>mc_style_disabled.
         INSERT ls_style INTO TABLE ls_disp_cond-cell_style.

      ELSE.
      _lock_field 'ICON'.
      _lock_field 'ITEM_NO'.   " Số Item
*      _lock_field 'CURRENCY'.  " Tiền tệ
*      _lock_field 'PER'.       " Pricing Unit
*      _lock_field 'UOM'.       " Đơn vị tính
      ENDIF.

      " B. Xử lý Icon trạng thái & Nút Error Log
      CASE ls_cond-status.
        WHEN 'ERROR' OR 'FAILED'.
          ls_disp_cond-icon    = icon_led_red.
          ls_disp_cond-err_btn = icon_protocol.
        WHEN 'INCOMP'.
          ls_disp_cond-icon    = icon_led_yellow.
          ls_disp_cond-err_btn = icon_protocol.
        WHEN 'SUCCESS'.
          ls_disp_cond-icon    = icon_led_green.
          ls_disp_cond-err_btn = ' '.
        WHEN OTHERS.
          ls_disp_cond-icon    = icon_led_green.
          ls_disp_cond-err_btn = ' '.
      ENDCASE.

      APPEND ls_disp_cond TO gt_disp_cond.
    ENDLOOP.
  ENDIF.

  " 1.5. [MỚI] Gọi tô màu ô lỗi
  PERFORM highlight_error_cells.

  PERFORM alv_set_gridtitle USING 'GO_MU_ALV_COND'.

  " 2. Refresh nếu đã tồn tại
  IF go_mu_alv_cond IS BOUND.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.
    go_mu_alv_cond->refresh_table_display( is_stable = ls_stable ).
    RETURN.
  ENDIF.

  " 3. Khởi tạo
  IF go_mu_cont_item IS INITIAL.
    CREATE OBJECT go_mu_cont_item
      EXPORTING
        container_name = 'CC_ALV_COND'.

    CREATE OBJECT go_mu_alv_cond
      EXPORTING
        i_parent = go_mu_cont_item.
  ENDIF.

  " 4. Hiển thị
  " [LƯU Ý]: Nhớ set Layout-stylefname = 'CELLTAB' trong Form chuẩn
  PERFORM alv_grid_display   USING 'GO_MU_ALV_COND'.
  PERFORM alv_outtab_display USING 'GO_MU_ALV_COND'.

  " 5. Đăng ký sự kiện
  IF go_event_mu_cond IS INITIAL.
    CREATE OBJECT go_event_mu_cond
      EXPORTING
        io_grid  = go_mu_alv_cond
        it_table = REF #( gt_disp_cond ).
  ENDIF.

  " Đăng ký Handler
  SET HANDLER go_event_mu_cond->handle_hotspot_click FOR go_mu_alv_cond.
  go_mu_alv_cond->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PREPARE_SINGLE_ITEM_STYLES
*&---------------------------------------------------------------------*
* Description:
* Prepares cell styles (Edit/Read-only) for the Item Details ALV.
* Sets specific technical columns to 'Read-only' mode.
*----------------------------------------------------------------------*
FORM prepare_single_item_styles.

  " --- 1. Define Static Styles (Build ONCE, use MANY times) ---
  DATA: lt_readonly_styles TYPE lvc_t_styl.

  lt_readonly_styles = VALUE #(
    style = cl_gui_alv_grid=>mc_style_disabled " Set common property
    ( fieldname = 'ITEM_NO' )
    ( fieldname = 'COND_TYPE' )
    ( fieldname = 'REQ_DATE' )
    ( fieldname = 'UNIT' )
    ( fieldname = 'CURRENCY' )
    ( fieldname = 'ITCA' )
    ( fieldname = 'DESCRIPTION' )
    ( fieldname = 'CONF_QTY' )
  ).

  " --- 2. Apply Styles to Internal Table ---
  " Loop through the data and assign the pre-defined styles
  FIELD-SYMBOLS: <ls_item> TYPE ty_item_details.

  LOOP AT gt_item_details ASSIGNING <ls_item>.
    <ls_item>-cell_style = lt_readonly_styles.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_alv_layout_single_item
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM build_alv_layout_single_item .
  " 1. Tạo Container (CHỈ 1 LẦN)
  IF go_cont_item_single IS INITIAL.
    CREATE OBJECT go_cont_item_single
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
        i_parent = go_cont_item_single.

    CALL METHOD go_grid_item_single->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_enter. " Triggers on Enter key

    CALL METHOD go_grid_item_single->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified. " Triggers on Tab key/leaving the cell

    " 2c. Gọi helper FORMs (Như bạn muốn)
    PERFORM alv_grid_display USING 'GO_GRID_ITEM_SINGLE'.
    PERFORM alv_outtab_display USING 'GO_GRID_ITEM_SINGLE'.

    " 2d. Bật chế độ Edit (Bật lại)
    CALL METHOD go_grid_item_single->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    " 2e. Flush (Chỉ flush khi tạo lần đầu)
    cl_gui_cfw=>flush( ).
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_conditions_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM build_conditions_alv .
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


*---------------------------------------------------------------------*
* Include ZPG_216_SOF00 – UI initialization forms
*---------------------------------------------------------------------*
FORM set_dropdown_sales_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key = 'INC' . ls_value-text = TEXT-001. APPEND ls_value TO lt_values.
  ls_value-key  = 'COM'. ls_value-text = TEXT-002. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_SOSTA'
      values = lt_values.
ENDFORM.

FORM set_dropdown_process_phase.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key = 'ALL'. ls_value-text = 'All'. APPEND ls_value TO lt_values.
  ls_value-key = 'ORD'. ls_value-text = TEXT-003. APPEND ls_value TO lt_values.
  ls_value-key = 'DEL'. ls_value-text = TEXT-004. APPEND ls_value TO lt_values.
  ls_value-key = 'INV'. ls_value-text = TEXT-005. APPEND ls_value TO lt_values.
  ls_value-key = 'BIL'. ls_value-text = TEXT-006. APPEND ls_value TO lt_values.
  ls_value-key = 'ACC'. ls_value-text = TEXT-007. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_PHASE'
      values = lt_values.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SET_DROPDOWN_DELIVERY_STATUS
*&---------------------------------------------------------------------*
FORM set_dropdown_delivery_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'.   ls_value-text = 'All'. APPEND ls_value TO lt_values.

  " [GỘP]: Text chung cho cả Return và Standard
  ls_value-key  = 'READY'. ls_value-text = TEXT-008. APPEND ls_value TO lt_values.
  ls_value-key  = 'POST'.  ls_value-text = TEXT-009. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_DDSTA'
      values = lt_values.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SET_DROPDOWN_BILLING_STATUS
*&---------------------------------------------------------------------*
FORM set_dropdown_billing_status.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  CLEAR lt_values.
  ls_value-key  = 'ALL'.  ls_value-text = 'All'.       APPEND ls_value TO lt_values.

  " --- [SỬA]: Đổi text OPEN đúng theo yêu cầu ---
  ls_value-key  = 'OPEN'. ls_value-text = TEXT-010. APPEND ls_value TO lt_values.
  ls_value-key  = 'CANC'. ls_value-text = TEXT-011. APPEND ls_value TO lt_values.
  ls_value-key  = 'COMP'. ls_value-text = TEXT-012. APPEND ls_value TO lt_values.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'CB_BDSTA'
      values = lt_values.
ENDFORM.

FORM alv_prepare.
  CLEAR: gt_fcat, gs_layout.

  gs_layout-zebra      = abap_true.
  gs_layout-cwidth_opt = abap_true.
  gs_layout-grid_title = TEXT-013.

  " BÁO ALV DÙNG CHECKBOX HỆ THỐNG:
  gs_layout-box_fname  = 'SEL_BOX'. " Tên trường data để lưu 'X'
  gs_layout-sel_mode   = 'D'.       " Cho phép chọn nhiều
  gs_layout-no_merging = space. " <== QUAN TRỌNG: Để cột Sales Doc tự gộp lại
  gs_layout-no_toolbar = 'X'.

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
  add_field 'PROCESS_PHASE' TEXT-014      20 abap_false.
  add_field 'SALES_DOCUMENT' TEXT-015    12 abap_false.
  add_field 'ORDER_TYPE'        TEXT-016    4  abap_false.
  add_field 'DOCUMENT_DATE'     TEXT-017       10 abap_false.
  add_field 'SOLD_TO_PARTY'     TEXT-018       10 abap_false.
  add_field 'SALES_ORG'         TEXT-019           4  abap_false.
  add_field 'DISTR_CHAN'        TEXT-020       2  abap_false.
  add_field 'DIVISION'          TEXT-021            2  abap_false.
  add_field 'DELIVERY_DOCUMENT' TEXT-022 12 abap_false.
  add_field 'REQ_DELIVERY_DATE' TEXT-023 10 abap_false.
  add_field 'BILLING_DOCUMENT'  TEXT-024   12 abap_false.
  add_field 'NET_VALUE'         TEXT-025           15 abap_false.
  add_field 'CURRENCY'          TEXT-026            5  abap_false.
  add_field 'FI_DOC_BILLING'    TEXT-027   12 abap_false.
  add_field 'BILL_DOC_CANCEL'   TEXT-028  12 abap_false.
  add_field 'FI_DOC_CANCEL'     TEXT-029 12 abap_false.

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

ENDFORM.

*----------------------------------------------------------------------*
* CLASS lcl_event_handler DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_event_handler1 DEFINITION.
  PUBLIC SECTION.
    METHODS:
      handle_double_click
        FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column es_row_no.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_event_handler IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_event_handler1 IMPLEMENTATION.
  METHOD handle_double_click.
    " --- [FIX LỖI] ---
    " Khai báo biến trung gian để hứng index
    DATA: lv_index TYPE i.

    " Chuyển giá trị từ e_row-index sang biến kiểu Integer
    lv_index = e_row-index.

    " Truyền biến lv_index vào FORM (lúc này kiểu dữ liệu đã khớp)
    PERFORM show_document_flow_popup USING lv_index.
    " -----------------
  ENDMETHOD.
ENDCLASS.
