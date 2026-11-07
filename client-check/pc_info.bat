@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM ==============================================================================
REM Тема: Инструментальные средства ревьюирования и аудит на стороне клиента.
REM Практическая работа 8. Часть 2 (Доработка скрипта диагностики)
REM ==============================================================================

:: Определение путей (сохраняем файл рядом со скриптом через %~dp0)
set "REPORT_FILE=%~dp0pc_report.txt"
set "APPS_LIST=%temp%\apps_list.txt"

:: Очищаем старый отчет перед новым запуском
if exist "%REPORT_FILE%" del "%REPORT_FILE%"

:: Сбор текущей даты и времени для версионирования отчета
for /f "tokens=1-3 delims=. " %%a in ("%date%") do set "current_date=%%a.%%b.%%c"
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set "current_time=%%a:%%b"

:: Информируем пользователя в консоли о начале долгой операции
echo [ИНФО]: Запуск комплексного аудита системы...
echo Пожалуйста, подождите, сбор данных и анализ займут около 1 минуты.
echo -----------------------------------------------------------------------

call :log "======================================================================="
call :log "           РАСШИРЕННЫЙ ОТЧЕТ И АУДИТ БЕЗОПАСНОСТИ ПК                   "
call :log "======================================================================="
call :log "Дата проверки: %current_date% в %current_time%"
call :log "======================================================================="
call :log ""

REM ==============================================================================
REM ШАГ 3. ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ (Защита от сбоев + PowerShell вместо WMIC)
REM ==============================================================================
call :log "--- [РАЗДЕЛ 1. ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ ПК] ---"

:: Явная очистка переменных перед каждым блоком сбора данных
set "os_name="
set "os_version="
set "cpu_name="
set "total_ram="
set "free_disk="

:: Сбор данных через CIM-инстансы PowerShell (надежно для Win 10 и Win 11)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption" 2^>nul`) do set "os_name=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Version" 2^>nul`) do set "os_version=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name" 2^>nul`) do set "cpu_name=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[math]::round\(\(Get-CimInstance Win32_PhysicalMemory ^| Measure-Object Capacity -Sum\).Sum / 1GB\)" 2^>nul`) do set "total_ram=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[math]::round\(\(Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\"\).FreeSpace / 1GB\)" 2^>nul`) do set "free_disk=%%i"

:: Вывод с проверкой: если переменная пуста — пишем ошибку, но не прерываем скрипт
if defined os_name ( call :log "Операционная система: %os_name% (Версия %os_version%)" ) else ( call :log "Ошибка: Данные об ОС не получены." )
if defined cpu_name ( call :log "Процессор: %cpu_name%" ) else ( call :log "Ошибка: Данные о процессоре не получены." )
if defined total_ram ( call :log "Всего памяти: %total_ram% ГБ" ) else ( call :log "Ошибка: Данные о RAM не получены." )
if defined free_disk ( call :log "Свободно на диске C: %free_disk% ГБ" ) else ( call :log "Ошибка: Свободное место на C: не определено." )
call :log ""

REM ==============================================================================
REM ШАГ 4. ПОЛУЧЕНИЕ И ОЧИСТКА СПИСКА ПРОГРАММ ИЗ РЕЕСТРА (32 и 64 бит)
REM ==============================================================================
if exist "%APPS_LIST%" del "%APPS_LIST%"

set "reg_64=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall"
set "reg_32=HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

:: Обход обеих веток реестра, вытаскиваем только значения параметров DisplayName
for %%p in ("%reg_64%" "%reg_32%") do (
    for /f "usebackq delims=" %%k in (`reg query "%%~p" /s /v DisplayName 2^>nul`) do (
        for /f "tokens=2*" %%a in ("%%k") do (
            if "%%a"=="REG_SZ" (
                set "app_name=%%b"
                if defined app_name echo !app_name! >> "%APPS_LIST%"
            )
        )
    )
)

:: Сортировка списка и удаление дубликатов штатными средствами PowerShell
if exist "%APPS_LIST%" (
    powershell -NoProfile -Command "Get-Content '%APPS_LIST%' -ErrorAction SilentlyContinue | Sort-Object -Unique | Set-Content '%APPS_LIST%'"
) else (
    echo Не удалось сформировать список ПО > "%APPS_LIST%"
)

set /a base_checked=5
set /a recommendations_count=0

REM ==============================================================================
REM ШАГ 5. АУДИТ ПО БЕЛОМУ СПИСКУ (Поиск недостающего офисного софта)
REM ==============================================================================
call :log "--- [РАЗДЕЛ 2. АУДИТ НЕОБХОДИМОГО РАБОЧЕГО ПО] ---"

:: 1. Офисный софт
findstr /I /C:"office" /C:"libreoffice" /C:"openoffice" /C:"myoffice" "%APPS_LIST%" >nul
if %errorlevel% equ 0 (
    call :log "[ОК] Офисный пакет: Обнаружен."
) else (
    call :log "[РЕКОМЕНДАЦИЯ] Не обнаружен офисный пакет. Для работы с документами рекомендуется установить LibreOffice или МойОфис."
    set /a recommendations_count+=1
)

:: 2. Архиваторы
findstr /I /C:"7-Zip" /C:"WinRAR" /C:"WinZip" "%APPS_LIST%" >nul
if %errorlevel% equ 0 (
    call :log "[ОК] Архиватор: Обнаружен."
) else (
    call :log "[РЕКОМЕНДАЦИЯ] Не обнаружен архиватор. Для распаковки вложений почты рекомендуется установить 7-Zip."
    set /a recommendations_count+=1
)

:: 3. Просмотр PDF
findstr /I /C:"Acrobat" /C:"Foxit" /C:"SumatraPDF" "%APPS_LIST%" >nul
if %errorlevel% equ 0 (
    call :log "[ОК] PDF-ридер: Обнаружен."
) else (
    call :log "[РЕКОМЕНДАЦИЯ] Не обнаружен PDF-ридер. Для чтения актов и договоров рекомендуется установить Foxit Reader."
    set /a recommendations_count+=1
)

:: 4. Браузер (Учитываем нюанс про Edge)
findstr /I /C:"Chrome" /C:"Firefox" /C:"Yandex" /C:"Opera" "%APPS_LIST%" >nul
if %errorlevel% equ 0 (
    call :log "[ОК] Корпоративный браузер: Обнаружен альтернативный браузер."
) else (
    call :log "[ИНФО] Сторонние браузеры не найдены. Доступен встроенный Microsoft Edge (компонент ОС)."
)

:: 5. Средства ИБ
findstr /I /C:"Kaspersky" /C:"ESET" /C:"Dr.Web" /C:"Defender" "%APPS_LIST%" >nul
if %errorlevel% equ 0 (
    call :log "[ОК] Средства антивирусной защиты: Обнаружены."
) else (
    call :log "[РЕКОМЕНДАЦИЯ] Корпоративный антивирус не найден. Убедитесь, что встроенный Defender активен."
    set /a recommendations_count+=1
)
call :log ""

REM ==============================================================================
REM ШАГ 6. АУДИТ ПО ЧЕРНОМУ СПИСКУ (Поиск нецелевого/излишнего ПО)
REM ==============================================================================
call :log "--- [РАЗДЕЛ 3. АУДИТ ПОДЛЕЖАЩЕГО ПРОВЕРКЕ / НЕЦЕЛЕВОГО ПО] ---"
call :log "Внимание: Данный раздел носит рекомендательный характер для системного администратора."

:: Группа 1: Гейминг
set "found_games="
for /f "delims=" %%g in ('findstr /I /C:"Steam" /C:"Epic Games" /C:"GOG" /C:"Origin" /C:"game" /C:"gaming" "%APPS_LIST%" 2^>nul') do (set "found_games=!found_games! '%%g';")
if defined found_games (
    call :log "[ВНИМАНИЕ] Найдено игровое ПО: %found_games%"
    set /a recommendations_count+=1
) else (
    call :log "[ОК] Развлекательное игровое ПО не обнаружено."
)

:: Группа 2: Торрент-сеть
set "found_torrents="
for /f "delims=" %%t in ('findstr /I /C:"torrent" /C:"uTorrent" /C:"BitTorrent" /C:"qBittorrent" "%APPS_LIST%" 2^>nul') do (set "found_torrents=!found_torrents! '%%t';")
if defined found_torrents (
    call :log "[КРИТИЧНО] Найдены торрент-клиенты: %found_torrents% (Высокий риск сетевой нагрузки и вирусов)."
    set /a recommendations_count+=1
) else (
    call :log "[ОК] Опасные файлообменные программы не обнаружены."
)

:: Группа 3: Некорпоративные мессенджеры
set "found_msg="
for /f "delims=" %%m in ('findstr /I /C:"Discord" /C:"Telegram" /C:"WhatsApp" /C:"Viber" "%APPS_LIST%" 2^>nul') do (set "found_msg=!found_msg! '%%m';")
if defined found_msg (
    call :log "[ПРОВЕРИТЬ] Найден софт для личного общения: %found_msg% (Требуется сверка с ИТ-политикой фирмы)."
    set /a recommendations_count+=1
) else (
    call :log "[ОК] Несогласованные мессенджеры не обнаружены."
)

:: Группа 4: Утилиты стриминга/оформления
set "found_media="
for /f "delims=" %%e in ('findstr /I /C:"Wallpaper Engine" /C:"OBS" /C:"Soundpad" "%APPS_LIST%" 2^>nul') do (set "found_media=!found_media! '%%e';")
if defined found_media (
    call :log "[ПРОВЕРИТЬ] Обнаружены медиа-инструменты развлечений: %found_media%"
    set /a recommendations_count+=1
) else (
    call :log "[ОК] Избыточные мультимедиа-программы не обнаружены."
)
call :log ""

REM ==============================================================================
REM ФИНАЛИЗАЦИЯ И УДАЛЕНИЕ МУСОРА
REM ==============================================================================
if exist "%APPS_LIST%" del "%APPS_LIST%"

echo -----------------------------------------------------------------------
echo [УСПЕШНО]: Диагностика и аудит завершены!
echo Проверено обязательных категорий ПО: %base_checked%
echo Выдано замечаний/рекомендаций для ИТ-отдела: %recommendations_count%
echo Полный лог-файл сформирован и лежит здесь:
echo %REPORT_FILE%
echo -----------------------------------------------------------------------
echo.
pause
exit /b

REM ==============================================================================
REM ШАГ 2. ПОДПРОГРАММА ВЫВОДА (Ловушка пустых строк + вывод экран/файл)
REM ==============================================================================
:log
:: Ловушка пустой строки: echo( гарантирует чистый перенос без вывода статуса "ECHO OFF"
if "%~1"=="" (
    echo(
    echo( >> "%REPORT_FILE%"
    exit /b
)

