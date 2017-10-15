/* ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/Flooding_struct.h"

module Node {
   uses interface Boot;
   uses interface Timer<TMilli> as periodicTimer;
   uses interface Hashmap<uint16_t>;
   uses interface List<uint16_t>;
   uses interface List<tuple> as myTuple;
   uses interface SplitControl as AMControl;
   uses interface Receive;

   //use methods from this interface
   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
}

implementation {
   pack sendPackage;
   int seqNum = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void handleNeighborDiscovery(message_t* msg, void* payload);
   void beginNeighborDiscovery();

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");

   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){


      dbg(GENERAL_CHANNEL, "Packet Received\n");

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         logPack(myMsg);

         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);



         switch(myMsg->protocol) {
           case PROTOCOL_PING:
             dbg(GENERAL_CHANNEL, "Protocol is PING\n");

             if (myMsg->src == TOS_NODE_ID) {
               dbg(GENERAL_CHANNEL, "Not going to send packet back out, I'm the source node.\n");
               return msg;
             }
             //otherwise, check destination
             if (myMsg->dest == TOS_NODE_ID) {
               dbg(GENERAL_CHANNEL, "Going to ping reply back to the source.\n");
               dbg(GENERAL_CHANNEL, "\n\nPACKAGE ARRIVED AT PROPER DESTINATION: Current Node: (%i)\n\n", TOS_NODE_ID);
               dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
               dbg(GENERAL_CHANNEL, "Going to ping reply back to the source.\n");
               makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, seqNum++, payload, PACKET_MAX_PAYLOAD_SIZE);
               return msg;
             }

             if (myMsg->TTL <= 0) {
               //drop packet
               dbg(GENERAL_CHANNEL, "TTL dropped to 0, drop packet.\n");
               return msg;
             }

	     // if (myMsg->seqNum ==  ) {

             //    dbg(GENERAL_CHANNEL, "I have already received this packet -- going to send to another channel.\n");

             // }

             //send packet to all neighbors again
             dbg(GENERAL_CHANNEL, "Package not meant for my ID: (%i)\n", TOS_NODE_ID);
             myMsg->TTL--;
	     // call List.pushback();
             call Sender.send(*myMsg, AM_BROADCAST_ADDR);



           case PROTOCOL_PINGREPLY:
            dbg(GENERAL_CHANNEL, "Protocol is PINGREPLY\n");
	     if (myMsg->src == TOS_NODE_ID) {
		dbg(GENERAL_CHANNEL, "I'm the source.\n");
	     }
		
	     if (myMsg->dest == TOS_NODE_ID) {
		dbg(GENERAL_CHANNEL, "Finally acknowledged.\n");
	     }

             // if (myMsg->seqNum ==  ) {

             //    dbg(GENERAL_CHANNEL, "I have already received this packet -- going to send to another channel.\n");

             // } 
         }
      }

      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){

      dbg(GENERAL_CHANNEL, "PING EVENT for Node %hhu \n", TOS_NODE_ID);

      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
      seqNum++;

      logPack(&sendPackage);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR); //sends to all neighbors

   }

   event void periodicTimer.fired() {

     beginNeighborDiscovery();
     return;
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   void handleNeighborDiscovery(message_t* msg, void* payload) {
     pack* myMsg=(pack*) payload;
     //first if statement is for source node
     if (myMsg->src == TOS_NODE_ID) {
       call List.pushback(myMsg->dest);
       printf("Neighbors of Node (%i):\n", TOS_NODE_ID);
       //dbg(NEIGHBOR_CHANNEL, "Neighbors of Node (%i):", TOS_NODE_ID);
       return;
     }
     myMsg->dest = TOS_NODE_ID;
     dbg(NEIGHBOR_CHANNEL, "Current Node: (%i), sending to source: (%i)\n", TOS_NODE_ID, myMsg->src);
     call Sender.send(*myMsg, myMsg->src);
     return;
   }

   void beginNeighborDiscovery() {
     makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, 7, 0, "hi", PACKET_MAX_PAYLOAD_SIZE);
     call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
}

