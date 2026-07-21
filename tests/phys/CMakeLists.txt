cmake_minimum_required(VERSION 3.16)

find_package(Qt6 REQUIRED COMPONENTS Gui Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED wayland-client)

# Helper function to add a simple probe executable
function(add_phys_probe name sources)
    qt_add_executable(${name} ${sources})
    target_link_libraries(${name} PRIVATE 
        Qt6::Gui 
        Qt6::Quick 
        MpvQt::MpvQt 
        ${MPV_LIBRARIES} 
        va 
        va-drm 
        va-wayland
        ${WAYLAND_CLIENT_LIBRARIES}
    )
endfunction()

# Hardware probes
add_phys_probe(phys_vaapi test_vaapi.cpp)
add_phys_probe(phys_vaapi_wl_connect test_vaapi_wl_connect.cpp)
add_phys_probe(phys_hwdec test_hwdec.cpp)
add_phys_probe(phys_fps test_fps.cpp)

# Qt probes
add_phys_probe(phys_qt_render test_qt_render.cpp)

