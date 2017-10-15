# ifndef __PAIR__
# define __PAIR__

enum{
    MAX_NODES_FLOODED = 19
};

typedef struct pair {
	uint16_t src;
    uint16_t seq;
} pair;
# endif