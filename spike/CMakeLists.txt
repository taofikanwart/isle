# SPDX-License-Identifier: GPL-3.0-or-later
# Feasibility spike for the KDE port of Isle. Throwaway code: it proves (or
# disproves) the layer-shell notch architecture before any real work starts.
# Targets Qt5 because this machine runs Plasma 5.27; the real port will offer
# a Qt6 build once the target distros ship Plasma 6.

cmake_minimum_required(VERSION 3.16)
project(isle-spike CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 REQUIRED COMPONENTS Gui Quick DBus)
# Wayland layer-shell support. Optional so the spike still builds for the
# X11 fallback test on machines without the dev package.
find_package(LayerShellQtInterface QUIET)

add_executable(isle-spike main.cpp qml.qrc)
target_link_libraries(isle-spike Qt5::Gui Qt5::Quick Qt5::DBus)

if(LayerShellQtInterface_FOUND)
    target_compile_definitions(isle-spike PRIVATE HAVE_LAYERSHELL)
    target_link_libraries(isle-spike LayerShellQtInterface)
    message(STATUS "LayerShellQt found: Wayland layer-shell path enabled")
else()
    message(WARNING "LayerShellQt NOT found: only the X11 fallback will work")
endif()
