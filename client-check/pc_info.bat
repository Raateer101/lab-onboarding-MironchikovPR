@echo off
chcp 65001 >nul

REM =========================================================
REM Тема: Инструментальные средства ревьюирования, проверки на стороне клиента.
REM Автор: Мирончиков
REM Дата: 31.10.2026
REM =========================================================

set "report_file=%~dp0pc_report.txt"

echo =========================================
echo       ДИАГНОСТИКА КОМПЬЮТЕРА
echo =========================================
echo.

echo ========================================= > "%report_file%"
echo       ДИАГНОСТИКА КОМПЬЮТЕРА >> "%report_file%"
echo ========================================= >> "%report_file%"
echo. >> "%report_file%"

REM --- Сведения об операционной системе ---
echo [Операционная система]
echo [Операционная система] >> "%report_file%"
for /f "tokens=2 delims==" %%i in ('wmic os get Caption /format:list 2^>nul') do (
    echo Название: %%i
    echo Название: %%i >> "%report_file%"
)
for /f "tokens=2 delims==" %%i in ('wmic os get Version /format:list 2^>nul') do (
    echo Версия:   %%i
    echo Версия:   %%i >> "%report_file%"
)
echo.
echo. >> "%report_file%"

REM --- Сведения о процессоре ---
echo [Процессор]
echo [Процессор] >> "%report_file%"
for /f "tokens=2 delims==" %%i in ('wmic cpu get Name /format:list 2^>nul') do (
    echo Модель: %%i
    echo Модель: %%i >> "%report_file%"
)
echo.
echo. >> "%report_file%"

REM --- Сведения об оперативной памяти ---
echo [Оперативная память]
echo [Оперативная память] >> "%report_file%"
for /f "tokens=2 delims==" %%i in ('wmic OS get TotalVisibleMemorySize /format:list 2^>nul') do set "total_mem=%%i"
for /f "tokens=2 delims==" %%i in ('wmic OS get FreePhysicalMemory /format:list 2^>nul') do set "free_mem=%%i"

set /a total_gb=%total_mem% / 1048576
set /a free_gb=%free_mem% / 1048576

echo Всего памяти:    %total_gb% ГБ
echo Всего памяти:    %total_gb% ГБ >> "%report_file%"
echo Свободно памяти: %free_gb% ГБ
echo Свободно памяти: %free_gb% ГБ >> "%report_file%"
echo.
echo. >> "%report_file%"

REM --- Свободное место на диске C ---
echo [Диск C]
echo [Диск C] >> "%report_file%"
for /f "tokens=2 delims==" %%i in ('wmic logicaldisk where "DeviceID='C:'" get Size /format:list 2^>nul') do set "disk_size=%%i"
for /f "tokens=2 delims==" %%i in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /format:list 2^>nul') do set "disk_free=%%i"

set /a disk_size_gb=%disk_size:~0,-6% / 1073
set /a disk_free_gb=%disk_free:~0,-6% / 1073

echo Общий размер диска C: %disk_size_gb% ГБ
echo Общий размер диска C: %disk_size_gb% ГБ >> "%report_file%"
echo Свободно на диске C:  %disk_free_gb% ГБ
echo Свободно на диске C:  %disk_free_gb% ГБ >> "%report_file%"
echo.
echo. >> "%report_file%"

REM --- Список установленных программ ---
echo [Установленные программы]
echo [Установленные программы] >> "%report_file%"
echo Пожалуйста, подождите, идёт сбор данных...
echo.

for /f "tokens=2*" %%a in ('reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f DisplayName 2^>nul ^| findstr "DisplayName"') do (
    echo %%b
    echo %%b >> "%report_file%"
)
for /f "tokens=2*" %%a in ('reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /f DisplayName 2^>nul ^| findstr "DisplayName"') do (
    echo %%b
    echo %%b >> "%report_file%"
)
echo.
echo. >> "%report_file%"

echo =========================================
echo Отчёт успешно сохранён в файл pc_report.txt
echo =========================================
pause
