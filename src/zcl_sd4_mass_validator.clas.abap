class ZCL_SD4_MASS_VALIDATOR definition
  public
  final
  create public .

public section.

*  TYPES:
*      BEGIN OF ty_validation_result,
*        has_error TYPE abap_bool,
*        error_tab TYPE STANDARD TABLE OF zsd4_so_err_log WITH DEFAULT KEY,
*      END OF ty_validation_result.
*
*    CLASS-METHODS:
*      validate_header
*        IMPORTING
*          is_header  TYPE ztb_so_upload_hd
*        RETURNING
*          VALUE(rs_result) TYPE ty_validation_result,
*
*      validate_item
*        IMPORTING
*          is_item TYPE ztb_so_upload_it
*        RETURNING
*          VALUE(rs_result) TYPE ty_validation_result.
*
*  class-data GT_ERRORS type ZTTY_VALIDATION_ERROR .
*
*  class-methods CLEAR_ERRORS .


   "------------------------------------------------------------
    " Result structure returned to caller
    "------------------------------------------------------------
    TYPES:
      BEGIN OF ty_error,
        fieldname TYPE char30,
        message   TYPE bapi_msg,
        temp_id   TYPE char10,
        item_no   TYPE posnr_va,
      END OF ty_error.

    TYPES:
      ty_error_tab TYPE STANDARD TABLE OF ty_error WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_validation_result,
        has_error TYPE abap_bool,
        error_tab TYPE ty_error_tab,
      END OF ty_validation_result.

    "------------------------------------------------------------
    " PUBLIC METHODS (API for Module Pool)
    "------------------------------------------------------------
    CLASS-METHODS:
      validate_header
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        RETURNING
          VALUE(rs_result) TYPE ty_validation_result,

      validate_item
        IMPORTING
          is_item TYPE ztb_so_upload_it
        RETURNING
          VALUE(rs_result) TYPE ty_validation_result.
protected section.
private section.
*  CLASS-METHODS:
*      check_required
*        IMPORTING
*          iv_value TYPE any
*          iv_field TYPE char30
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_numeric
*        IMPORTING
*          iv_value TYPE any
*          iv_field TYPE char30
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_date
*        IMPORTING
*          iv_date  TYPE any
*          iv_field TYPE char30
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_sales_area
*        IMPORTING
*          iv_vkorg TYPE vkorg
*          iv_vtweg TYPE vtweg
*          iv_spart TYPE spart
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_customer
*        IMPORTING
*          iv_kunnr TYPE kunnr
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_material
*        IMPORTING
*          iv_matnr TYPE matnr
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_plant
*        IMPORTING
*          iv_werks TYPE werks_d
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_price
*        IMPORTING
*          iv_price TYPE kbetr
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      check_quantity
*        IMPORTING
*          iv_qty TYPE kwmeng
*        RETURNING
*          VALUE(rv_msg) TYPE bapi_msg,
*
*      append_error
*        IMPORTING
*          iv_msg      TYPE bapi_msg
*          iv_field    TYPE char30
*          iv_temp_id  TYPE char10
*          iv_item_no  TYPE numc6
*        CHANGING
*          ct_errlog   TYPE ZTTY_VALIDATION_ERROR.

     "------------------------------------------------------------
    " HELPER METHODS – HEADER
    "------------------------------------------------------------
    CLASS-METHODS:
      check_required_hdr
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_sales_area
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_customer
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_header_dates
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_payment_terms
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_incoterms
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,

      check_currency
        IMPORTING
          is_header TYPE ztb_so_upload_hd
        CHANGING
          ct_err TYPE ty_error_tab,


    "------------------------------------------------------------
    " HELPER METHODS – ITEM
    "------------------------------------------------------------
      check_required_itm
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_material
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_plant
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_storage_location
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_shipping_point
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_quantity
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_unit
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_price
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab,

      check_schedule_date
        IMPORTING
          is_item TYPE ztb_so_upload_it
        CHANGING
          ct_err TYPE ty_error_tab.

      "------------------------------------------------------------
    " INTERNAL UTILITY
    "------------------------------------------------------------
    CLASS-METHODS:
      append_error
        IMPORTING
          iv_fieldname TYPE char30
          iv_message   TYPE bapi_msg
          iv_temp_id   TYPE char10
          iv_item_no   TYPE posnr_va
        CHANGING
          ct_err TYPE ty_error_tab.
ENDCLASS.



CLASS ZCL_SD4_MASS_VALIDATOR IMPLEMENTATION.


  method APPEND_ERROR.
  "------------------------------------------------------------
  " PRIVATE: Append error to internal table
  "------------------------------------------------------------
    DATA ls_err TYPE ty_error.

    ls_err-fieldname = iv_fieldname.
    ls_err-message   = iv_message.
    ls_err-temp_id   = iv_temp_id.
    ls_err-item_no   = iv_item_no.

    APPEND ls_err TO ct_err.
  endmethod.


  method CHECK_CURRENCY.
    "------------------------------------------------------------
  " HEADER: Currency validation
  "------------------------------------------------------------
    DATA: lv_msg TYPE bapi_msg.

    IF is_header-currency IS NOT INITIAL.

      SELECT SINGLE waers
        FROM tcurc
        INTO @DATA(lv_waers)
        WHERE waers = @is_header-currency.

      IF sy-subrc <> 0.
        MESSAGE e050(zsd4_msg) WITH is_header-currency INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'CURRENCY'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.

    ENDIF.
  endmethod.


  method CHECK_CUSTOMER.
   "------------------------------------------------------------
  " HEADER: Customer validation
  "------------------------------------------------------------
     DATA: lv_msg TYPE bapi_msg.

    IF is_header-sold_to_party IS NOT INITIAL.

      " Kiểm tra tồn tại trong KNA1
      SELECT SINGLE kunnr
        FROM kna1
        INTO @DATA(lv_kunnr)
        WHERE kunnr = @is_header-sold_to_party.

      IF sy-subrc <> 0.
        MESSAGE e020(zsd4_msg) WITH is_header-sold_to_party INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'SOLD_TO_PARTY'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.

    ENDIF.
  endmethod.


  method CHECK_HEADER_DATES.
   "------------------------------------------------------------
  " HEADER: Date validation (Order Date, Req. Date, Price Date)
  "------------------------------------------------------------
    DATA: lv_msg  TYPE bapi_msg.
    DATA: lv_date TYPE datum.

    " Order Date format
    IF is_header-order_date IS NOT INITIAL.
      lv_date = is_header-order_date.
      IF lv_date = '00000000'.
        MESSAGE e075(zsd4_msg) WITH 'Order Date' INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'ORDER_DATE'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.

    " Req. Date
    IF is_header-req_date IS NOT INITIAL.
      lv_date = is_header-req_date.
      IF lv_date = '00000000'.
        MESSAGE e075(zsd4_msg) WITH 'Requested Date' INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'REQ_DATE'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.

    " Price Date
    IF is_header-price_date IS NOT INITIAL.
      lv_date = is_header-price_date.
      IF lv_date = '00000000'.
        MESSAGE e075(zsd4_msg) WITH 'Price Date' INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'PRICE_DATE'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.
  endmethod.


  method CHECK_INCOTERMS.
    "------------------------------------------------------------
  " HEADER: Incoterms validation
  "------------------------------------------------------------
    DATA: lv_msg TYPE bapi_msg.

    IF is_header-incoterms IS NOT INITIAL.

      " Ví dụ: kiểm tra INCO1 trong TINCT
      SELECT SINGLE inco1
        FROM tinct
        INTO @DATA(lv_inco1)
        WHERE inco1 = @is_header-incoterms.

      IF sy-subrc <> 0.
        MESSAGE e040(zsd4_msg) WITH is_header-incoterms INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'INCOTERMS'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.

    ENDIF.

  endmethod.


  method CHECK_MATERIAL.
  endmethod.


  method CHECK_PAYMENT_TERMS.
    "------------------------------------------------------------
  " HEADER: Payment Terms validation
  "------------------------------------------------------------
    DATA: lv_msg TYPE bapi_msg.

    IF is_header-pmnttrms IS NOT INITIAL.

      SELECT SINGLE zterm
        FROM t052
        INTO @DATA(lv_zterm)
        WHERE zterm = @is_header-pmnttrms.

      IF sy-subrc <> 0.
        MESSAGE e030(zsd4_msg) WITH is_header-pmnttrms INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'PMNTTRMS'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.

    ENDIF.
  endmethod.


  method CHECK_PLANT.
  endmethod.


  method CHECK_PRICE.
  endmethod.


  method CHECK_QUANTITY.
  endmethod.


  method CHECK_REQUIRED_HDR.
    DATA: lv_msg TYPE bapi_msg.

    " Sales Organization
    IF is_header-sales_org IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Sales Organization' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'SALES_ORG'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Distribution Channel
    IF is_header-sales_channel IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Distribution Channel' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'SALES_CHANNEL'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Division
    IF is_header-sales_div IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Division' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'SALES_DIV'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Order Type
    IF is_header-order_type IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Order Type' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'ORDER_TYPE'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Sold-to Party
    IF is_header-sold_to_party IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Sold-to Party' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'SOLD_TO_PARTY'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Order Date
    IF is_header-order_date IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Order Date' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'ORDER_DATE'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.

    " Currency
    IF is_header-currency IS INITIAL.
      MESSAGE e079(zsd4_msg) WITH 'Currency' INTO lv_msg.
      append_error(
        EXPORTING
          iv_fieldname = 'CURRENCY'
          iv_message   = lv_msg
          iv_temp_id   = is_header-temp_id
          iv_item_no   = '000000'
        CHANGING
          ct_err       = ct_err ).
    ENDIF.
  endmethod.


  method CHECK_REQUIRED_ITM.
  endmethod.


  method CHECK_SALES_AREA.
   "------------------------------------------------------------
  " HEADER: Sales Area validation (VKORG/VTWEG/SPART)
  "------------------------------------------------------------
    DATA: lv_msg TYPE bapi_msg.

    " Check Sales Org tồn tại
    IF is_header-sales_org IS NOT INITIAL.
      SELECT SINGLE vkorg
        FROM tvko
        INTO @DATA(lv_vkorg)
        WHERE vkorg = @is_header-sales_org.

      IF sy-subrc <> 0.
        MESSAGE e080(zsd4_msg) WITH is_header-sales_org INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'SALES_ORG'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.

    " Check Distribution Channel tồn tại
    IF is_header-sales_channel IS NOT INITIAL.
      SELECT SINGLE vtweg
        FROM tvtw
        INTO @DATA(lv_vtweg)
        WHERE vtweg = @is_header-sales_channel.

      IF sy-subrc <> 0.
        MESSAGE e081(zsd4_msg) WITH is_header-sales_channel INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'SALES_CHANNEL'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.

    " Check Division tồn tại
    IF is_header-sales_div IS NOT INITIAL.
      SELECT SINGLE spart
        FROM tspat
        INTO @DATA(lv_spart)
        WHERE spart = @is_header-sales_div.

      IF sy-subrc <> 0.
        MESSAGE e082(zsd4_msg) WITH is_header-sales_div INTO lv_msg.
        append_error(
          EXPORTING
            iv_fieldname = 'SALES_DIV'
            iv_message   = lv_msg
            iv_temp_id   = is_header-temp_id
            iv_item_no   = '000000'
          CHANGING
            ct_err       = ct_err ).
      ENDIF.
    ENDIF.

  endmethod.


  method CHECK_SCHEDULE_DATE.
  endmethod.


  method CHECK_SHIPPING_POINT.
  endmethod.


  method CHECK_STORAGE_LOCATION.
  endmethod.


  method CHECK_UNIT.
  endmethod.


  method VALIDATE_HEADER.
     DATA lt_err TYPE ty_error_tab.

    " Gọi từng nhóm rule theo Module B
    check_required_hdr( EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_sales_area(   EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_customer(     EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_header_dates( EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_payment_terms( EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_incoterms(     EXPORTING is_header = is_header CHANGING ct_err = lt_err ).
    check_currency(      EXPORTING is_header = is_header CHANGING ct_err = lt_err ).

    rs_result-error_tab = lt_err.
    rs_result-has_error = xsdbool( lines( lt_err ) > 0 ).
  endmethod.


  method VALIDATE_ITEM.
    DATA lt_err TYPE ty_error_tab.

    check_required_itm( EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_material(     EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_plant(        EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_storage_location( EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_shipping_point(   EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_quantity(         EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_unit(             EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_price(            EXPORTING is_item = is_item CHANGING ct_err = lt_err ).
    check_schedule_date(    EXPORTING is_item = is_item CHANGING ct_err = lt_err ).

    rs_result-error_tab = lt_err.
    rs_result-has_error = xsdbool( lines( lt_err ) > 0 ).
  endmethod.
ENDCLASS.
