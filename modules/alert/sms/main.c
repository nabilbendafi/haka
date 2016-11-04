/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <haka/alert_module.h>
#include <haka/log.h>
#include <haka/error.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <gammu/gammu.h>

#define BODY_SIZE	2048

static REGISTER_LOG_SECTION(sms);
GSM_StateMachine *state_machine;

struct sms {
	char *body;
	size_t size;
};

struct sms_alerter {
	struct alerter_module module;
	char *port;
	char *pin;
	char *recipients;
};

static int init(struct parameters *args)
{
	return 0;
}

static void cleanup()
{
	;
}

/* Function to handle errors */
static bool error_handler(GSM_Error error)
{
	if (error != ERR_NONE) {
		LOG_ERROR(sms, "%s\n", GSM_ErrorString(error));
		if (GSM_IsConnected(state_machine))
			GSM_TerminateConnection(state_machine);
		return true;
	}
}

static bool send_sms(struct sms_alerter *state, uint64 id, const struct time *time, const struct alert *alert, bool update)
{
	GSM_SMSMessage sms;
	GSM_Debug_Info *debug_info;
	GSM_Error error;
	int return_value = 0;

	struct sms_alerter *alerter = (struct sms_alerter *)state;

	if (0) {
		LOG_ERROR(sms, "sms failed\n");
		return false;
	}

	GSM_InitLocales(NULL);

	/* Message body */
	char body[BODY_SIZE];
	snprintf(body, BODY_SIZE, "Subject: [Haka] alert: %s%s\r\n",
		update ? "update " : "", alert_tostring(id, time, alert, "", " ", false));

	if (getlevel("sms") == HAKA_LOG_DEBUG) {
		/* Enable global debugging */
		debug_info = GSM_GetGlobalDebug();
		GSM_SetDebugFileDescriptor(stderr, TRUE, debug_info);
		GSM_SetDebugLevel("textall", debug_info);
	}

	/* Allocates state machine */
	state_machine = GSM_AllocStateMachine();
	if (state_machine == NULL)
		return false;

	/* We have one valid configuration */
	GSM_SetConfigNum(state_machine, 1);

	/* Connect to phone */
	error = GSM_InitConnection(state_machine, 1);
	if (error_handler(error))
		return false;

	/* Prepare message */
	/* Cleanup the structure */
	memset(&sms, 0, sizeof(sms));
	/* Encode message text */
	EncodeUnicode(sms.Text, body, strlen(body));
	/* We want to submit message */
	sms.PDU = SMS_Submit;
	/* No UDH, just a plain message */
	sms.UDH.Type = UDH_NoUDH;
	/* We used default coding for text */
	sms.Coding = SMS_Coding_Default_No_Compression;
	/* Class 1 message (normal) */
	sms.Class = 1;
	
	char *recipient;
	while ((recipient = strtok((char *)alerter->recipients, ",")) != NULL) {
		/* Encode recipient number */
		EncodeUnicode(sms.Number, recipient, strlen(recipient));

		/* Send the message */
		error = GSM_SendSMS(state_machine, &sms);
		if (error_handler(error))
			return false;

		/* Wait for network reply */
		while (!gshutdown) {
			GSM_ReadDevice(state_machine, TRUE);
			if (sms_send_status == ERR_NONE) {
				/* Message sent OK */
				return_value = 0;
				break;
			}
			if (sms_send_status != ERR_TIMEOUT) {
				/* Message sending failed */
				return_value = 100;
				break;
			}
		}
	}

	/* Terminate connection */
	error = GSM_TerminateConnection(state_machine);
	if (error_handler(error))
		return false;

	/* Free up used memory */
	GSM_FreeStateMachine(state_machine);

	return true;
}

static bool do_alert(struct alerter *state, uint64 id, const struct time *time, const struct alert *alert)
{
	return send_sms((struct sms_alerter *)state, id, time, alert, false);
}

static bool do_alert_update(struct alerter *state, uint64 id, const struct time *time, const struct alert *alert)
{
	return send_sms((struct sms_alerter *)state, id, time, alert, true);
}

struct alerter_module *init_alerter(struct parameters *args)
{
	struct sms_alerter *sms_alerter = malloc(sizeof(struct sms_alerter));
	if (!sms_alerter) {
		error("memory error");
		return NULL;
	}

	sms_alerter->module.alerter.alert = do_alert;
	sms_alerter->module.alerter.update = do_alert_update;

	/* Mandatory fields: device port, recipient phone number*/
	const char *port = parameters_get_string(args, "port", NULL);
	const char *pin = parameters_get_string(args, "pin", NULL);
	const char *recipients = parameters_get_string(args, "recipient", NULL);
	//const char *connection = "at"; /* Only 'at' supported, yet !*/

	if (!port || !recipients) {
		error("missing mandatory field");
		free(sms_alerter);
		return NULL;
	}

	sms_alerter->port = strdup(port);
	sms_alerter->recipients = strdup(recipients);

	if (!sms_alerter->port || !sms_alerter->recipients) {
		error("memory error");
		free(sms_alerter);
		return NULL;
	}

	sms_alerter->pin = strdup(pin);

	return &sms_alerter->module;
}

void cleanup_alerter(struct alerter_module *module)
{
	struct sms_alerter *alerter = (struct sms_alerter *)module;

	free(alerter);
}

struct alert_module HAKA_MODULE = {
	module: {
	        type:        MODULE_ALERT,
	        name:        "SMS alert",
	        description: "Alert output as SMS",
	        api_version: HAKA_API_VERSION,
	        init:        init,
	        cleanup:     cleanup
	},
	init_alerter:    init_alerter,
	cleanup_alerter: cleanup_alerter
};
