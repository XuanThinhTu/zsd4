class ZCL_SD4_MASS_LOGGER definition
  public
  final
  create public .

   PUBLIC SECTION.

   " Delete old errors (by REQ_ID)
    CLASS-METHODS clear_errors
      IMPORTING
        iv_req_id TYPE zsd_req_id.

    " Add error into DB table ZSD4_SO_ERR_LOG
    CLASS-METHODS add_error
      IMPORTING
        iv_req_id   TYPE zsd_req_id
        is_err      TYPE zcl_sd4_mass_validator=>ty_error.
protected section.
private section.
" Auto-generate line number for error log
    CLASS-METHODS get_next_line_no
      IMPORTING
        iv_req_id TYPE zsd_req_id
      RETURNING
        VALUE(rv_line_no) TYPE int4.
ENDCLASS.



CLASS ZCL_SD4_MASS_LOGGER IMPLEMENTATION.


  method ADD_ERROR.
  "------------------------------------------------------------
  " Insert lỗi vào bảng error log
  "------------------------------------------------------------


    DATA: ls_db TYPE zsd4_so_err_log.

    ls_db-req_id   = iv_req_id.
    ls_db-temp_id  = is_err-temp_id.
    ls_db-item_no  = is_err-item_no.
    ls_db-fieldname = is_err-fieldname.
    ls_db-message   = is_err-message.
    ls_db-msg_type  = 'E'.
    ls_db-line_no   = get_next_line_no( iv_req_id ).

    ls_db-created_by = sy-uname.
    ls_db-created_at = sy-datum.

    INSERT zsd4_so_err_log FROM ls_db.

  endmethod.


  method CLEAR_ERRORS.
    "------------------------------------------------------------
    " Xóa toàn bộ lỗi theo REQ_ID
    "------------------------------------------------------------

    DELETE FROM zsd4_so_err_log
      WHERE req_id = iv_req_id.


  endmethod.


  method GET_NEXT_LINE_NO.
  "------------------------------------------------------------
  " Sinh line number cho từng lỗi
  "------------------------------------------------------------


    SELECT MAX( line_no )
      FROM zsd4_so_err_log
      WHERE req_id = @iv_req_id
      INTO @DATA(lv_max).

    IF sy-subrc <> 0 OR lv_max IS INITIAL.
      rv_line_no = 1.
    ELSE.
      rv_line_no = lv_max + 1.
    ENDIF.

  endmethod.
ENDCLASS.
