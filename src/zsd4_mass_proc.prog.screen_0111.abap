PROCESS BEFORE OUTPUT.
*&SPWIZARD: PBO FLOW LOGIC FOR TABSTRIP 'TS_MAIN'

  " Module này sẽ kiểm tra xem user có thay đổi data không

  MODULE ts_main_active_tab_set.
  CALL SUBSCREEN ts_main_sca
    INCLUDING g_ts_main-prog g_ts_main-subscreen.
  MODULE status_0111.
*
PROCESS AFTER INPUT.

*&SPWIZARD: PAI FLOW LOGIC FOR TABSTRIP 'TS_MAIN'
  CALL SUBSCREEN ts_main_sca.
  MODULE ts_main_active_tab_get.

  MODULE reset_flag_on_change.
  MODULE pai_handle_data_transfer. " <<< THÊM MODULE NÀY

  MODULE user_command_0111.
*
