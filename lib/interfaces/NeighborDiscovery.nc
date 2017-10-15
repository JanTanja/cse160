# define AM_NEIGHBOR 19

configuration NeighborDiscoveryC {
	provides interface NeighborDiscovery;
}

implementation {
	components NeighborDiscoveryP;
	components new TimerMilliC() as TimerC;
	components new SimpleSendC(AM_NEIGHBOR);
    components new AMReceiverC(AM_NEIGHBOR);
/* ------------------- Wiring ----------------------*/
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;
/* -------------- Internal Wiring -----------------*/
	NeighborDiscoveryP.Sender->SimpleSendC;
	NeighborDiscoveryP.Receive->AMReceiverC;
	NeighborDiscoveryP.TimerC->TimerC;
}