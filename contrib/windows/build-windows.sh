#!/bin/sh

PKGARCH=$1
if [ "${PKGARCH}" == "" ];
then
  echo "tell me the architecture: x86, x64, arm or arm64"
  exit 1
fi

# Download the wix tools!
dotnet tool install --global wix --version 5.0.0

# Build Yggdrasil!
[ "${PKGARCH}" == "x64" ] && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 ./build
[ "${PKGARCH}" == "x86" ] && GOOS=windows GOARCH=386 CGO_ENABLED=0 ./build
[ "${PKGARCH}" == "arm" ] && GOOS=windows GOARCH=arm CGO_ENABLED=0 ./build
[ "${PKGARCH}" == "arm64" ] && GOOS=windows GOARCH=arm64 CGO_ENABLED=0 ./build

# Create the postinstall script
cat > start.bat << EOF
@echo off
set "SCRIPT_DIR=%~dp0"

if not exist "%SCRIPT_DIR%yggdrasil.conf" (
  if exist "%SCRIPT_DIR%yggdrasil.exe" (
    echo Generating yggdrasil.conf...
    "%SCRIPT_DIR%yggdrasil.exe" -genconf > "%SCRIPT_DIR%yggdrasil.conf"
    if errorlevel 1 (
      echo Failed to generate the configuration file!
      exit /b 1
    )
  ) else (
    echo yggdrasil.exe not found!
    exit /b 1
  )
)

if exist "%SCRIPT_DIR%yggdrasil.conf" (
  echo Starting Yggdrasil with the configuration file...
  "%SCRIPT_DIR%yggdrasil.exe" -useconffile "%SCRIPT_DIR%yggdrasil.conf"
  if errorlevel 1 (
    echo Failed to start Yggdrasil!
    exit /b 1
  )
) else (
  echo yggdrasil.conf file is missing!
  exit /b 1
)
EOF

# Work out metadata for the package info
PKGNAME=$(sh contrib/semver/name.sh)
PKGVERSION=$(sh contrib/msi/msversion.sh --bare)
PKGVERSIONMS=$(echo $PKGVERSION | tr - .)
([ "${PKGARCH}" == "x64" ] || [ "${PKGARCH}" == "arm64" ]) && \
  PKGGUID="77757838-1a23-40a5-a720-c3b43e0260cc" PKGINSTFOLDER="ProgramFiles64Folder" || \
  PKGGUID="54a3294e-a441-4322-aefb-3bb40dd022bb" PKGINSTFOLDER="ProgramFilesFolder"

# Download the Wintun driver
if [ ! -d wintun ];
then
  curl -o wintun.zip https://www.wintun.net/builds/wintun-0.14.1.zip
  if [ `sha256sum wintun.zip | cut -f 1 -d " "` != "07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51" ];
  then
    echo "wintun package didn't match expected checksum"
    exit 1
  fi
  unzip wintun.zip
fi

if [ $PKGARCH = "x64" ]; then
  mv ./wintun/bin/amd64/wintun.dll ./wintun.dll
elif [ $PKGARCH = "x86" ]; then
  mv ./wintun/bin/x86/wintun.dll ./wintun.dll
elif [ $PKGARCH = "arm" ]; then
  mv ./wintun/bin/arm/wintun.dll ./wintun.dll
elif [ $PKGARCH = "arm64" ]; then
  mv ./wintun/bin/arm64/wintun.dll ./wintun.dll
else
  echo "wasn't sure which architecture to get wintun for"
  exit 1
fi
rm -rf ./wintun
