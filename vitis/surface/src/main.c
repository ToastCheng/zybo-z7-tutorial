#include <stdint.h>
#include <string.h>
#ifndef DETECTOR_BYTES
#define DETECTOR_BYTES 3u
#endif
struct parser {uint8_t b[20]; unsigned n; uint32_t last_ms;};
static void shift(struct parser *p){memmove(p->b,p->b+1,--p->n);}
static int feed(struct parser *p,uint8_t byte,uint32_t ms,uint8_t out[9],
                uint32_t (*decode)(const uint8_t *,unsigned)){
 if((uint32_t)(ms-p->last_ms)>50) p->n=0;
 p->last_ms=ms;
 if(!p->n && byte!=0xc3) return 0;
 p->b[p->n++]=byte;
 while(p->n){
  if(p->b[0]!=0xc3){shift(p);continue;}
  if(p->n<3) return 0;
  unsigned len=p->b[2];
  if(len!=0 && len!=DETECTOR_BYTES){shift(p);continue;}
  if(p->n<len+4) return 0;
  uint8_t sum=0;for(unsigned i=0;i<len+4;i++) sum^=p->b[i];
  if(sum){shift(p);continue;}
  uint32_t s=decode(p->b+3,len),cycles=s&0x0fffffffu;
  out[0]=0x3c;out[1]=p->b[1];out[2]=(s==0xffffffffu)?2:((s>>29)&1);
  out[3]=len?((s>>28)&1):0;
  for(unsigned i=0;i<4;i++) out[4+i]=(uint8_t)(cycles>>(8*i));
  out[8]=0;for(unsigned i=0;i<8;i++) out[8]^=out[i];p->n=0;return 1;
 }
 return 0;
}
#ifndef SURFACE_NATIVE_TEST
#include "xparameters.h"
#include "xil_io.h"
#include "xuartps.h"
#include "xuartps_hw.h"
#include "xiltimer.h"
#define GPIO 0x41200000u
#define UART XPAR_XUARTPS_0_BASEADDR
static uint32_t toggle;
static uint32_t now_ms(void){XTime t;XTime_GetTime(&t);return (uint32_t)(t/(COUNTS_PER_SECOND/1000));}
static uint32_t command(unsigned op,unsigned index,unsigned data){
 toggle^=1;Xil_Out32(GPIO,(toggle<<31)|(op<<24)|(index<<16)|data);
 uint32_t start=now_ms(),s;
 do{s=Xil_In32(GPIO+8);if((s>>31)==toggle)return s;}while((uint32_t)(now_ms()-start)<1000);
 return 0xffffffffu;
}
static uint32_t decode_pl(const uint8_t *data,unsigned bytes){
 if(!bytes)return command(3,0,0);
 for(unsigned i=0;i<bytes;i+=2){
  unsigned word=data[i]|((i+1<bytes)?((unsigned)data[i+1]<<8):0);
  uint32_t s=command(1,i/2,word);if(s==0xffffffffu || (s&(1u<<29)))return 0xffffffffu;
 }
 return command(2,0,0);
}
int main(void){
 XUartPs uart;XUartPs_Config *cfg=XUartPs_LookupConfig(UART);
 if(!cfg || XUartPs_CfgInitialize(&uart,cfg,cfg->BaseAddress)!=0)return 1;
 if(XUartPs_SetBaudRate(&uart,115200)!=0)return 2;
 XUartPs_SetOperMode(&uart,XUARTPS_OPER_MODE_NORMAL);
 toggle=Xil_In32(GPIO+8)>>31;command(3,0,0);
 struct parser p={0};uint8_t out[9];
 for(;;)if(XUartPs_IsReceiveData(UART)){
  uint8_t byte=XUartPs_ReadReg(UART,XUARTPS_FIFO_OFFSET);
  if(feed(&p,byte,now_ms(),out,decode_pl))for(int i=0;i<9;i++)XUartPs_SendByte(UART,out[i]);
 }
}
#endif
