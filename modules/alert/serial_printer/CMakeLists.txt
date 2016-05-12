# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

add_library(alert-serial_printer MODULE main.c)
set_target_properties(alert-serial_printer PROPERTIES OUTPUT_NAME serial_printer)
INSTALL_MODULE(alert-serial_printer alert)
