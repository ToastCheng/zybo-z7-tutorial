#include <stdint.h>
#include <string.h>
struct parser { uint8_t b[4]; unsigned n; uint32_t last_ms; };
static int feed(struct parser *p, uint8_t byte, uint32_t ms, uint8_t out[6],
                uint32_t (*decode)(uint8_t)) {
 if((uint32_t)(ms-p->last_ms)>50) p->n=0;
 p->last_ms=ms;
 if(!p->n && byte!=0xa5) return 0;
 p->b[p->n++]=byte;
 if(p->n<4) return 0;
 if(p->b[0]==0xa5 && !(p->b[0]^p->b[1]^p->b[2]^p->b[3])) {
   uint32_t status=decode(p->b[2]);
   if(status==0xffffffffu) {p->n=0; return 0;}
   out[0]=0x5a; out[1]=p->b[1]; out[2]=(status>>1)&1;
   out[3]=(status>>2)&255; out[4]=(status>>10)&255;
   out[5]=out[0]^out[1]^out[2]^out[3]^out[4]; p->n=0; return 1;
 }
 memmove(p->b,p->b+1,3); p->n=3;
 while(p->n && p->b[0]!=0xa5) {memmove(p->b,p->b+1,--p->n);}
 return 0;
}
#ifndef QEC_NATIVE_TEST
#include "xparameters.h"
#include "xil_io.h"
#include "xuartps.h"
#include "xuartps_hw.h"
#include "xiltimer.h"
#define GPIO 0x41200000u
#define UART XPAR_XUARTPS_0_BASEADDR
static uint32_t toggle;
static uint32_t now_ms(void){XTime t; XTime_GetTime(&t); return (uint32_t)(t/(COUNTS_PER_SECOND/1000));}
static void reset_pl(void){
 Xil_Out32(GPIO,512); for(volatile int i=0;i<10000;i++) {}
 Xil_Out32(GPIO,0); toggle=0;
}
static uint32_t decode_pl(uint8_t syndrome){
 toggle^=1; Xil_Out32(GPIO,(toggle<<8)|syndrome);
 uint32_t start=now_ms(),s;
 do {s=Xil_In32(GPIO+8); if((s&1)==toggle) return s;} while((uint32_t)(now_ms()-start)<100);
 reset_pl(); return 0xffffffffu;
}
int main(void){
 XUartPs uart; XUartPs_Config *cfg=XUartPs_LookupConfig(UART);
 if(!cfg || XUartPs_CfgInitialize(&uart,cfg,cfg->BaseAddress)!=0) return 1;
 if(XUartPs_SetBaudRate(&uart,115200)!=0) return 2;
 XUartPs_SetOperMode(&uart,XUARTPS_OPER_MODE_NORMAL);
 reset_pl(); struct parser p={0}; uint8_t out[6];
 for(;;) {
   if(XUartPs_IsReceiveData(UART)) {
     uint8_t b=XUartPs_ReadReg(UART,XUARTPS_FIFO_OFFSET);
     if(feed(&p,b,now_ms(),out,decode_pl))
       for(int i=0;i<6;i++) XUartPs_SendByte(UART,out[i]);
   }
 }
}
#endif
