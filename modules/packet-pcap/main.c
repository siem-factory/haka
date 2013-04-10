
#include <haka/packet_module.h>
#include <haka/log.h>

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <pcap.h>
#include <string.h>

/* snapshot length - a value of 65535 is sufficient to get all
 * of the packet's data on most netwroks (from pcap man page)
 */
#define SNAPLEN 65535

struct packet {
	struct pcap_pkthdr header;
	char data[0];
};

static pcap_t *pd;

static int init(int argc, char *argv[])
{
	if (argc == 2) {
		char errbuf[PCAP_ERRBUF_SIZE] = {'0'};

		/* get a pcap descriptor from device */
		if (strcmp(argv[0], "-i") == 0) {
			pd = pcap_open_live(argv[1], SNAPLEN, 1, 0, errbuf);
			if (!pd) {
				messagef(LOG_ERROR, L"pcap", L"%s", errbuf);
				return 1;
			}
			if(strlen(errbuf) != 0 ) {
				 messagef(LOG_WARNING, L"pcap", L"%s", errbuf);
			}
		}
		/* get a pcap descriptor from a pcap file */
		else if (strcmp(argv[0], "-f") == 0) {
			pd = pcap_open_offline(argv[1], errbuf);
			if (!pd) {
				messagef(LOG_ERROR, L"pcap", L"%s", errbuf);
				return 1;
			}
		}
		else {
			messagef(LOG_ERROR, L"pcap", L"unkown options");
			return 1;
		}
	}
	else {
		messagef(LOG_ERROR, L"pcap", L"specify a device (-i) or a pcap filename (-f)");
		return 1;
	}
	return 0;
}

static void cleanup()
{
	pcap_close(pd);
}

static int packet_receive(struct packet **pkt)
{
	struct pcap_pkthdr header;
	struct packet *packet = NULL;
	const u_char *p;	
	
	/* read packet */
	p = pcap_next(pd, &header);

	if (p)
	{
		packet = malloc(sizeof(struct packet) + header.caplen);
		if (!packet) {
			return ENOMEM;
		}

		/* fill packet data structure */
		memcpy(packet->data, p, header.caplen);
		packet->header = header;

		if (packet->header.caplen < packet->header.len)
			messagef(LOG_WARNING, L"pcap", L"packet truncated");

		*pkt = packet;
	}

	return 0;
}

static void packet_verdict(struct packet *pkt, filter_result result)
{
	free(pkt);
}

static size_t packet_get_length(struct packet *pkt)
{
	return pkt->header.caplen;
}

static const char *packet_get_data(struct packet *pkt)
{
	return pkt->data;
}


struct packet_module HAKA_MODULE = {
	module: {
		type:        MODULE_PACKET,
		name:        L"Pcap Module",
		description: L"Pcap packet module",
		author:      L"Arkoon Network Security",
		init:        init,
		cleanup:     cleanup
	},
	receive:         packet_receive,
	verdict:         packet_verdict,
	get_length:      packet_get_length,
	get_data:        packet_get_data
};

