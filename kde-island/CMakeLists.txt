# SPDX-License-Identifier: GPL-3.0-or-later
# The KDE frontend for Isle: a notch at the top of the screen that talks to
# isled over D-Bus. Builds against Qt 5 or Qt 6; layer-shell is optional so
# the X11 fallback still works where the dev package is missing.

cmake_minimum_required(VERSION 3.16)
project(isle-island VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Gui Quick DBus)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Gui Quick DBus)
message(STATUS "Building against Qt ${QT_VERSION_MAJOR}")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO REQUIRED gio-2.0)

find_package(LayerShellQt QUIET)

add_executable(isle-island
    src/main.cpp
    src/spring.cpp
    src/daemonclient.cpp
    src/windowbackend.cpp
    qml/qml.qrc
)

if(LayerShellQt_FOUND)
    target_compile_definitions(isle-island PRIVATE HAVE_LAYERSHELL)
    message(STATUS "LayerShellQt found: Wayland layer-shell enabled")
else()
    message(WARNING "LayerShellQt not found: Wayland falls back to a plain window")
endif()

target_include_directories(isle-island PRIVATE src ${GIO_INCLUDE_DIRS})
target_link_libraries(isle-island PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::DBus
    ${GIO_LIBRARIES}
)

if(LayerShellQt_FOUND)
    target_link_libraries(isle-island PRIVATE LayerShellQt::Interface)
endif()

install(TARGETS isle-island RUNTIME DESTINATION bin)
