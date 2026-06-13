cmake_minimum_required(VERSION 3.20)
project(DirectoryCitizens VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(${PROJECT_NAME} WIN32 src/main.cpp)

target_link_libraries(${PROJECT_NAME} PRIVATE user32 gdi32)
