#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

#include <haka/alert_module.h>
#include <haka/colors.h>
#include <haka/error.h>

// https://www.cmrr.umn.edu/~strupp/serial.html#2_5
//https://en.wikibooks.org/wiki/Serial_Programming/termios

const char *device = "/dev/ttyS0";

struct serial_alerter {
	struct alerter_module module;
	int printer;
	bool color;
	struct termios options;
};

static int init(struct parameters *args)
{
	return 0;
}

static bool write_to_printer(struct serial_alerter *alerter, uint64 id, const struct time *time, const struct alert *alert, bool update)
{
	fprintf(alerter->printer, "alert: %s%s\n",
	        update ? "update " : "", alert_tostring(id, time, alert, "", " ", false));
	return true;
}

static bool do_alert(struct alerter *state, uint64 id, const struct time *time, const struct alert *alert)
{
	return write_to_printer((struct serial_alerter *)state, id, time, alert, false);
}

static bool do_alert_update(struct alerter *state, uint64 id, const struct time *time, const struct alert *alert)
{
	return write_to_printer((struct serial_alerter *)state, id, time, alert, true);
}

struct alerter_module *init_alerter(struct parameters *args)
{
	struct serial_alerter *serial_alerter = malloc(sizeof(struct serial_alerter));
	if (!serial_alerter) {
		error("Memory error");
		return NULL;
	}

	const char *device = parameters_get_string(args, "port", NULL);
	const char *params = parameters_get_string(args, "params", "8N1");
	const int speed = parameters_get_integer(args, "baudrate", 9600);

	serial_alerter->printer = open(device, O_WRONLY | O_NOCTTY | O_NDELAY);
	if (serial_alerter->printer == -1) {
		error("Cannot open serial port '%s' for alert", device);
		return NULL;
	}

	if (sscanf(params, "%i", &data_bits) != 1)
		error = 1;
	if (sscanf(params, "%c", &parity) != 1)
		error = 1;
	if (sscanf(params, "%i", &stop_bits) != 1)
		error = 1;

	if (error != 0) {
		error("Wrong serial port parameters: %s", params);
		return NULL;
	}
	sprintf(message, "device=%s (%li, %i%i%i)\r\n", device, speed);

	/*
	 * Get the current options for the port.
	 */
	if (tcgetattr(serial_alerter->printer, &serial_alerter->options) < 0) {
		error("Cannot retrieve serial %s port options.", serial_alerter->printer);
		return NULL;
	}

	speed_t baud_rate;
	switch (speed) {
		case 38400:
			baud_rate = B38400;
			break;
		case 19200:
			baud_rate = B19200;
			break;
		case 9600:
		default:
			baud_rate = B9600;
			break;
		case 4800:
			baud_rate = B4800;
			break;
		case 2400:
			baud_rate = B2400;
			break;
		case 1800:
			baud_rate = B1800;
			break;
		case 1200:
			baud_rate = B1200;
			break;
		case 600:
			baud_rate = B600;
			break;
		case 300:
			baud_rate = B300;
			break;
		case 200:
			baud_rate = B200;
			break;
		case 150:
			baud_rate = B150;
			break;
		case 134:
			baud_rate = B134;
			break;
		case 110:
			baud_rate = B110;
			break;
		case 75:
			baud_rate = B75;
			break;
		case 50:
			baud_rate = B50;
			break;
	} // end of switch speed

	switch (data_bits) {
		case 5:
			options.c_cflag |= CS5;
			break;
		case 6:
			options.c_cflag |= CS6;
			break;
		case 7:
			options.c_cflag |= CS7;
			break;
		case 8:
		default:
			options.c_cflag |= CS8;
			break;
	} // end of switch data_bits

	switch (parity) {
		case 'N': // None
		default:
			options.c_cflag &= ~PARENB;
			options.c_cflag &= ~PARODD;
			break;
		case 'E': // Even
			options.c_cflag |= PARENB;
			break;
		case 'O': // Odd
			options.c_cflag |= PARENB | PARODD;
			break;
	} // end of stop

	switch (stop_bits) {
		case 1:
		default:
			options.c_cflag &= ~CSTOPB;
			break;
		case 2:
			options.c_cflag |= CSTOPB;
			break;
	} // end of stop_bits

	// set the new options for the port
	tcsetattr(serial_alerter->printer, TCSANOW, &options); 

	serial_alerter->color = colors_supported(serial_alerter->printer);

	return &serial_alerter->module;
}

void cleanup_alerter(struct alerter_module *module)
{
	struct serial_alerter *alerter = (struct serial_alerter *)module;

	fclose(alerter->printer);

	free(alerter);
}

struct alert_module HAKA_MODULE = {
	module: {
		type:        MODULE_ALERT,
		name:        "Serial printer alert",
		description: "Alert output to serial printer",
		api_version: HAKA_API_VERSION,
		init:        init,
		cleanup:     cleanup
	},
	init_alerter:    init_alerter,
	cleanup_alerter: cleanup_alerter
};
