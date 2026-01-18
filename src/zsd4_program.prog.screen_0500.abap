
PROCESS BEFORE OUTPUT.
  MODULE status_0500.
  MODULE display_tracking_alv.
  MODULE modify_screen_fields.



PROCESS AFTER INPUT.
  " 1. Validate riêng lẻ từng trường (Nếu sai, chỉ mở lại trường đó)
  FIELD gv_doc_date MODULE validate_date ON REQUEST.

  " 2. Validate theo nhóm (Ví dụ check mã SO có tồn tại không)
  " Dùng CHAIN để nếu lỗi thì vẫn cho phép sửa lại
  CHAIN.
    FIELD gv_vbeln.
    FIELD gv_kunnr.
    FIELD gv_deliv.
    FIELD gv_bill.
    MODULE validate_existence ON CHAIN-REQUEST.
  ENDCHAIN.

  " 3. Sau khi validate xong xuôi mới đến xử lý lệnh (Search/Button)
  MODULE user_command_0500.


PROCESS ON VALUE-REQUEST.
  "--- Search help cho các trường ---
  FIELD gv_vbeln  MODULE f4_for_vbeln.
  FIELD gv_kunnr  MODULE f4_for_kunnr.
  FIELD gv_ernam  MODULE f4_for_ernam.
  FIELD gv_deliv MODULE f4_for_deliv.
  FIELD gv_bill  MODULE f4_for_bill.
  FIELD gv_doc_date MODULE f4_for_doc_date.
*--- KẾT THÚC CODE MỚI ---*
