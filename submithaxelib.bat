@echo off
del deepstate.zip >nul 2>&1

zip -r deepstate.zip src README.md haxelib.json

haxelib submit deepstate.zip
del deepstate.zip
