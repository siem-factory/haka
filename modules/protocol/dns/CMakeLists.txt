# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

lua_compile(NAME dns FILES dns.lua)
lua_install(TARGET dns DESTINATION ${MODULE_INSTALL_PATH}/protocol)

# Tests
add_subdirectory(test)
