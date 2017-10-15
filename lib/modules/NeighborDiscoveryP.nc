# include "../../includes/channels.h"
# include "../../includes/packet.h"

module NeighborDiscoveryP {
	uses interface Timer<TMilli> as TimerC;
	uses interface SimpleSend as Sender;
	uses interface Receive;
	provides interface NeighborDiscovery;
}

implementation {

   pack sendPackage;
   pair Pair;
   int seqNum = 0;

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void makePair(pair *pingPair, uint16_t src, uint16_t seq);
   void handleNeighborDiscovery(message_t* msg, void* payload);
   void beginNeighborDiscovery();

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
      call periodicTimer.startPeriodic(call Random.rand16() % 999);
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

	void handleNeighborDiscovery(message_t* msg, void* payload) {
		pack* myMsg=(pack*) payload;
		if (myMsg->src == TOS_NODE_ID) {
			call neighborList.pushback(myMsg->dest);
			printf("Neighbors of Node (%i):\n", TOS_NODE_ID);
			dbg(NEIGHBOR_CHANNEL, "Neighbors of Node (%i):\n", TOS_NODE_ID);
			call neighborList.printList();
			return;
		}
		myMsg->dest = TOS_NODE_ID;
		dbg(NEIGHBOR_CHANNEL, "Current Node: (%i), sending to source: (%i)\n", TOS_NODE_ID, myMsg->src);
		call Sender.send(*myMsg, myMsg->src);
		return;
	}

	event void periodicTimer.fired() {
		while (!(call neighborList.isEmpty())) {
			call neighborList.popback();
		}
		beginNeighborDiscovery();
		return;
	}

	void beginNeighborDiscovery() {
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_NEIGHDMP, seqNum, "testing", PACKET_MAX_PAYLOAD_SIZE);
		seqNum++;
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	}

}