cmake_minimum_required(VERSION 3.16)

project(flex_player VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network OpenGL Test QuickTest Gui DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED mpv)
add_subdirectory(3rdparty/mpvqt)

qt_standard_project_setup()

set(APP_SOURCES
    src/PlexModel.cpp
    src/PlexAuth.cpp
    src/PlexAuth.h
    src/ScreenSaverInhibitor.cpp
    src/ScreenSaverInhibitor.h
    src/PlexModel.h
    src/MpvItem.cpp
    src/MpvItem.h
    src/qthelper.hpp
)

# Main Application
qt_add_executable(flex_player_app src/main.cpp ${APP_SOURCES})

qt_add_qml_module(flex_player_app
    URI flex_player
    VERSION 1.0
    QML_FILES src/Main.qml src/SettingsWindow.qml src/PlayerView.qml src/SidebarView.qml src/LibraryRail.qml src/MoviePosterDelegate.qml
    src/MovieDetailsView.qml src/DetailsCastList.qml src/SeriesDetailsView.qml src/SeasonDetailsView.qml src/LibraryRecommendView.qml src/CollectionMoviesView.qml src/HomeView.qml
    RESOURCES assets/imdb_logo.svg assets/flex_icon.svg
)

target_include_directories(flex_player_app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src ${MPV_INCLUDE_DIRS} /usr/include/qt6/QtGui/6.11.1)
target_link_libraries(flex_player_app PRIVATE Qt6::Quick Qt6::Network Qt6::OpenGL Qt6::DBus MpvQt::MpvQt ${MPV_LIBRARIES})

# Test Executable
enable_testing()
qt_add_executable(flex_player_test tests/main_test.cpp ${APP_SOURCES})

qt_add_qml_module(flex_player_test
    URI flex_player_test_module
    VERSION 1.0
    QML_FILES src/Main.qml src/SettingsWindow.qml src/PlayerView.qml src/SidebarView.qml src/LibraryRail.qml src/MoviePosterDelegate.qml
    src/MovieDetailsView.qml src/DetailsCastList.qml src/SeriesDetailsView.qml src/SeasonDetailsView.qml src/LibraryRecommendView.qml src/CollectionMoviesView.qml src/HomeView.qml
    RESOURCES assets/imdb_logo.svg assets/flex_icon.svg
)

target_include_directories(flex_player_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src ${MPV_INCLUDE_DIRS} /usr/include/qt6/QtGui/6.11.1)
target_link_libraries(flex_player_test PRIVATE Qt6::Quick Qt6::Network Qt6::OpenGL Qt6::DBus Qt6::Test Qt6::QuickTest MpvQt::MpvQt ${MPV_LIBRARIES})
target_compile_definitions(flex_player_test PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests")
add_test(NAME flex_player_test COMMAND flex_player_test)
