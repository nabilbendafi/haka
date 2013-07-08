
#ifndef _LUADEBUG_UTILS_H
#define _LUADEBUG_UTILS_H

#define CLEAR   "\e[0m"
#define BOLD    "\e[1m"
#define BLACK   "\e[30m"
#define RED     "\e[31m"
#define GREEN   "\e[32m"
#define YELLOW  "\e[33m"
#define BLUE    "\e[34m"
#define MAGENTA "\e[35m"
#define CYAN    "\e[36m"
#define WHITE   "\e[37m"


struct lua_State;

int execute_print(struct lua_State *L);
int capture_env(struct lua_State *L, int frame);

#endif /* _LUADEBUG_UTILS_H */