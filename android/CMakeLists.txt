cmake_minimum_required(VERSION 3.21)
project(bioquiz LANGUAGES CXX)

# Qt 6 build for Android, iOS and the desktop (for testing). Same sources and
# QML as the Sailfish OS build; only the window around AppView differs.

set(BIOQUIZ_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")

# The version lives in the RPM spec only.
file(READ "${BIOQUIZ_ROOT}/rpm/harbour-bioquiz.spec" BIOQUIZ_SPEC)
string(REGEX MATCH "Version:[ \t]*([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${BIOQUIZ_SPEC}")
set(BIOQUIZ_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
math(EXPR BIOQUIZ_VERSION_CODE "${CMAKE_MATCH_1} * 10000 + ${CMAKE_MATCH_2} * 100 + ${CMAKE_MATCH_3}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Network Qml Quick)
qt_standard_project_setup(REQUIRES 6.9)
set(CMAKE_AUTORCC ON)

qt_add_executable(bioquiz
    ${BIOQUIZ_ROOT}/src/main.cpp
    ${BIOQUIZ_ROOT}/src/QuestionBank.cpp
    ${BIOQUIZ_ROOT}/src/QuestionBank.h
    ${BIOQUIZ_ROOT}/src/Match.cpp
    ${BIOQUIZ_ROOT}/src/Match.h
    ${BIOQUIZ_ROOT}/src/GameController.cpp
    ${BIOQUIZ_ROOT}/src/GameController.h
    ${BIOQUIZ_ROOT}/src/LanSession.cpp
    ${BIOQUIZ_ROOT}/src/LanSession.h
    ${BIOQUIZ_ROOT}/src/BtLink.cpp
    ${BIOQUIZ_ROOT}/src/BtLink.h
    ${BIOQUIZ_ROOT}/src/BtLinkAndroid.cpp
    ${BIOQUIZ_ROOT}/bioquiz.qrc
)
target_include_directories(bioquiz PRIVATE ${BIOQUIZ_ROOT}/src)
target_compile_definitions(bioquiz PRIVATE BIOQUIZ_VERSION="${BIOQUIZ_VERSION}")
target_link_libraries(bioquiz PRIVATE Qt6::Core Qt6::Gui Qt6::Network Qt6::Qml Qt6::Quick)
# Raw RFCOMM plus BlueZ over D-Bus on desktop Linux, as on Sailfish OS.
if(LINUX AND NOT ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS DBus)
    target_link_libraries(bioquiz PRIVATE Qt6::DBus)
endif()

if(ANDROID)
    # The question catalogue and the pictures go into the APK's assets/data;
    # QuestionBank reads them through Qt's assets:/ file engine.
    set(BIOQUIZ_PACKAGE "${CMAKE_CURRENT_BINARY_DIR}/package")
    file(REMOVE_RECURSE "${BIOQUIZ_PACKAGE}")
    file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/package/" DESTINATION "${BIOQUIZ_PACKAGE}")
    file(COPY "${BIOQUIZ_ROOT}/data" DESTINATION "${BIOQUIZ_PACKAGE}/assets")
    set_target_properties(bioquiz PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${BIOQUIZ_PACKAGE}"
        QT_ANDROID_PACKAGE_NAME "org.smatkovi.bioquiz"
        QT_ANDROID_APP_NAME "BioQuiz"
        QT_ANDROID_APP_ICON "@mipmap/ic_launcher"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 36
        QT_ANDROID_VERSION_CODE ${BIOQUIZ_VERSION_CODE}
        QT_ANDROID_VERSION_NAME "${BIOQUIZ_VERSION}"
    )
    # Broadcast discovery needs a Wi-Fi multicast lock on many devices.
    qt_add_android_permission(bioquiz NAME android.permission.ACCESS_WIFI_STATE)
    qt_add_android_permission(bioquiz NAME android.permission.ACCESS_NETWORK_STATE)
    qt_add_android_permission(bioquiz NAME android.permission.CHANGE_WIFI_MULTICAST_STATE)
    qt_add_android_permission(bioquiz NAME android.permission.WAKE_LOCK)
elseif(IOS)
    # Without NSLocalNetworkUsageDescription iOS refuses every LAN connection
    # and never asks. Broadcast discovery would need Apple's multicast
    # entitlement, so on iOS a host is joined by its address.
    set_target_properties(bioquiz PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${BIOQUIZ_ROOT}/ios/Info.plist.in"
        MACOSX_BUNDLE_GUI_IDENTIFIER "org.smatkovi.bioquiz"
        MACOSX_BUNDLE_BUNDLE_NAME "BioQuiz"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${BIOQUIZ_VERSION}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${BIOQUIZ_VERSION_CODE}"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    )
    set_target_properties(bioquiz PROPERTIES OUTPUT_NAME BioQuiz)
    # The catalogue next to the executable inside the .app (applicationDirPath()/data),
    # and the icons as plain files (CFBundleIconFiles in Info.plist.in).
    file(GLOB BIOQUIZ_IOS_ICONS "${BIOQUIZ_ROOT}/ios/icons/*.png")
    add_custom_command(TARGET bioquiz POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${BIOQUIZ_ROOT}/data" "$<TARGET_BUNDLE_CONTENT_DIR:bioquiz>/data"
        COMMAND ${CMAKE_COMMAND} -E copy ${BIOQUIZ_IOS_ICONS} "$<TARGET_BUNDLE_CONTENT_DIR:bioquiz>/")
elseif(APPLE)
    # macOS: BioQuiz.app with the catalogue in Contents/Resources/data. The
    # public build carries the sample questions; the full catalogue is put
    # in afterwards (tools/apple-fill.sh) and the bundle signed again.
    set_source_files_properties("${BIOQUIZ_ROOT}/macos/bioquiz.icns" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(bioquiz PRIVATE "${BIOQUIZ_ROOT}/macos/bioquiz.icns")
    set_target_properties(bioquiz PROPERTIES
        OUTPUT_NAME BioQuiz
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${BIOQUIZ_ROOT}/macos/Info.plist.in"
        MACOSX_BUNDLE_GUI_IDENTIFIER "org.smatkovi.bioquiz"
        MACOSX_BUNDLE_BUNDLE_NAME "BioQuiz"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${BIOQUIZ_VERSION}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${BIOQUIZ_VERSION_CODE}"
    )
    add_custom_command(TARGET bioquiz POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${BIOQUIZ_ROOT}/data" "$<TARGET_BUNDLE_CONTENT_DIR:bioquiz>/Resources/data")
elseif(WIN32)
    # One portable BioQuiz.exe: static Qt, and the question catalogue with its
    # pictures compiled in as a resource (read from :/data).
    set_target_properties(bioquiz PROPERTIES WIN32_EXECUTABLE TRUE OUTPUT_NAME BioQuiz)
    target_sources(bioquiz PRIVATE ${BIOQUIZ_ROOT}/windows/bioquiz.rc)
    target_compile_definitions(bioquiz PRIVATE BIOQUIZ_EMBEDDED_DATA)
    file(GLOB_RECURSE BIOQUIZ_DATA_FILES "${BIOQUIZ_ROOT}/data/*")
    qt_add_resources(bioquiz bioquiz_data PREFIX "/" BASE "${BIOQUIZ_ROOT}"
        FILES ${BIOQUIZ_DATA_FILES} BIG_RESOURCES)
else()
    # Desktop and AppImage: data/ next to the executable.
    add_custom_command(TARGET bioquiz POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E create_symlink "${BIOQUIZ_ROOT}/data" "$<TARGET_FILE_DIR:bioquiz>/data")
endif()

# Static builds (Windows) link the QML plugins the shared QML imports, and
# the WebP reader for the pictures. The QML lives in ../qml, outside the
# directory the import scanner looks at by default.
set_target_properties(bioquiz PROPERTIES QT_QML_ROOT_PATH "${BIOQUIZ_ROOT}/qml")
get_target_property(BIOQUIZ_QTCORE_TYPE Qt6::Core TYPE)
if(BIOQUIZ_QTCORE_TYPE STREQUAL "STATIC_LIBRARY")
    # The automatic import scan finds nothing for QML outside this folder,
    # so the plugins of the imports in ../qml are named here (see main.cpp).
    target_link_libraries(bioquiz PRIVATE Qt6::qtquick2plugin Qt6::qmlplugin Qt6::modelsplugin
                                          Qt6::workerscriptplugin Qt6::quickwindow)
    target_compile_definitions(bioquiz PRIVATE BIOQUIZ_STATIC_QML)
    if(TARGET Qt6::QWebpPlugin)
        qt_import_plugins(bioquiz INCLUDE Qt6::QWebpPlugin)
    endif()
endif()
