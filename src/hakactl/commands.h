
#ifndef _COMMANDS_H
#define _COMMANDS_H

enum {
	COMMAND_SUCCESS       = 0,
	COMMAND_FAILED        = 1,
};

struct command {
	char  *name;
	char  *help;
	int    nb_args;
	int  (*run)(int fd, int argc, char *argv[]);
};

extern struct command command_status;
extern struct command command_stop;
extern struct command command_stat;
extern struct command command_logs;
extern struct command command_loglevel;
extern struct command command_debug;
extern struct command command_interactive;

extern bool use_colors;

#endif /* _COMMANDS_H */
