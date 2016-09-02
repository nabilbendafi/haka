# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

find_path(GAMMU_INCLUDE_DIRS NAMES gammu/gammu.h)
find_library(LIBGAMMU_LIBRARY NAMES libGammu.so)

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(Gammu
	DEFAULT_MSG GAMMU_INCLUDE_DIRS LIBGAMMU_LIBRARY)
