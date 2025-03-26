Dim shell, fso, tempDir, profilePath, dropboxUrl, zipFile, extractPath, fullExtractPath, logFile

' Initialize objects
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Expand environment variables
tempDir = shell.ExpandEnvironmentStrings("%TEMP%")
profilePath = shell.ExpandEnvironmentStrings("%USERPROFILE%")

' Set paths (updated to match your Dropbox structure)
dropboxUrl = "https://dl.dropboxusercontent.com/scl/fi/wc1vinjy551t0k5wai922/shopgoodwill.zip?rlkey=7y337s7mv7r07j0ckl4om6bq1&st=enagqzb3&dl=0"
zipFile = tempDir & "\shopgoodwill.zip"
extractPath = profilePath
fullExtractPath = profilePath & "\Bid_Sniper" ' Matches C:\Users\GTA-m\Bid_Sniper
logFile = tempDir & "\download_extract_log.txt"

' Delete log file if it exists
If fso.FileExists(logFile) Then fso.DeleteFile logFile, True

' Check if running as admin
Function IsAdmin()
    Dim adminStatus
    adminStatus = shell.Run("net session", 0, True)
    IsAdmin = (adminStatus = 0)
End Function

Sub ElevateIfNotAdmin()
    If Not IsAdmin() Then
        CreateObject("Shell.Application").ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 1
        WScript.Quit
    End If
End Sub

Call ElevateIfNotAdmin()

Sub DisplayMessage(message)
    MsgBox message
End Sub

' Check for errors in log file
Function CheckForErrors()
    If fso.FileExists(logFile) Then
        Dim logFileContent, logContent
        Set logFileContent = fso.OpenTextFile(logFile, 1, False)
        If Not logFileContent.AtEndOfStream Then
            logContent = logFileContent.ReadAll
        Else
            logContent = "Log file empty."
        End If
        logFileContent.Close
        CheckForErrors = (InStr(logContent, "Exception") > 0 Or InStr(logContent, "Error") > 0)
    Else
        CheckForErrors = True
    End If
End Function

Sub KillRunningAppProcesses()
    Dim objWMIService, colProcesses, objProcess, exePath
    On Error Resume Next
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    If Err.Number <> 0 Then
        MsgBox "WMI fucked up. Run as admin, asshole.", vbCritical
        Exit Sub
    End If
    Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process")
    For Each objProcess In colProcesses
        exePath = ""
        On Error Resume Next
        exePath = objProcess.ExecutablePath
        On Error GoTo 0
        If Not IsNull(exePath) And exePath <> "" Then
            If InStr(LCase(exePath), "\bid_sniper\") > 0 Then
                objProcess.Terminate
            End If
        End If
    Next
    Set colProcesses = Nothing
    Set objWMIService = Nothing
    On Error GoTo 0
End Sub

Sub DownloadAndExtract()
    Dim downloadAndExtractScript, psCommand
    Dim safeZipFile, safeExtractPath, safeFullExtractPath, safeLogFile
    safeZipFile = Replace(zipFile, "'", "''")
    safeExtractPath = Replace(extractPath, "'", "''")
    safeFullExtractPath = Replace(fullExtractPath, "'", "''")
    safeLogFile = Replace(logFile, "'", "''")
    
    downloadAndExtractScript = _
        "param($url, $zipFile, $extractPath, $fullExtractPath)" & vbCrLf & _
        "$ErrorActionPreference = 'Stop'" & vbCrLf & _
        "Write-Host 'Using paths:'" & vbCrLf & _
        "Write-Host 'Zip: ' $zipFile" & vbCrLf & _
        "Write-Host 'Extract: ' $extractPath" & vbCrLf & _
        "Write-Host 'Full: ' $fullExtractPath" & vbCrLf & _
        "try {" & vbCrLf & _
        "    if (Test-Path -Path $zipFile) { Remove-Item -Path $zipFile -Force }" & vbCrLf & _
        "    if (Test-Path -Path $fullExtractPath) { Remove-Item -Path $fullExtractPath -Recurse -Force }" & vbCrLf & _
        "    Write-Host 'Downloading...'" & vbCrLf & _
        "    Start-BitsTransfer -Source $url -Destination $zipFile" & vbCrLf & _
        "    Write-Host 'Extracting...'" & vbCrLf & _
        "    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force" & vbCrLf & _
        "    Write-Host 'Setting firewall...'" & vbCrLf & _
        "    New-NetFirewallRule -DisplayName 'Allow SniperKing' -Direction Inbound -Program (Join-Path $fullExtractPath 'node_modules\electron\dist\electron.exe') -Action Allow -Profile Any" & vbCrLf & _
        "} catch {" & vbCrLf & _
        "    Write-Host 'Error: ' $_.Exception.Message" & vbCrLf & _
        "    exit 1" & vbCrLf & _
        "}"

    psCommand = "powershell -NoProfile -ExecutionPolicy Bypass -Command " & _
                """& {" & downloadAndExtractScript & "} " & _
                "-url '" & dropboxUrl & "' " & _
                "-zipFile '" & safeZipFile & "' " & _
                "-extractPath '" & safeExtractPath & "' " & _
                "-fullExtractPath '" & safeFullExtractPath & "' " & _
                "| Out-File -FilePath '" & safeLogFile & "' -Encoding utf8; if ($LASTEXITCODE -ne 0) { exit 1 }"""
    
    shell.Run psCommand, 1, True
End Sub

Function ReadLogFile()
    If fso.FileExists(logFile) Then
        Dim logFileContent, logContent
        On Error Resume Next
        Set logFileContent = fso.OpenTextFile(logFile, 1, False)
        If Not logFileContent.AtEndOfStream Then
            logContent = logFileContent.ReadAll
        Else
            logContent = "Log file’s empty, dipshit."
        End If
        logFileContent.Close
        On Error GoTo 0
        ReadLogFile = logContent
    Else
        ReadLogFile = "Log file’s missing, you fucked something up."
    End If
End Function

Function InstallationSuccessful()
    InstallationSuccessful = fso.FileExists(fullExtractPath & "\node.exe")
End Function

Sub CreateLaunchScript()
    Dim launchScriptPath, launchScript
    launchScriptPath = fullExtractPath & "\LaunchSniperKing.vbs"
    Set launchScript = fso.CreateTextFile(launchScriptPath, True)
    launchScript.WriteLine "Set WshShell = CreateObject(""WScript.Shell"")"
    launchScript.WriteLine "WshShell.Run ""cmd /c cd /d """"" & fullExtractPath & """"" && set NODE_ENV=production && """"" & fullExtractPath & "\node.exe"""" """"" & fullExtractPath & "\node_modules\electron\cli.js"""" """"" & fullExtractPath & """"""", 0, False"
    launchScript.Close
End Sub

Sub CreateDesktopShortcut()
    Dim shortcutPath, shortcut, iconPath
    shortcutPath = shell.SpecialFolders("Desktop") & "\SniperKing.lnk"
    iconPath = fullExtractPath & "\img\icons\win\icon.ico"
    If fso.FileExists(shortcutPath) Then fso.DeleteFile shortcutPath, True
    Set shortcut = shell.CreateShortcut(shortcutPath)
    With shortcut
        .TargetPath = fullExtractPath & "\LaunchSniperKing.vbs"
        .WorkingDirectory = fullExtractPath
        .Arguments = ""
        .IconLocation = iconPath
        .Save
    End With
End Sub

Call KillRunningAppProcesses()

' Main execution
DisplayMessage "This’ll download and install SniperKing to " & fullExtractPath & " and slap a shortcut on your desktop. PowerShell’s gonna flicker—don’t piss yourself."
Call DownloadAndExtract()

Dim logContent
logContent = ReadLogFile()

If Not CheckForErrors() And InstallationSuccessful() Then
    Call CreateLaunchScript()
    Call CreateDesktopShortcut()
    DisplayMessage "SniperKing’s ready, fucker. Launch it from the desktop."
Else
    DisplayMessage "Shit broke during install: " & vbCrLf & logContent
End If
