#define SURFACE_NATIVE_TEST
#include "../../vitis/surface/src/main.c"
#include <assert.h>
#include <stdio.h>
static int calls;
static uint32_t decode_test(const uint8_t *data,unsigned bytes){
 calls++; if(!bytes) return 0;
 assert(bytes==3 && data[0]==0x12 && data[1]==0x34 && data[2]==0x56);
 return (1u<<30)|(1u<<28)|98321;
}
int main(void){
 struct parser p={0}; uint8_t out[9];
 uint8_t packet[]={0xc3,0x25,3,0x12,0x34,0x56,0};
 for(int i=0;i<6;i++) packet[6]^=packet[i];
 for(int i=0;i<7;i++) assert(feed(&p,packet[i],i,out,decode_test)==(i==6));
 assert(calls==1 && out[0]==0x3c && out[1]==0x25 && out[2]==0 && out[3]==1);
 assert(((uint32_t)out[4]|(uint32_t)out[5]<<8|(uint32_t)out[6]<<16|(uint32_t)out[7]<<24)==98321);
 uint8_t xor=0;for(int i=0;i<9;i++) xor^=out[i]; assert(!xor);
 for(int i=0;i<7;i++) assert(!feed(&p,i==6?packet[i]^1:packet[i],10+i,out,decode_test));
 for(int i=0;i<7;i++) assert(feed(&p,packet[i],20+i,out,decode_test)==(i==6));
 assert(!feed(&p,0xc3,30,out,decode_test));assert(!feed(&p,0x25,31,out,decode_test));
 for(int i=0;i<7;i++) assert(feed(&p,packet[i],100+i,out,decode_test)==(i==6));
 uint8_t reset[]={0xc3,0x28,0,0xeb};
 for(int i=0;i<4;i++) assert(feed(&p,reset[i],110+i,out,decode_test)==(i==3));
 assert(calls==4); puts("PASS surface firmware framing 24-bit input/32-bit cycles/checksum/recovery/reset");
}
