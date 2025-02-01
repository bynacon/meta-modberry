cmake_minimum_required(VERSION 3.5 FATAL_ERROR)
project(libmbus VERSION 0.8.0 DESCRIPTION "RScada MBus library")

include_directories(. mbus)
file(GLOB LIBSOURCES mbus/*.c)
file(GLOB HEADERS mbus/*.h)

# Build library
add_library(mbus SHARED ${LIBSOURCES})
set_target_properties(mbus PROPERTIES VERSION ${PROJECT_VERSION})
target_link_libraries(mbus m)

# Build command line programs
add_executable(mbus-serial-request-data bin/mbus-serial-request-data.c)
target_link_libraries(mbus-serial-request-data mbus)

add_executable(mbus-serial-request-data-multi-reply bin/mbus-serial-request-data-multi-reply.c)
target_link_libraries(mbus-serial-request-data-multi-reply mbus)

add_executable(mbus-serial-scan bin/mbus-serial-scan.c)
target_link_libraries(mbus-serial-scan mbus)

add_executable(mbus-serial-scan-secondary bin/mbus-serial-scan-secondary.c)
target_link_libraries(mbus-serial-scan-secondary mbus)

add_executable(mbus-serial-select-secondary bin/mbus-serial-select-secondary.c)
target_link_libraries(mbus-serial-select-secondary mbus)

add_executable(mbus-serial-set-address bin/mbus-serial-set-address.c)
target_link_libraries(mbus-serial-set-address mbus)

add_executable(mbus-serial-switch-baudrate bin/mbus-serial-switch-baudrate.c)
target_link_libraries(mbus-serial-switch-baudrate mbus)


add_executable(mbus-tcp-application-reset bin/mbus-tcp-application-reset.c)
target_link_libraries(mbus-tcp-application-reset mbus)

add_executable(mbus-tcp-raw-send bin/mbus-tcp-raw-send.c)
target_link_libraries(mbus-tcp-raw-send mbus)

add_executable(mbus-tcp-request-data bin/mbus-tcp-request-data.c)
target_link_libraries(mbus-tcp-request-data mbus)

add_executable(mbus-tcp-request-data-multi-reply bin/mbus-tcp-request-data-multi-reply.c)
target_link_libraries(mbus-tcp-request-data-multi-reply mbus)

add_executable(mbus-tcp-scan bin/mbus-tcp-scan.c)
target_link_libraries(mbus-tcp-scan mbus)

add_executable(mbus-tcp-scan-secondary bin/mbus-tcp-scan-secondary.c)
target_link_libraries(mbus-tcp-scan-secondary mbus)

add_executable(mbus-tcp-select-secondary bin/mbus-tcp-select-secondary.c)
target_link_libraries(mbus-tcp-select-secondary mbus)

# Install library
install(TARGETS mbus DESTINATION lib)
install(FILES ${HEADERS} DESTINATION include/mbus)

# Install command line programs
install(TARGETS
    mbus-serial-request-data
    mbus-serial-request-data-multi-reply
    mbus-serial-scan
    mbus-serial-scan-secondary
    mbus-serial-select-secondary
    mbus-serial-set-address
    mbus-serial-switch-baudrate

    mbus-tcp-application-reset
    mbus-tcp-raw-send
    mbus-tcp-request-data
    mbus-tcp-request-data-multi-reply
    mbus-tcp-scan
    mbus-tcp-scan-secondary
    mbus-tcp-select-secondary
    DESTINATION bin)