# ifndef __LINKSTATE__
# define __LINKSTATE__

# include "packet.h"

typedef struct {
	uint16_t dest;
	uint16_t src;	    
	uint16_t seq;		
	uint8_t TTL;		    
	uint8_t protocol;
    uint8_t neighbors[PACKET_MAX_PAYLOAD_SIZE];    
} LinkStatePack;

typedef struct {
     uint16_t  Destination;   
     uint16_t  nextHop;       
    //  uint8_t  Cost;      /* metric */
} Router;

void makeRoutingPack(LinkStatePack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t *neighbors) {
    Package->src = src;
    Package->dest = dest;
    Package->TTL = TTL;
    Package->seq = seq;
    Package->protocol = protocol;
    memcpy(Package->neighbors, neighbors, PACKET_MAX_PAYLOAD_SIZE);
}

uint16_t topologyMatrix[PACKET_MAX_PAYLOAD_SIZE][PACKET_MAX_PAYLOAD_SIZE];

# endif