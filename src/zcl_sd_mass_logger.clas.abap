class ZCL_SD_MASS_LOGGER definition
  public
  final
  create public .

public section.

  class-methods SAVE_ERRORS_TO_DB
    importing
      !IT_ERRORS type ZTTY_VALIDATION_ERROR .
  class-methods LOG_EXECUTION_STEP
    importing
      !IV_REQ_ID type ZSD_REQ_ID
      !IV_TEMP_ID type CHAR10
      !IV_STATUS type CHAR15
      !IV_MESSAGE type BAPI_MSG
      !IV_VBELN_SO type VBELN_VA
      !IV_VBELN_DLV type VBELN_VL .
protected section.
private section.
ENDCLASS.



CLASS ZCL_SD_MASS_LOGGER IMPLEMENTATION.


  method LOG_EXECUTION_STEP.
    UPDATE ztb_so_upload_hd SET
    status    = @iv_status,
    message   = @iv_message,
    vbeln_so  = @iv_vbeln_so,
    vbeln_dlv = @iv_vbeln_dlv
    WHERE req_id = @iv_req_id
      AND temp_id = @iv_temp_id.
  COMMIT WORK. " (Cân nhắc Commit ở đây hoặc ở FORM cha)
  endmethod.


METHOD save_errors_to_db.
*  method SAVE_ERRORS_TO_DB.
*    " 1. Xóa log cũ (của lần Validate trước)
*  READ TABLE it_errors INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_err>).
*  IF sy-subrc <> 0. RETURN. ENDIF. " Không có lỗi, không làm gì
*
*  DELETE FROM ztb_so_error_log WHERE req_id = <fs_err>-req_id.
*
*  " 2. INSERT log mới
*  DATA lt_log_db TYPE TABLE OF ztb_so_error_log.
*  LOOP AT it_errors ASSIGNING <fs_err>.
*    APPEND VALUE #(
*      req_id    = <fs_err>-req_id
*      temp_id   = <fs_err>-temp_id
*      item_no   = <fs_err>-item_no
*      fieldname = <fs_err>-fieldname
*      msg_type  = <fs_err>-msg_type
*      message   = <fs_err>-message
*      log_user  = sy-uname
*      log_date  = sy-datum
*      status    = 'UNFIXED'
*    ) TO lt_log_db.
*  ENDLOOP.
*
*  INSERT ztb_so_error_log FROM TABLE lt_log_db.
*  COMMIT WORK.
*  endmethod.


    " 1. Xóa log cũ (của lần Validate trước)
    READ TABLE it_errors INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_err_first>).
    IF sy-subrc <> 0. RETURN. ENDIF. " Không có lỗi, không làm gì

    DELETE FROM ztb_so_error_log WHERE req_id = <fs_err_first>-req_id.

    " 2. Chuẩn bị bảng Log (Xử lý trùng lắp)
    DATA: lt_log_db TYPE TABLE OF ztb_so_error_log.
    FIELD-SYMBOLS: <fs_log_exist> TYPE ztb_so_error_log.

    LOOP AT it_errors ASSIGNING FIELD-SYMBOL(<fs_err>).

      " [FIX QUAN TRỌNG]: Kiểm tra xem lỗi này (Key: TempID + Item + Field) đã tồn tại trong bảng chuẩn bị chưa?
      READ TABLE lt_log_db ASSIGNING <fs_log_exist>
        WITH KEY req_id    = <fs_err>-req_id
                 temp_id   = <fs_err>-temp_id
                 item_no   = <fs_err>-item_no
                 fieldname = <fs_err>-fieldname.

      IF sy-subrc = 0.
        " CASE A: Đã tồn tại -> Nối thêm thông báo lỗi vào dòng cũ
        " (Ví dụ: 'Lỗi A' -> 'Lỗi A / Lỗi B')
        <fs_log_exist>-message = |{ <fs_log_exist>-message } / { <fs_err>-message }|.

        " Cắt bớt nếu quá dài (Message thường 220 ký tự)
        IF strlen( <fs_log_exist>-message ) > 220.
           <fs_log_exist>-message = <fs_log_exist>-message(220).
        ENDIF.

      ELSE.
        " CASE B: Chưa tồn tại -> Thêm dòng mới
        APPEND VALUE #(
          req_id    = <fs_err>-req_id
          temp_id   = <fs_err>-temp_id
          item_no   = <fs_err>-item_no
          fieldname = <fs_err>-fieldname
          msg_type  = <fs_err>-msg_type
          message   = <fs_err>-message
          log_user  = sy-uname
          log_date  = sy-datum
          status    = 'UNFIXED'
        ) TO lt_log_db.
      ENDIF.

    ENDLOOP.

    " 3. INSERT vào DB (Bây giờ lt_log_db đảm bảo không trùng Key)
    IF lt_log_db IS NOT INITIAL.
      INSERT ztb_so_error_log FROM TABLE lt_log_db.
    ENDIF.

    " (Commit được gọi ở ngoài)
  ENDMETHOD.
ENDCLASS.
