
PROCESS BEFORE OUTPUT.
  MODULE status_0500.
  MODULE display_tracking_alv.
  MODULE modify_screen_fields.



PROCESS AFTER INPUT.
* MODULE move_screen_fields.
  MODULE user_command_0500.


PROCESS ON VALUE-REQUEST.
  "--- Search help cho các trường ---
  FIELD gv_vbeln  MODULE f4_for_vbeln.
  FIELD gv_kunnr  MODULE f4_for_kunnr.
  FIELD gv_ernam  MODULE f4_for_ernam.
*  FIELD gv_vkorg  MODULE f4_for_vkorg.
*  FIELD gv_vtweg  MODULE f4_for_vtweg.
*  FIELD gv_spart  MODULE f4_for_spart.
  FIELD gv_doc_date MODULE f4_for_doc_date.
*--- KẾT THÚC CODE MỚI ---*
