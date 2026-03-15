# tools/wheels/repair_windows.ps1
# Wraps delvewheel to bundle SUNDIALS and MSYS2 UCRT64 runtime DLLs into the wheel.
# Called by cibuildwheel repair-wheel-command.
param([string]$Wheel, [string]$DestDir)
delvewheel repair `
    --add-path "C:\msys64\ucrt64\bin;C:\deps\bin;C:\deps\lib" `
    -w $DestDir `
    $Wheel
