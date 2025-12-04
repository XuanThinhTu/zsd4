class ZCL_SD_MASS_VALIDATOR definition
  public
  final
  create public .

public section.

  class-data GT_ERRORS type ZTTY_VALIDATION_ERROR .
  constants GC_MSGID type SYMSGID value 'ZSD4_MSG' ##NO_TEXT.

    CLASS-METHODS: set_context
      IMPORTING iv_req_id TYPE zsd_req_id.

  class-methods CLEAR_ERRORS .
  class-methods GET_ERRORS
    returning
      value(RT_ERRORS) type ZTTY_VALIDATION_ERROR .
  class-methods ADD_ERROR
    importing
      !IV_TEMP_ID type CHAR10
      !IV_ITEM_NO type POSNR_VA
      !IV_FIELDNAME type FIELDNAME
      !IV_MSG_TYPE type SYMSGTY
      !IV_MESSAGE type BAPI_MSG .
  class-methods EXECUTE_VALIDATION_HDR
    changing
      !CS_HEADER type ZTB_SO_UPLOAD_HD .
  class-methods EXECUTE_VALIDATION_ITM
    importing
      !IS_HEADER type ZTB_SO_UPLOAD_HD
    changing
      !CS_ITEM type ZTB_SO_UPLOAD_IT .
  " [THÊM MỚI] Method Validate Pricing (Chính)
    CLASS-METHODS:
      execute_validation_prc
        CHANGING cs_pricing TYPE ztb_so_upload_pr. " (Lưu ý: Tên bảng PR)
protected section.
private section.

  " --- [THÊM] Biến chứa REQ_ID hiện tại ---
    CLASS-DATA: gv_current_req_id TYPE zsd_req_id.

  types:
*&---------------------------------------------------------------------*
*& (PASTE TOÀN BỘ CODE NÀY VÀO PRIVATE SECTION CỦA BẠN)
*&---------------------------------------------------------------------*
  " === 1. [SỬA] ĐỊNH NGHĨA 'KIỂU' (TYPES) CẦN DÙNG ===
  " (Copy 18 TYPES từ ...BUFF_DEF vào đây)
    BEGIN OF ty_tvak_buf,
      auart TYPE tvak-auart,
      vbtyp TYPE tvak-vbtyp,
      sperr TYPE tvak-sperr,
      numki TYPE tvak-numki,
      kalvg TYPE tvak-kalvg,
    END OF ty_tvak_buf .
  types:
    BEGIN OF ty_tvko_buf,
      vkorg TYPE tvko-vkorg,
    END OF ty_tvko_buf .
  types:
    BEGIN OF ty_tvtw_buf,
      vtweg TYPE tvtw-vtweg,
    END OF ty_tvtw_buf .
  types:
    BEGIN OF ty_tspat_buf,
      spart TYPE tspat-spart,
    END OF ty_tspat_buf .
  types:
    BEGIN OF ty_tvta_buf,
      vkorg TYPE tvta-vkorg,
      vtweg TYPE tvta-vtweg,
      spart TYPE tvta-spart,
    END OF ty_tvta_buf .
  types:
    BEGIN OF ty_tvbur_buf,
      vkbur TYPE tvbur-vkbur,
    END OF ty_tvbur_buf .
  types:
    BEGIN OF ty_tvkgr_buf,
      vkgrp TYPE tvkgr-vkgrp,
    END OF ty_tvkgr_buf .
  types:
    BEGIN OF ty_kna1_buf,
      kunnr TYPE kna1-kunnr,
      loevm TYPE kna1-loevm,
    END OF ty_kna1_buf .
  types:
    BEGIN OF ty_knvv_buf,
      kunnr TYPE knvv-kunnr,
      vkorg TYPE knvv-vkorg,
      vtweg TYPE knvv-vtweg,
      spart TYPE knvv-spart,
      kalks TYPE knvv-kalks,
    END OF ty_knvv_buf .
  types:
    BEGIN OF ty_t052_buf,
      zterm TYPE t052-zterm,
      zschf TYPE t052-zschf,
    END OF ty_t052_buf .
  types:
    BEGIN OF ty_tinct_buf,
      inco1 TYPE tinct-inco1,
    END OF ty_tinct_buf .
  types:
    BEGIN OF ty_tcurc_buf,
      waers TYPE tcurc-waers,
      isocd TYPE tcurc-isocd,
    END OF ty_tcurc_buf .
  types:
    BEGIN OF ty_t683v_buf,
      kalsm TYPE t683v-kalsm,
    END OF ty_t683v_buf .
  types:
    BEGIN OF ty_mara_buf,
      matnr TYPE mara-matnr,
      lvorm TYPE mara-lvorm,
      mtart TYPE mara-mtart,
    END OF ty_mara_buf .
  types:
    BEGIN OF ty_mvke_buf,
      matnr TYPE mvke-matnr,
      vkorg TYPE mvke-vkorg,
      vtweg TYPE mvke-vtweg,
      lvorm TYPE mvke-lvorm,
    END OF ty_mvke_buf .
  types:
    BEGIN OF ty_t001w_buf,
      werks TYPE t001w-werks,
    END OF ty_t001w_buf .
  types:
    BEGIN OF ty_tvst_buf,
      vstel TYPE tvst-vstel,
    END OF ty_tvst_buf .
  types:
    BEGIN OF ty_t001l_buf,
      werks TYPE t001l-werks,
      lgort TYPE t001l-lgort,
    END OF ty_t001l_buf .
  types:
    BEGIN OF ty_marm_buf,
      matnr TYPE marm-matnr,
      meinh TYPE marm-meinh,
    END OF ty_marm_buf.
  types:
  " (Thêm vào danh sách TYPES)
    BEGIN OF ty_t685_buf,
      kschl TYPE t685-kschl,
      kvewe TYPE t685-kvewe, " Usage (A = Pricing)
    END OF ty_t685_buf.
  class-data:
  " === 2. [SỬA] ĐỊNH NGHĨA 'BỘ ĐỆM' (BUFFER TABLES) ===
  " (Copy 18 DATA từ ...BUFF_DEF vào đây, đổi thành CLASS-DATA)
    gt_tvak_buf  TYPE HASHED TABLE OF ty_tvak_buf WITH UNIQUE KEY auart .
  class-data:
    gt_tvko_buf  TYPE HASHED TABLE OF ty_tvko_buf WITH UNIQUE KEY vkorg .
  class-data:
    gt_tvtw_buf  TYPE HASHED TABLE OF ty_tvtw_buf WITH UNIQUE KEY vtweg .
  class-data:
    gt_tspat_buf TYPE HASHED TABLE OF ty_tspat_buf WITH UNIQUE KEY spart .
  class-data:
    gt_tvta_buf  TYPE HASHED TABLE OF ty_tvta_buf WITH UNIQUE KEY vkorg vtweg spart .
  class-data:
    gt_tvbur_buf TYPE HASHED TABLE OF ty_tvbur_buf WITH UNIQUE KEY vkbur .
  class-data:
    gt_tvkgr_buf TYPE HASHED TABLE OF ty_tvkgr_buf WITH UNIQUE KEY vkgrp .
  class-data:
    gt_kna1_buf  TYPE HASHED TABLE OF ty_kna1_buf WITH UNIQUE KEY kunnr .
  class-data:
    gt_knvv_buf  TYPE HASHED TABLE OF ty_knvv_buf WITH UNIQUE KEY kunnr vkorg vtweg spart .
  class-data:
    gt_t052_buf  TYPE HASHED TABLE OF ty_t052_buf WITH UNIQUE KEY zterm .
  class-data:
    gt_tinct_buf TYPE HASHED TABLE OF ty_tinct_buf WITH UNIQUE KEY inco1 .
  class-data:
    gt_tcurc_buf TYPE HASHED TABLE OF ty_tcurc_buf WITH UNIQUE KEY waers .
  class-data:
    gt_t683v_buf TYPE HASHED TABLE OF ty_t683v_buf WITH UNIQUE KEY kalsm .
  class-data:
    gt_mara_buf  TYPE HASHED TABLE OF ty_mara_buf WITH UNIQUE KEY matnr .
  class-data:
    gt_mvke_buf  TYPE HASHED TABLE OF ty_mvke_buf WITH UNIQUE KEY matnr vkorg vtweg .
  class-data:
    gt_t001w_buf TYPE HASHED TABLE OF ty_t001w_buf WITH UNIQUE KEY werks .
  class-data:
    gt_tvst_buf  TYPE HASHED TABLE OF ty_tvst_buf WITH UNIQUE KEY vstel .
  class-data:
    gt_t001l_buf TYPE HASHED TABLE OF ty_t001l_buf WITH UNIQUE KEY werks lgort .
  class-data:
    gt_marm_buf  TYPE HASHED TABLE OF ty_marm_buf WITH UNIQUE KEY matnr meinh .
  CLASS-DATA:
      gt_t685_buf TYPE HASHED TABLE OF ty_t685_buf WITH UNIQUE KEY kschl kvewe.

  " === 3. [CODE BẠN YÊU CẦU] ĐỊNH NGHĨA 'METHODS' (LOAD BUFFER) ===
  " (Copy 18 FORM từ ...BUFF_LOAD vào đây)
  class-methods BUFFER_LOAD_TVAK
    importing
      !IV_AUART type VBAK-AUART
    changing
      !ES_TVAK type TY_TVAK_BUF
      !EV_FOUND type ABAP_BOOL.
   class-methods buffer_load_tvko
      IMPORTING iv_vkorg TYPE vbak-vkorg
      CHANGING  es_tvko  TYPE ty_tvko_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tvtw
      IMPORTING iv_vtweg TYPE vbak-vtweg
      CHANGING  es_tvtw  TYPE ty_tvtw_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tspat
      IMPORTING iv_spart TYPE vbak-spart
      CHANGING  es_tspat TYPE ty_tspat_buf
                ev_found TYPE abap_bool.
  class-methods  buffer_load_tvta
      IMPORTING iv_vkorg TYPE vbak-vkorg
                iv_vtweg TYPE vbak-vtweg
                iv_spart TYPE vbak-spart
      CHANGING  es_tvta  TYPE ty_tvta_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tvbur
      IMPORTING iv_vkbur TYPE vbak-vkbur
      CHANGING  es_tvbur TYPE ty_tvbur_buf
                ev_found TYPE abap_bool.
    class-methods buffer_load_tvkgr
      IMPORTING iv_vkgrp TYPE vbak-vkgrp
      CHANGING  es_tvkgr TYPE ty_tvkgr_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_kna1
      IMPORTING iv_kunnr TYPE kna1-kunnr
      CHANGING  es_kna1  TYPE ty_kna1_buf
                ev_found TYPE abap_bool.
    class-methods buffer_load_knvv
      IMPORTING iv_kunnr TYPE knvv-kunnr
                iv_vkorg TYPE knvv-vkorg
                iv_vtweg TYPE knvv-vtweg
                iv_spart TYPE knvv-spart
      CHANGING  es_knvv  TYPE ty_knvv_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_t052
      IMPORTING iv_zterm TYPE vbkd-zterm
      CHANGING  es_t052  TYPE ty_t052_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tinct
      IMPORTING iv_inco1 TYPE vbkd-inco1
      CHANGING  es_tinct TYPE ty_tinct_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tcurc
      IMPORTING iv_waers TYPE vbak-waerk
      CHANGING  es_tcurc TYPE ty_tcurc_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_t683v
      IMPORTING iv_kalsm TYPE t683v-kalsm
      CHANGING  es_t683v TYPE ty_t683v_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_mara
      IMPORTING iv_matnr TYPE mara-matnr
      CHANGING  es_mara  TYPE ty_mara_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_mvke
      IMPORTING iv_matnr TYPE mvke-matnr
                iv_vkorg TYPE mvke-vkorg
                iv_vtweg TYPE mvke-vtweg
      CHANGING  es_mvke  TYPE ty_mvke_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_t001w
      IMPORTING iv_werks TYPE t001w-werks
      CHANGING  es_t001w TYPE ty_t001w_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_tvst
      IMPORTING iv_vstel TYPE tvst-vstel
      CHANGING  es_tvst  TYPE ty_tvst_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_t001l
      IMPORTING iv_werks TYPE t001l-werks
                iv_lgort TYPE t001l-lgort
      CHANGING  es_t001l TYPE ty_t001l_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_marm
      IMPORTING iv_matnr TYPE marm-matnr
                iv_meinh TYPE marm-meinh
      CHANGING  es_marm  TYPE ty_marm_buf
                ev_found TYPE abap_bool.
   class-methods buffer_load_t685
      IMPORTING iv_kschl TYPE kschl
                iv_kvewe TYPE kvewe DEFAULT 'A' " Mặc định là A (Pricing)
      CHANGING  es_t685  TYPE ty_t685_buf
                ev_found TYPE abap_bool.
  class-methods VALIDATE_HEADER_AUART
    changing
      !CS_HEADER type ZTB_SO_UPLOAD_HD .
  " === 4. [CODE BẠN YÊU CẦU] ĐỊNH NGHĨA 'METHODS' (VALIDATE HEADER) ===
  CLASS-METHODS
    validate_header_vkorg
      CHANGING cs_header TYPE ztb_so_upload_hd.
  CLASS-METHODS  validate_header_vtweg
      CHANGING cs_header TYPE ztb_so_upload_hd.
  CLASS-METHODS  validate_header_spart
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_sales_area
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_vkbur
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_vkgrp
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_sold_to_party
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_cust_ref
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_req_date
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_price_date
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_pmnttrms
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_incoterms
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_currency
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS validate_header_order_date
      CHANGING cs_header TYPE ztb_so_upload_hd.
   CLASS-METHODS:
    validate_item_pricing_proc
      IMPORTING is_header TYPE ztb_so_upload_hd " (SỬA: Cần Header)
      CHANGING  cs_item   TYPE ztb_so_upload_it,
    validate_item_material
      IMPORTING is_header TYPE ztb_so_upload_hd " (SỬA: Cần Header)
      CHANGING  cs_item   TYPE ztb_so_upload_it,
    validate_item_plant
      IMPORTING is_header TYPE ztb_so_upload_hd " (SỬA: Cần Header)
      CHANGING  cs_item   TYPE ztb_so_upload_it,
    validate_item_ship_point
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_store_loc
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_quantity
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_unit_price
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_per
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_unit
      CHANGING cs_item TYPE ztb_so_upload_it,
    validate_item_sch_date
      IMPORTING is_header TYPE ztb_so_upload_hd " (SỬA: Cần Header)
      CHANGING  cs_item   TYPE ztb_so_upload_it,
    " === [THÊM MỚI] ĐỊNH NGHĨA AUTO-FILL METHODS (HEADER) ===
    auto_fill_incoterm
      CHANGING cs_header TYPE ztb_so_upload_hd,

    auto_fill_currency
      CHANGING cs_header TYPE ztb_so_upload_hd,

    auto_fill_item_basics
      IMPORTING
        iv_matnr      TYPE matnr
      CHANGING
        cv_short_text TYPE arktx
        cv_unit       TYPE vrkme
        cv_per        TYPE kpein
        cv_status     TYPE char15   " (Hoặc ze_so_status nếu bạn đã tạo Data Element)
        cv_message    TYPE bapi_msg,
    auto_fill_plant
      IMPORTING iv_matnr TYPE matnr
                iv_vkorg TYPE vkorg
      CHANGING  cv_plant TYPE werks_d,

    auto_fill_ship_point
      CHANGING cs_item TYPE ztb_so_upload_it,

    auto_fill_price_proc_item
      IMPORTING is_header     TYPE ztb_so_upload_hd
      CHANGING  cv_price_proc TYPE kalsm_d,
    check_special_chars
      IMPORTING
        iv_value     TYPE any
        iv_allow_num TYPE abap_bool DEFAULT abap_true
        iv_allow_space TYPE abap_bool DEFAULT abap_false " <--- THÊM DÒNG NÀY
      RETURNING
        VALUE(rt_invalid) TYPE abap_bool,
    validate_header_inco2 CHANGING cs_header TYPE ztb_so_upload_hd,
    " [THÊM MỚI] Các method Validate Pricing (Con)
      validate_prc_cond_type
        CHANGING cs_pricing TYPE ztb_so_upload_pr,

      validate_prc_amount
        CHANGING cs_pricing TYPE ztb_so_upload_pr,

      validate_prc_currency
        CHANGING cs_pricing TYPE ztb_so_upload_pr,

      validate_prc_per
        CHANGING cs_pricing TYPE ztb_so_upload_pr,

      validate_prc_uom
        CHANGING cs_pricing TYPE ztb_so_upload_pr.
ENDCLASS.



CLASS ZCL_SD_MASS_VALIDATOR IMPLEMENTATION.


  method ADD_ERROR.
    APPEND VALUE #(
      req_id    = gv_current_req_id  " <<< [THÊM DÒNG NÀY QUAN TRỌNG NHẤT]
      temp_id   = iv_temp_id
      item_no   = iv_item_no
      fieldname = iv_fieldname
      msg_type  = iv_msg_type
      message   = iv_message
    ) TO gt_errors.
  endmethod.


  METHOD auto_fill_currency.
    DATA: ls_tvko  TYPE ty_tvko_buf,
          lv_found TYPE abap_bool.

    " Ưu tiên 1: Lấy từ Sales Org (TVKO)
    CALL METHOD buffer_load_tvko
      EXPORTING iv_vkorg = cs_header-sales_org
      CHANGING  es_tvko  = ls_tvko
                ev_found = lv_found.

    IF lv_found = abap_true.
      " Lấy từ buffer (nếu có field WAERS) hoặc select
      SELECT SINGLE waers FROM tvko INTO cs_header-currency
        WHERE vkorg = cs_header-sales_org.
    ENDIF.

    " Ưu tiên 2: Nếu TVKO không có, lấy từ Customer (KNVV)
    IF cs_header-currency IS INITIAL.
       SELECT SINGLE waers FROM knvv INTO cs_header-currency
         WHERE kunnr = cs_header-sold_to_party
           AND vkorg = cs_header-sales_org
           AND vtweg = cs_header-sales_channel
           AND spart = cs_header-sales_div.
    ENDIF.
  ENDMETHOD.


  METHOD auto_fill_incoterm.
    DATA: ls_knvv  TYPE ty_knvv_buf,
          lv_found TYPE abap_bool.

    " Load KNVV từ buffer dựa trên thông tin trong cs_header
    CALL METHOD buffer_load_knvv
      EXPORTING
        iv_kunnr = cs_header-sold_to_party
        iv_vkorg = cs_header-sales_org
        iv_vtweg = cs_header-sales_channel
        iv_spart = cs_header-sales_div
      CHANGING
        es_knvv  = ls_knvv
        ev_found = lv_found.

    IF lv_found = abap_true.
      " Lấy trực tiếp từ buffer (nếu bạn đã thêm field INCO1 vào ty_knvv_buf)
      " cs_header-incoterms = ls_knvv-inco1.

      " (Hoặc select lại nếu buffer chưa có field INCO1)
      SELECT SINGLE inco1 FROM knvv
        INTO cs_header-incoterms
        WHERE kunnr = cs_header-sold_to_party
          AND vkorg = cs_header-sales_org
          AND vtweg = cs_header-sales_channel
          AND spart = cs_header-sales_div.
    ENDIF.
  ENDMETHOD.


  METHOD auto_fill_item_basics.
    DATA: ls_mara  TYPE ty_mara_buf,
          lv_found TYPE abap_bool.

    " 1. Lấy thông tin từ MARA (Buffer)
    CALL METHOD buffer_load_mara
      EXPORTING iv_matnr = iv_matnr
      CHANGING  es_mara  = ls_mara
                ev_found = lv_found.

    IF lv_found = abap_true.
       " Lấy Unit of Measure
       " (Giả sử bạn đã thêm trường MEINS vào ty_mara_buf trong Task 4.0.A)
       " cv_unit = ls_mara-meins.

       " (Nếu chưa có trong buffer, select tạm để demo)
       SELECT SINGLE meins FROM mara INTO cv_unit WHERE matnr = iv_matnr.
    ELSE.
       cv_status  = 'ERROR'.
       cv_message = 'Material not found in MARA.'.
       RETURN.
    ENDIF.

    " 2. Lấy Short Text từ MAKT
    SELECT SINGLE maktx FROM makt INTO cv_short_text
      WHERE matnr = iv_matnr
        AND spras = sy-langu.

    " 3. Default Per
    cv_per = 1.

    " Check lại lần cuối
    IF cv_unit IS INITIAL.
      cv_status  = 'ERROR'.
      cv_message = 'Base Unit of Measure missing for Material.'.
    ENDIF.
  ENDMETHOD.


  METHOD auto_fill_plant.
    DATA: ls_mvke TYPE ty_mvke_buf,
          lv_found TYPE abap_bool.

    " Load MVKE buffer
    CALL METHOD buffer_load_mvke
      EXPORTING iv_matnr = iv_matnr iv_vkorg = iv_vkorg iv_vtweg = ' ' " (Tạm thời)
      CHANGING  es_mvke  = ls_mvke
                ev_found = lv_found.

    " (Giả sử ty_mvke_buf có trường DWERK - Delivering Plant)
    " Nếu chưa có trong buffer, select trực tiếp để demo
    SELECT SINGLE dwerk FROM mvke
      INTO cv_plant
      WHERE matnr = iv_matnr AND vkorg = iv_vkorg.
  ENDMETHOD.


  METHOD auto_fill_price_proc_item.
    " Item thường kế thừa PP của Header nếu không có gì đặc biệt (như Item Category riêng)
*    cv_price_proc = is_header-price_proc.
    " (Lưu ý: ZTB...HDR phải có cột PRICE_PROC nếu muốn dùng, nếu không thì bỏ qua)
  ENDMETHOD.


  METHOD auto_fill_ship_point.
    " Logic đơn giản: Lấy Shipping Point mặc định từ Plant (nếu cấu hình 1-1)
    " Hoặc để trống để SAP tự tính khi tạo SO.
    " Ở đây ta giả lập lấy từ Plant nếu có.
    IF cs_item-plant IS NOT INITIAL.
      " (Code demo: Lấy Ship Point = Plant nếu Plant là số)
      " SELECT SINGLE vstel FROM tvst ...
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_kna1.
    READ TABLE gt_kna1_buf WITH KEY kunnr = iv_kunnr INTO es_kna1.
    IF sy-subrc = 0. ev_found = abap_true. RETURN. ENDIF.
    CLEAR: es_kna1, ev_found.
    SELECT SINGLE kunnr, loevm
      FROM kna1
      INTO CORRESPONDING FIELDS OF @es_kna1
      WHERE kunnr = @iv_kunnr.
    IF sy-subrc = 0.
      INSERT es_kna1 INTO TABLE gt_kna1_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_knvv.
    DATA: lv_kunnr_internal TYPE knvv-kunnr.
    lv_kunnr_internal = iv_kunnr.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input  = lv_kunnr_internal
      IMPORTING output = lv_kunnr_internal.

    READ TABLE gt_knvv_buf
      WITH TABLE KEY kunnr = lv_kunnr_internal vkorg = iv_vkorg vtweg = iv_vtweg spart = iv_spart
      INTO es_knvv.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_knvv, ev_found.
    SELECT SINGLE kunnr, vkorg, vtweg, spart, kalks
      FROM knvv
      INTO CORRESPONDING FIELDS OF @es_knvv
      WHERE kunnr = @lv_kunnr_internal
        AND vkorg = @iv_vkorg
        AND vtweg = @iv_vtweg
        AND spart = @iv_spart.
    IF sy-subrc = 0.
      INSERT es_knvv INTO TABLE gt_knvv_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_mara.
    READ TABLE gt_mara_buf WITH KEY matnr = iv_matnr INTO es_mara.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_mara, ev_found.
    SELECT SINGLE matnr, lvorm, mtart
      FROM mara
      INTO CORRESPONDING FIELDS OF @es_mara
      WHERE matnr = @iv_matnr.
    IF sy-subrc = 0.
      INSERT es_mara INTO TABLE gt_mara_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_marm.
    READ TABLE gt_marm_buf
      WITH TABLE KEY matnr = iv_matnr meinh = iv_meinh
      INTO es_marm.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_marm, ev_found.
    SELECT SINGLE matnr, meinh
      FROM marm
      INTO CORRESPONDING FIELDS OF @es_marm
      WHERE matnr = @iv_matnr
        AND meinh = @iv_meinh.
    IF sy-subrc = 0.
      INSERT es_marm INTO TABLE gt_marm_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_mvke.
    READ TABLE gt_mvke_buf
      WITH TABLE KEY matnr = iv_matnr vkorg = iv_vkorg vtweg = iv_vtweg
      INTO es_mvke.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_mvke, ev_found.
    SELECT SINGLE matnr, vkorg, vtweg, lvorm
      FROM mvke
      INTO CORRESPONDING FIELDS OF @es_mvke
      WHERE matnr = @iv_matnr
        AND vkorg = @iv_vkorg
        AND vtweg = @iv_vtweg.
    IF sy-subrc = 0.
      INSERT es_mvke INTO TABLE gt_mvke_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_t001l.
    READ TABLE gt_t001l_buf
      WITH TABLE KEY werks = iv_werks lgort = iv_lgort
      INTO es_t001l.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_t001l, ev_found.
    SELECT SINGLE werks, lgort
      FROM t001l
      INTO CORRESPONDING FIELDS OF @es_t001l
      WHERE werks = @iv_werks
        AND lgort = @iv_lgort.
    IF sy-subrc = 0.
      INSERT es_t001l INTO TABLE gt_t001l_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_t001w.
    READ TABLE gt_t001w_buf WITH KEY werks = iv_werks INTO es_t001w.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_t001w, ev_found.
    SELECT SINGLE werks
      FROM t001w
      INTO @es_t001w-werks
      WHERE werks = @iv_werks.
    IF sy-subrc = 0.
      INSERT es_t001w INTO TABLE gt_t001w_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_t052.
    READ TABLE gt_t052_buf WITH KEY zterm = iv_zterm INTO es_t052.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_t052, ev_found.
    SELECT SINGLE zterm, zschf
      FROM t052
      INTO CORRESPONDING FIELDS OF @es_t052
      WHERE zterm = @iv_zterm.
    IF sy-subrc = 0.
      INSERT es_t052 INTO TABLE gt_t052_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_t683v.
    READ TABLE gt_t683v_buf WITH KEY kalsm = iv_kalsm INTO es_t683v.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_t683v, ev_found.
    SELECT SINGLE kalsm
      FROM t683v
      INTO @es_t683v-kalsm
      WHERE kalsm = @iv_kalsm.
    IF sy-subrc = 0.
      INSERT es_t683v INTO TABLE gt_t683v_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_t685.
    " Check Buffer
    READ TABLE gt_t685_buf WITH TABLE KEY kschl = iv_kschl kvewe = iv_kvewe INTO es_t685.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.

    " Check Database
    CLEAR: es_t685, ev_found.
    SELECT SINGLE kschl, kvewe
      FROM t685
      INTO CORRESPONDING FIELDS OF @es_t685
      WHERE kschl = @iv_kschl
        AND kvewe = @iv_kvewe.

    IF sy-subrc = 0.
      INSERT es_t685 INTO TABLE gt_t685_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tcurc.
    READ TABLE gt_tcurc_buf WITH KEY waers = iv_waers INTO es_tcurc.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tcurc, ev_found.
    SELECT SINGLE waers, isocd
      FROM tcurc
      INTO CORRESPONDING FIELDS OF @es_tcurc
      WHERE waers = @iv_waers.
    IF sy-subrc = 0.
      INSERT es_tcurc INTO TABLE gt_tcurc_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tinct.
    READ TABLE gt_tinct_buf WITH KEY inco1 = iv_inco1 INTO es_tinct.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tinct, ev_found.
    SELECT SINGLE inco1
      FROM tinct
      INTO @es_tinct-inco1
      WHERE inco1 = @iv_inco1.
    IF sy-subrc = 0.
      INSERT es_tinct INTO TABLE gt_tinct_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tspat.
    READ TABLE gt_tspat_buf WITH KEY spart = iv_spart INTO es_tspat.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tspat, ev_found.
    SELECT SINGLE spart
      FROM tspat
      INTO @es_tspat-spart
      WHERE spart = @iv_spart.
    IF sy-subrc = 0.
      INSERT es_tspat INTO TABLE gt_tspat_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvak.
    " <<< SỬA: Bỏ 'me->' vì đây là STATIC method/attribute >>>
    READ TABLE gt_tvak_buf WITH KEY auart = iv_auart INTO es_tvak.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvak, ev_found.
    SELECT SINGLE auart, vbtyp, sperr, numki, kalvg
      FROM tvak
      INTO CORRESPONDING FIELDS OF @es_tvak
      WHERE auart = @iv_auart.
    IF sy-subrc = 0.
      " <<< SỬA: Bỏ 'me->' >>>
      INSERT es_tvak INTO TABLE gt_tvak_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvbur.
    READ TABLE gt_tvbur_buf WITH KEY vkbur = iv_vkbur INTO es_tvbur.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvbur, ev_found.
    SELECT SINGLE vkbur
      FROM tvbur
      INTO @es_tvbur-vkbur
      WHERE vkbur = @iv_vkbur.
    IF sy-subrc = 0.
      INSERT es_tvbur INTO TABLE gt_tvbur_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvkgr.
    READ TABLE gt_tvkgr_buf WITH KEY vkgrp = iv_vkgrp INTO es_tvkgr.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvkgr, ev_found.
    SELECT SINGLE vkgrp
      FROM tvkgr
      INTO @es_tvkgr-vkgrp
      WHERE vkgrp = @iv_vkgrp.
    IF sy-subrc = 0.
      INSERT es_tvkgr INTO TABLE gt_tvkgr_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvko.
    READ TABLE gt_tvko_buf WITH KEY vkorg = iv_vkorg INTO es_tvko.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvko, ev_found.
    SELECT SINGLE vkorg
      FROM tvko
      INTO @es_tvko-vkorg
      WHERE vkorg = @iv_vkorg.
    IF sy-subrc = 0.
      INSERT es_tvko INTO TABLE gt_tvko_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvst.
    READ TABLE gt_tvst_buf WITH KEY vstel = iv_vstel INTO es_tvst.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvst, ev_found.
    SELECT SINGLE vstel
      FROM tvst
      INTO @es_tvst-vstel
      WHERE vstel = @iv_vstel.
    IF sy-subrc = 0.
      INSERT es_tvst INTO TABLE gt_tvst_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvta.
    READ TABLE gt_tvta_buf
      WITH TABLE KEY vkorg = iv_vkorg vtweg = iv_vtweg spart = iv_spart
      INTO es_tvta.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvta, ev_found.
    SELECT SINGLE vkorg, vtweg, spart
      FROM tvta
      INTO CORRESPONDING FIELDS OF @es_tvta
      WHERE vkorg = @iv_vkorg
        AND vtweg = @iv_vtweg
        AND spart = @iv_spart.
    IF sy-subrc = 0.
      INSERT es_tvta INTO TABLE gt_tvta_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD buffer_load_tvtw.
    READ TABLE gt_tvtw_buf WITH KEY vtweg = iv_vtweg INTO es_tvtw.
    IF sy-subrc = 0.
      ev_found = abap_true.
      RETURN.
    ENDIF.
    CLEAR: es_tvtw, ev_found.
    SELECT SINGLE vtweg
      FROM tvtw
      INTO @es_tvtw-vtweg
      WHERE vtweg = @iv_vtweg.
    IF sy-subrc = 0.
      INSERT es_tvtw INTO TABLE gt_tvtw_buf.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.


METHOD check_special_chars.
    DATA: lv_string  TYPE string,
          lv_allowed TYPE string.

    lv_string = iv_value.
    TRANSLATE lv_string TO UPPER CASE.

    " 1. Xác định bộ ký tự cho phép cơ bản
    IF iv_allow_num = abap_true.
      lv_allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.
    ELSE.
      lv_allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    ENDIF.

    " 2. [QUAN TRỌNG] Nếu cho phép dấu cách -> Thêm vào bộ ký tự
    IF iv_allow_space = abap_true.
      CONCATENATE lv_allowed ' ' INTO lv_allowed.
    ENDIF.

    " 3. Kiểm tra: Nếu chứa ký tự KHÔNG nằm trong bộ allowed -> Lỗi
    IF lv_string CN lv_allowed.
      rt_invalid = abap_true.
    ENDIF.

*METHOD check_special_chars.
*    DATA: lv_pattern TYPE string.
*
*    " 1. Xây dựng Regex Pattern động
*    " [^...] nghĩa là: Tìm ký tự nào KHÔNG nằm trong danh sách này
*
*    IF iv_allow_num = abap_true.
*       lv_pattern = '[^A-Z0-9'.  " Cho phép A-Z và 0-9
*    ELSE.
*       lv_pattern = '[^A-Z'.     " Chỉ cho phép A-Z
*    ENDIF.
*
*    " Nếu cho phép dấu cách
*    IF iv_allow_space = abap_true.
*       CONCATENATE lv_pattern '\s' INTO lv_pattern. " \s là khoảng trắng
*    ENDIF.
*
*    " Đóng ngoặc Pattern
*    CONCATENATE lv_pattern ']' INTO lv_pattern.
*    " Kết quả pattern sẽ là '[^A-Z0-9]' hoặc '[^A-Z0-9\s]'
*
*    " 2. Kiểm tra Regex
*    FIND REGEX lv_pattern IN iv_value MATCH COUNT DATA(lv_cnt).
*
*    " 3. Trả về kết quả
*    IF lv_cnt > 0.
*      rt_invalid = abap_true. " Có ký tự lạ
*    ELSE.
*      rt_invalid = abap_false.
*    ENDIF.
*  ENDMETHOD.
  ENDMETHOD.


  method CLEAR_ERRORS.
    REFRESH gt_errors.
  endmethod.


METHOD execute_validation_hdr.
*  method EXECUTE_VALIDATION_HDR.
*     " 0. Reset status (cho logic Re-validate)
*    " [SỬA LỖI 1 & 2] Dùng Z-table field 'STATUS'
*    cs_header-status  = ' '.
*    cs_header-message = ''.
*
*    " --- 1. KIỂM TRA BẮT BUỘC (REQUIRED) ---
*    CALL METHOD validate_header_auart( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF. " (Sửa: status_code -> status)
*
*    CALL METHOD validate_header_vkorg( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_vtweg( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_spart( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_sales_area( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_sold_to_party( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_cust_ref( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_req_date( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    CALL METHOD validate_header_pmnttrms( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " --- 2. AUTO-FILL VÀ VALIDATE (HYBRID / MỞ) ---
*    " (A. Incoterm - Hybrid)
*    IF cs_header-incoterms IS INITIAL.
**      CALL METHOD auto_fill_incoterm
**        EXPORTING
**          iv_sold_to = cs_header-sold_to_party
**          "(...)
**        CHANGING
**          cv_incoterms = cs_header-incoterms.
*      CALL METHOD auto_fill_incoterm( CHANGING cs_header = cs_header ).
*    ELSE.
*      CALL METHOD validate_header_incoterms( CHANGING cs_header = cs_header ).
*    ENDIF.
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " (B. Currency - Auto-fill Mở)
*    IF cs_header-currency IS INITIAL.
*      CALL METHOD auto_fill_currency( CHANGING cs_header = cs_header ).
*    ELSE.
*      CALL METHOD validate_header_currency( CHANGING cs_header = cs_header ).
*    ENDIF.
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " (C. Price Date - Auto-fill Mở)
*    IF cs_header-price_date IS INITIAL OR cs_header-price_date = '00000000'.
*      cs_header-price_date = cs_header-req_date.
*    ELSE.
*      CALL METHOD validate_header_price_date( CHANGING cs_header = cs_header ).
*    ENDIF.
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " (D. Order Date - Auto-fill Mở)
*    IF cs_header-order_date IS INITIAL OR cs_header-order_date = '00000000'.
*      cs_header-order_date = sy-datum.
*    ELSE.
*      CALL METHOD validate_header_order_date( CHANGING cs_header = cs_header ).
*    ENDIF.
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " (E. Sales Office / Group - Optional)
*    CALL METHOD validate_header_vkbur( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*    CALL METHOD validate_header_vkgrp( CHANGING cs_header = cs_header ).
**    IF cs_header-status = 'ERROR'. RETURN. ENDIF.
*
*    " --- 3. GÁN STATUS CUỐI CÙNG ---
*    " [SỬA LỖI 1 & 2] Dùng Z-table field 'STATUS'
**    IF cs_header-status IS INITIAL.
**      cs_header-status = 'READY'.
**      cs_header-message = 'Success'.
**    ELSEIF cs_header-status = 'W'.
**      cs_header-status = 'INCOMP'. " (Chuyển 'W' (Warning) thành 'INCOMP' (Incomplete))
**      cs_header-message = 'Incomplete'. " (Gán message chung nếu cần)
**    ELSE.
**      cs_header-status = 'ERROR'.
***      cs_header-message = 'Error'. " (Gán message chung nếu cần)
**    ENDIF.
*
**     IF cs_header-status = 'ERROR'.
**       " Đã là Error thì giữ nguyên
**    ELSEIF cs_header-status = 'INCOMP' OR cs_header-status = 'W'.
**       cs_header-status = 'INCOMP'.
**       cs_header-message = 'Data is incomplete.'.
**    ELSE.
**       cs_header-status = 'READY'.
**       cs_header-message = 'Data is valid.'.
**    ENDIF.
*
*     " --- 3. CHỐT STATUS CUỐI CÙNG ---
*
*    " Logic An toàn: Kiểm tra lại bảng lỗi trong Class xem có lỗi nào thuộc dòng này không
*    " (Đây là chốt chặn cuối cùng để đảm bảo Status khớp với Log)
*    DATA(lt_current_errors) = get_errors( ).
*
*    " Kiểm tra xem có lỗi 'E' nào cho dòng Header này không
*    READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*      WITH KEY temp_id = cs_header-temp_id
*               msg_type = 'E'.
*    IF sy-subrc = 0.
*       cs_header-status = 'ERROR'.
*       cs_header-message = 'Data contains errors.'.
*
*    ELSE.
*       " Kiểm tra xem có lỗi 'W' (Incomplete) không
*       READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*         WITH KEY temp_id = cs_header-temp_id
*                  msg_type = 'W'.
*       IF sy-subrc = 0.
*          cs_header-status = 'INCOMP'.
*          cs_header-message = 'Data is incomplete.'.
*       ELSE.
*          " Nếu không có E, không có W -> Chắc chắn là Sạch
*          cs_header-status = 'READY'.
*          cs_header-message = 'Data is valid.'.
*       ENDIF.
*    ENDIF.
*  endmethod.


    " 0. Reset status
    cs_header-status  = ' '.
    cs_header-message = ''.

    " --- 1. KIỂM TRA BẮT BUỘC (REQUIRED) - CHẠY XUYÊN SUỐT ---
    CALL METHOD validate_header_auart( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_vkorg( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_vtweg( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_spart( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_sales_area( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_sold_to_party( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_cust_ref( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_req_date( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_pmnttrms( CHANGING cs_header = cs_header ).

    " --- 2. AUTO-FILL VÀ VALIDATE (HYBRID / MỞ) ---

    " (A. Incoterm)
    IF cs_header-incoterms IS INITIAL.
      CALL METHOD auto_fill_incoterm( CHANGING cs_header = cs_header ).
    ELSE.
      CALL METHOD validate_header_incoterms( CHANGING cs_header = cs_header ).
    ENDIF.

    " (B. Currency)
    IF cs_header-currency IS INITIAL.
      CALL METHOD auto_fill_currency( CHANGING cs_header = cs_header ).
    ELSE.
      CALL METHOD validate_header_currency( CHANGING cs_header = cs_header ).
    ENDIF.

    " (C. Price Date)
    IF cs_header-price_date IS INITIAL OR cs_header-price_date = '00000000'.
      cs_header-price_date = cs_header-REQ_DATE.
    ELSE.
      CALL METHOD validate_header_price_date( CHANGING cs_header = cs_header ).
    ENDIF.

    " (D. Order Date)
    IF cs_header-order_date IS INITIAL OR cs_header-order_date = '00000000'.
      cs_header-order_date = sy-datum.
    ELSE.
      CALL METHOD validate_header_order_date( CHANGING cs_header = cs_header ).
    ENDIF.

    " (E. Sales Office / Group)
    CALL METHOD validate_header_vkbur( CHANGING cs_header = cs_header ).
    CALL METHOD validate_header_vkgrp( CHANGING cs_header = cs_header ).

    " --- 3. CHỐT STATUS CUỐI CÙNG (DỰA TRÊN LOG THỰC TẾ) ---
    DATA(lt_current_errors) = get_errors( ).

    " A. Kiểm tra xem có lỗi 'E' nào cho dòng Header này không
    READ TABLE lt_current_errors TRANSPORTING NO FIELDS
      WITH KEY temp_id = cs_header-temp_id
               msg_type = 'E'.

    IF sy-subrc = 0.
       cs_header-status  = 'ERROR'.
       cs_header-message = 'Data contains errors.'.

    ELSE.
       " B. Kiểm tra xem có lỗi 'W' (Incomplete) không
       READ TABLE lt_current_errors TRANSPORTING NO FIELDS
         WITH KEY temp_id = cs_header-temp_id
                  msg_type = 'W'.

       IF sy-subrc = 0.
          cs_header-status  = 'INCOMP'.
          cs_header-message = 'Data is incomplete.'.
       ELSE.
          " C. Nếu không có E, không có W -> Chắc chắn là Sạch
          cs_header-status  = 'READY'.
          cs_header-message = 'Data is valid.'.
       ENDIF.
    ENDIF.
  ENDMETHOD.


  method EXECUTE_VALIDATION_ITM.
      " 1. Reset status
    cs_item-status  = ' '.
    cs_item-message = ''.

*    " 2. Kiểm tra Header (Cha)
*    IF is_header-status = 'ERROR'.
*      cs_item-status = 'ERROR'.
*      cs_item-message = 'Parent Header row has errors.'.
*      RETURN.
*    ENDIF.

    " 2. Kiểm tra Header (Cha) - [SỬA: KHÔNG RETURN NỮA]
    DATA: lv_header_error TYPE abap_bool.

    IF is_header-status = 'ERROR'.
      cs_item-status  = 'ERROR'.
      cs_item-message = 'Parent Header row has errors.'.
      lv_header_error = abap_true.
      " (Lưu ý: Không RETURN ở đây để tiếp tục check các field khác của Item)
    ENDIF.

    " --- 3. KIỂM TRA BẮT BUỘC (REQUIRED) ---
    " [SỬA LỖI]: Dùng EXPORTING để gửi is_header vào
    CALL METHOD validate_item_material(
      EXPORTING is_header = is_header
      CHANGING  cs_item   = cs_item ).
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

    CALL METHOD validate_item_store_loc( CHANGING cs_item = cs_item ).
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

    CALL METHOD validate_item_quantity( CHANGING cs_item = cs_item ).
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.



    " --- 4. AUTO-FILL & VALIDATE ---
    " (A. REQ_DATE)
*    cs_item-req_date = is_header-req_date.




    " (B. SHORT_TEXT, PER, UOM - Locked)
*    CALL METHOD auto_fill_item_basics
*      USING
*        iv_matnr = cs_item-matnr
*      CHANGING
*        cv_short_text = cs_item-short_text
*        cv_unit       = cs_item-unit
*        cv_per        = cs_item-per
*        cv_status     = cs_item-status
*        cv_message    = cs_item-message.
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

*    " (C. PLANT - Auto-fill Mở)
*    IF cs_item-plant IS INITIAL.
*    CALL METHOD auto_fill_plant
*        EXPORTING iv_matnr = cs_item-material iv_vkorg = is_header-sales_org
*        CHANGING  cv_plant = cs_item-plant.
*    ELSE.
*      " [SỬA LỖI]: Dùng EXPORTING
*      CALL METHOD validate_item_plant(
*        EXPORTING is_header = is_header
*        CHANGING  cs_item   = cs_item ).
*    ENDIF.

     " (B) Các check phụ thuộc Sales Area (Chỉ chạy nếu Header có Sales Area)
    IF is_header-sales_org IS NOT INITIAL.
        " Check Plant
        IF cs_item-plant IS INITIAL.
          CALL METHOD auto_fill_plant
            EXPORTING iv_matnr = cs_item-material iv_vkorg = is_header-sales_org
            CHANGING  cv_plant = cs_item-plant.
        ELSE.
          CALL METHOD validate_item_plant( EXPORTING is_header = is_header CHANGING cs_item = cs_item ).
        ENDIF.


    " Check Pricing Proc
        IF cs_item-price_proc IS INITIAL.
*           CALL METHOD auto_fill_price_proc_item( EXPORTING is_header = is_header CHANGING cv_price_proc = cs_item-price_proc ).
        ELSE.
           CALL METHOD validate_item_pricing_proc( EXPORTING is_header = is_header CHANGING cs_item = cs_item ).
        ENDIF.
    ENDIF.

*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

    " (D. SHIP_POINT - Auto-fill Mở)
    IF cs_item-ship_point IS INITIAL.
        CALL METHOD auto_fill_ship_point( CHANGING cs_item = cs_item ).
    ELSE.
       CALL METHOD validate_item_ship_point( CHANGING cs_item = cs_item ).
    ENDIF.
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

*    " (E. PRICE_PROC - Auto-fill Mở)
*    IF cs_item-price_proc IS INITIAL.
**       CALL METHOD auto_fill_price_proc_item(
**         USING    is_header     = is_header
**         CHANGING cv_price_proc = cs_item-price_proc ).
*    ELSE.
*       " [SỬA LỖI]: Dùng EXPORTING
*       CALL METHOD validate_item_pricing_proc(
*         EXPORTING is_header = is_header
*         CHANGING  cs_item   = cs_item ).
*    ENDIF.
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

    " (F. UNIT PRICE & COND. TYPE - Hybrid)
    IF cs_item-unit_price IS NOT INITIAL.
      IF cs_item-cond_type IS INITIAL.
        cs_item-status = 'ERROR'.
        cs_item-message = 'Cond. Type is required if Unit Price is entered'.

        " [SỬA LỖI]: Convert String sang BAPI_MSG
        CALL METHOD add_error
          EXPORTING
            iv_temp_id   = cs_item-temp_id
            iv_item_no   = cs_item-item_no
            iv_fieldname = 'COND_TYPE'
            iv_msg_type  = 'E'
            iv_message   =  cs_item-message.
      ELSE.
        CALL METHOD validate_item_unit_price( CHANGING cs_item = cs_item ).
      ENDIF.
    ENDIF.
*    IF cs_item-status = 'ERROR'. RETURN. ENDIF.

    " --- 5. GÁN STATUS CUỐI CÙNG ---
*    IF cs_item-status IS INITIAL.
*      cs_item-status = 'READY'.
*      cs_item-message = 'Success'.
*    ELSEIF cs_item-status = 'W'.
*      cs_item-status = 'INCOMP'.
*      cs_item-message = 'Incomplete'.
*    ELSE.
*      cs_item-status = 'ERROR'.
*      " (Giữ nguyên message lỗi cũ)
*    ENDIF.

" --- 5. CHỐT STATUS CUỐI CÙNG (Logic An toàn: Check Log) ---



*
*    " Lấy danh sách lỗi hiện tại trong Class
*    DATA(lt_current_errors) = get_errors( ).
*
*    " A. Kiểm tra xem Item này có lỗi 'E' nào không
*    READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*      WITH KEY temp_id = cs_item-temp_id
*               item_no = cs_item-item_no
*               msg_type = 'E'.
*
*    IF sy-subrc = 0.
*       " Nếu tìm thấy ít nhất 1 lỗi E -> Chắc chắn là ERROR
*       cs_item-status = 'ERROR'.
*       " (Message cụ thể đã nằm trong Log, ở đây có thể để trống hoặc message chung)
*
*    ELSE.
*       " B. Nếu không có E, kiểm tra xem có Warning 'W' không
*       READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*         WITH KEY temp_id = cs_item-temp_id
*                  item_no = cs_item-item_no
*                  msg_type = 'W'.
*
*       IF sy-subrc = 0.
*          " Nếu có W -> Là INCOMPLETE
*          cs_item-status = 'INCOMP'.
*       ELSE.
*          " C. Nếu không có E, không có W -> Chắc chắn là READY
*          cs_item-status = 'READY'.
*       ENDIF.
*    ENDIF.

*    " --- 5. CHỐT STATUS ---
*    " Nếu Header lỗi, thì Item chắc chắn phải là ERROR (dù các field item đúng hết)
*    IF lv_header_error = abap_true.
*       cs_item-status = 'ERROR'.
*    ELSEIF cs_item-status = 'ERROR'.
*       " Giữ nguyên
*    ELSEIF cs_item-status = 'W' OR cs_item-status = 'INCOMP'.
*       cs_item-status = 'INCOMP'.
*    ELSE.
*       cs_item-status = 'READY'.
*    ENDIF.


*    " --- 5. CHỐT STATUS CUỐI CÙNG (Logic An toàn: Check Log) ---
*
*    " Lấy danh sách lỗi hiện tại trong Class
*    DATA(lt_current_errors) = get_errors( ).
*
*    " A. Kiểm tra xem Item này có lỗi 'E' nào không
*    READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*      WITH KEY temp_id = cs_item-temp_id
*               item_no = cs_item-item_no
*               msg_type = 'E'.
*
*    IF sy-subrc = 0 OR lv_header_error = abap_true.
*       " [QUAN TRỌNG]: Nếu tìm thấy lỗi E trong log HOẶC Header cha bị lỗi
*       " -> Chắc chắn là ERROR
*       cs_item-status = 'ERROR'.
*
*       IF lv_header_error = abap_true AND cs_item-message IS INITIAL.
*          cs_item-message = 'Parent Header row has errors.'.
*       ELSEIF cs_item-message IS INITIAL.
*          cs_item-message = 'Item contains errors.'.
*       ENDIF.
*
*    ELSE.
*       " B. Nếu không có E, kiểm tra xem có Warning 'W' không
*       READ TABLE lt_current_errors TRANSPORTING NO FIELDS
*         WITH KEY temp_id = cs_item-temp_id
*                  item_no = cs_item-item_no
*                  msg_type = 'W'.
*
*       IF sy-subrc = 0.
*          " Nếu có W -> Là INCOMPLETE
*          cs_item-status = 'INCOMP'.
*          cs_item-message = 'Item is incomplete.'.
*       ELSE.
*          " C. Nếu không có E, không có W, không có Header Error -> READY
*          cs_item-status = 'READY'.
*          cs_item-message = 'Item is valid.'.
*       ENDIF.
*    ENDIF.


      " --- 5. CHỐT STATUS CUỐI CÙNG (Logic Ưu tiên ERROR) ---

    " Kiểm tra lại bảng Log lần cuối (Chốt chặn)
    DATA(lt_current_errors) = get_errors( ).

    READ TABLE lt_current_errors TRANSPORTING NO FIELDS
      WITH KEY temp_id = cs_item-temp_id
               item_no = cs_item-item_no
               msg_type = 'E'.

    " [LOGIC MỚI]:
    " 1. Nếu Header cha lỗi -> Chắc chắn ERROR
    " 2. Nếu Log có lỗi E -> Chắc chắn ERROR
    " 3. Nếu trong quá trình chạy ở trên đã bị gán ERROR -> Giữ nguyên ERROR

    IF lv_header_error = abap_true OR sy-subrc = 0 OR cs_item-status = 'ERROR'.
       cs_item-status = 'ERROR'.
       IF cs_item-message IS INITIAL. cs_item-message = 'Item contains errors.'. ENDIF.

    ELSE.
       " Nếu không phải ERROR, kiểm tra xem có Warning (Incomplete) không
       READ TABLE lt_current_errors TRANSPORTING NO FIELDS
         WITH KEY temp_id = cs_item-temp_id
                  item_no = cs_item-item_no
                  msg_type = 'W'.

       IF sy-subrc = 0 OR cs_item-status = 'INCOMP' OR cs_item-status = 'W'.
          cs_item-status = 'INCOMP'.
          IF cs_item-message IS INITIAL. cs_item-message = 'Item is incomplete.'. ENDIF.
       ELSE.
          " Sạch sẽ -> Ready
          cs_item-status = 'READY'.
          cs_item-message = 'Item is valid.'.
       ENDIF.
    ENDIF.

    ENDMETHOD.


METHOD execute_validation_prc.
    " Method này nhận vào 1 dòng Pricing (cs_pricing)

    cs_pricing-status  = ' '.
    cs_pricing-message = ''.

    " --- Validate từng trường ---

    " 1. Condition Type (Quan trọng nhất)
    CALL METHOD validate_prc_cond_type( CHANGING cs_pricing = cs_pricing ).

    " 2. Amount
    CALL METHOD validate_prc_amount( CHANGING cs_pricing = cs_pricing ).

    " 3. Currency
    CALL METHOD validate_prc_currency( CHANGING cs_pricing = cs_pricing ).

    " 4. Per
    CALL METHOD validate_prc_per( CHANGING cs_pricing = cs_pricing ).

    " 5. UoM
    CALL METHOD validate_prc_uom( CHANGING cs_pricing = cs_pricing ).

    " --- Chốt Status ---
    IF cs_pricing-status = 'ERROR'.
      " Giữ nguyên
    ELSEIF cs_pricing-status = 'W'.
      cs_pricing-status = 'INCOMP'.
    ELSE.
      cs_pricing-status = 'READY'.
    ENDIF.
  ENDMETHOD.


  method GET_ERRORS.
    rt_errors = gt_errors.
  endmethod.


  METHOD set_context.
    gv_current_req_id = iv_req_id.
ENDMETHOD.


METHOD validate_header_auart.
*  method VALIDATE_HEADER_AUART.
*   " (XÓA BỎ: TYPES: BEGIN OF ty_tvak_buf... END OF.)
*    " (XÓA BỎ: DATA: gt_tvak_buf...)
*    " (Lý do: Chúng đã được khai báo ở tab "Types" và "Attributes" của Class)
*
*    DATA: lv_auart TYPE vbak-auart,
*          ls_tvak  TYPE ty_tvak_buf, " (Class 'hiểu' kiểu này vì đã ở tab "Types")
*          lv_found TYPE abap_bool.
*
*    " [SỬA LỖI 1] Dùng STATUS (Z-table) thay vì STATUS_CODE/TEXT
*    CLEAR: cs_header-status, cs_header-message.
*    lv_auart = cs_header-order_type.
*    SHIFT lv_auart LEFT DELETING LEADING space.
*    TRANSLATE lv_auart TO UPPER CASE.
*
*    IF lv_auart IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa: 'E' -> 'ERROR')
*      " (XÓA: cs_header-status_text = 'Error'.)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '000' INTO cs_header-message.
*
*      " [SỬA LỖI 4] Thay PERFORM bằng CALL METHOD (của Class)
*      CALL METHOD add_error
*        EXPORTING
*          iv_temp_id   = cs_header-temp_id
*          iv_item_no   = '000000'
*          iv_fieldname = 'ORDER_TYPE'
*          iv_msg_type  = 'E'
*          iv_message   = cs_header-message.
*      RETURN.
*    ENDIF.
*
*    " [SỬA LỖI 4] Thay PERFORM bằng CALL METHOD (của Class)
*    CALL METHOD buffer_load_tvak
*      EXPORTING
*        iv_auart = lv_auart
*      CHANGING
*        es_tvak  = ls_tvak
*        ev_found = lv_found.
*
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      " (XÓA: cs_header-status_text)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '001' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-vbtyp <> 'C'.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '002' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-sperr IS NOT INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '003' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-numki IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '004' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (Sửa: 'S' -> 'READY')
*      cs_header-message = 'Sales Order Type is valid.'.
*    ENDIF.
*  endmethod.

*  method VALIDATE_HEADER_AUART.
*   " (XÓA BỎ: TYPES: BEGIN OF ty_tvak_buf... END OF.)
*    " (XÓA BỎ: DATA: gt_tvak_buf...)
*    " (Lý do: Chúng đã được khai báo ở tab "Types" và "Attributes" của Class)
*
*    DATA: lv_auart TYPE vbak-auart,
*          ls_tvak  TYPE ty_tvak_buf, " (Class 'hiểu' kiểu này vì đã ở tab "Types")
*          lv_found TYPE abap_bool.
*
*    " [SỬA LỖI 1] Dùng STATUS (Z-table) thay vì STATUS_CODE/TEXT
**    CLEAR: cs_header-status, cs_header-message.
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*    lv_auart = cs_header-order_type.
*    SHIFT lv_auart LEFT DELETING LEADING space.
*    TRANSLATE lv_auart TO UPPER CASE.
*
*    IF lv_auart IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa: 'E' -> 'ERROR')
*      " (XÓA: cs_header-status_text = 'Error'.)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '000' INTO cs_header-message.
*
*      " [SỬA LỖI 4] Thay PERFORM bằng CALL METHOD (của Class)
*      CALL METHOD add_error
*        EXPORTING
*          iv_temp_id   = cs_header-temp_id
*          iv_item_no   = '000000'
*          iv_fieldname = 'ORDER_TYPE'
*          iv_msg_type  = 'E'
*          iv_message   = cs_header-message.
*      RETURN.
*    ENDIF.
*
*    " [SỬA LỖI 4] Thay PERFORM bằng CALL METHOD (của Class)
*    CALL METHOD buffer_load_tvak
*      EXPORTING
*        iv_auart = lv_auart
*      CHANGING
*        es_tvak  = ls_tvak
*        ev_found = lv_found.
*
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      " (XÓA: cs_header-status_text)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '001' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-vbtyp <> 'C'.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '002' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-sperr IS NOT INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '003' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_tvak-numki IS INITIAL.
*      cs_header-status = 'ERROR'. " (Sửa)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '004' WITH lv_auart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*  endmethod.


    CLEAR cs_header-message.
    DATA: lv_auart TYPE vbak-auart.
    lv_auart = cs_header-order_type.

    " 1. Check Required
    IF lv_auart IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E'
        iv_message = 'Sales Order Type is required' ).
      RETURN.
    ENDIF.

    " 2. Check Length (Thực ra đã tự cắt bởi cấu trúc, nhưng check logic 4 char)
    " (ABAP tự handle length khi gán, nên ta check Format quan trọng hơn)

    " 3. Check Special Chars (Chỉ cho phép chữ và số)
    IF check_special_chars( iv_value = lv_auart ) = abap_true.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E'
        iv_message = 'Sales Order Type contains invalid characters' ).
      RETURN.
    ENDIF.

    " 4. Check Domain/Existence (TVAK) - Basic Check
    " (Giúp user biết lỗi sai mã trước khi gọi BAPI)
    SELECT SINGLE auart FROM tvak INTO @DATA(lv_dummy) WHERE auart = @lv_auart.
    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'ORDER_TYPE' iv_msg_type = 'E'
        iv_message = |Sales Order Type { lv_auart } does not exist in configuration| ).
    ENDIF.
  ENDMETHOD.


METHOD validate_header_currency.
*  METHOD validate_header_currency.
*    DATA: lv_waers TYPE vbak-waerk,
*          ls_tcurc TYPE ty_tcurc_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_waers = cs_header-currency.
*    SHIFT lv_waers LEFT DELETING LEADING space.
*    TRANSLATE lv_waers TO UPPER CASE.
*    IF lv_waers IS INITIAL.
*      " (SỬA: Bỏ Required, vì đây là Auto-fill Mở)
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tcurc( EXPORTING iv_waers = lv_waers CHANGING es_tcurc = ls_tcurc ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '042' WITH lv_waers INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CURRENCY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = |Currency { lv_waers } is valid.|.
*    ENDIF.
*  ENDMETHOD.

    DATA: ls_tcurc TYPE ty_tcurc_buf,
          lv_found TYPE abap_bool.

    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    TRANSLATE cs_header-currency TO UPPER CASE.

    IF cs_header-currency IS INITIAL. RETURN. ENDIF. " Optional (Auto-fill)

    CALL METHOD buffer_load_tcurc( EXPORTING iv_waers = cs_header-currency CHANGING es_tcurc = ls_tcurc ev_found = lv_found ).
    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '042' WITH cs_header-currency INTO cs_header-message.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CURRENCY' iv_msg_type = 'E' iv_message = cs_header-message ).
    ENDIF.
  ENDMETHOD.


METHOD validate_header_cust_ref.
*  METHOD validate_header_cust_ref.
*    DATA: lv_auart TYPE vbak-auart,
*          lv_bstnk TYPE vbak-bstnk,
*          lv_prbst TYPE tvak-prbst,
*          lv_kunnr TYPE kna1-kunnr,
*          lv_vbeln TYPE vbak-vbeln.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_auart = cs_header-order_type.
*    lv_bstnk = cs_header-cust_ref.
*    lv_kunnr = cs_header-sold_to_party.
*    SHIFT lv_bstnk LEFT DELETING LEADING space.
*    SHIFT lv_bstnk RIGHT DELETING TRAILING space.
*    IF strlen( lv_bstnk ) > 35.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '022' WITH '35' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF lv_bstnk CP '*[*\x00-\x1F*]*'.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '024' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    SELECT SINGLE prbst
*      INTO @lv_prbst
*      FROM tvak
*      WHERE auart = @lv_auart.
*    IF lv_prbst = 'A' AND lv_bstnk IS NOT INITIAL.
*      IF lv_kunnr IS NOT INITIAL.
*        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*          EXPORTING input  = lv_kunnr
*          IMPORTING output = lv_kunnr.
*      ENDIF.
*      SELECT SINGLE vbeln
*        INTO @lv_vbeln
*        FROM vbak
*        WHERE bstnk = @lv_bstnk
*          AND kunnr = @lv_kunnr.
*      IF sy-subrc = 0.
*        cs_header-status = 'ERROR'. " (SỬA)
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '023' WITH lv_bstnk lv_kunnr lv_auart INTO cs_header-message.
*        CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*        RETURN.
*      ENDIF.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      IF lv_bstnk IS INITIAL.
*        cs_header-message = 'Customer Reference (BSTNK) not provided.'.
*      ELSE.
*        cs_header-message = 'Customer Reference is valid.'.
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.

*  METHOD validate_header_cust_ref.
*    DATA: lv_auart TYPE vbak-auart,
*          lv_bstnk TYPE vbak-bstnk,
*          lv_prbst TYPE tvak-prbst,
*          lv_kunnr TYPE kna1-kunnr,
*          lv_vbeln TYPE vbak-vbeln.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
**    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_auart = cs_header-order_type.
*    lv_bstnk = cs_header-cust_ref.
*    lv_kunnr = cs_header-sold_to_party.
*    SHIFT lv_bstnk LEFT DELETING LEADING space.
*    SHIFT lv_bstnk RIGHT DELETING TRAILING space.
*    IF strlen( lv_bstnk ) > 35.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '022' WITH '35' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF lv_bstnk CP '*[*\x00-\x1F*]*'.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '024' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    SELECT SINGLE prbst
*      INTO @lv_prbst
*      FROM tvak
*      WHERE auart = @lv_auart.
*    IF lv_prbst = 'A' AND lv_bstnk IS NOT INITIAL.
*      IF lv_kunnr IS NOT INITIAL.
*        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*          EXPORTING input  = lv_kunnr
*          IMPORTING output = lv_kunnr.
*      ENDIF.
*      SELECT SINGLE vbeln
*        INTO @lv_vbeln
*        FROM vbak
*        WHERE bstnk = @lv_bstnk
*          AND kunnr = @lv_kunnr.
*      IF sy-subrc = 0.
*        cs_header-status = 'ERROR'. " (SỬA)
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '023' WITH lv_bstnk lv_kunnr lv_auart INTO cs_header-message.
*        CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = cs_header-message ).
*        RETURN.
*      ENDIF.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      IF lv_bstnk IS INITIAL.
*        cs_header-message = 'Customer Reference (BSTNK) not provided.'.
*      ELSE.
*        cs_header-message = 'Customer Reference is valid.'.
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.


    CLEAR cs_header-message.

    " 1. Required
    IF cs_header-cust_ref IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'CUST_REF' iv_msg_type = 'E' iv_message = 'Customer Reference is required' ).
    ENDIF.

    " 2. Length Check (Mặc dù structure đã cắt, nhưng nếu muốn báo lỗi thì check raw data từ Excel,
    "    nhưng ở đây ta check trên structure ZTB đã lưu nên nó đã bị cắt rồi).
    "    Ta có thể check độ dài tối thiểu hoặc các ký tự cấm (ví dụ ký tự xuống dòng).
  ENDMETHOD.


METHOD validate_header_inco2.
    CLEAR cs_header-message.

    " 1. Check Length (Tối đa 28 ký tự cho INCO2_L)
    IF strlen( cs_header-inco2 ) > 28.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'INCO2' iv_msg_type = 'E'
        iv_message = 'Incoterm Location is too long (Max 28 chars)' ).
      RETURN.
    ENDIF.

    " 2. Logic Phụ thuộc (Nếu Incoterm là 'EXW' thì thường không cần Location, nhưng 'CIF' thì cần)
    " (Cái này có thể để BAPI check hoặc check sơ bộ)
    IF cs_header-incoterms IS NOT INITIAL AND cs_header-inco2 IS INITIAL.
       " Logic: Kiểm tra TINCT-EIGEN (Nếu = 'X' là bắt buộc nhập Location)
       " (Bạn có thể thêm logic này nếu muốn chặt chẽ, hoặc để BAPI lo)
    ENDIF.
  ENDMETHOD.


METHOD validate_header_incoterms.
*  METHOD validate_header_incoterms.
*    DATA: lv_inco1 TYPE vbkd-inco1,
*          ls_tinct TYPE ty_tinct_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*    lv_inco1 = cs_header-incoterms.
*    SHIFT lv_inco1 LEFT DELETING LEADING space.
*    TRANSLATE lv_inco1 TO UPPER CASE.
*    IF lv_inco1 IS INITIAL.
*      " (SỬA: Bỏ Required, vì đây là Hybrid)
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tinct( EXPORTING iv_inco1 = lv_inco1 CHANGING es_tinct = ls_tinct ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '038' WITH lv_inco1 INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'INCOTERMS' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = |Incoterms { lv_inco1 } is valid.|.
*    ENDIF.
*  ENDMETHOD.


    CLEAR cs_header-message.

    IF cs_header-incoterms IS NOT INITIAL.
       SELECT SINGLE inco1 FROM tinct INTO @DATA(lv_dummy) WHERE inco1 = @cs_header-incoterms.
       IF sy-subrc <> 0.
          cs_header-status = 'ERROR'.
          CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
            iv_fieldname = 'INCOTERMS' iv_msg_type = 'E'
            iv_message = |Incoterm { cs_header-incoterms } is not valid| ).
       ENDIF.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_order_date.
*  METHOD validate_header_order_date.
*    DATA lv_date_output TYPE CHAR10.
*    DATA: lv_order_date TYPE dats,
*          lv_today      TYPE dats.
*    lv_today = sy-datum.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_order_date = cs_header-order_date.
*    IF lv_order_date IS INITIAL OR lv_order_date = '00000000'.
*      " (SỬA: Bỏ Required, vì đây là Auto-fill Mở)
*      RETURN.
*    ENDIF.
*    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
*      EXPORTING date = lv_order_date
*      EXCEPTIONS plausibility_check_failed = 1
*                 OTHERS                   = 2.
*    IF sy-subrc <> 0.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '045' WITH lv_order_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_DATE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF lv_order_date > lv_today.
*      cs_header-status = 'INCOMP'. " (SỬA: 'W' -> 'INCOMP')
*      MESSAGE ID gc_msgid TYPE 'W' NUMBER '047' WITH lv_order_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_DATE' iv_msg_type = 'W' iv_message = cs_header-message ).
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      WRITE lv_order_date TO lv_date_output DD/MM/YYYY.
*      CONDENSE lv_date_output.
*      cs_header-message = |Order Date { lv_date_output } is valid.|.
*    ENDIF.
*  ENDMETHOD.

    DATA: lv_order_date TYPE dats,
          lv_today      TYPE dats.
    lv_today = sy-datum.

    lv_order_date = cs_header-order_date.
    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    " 1. Empty Check (Auto-fill Mở -> Không bắt buộc)
    IF lv_order_date IS INITIAL OR lv_order_date = '00000000'.
      RETURN.
    ENDIF.

    " 2. Validate Hợp lệ
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = lv_order_date
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '045' WITH lv_order_date INTO cs_header-message.
      " E047: Order Date & is invalid.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_DATE' iv_msg_type = 'E' iv_message = cs_header-message ).
      RETURN.
    ENDIF.

    " 3. Check Future Date (Ngày đặt hàng không được ở tương lai)
    IF lv_order_date > lv_today.
      IF cs_header-status <> 'ERROR'.
        cs_header-status = 'INCOMP'.
      ENDIF.
      MESSAGE ID gc_msgid TYPE 'W' NUMBER '047' WITH lv_order_date INTO cs_header-message.
      " W048: Order Date & is in the future.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'ORDER_DATE' iv_msg_type = 'W' iv_message = cs_header-message ).
    ENDIF.
  ENDMETHOD.


METHOD validate_header_pmnttrms.
*  METHOD validate_header_pmnttrms.
*    DATA: lv_zterm TYPE vbkd-zterm,
*          ls_t052  TYPE ty_t052_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_zterm = cs_header-pmnttrms.
*    SHIFT lv_zterm LEFT DELETING LEADING space.
*    TRANSLATE lv_zterm TO UPPER CASE.
*    IF lv_zterm IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '033' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PMNTTRMS' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_t052( EXPORTING iv_zterm = lv_zterm CHANGING es_t052 = ls_t052 ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '034' WITH lv_zterm INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PMNTTRMS' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = |Payment terms { lv_zterm } is valid.|.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_header_pmnttrms.
*    DATA: ls_t052  TYPE ty_t052_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    TRANSLATE cs_header-pmnttrms TO UPPER CASE.
*
*    " 1. Required Check
*    IF cs_header-pmnttrms IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '033' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PMNTTRMS' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence Check (T052)
*    CALL METHOD buffer_load_t052( EXPORTING iv_zterm = cs_header-pmnttrms CHANGING es_t052 = ls_t052 ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '034' WITH cs_header-pmnttrms INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PMNTTRMS' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    CLEAR cs_header-message.

    " Chỉ check nếu user có nhập
    IF cs_header-pmnttrms IS NOT INITIAL.
       SELECT SINGLE zterm FROM t052 INTO @DATA(lv_dummy) WHERE zterm = @cs_header-pmnttrms.
       IF sy-subrc <> 0.
          cs_header-status = 'ERROR'.
          CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
            iv_fieldname = 'PMNTTRMS' iv_msg_type = 'E'
            iv_message = |Payment Term { cs_header-pmnttrms } is not valid| ).
       ENDIF.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_price_date.
*  METHOD validate_header_price_date.
*    DATA lv_date_output TYPE CHAR10.
*    DATA: lv_price_date TYPE dats,
*          lv_req_date   TYPE dats,
*          lv_today      TYPE dats.
*    lv_today = sy-datum.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_price_date = cs_header-price_date.
*    IF lv_price_date IS INITIAL OR lv_price_date = '00000000'.
*      " (SỬA: Bỏ Required, vì đây là Auto-fill Mở)
*      " cs_header-status = 'ERROR'.
*      RETURN.
*    ENDIF.
*    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
*      EXPORTING date = lv_price_date
*      EXCEPTIONS plausibility_check_failed = 1
*                 OTHERS                   = 2.
*    IF sy-subrc <> 0.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '031' WITH lv_price_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PRICE_DATE' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    lv_req_date = cs_header-REQ_DATE.
*    IF lv_req_date IS NOT INITIAL AND lv_req_date <> '00000000'.
*      IF lv_price_date > lv_req_date.
*        cs_header-status = 'INCOMP'. " (SỬA: 'W' -> 'INCOMP')
*        MESSAGE ID gc_msgid TYPE 'W' NUMBER '032' WITH lv_price_date lv_req_date INTO cs_header-message.
*        CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PRICE_DATE' iv_msg_type = 'W' iv_message = cs_header-message ).
*      ENDIF.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      WRITE lv_price_date TO lv_date_output DD/MM/YYYY.
*      CONDENSE lv_date_output.
*      cs_header-message = |Price Date { lv_date_output } is valid.|.
*    ENDIF.
*  ENDMETHOD.

    DATA lv_date_output TYPE CHAR10.
    DATA: lv_price_date TYPE dats,
          lv_req_date   TYPE dats.

    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    " Reset message cũ của field này
    " (Lưu ý: Không clear cs_header-status ở đây nếu nó đang là ERROR từ các field trước,
    "  nhưng logic của chúng ta là chạy tuần tự nên có thể clear message).

    lv_price_date = cs_header-price_date.

    " 1. Empty Check (Auto-fill Mở -> Không bắt buộc)
    IF lv_price_date IS INITIAL OR lv_price_date = '00000000'.
      RETURN.
    ENDIF.

    " 2. Validate Hợp lệ (Check ngày có tồn tại không)
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = lv_price_date
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '031' WITH lv_price_date INTO cs_header-message.
      " E032: Price Date & is invalid.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PRICE_DATE' iv_msg_type = 'E' iv_message = cs_header-message ).
      RETURN.
    ENDIF.

    " 3. Check Logic Business (Price Date không nên lớn hơn Req. Date)
    lv_req_date = cs_header-req_date.
    IF lv_req_date IS NOT INITIAL AND lv_req_date <> '00000000'.
      IF lv_price_date > lv_req_date.
        " Chỉ cảnh báo (Warning), không chặn
        IF cs_header-status <> 'ERROR'.
          cs_header-status = 'INCOMP'.
        ENDIF.
        MESSAGE ID gc_msgid TYPE 'W' NUMBER '032' WITH lv_price_date lv_req_date INTO cs_header-message.
        " W033: Price date is after requested delivery date.
        CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'PRICE_DATE' iv_msg_type = 'W' iv_message = cs_header-message ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_req_date.
*  METHOD validate_header_req_date.
*    DATA lv_date_output TYPE CHAR10.
*    DATA: lv_req_date TYPE dats,
*          lv_today    TYPE dats.
*    lv_today = sy-datum.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_req_date = cs_header-REQ_DATE.
*    IF lv_req_date IS INITIAL OR lv_req_date = '00000000'.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '025' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
*      EXPORTING date = lv_req_date
*      EXCEPTIONS plausibility_check_failed = 1
*                 OTHERS                   = 2.
*    IF sy-subrc <> 0.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '026' WITH lv_req_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF lv_req_date < lv_today.
*      cs_header-status = 'INCOMP'. " (SỬA: 'W' -> 'INCOMP')
*      MESSAGE ID gc_msgid TYPE 'W' NUMBER '028' WITH lv_req_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'W' iv_message = cs_header-message ).
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      WRITE lv_req_date TO lv_date_output DD/MM/YYYY.
*      CONDENSE lv_date_output.
*      cs_header-message = |Requested Delivery Date { lv_date_output } is valid.|.
*    ENDIF.
*  ENDMETHOD.


*METHOD validate_header_req_date.
*    DATA: lv_date TYPE dats.
*    lv_date = cs_header-req_date.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    " 1. Required Check
*    IF lv_date IS INITIAL OR lv_date = '00000000'.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '025' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Check Valid Date
*    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
*      EXPORTING date = lv_date
*      EXCEPTIONS OTHERS = 1.
*    IF sy-subrc <> 0.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '026' WITH lv_date INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 3. Check Past Date (Warning) - Chỉ set INCOMP nếu chưa ERROR
*    IF lv_date < sy-datum.
*      IF cs_header-status <> 'ERROR'.
*        cs_header-status = 'INCOMP'. " Warning -> Incomplete
*        MESSAGE ID gc_msgid TYPE 'W' NUMBER '028' INTO cs_header-message.
*      ENDIF.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'req_date' iv_msg_type = 'W' iv_message = cs_header-message ).
*    ENDIF.
*  ENDMETHOD.



    CLEAR cs_header-message.

    " 1. Check Required (Initial hoặc 00000000)
    IF cs_header-req_date IS INITIAL OR cs_header-req_date = '00000000'.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'REQ_DATE' iv_msg_type = 'E' iv_message = 'Requested Delivery Date is required' ).
      RETURN.
    ENDIF.

    " 2. Check Valid Date (Ngày hợp lệ)
    " Hàm này check xem ngày có tồn tại trên lịch không (ví dụ không có ngày 30/02)
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = cs_header-req_date
      EXCEPTIONS OTHERS = 1.

    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'REQ_DATE' iv_msg_type = 'E'
        iv_message = 'Invalid Date format' ).
    ENDIF.

    " (Có thể thêm check ngày quá khứ nếu muốn warning)
  ENDMETHOD.


METHOD validate_header_sales_area.
*  METHOD validate_header_sales_area.
*    DATA: lv_vkorg TYPE vbak-vkorg,
*          lv_vtweg TYPE vbak-vtweg,
*          lv_spart TYPE vbak-spart,
*          ls_tvta  TYPE ty_tvta_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_vkorg = cs_header-sales_org.
*    lv_vtweg = cs_header-sales_channel.
*    lv_spart = cs_header-sales_div.
*    IF lv_vkorg IS INITIAL OR lv_vtweg IS INITIAL OR lv_spart IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '012' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tvta( EXPORTING iv_vkorg = lv_vkorg iv_vtweg = lv_vtweg iv_spart = lv_spart CHANGING es_tvta = ls_tvta ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '013' WITH lv_vkorg lv_vtweg lv_spart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Sales Area combination is valid.'.
*    ENDIF.
*  ENDMETHOD.

    DATA: ls_tvta  TYPE ty_tvta_buf,
          lv_found TYPE abap_bool.

    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    " Chỉ check khi cả 3 trường đã có dữ liệu (nếu thiếu thì đã bị bắt ở các hàm trên rồi)
    IF cs_header-sales_org IS INITIAL OR cs_header-sales_channel IS INITIAL OR cs_header-sales_div IS INITIAL.
      RETURN.
    ENDIF.

    " Check combination (TVTA)
    CALL METHOD buffer_load_tvta(
      EXPORTING iv_vkorg = cs_header-sales_org
                iv_vtweg = cs_header-sales_channel
                iv_spart = cs_header-sales_div
      CHANGING  es_tvta = ls_tvta
                ev_found = lv_found ).

    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '013' WITH cs_header-sales_org cs_header-sales_channel cs_header-sales_div INTO cs_header-message.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_sold_to_party.
*  METHOD validate_header_sold_to_party.
*    DATA: lv_kunnr TYPE kna1-kunnr,
*          lv_vkorg TYPE vbak-vkorg,
*          lv_vtweg TYPE vbak-vtweg,
*          lv_spart TYPE vbak-spart,
*          ls_kna1  TYPE ty_kna1_buf,
*          ls_knvv  TYPE ty_knvv_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_kunnr = cs_header-sold_to_party.
*    lv_vkorg = cs_header-sales_org.
*    lv_vtweg = cs_header-sales_channel.
*    lv_spart = cs_header-sales_div.
*    SHIFT lv_kunnr LEFT DELETING LEADING space.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*      EXPORTING input = lv_kunnr
*      IMPORTING output = lv_kunnr.
*    IF lv_kunnr IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '016' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_kna1( EXPORTING iv_kunnr = lv_kunnr CHANGING es_kna1 = ls_kna1 ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '017' WITH lv_kunnr INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF ls_kna1-loevm = 'X'.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '018' WITH lv_kunnr INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_knvv( EXPORTING iv_kunnr = lv_kunnr iv_vkorg = lv_vkorg iv_vtweg = lv_vtweg iv_spart = lv_spart CHANGING es_knvv = ls_knvv ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '019' WITH lv_kunnr lv_vkorg lv_vtweg lv_spart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    DATA lv_knvv_aufsd TYPE knvv-aufsd.
*    SELECT SINGLE aufsd INTO @lv_knvv_aufsd
*      FROM knvv
*      WHERE kunnr = @lv_kunnr
*        AND vkorg = @lv_vkorg
*        AND vtweg = @lv_vtweg
*        AND spart = @lv_spart.
*    IF lv_knvv_aufsd IS NOT INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '020' WITH lv_kunnr lv_vkorg lv_vtweg lv_spart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = |Customer { lv_kunnr } is valid for Sales Area { lv_vkorg }/{ lv_vtweg }/{ lv_spart }|.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_header_sold_to_party.
*    DATA: lv_kunnr TYPE kna1-kunnr,
*          ls_kna1  TYPE ty_kna1_buf,
*          ls_knvv  TYPE ty_knvv_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    lv_kunnr = cs_header-sold_to_party.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT' EXPORTING input = lv_kunnr IMPORTING output = lv_kunnr.
*
*    " 1. Required Check
*    IF lv_kunnr IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '016' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence in KNA1
*    CALL METHOD buffer_load_kna1( EXPORTING iv_kunnr = lv_kunnr CHANGING es_kna1 = ls_kna1 ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '017' WITH lv_kunnr INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 3. Check Blocked (LOEVM)
*    IF ls_kna1-loevm = 'X'.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '087' WITH lv_kunnr INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 4. Check Sales Area Extension (KNVV)
*    IF cs_header-sales_org IS NOT INITIAL. " Chỉ check nếu có Sales Area
*      CALL METHOD buffer_load_knvv(
*        EXPORTING iv_kunnr = lv_kunnr iv_vkorg = cs_header-sales_org iv_vtweg = cs_header-sales_channel iv_spart = cs_header-sales_div
*        CHANGING es_knvv = ls_knvv ev_found = lv_found ).
*
*      IF lv_found IS INITIAL.
*        cs_header-status = 'ERROR'.
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '018' WITH lv_kunnr INTO cs_header-message.
*        CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = cs_header-message ).
*        RETURN.
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.


    CLEAR cs_header-message.

    " 1. Check Special (Trước khi convert)
    " Customer ID chỉ nên chứa số hoặc chữ cái in hoa (nếu là mã ngoài)
    IF check_special_chars( iv_value = cs_header-sold_to_party ) = abap_true.
       cs_header-status = 'ERROR'.
       CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
         iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E'
         iv_message = 'Customer ID contains invalid characters' ).
       RETURN.
    ENDIF.

    " 2. Alpha Conversion (Chuẩn hóa dữ liệu cho BAPI)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input = cs_header-sold_to_party
      IMPORTING output = cs_header-sold_to_party.

    " 3. Required Check
    IF cs_header-sold_to_party IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E' iv_message = 'Sold-to Party is required' ).
      RETURN.
    ENDIF.

    " 4. Existence Check (KNA1)
    SELECT SINGLE kunnr FROM kna1 INTO @DATA(lv_dummy) WHERE kunnr = @cs_header-sold_to_party.
    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SOLD_TO_PARTY' iv_msg_type = 'E'
        iv_message = |Customer { cs_header-sold_to_party } does not exist| ).
    ENDIF.
  ENDMETHOD.


METHOD validate_header_spart.
*  METHOD validate_header_spart.
*    DATA: lv_spart TYPE vbak-spart,
*          ls_tspat TYPE ty_tspat_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_spart = cs_header-sales_div.
*    SHIFT lv_spart LEFT DELETING LEADING space.
*    TRANSLATE lv_spart TO UPPER CASE.
*    IF lv_spart IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '010' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tspat( EXPORTING iv_spart = lv_spart CHANGING es_tspat = ls_tspat ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '011' WITH lv_spart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Division is valid.'.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_header_spart.
*    DATA: lv_spart TYPE vbak-spart,
*          ls_tspat TYPE ty_tspat_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    lv_spart = cs_header-sales_div.
*    TRANSLATE lv_spart TO UPPER CASE.
*
*    " 1. Required Check
*    IF lv_spart IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '010' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence Check (TSPAT)
*    CALL METHOD buffer_load_tspat( EXPORTING iv_spart = lv_spart CHANGING es_tspat = ls_tspat ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '011' WITH lv_spart INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    " [SỬA LỖI]: Khai báo biến tường minh
    DATA: lv_spart TYPE vbak-spart,
          ls_tspat TYPE ty_tspat_buf,
          lv_found TYPE abap_bool. " <<< Khai báo ở đây

    CLEAR cs_header-message.
    lv_spart = cs_header-sales_div.
    TRANSLATE lv_spart TO UPPER CASE.

    " 1. Required
    IF lv_spart IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = 'Division is required' ).
      RETURN.
    ENDIF.

    " 2. Special Chars
    IF check_special_chars( iv_value = lv_spart ) = abap_true.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = 'Invalid characters in Division' ).
      RETURN.
    ENDIF.

    " 3. Existence (TSPAT) - [SỬA LỖI]: Bỏ DATA(...) inline
    CALL METHOD buffer_load_tspat
      EXPORTING
        iv_spart = lv_spart
      CHANGING
        ev_found = lv_found   " <<< Dùng biến đã khai báo
        es_tspat = ls_tspat.  " <<< Dùng biến đã khai báo

    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_DIV' iv_msg_type = 'E' iv_message = |Division { lv_spart } does not exist| ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_vkbur.
*  METHOD validate_header_vkbur.
*    DATA: lv_vkbur TYPE vbak-vkbur,
*          ls_tvbur TYPE ty_tvbur_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_vkbur = cs_header-sales_off.
*    SHIFT lv_vkbur LEFT DELETING LEADING space.
*    IF lv_vkbur IS INITIAL.
*      RETURN. " Optional => skip validation
*    ENDIF.
*    CALL METHOD buffer_load_tvbur( EXPORTING iv_vkbur = lv_vkbur CHANGING es_tvbur = ls_tvbur ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '014' WITH lv_vkbur INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_OFF' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Sales Office is valid.'.
*    ENDIF.
*  ENDMETHOD.

    DATA: lv_vkbur TYPE vbak-vkbur,
          ls_tvbur TYPE ty_tvbur_buf,
          lv_found TYPE abap_bool.

    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    lv_vkbur = cs_header-sales_off.
    SHIFT lv_vkbur LEFT DELETING LEADING space.

    " 1. Empty Check (Optional)
    IF lv_vkbur IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Existence Check (TVBUR)
    CALL METHOD buffer_load_tvbur( EXPORTING iv_vkbur = lv_vkbur CHANGING es_tvbur = ls_tvbur ev_found = lv_found ).

    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '014' WITH lv_vkbur INTO cs_header-message.
      " E015: Sales Office & does not exist.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_OFF' iv_msg_type = 'E' iv_message = cs_header-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_vkgrp.
*  METHOD validate_header_vkgrp.
*    DATA: lv_vkgrp TYPE vbak-vkgrp,
*          ls_tvkgr TYPE ty_tvkgr_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_vkgrp = cs_header-sales_grp.
*    SHIFT lv_vkgrp LEFT DELETING LEADING space.
*    IF lv_vkgrp IS INITIAL.
*      RETURN. " Optional => skip validation
*    ENDIF.
*    CALL METHOD buffer_load_tvkgr( EXPORTING iv_vkgrp = lv_vkgrp CHANGING es_tvkgr = ls_tvkgr ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '015' WITH lv_vkgrp INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_GRP' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Sales Group is valid.'.
*    ENDIF.
*  ENDMETHOD.

    DATA: lv_vkgrp TYPE vbak-vkgrp,
          ls_tvkgr TYPE ty_tvkgr_buf,
          lv_found TYPE abap_bool.

    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi

    lv_vkgrp = cs_header-sales_grp.
    SHIFT lv_vkgrp LEFT DELETING LEADING space.

    " 1. Empty Check (Optional)
    IF lv_vkgrp IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Existence Check (TVKGR)
    CALL METHOD buffer_load_tvkgr( EXPORTING iv_vkgrp = lv_vkgrp CHANGING es_tvkgr = ls_tvkgr ev_found = lv_found ).

    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '015' WITH lv_vkgrp INTO cs_header-message.
      " E016: Sales Group & does not exist.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_GRP' iv_msg_type = 'E' iv_message = cs_header-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_header_vkorg.
*  METHOD validate_header_vkorg.
*    DATA: lv_vkorg TYPE vbak-vkorg,
*          ls_tvko  TYPE ty_tvko_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA: Xóa status_code/text)
*    lv_vkorg = cs_header-sales_org.
*    SHIFT lv_vkorg LEFT DELETING LEADING space.
*    TRANSLATE lv_vkorg TO UPPER CASE.
*    IF lv_vkorg IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '006' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tvko( EXPORTING iv_vkorg = lv_vkorg CHANGING es_tvko = ls_tvko ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '007' WITH lv_vkorg INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Sales Organization is valid.'.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_header_vkorg.
*    DATA: lv_vkorg TYPE vbak-vkorg,
*          ls_tvko  TYPE ty_tvko_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    " Reset chỉ message của field này, không reset toàn bộ status header
*    " (Vì status header là tổng hợp)
*
*    lv_vkorg = cs_header-sales_org.
*    TRANSLATE lv_vkorg TO UPPER CASE.
*
*    " 1. Required Check
*    IF lv_vkorg IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '006' INTO cs_header-message. " E000: Sales Org required
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence Check (TVKO)
*    CALL METHOD buffer_load_tvko( EXPORTING iv_vkorg = lv_vkorg CHANGING es_tvko = ls_tvko ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '007' WITH lv_vkorg INTO cs_header-message. " E007: Not found
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    CLEAR cs_header-message.
    DATA: lv_vkorg TYPE vbak-vkorg.
    lv_vkorg = cs_header-sales_org.

    " 1. Required
    IF lv_vkorg IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = 'Sales Organization is required' ).
      RETURN.
    ENDIF.

    " 2. Special Chars
    IF check_special_chars( iv_value = lv_vkorg ) = abap_true.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = 'Invalid characters in Sales Org' ).
      RETURN.
    ENDIF.

    " 3. Existence (TVKO)
    SELECT SINGLE vkorg FROM tvko INTO @DATA(lv_dummy) WHERE vkorg = @lv_vkorg.
    IF sy-subrc <> 0.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_ORG' iv_msg_type = 'E' iv_message = |Sales Org { lv_vkorg } does not exist| ).
    ENDIF.
  ENDMETHOD.


METHOD validate_header_vtweg.
*  METHOD validate_header_vtweg.
*    DATA: lv_vtweg TYPE vbak-vtweg,
*          ls_tvtw  TYPE ty_tvtw_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_header-status, cs_header-message. " (SỬA)
*    lv_vtweg = cs_header-sales_channel.
*    SHIFT lv_vtweg LEFT DELETING LEADING space.
*    TRANSLATE lv_vtweg TO UPPER CASE.
*    IF lv_vtweg IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '008' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tvtw( EXPORTING iv_vtweg = lv_vtweg CHANGING es_tvtw = ls_tvtw ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '009' WITH lv_vtweg INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*    IF cs_header-status IS INITIAL.
*      cs_header-status = 'READY'. " (SỬA)
*      cs_header-message = 'Distribution Channel is valid.'.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_header_vtweg.
*    DATA: lv_vtweg TYPE vbak-vtweg,
*          ls_tvtw  TYPE ty_tvtw_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_header-message. " <<< ĐÚNG: Chỉ xóa message của field này thôi
*
*    lv_vtweg = cs_header-sales_channel.
*    TRANSLATE lv_vtweg TO UPPER CASE.
*
*    " 1. Required Check
*    IF lv_vtweg IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '008' INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence Check (TVTW)
*    CALL METHOD buffer_load_tvtw( EXPORTING iv_vtweg = lv_vtweg CHANGING es_tvtw = ls_tvtw ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_header-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '009' WITH lv_vtweg INTO cs_header-message.
*      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000' iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = cs_header-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    " [SỬA LỖI]: Khai báo biến tường minh (Explicit)
    DATA: lv_vtweg TYPE vbak-vtweg,
          ls_tvtw  TYPE ty_tvtw_buf,
          lv_found TYPE abap_bool.  " <<< Khai báo ở đây

    CLEAR cs_header-message.
    lv_vtweg = cs_header-sales_channel.
    TRANSLATE lv_vtweg TO UPPER CASE.

    " 1. Required
    IF lv_vtweg IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = 'Distribution Channel is required' ).
      RETURN.
    ENDIF.

    " 2. Special Chars
    IF check_special_chars( iv_value = lv_vtweg ) = abap_true.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = 'Invalid characters in Dist. Channel' ).
      RETURN.
    ENDIF.

    " 3. Existence (TVTW) - [SỬA LỖI]: Bỏ DATA(...) inline
    CALL METHOD buffer_load_tvtw
      EXPORTING
        iv_vtweg = lv_vtweg
      CHANGING
        ev_found = lv_found  " <<< Dùng biến đã khai báo
        es_tvtw  = ls_tvtw.  " <<< Dùng biến đã khai báo

    IF lv_found IS INITIAL.
      cs_header-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_header-temp_id iv_item_no = '000000'
        iv_fieldname = 'SALES_CHANNEL' iv_msg_type = 'E' iv_message = |Dist. Channel { lv_vtweg } does not exist| ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_item_material.
*  METHOD validate_item_material.
*    DATA: lv_matnr TYPE mara-matnr,
*          lv_vkorg TYPE vbak-vkorg,
*          lv_vtweg TYPE vbak-vtweg,
*          ls_mara  TYPE ty_mara_buf,
*          ls_mvke  TYPE ty_mvke_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_item-status, cs_item-message. " (SỬA)
*    lv_matnr = cs_item-MATERIAL.
*    SHIFT lv_matnr LEFT DELETING LEADING space.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*      EXPORTING input = lv_matnr IMPORTING output = lv_matnr.
*
*    IF lv_matnr IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '051' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    CALL METHOD buffer_load_mara( EXPORTING iv_matnr = lv_matnr CHANGING es_mara = ls_mara ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '052' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_mara-lvorm = 'X'.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '053' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " (SỬA: Không READ gt_so_header, dùng is_header)
*    IF is_header IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '083' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*    lv_vkorg = is_header-sales_org.
*    lv_vtweg = is_header-sales_channel.
*
*    CALL METHOD buffer_load_mvke( EXPORTING iv_matnr = lv_matnr iv_vkorg = lv_vkorg iv_vtweg = lv_vtweg CHANGING es_mvke = ls_mvke ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '054' WITH lv_matnr lv_vkorg lv_vtweg INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    IF ls_mvke-lvorm = 'X'.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '055' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATNR' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_item_material.
*    DATA: lv_matnr TYPE mara-matnr,
*          lv_vkorg TYPE vbak-vkorg,
*          lv_vtweg TYPE vbak-vtweg,
*          ls_mara  TYPE ty_mara_buf,
*          ls_mvke  TYPE ty_mvke_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_item-message.
*
*
*    " [SỬA LỖI]: Dùng tên trường MATERIAL
*    lv_matnr = cs_item-material.
*    SHIFT lv_matnr LEFT DELETING LEADING space.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*      EXPORTING input = lv_matnr IMPORTING output = lv_matnr.
*
*    " 1. Required Check
*    IF lv_matnr IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '051' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Check Existence (MARA)
*    CALL METHOD buffer_load_mara( EXPORTING iv_matnr = lv_matnr CHANGING es_mara = ls_mara ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '052' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " 3. Check Blocked (MARA-LVORM)
*    IF ls_mara-lvorm = 'X'.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '053' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " 4. Check Sales View (MVKE)
*    IF is_header IS INITIAL OR is_header-status = 'ERROR'.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '084' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    lv_vkorg = is_header-sales_org.
*    lv_vtweg = is_header-sales_channel.
*
*    CALL METHOD buffer_load_mvke( EXPORTING iv_matnr = lv_matnr iv_vkorg = lv_vkorg iv_vtweg = lv_vtweg CHANGING es_mvke = ls_mvke ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '054' WITH lv_matnr lv_vkorg lv_vtweg INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " 5. Check Blocked in Sales Area (MVKE-LVORM)
*    IF ls_mvke-lvorm = 'X'.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '055' WITH lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'MATERIAL' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
**    IF cs_item-status IS INITIAL.
**      cs_item-status = 'READY'.
**      cs_item-message = |Material { lv_matnr } is valid.|.
**    ENDIF.
*  ENDMETHOD.

    CLEAR cs_item-message.

    " 1. Check Special Chars (Bật iv_allow_space = 'X')
    IF check_special_chars( iv_value = cs_item-material iv_allow_space = abap_true ) = abap_true.
       cs_item-status = 'ERROR'.
       CALL METHOD add_error(
          iv_temp_id   = cs_item-temp_id
          iv_item_no   = cs_item-item_no
          iv_fieldname = 'MATERIAL'
          iv_msg_type  = 'E'
          iv_message   = 'Material Number contains invalid characters' ).
       RETURN.
    ENDIF.

    " 2. Alpha Conversion (Giữ nguyên)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input  = cs_item-material
      IMPORTING output = cs_item-material.

    " 3. Required Check (Giữ nguyên)
    IF cs_item-material IS INITIAL.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error(
          iv_temp_id   = cs_item-temp_id
          iv_item_no   = cs_item-item_no
          iv_fieldname = 'MATERIAL'
          iv_msg_type  = 'E'
          iv_message   = 'Material is required' ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD validate_item_per.
*    DATA: lv_per TYPE decfloat16.
*    " (SỬA: Bỏ Clear status)
*    IF cs_item-per IS INITIAL.
*      RETURN. " (SỬA: Bỏ Required, vì đây là Locked/Auto-fill)
*    ENDIF.
*    TRY.
*        lv_per = cs_item-per.
*      CATCH cx_sy_conversion_no_number.
*        cs_item-status = 'ERROR'. " (SỬA)
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '120' WITH cs_item-per INTO cs_item-message.
*        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PER' iv_msg_type = 'E' iv_message = cs_item-message ).
*        RETURN.
*    ENDTRY.
*    IF lv_per <= 0.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '121' WITH cs_item-per INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PER' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.

    DATA: lv_per TYPE decfloat16.

    IF cs_item-per IS INITIAL. RETURN. ENDIF.

    TRY.
        lv_per = cs_item-per.
      CATCH cx_sy_conversion_no_number.
        cs_item-status = 'ERROR'.
        MESSAGE ID gc_msgid TYPE 'E' NUMBER '070' WITH cs_item-per INTO cs_item-message.
        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PER' iv_msg_type = 'E' iv_message = cs_item-message ).
        RETURN.
    ENDTRY.

    IF lv_per <= 0.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '071' WITH cs_item-per INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PER' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_item_plant.
*  METHOD validate_item_plant.
*    DATA: lv_werks TYPE vbap-werks,
*          ls_t001w TYPE ty_t001w_buf,
*          lv_found TYPE abap_bool.
*    " (SỬA: Bỏ Clear status)
*    lv_werks = cs_item-plant.
*    SHIFT lv_werks LEFT DELETING LEADING space.
*    TRANSLATE lv_werks TO UPPER CASE.
*    IF lv_werks IS INITIAL.
*      " (SỬA: Bỏ Required, vì đây là Auto-fill Mở)
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_t001w( EXPORTING iv_werks = lv_werks CHANGING es_t001w = ls_t001w ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '058' WITH lv_werks INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PLANT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_item_plant.
*    DATA: lv_werks TYPE vbap-werks,
*          ls_t001w TYPE ty_t001w_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_item-message.
*
*
*    lv_werks = cs_item-plant.
*    SHIFT lv_werks LEFT DELETING LEADING space.
*    TRANSLATE lv_werks TO UPPER CASE.
*
*    " 1. Required (Soft)
*    IF lv_werks IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '057' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PLANT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " 2. Existence Check
*    CALL METHOD buffer_load_t001w( EXPORTING iv_werks = lv_werks CHANGING es_t001w = ls_t001w ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '058' WITH lv_werks INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PLANT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    DATA: lv_werks TYPE vbap-werks,
          ls_t001w TYPE ty_t001w_buf,
          lv_found TYPE abap_bool.

    CLEAR cs_item-message.
    lv_werks = cs_item-plant.
    TRANSLATE lv_werks TO UPPER CASE.

    " 1. Nếu rỗng -> Bỏ qua (Optional)
    IF lv_werks IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Nếu có nhập -> Check Ký tự đặc biệt
    IF check_special_chars( iv_value = lv_werks ) = abap_true.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'PLANT' iv_msg_type = 'E' iv_message = 'Invalid characters in Plant' ).
      RETURN.
    ENDIF.

    " 3. Nếu có nhập -> Check Tồn tại (T001W)
    CALL METHOD buffer_load_t001w( EXPORTING iv_werks = lv_werks CHANGING es_t001w = ls_t001w ev_found = lv_found ).
    IF lv_found IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '071' WITH lv_werks INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'PLANT' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD validate_item_pricing_proc.
    DATA: ls_tvak      TYPE ty_tvak_buf,
          ls_knvv      TYPE ty_knvv_buf,
          lv_det_kalsm TYPE t683v-kalsm,
          lv_found_tvak TYPE abap_bool,
          lv_found_knvv TYPE abap_bool.

    CLEAR: cs_item-message.


    " (SỬA: Không READ gt_so_header, dùng is_header)
    IF is_header IS INITIAL OR is_header-status = 'ERROR'.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '082' INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PRICE_PROC' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

    CALL METHOD buffer_load_tvak( EXPORTING iv_auart = is_header-order_type CHANGING es_tvak = ls_tvak ev_found = lv_found_tvak ).
    IF lv_found_tvak IS INITIAL OR ls_tvak-kalvg IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '084' WITH is_header-order_type INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PRICE_PROC' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

    CALL METHOD buffer_load_knvv(
      EXPORTING
        iv_kunnr = is_header-sold_to_party
        iv_vkorg = is_header-sales_org
        iv_vtweg = is_header-sales_channel
        iv_spart = is_header-sales_div
      CHANGING
        es_knvv  = ls_knvv
        ev_found = lv_found_knvv ).
    IF lv_found_knvv IS INITIAL OR ls_knvv-kalks IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '085' WITH is_header-sold_to_party is_header-sales_org is_header-sales_channel is_header-sales_div INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PRICE_PROC' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

    SELECT SINGLE kalsm
      INTO @lv_det_kalsm
      FROM t683v
      WHERE vkorg = @is_header-sales_org
        AND vtweg = @is_header-sales_channel
        AND spart = @is_header-sales_div
        AND kalvg = @ls_tvak-kalvg
        AND kalks = @ls_knvv-kalks.
    IF sy-subrc <> 0 OR lv_det_kalsm IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '086' WITH ls_tvak-kalvg ls_knvv-kalks is_header-sales_org is_header-sales_channel INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'PRICE_PROC' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

*    cs_item-status = 'READY'. " (SỬA)
*    cs_item-price_proc = lv_det_kalsm.
*    cs_item-message = |Pricing Procedure { lv_det_kalsm } determined.|.
  ENDMETHOD.


METHOD validate_item_quantity.
*  METHOD validate_item_quantity.
*    DATA: lv_qty TYPE decfloat16.
*    CLEAR: cs_item-status, cs_item-message. " (SỬA)
*    IF cs_item-quantity IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '063' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*    TRY.
*        lv_qty = cs_item-quantity.
*      CATCH cx_sy_conversion_no_number.
*        cs_item-status = 'ERROR'. " (SỬA)
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '064' WITH cs_item-quantity INTO cs_item-message.
*        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*        RETURN.
*    ENDTRY.
*    IF lv_qty <= 0.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '065' WITH cs_item-quantity INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_item_quantity.
*    DATA: lv_qty TYPE decfloat16.
*
*    CLEAR: cs_item-message.
*
*
*    IF cs_item-quantity IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '063' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    TRY.
*        lv_qty = cs_item-quantity.
*      CATCH cx_sy_conversion_no_number.
*        cs_item-status = 'ERROR'.
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '064' WITH cs_item-quantity INTO cs_item-message.
*        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*        RETURN.
*    ENDTRY.
*
*    IF lv_qty <= 0.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '065' WITH cs_item-quantity INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'QUANTITY' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

    CLEAR cs_item-message.
    DATA: lv_qty TYPE decfloat16.

    " 1. Required Check
    IF cs_item-quantity IS INITIAL.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'QUANTITY' iv_msg_type = 'E'
        iv_message = 'Order Quantity is required' ).
      RETURN.
    ENDIF.

    " 2. Numeric Check (Đảm bảo là số)
    TRY.
        lv_qty = cs_item-quantity.
      CATCH cx_sy_conversion_no_number.
        cs_item-status = 'ERROR'.
        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
          iv_fieldname = 'QUANTITY' iv_msg_type = 'E'
          iv_message = 'Invalid Quantity format' ).
        RETURN.
    ENDTRY.

    " 3. Positive Check
    IF lv_qty <= 0.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'QUANTITY' iv_msg_type = 'E'
        iv_message = 'Quantity must be greater than 0' ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD validate_item_sch_date.
    " (SỬA: Logic này không cần nữa, vì REQ_DATE (Item)
    "  sẽ được auto-fill từ REQ_DATE (Header)
    "  trong METHOD 'EXECUTE_VALIDATION_ITM')

    " (Bạn có thể để trống METHOD này,
    "  hoặc xóa nó khỏi IMPLEMENTATION
    "  và xóa nó khỏi DEFINITION)
    DATA: lv_sch_date TYPE dats,
          lv_req_hdr  TYPE dats.

    lv_sch_date = cs_item-req_date.

    IF lv_sch_date IS INITIAL OR lv_sch_date = '00000000'.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '074' INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'REQ_DATE' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY' EXPORTING date = lv_sch_date EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '075' WITH lv_sch_date INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'REQ_DATE' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.

    IF lv_sch_date < sy-datum.
      IF cs_item-status <> 'ERROR'. cs_item-status = 'INCOMP'. ENDIF.
      MESSAGE ID gc_msgid TYPE 'W' NUMBER '077' WITH lv_sch_date INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'REQ_DATE' iv_msg_type = 'W' iv_message = cs_item-message ).
    ENDIF.

    " So sánh với Header Req Date
    lv_req_hdr = is_header-req_date.
    IF lv_req_hdr IS NOT INITIAL AND lv_sch_date < lv_req_hdr.
      IF cs_item-status <> 'ERROR'. cs_item-status = 'INCOMP'. ENDIF.
      MESSAGE ID gc_msgid TYPE 'W' NUMBER '078' WITH lv_sch_date lv_req_hdr INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'REQ_DATE' iv_msg_type = 'W' iv_message = cs_item-message ).
    ENDIF.
  ENDMETHOD.


METHOD validate_item_ship_point.
*  METHOD validate_item_ship_point.
*    DATA: lv_vstel TYPE vbap-vstel,
*          ls_tvst  TYPE ty_tvst_buf,
*          lv_found TYPE abap_bool.
*    " (SỬA: Bỏ Clear status)
*    lv_vstel = cs_item-ship_point.
*    SHIFT lv_vstel LEFT DELETING LEADING space.
*    TRANSLATE lv_vstel TO UPPER CASE.
*    IF lv_vstel IS INITIAL.
*      " (SỬA: Bỏ Required, vì đây là Auto-fill Mở)
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_tvst( EXPORTING iv_vstel = lv_vstel CHANGING es_tvst = ls_tvst ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '060' WITH lv_vstel INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'SHIP_POINT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_item_ship_point.
*    DATA: lv_vstel TYPE vbap-vstel,
*          ls_tvst  TYPE ty_tvst_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_item-message.
*
*
*    lv_vstel = cs_item-ship_point.
*    SHIFT lv_vstel LEFT DELETING LEADING space.
*    TRANSLATE lv_vstel TO UPPER CASE.
*
*    IF lv_vstel IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '059' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'SHIP_POINT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    CALL METHOD buffer_load_tvst( EXPORTING iv_vstel = lv_vstel CHANGING es_tvst = ls_tvst ev_found = lv_found ).
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '060' WITH lv_vstel INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'SHIP_POINT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.


    DATA: lv_vstel TYPE vbap-vstel,
          ls_tvst  TYPE ty_tvst_buf,
          lv_found TYPE abap_bool.

    CLEAR cs_item-message.
    lv_vstel = cs_item-ship_point.
    TRANSLATE lv_vstel TO UPPER CASE.

    " 1. Nếu rỗng -> Bỏ qua
    IF lv_vstel IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Check Ký tự đặc biệt
    IF check_special_chars( iv_value = lv_vstel ) = abap_true.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'SHIP_POINT' iv_msg_type = 'E' iv_message = 'Invalid characters in Shipping Point' ).
      RETURN.
    ENDIF.

    " 3. Check Tồn tại (TVST)
    CALL METHOD buffer_load_tvst( EXPORTING iv_vstel = lv_vstel CHANGING es_tvst = ls_tvst ev_found = lv_found ).
    IF lv_found IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '081' WITH lv_vstel INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'SHIP_POINT' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_item_store_loc.
*  METHOD validate_item_store_loc.
*    DATA: lv_werks TYPE vbap-werks,
*          lv_lgort TYPE vbap-lgort,
*          ls_t001l TYPE ty_t001l_buf,
*          lv_found TYPE abap_bool.
*    CLEAR: cs_item-status, cs_item-message. " (SỬA)
*    lv_werks = cs_item-plant. " (Cần Plant để check S.Loc)
*    lv_lgort = cs_item-store_loc.
*    SHIFT lv_lgort LEFT DELETING LEADING space.
*    TRANSLATE lv_lgort TO UPPER CASE.
*    IF lv_lgort IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '061' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*    CALL METHOD buffer_load_t001l( EXPORTING iv_werks = lv_werks iv_lgort = lv_lgort CHANGING es_t001l = ls_t001l ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '062' WITH lv_lgort lv_werks INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

*METHOD validate_item_store_loc.
*    DATA: lv_werks TYPE vbap-werks,
*          lv_lgort TYPE vbap-lgort,
*          ls_t001l TYPE ty_t001l_buf,
*          lv_found TYPE abap_bool.
*
*    CLEAR: cs_item-message.
*
*
*    lv_werks = cs_item-plant.
*    lv_lgort = cs_item-store_loc.
*    SHIFT lv_lgort LEFT DELETING LEADING space.
*    TRANSLATE lv_lgort TO UPPER CASE.
*
*    IF lv_lgort IS INITIAL.
*      cs_item-status = 'ERROR'.
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '061' INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*
*    " Check trong T001L (cần Plant)
*    IF lv_werks IS NOT INITIAL.
*      CALL METHOD buffer_load_t001l( EXPORTING iv_werks = lv_werks iv_lgort = lv_lgort CHANGING es_t001l = ls_t001l ev_found = lv_found ).
*      IF lv_found IS INITIAL.
*        cs_item-status = 'ERROR'.
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '062' WITH lv_lgort lv_werks INTO cs_item-message.
*        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = cs_item-message ).
*        RETURN.
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.


    DATA: lv_werks TYPE vbap-werks,
          lv_lgort TYPE vbap-lgort,
          ls_t001l TYPE ty_t001l_buf,
          lv_found TYPE abap_bool.

    CLEAR cs_item-message.
    lv_werks = cs_item-plant.
    lv_lgort = cs_item-store_loc.
    TRANSLATE lv_lgort TO UPPER CASE.

    " 1. Nếu rỗng -> Bỏ qua
    IF lv_lgort IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Check Ký tự đặc biệt
    IF check_special_chars( iv_value = lv_lgort ) = abap_true.
      cs_item-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
        iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = 'Invalid characters in Storage Location' ).
      RETURN.
    ENDIF.

    " 3. Check Tồn tại (T001L) - Cần Plant để check
    IF lv_werks IS NOT INITIAL.
      CALL METHOD buffer_load_t001l( EXPORTING iv_werks = lv_werks iv_lgort = lv_lgort CHANGING es_t001l = ls_t001l ev_found = lv_found ).
      IF lv_found IS INITIAL.
        cs_item-status = 'ERROR'.
        MESSAGE ID gc_msgid TYPE 'E' NUMBER '091' WITH lv_lgort lv_werks INTO cs_item-message.
        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no
          iv_fieldname = 'STORE_LOC' iv_msg_type = 'E' iv_message = cs_item-message ).
        RETURN.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD validate_item_unit.
*    DATA: lv_unit  TYPE mara-meins,
*          lv_matnr TYPE mara-matnr,
*          ls_marm  TYPE ty_marm_buf,
*          lv_found TYPE abap_bool.
*    " (SỬA: Bỏ Clear status)
*    lv_unit = cs_item-unit.
*    lv_matnr = cs_item-MATERIAL.
*    SHIFT lv_unit LEFT DELETING LEADING space.
*    TRANSLATE lv_unit TO UPPER CASE.
*    IF lv_unit IS INITIAL.
*      RETURN. " (SỬA: Bỏ Required, vì đây là Locked/Auto-fill)
*    ENDIF.
*    CALL METHOD buffer_load_marm( EXPORTING iv_matnr = lv_matnr iv_meinh = lv_unit CHANGING es_marm = ls_marm ev_found = lv_found ). " (SỬA)
*    IF lv_found IS INITIAL.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '131' WITH lv_unit lv_matnr INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.

     DATA: lv_unit  TYPE mara-meins,
          ls_marm  TYPE ty_marm_buf,
          lv_found TYPE abap_bool.

    lv_unit = cs_item-unit.
    SHIFT lv_unit LEFT DELETING LEADING space.
    TRANSLATE lv_unit TO UPPER CASE.

    IF lv_unit IS INITIAL. RETURN. ENDIF.

    CALL METHOD buffer_load_marm( EXPORTING iv_matnr = cs_item-material iv_meinh = lv_unit CHANGING es_marm = ls_marm ev_found = lv_found ).
    IF lv_found IS INITIAL.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '073' WITH lv_unit cs_item-material INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


METHOD validate_item_unit_price.
*  METHOD validate_item_unit_price.
*    DATA: lv_price TYPE decfloat16.
*    " (SỬA: Bỏ Clear status)
*    IF cs_item-unit_price IS INITIAL.
*      " (SỬA: Bỏ Required, vì đây là Hybrid)
*      RETURN.
*    ENDIF.
*    TRY.
*        lv_price = cs_item-unit_price.
*      CATCH cx_sy_conversion_no_number.
*        cs_item-status = 'ERROR'. " (SỬA)
*        MESSAGE ID gc_msgid TYPE 'E' NUMBER '067' WITH cs_item-unit_price INTO cs_item-message.
*        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT_PRICE' iv_msg_type = 'E' iv_message = cs_item-message ).
*        RETURN.
*    ENDTRY.
*    IF lv_price <= 0.
*      cs_item-status = 'ERROR'. " (SỬA)
*      MESSAGE ID gc_msgid TYPE 'E' NUMBER '068' WITH cs_item-unit_price INTO cs_item-message.
*      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT_PRICE' iv_msg_type = 'E' iv_message = cs_item-message ).
*      RETURN.
*    ENDIF.
*  ENDMETHOD.

    DATA: lv_price TYPE decfloat16.

    CLEAR: cs_item-message.


    IF cs_item-unit_price IS INITIAL.
      RETURN. " Optional
    ENDIF.

    TRY.
        lv_price = cs_item-unit_price.
      CATCH cx_sy_conversion_no_number.
        cs_item-status = 'ERROR'.
        MESSAGE ID gc_msgid TYPE 'E' NUMBER '067' WITH cs_item-unit_price INTO cs_item-message.
        CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT_PRICE' iv_msg_type = 'E' iv_message = cs_item-message ).
        RETURN.
    ENDTRY.

    IF lv_price <= 0.
      cs_item-status = 'ERROR'.
      MESSAGE ID gc_msgid TYPE 'E' NUMBER '068' WITH cs_item-unit_price INTO cs_item-message.
      CALL METHOD add_error( iv_temp_id = cs_item-temp_id iv_item_no = cs_item-item_no iv_fieldname = 'UNIT_PRICE' iv_msg_type = 'E' iv_message = cs_item-message ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD validate_prc_amount.
    DATA: lv_amount TYPE decfloat16.

    " 1. Check format số (Quan trọng vì Excel có thể gửi text)
    TRY.
        lv_amount = cs_pricing-amount.
      CATCH cx_sy_conversion_no_number.
        cs_pricing-status = 'ERROR'.
        CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
          iv_fieldname = 'AMOUNT' iv_msg_type = 'E' iv_message = 'Invalid Amount format' ).
        RETURN.
    ENDTRY.

    " 2. Check giá trị (Tùy nghiệp vụ, có thể cho phép âm nếu là chiết khấu)
    " Nhưng thông thường nhập vào thì nên khác 0
    IF lv_amount = 0.
       " Warning: Amount is zero
       cs_pricing-status = 'INCOMP'.
       CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
         iv_fieldname = 'AMOUNT' iv_msg_type = 'W' iv_message = 'Condition Amount is zero' ).
    ENDIF.
  ENDMETHOD.


METHOD validate_prc_cond_type.
    DATA: lv_kschl TYPE konv-kschl,
          lv_found TYPE abap_bool.

    lv_kschl = cs_pricing-cond_type.
    TRANSLATE lv_kschl TO UPPER CASE.

    " 1. Required
    IF lv_kschl IS INITIAL.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
        iv_fieldname = 'COND_TYPE' iv_msg_type = 'E' iv_message = 'Condition Type is required' ).
      RETURN.
    ENDIF.

    " 2. Special Chars
    IF check_special_chars( iv_value = lv_kschl ) = abap_true.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
        iv_fieldname = 'COND_TYPE' iv_msg_type = 'E' iv_message = 'Invalid characters in Cond Type' ).
      RETURN.
    ENDIF.

    " 3. Existence Check (T685 - Conditions: Types)
    " (Bạn cần implement buffer_load_t685 hoặc select trực tiếp)
    SELECT SINGLE kschl FROM t685 INTO @DATA(lv_dummy) WHERE kschl = @lv_kschl AND kvewe = 'A'. " A = Pricing
    IF sy-subrc <> 0.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
        iv_fieldname = 'COND_TYPE' iv_msg_type = 'E' iv_message = |Condition Type { lv_kschl } does not exist| ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_prc_currency.
    DATA: lv_waers TYPE tcurc-waers,
          ls_tcurc TYPE ty_tcurc_buf,
          lv_found TYPE abap_bool.

    lv_waers = cs_pricing-currency.
    TRANSLATE lv_waers TO UPPER CASE.

    IF lv_waers IS INITIAL. RETURN. ENDIF.

    CALL METHOD buffer_load_tcurc( EXPORTING iv_waers = lv_waers CHANGING es_tcurc = ls_tcurc ev_found = lv_found ).
    IF lv_found IS INITIAL.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error( iv_temp_id = cs_pricing-temp_id iv_item_no = cs_pricing-item_no
        iv_fieldname = 'CURRENCY' iv_msg_type = 'E' iv_message = |Currency { lv_waers } does not exist| ).
    ENDIF.
  ENDMETHOD.


METHOD validate_prc_per.
    DATA: lv_per TYPE decfloat16.

    " 1. Empty Check (Nếu user để trống, BAPI thường mặc định là 1, nên có thể bỏ qua)
    IF cs_pricing-per IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Numeric Check
    TRY.
        lv_per = cs_pricing-per.
      CATCH cx_sy_conversion_no_number.
        cs_pricing-status = 'ERROR'.
        CALL METHOD add_error(
            iv_temp_id   = cs_pricing-temp_id
            iv_item_no   = cs_pricing-item_no
            iv_fieldname = 'PER'
            iv_msg_type  = 'E'
            iv_message   = 'Invalid Pricing Unit format' ).
        RETURN.
    ENDTRY.

    " 3. Positive Check
    IF lv_per <= 0.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error(
          iv_temp_id   = cs_pricing-temp_id
          iv_item_no   = cs_pricing-item_no
          iv_fieldname = 'PER'
          iv_msg_type  = 'E'
          iv_message   = 'Pricing Unit must be greater than 0' ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_prc_uom.
    " 1. Empty Check
    IF cs_pricing-uom IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Conversion & Existence Check (Chuẩn SAP)
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = cs_pricing-uom
        language       = sy-langu
      IMPORTING
        output         = cs_pricing-uom " (Update lại giá trị chuẩn vào bảng)
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.

    IF sy-subrc <> 0.
      cs_pricing-status = 'ERROR'.
      CALL METHOD add_error(
          iv_temp_id   = cs_pricing-temp_id
          iv_item_no   = cs_pricing-item_no
          iv_fieldname = 'UOM'
          iv_msg_type  = 'E'
          iv_message   = |Condition UoM { cs_pricing-uom } is not valid| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
