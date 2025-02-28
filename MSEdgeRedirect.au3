#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Assets\MSEdgeRedirect.ico
#AutoIt3Wrapper_Outfile=MSEdgeRedirect_x86.exe
#AutoIt3Wrapper_Outfile_x64=MSEdgeRedirect.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=https://www.msedgeredirect.com
#AutoIt3Wrapper_Res_Description=A Tool to Redirect News, Search, Widgets, Weather and More to Your Default Browser
#AutoIt3Wrapper_Res_Fileversion=0.6.0.0
#AutoIt3Wrapper_Res_ProductName=MSEdgeRedirect
#AutoIt3Wrapper_Res_ProductVersion=0.6.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Robert Maehl, using LGPL 3 License
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_Compatibility=Win8,Win81,Win10
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7 -v1 -v2 -v3
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/so
#AutoIt3Wrapper_Res_Icon_Add=Assets\MSEdgeRedirect.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Date.au3>
#include <Misc.au3>
#include <Array.au3>
#include <WinAPIHObj.au3>
#include <WinAPIProc.au3>
#include <WinAPIShPath.au3>
#include <EditConstants.au3>
#include <TrayConstants.au3>
#include <ComboConstants.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>

#include "Includes\_Logging.au3"
#include "Includes\_Theming.au3"
#include "Includes\_Settings.au3"
#include "Includes\_Translation.au3"

#include "Includes\ResourcesEx.au3"

Opt("TrayMenuMode", 3)
Opt("TrayAutoPause", 0)
Opt("GUICloseOnESC", 0)

#include "MSEdgeRedirect_Wrapper.au3"

SetupAppdata()
ProcessCMDLine()

Func ActiveMode(ByRef $aCMDLine)

	Local $sCMDLine = ""

	Select
		Case $aCMDLine[0] = 1 ; No Parameters
			ReDim $aCMDLine[3]
			$aCMDLine[2] = ""
			ContinueCase
		Case $aCMDLine[0] = 2 And $aCMDLine[2] = "--inprivate" ; In Private Browsing, No Parameters
			If FileGetVersion($aCMDLine[1]) <> FileGetVersion(StringReplace($aCMDLine[1], "msedge.exe", "msedge_no_ifeo.exe")) Then
				If MsgBox($MB_YESNO + $MB_ICONINFORMATION + $MB_TOPMOST, _
					_Translate($aMUI[1], "File Update Required"), _
					_Translate($aMUI[1], "The Microsoft Edge IFEO exclusion file is out of date and needs to be updated to use Edge. Update Now?"), _
					10) = $IDYES Then ShellExecuteWait(@ScriptFullPath, "/repair", @ScriptDir, "RunAs")
				If @error Then MsgBox($MB_ICONERROR+$MB_OK, _
					"Repair Failed", _
					"Unable to update Microsoft Edge IFEO exclusion file without Admin Rights!")
			EndIf
			$aCMDLine[1] = StringReplace($aCMDLine[1], "msedge.exe", "msedge_no_ifeo.exe")
			ShellExecute($aCMDLine[1], $aCMDLine[2])
		Case Else
			For $iLoop = 2 To $aCMDLine[0]
				$sCMDLine &= $aCMDLine[$iLoop] & " "
			Next
			_DecodeAndRun($sCMDLine)
	EndSelect

EndFunc

Func ProcessCMDLine()

	Local $aPIDs
	Local $bHide = _GetSettingValue("NoTray")
	Local $hFile = @ScriptDir & ".\Setup.ini"
	Local $iParams = $CmdLine[0]
	Local $bSilent = False
	Local $aInstall[3]
	Local $bPortable = False

	If DriveGetType(@ScriptDir) = "Removable" Then $bPortable = True

	If $iParams > 0 Then

		;_ArrayDisplay($CmdLine)
		If _ArraySearch($aEdges, $CmdLine[1]) > 0 Then ; Image File Execution Options Mode
			ActiveMode($CmdLine)
			If Not _GetSettingValue("NoUpdates") And Random(1, 10, 1) = 1 Then RunUpdateCheck()
			Exit
		EndIf

		Do
			Switch $CmdLine[1]
				Case "/?", "/help"
					MsgBox(0, "Help and Flags", _
							"MSEdgeRedirect [/hide]" & @CRLF & _
							@CRLF & _
							@TAB & "/hide  " & @TAB & "Hides the tray icon" & @CRLF & _
							@TAB & "/update" & @TAB & "Downloads the latest RELEASE (default) or DEV build" & @CRLF & _
							@CRLF & _
							@CRLF)
					Exit 0
				Case "/change"
					RunSetup(True, $bSilent, 1)
					Exit
				Case "/h", "/hide"
					$bHide = True
					_ArrayDelete($CmdLine, 1)
				Case "/p", "/portable"
					$bPortable = True
					_ArrayDelete($CmdLine, 1)
				Case "/repair"
					RunRepair()
					Exit
				Case "/settings"
					RunSetup(True, False, 2)
					Exit
				Case "/si", "/silentinstall"
					$bSilent = True
					Select
						Case UBound($CmdLine) = 2
							_ArrayDelete($CmdLine, 1)
						Case UBound($CmdLine) > 2 And FileExists($CmdLine[2])
							$hFile = $CmdLine[2]
							_ArrayDelete($CmdLine, "1-2")
						Case StringLeft($CmdLine[2], 1) = "/"
							_ArrayDelete($CmdLine, 1)
						Case Else
							MsgBox(0, _
								"Invalid", _
								'Invalid file - "' & $CmdLine[2] & @CRLF)
							Exit 87 ; ERROR_INVALID_PARAMETER
					EndSelect
				Case "/u", "/update"
					Select
						Case UBound($CmdLine) = 2
							InetGet("https://fcofix.org/MSEdgeRedirect/releases/latest/download/MSEdgeRedirect.exe", @ScriptDir & "\MSEdgeRedirect_Latest.exe")
							_ArrayDelete($CmdLine, 1)
						Case UBound($CmdLine) > 2 And $CmdLine[2] = "dev"
							InetGet("https://nightly.link/rcmaehl/MSEdgeRedirect/workflows/mser/main/mser.zip", @ScriptDir & "\WhyNotWin11_dev.zip")
							_ArrayDelete($CmdLine, "1-2")
						Case UBound($CmdLine) > 2 And $CmdLine[2] = "release"
							InetGet("https://fcofix.org/MSEdgeRedirect/releases/latest/download/MSEdgeRedirect.exe", @ScriptDir & "\MSEdgeRedirect_Latest.exe")
							_ArrayDelete($CmdLine, "1-2")
						Case StringLeft($CmdLine[2], 1) = "/"
							InetGet("https://fcofix.org/MSEdgeRedirect/releases/latest/download/MSEdgeRedirect.exe", @ScriptDir & "\MSEdgeRedirect_Latest.exe")
							_ArrayDelete($CmdLine, 1)
						Case Else
							MsgBox(0, _
								"Invalid", _
								'Invalid release type - "' & $CmdLine[2] & "." & @CRLF)
							Exit 87 ; ERROR_INVALID_PARAMETER
					EndSelect
				Case "/uninstall"
					RunRemoval()
					Exit
				Case Else
					If @Compiled Then ; support for running non-compiled script - mLipok
						MsgBox(0, _
							"Invalid", _
							'Invalid parameter - "' & $CmdLine[1] & "." & @CRLF)
						Exit 87 ; ERROR_INVALID_PARAMETER
					EndIf
			EndSwitch
		Until UBound($CmdLine) <= 1
	Else
		;;;
	EndIf

	RunArchCheck($bSilent)
	RunHTTPCheck($bSilent)

	If Not $bPortable Then
		$aInstall = _IsInstalled()

		Select
			Case Not $aInstall[0] ; Not Installed
				RunSetup(False, $bSilent, 0, $hFile)
			Case _VersionCompare($sVersion, $aInstall[2]) ; Installed, Out of Date
				RunSetup($aInstall[1], $bSilent, 0, $hFile)
			Case StringInStr($aInstall[1], "HKCU") ; Installed, Up to Date, Service Mode
				If @ScriptDir <> @LocalAppDataDir & "\MSEdgeRedirect" Then
					RunSetup($aInstall[1], $bSilent, 0, $hFile)
					;ShellExecute(@LocalAppDataDir & "\MSEdgeRedirect\MSEdgeRedirect.exe", "", @LocalAppDataDir & "\MSEdgeRedirect\")
				Else
					$aPIDs = ProcessList(@ScriptName)
					For $iLoop = 1 To $aPIDs[0][0] Step 1
						If $aPIDs[$iLoop][1] <> @AutoItPID Then
							$bHide = False
							ProcessClose($aPIDs[$iLoop][1])
						EndIf
					Next
				EndIf
			Case Else
				RunSetup(True, $bSilent, 0, $hFile)
		EndSelect
	EndIf
	ReactiveMode($bHide)

EndFunc

Func ReactiveMode($bHide = False)

	Local $hTimer = TimerInit()
	Local $aAdjust

	Local $hMsg

	; Enable "SeDebugPrivilege" privilege for obtain full access rights to another processes
	Local $hToken = _WinAPI_OpenProcessToken(BitOR($TOKEN_ADJUST_PRIVILEGES, $TOKEN_QUERY))

	_WinAPI_AdjustTokenPrivileges($hToken, $SE_DEBUG_NAME, $SE_PRIVILEGE_ENABLED, $aAdjust)

	TrayCreateItem($sVersion)
	TrayItemSetState(-1, $TRAY_DISABLE)
	TrayCreateItem("")
	Local $hStartup = TrayCreateItem("Start With Windows")
	Local $hUpdate = TrayCreateItem("Check for Updates")
	TrayCreateItem("")
	Local $hDonate = TrayCreateItem("Donate")
	TrayCreateItem("")
	Local $hHide = TrayCreateItem("Hide Icon")
	Local $hExit = TrayCreateItem("Exit")

	If $bHide Then TraySetState($TRAY_ICONSTATE_HIDE)

	If FileExists(@StartupDir & "\MSEdgeRedirect.lnk") Then TrayItemSetState($hStartup, $TRAY_CHECKED)


	Local $aProcessList
	Local $sCommandline

	While True
		$hMsg = TrayGetMsg()

		If TimerDiff($hTimer) >= 100 Then
			$aProcessList = ProcessList("msedge.exe")
			For $iLoop = 1 To $aProcessList[0][0] - 1
				$sCommandline = _WinAPI_GetProcessCommandLine($aProcessList[$iLoop][1])
				If StringRegExp($sCommandline, ".*(microsoft\-edge|app\-id).*") Then
					ProcessClose($aProcessList[$iLoop][1])
					If _ArraySearch($aEdges, _WinAPI_GetProcessFileName($aProcessList[$iLoop][1]), 1, $aEdges[0]) > 0 Then
						_DecodeAndRun($sCommandline)
					EndIf
				EndIf
			Next
			$hTimer = TimerInit()
		EndIf

		Select

			Case $hMsg = $hHide
				TraySetState($TRAY_ICONSTATE_HIDE)

			Case $hMsg = $hExit
				ExitLoop

			Case $hMsg = $hDonate
				ShellExecute("https://paypal.me/rhsky")

			Case $hMsg = $hUpdate
				RunUpdateCheck(True)

			Case $hMsg = $hStartup
				If Not FileExists(@StartupDir & "\MSEdgeRedirect.lnk") Then
					FileCreateShortcut(@AutoItExe, @StartupDir & "\MSEdgeRedirect.lnk", @ScriptDir)
					TrayItemSetState($hStartup, $TRAY_CHECKED)
				ElseIf FileExists(@StartupDir & "\MSEdgeRedirect.lnk") Then
					FileDelete(@StartupDir & "\MSEdgeRedirect.lnk")
					TrayItemSetState($hStartup, $TRAY_UNCHECKED)
				EndIf

			Case Else

		EndSelect
	WEnd

	_WinAPI_AdjustTokenPrivileges($hToken, $aAdjust, 0, $aAdjust)
	_WinAPI_CloseHandle($hToken)
	For $iLoop = 0 To UBound($hLogs) - 1
		FileClose($hLogs[$iLoop])
	Next
	Exit

EndFunc

Func RunArchCheck($bSilent = False)
	If @Compiled And Not $bIs64Bit Then
		If Not $bSilent Then
			MsgBox($MB_ICONERROR+$MB_OK, _
				"Wrong Version", _
				"The 64-bit Version of MSEdgeRedirect must be used with 64-bit Windows!")
		EndIf
		FileWrite($hLogs[$AppFailures], _NowCalc() & " - " & "32 Bit Version on 64 Bit System. EXITING!" & @CRLF)
		For $iLoop = 0 To UBound($hLogs) - 1
			FileClose($hLogs[$iLoop])
		Next
		Exit 216 ; ERROR_EXE_MACHINE_TYPE_MISMATCH
	EndIf
EndFunc

Func RunHTTPCheck($bSilent = False)

	Local $sHive = ""

	If $bIs64Bit Then
		$sHive = "HKCU64"
	Else
		$sHive = "HKCU"
	EndIf

	Local $aDefaults[3]
	Local Enum $hHTTP, $hHTTPS, $hMSEdge

	$aDefaults[$hHTTP] = RegRead($sHive & "\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice", "ProgId")
	$aDefaults[$hHTTPS] = RegRead($sHive & "\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice", "ProgId")
	$aDefaults[$hMSEdge] = RegRead($sHive & "\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\microsoft-edge\UserChoice", "ProgId")

	If StringInStr($aDefaults[$hMSEdge], "MSEdge") Then
		If $aDefaults[$hHTTP] = $aDefaults[$hMSEdge] Or $aDefaults[$hHTTPS] = $aDefaults[$hMSEdge] Then
			If Not $bSilent Then
				MsgBox($MB_ICONERROR+$MB_OK, _
					"Edge Set As Default", _
					"You must set a different Default Browser to use MSEdgeRedirect!")
			EndIf
			FileWrite($hLogs[$AppFailures], _NowCalc() & " - " & "Found same MS Edge for both default browser and microsoft-edge handling, EXITING!" & @CRLF)
			For $iLoop = 0 To UBound($hLogs) - 1
				FileClose($hLogs[$iLoop])
			Next
			Exit 4315 ; ERROR_MEDIA_INCOMPATIBLE
		EndIf
	EndIf

EndFunc

Func _ChangeSearchEngine($sURL)

	If StringInStr($sURL, "bing.com/search?q=") Then
		$sURL = StringRegExpReplace($sURL, "(.*)(q=)", "")

		Switch _GetSettingValue("Search")

			Case "Ask"
				$sURL = "https://www.ask.com/web?q=" & $sURL

			Case "Baidu"
				$sURL = "https://www.baidu.com/s?wd=" & $sURL

			Case "Custom"
				$sURL = _GetSettingValue("SearchPath") & $sURL

			Case "DuckDuckGo"
				$sURL = "https://duckduckgo.com/?q=" & $sURL

			Case "Ecosia"
				$sURL = "https://www.ecosia.org/search?q=" & $sURL

			Case "Google"
				$sURL = "https://www.google.com/search?q=" & $sURL

			Case "Sogou"
				$sURL = "https://www.sogou.com/web?query=" & $sURL

			Case "Yahoo"
				$sURL = "https://search.yahoo.com/search?p=" & $sURL

			Case "Yandex"
				$sURL = "https://yandex.com/search/?text=" & $sURL

			Case Null
				$sURL = "https://bing.com/search?q=" & $sURL

			Case Else
				$sURL = _GetSettingValue("SearchPath") & $sURL

		EndSwitch
	EndIf

	Return $sURL

EndFunc

Func _ChangeWeatherProvider($sURL)

	;https://a.msn.com/54/en-us/ct<LATITUDE>,<LONGITUDE>?weadegreetype=F&weaext0={%22l%22:%22<CITY>%22,%22r%22:%22<STATE>%22,%22c%22:%22<COUNTRY>...

	Local $fLat
	Local $fLong
	Local $sSign
	Local $sLocale
	Local $vCoords

	#forceref $sLocale

	If StringInStr($sURL, "weadegreetype") Then
		$vCoords = StringRegExpReplace($sURL, "(.*)(\/ct)", "")
		$vCoords = StringRegExpReplace($vCoords, "(?=\?weadegreetype=)(.*)", "")
		$vCoords = StringSplit($vCoords, ",")
		If $vCoords[0] = 2 Then
			$fLat = $vCoords[1]
			$fLong = $vCoords[2]
			$sSign = StringRegExpReplace($sURL, "(.*)(weadegreetype=)", "")
			$sSign = StringRegExpReplace($sSign, "(?=&weaext0=)(.*)", "")
			Switch _GetSettingValue("Weather")

				Case "Weather.com"
					$sURL = "https://www.weather.com/wx/today/?lat=" & $fLat & "&lon=" & $fLong & "&temp=" & $sSign ;"&locale=" & <LOCALE>

				Case "Weather.gov"
					$sURL = "https://forecast.weather.gov/MapClick.php?lat=" & $fLat & "&lon=" & $fLong

				Case Null
					;;;

				Case Else
					$sURL = _GetSettingValue("WeatherPath") & $sURL

			EndSwitch
		Else

		EndIf
	EndIf

	Return $sURL


EndFunc

Func _DecodeAndRun($sCMDLine)

	Local $sCaller
	Local $aLaunchContext

	Select
		Case StringInStr($sCMDLine, "--default-search-provider=?")
			FileWrite($hLogs[$URIFailures], _NowCalc() & " - Skipped Settings URL: " & $sCMDLine & @CRLF)
		Case StringInStr($sCMDLine, ".pdf") And _GetSettingValue("NoPDFs")
			$sCMDLine = StringReplace($sCMDLine, "--single-argument ", "")
			ShellExecute(_GetSettingValue("PDFApp"), '"' & $sCMDLine & '"')
		Case StringInStr($sCMDLine, "--app-id") And _GetSettingValue("NoApps") ; TikTok and other Apps
			$sCMDLine = StringRegExpReplace($sCMDLine, "(.*)(--app-fallback-url=)", "")
			$sCMDLine = StringRegExpReplace($sCMDLine, "(?= --)(.*)", "")
			If _IsSafeURL($sCMDLine) Then
				ShellExecute($sCMDLine)
			Else
				FileWrite($hLogs[$URIFailures], _NowCalc() & " - Invalid App URL: " & $sCMDLine & @CRLF)
			EndIf
		Case StringInStr($sCMDLine, "Windows.Widgets")
			$sCaller = "Windows.Widgets"
			ContinueCase
		Case StringRegExp($sCMDLine, "microsoft-edge:[\/]*?\?launchContext1")
			$aLaunchContext = StringSplit($sCMDLine, "=")
			If $aLaunchContext[0] >= 3 Then
				If $sCaller = "" Then $sCaller = $aLaunchContext[2]
				FileWrite($hLogs[$AppGeneral], _NowCalc() & " - Redirected Edge Call from: " & $sCaller & @CRLF)
				$sCMDLine = _UnicodeURLDecode($aLaunchContext[$aLaunchContext[0]])
				If _IsSafeURL($sCMDLine) Then
					$sCMDLine = _ModifyURL($sCMDLine)
					ShellExecute($sCMDLine)
				Else
					FileWrite($hLogs[$URIFailures], _NowCalc() & " - Invalid Regexed URL: " & $sCMDLine & @CRLF)
				EndIf
			Else
				FileWrite($hLogs[$URIFailures], _NowCalc() & " - Command Line Missing Needed Parameters: " & $sCMDLine & @CRLF)
			EndIf
		Case Else
			$sCMDLine = StringRegExpReplace($sCMDLine, "(.*) microsoft-edge:[\/]*", "")
			If _IsSafeURL($sCMDLine) Then
				$sCMDLine = _ModifyURL($sCMDLine)
				ShellExecute($sCMDLine)
			Else
				FileWrite($hLogs[$URIFailures], _NowCalc() & " - Invalid URL: " & $sCMDLine & @CRLF)
			EndIf
	EndSelect
EndFunc

Func _GetDefaultBrowser()

	Local $sProg
	Local $sHive1
	Local $sHive2

	Local Static $sBrowser

	If $sBrowser <> "" Then
		;;;
	Else
		If $bIs64Bit Then
			$sHive1 = "HKCU64"
			$sHive2 = "HKCR64"
		Else
			$sHive1 = "HKCU"
			$sHive2 = "HKCR"
		EndIf
		$sProg = RegRead($sHive1 & "\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice", "ProgID")
		$sBrowser = RegRead($sHive2 & "\" & $sProg & "\shell\open\command", "")
		$sBrowser = StringReplace($sBrowser, "%1", "")
	EndIf

	Return $sBrowser

EndFunc

Func _IsSafeURL($sURL)

	Local $aURL
	Local $bSafe = False

	$aURL = StringSplit($sURL, ":")
	If $aURL[0] < 2 Then
		ReDim $aURL[3]
		$aURL[2] = $aURL[1]
		$aURL[1] = "https"
		$sURL = "https://" & $sURL
	EndIf

	Select
		Case $aURL[1] <> "http" And $aURL[1] <> "https"
			ContinueCase
		Case _WinAPI_UrlIs($sURL, $URLIS_FILEURL)
			ContinueCase
		Case _WinAPI_UrlIs($sURL, $URLIS_OPAQUE)
			$bSafe = False
		Case _WinAPI_UrlIs($sURL, $URLIS_URL)
			$bSafe = True
		Case Else
			;;;
	EndSelect

	If Not $bSafe Then FileWrite($hLogs[$AppSecurity], _NowCalc() & " - " & "Blocked Unsafe URL: " & $sURL & @CRLF)

	Return $bSafe

EndFunc

Func _ModifyURL($sURL)

	If _GetSettingValue("NoBing") Then $sURL = _ChangeSearchEngine($sURL)
	If _GetSettingValue("NoMSN") Then $sURL = _ChangeWeatherProvider($sURL)

	Return $sURL

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _UnicodeURLDecode
; Description ...: Tranlates a URL-friendly string to a normal string
; Syntax ........: _UnicodeURLDecode($toDecode)
; Parameters ....: $$toDecode           - The URL-friendly string to decode
; Return values .: The URL decoded string
; Author ........: nfwu, Dhilip89, rcmaehl
; Modified ......: 12/19/2021
; Remarks .......: Modified from _URLDecode() that only supported non-unicode.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _UnicodeURLDecode($toDecode)
    Local $strChar = "", $iOne, $iTwo
    Local $aryHex = StringSplit($toDecode, "")
    For $i = 1 To $aryHex[0]
        If $aryHex[$i] = "%" Then
            $i += 1
            $iOne = $aryHex[$i]
            $i += 1
            $iTwo = $aryHex[$i]
            $strChar = $strChar & Chr(Dec($iOne & $iTwo))
        Else
            $strChar = $strChar & $aryHex[$i]
        EndIf
    Next
    Local $Process = StringToBinary(StringReplace($strChar, "+", " "))
    Local $DecodedString = BinaryToString($Process, 4)
    Return $DecodedString
EndFunc   ;==>_UnicodeURLDecode
