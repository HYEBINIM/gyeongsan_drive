@echo off
REM PyInstaller 빌드 스크립트 - MySQL 연결 문제 해결

echo ========================================
echo Flask 서버 빌드 시작
echo ========================================

REM PyInstaller로 빌드 (MySQL 관련 hidden imports 포함)
pyinstaller -F ^
    --hidden-import=pymysql ^
    --hidden-import=pymysql.cursors ^
    --name app_server ^
    app.py

echo.
echo ========================================
echo 빌드 완료!
echo 실행 파일: dist\app_server.exe
echo ========================================

pause
