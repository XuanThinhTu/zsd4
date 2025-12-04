PROCESS BEFORE OUTPUT.
  MODULE status_0802.
  " Gọi Subscreen tìm kiếm (0801)
  CALL SUBSCREEN sub_filter INCLUDING sy-repid '0801'.
*
PROCESS AFTER INPUT.
  " [QUAN TRỌNG] Gọi Subscreen TRƯỚC user command
  CALL SUBSCREEN sub_filter.
  MODULE user_command_0802.
