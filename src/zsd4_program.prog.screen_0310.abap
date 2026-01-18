PROCESS BEFORE OUTPUT.
*&SPWIZARD: PBO FLOW LOGIC FOR TABSTRIP 'TS_MAIN'
*----------------------------------------------------------------------*
* SYSTEM LOGIC (Do not modify)
*----------------------------------------------------------------------*
  " 1. Set the active tab based on user selection or default
  MODULE ts_main_active_tab_set.

  " 2. Call the subscreen associated with the active tab
  CALL SUBSCREEN ts_main_sca
    INCLUDING g_ts_main-prog g_ts_main-subscreen.

*----------------------------------------------------------------------*
* BUSINESS LOGIC (Custom)
*----------------------------------------------------------------------*
  " 3. Set GUI Status, Titlebar, and Screen Initialization
  MODULE status_0310.


PROCESS AFTER INPUT.
*&SPWIZARD: PAI FLOW LOGIC FOR TABSTRIP 'TS_MAIN'
*----------------------------------------------------------------------*
* SYSTEM LOGIC (Do not modify)
*----------------------------------------------------------------------*
  " 1. Trigger PAI of the Subscreen (Validate fields inside the tab)
  CALL SUBSCREEN ts_main_sca.

  " 2. Determine which tab was clicked by the user
  MODULE ts_main_active_tab_get.

*----------------------------------------------------------------------*
* BUSINESS LOGIC (Custom)
*----------------------------------------------------------------------*
  " 3. Change Tracking: Detect if user modified any data
  MODULE reset_flag_on_change.

  " 4. Data Transfer: Move data from Screen Fields -> Global Structure
  " Critical for Tabstrips: Ensures data is not lost when switching tabs
  MODULE pai_handle_data_transfer.

  " 5. Handle Standard Commands (Save, Back, Exit)
  MODULE user_command_0310.
