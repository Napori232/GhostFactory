# Use tools\test.cmd instead.
#
# This project's primary one-click test runner is test.cmd, because Windows
# execution policy blocks unsigned .ps1 files by default. If your policy allows
# local scripts, you can run the two commands directly:
#
#   Godot --headless --path <project> --import
#   Godot --headless --audio-driver Dummy --path <project> res://Code/Tests/TestRunner.tscn
