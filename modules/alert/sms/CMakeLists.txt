# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

find_package(Gammu)

if(GAMMU_FOUND)
	add_library(alert-sms MODULE main.c)
	include_directories(${GAMMU_INCLUDE_DIRS}/gammu)

	target_link_libraries(alert-sms LINK_PRIVATE ${LIBGAMMU_LIBRARY})

	set_target_properties(alert-sms PROPERTIES OUTPUT_NAME sms)
	INSTALL_MODULE(alert-sms alert)
endif()
