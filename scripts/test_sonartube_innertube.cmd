@echo off
setlocal EnableExtensions

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERRORE: flutter non e' nel PATH.
  exit /b 1
)

echo.
echo === Test SonarTube deterministici: Dart diretto + fallback ===
call flutter test test\sonartube_service_test.dart -r expanded
if errorlevel 1 exit /b 1

echo.
echo === Test contratto video TV fullscreen ===
call flutter test test\radio_player_landscape_video_surface_contract_test.dart -r expanded
if errorlevel 1 exit /b 1

if /I not "%~1"=="live" goto :done

echo.
echo === Test LIVE InnerTube diretto ===
echo Il fallback e' volutamente puntato a localhost:9: se questi test passano,
echo ricerca e navigazione stanno realmente usando InnerTube da Dart.
call flutter test test\sonartube_innertube_live_test.dart --dart-define=RUN_LIVE_SONARTUBE_TESTS=true -r expanded
if errorlevel 1 exit /b 1

:done
echo.
echo Tutti i test richiesti sono terminati correttamente.
exit /b 0
