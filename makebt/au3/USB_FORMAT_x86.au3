#RequireAdmin
#cs ----------------------------------------------------------------------------

AutoIt Version: 3.3.14.5
 Author:        WIMB  -  April 07, 2020

 Program:       USB_FORMAT_x86.exe - Version 3.2 in rule 100

 Script Function
	can be used to Format USB Drive for Booting with Windows Boot Manager Menu in BIOS or UEFI mode and
	can be used to make USB Drive having two partitions FAT32 + NTFS - Supported for Removable Drives only in Windows 10
	FAT32 for Boot files and Linux ISO files in folder images + NTFS for VHD and PE WIM and Windows Setup ISO files
	UEFI_MULTI can be used to Make Multi-Boot USB Drives by using Boot Image Files - VHD or PE WIM

 Credits and Thanks to:
	Uwe Sieber for making ListUsbDrives - http://www.uwe-sieber.de/english.html

	The program is released "as is" and is free for redistribution, use or changes as long as original author,
	credits part and link to the reboot.pro and MSFN support forum are clearly mentioned

	Author does not take any responsibility for use or misuse of the program.

#ce ----------------------------------------------------------------------------

#include <guiconstants.au3>
#include <ProgressConstants.au3>
#include <GuiConstantsEx.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#Include <GuiStatusBar.au3>
#include <Array.au3>
#Include <String.au3>
#include <Process.au3>
#include <Date.au3>

Opt('MustDeclareVars', 1)
Opt("GuiOnEventMode", 1)
Opt("TrayIconHide", 1)

; Setting variables
Global $TargetDrive="", $ProgressAll, $hStatus, $TargetSize, $TargetFree, $FSvar="", $WinLang = "en-US", $PE_flag = 0
Global $hGuiParent, $EXIT, $TargetSel, $Target, $BootLoader, $Bootmgr_Menu, $Allow_Fixed_USB, $Reversed_PartLayout
Global $DriveType="Fixed", $usbfix=0, $bcdedit="", $refind, $Combo_EFI, $WinDir_PE="D:\Windows", $BusType = ""

Global $Target_Device, $Target_Type, $FormUSB, $Combo_2nd, $f32_size="10240", $ntfs_size="", $NTFS_Drive = ""
Global $inst_disk="", $inst_part="", $disk_size="", $vol_size="", $disk_GB = 15, $dp_finish = 0

Global $str = "", $bt_files[9] = ["\makebt\listusbdrives\ListUsbDrives.exe", "\makebt\grldr.mbr", "\makebt\grldr", "\makebt\menu.lst", _
"\makebt\menu_Linux.lst", "\UEFI_MAN\efi", "\UEFI_MAN\efi_mint", "\makebt\Linux_ISO_Files.txt", "\makebt\grub.exe"]

If @OSArch <> "X86" Then
   MsgBox(48, "ERROR - Environment", "In x64 environment use USB_FORMAT_x64.exe ")
   Exit
EndIf

If @OSVersion = "WIN_VISTA" Or @OSVersion = "WIN_2003" Or @OSVersion = "WIN_XP" Or @OSVersion = "WIN_XPe" Or @OSVersion = "WIN_2000" Then
   MsgBox(48, "ERROR - Old Operating System ", "No support in XP or VISTA ")
   Exit
EndIf

For $str In $bt_files
	If Not FileExists(@ScriptDir & $str) Then
		MsgBox(48, "ERROR - Missing File", "File " & $str & " NOT Found ")
		Exit
	EndIf
Next

; Remove bs_temp in _USB_Format used After Selection of Format Drive button
; If FileExists(@ScriptDir & "\makebt\bs_temp") Then DirRemove(@ScriptDir & "\makebt\bs_temp",1)
If Not FileExists(@ScriptDir & "\makebt\bs_temp") Then DirCreate(@ScriptDir & "\makebt\bs_temp")

; If FileExists(@ScriptDir & "\makebt\dp_temp") Then DirRemove(@ScriptDir & "\makebt\dp_temp",1)
If Not FileExists(@ScriptDir & "\makebt\dp_temp") Then DirCreate(@ScriptDir & "\makebt\dp_temp")

If StringLeft(@SystemDir, 1) = "X" Then
	$PE_flag = 1
Else
	$PE_flag = 0
EndIf

If $PE_flag = 1 Then
	If FileExists("C:\Windows\Boot") Then
		$WinDir_PE = "C:\Windows"
	ElseIf FileExists("D:\Windows\Boot") Then
		$WinDir_PE = "D:\Windows"
	ElseIf FileExists("E:\Windows\Boot") Then
		$WinDir_PE = "E:\Windows"
	Else
		$WinDir_PE = "D:\Windows"
	EndIf
EndIf

; Creating GUI and controls
$hGuiParent = GUICreate(" USB_FORMAT x86 - Tool to Make Bootable USB Drive", 400, 430, -1, -1, BitXOR($GUI_SS_DEFAULT_GUI, $WS_MINIMIZEBOX))
GUISetOnEvent($GUI_EVENT_CLOSE, "_Quit")

GUICtrlCreateGroup("USB FORMAT - Version 3.2 ", 18, 10, 364, 235)

GUICtrlCreateLabel( "1 - Format USB Drive with MBR and 2 Partitions FAT32 + NTFS", 32, 37)
GUICtrlCreateLabel( "2 - UEFI_MULTI can Add VHD or PE WIM File Booting from RAMDISK", 32, 67)
GUICtrlCreateLabel( "3 - Copy Linux ISO files to folder images on FAT32 - boot UEFI Grub2", 32, 97)
GUICtrlCreateLabel( "4 - USB drive Booting with Boot Manager Menu in BIOS or UEFI Mode", 32, 127)

GUICtrlCreateLabel( "FAT32  Size", 32, 187)
GUICtrlCreateLabel( "FAT32   MAX = 32 GB   MIN = 1 GB", 180, 187)

$Combo_2nd = GUICtrlCreateCombo("", 105, 182, 60, 24, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_2nd,"MIN|25 %|50 %|75 %|MAX", "50 %")
GUICtrlSetTip($Combo_2nd, " Only for Windows 10 and Removable Devices " _
& @CRLF & " FAT32 MAX = 32 GB   MIN = 1 GB   Rest = NTFS")

$refind = GUICtrlCreateCheckbox("", 224, 213, 17, 17)
GUICtrlSetTip($refind, " Add Grub2 needed to boot Linux ISO in UEFI mode" & @CRLF _
& " UEFI Mult-Boot Linux ISO + Windows 8 / 10 VHD + PE WIM " & @CRLF _
& " Setting Other is used for support of a1ive Grub2 File Manager ")
GUICtrlCreateLabel( "EFI Mgr", 328, 215)
$Combo_EFI = GUICtrlCreateCombo("", 248, 212, 70, 24, $CBS_DROPDOWNLIST)
GUICtrlSetData($Combo_EFI,"Grub 2|Other", "Grub 2")
GUICtrlSetTip($Combo_EFI, " Add Grub2 needed to boot Linux ISO in UEFI mode" & @CRLF _
& " UEFI Mult-Boot Linux ISO + Windows 8 / 10 VHD + PE WIM " & @CRLF _
& " Setting Other is used for support of a1ive Grub2 File Manager ")

$Reversed_PartLayout = GUICtrlCreateCheckbox("", 32, 213, 17, 17)
GUICtrlSetTip($Reversed_PartLayout, " Reversed Partition Layout - Max Disk Size 128 GB " _
& @CRLF & " 1 = NTFS  and  2 = FAT32 - Only for Windows 10")
GUICtrlCreateLabel( "Reversed Partition Layout", 52, 215)

$Allow_Fixed_USB = GUICtrlCreateCheckbox("", 32, 260, 17, 17)
GUICtrlSetTip($Allow_Fixed_USB, " Allow Fixed USB Drives " _
& @CRLF & " WARNING - All Content of USB Harddisk get Lost ")
GUICtrlCreateLabel( "Allow Fixed USB Drives", 52, 262)

$Bootmgr_Menu = GUICtrlCreateCheckbox("", 224, 260, 17, 17)
GUICtrlSetTip($Bootmgr_Menu, " Make USB Drive bootable with Windows Boot Manager and " _
& @CRLF & " Grub4dos Menu entry for booting VHD or Linux ISO in BIOS mode ")
GUICtrlCreateLabel( "Make Boot Manager Menu", 248, 262)

GUICtrlCreateGroup("Target USB Drive", 18, 290, 364, 54)

$Target = GUICtrlCreateInput($TargetSel, 32, 312, 40, 20, $ES_READONLY)
$TargetSel = GUICtrlCreateButton("...", 78, 313, 26, 18)
GUICtrlSetTip(-1, " Select USB First Partition as Target USB Drive for " & @CRLF _
& " Erase, Partition and Format USB Drive " & @CRLF _
& " FAT32 Size MAX = 32 GB and MIN = 1 GB - Rest is NTFS ")
GUICtrlSetOnEvent($TargetSel, "_target_drive")
$TargetSize = GUICtrlCreateLabel( "", 120, 306, 90, 15, $ES_READONLY)
$TargetFree = GUICtrlCreateLabel( "", 120, 323, 90, 15, $ES_READONLY)
$Target_Device = GUICtrlCreateLabel( "", 215, 306, 150, 15, $ES_READONLY)
$Target_Type = GUICtrlCreateLabel( "", 215, 323, 150, 15, $ES_READONLY)
GUICtrlSetOnEvent($TargetSel, "_target_drive")

$FormUSB = GUICtrlCreateButton("Format Drive", 235, 360, 70, 30)
GUICtrlSetTip($FormUSB, " Erase, Partition and Format USB Drive ")
GUICtrlSetOnEvent($FormUSB, "_USB_Format")

$EXIT = GUICtrlCreateButton("EXIT", 320, 360, 60, 30)
GUICtrlSetOnEvent($EXIT, "_Quit")

$ProgressAll = GUICtrlCreateProgress(16, 368, 203, 16, $PBS_SMOOTH)

$hStatus = _GUICtrlStatusBar_Create($hGuiParent, -1, "", $SBARS_TOOLTIPS)
Global $aParts[3] = [310, 350, -1]
_GUICtrlStatusBar_SetParts($hStatus, $aParts)

_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)

DisableMenus(1)

If @OSVersion = "WIN_10" Then
	GUICtrlSetState($Combo_2nd, $GUI_ENABLE)
	GUICtrlSetState($Reversed_PartLayout, $GUI_ENABLE)
Else
	GUICtrlSetData($Combo_2nd,"MIN|25 %|50 %|75 %|MAX", "MAX")
	GUICtrlSetState($Combo_2nd, $GUI_DISABLE)
	GUICtrlSetState($Reversed_PartLayout, $GUI_DISABLE)
EndIf

GUICtrlSetState($refind, $GUI_UNCHECKED + $GUI_ENABLE)
GUICtrlSetState($Combo_EFI, $GUI_ENABLE)
GUICtrlSetState($TargetSel, $GUI_ENABLE)
GUICtrlSetState($FormUSB, $GUI_DISABLE)
GUICtrlSetState($EXIT, $GUI_ENABLE)

GUICtrlSetState($Allow_Fixed_USB, $GUI_ENABLE)
GUICtrlSetState($Bootmgr_Menu, $GUI_ENABLE + $GUI_CHECKED)

GUISetState(@SW_SHOW)

;===================================================================================================
While 1
	CheckGo()
    Sleep(300)
WEnd   ;==> Loop
;===================================================================================================
Func CheckGo()
	Local $valid=1

	If $TargetDrive <> "" Then
		GUICtrlSetState($FormUSB, $GUI_ENABLE)
		_GUICtrlStatusBar_SetText($hStatus," Use Format Drive to Erase and Format USB Drive", 0)
	Else
		If GUICtrlRead($FormUSB) = $GUI_ENABLE Then
			GUICtrlSetState($FormUSB, $GUI_DISABLE)
			_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
		EndIf
	EndIf
EndFunc ;==> _CheckGo
;===================================================================================================
Func _Quit()
	Local $ikey
    If @GUI_WinHandle = $hGuiParent Then
		DisableMenus(1)
		$ikey = MsgBox(48+4+256, " STOP Program ", " STOP Program ? ")
		If $ikey = 6 Then
			Exit
		Else
			DisableMenus(0)
			If $TargetDrive = "" Then
				GUICtrlSetState($TargetSel, $GUI_ENABLE + $GUI_FOCUS)
			EndIf
			Return
		EndIf
    Else
        GUIDelete(@GUI_WinHandle)
    EndIf
EndFunc   ;==> _Quit
;===================================================================================================
Func SystemFileRedirect($Wow64Number)
	If @OSArch = "X64" Then
		Local $WOW64_CHECK = DllCall("kernel32.dll", "int", "Wow64DisableWow64FsRedirection", "ptr*", 0)
		If Not @error Then
			If $Wow64Number = "On" And $WOW64_CHECK[1] <> 1 Then
				DllCall("kernel32.dll", "int", "Wow64DisableWow64FsRedirection", "int", 1)
			ElseIf $Wow64Number = "Off" And $WOW64_CHECK[1] <> 0 Then
				DllCall("kernel32.dll", "int", "Wow64EnableWow64FsRedirection", "int", 1)
			EndIf
		EndIf
	EndIf
EndFunc   ;==> SystemFileRedirect
;===================================================================================================
Func _target_drive()
	Local $TargetSelect, $Tdrive, $valid = 0, $ValidDrives, $RemDrives
	Local $NoDrive[3] = ["A:", "B:", "X:"], $FileSys[4] = ["NTFS", "FAT32", "FAT", "exFAT"]
	Local $pos, $fs_ok=0

	$DriveType="Fixed"
	DisableMenus(1)

	_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)

	$ValidDrives = DriveGetDrive( "FIXED" )
	_ArrayPush($ValidDrives, "")
	_ArrayPop($ValidDrives)
	$RemDrives = DriveGetDrive( "REMOVABLE" )
	_ArrayPush($RemDrives, "")
	_ArrayPop($RemDrives)
	_ArrayConcatenate($ValidDrives, $RemDrives)
	; _ArrayDisplay($ValidDrives)

	$TargetDrive = ""
	$FSvar=""
	GUICtrlSetData($Target, "")
	GUICtrlSetData($TargetSize, "")
	GUICtrlSetData($TargetFree, "")
	GUICtrlSetData($Target_Device, "")
	GUICtrlSetData($Target_Type, "")
	GUICtrlSetState($FormUSB, $GUI_DISABLE)

	$TargetSelect = FileSelectFolder("Select USB Drive as Target Drive", "")
	If @error Then
		DisableMenus(0)
		Return
	EndIf

	$pos = StringInStr($TargetSelect, "\", 0, -1)
	If $pos = 0 Then
		MsgBox(48,"ERROR - Path Invalid", "Path Invalid - No Backslash Found" & @CRLF & @CRLF & "Selected Path = " & $TargetSelect)
		DisableMenus(0)
		Return
	EndIf

	$pos = StringInStr($TargetSelect, " ", 0, -1)
	If $pos Then
		MsgBox(48,"ERROR - Path Invalid", "Path Invalid - Space Found" & @CRLF & @CRLF & "Selected Path = " & $TargetSelect & @CRLF & @CRLF _
		& "Solution - Use simple Path without Spaces ")
		DisableMenus(0)
		Return
	EndIf

	$pos = StringInStr($TargetSelect, ":", 0, 1)
	If $pos <> 2 Then
		MsgBox(48,"ERROR - Path Invalid", "Drive Invalid - : Not found" & @CRLF & @CRLF & "Selected Path = " & $TargetSelect)
		DisableMenus(0)
		Return
	EndIf

	$Tdrive = StringLeft($TargetSelect, 2)
	FOR $d IN $ValidDrives
		If $d = $Tdrive Then
			$valid = 1
			ExitLoop
		EndIf
	NEXT
	FOR $d IN $NoDrive
		If $d = $Tdrive Then
			$valid = 0
			MsgBox(48, "ERROR - Drive NOT Valid", " Drive A: B: and X: ", 3)
			DisableMenus(0)
			Return
		EndIf
	NEXT
	If $valid And DriveStatus($Tdrive) <> "READY" Then
		$valid = 0
		MsgBox(16, "WARNING - Drive NOT Ready", "Drive NOT READY " & @CRLF & @CRLF & "First Format Target Drive  ", 0)
		DisableMenus(0)
		Return
	EndIf
	If $valid Then

		$DriveType=DriveGetType($Tdrive)

		IF $DriveType <> "Removable" And GUICtrlRead($Allow_Fixed_USB) = $GUI_UNCHECKED Then
			$valid = 0
			MsgBox(48, "WARNING - Invalid Drive Type ", "Selected Drive Type = " & $DriveType & @CRLF _
			& @CRLF & "Target Drive Type must be Removable USB-Stick " & @CRLF _
			& @CRLF & "Or Select - Allow Fixed USB Drives ", 0)
			GUICtrlSetState($TargetSel, $GUI_ENABLE + $GUI_FOCUS)
			_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
			DisableMenus(0)
			Return
		EndIf
		$FSvar = DriveGetFileSystem( $Tdrive )
		FOR $d IN $FileSys
			If $d = $FSvar Then
				$fs_ok = 1
				ExitLoop
			Else
				$fs_ok = 0
			EndIf
		NEXT
		IF Not $fs_ok Then
			$valid = 0
			MsgBox(48, "WARNING - Invalid FileSystem", "NTFS - FAT32 Or exFAT FileSystem NOT Found" & @CRLF _
			& @CRLF & "Continue and First Format Target Drive ", 0)
			GUICtrlSetState($TargetSel, $GUI_ENABLE + $GUI_FOCUS)
			_GUICtrlStatusBar_SetText($hStatus," First Format Target Drive ", 0)
			DisableMenus(0)
			Return
		EndIf
	EndIf
	If $valid Then
		$TargetDrive = $Tdrive
		; $TargetDrive = StringLeft($TargetSelect, 2)

		_GUICtrlStatusBar_SetText($hStatus," Getting Drive Parameters - Wait ... ", 0)
		_ListUsb()

		If $inst_disk = "" Or $inst_part = "" Or $vol_size = "no media" Or $inst_part <> "1" Or $usbfix = 0 Then
			$valid = 0
			MsgBox(16, "  STOP - Target Drive is NOT Valid", "Target Drive is Not USB First Partition " & @CRLF & @CRLF _
			& "More Info in Drive List makebt\usblist.txt " & @CRLF & @CRLF _
			& "Target Drive = " & $TargetDrive & "   Device = " & $inst_disk & "   Partition = " & $inst_part & @CRLF & @CRLF _
			& "Disk Size = " & $disk_size & "   Volume Size = " & $vol_size & @CRLF & @CRLF & "Bus Type = " & $BusType & "   Drive Type = " & $DriveType)

			$TargetDrive = ""
			_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
			DisableMenus(0)
			Return
		EndIf

		GUICtrlSetData($Target, $TargetDrive)
		GUICtrlSetData($TargetSize, $FSvar & "   " & Round(DriveSpaceTotal($TargetDrive) / 1024) & " GB")
		GUICtrlSetData($TargetFree, "Disk  =  " & $disk_size)
		GUICtrlSetData($Target_Device, "Device = " & $inst_disk & "    Partition = " & $inst_part)
		GUICtrlSetData($Target_Type, $BusType & "   " & $DriveType)

	EndIf
	_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
	DisableMenus(0)
EndFunc   ;==> _target_drive
;===================================================================================================
Func _ListUsb()

	Local $file, $line, $linesplit[20], $mptarget=0, $count, $MountPoint="", $VolumeLabel = ""

	If FileExists(@ScriptDir & "\makebt\usblist.txt") Then
		FileCopy(@ScriptDir & "\makebt\usblist.txt", @ScriptDir & "\makebt\usblist_bak.txt", 1)
		FileDelete(@ScriptDir & "\makebt\usblist.txt")
	EndIf
	Sleep(1000)

	RunWait(@ComSpec & " /c makebt\listusbdrives\ListUsbDrives.exe -a > makebt\usblist.txt", @ScriptDir, @SW_HIDE)

	If $dp_finish = 1 Then
		$file = FileOpen(@ScriptDir & "\makebt\usblist.txt", 0)
		If $file <> -1 Then
			$count = 0
			$mptarget = 0
			While 1
				$line = FileReadLine($file)
				If @error = -1 Then ExitLoop
				If $line <> "" Then
					$count = $count + 1
					$linesplit = StringSplit($line, "=")
					$linesplit[1] = StringStripWS($linesplit[1], 3)
					If $linesplit[1] = "MountPoint" And $linesplit[0] = 2 Then
						$MountPoint = StringStripWS($linesplit[2], 3)
					EndIf
					If $linesplit[1] = "Volume Label" And $linesplit[0] = 2 Then
						$VolumeLabel = StringStripWS($linesplit[2], 3)
					EndIf
					If $linesplit[1] = "Device Number" And $linesplit[0] = 2 Then
						If StringStripWS($linesplit[2], 3) = $inst_disk And $VolumeLabel = "U-NTFS" Then
							$NTFS_Drive = StringLeft($MountPoint, 2)
							; MsgBox(0, "NTFS Drive Found - OK", " NTFS Drive = " & $NTFS_Drive)
						EndIf
					EndIf
				EndIf
			Wend
			FileClose($file)
		EndIf
	EndIf

	$usbfix=0
	$file = FileOpen(@ScriptDir & "\makebt\usblist.txt", 0)
	If $file <> -1 Then
		$count = 0
		$mptarget = 0
		While 1
			$line = FileReadLine($file)
			If @error = -1 Then ExitLoop
			If $line <> "" Then
				$count = $count + 1
				$linesplit = StringSplit($line, "=")
				$linesplit[1] = StringStripWS($linesplit[1], 3)
				If $linesplit[1] = "MountPoint" And $linesplit[0] = 2 Then
					$linesplit[2] = StringStripWS($linesplit[2], 3)
					If $linesplit[2] = $TargetDrive & "\" Then
						$mptarget = 1
						; MsgBox(0, "TargetDrive Found - OK", " TargetDrive = " & $linesplit[2], 3)
					Else
						$mptarget = 0
					EndIf
				EndIf
				If $mptarget = 1 Then
					If $linesplit[1] = "Bus Type" And $linesplit[0] = 2 Then
						$linesplit[2] = StringStripWS($linesplit[2], 3)
						$BusType = $linesplit[2]
						If $linesplit[2] = "USB" Then
							$usbfix = 1
						Else
							$usbfix = 0
						EndIf
						; MsgBox(0, "TargetDrive USB or HDD ?", " Bus Type = " & $BusType, 3)
					EndIf
					If $linesplit[1] = "Volume Size" And $linesplit[0] = 2 Then
						$vol_size = StringStripWS($linesplit[2], 3)
					EndIf
					If $linesplit[1] = "Disk Size" And $linesplit[0] = 2 Then
						$disk_size = StringStripWS($linesplit[2], 3)
					EndIf
					If $linesplit[1] = "Device Number" And $linesplit[0] = 2 Then
						$inst_disk = StringStripWS($linesplit[2], 3)
					EndIf
					If $linesplit[1] = "Partition Number" Then
						$inst_part = StringLeft(StringStripWS($linesplit[2], 3), 1)
					EndIf
				EndIf
			EndIf
		Wend
		FileClose($file)
	EndIf

;~ 	MsgBox(48, "Target Drive Found", "Device Number Found in makebt\usblist.txt" & @CRLF & @CRLF _
;~ 	& "Target Drive = " & $TargetDrive & "   HDD = " & $inst_disk & "   PART = " & $inst_part & @CRLF & @CRLF _
;~ 	& "Disk Size = " & $disk_size & "   Volume Size = " & $vol_size & @CRLF & @CRLF & "Bus Type = " & $BusType & "   Drive Type = " & $DriveType)

EndFunc ;==> _ListUsb
;===================================================================================================
Func DisableMenus($endis)
	If $endis = 0 Then
		$endis = $GUI_ENABLE
	Else
		$endis = $GUI_DISABLE
	EndIf
	If @OSVersion = "WIN_10" Then
		GUICtrlSetState($Combo_2nd, $endis)
		GUICtrlSetState($Reversed_PartLayout, $endis)
	Else
		GUICtrlSetState($Combo_2nd, $GUI_DISABLE)
		GUICtrlSetState($Reversed_PartLayout, $GUI_DISABLE)
	EndIf
	GUICtrlSetState($FormUSB, $GUI_DISABLE)
	GUICtrlSetState($EXIT, $endis)
	GUICtrlSetState($Combo_EFI, $endis)
	If GUICtrlRead($Bootmgr_Menu) = $GUI_UNCHECKED Then
		GUICtrlSetState($refind, $GUI_UNCHECKED)
	EndIf
	GUICtrlSetState($refind, $endis)
	GUICtrlSetState($Allow_Fixed_USB, $endis)
	GUICtrlSetState($Bootmgr_Menu, $endis)

	GUICtrlSetState($TargetSel, $endis)
	GUICtrlSetState($Target, $endis)
	GUICtrlSetData($Target, $TargetDrive)
EndFunc ;==>DisableMenus
;===================================================================================================
Func _USB_Format() ; Erase, Partition and Format USB Drives

	Local $val=0, $file, $line, $linesplit[20], $ikey, $PSize = "MIN", $AutoPlay_Data="", $make_ntfs_flag = 0

	DisableMenus(1)

	If GUICtrlRead($Bootmgr_Menu) = $GUI_UNCHECKED Then
		GUICtrlSetState($refind, $GUI_UNCHECKED)
	EndIf

	$DriveType=DriveGetType($TargetDrive)

	; Should not occur ....
	If $DriveType <> "Removable" And GUICtrlRead($Allow_Fixed_USB) = $GUI_UNCHECKED Then
		MsgBox(16, "Invalid Drive", " Drive is NOT Removable USB-stick ", 0)
		Exit
	EndIf

	If DriveStatus($TargetDrive) <> "READY" Then
		MsgBox(16, "WARNING - Drive NOT Ready", "Drive NOT READY " & @CRLF & @CRLF & "First Format Target Drive using Other Tool ", 0)
		Exit
	EndIf

	If @SystemDir = "X:\i386\system32" Or @SystemDir = "X:\minint\system32" Then
		MsgBox(16, "BartPE type Operating System", " Unable to Format USB Drive in BartPE Environment ", 0)
		Exit
	EndIf

	_GUICtrlStatusBar_SetText($hStatus," Getting Drive Parameters - Wait ... ", 0)
	GUICtrlSetData($ProgressAll, 20)

	If FileExists(@ScriptDir & "\makebt\bs_temp") Then DirRemove(@ScriptDir & "\makebt\bs_temp",1)
	If Not FileExists(@ScriptDir & "\makebt\bs_temp") Then DirCreate(@ScriptDir & "\makebt\bs_temp")

	If FileExists(@ScriptDir & "\makebt\dp_temp") Then DirRemove(@ScriptDir & "\makebt\dp_temp",1)
	If Not FileExists(@ScriptDir & "\makebt\dp_temp") Then DirCreate(@ScriptDir & "\makebt\dp_temp")

	_ListUsb()

	If $inst_disk = "" Or $inst_part = "" Or $vol_size = "no media" Or $inst_part <> "1" Or $usbfix = 0 Then
		MsgBox(16, "  STOP - Target Drive is NOT Valid", "Target Drive is Not USB First Partition " & @CRLF & @CRLF _
		& "More Info in Drive List makebt\usblist.txt " & @CRLF & @CRLF _
		& "Target Drive = " & $TargetDrive & "   Device = " & $inst_disk & "   Partition = " & $inst_part & @CRLF & @CRLF _
		& "Disk Size = " & $disk_size & "   Volume Size = " & $vol_size & @CRLF & @CRLF & "Bus Type = " & $BusType & "   Drive Type = " & $DriveType)
		_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
		GUICtrlSetData($ProgressAll, 0)
		DisableMenus(0)
		Return
	EndIf

	If $disk_size = "" Then
		$disk_size = $vol_size
	EndIf
	$linesplit = StringSplit($disk_size, " ")
	; _ArrayDisplay($linesplit)

	If $linesplit[0] >= 2 And $linesplit[2] = "GB" Then
		$disk_GB = $linesplit[1]
	EndIf

	; Reversed Partition Layout only for USB-Stick max size = 128 GB
	If $disk_GB > 128 Then
		GUICtrlSetState($Reversed_PartLayout, $GUI_UNCHECKED)
	EndIf

	$PSize = GUICtrlRead($Combo_2nd)
	If $PSize = "MAX" Then
		If $disk_GB > 29 Then
			$f32_size="29000"
			If $disk_GB > 35 Then
				$make_ntfs_flag = 1
			EndIf
		Else
			$f32_size = $disk_GB & "000"
		EndIf
	ElseIf $PSize = "75 %" Then
		If $disk_GB > 29 Then
			$f32_size="22528"  ; 22 GB
		Else
			$f32_size = Round($disk_GB * 750)
		EndIf
	ElseIf $PSize = "50 %" Then
		If $disk_GB > 29 Then
			$f32_size="15360"  ; 15 GB
		Else
			$f32_size = Round($disk_GB * 500)
		EndIf
	ElseIf $PSize = "25 %" Then
		If $disk_GB > 29 Then
			$f32_size="8192"  ; 8 GB
		Else
			$f32_size = Round($disk_GB * 250)
		EndIf
	Else
		$f32_size="1024"
	EndIf

	$ntfs_size = ($disk_GB - 2)*1000 - $f32_size

	GUICtrlSetData($ProgressAll, 30)

	If $DriveType = "Removable" And GUICtrlRead($Allow_Fixed_USB) = $GUI_UNCHECKED Then
		$ikey = MsgBox(48+4+256, "  Erase, Partition and Format USB Drive ? ", "USB Drive = " & $TargetDrive & "   Partition = " & $inst_part & "   Disk = " & $inst_disk  & @CRLF & @CRLF _
		& "Size = " & $disk_size & "   Bus Type = " & $BusType & "   Drive Type = " & $DriveType & @CRLF & @CRLF _
		& "Erase, Partition and Format Target USB Drive " & $TargetDrive & " with FAT32 "	& @CRLF & @CRLF _
		& "WARNING - All Data on Selected Drive get Lost ")
	Else
		$ikey = MsgBox(48+4+256, "  Erase, Partition and Format USB Drive ? ", "USB Drive = " & $TargetDrive & "   Partition = " & $inst_part & "   Disk = " & $inst_disk  & @CRLF & @CRLF _
		& "Size = " & $disk_size & "   Bus Type = " & $BusType & "   Drive Type = " & $DriveType & @CRLF & @CRLF _
		& "Erase, Partition and Format Target USB Drive " & $TargetDrive & " with FAT32 "	& @CRLF & @CRLF _
		& "WARNING - All Data on Selected Drive get Lost " & @CRLF & @CRLF _
		& "Are You Sure ? - This is an USB Harddisk ! ")
	EndIf

	If $ikey <> 6 Then
		_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
		GUICtrlSetData($ProgressAll, 0)
		DisableMenus(0)
		Return
	EndIf

	SystemFileRedirect("On")

	If Not FileExists(@WindowsDir & "\system32\diskpart.exe") Then
		; SystemFileRedirect("Off")
		MsgBox(48, "ERROR - DiskPart Not Found ", " system32\diskpart.exe needed to Make Partitions " & @CRLF & @CRLF & " Boot with Windows 7/8/10 or 7/8/10 PE ", 3)
		_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
		GUICtrlSetData($ProgressAll, 0)
		DisableMenus(0)
		Return
	EndIf

	If FileExists(@ScriptDir & "\makebt\dp_temp\Reg_DisableAutoPlay.txt") Then FileDelete(@ScriptDir & "\makebt\dp_temp\Reg_DisableAutoPlay.txt")

	RunWait(@ComSpec & " /c reg query HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers /v DisableAutoplay" & " > makebt\dp_temp\Reg_DisableAutoPlay.txt", @ScriptDir, @SW_HIDE)

	$file = FileOpen(@ScriptDir & "\makebt\dp_temp\Reg_DisableAutoPlay.txt", 0)
	While 1
		$line = FileReadLine($file)
		If @error = -1 Then ExitLoop
		If $line <> "" Then
			$line = StringStripWS($line, 7)
			$linesplit = StringSplit($line, " ")
			; _ArrayDisplay($linesplit)
			If $linesplit[1] = "DisableAutoplay" Then
				$AutoPlay_Data = $linesplit[3]
			EndIf
		EndIf
	Wend
	FileClose($file)

	If FileExists(@ScriptDir & "\makebt\dp_temp\disk_part.txt") Then FileDelete(@ScriptDir & "\makebt\dp_temp\disk_part.txt")

	If $AutoPlay_Data = "0x0" Or $AutoPlay_Data = "" Then
		RunWait(@ComSpec & " /c reg add HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers /v DisableAutoplay /t REG_DWORD /d 1 /f", @ScriptDir, @SW_HIDE)
		; MsgBox(48, "Info AutoPlay Disabled ", "  " & @CRLF & @CRLF & " Disable AutoPlay_Data = 1 ", 0)
	EndIf

	If GUICtrlRead($Reversed_PartLayout) = $GUI_UNCHECKED Then
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","list disk")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","select disk " & $inst_disk)
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","clean")
		If $PSize = "MAX" And $make_ntfs_flag = 0 Then
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","create partition primary")
		Else
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","create partition primary size=" & $f32_size)
		EndIf
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","format quick fs=fat32 label=U-BOOT")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","assign letter=" & StringLeft($TargetDrive, 1))
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","active")
		If $PSize <> "MAX" Or $make_ntfs_flag = 1 Then
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","create partition primary")
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","format quick fs=ntfs label=U-NTFS")
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","assign")
		EndIf
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","list volume")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","exit")
	Else
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","list disk")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","select disk " & $inst_disk)
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","clean")
		If $PSize <> "MAX" Or $make_ntfs_flag = 1 Then
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","create partition primary size=" & $ntfs_size)
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","format quick fs=ntfs label=U-NTFS")
			FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","assign")
		EndIf
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","create partition primary")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","format quick fs=fat32 label=U-BOOT")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","assign letter=" & StringLeft($TargetDrive, 1))
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","active")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","list volume")
		FileWriteLine(@ScriptDir & "\makebt\dp_temp\disk_part.txt","exit")
	EndIf

	_GUICtrlStatusBar_SetText($hStatus," DiskPart is used to Format USB Drive - Wait ... ", 0)
	$val = RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\diskpart.exe /s  makebt\dp_temp\disk_part.txt", @ScriptDir, @SW_HIDE)
	If $val <> 0 Then
		; Reset Disable AutoPlay to Original value 0 = Enable AutoPlay
		If $AutoPlay_Data = "0x0" Or $AutoPlay_Data = "" Then
			RunWait(@ComSpec & " /c reg add HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers /v DisableAutoplay /t REG_DWORD /d 0 /f", @ScriptDir, @SW_HIDE)
			; MsgBox(48, "Info AutoPlay Enabled ", "  " & @CRLF & @CRLF & " Disable AutoPlay_Data = 0 ", 0)
		EndIf
		SystemFileRedirect("Off")
		MsgBox(16, " STOP - Error DiskPart", " DiskPart Error = " & $val & @CRLF & @CRLF _
		& " Use Disk Mananagement to Create Partition ", 0)
		_GUICtrlStatusBar_SetText($hStatus," Select USB First Partition as Target Drive ", 0)
		GUICtrlSetData($ProgressAll, 0)
		DisableMenus(0)
		Return
	EndIf

	; Reset Disable AutoPlay to Original value 0 = Enable AutoPlay
	If $AutoPlay_Data = "0x0" Or $AutoPlay_Data = "" Then
		RunWait(@ComSpec & " /c reg add HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers /v DisableAutoplay /t REG_DWORD /d 0 /f", @ScriptDir, @SW_HIDE)
		; MsgBox(48, "Info AutoPlay Enabled ", "  " & @CRLF & @CRLF & " Disable AutoPlay_Data = 0 ", 0)
	EndIf

	$dp_finish = 1

	Sleep(1000)

	_ListUsb()

	GUICtrlSetData($ProgressAll, 70)
	_GUICtrlStatusBar_SetText($hStatus," DiskPart has finished - Wait ... ", 0)
	$FSvar = DriveGetFileSystem($TargetDrive)
	GUICtrlSetData($Target, $TargetDrive)
	GUICtrlSetData($TargetSize, $FSvar & "   " & Round(DriveSpaceTotal($TargetDrive) / 1024) & " GB")
	GUICtrlSetData($TargetFree, "Disk  =  " & $disk_size)
	GUICtrlSetData($Target_Device, "Device = " & $inst_disk & "    Partition = " & $inst_part)
	GUICtrlSetData($Target_Type, $BusType & "   " & $DriveType)

	If FileExists(@ScriptDir & "\makebt\autorun.inf") Then FileCopy(@ScriptDir & "\makebt\autorun.inf", $TargetDrive & "\")
	If FileExists(@ScriptDir & "\makebt\Uefi_Multi.ico") Then FileCopy(@ScriptDir & "\makebt\Uefi_Multi.ico", $TargetDrive & "\")

	If $PSize <> "MAX" Or $make_ntfs_flag = 1 And $NTFS_Drive <> "" Then
		If FileExists(@ScriptDir & "\makebt\autorun.inf") Then FileCopy(@ScriptDir & "\makebt\autorun.inf", $NTFS_Drive & "\")
		If FileExists(@ScriptDir & "\makebt\Uefi_Multi.ico") Then FileCopy(@ScriptDir & "\makebt\Uefi_Multi.ico", $NTFS_Drive & "\")
	EndIf

	_WinLang()

	Sleep(2000)

	If $TargetDrive <> "" And GUICtrlRead($Bootmgr_Menu) = $GUI_CHECKED Then
		; SystemFileRedirect("On")
		If @OSVersion = "WIN_10" Or @OSVersion = "WIN_81" Or @OSVersion = "WIN_8" And @OSArch <> "X86" And $PE_flag = 0 Then
			_GUICtrlStatusBar_SetText($hStatus," UEFI x64 - Make Boot Manager Menu on USB " & $TargetDrive & " - wait .... ", 0)
			$val = RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdboot.exe " & @WindowsDir & " /l " & $WinLang & " /s " & $TargetDrive & " /f ALL", @ScriptDir, @SW_HIDE)
		Else
			If $PE_flag = 1 Then
				_GUICtrlStatusBar_SetText($hStatus," PE x64 - Make Boot Manager Menu on USB " & $TargetDrive & " - wait .... ", 0)
				$val = RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdboot.exe " & $WinDir_PE & " /s " & $TargetDrive & " /f ALL", @ScriptDir, @SW_HIDE)
			Else
				_GUICtrlStatusBar_SetText($hStatus," Make Boot Manager Menu on USB Drive " & $TargetDrive & " - wait .... ", 0)
				$val = RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdboot.exe " & @WindowsDir & " /l " & $WinLang & " /s " & $TargetDrive, @ScriptDir, @SW_HIDE)
			EndIf
		EndIf
		FileSetAttrib($TargetDrive & "\Boot", "-RSH", 1)
		FileSetAttrib($TargetDrive & "\bootmgr", "-RSH")
		Sleep(2000)
		; to get Win 8 Boot Manager Menu displayed and waiting for User Selection
		If FileExists($TargetDrive & "\EFI\Microsoft\Boot\BCD") And FileExists(@WindowsDir & "\system32\bcdedit.exe") Then
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\EFI\Microsoft\Boot\BCD" & " /set {default} bootmenupolicy legacy", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\EFI\Microsoft\Boot\BCD" & " /set {default} detecthal on", $TargetDrive & "\", @SW_HIDE)
			If FileExists(@WindowsDir & "\SysWOW64") Then
				RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
				& $TargetDrive & "\EFI\Microsoft\Boot\BCD" & " /set {default} testsigning on", $TargetDrive & "\", @SW_HIDE)
				RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
				& $TargetDrive & "\EFI\Microsoft\Boot\BCD" & " /set {bootmgr} nointegritychecks on", $TargetDrive & "\", @SW_HIDE)
			EndIf
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\EFI\Microsoft\Boot\BCD" & " /bootems {emssettings} ON", $TargetDrive & "\", @SW_HIDE)
		EndIf
		If FileExists($TargetDrive & "\Boot\BCD") And FileExists(@WindowsDir & "\system32\bcdedit.exe") Then
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\Boot\BCD" & " /set {default} bootmenupolicy legacy", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\Boot\BCD" & " /set {default} detecthal on", $TargetDrive & "\", @SW_HIDE)
			If FileExists(@WindowsDir & "\SysWOW64") Then
				RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
				& $TargetDrive & "\Boot\BCD" & " /set {default} testsigning on", $TargetDrive & "\", @SW_HIDE)
				RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
				& $TargetDrive & "\Boot\BCD" & " /set {bootmgr} nointegritychecks on", $TargetDrive & "\", @SW_HIDE)
			EndIf
			RunWait(@ComSpec & " /c " & @WindowsDir & "\system32\bcdedit.exe" & " /store " _
			& $TargetDrive & "\Boot\BCD" & " /bootems {emssettings} ON", $TargetDrive & "\", @SW_HIDE)
		EndIf
		; SystemFileRedirect("Off")
	EndIf

	SystemFileRedirect("Off")

	GUICtrlSetData($ProgressAll, 80)
	If $DriveType="Removable" Or $usbfix And GUICtrlRead($refind) = $GUI_CHECKED Then
		_GUICtrlStatusBar_SetText($hStatus," Adding Grub2 Boot Manager - wait .... ", 0)
		If FileExists($TargetDrive & "\efi\boot\bootx64.efi") And Not FileExists($TargetDrive & "\efi\boot\org-bootx64.efi") Then
			FileMove($TargetDrive & "\efi\boot\bootx64.efi", $TargetDrive & "\efi\boot\org-bootx64.efi", 1)
		EndIf
		If Not FileExists($TargetDrive & "\efi\microsoft\boot\bootmgfw.efi") And @OSArch = "X64" Then
			If FileExists(@WindowsDir & "\Boot\EFI\bootmgfw.efi") And FileExists($TargetDrive & "\efi\microsoft\boot\bcd") Then
				FileCopy(@WindowsDir & "\Boot\EFI\bootmgfw.efi", $TargetDrive & "\efi\microsoft\boot\", 0)
			EndIf
		EndIf
		If FileExists($TargetDrive & "\efi\boot\grubx64.efi") And Not FileExists($TargetDrive & "\efi\boot\org-grubx64.efi") Then
			FileMove($TargetDrive & "\efi\boot\grubx64.efi", $TargetDrive & "\efi\boot\org-grubx64.efi", 1)
		EndIf
		If FileExists($TargetDrive & "\efi\boot\grub.cfg") And Not FileExists($TargetDrive & "\efi\boot\org-grub.cfg") Then
			FileMove($TargetDrive & "\efi\boot\grub.cfg", $TargetDrive & "\efi\boot\org-grub.cfg", 1)
		EndIf
		If GUICtrlRead($Combo_EFI) = "Grub 2" Then
			DirCopy(@ScriptDir & "\UEFI_MAN\efi_mint", $TargetDrive & "\efi", 1)
			If Not FileExists($TargetDrive & "\grubfm.iso") And FileExists(@ScriptDir & "\UEFI_MAN\grubfm.iso") Then FileCopy(@ScriptDir & "\UEFI_MAN\grubfm.iso", $TargetDrive & "\", 1)
			If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grubfmx64.efi") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grubfmx64.efi", $TargetDrive & "\efi\boot\", 1)
			If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grubfmia32.efi") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grubfmia32.efi", $TargetDrive & "\efi\boot\", 1)
		Else
			DirCopy(@ScriptDir & "\UEFI_MAN\efi", $TargetDrive & "\efi", 1)
			If FileExists(@ScriptDir & "\UEFI_MAN\grub2") Then
				DirCopy(@ScriptDir & "\UEFI_MAN\grub2", $TargetDrive & "\grub2", 1)
			EndIf
			If FileExists(@ScriptDir & "\UEFI_MAN\ENROLL_THIS_KEY_IN_MOKMANAGER.cer") Then FileCopy(@ScriptDir & "\UEFI_MAN\ENROLL_THIS_KEY_IN_MOKMANAGER.cer", $TargetDrive & "\", 1)
			If Not FileExists($TargetDrive & "\grubfm.iso") And FileExists(@ScriptDir & "\UEFI_MAN\grubfm.iso") Then FileCopy(@ScriptDir & "\UEFI_MAN\grubfm.iso", $TargetDrive & "\", 1)
		EndIf
		If Not FileExists($TargetDrive & "\boot\grub\grub.cfg") Then
			If FileExists($TargetDrive & "\AIO\grub\grub.cfg") And Not FileExists($TargetDrive & "\boot\grub\Main.cfg") Then
				DirCopy($TargetDrive & "\AIO\grub", $TargetDrive& "\boot\grub", 1)
				If FileExists($TargetDrive & "\boot\grub\Main.cfg") Then
					FileMove($TargetDrive & "\boot\grub\Main.cfg", $TargetDrive & "\boot\grub\org-Main.cfg", 1)
				EndIf
				FileCopy(@ScriptDir & "\UEFI_MAN\boot\grub\Main.cfg", $TargetDrive & "\boot\grub\", 1)
			Else
				If GUICtrlRead($Combo_EFI) = "Grub 2" Then
					FileCopy(@ScriptDir & "\UEFI_MAN\efi_mint\boot\grub.cfg", $TargetDrive & "\boot\grub\", 8)
					FileCopy(@ScriptDir & "\UEFI_MAN\efi_mint\boot\grub_Linux.cfg", $TargetDrive & "\boot\grub\", 8)
				Else
					If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grub.cfg") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grub.cfg", $TargetDrive & "\boot\grub\", 8)
					If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grub_Linux.cfg") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grub_Linux.cfg", $TargetDrive & "\boot\grub\", 8)
				EndIf
			EndIf
		Else
			If Not FileExists($TargetDrive & "\AIO\grub\grub.cfg") And Not FileExists($TargetDrive & "\boot\grub\Main.cfg") Then
				If FileExists($TargetDrive & "\boot\grub\grub.cfg") Then
					FileMove($TargetDrive & "\boot\grub\grub.cfg", $TargetDrive & "\boot\grub\org-grub.cfg", 1)
				EndIf
				If GUICtrlRead($Combo_EFI) = "Grub 2" Then
					FileCopy(@ScriptDir & "\UEFI_MAN\efi_mint\boot\grub.cfg", $TargetDrive & "\boot\grub\", 1)
					FileCopy(@ScriptDir & "\UEFI_MAN\efi_mint\boot\grub_Linux.cfg", $TargetDrive & "\boot\grub\", 1)
				Else
					If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grub.cfg") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grub.cfg", $TargetDrive & "\boot\grub\", 1)
					If FileExists(@ScriptDir & "\UEFI_MAN\efi\boot\grub_Linux.cfg") Then FileCopy(@ScriptDir & "\UEFI_MAN\efi\boot\grub_Linux.cfg", $TargetDrive & "\boot\grub\", 1)
				EndIf
			EndIf
		EndIf
		; make folder images for Linux ISO files
		If Not FileExists($TargetDrive & "\images") Then DirCreate($TargetDrive & "\images")
		If Not FileExists($TargetDrive & "\images\Linux_ISO_Files.txt") Then FileCopy(@ScriptDir & "\makebt\Linux_ISO_Files.txt", $TargetDrive & "\images\", 1)
		; Add \AIO\grub\grub2win to \Boot\BCD Menu for BIOS support of Grub2
		If FileExists($TargetDrive & "\AIO\grub\grub2win") Then
			_bcd_grub2()
		EndIf
		If FileExists($TargetDrive & "\grub2\g2bootmgr\gnugrub.kernel.bios") Then
			_bcd_grub2win()
		EndIf
	Else
		GUICtrlSetState($refind, $GUI_UNCHECKED + $GUI_DISABLE)
	EndIf

	If GUICtrlRead($Bootmgr_Menu) = $GUI_CHECKED Then
		If Not FileExists($TargetDrive & "\grldr") Then	FileCopy(@ScriptDir & "\makebt\grldr", $TargetDrive & "\", 1)
		If Not FileExists($TargetDrive & "\grub.exe") Then FileCopy(@ScriptDir & "\makebt\grub.exe", $TargetDrive & "\", 1)
		If Not FileExists($TargetDrive & "\menu.lst") Then FileCopy(@ScriptDir & "\makebt\menu.lst", $TargetDrive & "\", 1)
		If Not FileExists($TargetDrive & "\menu_Linux.lst") Then FileCopy(@ScriptDir & "\makebt\menu_Linux.lst", $TargetDrive & "\", 1)
		If FileExists(@ScriptDir & "\UEFI_MAN\grubfm.iso") Then FileCopy(@ScriptDir & "\UEFI_MAN\grubfm.iso", $TargetDrive & "\", 1)
		; make folder images for Linux ISO files
		If Not FileExists($TargetDrive & "\images") Then DirCreate($TargetDrive & "\images")
		If Not FileExists($TargetDrive & "\images\Linux_ISO_Files.txt") Then FileCopy(@ScriptDir & "\makebt\Linux_ISO_Files.txt", $TargetDrive & "\images\", 1)
		FileSetAttrib($TargetDrive & "\menu.lst", "-RSH")
		_g4d_bcd_menu()
		Sleep(1000)
	EndIf

	_GUICtrlStatusBar_SetText($hStatus," Formatting Target USB Drive - Ready ", 0)
	GUICtrlSetData($ProgressAll, 100)
	MsgBox(64, "FORMAT - Ready", "Formatting Target USB Drive - Ready", 0)
	Exit

EndFunc ;==> _USB_Format
;===================================================================================================
Func _g4d_bcd_menu()
	Local $file, $line, $store, $guid, $pos1, $pos2

	SystemFileRedirect("On")

	If FileExists(@WindowsDir & "\system32\bcdedit.exe") Then
		$bcdedit = @WindowsDir & "\system32\bcdedit.exe"
	Else
		$bcdedit = ""
	EndIf

	If FileExists($TargetDrive & "\Boot\BCD") And $bcdedit <> "" Then
		$store = $TargetDrive & "\Boot\BCD"

		_GUICtrlStatusBar_SetText($hStatus," Making  Grub4dos Entry in Boot Manager Menu - wait ....", 0)
		FileCopy(@ScriptDir & "\makebt\grldr.mbr", $TargetDrive & "\", 1)

		RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
		& $store & " /create /d " & '"' & "Start GRUB4DOS" & '"' & " /application bootsector > makebt\bs_temp\bcd_out.txt", @ScriptDir, @SW_HIDE)
		$file = FileOpen(@ScriptDir & "\makebt\bs_temp\bcd_out.txt", 0)
		$line = FileReadLine($file)
		FileClose($file)
		$pos1 = StringInStr($line, "{")
		$pos2 = StringInStr($line, "}")
		If $pos2-$pos1=37 Then
			$guid = StringMid($line, $pos1, $pos2-$pos1+1)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " device boot", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " path \grldr.mbr", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /displayorder " & $guid & " /addlast", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /default " & $guid, $TargetDrive & "\", @SW_HIDE)
		EndIf
	Else
		MsgBox(48, "CONFIG ERROR Or Missing File", "Unable to Add to Boot Manager Menu" & @CRLF & @CRLF _
			& " Missing bcdedit.exe Or Boot\BCD file ", 5)
	EndIf

	SystemFileRedirect("Off")

EndFunc   ;==> _g4d_bcd_menu
;===================================================================================================
Func _bcd_grub2()
	Local $file, $line, $store, $guid, $pos1, $pos2

	SystemFileRedirect("On")

	If FileExists(@WindowsDir & "\system32\bcdedit.exe") Then
		$bcdedit = @WindowsDir & "\system32\bcdedit.exe"
	Else
		$bcdedit = ""
	EndIf

	If FileExists($TargetDrive & "\Boot\BCD") And $bcdedit <> "" Then
		$store = $TargetDrive & "\Boot\BCD"

	;	_GUICtrlStatusBar_SetText($hStatus," Making  Grub2 Entry in Boot Manager Menu - wait ....", 0)

		RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
		& $store & " /create /d " & '"' & "Grub2 - AIO grub2win" & '"' & " /application bootsector > makebt\bs_temp\bcd_grub2.txt", @ScriptDir, @SW_HIDE)
		$file = FileOpen(@ScriptDir & "\makebt\bs_temp\bcd_grub2.txt", 0)
		$line = FileReadLine($file)
		FileClose($file)
		$pos1 = StringInStr($line, "{")
		$pos2 = StringInStr($line, "}")
		If $pos2-$pos1=37 Then
			$guid = StringMid($line, $pos1, $pos2-$pos1+1)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " device boot", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " path \AIO\grub\grub2win", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /displayorder " & $guid & " /addlast", $TargetDrive & "\", @SW_HIDE)
;~ 			If $DriveType="Removable" Or $usbfix Then
;~ 				RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
;~ 				& $store & " /default " & $guid, $TargetDrive & "\", @SW_HIDE)
;~ 			EndIf
		EndIf
	Else
		MsgBox(48, "CONFIG ERROR Or Missing File", "Unable to Add Grub2 to Boot Manager Menu" & @CRLF & @CRLF _
			& " Missing bcdedit.exe Or Boot\BCD file ", 5)
	EndIf

	SystemFileRedirect("Off")

EndFunc   ;==> _bcd_grub2
;===================================================================================================
Func _bcd_grub2win()
	Local $file, $line, $store, $guid, $pos1, $pos2

	SystemFileRedirect("On")

	If FileExists(@WindowsDir & "\system32\bcdedit.exe") Then
		$bcdedit = @WindowsDir & "\system32\bcdedit.exe"
	Else
		$bcdedit = ""
	EndIf

	If FileExists($TargetDrive & "\Boot\BCD") And $bcdedit <> "" Then
		$store = $TargetDrive & "\Boot\BCD"

	;	_GUICtrlStatusBar_SetText($hStatus," Making  Grub2 Entry in Boot Manager Menu - wait ....", 0)

		RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
		& $store & " /create /d " & '"' & "Grub 2 for Windows - Linux ISO" & '"' & " /application bootsector > makebt\bs_temp\bcd_grub2win.txt", @ScriptDir, @SW_HIDE)
		$file = FileOpen(@ScriptDir & "\makebt\bs_temp\bcd_grub2win.txt", 0)
		$line = FileReadLine($file)
		FileClose($file)
		$pos1 = StringInStr($line, "{")
		$pos2 = StringInStr($line, "}")
		If $pos2-$pos1=37 Then
			$guid = StringMid($line, $pos1, $pos2-$pos1+1)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " device boot", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /set " & $guid & " path \grub2\g2bootmgr\gnugrub.kernel.bios", $TargetDrive & "\", @SW_HIDE)
			RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
			& $store & " /displayorder " & $guid & " /addlast", $TargetDrive & "\", @SW_HIDE)
;~ 			If $DriveType="Removable" Or $usbfix Then
;~ 				RunWait(@ComSpec & " /c " & $bcdedit & " /store " _
;~ 				& $store & " /default " & $guid, $TargetDrive & "\", @SW_HIDE)
;~ 			EndIf
		EndIf
	Else
		MsgBox(48, "CONFIG ERROR Or Missing File", "Unable to Add Grub2Win to Boot Manager Menu" & @CRLF & @CRLF _
			& " Missing bcdedit.exe Or Boot\BCD file ", 5)
	EndIf

	SystemFileRedirect("Off")

EndFunc   ;==> _bcd_grub2win
;===================================================================================================
Func _WinLang()
	If FileExists(@WindowsDir & "\System32\en-US\ieframe.dll.mui") Then $WinLang = "en-US"
	If FileExists(@WindowsDir & "\System32\ar-SA\ieframe.dll.mui") Then $WinLang = "ar-SA"
	If FileExists(@WindowsDir & "\System32\bg-BG\ieframe.dll.mui") Then $WinLang = "bg-BG"
	If FileExists(@WindowsDir & "\System32\cs-CZ\ieframe.dll.mui") Then $WinLang = "cs-CZ"
	If FileExists(@WindowsDir & "\System32\da-DK\ieframe.dll.mui") Then $WinLang = "da-DK"
	If FileExists(@WindowsDir & "\System32\de-DE\ieframe.dll.mui") Then $WinLang = "de-DE"
	If FileExists(@WindowsDir & "\System32\el-GR\ieframe.dll.mui") Then $WinLang = "el-GR"
	If FileExists(@WindowsDir & "\System32\es-ES\ieframe.dll.mui") Then $WinLang = "es-ES"
	If FileExists(@WindowsDir & "\System32\es-MX\ieframe.dll.mui") Then $WinLang = "es-MX"
	If FileExists(@WindowsDir & "\System32\et-EE\ieframe.dll.mui") Then $WinLang = "et-EE"
	If FileExists(@WindowsDir & "\System32\fi-FI\ieframe.dll.mui") Then $WinLang = "fi-FI"
	If FileExists(@WindowsDir & "\System32\fr-FR\ieframe.dll.mui") Then $WinLang = "fr-FR"
	If FileExists(@WindowsDir & "\System32\he-IL\ieframe.dll.mui") Then $WinLang = "he-IL"
	If FileExists(@WindowsDir & "\System32\hr-HR\ieframe.dll.mui") Then $WinLang = "hr-HR"
	If FileExists(@WindowsDir & "\System32\hu-HU\ieframe.dll.mui") Then $WinLang = "hu-HU"
	If FileExists(@WindowsDir & "\System32\it-IT\ieframe.dll.mui") Then $WinLang = "it-IT"
	If FileExists(@WindowsDir & "\System32\ja-JP\ieframe.dll.mui") Then $WinLang = "ja-JP"
	If FileExists(@WindowsDir & "\System32\ko-KR\ieframe.dll.mui") Then $WinLang = "ko-KR"
	If FileExists(@WindowsDir & "\System32\lt-LT\ieframe.dll.mui") Then $WinLang = "lt-LT"
	If FileExists(@WindowsDir & "\System32\lv-LV\ieframe.dll.mui") Then $WinLang = "lv-LV"
	If FileExists(@WindowsDir & "\System32\nb-NO\ieframe.dll.mui") Then $WinLang = "nb-NO"
	If FileExists(@WindowsDir & "\System32\nl-NL\ieframe.dll.mui") Then $WinLang = "nl-NL"
	If FileExists(@WindowsDir & "\System32\pl-PL\ieframe.dll.mui") Then $WinLang = "pl-PL"
	If FileExists(@WindowsDir & "\System32\pt-BR\ieframe.dll.mui") Then $WinLang = "pt-BR"
	If FileExists(@WindowsDir & "\System32\pt-PT\ieframe.dll.mui") Then $WinLang = "pt-PT"
	If FileExists(@WindowsDir & "\System32\ro-RO\ieframe.dll.mui") Then $WinLang = "ro-RO"
	If FileExists(@WindowsDir & "\System32\ru-RU\ieframe.dll.mui") Then $WinLang = "ru-RU"
	If FileExists(@WindowsDir & "\System32\sk-SK\ieframe.dll.mui") Then $WinLang = "sk-SK"
	If FileExists(@WindowsDir & "\System32\sl-SI\ieframe.dll.mui") Then $WinLang = "sl-SI"
	If FileExists(@WindowsDir & "\System32\sr-Latn-CS\ieframe.dll.mui") Then $WinLang = "sr-Latn-CS"
	If FileExists(@WindowsDir & "\System32\sv-SE\ieframe.dll.mui") Then $WinLang = "sv-SE"
	If FileExists(@WindowsDir & "\System32\th-TH\ieframe.dll.mui") Then $WinLang = "th-TH"
	If FileExists(@WindowsDir & "\System32\tr-TR\ieframe.dll.mui") Then $WinLang = "tr-TR"
	If FileExists(@WindowsDir & "\System32\uk-UA\ieframe.dll.mui") Then $WinLang = "uk-UA"
	If FileExists(@WindowsDir & "\System32\zh-CN\ieframe.dll.mui") Then $WinLang = "zh-CN"
	If FileExists(@WindowsDir & "\System32\zh-HK\ieframe.dll.mui") Then $WinLang = "zh-HK"
	If FileExists(@WindowsDir & "\System32\zh-TW\ieframe.dll.mui") Then $WinLang = "zh-TW"
EndFunc   ;==> _WinLang
;===================================================================================================
