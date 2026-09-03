cmake_minimum_required(VERSION 3.16)
project(pool_physics_sandbox LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(POOL_ENABLE_SFML "Build the optional SFML visualizer" OFF)
option(POOL_BUILD_OVERLAY "Build the GLFW/OpenGL trajectory overlay" ON)

add_executable(pool_sandbox
    main.cpp Config.cpp Prediction.cpp PhysicsSimulator.cpp BatchRunner.cpp
    TrajectoryRenderer.cpp)
target_include_directories(pool_sandbox PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
if (POOL_ENABLE_SFML)
    find_package(SFML 2.5 COMPONENTS graphics window system REQUIRED)
    target_compile_definitions(pool_sandbox PRIVATE POOL_ENABLE_SFML=1)
    target_link_libraries(pool_sandbox PRIVATE sfml-graphics sfml-window sfml-system)
endif()

if (POOL_BUILD_OVERLAY)
    find_package(OpenGL REQUIRED)
    find_package(glfw3 3.3 REQUIRED)
    add_executable(trajectory_overlay
        overlay_main.cpp Renderer.cpp IPCClient.cpp config_loader.cpp)
    target_include_directories(trajectory_overlay PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    if (TARGET glfw)
        target_link_libraries(trajectory_overlay PRIVATE glfw OpenGL::GL)
    else()
        target_link_libraries(trajectory_overlay PRIVATE glfw3::glfw OpenGL::GL)
    endif()
endif()
