.. This Source Code Form is subject to the terms of the Mozilla Public
.. License, v. 2.0. If a copy of the MPL was not distributed with this
.. file, You can obtain one at http://mozilla.org/MPL/2.0/.

Serial printer alert `alert/serial_printer`
==========================================

Description
^^^^^^^^^^^

This module will output all alerts on printer connected to a given serial port.

Parameters
^^^^^^^^^^

.. describe:: port

    Serial port used to communicate with printer.

.. describe:: baudrate

    Line speed in bits per seconds.
    Default to `9600`.

.. describe:: params

    Number of data bits, parity and stop bits.
    Default to `8N1`.
    
.. describe:: hw

    Hardware control flow
    Default to `N`.

Example :

.. code-block:: ini

    port = "/dev/ttyUSB0"
    baudrate = 115200
    params = 8N1
    hw = Y
