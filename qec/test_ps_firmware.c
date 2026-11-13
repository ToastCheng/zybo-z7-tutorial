#define QEC_NATIVE_TEST
#include "../vitis/qec/src/main.c"
#include <assert.h>
#include <stdio.h>
static int calls;
static uint32_t decode(uint8_t s){calls++; assert(s==0x37); return (7u<<2)|2u;}
int main(void){
 struct parser p={0}; uint8_t out[6];
 uint8_t packet[]={0xa5,0x42,0x37,0xd0};
 for(int i=0;i<3;i++) assert(!feed(&p,packet[i],i,out,decode));
 assert(feed(&p,packet[3],3,out,decode));
 assert(calls==1 && out[0]==0x5a && out[1]==0x42 && out[2]==1 && out[3]==7 && out[4]==0);
 assert((out[0]^out[1]^out[2]^out[3]^out[4]^out[5])==0);
 /* Bad checksum must not decode, and next valid frame must recover. */
 for(int i=0;i<4;i++) assert(!feed(&p,i==3?0:packet[i],10+i,out,decode));
 for(int i=0;i<4;i++) {int got=feed(&p,packet[i],20+i,out,decode); assert(got==(i==3));}
 /* Abandoned partial packet expires after 50 ms. */
 assert(!feed(&p,0xa5,30,out,decode)); assert(!feed(&p,0x42,31,out,decode));
 for(int i=0;i<4;i++) {int got=feed(&p,packet[i],100+i,out,decode); assert(got==(i==3));}
 assert(calls==3); puts("PASS PS firmware frame/checksum/recovery/timeout");
}
