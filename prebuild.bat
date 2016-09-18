@echo off

set LOG_TAG=/*NppXtremeLog*/
set ROOT=%~dp0
set NPP_DIR=%ROOT%libs\notepad-plus-plus
set BOOST_DIR=%ROOT%libs\boost
set BOOST_DEPENDENCIES=libs\config libs\detail libs\exception libs\functional libs\integer libs\mpl libs\preprocessor libs\regex libs\smart_ptr libs\static_assert libs\type_traits libs\utility tools\build

goto :Main

rem Print log to console
rem %1 log string
:Log
  echo %LOG_TAG% %*
  goto :End

rem Clean and reset a submodule
rem %1 : The submodule name
:Cleanup
  call :Log Cleaning up %1...
  pushd %1
  git checkout .
  git clean -ffxd
  popd
  goto :End

rem Apply a patch to a submodule
rem %1 : The submodule name
rem %2 : The patch name
:ApplyPatch
  call :Log Applying %2 for %1...
  pushd %1
  git apply %ROOT%libs\patches\%2 --whitespace=nowarn
  popd
  goto :End
  
rem Init and update a submodule (or all if %1 is omitted)
rem %1 : The submodule name (optional)
:UpdateInit
  call :Log Updating submodule(s) %1...
  git submodule update --init %1
  goto :End

:Main
  rem Prepare a clean and up-to-date repository
  call :UpdateInit
  call :Cleanup %NPP_DIR%
  call :Cleanup %BOOST_DIR%
  
  pushd %BOOST_DIR%
  for %%G in (%BOOST_DEPENDENCIES%) do (
    call :UpdateInit %%G
    call :Cleanup %%G
  )
  call :ApplyPatch tools\build boost_build.patch
  popd
  
  rem Set up the MSVC environment
  call :Log Detecting an installed VisualStudio...
  set SUPPORTED_VS_TOOLSET=12.0 11.0 10.0 9.0
  del .error 2>nul
  for %%G in (%SUPPORTED_VS_TOOLSET%) do (
    set VS_TOOLSET=msvc-%%G
    for /f "tokens=2*" %%U in ('REG QUERY "HKLM\Software\Wow6432Node\Microsoft\VisualStudio\%%G" /v "ShellFolder" 2^>.error') do (
      set VCVARSALL=%%~V\VC\vcvarsall.bat
    )
    for %%X in (.error) do (
      if %%~zX == 0 (goto :found)
    )
  )
  :notfound
  del .error 2>nul
  call :Log Couldn't find any msvc toolset. Press enter again to exit or manually set up your toolset version (for example msvc-9.0, msvc-10.0, ...).
  set VS_TOOLSET=
  set /p VS_TOOLSET=
  if "%VS_TOOLSET%" == "" (goto :End)
  call :Log Please enter your vcvarsall location:
  set /p VCVARSALL=
  
  :found
  del .error 2>nul
  call :Log Found the toolset %VS_TOOLSET%
  call :Log Setting up MSVC environment...
  call "%VCVARSALL%"
  
  rem Bootstrap boost
  call :Log Bootstrapping boost...
  pushd %BOOST_DIR%
  call bootstrap.bat
  call b2 headers
  popd
  
  rem Build SciLexer
  call :Log Building SciLexer...
  pushd %NPP_DIR%\scintilla\boostregex
  call BuildBoost.bat --toolset=%VS_TOOLSET% %BOOST_DIR%
  cd ..\win32
  call nmake DEBUG=1 -f scintilla.mak
  if not exist "%NPP_DIR%\PowerEditor\visual.net\Unicode Debug" (
    md "%NPP_DIR%\PowerEditor\visual.net\Unicode Debug"
  )
  if exist ..\bin\SciLexer.dll (
    copy /B /Y ..\bin\SciLexer.dll "%NPP_DIR%\PowerEditor\visual.net\Unicode Debug\SciLexer.dll"
  )
  if exist ..\bin\SciLexer.pdb (
    copy /B /Y ..\bin\SciLexer.pdb "%NPP_DIR%\PowerEditor\visual.net\Unicode Debug\SciLexer.pdb"
  )
  popd
  
:End