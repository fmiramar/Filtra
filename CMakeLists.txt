cmake_minimum_required(VERSION 3.16)
project(MS20Filters VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Locate SuperCollider source headers (SC_PATH)
set(DEFAULT_SC_PATH "/Users/fmmac/Desktop/UBM rhode/vendor/supercollider")
if(NOT SC_PATH)
    if(DEFINED ENV{SC_PATH} AND EXISTS "$ENV{SC_PATH}/include/plugin_interface/SC_PlugIn.h")
        set(SC_PATH "$ENV{SC_PATH}")
    elseif(EXISTS "${DEFAULT_SC_PATH}/include/plugin_interface/SC_PlugIn.h")
        set(SC_PATH "${DEFAULT_SC_PATH}")
    endif()
endif()

if(NOT EXISTS "${SC_PATH}/include/plugin_interface/SC_PlugIn.h")
    message(FATAL_ERROR "SuperCollider headers not found at SC_PATH='${SC_PATH}'. Pass -DSC_PATH=/path/to/supercollider")
endif()

message(STATUS "Using SuperCollider headers from: ${SC_PATH}")

option(SUPERNOVA "Build plugins for supernova as well as scsynth" OFF)

set(PLUGIN_EXTENSION ".so")
if(APPLE)
    set(PLUGIN_EXTENSION ".scx")
elseif(WIN32)
    set(PLUGIN_EXTENSION ".scx")
endif()

set(MS20_PLUGIN_SOURCES
    src/MS20FiltersPlugin.cpp
    src/MS20SK.cpp
    src/MS20TPT.cpp
    src/MS20Diode.cpp
    src/MS20OTA.cpp
    src/MS20Circuit.cpp
    src/FSWasp.cpp
    src/FSSteiner.cpp
)

add_library(MS20Filters MODULE ${MS20_PLUGIN_SOURCES})
target_include_directories(MS20Filters PRIVATE
    "${SC_PATH}/include/plugin_interface"
    "${SC_PATH}/include/common"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
set_target_properties(MS20Filters PROPERTIES
    PREFIX ""
    SUFFIX "${PLUGIN_EXTENSION}"
)

if(APPLE)
    target_compile_definitions(MS20Filters PRIVATE SC_DARWIN)
    target_link_options(MS20Filters PRIVATE "-Wl,-undefined,dynamic_lookup")
elseif(WIN32)
    target_compile_definitions(MS20Filters PRIVATE SC_WIN32 NOMINMAX _USE_MATH_DEFINES)
else()
    target_compile_definitions(MS20Filters PRIVATE SC_LINUX)
endif()

if(MSVC)
    target_compile_options(MS20Filters PRIVATE /O2 /W3)
else()
    target_compile_options(MS20Filters PRIVATE
        -O3
        -Wall
        -Wextra
        -Wno-unused-parameter
    )
endif()

if(SUPERNOVA)
    add_library(MS20Filters_supernova MODULE ${MS20_PLUGIN_SOURCES})
    target_include_directories(MS20Filters_supernova PRIVATE
        "${SC_PATH}/include/plugin_interface"
        "${SC_PATH}/include/common"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )
    target_compile_definitions(MS20Filters_supernova PRIVATE SUPERNOVA)
    if(APPLE)
        target_compile_definitions(MS20Filters_supernova PRIVATE SC_DARWIN)
        target_link_options(MS20Filters_supernova PRIVATE "-Wl,-undefined,dynamic_lookup")
    endif()
    set_target_properties(MS20Filters_supernova PROPERTIES
        PREFIX ""
        SUFFIX "${PLUGIN_EXTENSION}"
    )
    target_compile_options(MS20Filters_supernova PRIVATE -O3 -Wall -Wextra -Wno-unused-parameter)
endif()

# Default install location: user SuperCollider Extensions directory
if(APPLE)
    set(DEFAULT_INSTALL_DIR "$ENV{HOME}/Library/Application Support/SuperCollider/Extensions/MS20Filters")
elseif(WIN32)
    set(DEFAULT_INSTALL_DIR "$ENV{LOCALAPPDATA}/SuperCollider/Extensions/MS20Filters")
else()
    set(DEFAULT_INSTALL_DIR "$ENV{HOME}/.local/share/SuperCollider/Extensions/MS20Filters")
endif()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${DEFAULT_INSTALL_DIR}" CACHE PATH "Install path for SuperCollider extension" FORCE)
endif()

install(TARGETS MS20Filters DESTINATION "plugins")
if(SUPERNOVA)
    install(TARGETS MS20Filters_supernova DESTINATION "plugins")
endif()
install(DIRECTORY classes/ DESTINATION "classes")
install(DIRECTORY HelpSource/ DESTINATION "HelpSource")
install(DIRECTORY examples/ DESTINATION "examples")
install(FILES MS20Filters.quark DESTINATION ".")
