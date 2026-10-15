cmake_minimum_required(VERSION 3.5)
project(harbour-bioquiz LANGUAGES CXX)

# Sailfish OS build (Qt 5.6 + Silica). Android and iOS build from android/.

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/rpm/harbour-bioquiz.spec" BIOQUIZ_SPEC)
string(REGEX MATCH "Version:[ \t]*([0-9.]+)" _ "${BIOQUIZ_SPEC}")
set(BIOQUIZ_VERSION "${CMAKE_MATCH_1}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 REQUIRED COMPONENTS Core DBus Gui Network Qml Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)

set(BIOQUIZ_SOURCES
    src/main.cpp
    src/QuestionBank.cpp
    src/Match.cpp
    src/GameController.cpp
    src/LanSession.cpp
    src/BtLink.cpp
)

add_executable(harbour-bioquiz ${BIOQUIZ_SOURCES} bioquiz.qrc)
target_compile_definitions(harbour-bioquiz PRIVATE SAILFISH BIOQUIZ_VERSION="${BIOQUIZ_VERSION}")
target_include_directories(harbour-bioquiz PRIVATE src ${SAILFISHAPP_INCLUDE_DIRS})
target_link_libraries(harbour-bioquiz Qt5::Core Qt5::DBus Qt5::Gui Qt5::Network Qt5::Qml Qt5::Quick ${SAILFISHAPP_LIBRARIES})

install(TARGETS harbour-bioquiz RUNTIME DESTINATION bin)
install(DIRECTORY data DESTINATION share/harbour-bioquiz)
install(FILES harbour-bioquiz.desktop DESTINATION share/applications)
foreach(size 86 108 128 172)
    install(FILES assets/appicon/bioquiz-${size}.png
            DESTINATION share/icons/hicolor/${size}x${size}/apps
            RENAME harbour-bioquiz.png)
endforeach()
