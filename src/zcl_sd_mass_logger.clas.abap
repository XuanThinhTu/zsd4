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
  class-methods SAVE_SINGLE_ERROR
    importing
      !IV_REQ_ID type ZSD_REQ_ID
      !IV_TEMP_ID type CHAR10
      !IV_ITEM_NO type POSNR_VA
      !IV_FIELDNAME type FIELDNAME
      !IV_MSG_TYPE type SYMSGTY default 'E'
      !IV_MESSAGE type STRING
      !IV_COMMIT type ABAP_BOOL default ABAP_FALSE .
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


*METHOD save_errors_to_db.
*    " 1. Xóa log cũ (của lần Validate trước)
*    READ TABLE it_errors INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_err_first>).
*    IF sy-subrc <> 0. RETURN. ENDIF. " Không có lỗi, không làm gì
*
*    DELETE FROM ztb_so_error_log WHERE req_id = <fs_err_first>-req_id.
*
*    " 2. Chuẩn bị bảng Log (Xử lý trùng lắp)
*    DATA: lt_log_db TYPE TABLE OF ztb_so_error_log.
*    FIELD-SYMBOLS: <fs_log_exist> TYPE ztb_so_error_log.
*
*    LOOP AT it_errors ASSIGNING FIELD-SYMBOL(<fs_err>).
*
*      " [FIX QUAN TRỌNG]: Kiểm tra xem lỗi này (Key: TempID + Item + Field) đã tồn tại trong bảng chuẩn bị chưa?
*      READ TABLE lt_log_db ASSIGNING <fs_log_exist>
*        WITH KEY req_id    = <fs_err>-req_id
*                 temp_id   = <fs_err>-temp_id
*                 item_no   = <fs_err>-item_no
*                 fieldname = <fs_err>-fieldname.
*
*      IF sy-subrc = 0.
*        " CASE A: Đã tồn tại -> Nối thêm thông báo lỗi vào dòng cũ
*        " (Ví dụ: 'Lỗi A' -> 'Lỗi A / Lỗi B')
*        <fs_log_exist>-message = |{ <fs_log_exist>-message } / { <fs_err>-message }|.
*
*        " Cắt bớt nếu quá dài (Message thường 220 ký tự)
*        IF strlen( <fs_log_exist>-message ) > 220.
*           <fs_log_exist>-message = <fs_log_exist>-message(220).
*        ENDIF.
*
*      ELSE.
*        " CASE B: Chưa tồn tại -> Thêm dòng mới
*        APPEND VALUE #(
*          req_id    = <fs_err>-req_id
*          temp_id   = <fs_err>-temp_id
*          item_no   = <fs_err>-item_no
*          fieldname = <fs_err>-fieldname
*          msg_type  = <fs_err>-msg_type
*          message   = <fs_err>-message
*          log_user  = sy-uname
*          log_date  = sy-datum
*          status    = 'UNFIXED'
*        ) TO lt_log_db.
*      ENDIF.
*
*    ENDLOOP.
*
*    " 3. INSERT vào DB (Bây giờ lt_log_db đảm bảo không trùng Key)
*    IF lt_log_db IS NOT INITIAL.
*      INSERT ztb_so_error_log FROM TABLE lt_log_db.
*    ENDIF.
*
*    " (Commit được gọi ở ngoài)
*  ENDMETHOD.

    " [QUAN TRỌNG]: ĐÃ XÓA DÒNG 'DELETE FROM ...' Ở ĐÂY
    " Vì nếu để ở đây nó sẽ xóa mất lỗi của các dòng trước đó trong vòng lặp.

    DATA: lt_log_db TYPE TABLE OF ztb_so_error_log.
    FIELD-SYMBOLS: <fs_log_exist> TYPE ztb_so_error_log.

    " Chuẩn bị bảng nội bộ để xử lý trùng lặp
    LOOP AT it_errors ASSIGNING FIELD-SYMBOL(<fs_err>).

      " Check xem trong đợt này đã có lỗi cùng Key chưa (Gộp lỗi)
      READ TABLE lt_log_db ASSIGNING <fs_log_exist>
        WITH KEY req_id    = <fs_err>-req_id
                 temp_id   = <fs_err>-temp_id
                 item_no   = <fs_err>-item_no
                 fieldname = <fs_err>-fieldname.

      IF sy-subrc = 0.
        " Nối chuỗi lỗi
        <fs_log_exist>-message = |{ <fs_log_exist>-message } / { <fs_err>-message }|.
        IF strlen( <fs_log_exist>-message ) > 220.
           <fs_log_exist>-message = <fs_log_exist>-message(220).
        ENDIF.
      ELSE.
        " Thêm mới
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

    " [SỬA]: Dùng MODIFY thay vì INSERT để an toàn (Insert hoặc Update nếu trùng)
    IF lt_log_db IS NOT INITIAL.
      MODIFY ztb_so_error_log FROM TABLE lt_log_db.
    ENDIF.

    " (Commit được gọi ở ngoài)
  ENDMETHOD.


  METHOD save_single_error.
    DATA: ls_log TYPE ztb_so_error_log.

    " 1. Kiểm tra xem lỗi này đã tồn tại chưa (để tránh duplicate key dump)
    SELECT SINGLE * FROM ztb_so_error_log
      INTO ls_log
      WHERE req_id    = iv_req_id
        AND temp_id   = iv_temp_id
        AND item_no   = iv_item_no
        AND fieldname = iv_fieldname.

    IF sy-subrc = 0.
      " CASE A: Đã tồn tại -> Nối thêm thông báo vào dòng cũ
      " Ví dụ: 'Lỗi A' -> 'Lỗi A / Lỗi B'
      ls_log-message = |{ ls_log-message } / { iv_message }|.

      " Cắt bớt nếu quá dài (vì trường message trong DB có giới hạn, ví dụ 220 char)
      IF strlen( ls_log-message ) > 220.
         ls_log-message = ls_log-message(220).
      ENDIF.

      " Cập nhật lại User/Date mới nhất
      ls_log-log_user = sy-uname.
      ls_log-log_date = sy-datum.
      ls_log-msg_type = iv_msg_type. " Cập nhật loại lỗi (ví dụ E đè W)

      MODIFY ztb_so_error_log FROM ls_log.

    ELSE.
      " CASE B: Chưa tồn tại -> Insert mới
      CLEAR ls_log.
      ls_log-req_id    = iv_req_id.
      ls_log-temp_id   = iv_temp_id.
      ls_log-item_no   = iv_item_no.
      ls_log-fieldname = iv_fieldname.
      ls_log-msg_type  = iv_msg_type.
      ls_log-message   = iv_message.

      " Thông tin quản trị
      ls_log-log_user  = sy-uname.
      ls_log-log_date  = sy-datum.
      ls_log-status    = 'UNFIXED'.

      INSERT ztb_so_error_log FROM ls_log.
    ENDIF.

    " 3. Commit nếu được yêu cầu (thường dùng khi gọi lẻ tẻ)
    IF iv_commit = abap_true.
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
