@echo off
setlocal

cd /d C:\rustnotepad\sonarpad_mobile_starter
set "LOG=%USERPROFILE%\Documents\document_text_extractor_encoding_test_loop.log"
set /a RUN=0

echo Writing log to "%LOG%"
echo Press Ctrl+C to stop the loop.

:loop
set /a RUN+=1
echo.
echo ===== Run %RUN% - %DATE% %TIME% =====
echo ===== Run %RUN% - %DATE% %TIME% =====>>"%LOG%"

flutter test test\document_text_extractor_encoding_test.dart >>"%LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"

echo Exit code: %RESULT%
echo Exit code: %RESULT%>>"%LOG%"

if "%RESULT%"=="0" goto passed

echo Test failed. Retrying in 2 seconds...
echo Test failed. Retrying in 2 seconds...>>"%LOG%"
timeout /t 2 /nobreak >nul
goto loop

:passed
echo.
echo Test passed after %RUN% run(s).
echo Test passed after %RUN% run(s).>>"%LOG%"
endlocal
