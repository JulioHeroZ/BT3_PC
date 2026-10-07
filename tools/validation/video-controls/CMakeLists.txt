cmake_minimum_required(VERSION 3.21)
project(VideoControlsCheck LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Widgets)
get_filename_component(BT3_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
add_executable(video_controls_check
    video_controls_check.cpp
    "${BT3_ROOT}/ps2xRuntime/src/launcher/settings_manager.cpp"
    "${BT3_ROOT}/ps2xRuntime/src/launcher/tab_video.cpp"
    "${BT3_ROOT}/ps2xRuntime/src/launcher/tab_video.h")
target_include_directories(video_controls_check PRIVATE
    "${BT3_ROOT}/ps2xRuntime/include"
    "${BT3_ROOT}/ps2xRuntime/src/launcher")
target_link_libraries(video_controls_check PRIVATE Qt6::Widgets)
enable_testing()
add_test(NAME video_controls COMMAND video_controls_check)
set_tests_properties(video_controls PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
