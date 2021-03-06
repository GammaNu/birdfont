#!/usr/bin/python
"""
Copyright (C) 2013 Johan Mattsson

This library is free software; you can redistribute it and/or modify 
it under the terms of the GNU Lesser General Public License as 
published by the Free Software Foundation; either version 3 of the 
License, or (at your option) any later version.

This library is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
Lesser General Public License for more details.
"""
prefix = ""
valac = "valac"
valaflags = ""
cc = "gcc"
cflags = "-g ./build/icon.res -Wl,-subsystem,windows "
ldflags = ""
library_cflags = "-Wl,-subsystem,windows "
library_ldflags= "";
library = "libbirdfont.dll"

import configfile
configfile.write_config (prefix)
configfile.write_compile_parameters (".\\\\", "build", "gcc", "gee-1.0")

import build
from translations import compile_translations

from run import run

compile_translations()
run("windres ./resources/win32/icon.rc -O coff -o ./build/icon.res")
build.libbirdfont(prefix, cc, cflags, library_ldflags, valac, valaflags, library)
build.birdfont_export(prefix, cc, cflags, ldflags, valac, valaflags, library)

print ("Done")
