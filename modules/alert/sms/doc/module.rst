.. This Source Code Form is subject to the terms of the Mozilla Public
.. License, v. 2.0. If a copy of the MPL was not distributed with this
.. file, You can obtain one at http://mozilla.org/MPL/2.0/.

Short Message Service alert `alert/sms`
=======================================

Description
^^^^^^^^^^^

This module will exports all alerts and send them as SMS.

Parameters
^^^^^^^^^^

.. describe:: port

    Communication device port. [Mandatory]

.. describe:: recipient

    SMS receiver phone number. [Mandatory]

.. describe:: pin

    SIM card pin code number. [Optional]

.. describe:: connection

    Connection type to modem. [Optional]
    .. note:: Only ``at`` is supported yet.

.. describe:: alert_level

    Minimum level of alert to be sent : LOW, MEDIUM or HIGH.


Example :

.. code-block:: ini

    [alert]
    # Select the alert module
    module = "alert/sms"

    # alert/sms module option - No pin code protected SIM card
    port = /dev/ttyUSB0
    connection = at
    recipient = "+4369919054018"

    # alert/sms module option - PIN code protected SIM card
    pin = 1234
    port = /dev/ttyUSB0
    connection = at
    recipient = "+41761234567,+4369919054018"
