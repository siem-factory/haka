
set(INSTALL_DIR ${HAKA_INSTALL_PREFIX})

set(LUAJIT_CCDEBUG "")
set(LUAJIT_XCFLAGS -DLUAJIT_ENABLE_LUA52COMPAT)
if(CMAKE_BUILD_TYPE STREQUAL Debug)
	set(LUAJIT_XCFLAGS ${LUAJIT_XCFLAGS} -DLUAJIT_USE_GDBJIT -DLUA_USE_APICHECK -DLUAJIT_DISABLE_JIT -O0)
	set(LUAJIT_CCDEBUG -g)
elseif(CMAKE_BUILD_TYPE STREQUAL Memcheck)
	set(LUAJIT_XCFLAGS ${LUAJIT_XCFLAGS} -DLUAJIT_USE_VALGRIND -DLUAJIT_USE_GDBJIT -DLUA_USE_APICHECK -DLUAJIT_DISABLE_JIT -O0)
	set(LUAJIT_CCDEBUG -g)
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
	set(LUAJIT_XCFLAGS ${LUAJIT_XCFLAGS} -DLUAJIT_USE_GDBJIT -g)
	set(LUAJIT_CCDEBUG -g)
endif()

execute_process(COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/luajit)
execute_process(COMMAND echo CCDEBUG=${LUAJIT_CCDEBUG} XCFLAGS=${LUAJIT_XCFLAGS} PREFIX=${INSTALL_DIR} OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.tmp)
execute_process(COMMAND cmp ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.tmp ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.build
	RESULT_VARIABLE FILE_IS_SAME OUTPUT_QUIET ERROR_QUIET)
if(FILE_IS_SAME)
	execute_process(COMMAND cp ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.tmp ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.opt)
endif(FILE_IS_SAME)

add_custom_target(luajit-sync
	COMMAND rsync -rt ${CMAKE_CURRENT_SOURCE_DIR}/luajit ${CMAKE_CURRENT_BINARY_DIR}
)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.build
	COMMAND make -C ${CMAKE_CURRENT_BINARY_DIR}/luajit PREFIX=${INSTALL_DIR} clean
	COMMAND cp ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.opt ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.build
	MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.opt
	DEPENDS luajit-sync
)

add_custom_target(luajit
	COMMAND make -C ${CMAKE_CURRENT_BINARY_DIR}/luajit PREFIX=${INSTALL_DIR} BUILDMODE=dynamic CCDEBUG="${LUAJIT_CCDEBUG}" XCFLAGS="${LUAJIT_CFLAGS}"
	COMMAND make -C ${CMAKE_CURRENT_BINARY_DIR}/luajit LDCONFIG='/sbin/ldconfig -n' PREFIX=${INSTALL_DIR} BUILDMODE=dynamic CCDEBUG="${LUAJIT_CCDEBUG}" XCFLAGS="${LUAJIT_CFLAGS}"
		INSTALL_X='install -m 0755 -p' INSTALL_F='install -m 0644 -p' DESTDIR=${CMAKE_CURRENT_BINARY_DIR}/luajit/ install
	DEPENDS luajit-sync ${CMAKE_CURRENT_BINARY_DIR}/luajit/cmake.build
)

if(LUA STREQUAL "luajit")
	set(LUA_DIR ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR} PARENT_SCOPE)
	set(LUA_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/include/luajit-2.0 PARENT_SCOPE)
	set(LUA_LIBRARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/lib/ PARENT_SCOPE)
	set(LUA_LIBRARIES ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/lib/libluajit-5.1.so PARENT_SCOPE)
	
	set(LUA_COMPILER ${CMAKE_CURRENT_SOURCE_DIR}/luajitc -p "${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/" PARENT_SCOPE)
	set(LUA_FLAGS_NONE "-g" PARENT_SCOPE)
	set(LUA_FLAGS_DEBUG "-g" PARENT_SCOPE)
	set(LUA_FLAGS_MEMCHECK "-g" PARENT_SCOPE)
	set(LUA_FLAGS_RELEASE "-s" PARENT_SCOPE)
	set(LUA_FLAGS_RELWITHDEBINFO "-g" PARENT_SCOPE)
	set(LUA_FLAGS_MINSIZEREL "-s" PARENT_SCOPE)

	install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/lib DESTINATION ${INSTALL_DIR})
	install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/luajit/${INSTALL_DIR}/share DESTINATION ${INSTALL_DIR})
endif()
