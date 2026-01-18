PROCESS BEFORE OUTPUT.
*----------------------------------------------------------------------
* PBO: PREPARE SCREEN LAYOUT
*----------------------------------------------------------------------
  " 1. Set GUI Status (Buttons) & Titlebar
  MODULE status_0420.

  " 2. Embed Selection Subscreen
  " Loads Subscreen 0410 (Select-Options) into Area 'SUB_FILTER'
  CALL SUBSCREEN sub_filter INCLUDING sy-repid '0410'.


PROCESS AFTER INPUT.
*----------------------------------------------------------------------
* PAI: HANDLE USER INPUT
*----------------------------------------------------------------------
  " 1. Transfer Subscreen Data to ABAP Memory
  CALL SUBSCREEN sub_filter.

  " 2. Handle User Actions (Execute / Cancel)
  MODULE user_command_0420.
