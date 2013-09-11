@ECHO OFF

:: Use WMIC to retrieve date and time. WMIC is used to get around installaion specific date format
FOR /F "skip=1 tokens=1-6" %%G IN ('WMIC Path Win32_LocalTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table') DO (
   IF "%%~L"=="" goto s_done
      Set _yyyy=%%L
      Set _mm=00%%J
      Set _dd=00%%G
      Set _hour=00%%H
      SET _minute=00%%I
)
:s_done

:: Pad digits with leading zeros
      Set _mm=%_mm:~-2%
      Set _dd=%_dd:~-2%
      Set _hour=%_hour:~-2%
      Set _minute=%_minute:~-2%

set backuptime=%_dd%-%_mm%-%_yyyy%_%_hour%%_minute%

:: User name for DB - NOTE that root credentials are needed for this script.
set dbuser=root

:: User password - NOTE that the root credentials are needed for this script.
set dbpass=password

:: Path to location where you would like to save the errors log file. For simplicity, I keep mine in the same location as the backups.
set errorLogPath="\\EDDIE\Backups\XBMC\dumperrors.txt"

:: We need to switch to the data directory to enumerate the folders
pushd "C:\ProgramData\MySQL\MySQL Server 5.5\data"

:: We will dump each database to it's own .sql so you can easily restore ONLY what is needed in the future. We're also going to skip the performance_schema db as it is not necessary.
FOR /D %%F IN (*) DO (
IF NOT [%%F]==[performance_schema] (
SET %%F=!%%F:@002d=-!
"C:\Program Files\MySQL\MySQL Server 5.5\bin\mysqldump.exe" --user=%dbuser% --password=%dbpass% --databases --routines --events --log-error=%errorLogPath%  %%F > "\\EDDIE\Backups\XBMC\%%F.%backuptime%.sql"
) ELSE (
echo Skipping DB backup for performance_schema
)
)
popd

::Now to zip all of the .sql files in this folder and move the resulting .zip files to our network location.
"c:\XBMCSQLBACKUP\zip\7za.exe" a -tzip "\\EDDIE\Backups\XBMC\FullBackup.%backuptime%.zip" "\\EDDIE\Backups\XBMC\*.sql"

::Now we'll delete the unzipped .sql files
del "\\EDDIE\Backups\XBMC\*.sql"

::Now we'll delete all zip files older than 30 days. You can adjust the number of days to suit your needs, simply change the -30 to whatever number of days you prefer. Be sure you enter the path to your backup location.
PushD "\\EDDIE\Backups\XBMC\" &&(
    forfiles -s -m *.* -d -30 -c "cmd /c del /q @path" 
     ) & PopD



