#
# Copyright (c) 2019 befovy <befovy@gmail.com>
#
# This file is part of ijkPlayer.
#
# ijkPlayer is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# ijkPlayer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with ijkPlayer; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#

cmake_minimum_required(VERSION 3.6)

project("IjkPlayer")

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 11)

message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
message(STATUS "PROJECT_SOURCE_DIR ${PROJECT_SOURCE_DIR}")

set(IJKROOT_PATH "${PROJECT_SOURCE_DIR}/..")
get_filename_component(IJKROOT_PATH ${IJKROOT_PATH} ABSOLUTE)
message(STATUS "IJKROOT_PATH ${IJKROOT_PATH}")
include(CMakePrintHelpers)


option(IJK_GLFW "use glfw render" OFF)
cmake_print_variables(IJK_GLFW)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()
if (${CMAKE_BUILD_TYPE} STREQUAL "Release")
    add_definitions(-DNDEBUG=1)
elseif (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    add_definitions(-DDEBUG=1)
endif ()


# check depends: $CMAKE_SYSTEM_NAME
if (APPLE)
    set(IJK_FFMPAG_BUILD_DIR ${IJKROOT_PATH}/osx/contrib/build/ffmpeg-${CMAKE_HOST_SYSTEM_PROCESSOR}/output/)
    set(IJK_OPENSSL_BUILD_DIR ${IJKROOT_PATH}/osx/contrib/build/openssl-${CMAKE_HOST_SYSTEM_PROCESSOR}/output/)
endif ()
if (WIN32)
    set(IJK_FFMPAG_BUILD_DIR ${IJKROOT_PATH}/win32/contrib/build/ffmpeg-${CMAKE_HOST_SYSTEM_PROCESSOR}/output/)
    set(IJK_OPENSSL_BUILD_DIR ${IJKROOT_PATH}/win32/contrib/build/openssl-${CMAKE_HOST_SYSTEM_PROCESSOR}/output/)
    set(IJK_PTHREAD_BUILD_DIR ${IJKROOT_PATH}/win32/pthreads/lib/${CMAKE_HOST_SYSTEM_PROCESSOR})
    add_definitions(-DHAVE_STRUCT_TIMESPEC)
endif ()
cmake_print_variables(IJK_FFMPAG_BUILD_DIR)

if (NOT DEFINED IJK_FFMPAG_BUILD_DIR)
    message(FATAL_ERROR "Can not find ffmpeg build output: ${IJK_FFMPAG_BUILD_DIR}")
endif ()

find_package(SDL2 REQUIRED)
add_definitions(-DUSE_SDL2=1)
#should not add here
#include_directories(${SDL2_INCLUDE_DIRS})

add_definitions(-DIJK_DESKTOP_UNI=1)
set(IJK_DESKTOP_UNI ON)

set(FIJKPLAYER_SOURCE
    ${CMAKE_CURRENT_LIST_DIR}/sources/ijkplayer_desktop.h
    ${CMAKE_CURRENT_LIST_DIR}/sources/ijkplayer_desktop.c
    ${CMAKE_CURRENT_LIST_DIR}/glfw/deps/glad_gl.c
)

if (IJK_GLFW)
    add_definitions(-DIJK_GLFW=1)
endif ()

add_library(IjkPlayer SHARED ${FIJKPLAYER_SOURCE})

add_subdirectory(../ijkmedia ijkmedia)

target_include_directories(IjkPlayer PRIVATE ${IJKROOT_PATH}/ijkmedia)
target_include_directories(IjkPlayer PRIVATE ${IJKROOT_PATH}/ijkmedia/ijkplayer)
target_include_directories(IjkPlayer PRIVATE ${IJK_FFMPAG_BUILD_DIR}/include)
if (WIN32)
target_include_directories(IjkPlayer PRIVATE "${IJK_PTHREAD_BUILD_DIR}/../../include")
endif ()

target_include_directories(IjkPlayer PRIVATE glfw/deps)
target_include_directories(IjkPlayer PRIVATE glfw/include)

target_link_libraries(IjkPlayer ijksdl_static ijkplayer_static yuv)


find_package(PkgConfig REQUIRED QUIET)
set(ENV{PKG_CONFIG_PATH} "${IJK_FFMPAG_BUILD_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
pkg_check_modules(FFMPEG_STATIC REQUIRED libavcodec libavformat libavutil libswresample libswscale)
target_link_libraries(IjkPlayer ${SDL2_LIBRARIES})

if (WIN32)
    target_compile_options(ijksdl_static PRIVATE /W3 /we4013)
    target_compile_options(ijkplayer_static PRIVATE /W3 /we4013)
    target_compile_options(IjkPlayer PRIVATE /W3 /we4013)

    add_library(pthread STATIC IMPORTED)
    set_target_properties(pthread PROPERTIES IMPORTED_LOCATION ${IJK_PTHREAD_BUILD_DIR}/pthreadVC2.lib)
    target_link_libraries(IjkPlayer pthread)
endif ()

list(REMOVE_ITEM FFMPEG_STATIC_LIBRARIES "ssl")
list(REMOVE_ITEM FFMPEG_STATIC_LIBRARIES "crypto")

cmake_print_variables(FFMPEG_STATIC_INCLUDE_DIRS)
cmake_print_variables(FFMPEG_STATIC_LIBRARIES)
cmake_print_variables(FFMPEG_STATIC_LIBRARY_DIRS)

target_link_libraries(IjkPlayer ${FFMPEG_STATIC_LIBRARIES})
target_link_directories(IjkPlayer PUBLIC ${FFMPEG_STATIC_LIBRARY_DIRS})
target_link_libraries(IjkPlayer portaudio_static )
if (SRT_FOUND)
    message(STATUS "SRT ${SRT_STATIC_LIBRARIES}")
    target_link_libraries(IjkPlayer ${SRT_STATIC_LIBRARIES})
    target_link_directories(IjkPlayer PUBLIC ${SRT_STATIC_LIBRARY_DIRS})
endif()

if(APPLE AND SRT_STATIC_FOUND)
    set_target_properties(IjkPlayer PROPERTIES LINK_FLAGS "-Wl,-no_compact_unwind")
endif()

target_compile_definitions(IjkPlayer PRIVATE -DBUILDING_IJK=1)

if (WIN32)
    set(OPENSSL_ROOT_DIR ${IJK_OPENSSL_BUILD_DIR})
    find_package(OpenSSL REQUIRED)
    target_link_libraries(IjkPlayer ${OPENSSL_LIBRARIES})
    target_link_libraries(IjkPlayer ws2_32 secur32 avrt shlwapi advapi32 shell32 kernel32 user32)
elseif (APPLE)
    set(OPENSSL_ROOT_DIR ${IJK_OPENSSL_BUILD_DIR})
    find_package(OpenSSL REQUIRED)
    target_link_libraries(IjkPlayer ${OPENSSL_LIBRARIES})
    target_link_libraries(IjkPlayer z)
    target_link_libraries(IjkPlayer bz2)

    macro(add_framework appname fwname)
        find_library(FRAMEWORK_${fwname}
                NAMES ${fwname}
                PATHS ${CMAKE_OSX_SYSROOT}/System/Library
                PATH_SUFFIXES Frameworks NO_DEFAULT_PATH)

        if (${FRAMEWORK_${fwname}} STREQUAL FRAMEWORK_${fwname}-NOTFOUND)
            MESSAGE(ERROR ": Framework ${fwname} not found")
        else ()
            target_link_libraries(${appname} "${FRAMEWORK_${fwname}}")
            MESSAGE(STATUS "Framework ${fwname} found")
        endif ()
    endmacro(add_framework)

    add_framework(IjkPlayer CoreVideo)
    add_framework(IjkPlayer CoreMedia)
    add_framework(IjkPlayer VideoToolbox)
    add_framework(IjkPlayer Security)
endif ()

if (IJK_GLFW)
    MESSAGE(STATUS "Set GLFW build ...")
    set(GLFW_BUILD_EXAMPLES OFF)
    set(GLFW_BUILD_TESTS OFF)
    set(GLFW_INSTALL OFF)
    set(GLFW_BUILD_DOCS OFF)
    add_subdirectory(glfw)
endif ()

add_executable(tuidemo WIN32 MACOSX_BUNDLE ${CMAKE_CURRENT_LIST_DIR}/sources/ijkplayer_demo.c)
target_include_directories(tuidemo PRIVATE glad/include)
target_include_directories(tuidemo PRIVATE glfw/include)
target_include_directories(tuidemo PRIVATE glfw/deps)

if (IJK_GLFW)
    target_link_libraries(tuidemo glfw)
endif()

if (APPLE)
    set_target_properties(tuidemo PROPERTIES MACOSX_BUNDLE_BUNDLE_NAME "tuidemo")
    add_compile_definitions(APPLE=1)
endif()


if (WIN32)
    target_link_libraries(tuidemo IjkPlayer user32)
else ()
    target_link_libraries(tuidemo IjkPlayer)
endif ()

