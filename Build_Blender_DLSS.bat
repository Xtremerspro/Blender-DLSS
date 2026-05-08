@echo off
setlocal EnableDelayedExpansion

:: Force the script to run in its actual folder, NOT System32
cd /d "%~dp0"

:: Define the new path variables based on the requested structure
set "ROOT_DIR=%~dp0"
set "BUILD_TOOLS_DIR=%ROOT_DIR%Build_Tools"
set "DLSS_SDK_DIR=%BUILD_TOOLS_DIR%\DLSS"
set "OPTIX_DIR=%BUILD_TOOLS_DIR%\OPTIX"
set "BLENDER_GIT_DIR=%BUILD_TOOLS_DIR%\Blender_Git"
set "BLENDER_SRC_DIR=%BLENDER_GIT_DIR%\blender"
set "CMAKE_BUILD_DIR=%BLENDER_GIT_DIR%\build"
set "FINAL_RELEASE_DIR=%ROOT_DIR%Release"

:: Clean up trailing backslash from ROOT_DIR for cleaner display
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
if "%FINAL_RELEASE_DIR:~-1%"=="\" set "FINAL_RELEASE_DIR=%FINAL_RELEASE_DIR:~0,-1%"

echo =======================================================
echo Blender DLSS Automated Build Script (Custom Structure)
echo =======================================================
echo Root Directory: %ROOT_DIR%
echo Final Output:   %FINAL_RELEASE_DIR%
echo.

:: ---------------------------------------------------------
:: PRE-FLIGHT CHECKS
:: ---------------------------------------------------------
set "MISSING_DEPS=0"

echo [System Check] Verifying dependencies...

:: 1. Check for NVIDIA GPU (Updated to bypass deprecated wmic)
powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController).Name" | findstr /i "NVIDIA" >nul
if errorlevel 1 (
    echo [X] ERROR: No NVIDIA GPU detected. An NVIDIA card is required.
    set "MISSING_DEPS=1"
) else (
    echo [OK] NVIDIA GPU detected.
)

:: 2. Check for Git
git.exe --version >nul 2>&1
if errorlevel 1 (
    echo [X] ERROR: Git for Windows is not installed or not in your PATH.
    echo     Download: https://git-scm.com/download/win
    set "MISSING_DEPS=1"
) else (
    echo [OK] Git is installed.
)

:: 3. Check for CMake
cmake --version >nul 2>&1
if errorlevel 1 (
    echo [X] ERROR: CMake is not installed or not in your system PATH.
    echo     Download: https://cmake.org/download/ ^(Windows x64 Installer^)
    echo     CRITICAL: Check the box to "Add CMake to the system PATH" during installation.
    set "MISSING_DEPS=1"
) else (
    echo [OK] CMake is installed.
)

:: 4. Check for CUDA Toolkit
if not defined CUDA_PATH (
    echo [X] ERROR: CUDA Toolkit is missing [CUDA_PATH variable not found].
    echo     Download: https://developer.nvidia.com/cuda-downloads
    set "MISSING_DEPS=1"
) else (
    echo [OK] CUDA Toolkit detected.
)

:: 5. Check for Visual Studio 2022 Environment
if not defined VSCMD_VER (
    echo [X] ERROR: Not running in "x64 Native Tools Command Prompt for VS 2022".
    echo     Please open that specific command prompt from your Start Menu to run this script.
    echo     Download VS 2022: https://aka.ms/vs/17/release/vs_community.exe
    set "MISSING_DEPS=1"
) else (
    echo [OK] Visual Studio 2022 Environment detected.
)

:: 6. Check for OptiX SDK
set "OPTIX_SOURCE="
if exist "%OPTIX_DIR%\" (
    echo [OK] Local OPTIX folder already detected in Build_Tools.
) else (
    for /d %%D in ("C:\ProgramData\NVIDIA Corporation\OptiX*") do (
        set "OPTIX_SOURCE=%%D"
    )
    if defined OPTIX_SOURCE (
        echo [OK] OptiX SDK detected in ProgramData.
    ) else (
        echo [X] ERROR: Could not find OptiX SDK locally or in C:\ProgramData\NVIDIA Corporation\
        echo     Download: https://developer.nvidia.com/designworks/optix/downloads/legacy
        echo     Please install it, ensure it extracts to the default ProgramData path.
        set "MISSING_DEPS=1"
    )
)

:: Halt if any dependencies are missing
if "!MISSING_DEPS!"=="1" (
    echo.
    echo =======================================================
    echo BUILD ABORTED: Please install the missing dependencies 
    echo listed above, restart your computer if necessary, and 
    echo run this script again.
    echo =======================================================
    pause
    exit /b 1
)

echo.
echo All pre-flight checks passed! 
pause

echo Proceeding with build...
echo.

:: ---------------------------------------------------------
:: BEGIN BUILD PROCESS
:: ---------------------------------------------------------

:: Ensure directory structure exists
echo Creating Build_Tools and Release folders...
if not exist "%BUILD_TOOLS_DIR%" mkdir "%BUILD_TOOLS_DIR%"
if not exist "%FINAL_RELEASE_DIR%" mkdir "%FINAL_RELEASE_DIR%"
echo.

echo [1/7] Setting up DLSS SDK...
if not exist "%DLSS_SDK_DIR%" (
    echo Cloning DLSS SDK into Build_Tools...
    git.exe clone https://github.com/NVIDIA/DLSS.git "%DLSS_SDK_DIR%"
) else (
    echo DLSS SDK already exists in Build_Tools. Skipping clone.
)

echo.
echo [2/7] Setting up OptiX SDK...
if exist "%OPTIX_DIR%\" (
    echo OPTIX folder already exists in Build_Tools. Skipping copy.
) else (
    echo Copying OptiX SDK from "!OPTIX_SOURCE!" to Build_Tools...
    xcopy /E /I /Q /H /Y "!OPTIX_SOURCE!" "%OPTIX_DIR%"
    echo OptiX SDK copied successfully.
)

echo.
echo [3/7] Setting up Blender repository...
if not exist "%BLENDER_GIT_DIR%" mkdir "%BLENDER_GIT_DIR%"
cd /d "%BLENDER_GIT_DIR%"

if not exist "blender" (
    git.exe clone https://projects.blender.org/blender/blender.git
)
cd blender

echo.
echo [4/7] Fetching NVIDIA DLSS branch...
git.exe remote add nvidia https://projects.blender.org/pmoursnv/blender.git 2>nul
git.exe fetch nvidia
git.exe checkout -b dlss nvidia/dlss

echo.
echo [5/7] Downloading Precompiled Libraries...
:: Piping 'y' directly from memory with NO spaces before the pipe
echo y|call make update

echo.
echo [6/7] Configuring CMake Build...
cd /d "%BLENDER_GIT_DIR%"
if not exist "build" mkdir build
cd build

cmake ../blender ^
-G "Visual Studio 17 2022" -A x64 ^
-DCMAKE_INSTALL_PREFIX="%FINAL_RELEASE_DIR%" ^
-DWITH_CYCLES_DEVICE_CUDA=ON -DWITH_CYCLES_CUDA_BINARIES=ON -DWITH_DLSS=ON ^
-DDLSS_SDK_ROOT="%DLSS_SDK_DIR%" -DDLSS_INCLUDE_DIR="%DLSS_SDK_DIR%\include" ^
-DWITH_CYCLES_DEVICE_OPTIX=ON -DOPTIX_ROOT_DIR="%OPTIX_DIR%"

echo.
echo [7/7] Compiling Blender (This will take a while)...
cmake --build . --target INSTALL --config Release

echo.
echo [Final Step] Copying DLSS DLL...
if exist "%DLSS_SDK_DIR%\lib\Windows_x86_64\rel\nvngx_dlssd.dll" (
    copy /Y "%DLSS_SDK_DIR%\lib\Windows_x86_64\rel\nvngx_dlssd.dll" "%FINAL_RELEASE_DIR%\"
    echo DLSSD DLL copied successfully.
) else (
    echo WARNING: nvngx_dlssd.dll not found in DLSS folder.
)

if exist "%DLSS_SDK_DIR%\lib\Windows_x86_64\rel\nvngx_dlss.dll" (
    copy /Y "%DLSS_SDK_DIR%\lib\Windows_x86_64\rel\nvngx_dlss.dll" "%FINAL_RELEASE_DIR%\"
    echo DLSS Core DLL copied successfully.
)

echo.
echo =======================================================
echo Build Process Complete!
echo You can launch your custom Blender from: 
echo %FINAL_RELEASE_DIR%\blender.exe
echo =======================================================
pause