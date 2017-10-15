/*
 * ANDES Lab - University of California, Merced
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
#include "includes/Pair.h"
#include "includes/LinkState.h"
//created new data structure

module Node {
   uses interface Boot;
   uses interface Timer<TMilli> as periodicTimer;
   uses interface Hashmap<uint16_t> as neighborMap;
   uses interface List<uint16_t> as neighborList;
   uses interface List<pair> as floodingList;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface Random;

   //use methods from this interface
   uses interface SimpleSend as Sender;

   
  uses interface SimpleSend as FloodSender;
  uses interface Receive as FloodReceive;

  uses interface Receive as FloodReplyReceive;

  uses interface CommandHandler;
}

implementation {
   uint16_t seq_num = 0;
   pack sendPackage;
   pair Pair;
   LinkStatePack LSPack; 

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void makePair(pair *pingPair, uint16_t src, uint16_t seq);
   void handleNeighborDiscovery(message_t* msg, void* payload);
   void beginNeighborDiscovery();

   event void Boot.booted(){
      int c, i;
      // infinity
      int sentinel = -1;
      call AMControl.start();
      
      for (c = 0; c < PACKET_MAX_PAYLOAD_SIZE; c++) LSPack.neighbors[c] = sentinel;

      // upon startup, initializing topology matrix values to be 0 before inserting src and the adjacent vertices
      for (c = 0; c < PACKET_MAX_PAYLOAD_SIZE; c++) {
        for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
          topologyMatrix[c][i] = sentinel;
        }
      }

      // dbg(GENERAL_CHANNEL, "Booted\n");
      //once we boot, start periodic timer to discover neighbors
      call periodicTimer.startPeriodic(call Random.rand16() % 999);
      //put a random interval
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         // dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
      // dbg(GENERAL_CHANNEL, "Packet Received!\n");
      if(len == sizeof(pack)) {
         pack* message=(pack*) payload;
         logPack(message);
         // dbg(GENERAL_CHANNEL, "Package Payload: %s\n", message->payload);
           if (message->protocol == PROTOCOL_PING) {  
             if (message->src == TOS_NODE_ID) {
               return msg;
             }
             if (message->dest == TOS_NODE_ID) {
               // dbg(GENERAL_CHANNEL, "PING Reply initiated\n");
               seq_num++;
               makePack(&sendPackage, TOS_NODE_ID, message->src, MAX_TTL, PROTOCOL_PINGREPLY, seq_num, payload, PACKET_MAX_PAYLOAD_SIZE);
               call Sender.send(sendPackage, AM_BROADCAST_ADDR);
               return msg;
             }
             if (message->TTL <= 0) {
               // dbg(GENERAL_CHANNEL, "\n\tpacket dropped\n\n");
               return msg;
             }
             if (!(call floodingList.isEmpty())) {
               uint16_t c;
               for (c = 0; c < call floodingList.size(); c++) {
                 pair pingPair = call floodingList.get(c);
                 if (pingPair.src == message->src && pingPair.seq == message->seq) {
                   // dbg(GENERAL_CHANNEL, "\n\tpacked dropped\n\n");
                   return msg;
                 }
               }
             }
             message->TTL--;
             makePair(&Pair, message->src, message->seq);
             call floodingList.pushback(Pair);
             // dbg(GENERAL_CHANNEL, "List of pairs: \n\n");
             printf("List pair-> src: %i, seq: %i\n\n", (call floodingList.front()).src, (call floodingList.front()).seq);
             call Sender.send(*message, AM_BROADCAST_ADDR);
             return msg;
           }
          if (message->protocol == PROTOCOL_PINGREPLY) { 
             // dbg(GENERAL_CHANNEL, "Protocol is PING_REPLY\n");
             if (message->src == TOS_NODE_ID) {
               // dbg(GENERAL_CHANNEL, "Not going to send packet back out, I'm the source node.\n");
               return msg;
             }
             if (message->dest == TOS_NODE_ID) {
               // dbg(GENERAL_CHANNEL, "\n\tACK\n\n");
               return msg;
             }
             if (message->TTL <= 0) {
               // dbg(GENERAL_CHANNEL, "packet dropped\n");
               return msg;
             }
             if (!(call floodingList.isEmpty())) {
               uint16_t c;
               // dbg(GENERAL_CHANNEL, "\n\twe are inside if statement of list NOT empty.\n\n");
               for (c = 0; c < call floodingList.size(); c++) {
                 pair pingPair = call floodingList.get(c);
                 if (pingPair.src == message->src && pingPair.seq == message->seq) {
                   // dbg(GENERAL_CHANNEL, "\n\tWe have seen package before, drop it.\n\n");
                   return msg;
                 }
               }
             }
             message->TTL -= 1;
             makePair(&Pair, message->src, message->seq);
             call floodingList.pushback(Pair);
             // dbg(GENERAL_CHANNEL, "List of pairs: \n\n");
             printf("List pair-> src: %i, seq: %i\n\n", (call floodingList.front()).src, (call floodingList.front()).seq);
             call Sender.send(*message, AM_BROADCAST_ADDR);
             return msg;
          }  
           if (message->protocol == PROTOCOL_NEIGHBOR_DUMP) {
             handleNeighborDiscovery(msg, payload);
             return msg;
         }
      }
      // dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload) {
      // dbg(GENERAL_CHANNEL, "PING EVENT for Node %hhu \n", TOS_NODE_ID);
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seq_num, payload, PACKET_MAX_PAYLOAD_SIZE);
      seq_num++;
      
      /* broadcast to next hop NOT to all neighbors*/
      call Sender.send(sendPackage, AM_BROADCAST_ADDR/*Router.nextHop*/); 
   }

   event void CommandHandler.printNeighbors() {
     call neighborList.printList();
   }

   event void periodicTimer.fired() {
    //  while (!(call neighborList.isEmpty())) call neighborList.popback();
    beginNeighborDiscovery();
    return;
   }

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

   void makePair(pair *pingPair, uint16_t src, uint16_t seq) {
      pingPair->src = src;
      pingPair->seq = seq;
   }

   void handleNeighborDiscovery(message_t* msg, void* payload) {
     pack* message=(pack*) payload;
     if (message->src == TOS_NODE_ID) {
       call neighborList.pushback(message->dest);
       // dbg(NEIGHBOR_CHANNEL, "Neighbors of Node (%i):\n", TOS_NODE_ID);
       printf("Neighbors of Node (%i):\n", TOS_NODE_ID);
       call neighborList.printList();
       return;
     }
     message->dest = TOS_NODE_ID;
     // dbg(NEIGHBOR_CHANNEL, "Current Node: (%i), sending to source: (%i)\n", TOS_NODE_ID, message->src);
     call Sender.send(*message, message->src);
     return;
   }

   void beginNeighborDiscovery() {
     makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_NEIGHBOR_DUMP, seq_num, "NEIGHBOR_DUMP", PACKET_MAX_PAYLOAD_SIZE);
     seq_num++;
     call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
}
