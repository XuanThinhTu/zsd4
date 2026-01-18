PROCESS BEFORE OUTPUT.
*----------------------------------------------------------------------*
* Set GUI Status (Buttons) and Titlebar
*----------------------------------------------------------------------*
  MODULE status_0300.

PROCESS AFTER INPUT.
*----------------------------------------------------------------------*
* Handle Exit Commands (Back, Cancel, Exit) -> Type 'E'
* Bypasses automatic field checks
*----------------------------------------------------------------------*
  MODULE exit_command_0300 AT EXIT-COMMAND.

*----------------------------------------------------------------------*
* Field Validation & User Command Processing
* Note: Using CHAIN to ensure these fields remain input-enabled
* if an Error Message is raised within USER_COMMAND_0300
*----------------------------------------------------------------------*
  CHAIN.
    FIELD gs_so_heder_ui-so_hdr_auart.
    FIELD gs_so_heder_ui-so_hdr_vkorg.
    FIELD gs_so_heder_ui-so_hdr_vtweg.
    FIELD gs_so_heder_ui-so_hdr_spart.
    FIELD gs_so_heder_ui-so_hdr_vkgrp.
    FIELD gs_so_heder_ui-so_hdr_vkbur.

    MODULE user_command_0300.
  ENDCHAIN.

PROCESS ON VALUE-REQUEST.
*----------------------------------------------------------------------*
* Custom F4 Help Implementation
*----------------------------------------------------------------------*
  FIELD gs_so_heder_ui-so_hdr_vtweg MODULE f4_vtweg.
  FIELD gs_so_heder_ui-so_hdr_spart MODULE f4_spart.
  FIELD gs_so_heder_ui-so_hdr_vkgrp MODULE f4_vkgrp.
  FIELD gs_so_heder_ui-so_hdr_vkbur MODULE f4_vkbur.
