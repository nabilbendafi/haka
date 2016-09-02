/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <haka/alert_module.h>
#include <haka/log.h>
#include <haka/error.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gammu/gammu.h>
#include <unistd.h>

#define BODY_SIZE	2048

static REGISTER_LOG_SECTION(sms);

struct sms {
	char *body;
	size_t size;
};

struct sms_alerter {
	struct alerter_module module;
	char *port;
	char *recipients;
};

struct sms sms_ctx;

static int init(struct parameters *args)
{
	return 0;
}

static void cleanup()
{
	;
}

static bool send_sms(struct sms_alerter *state, uint64 id, const struct time *time, const struct alert *alert, bool update)
{
	if (0) {
		LOG_ERROR(sms, "sms failed\n");
		return false;
	}

	/* Message body */
	char body[BODY_SIZE];
	snprintf(body, BODY_SIZE, "Subject: [Haka] alert: %s%s\r\n",
		update ? "update " : "", alert_tostring(id, time, alert, "", " ", false));

	if (getlevel("sms") == HAKA_LOG_DEBUG)
		;

	/* Send the message */

	/* Check for errors */

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
	const char *recipients = parameters_get_string(args, "recipient", NULL);
	//const char *pin = parameters_get_string(args, "pin", NULL);
	//const char *connection = "at";

	if (!port || !recipients) {
		error("missing mandatory field");
		free(sms_alerter);
		return NULL;
	}

	char *recipient;
	while ((recipient = strtok((char *)recipients, ",")) != NULL)
		sms_alerter->recipients = recipient;

	if (!sms_alerter->port || !sms_alerter->recipients) {
		error("memory error");
		free(sms_alerter);
		return NULL;
	}

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
