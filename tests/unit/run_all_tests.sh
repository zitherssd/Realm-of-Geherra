#!/bin/bash
"love_exe"="${C:\Program Files\Love\love.exe}"
"test_file"="D:/Projects/Realm-of-Geherra/tests/unit/main.lua"

echo "Running: ${love_exe} ${test_file}"
exec "${love_exe}" "${test_file}" 2>&1
