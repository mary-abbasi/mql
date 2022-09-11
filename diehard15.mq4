//+------------------------------------------------------------------+
//|                                                     diehard1.mq4 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//|                                             970704  By Maryam    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#include <diehard15.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   #ifdef TEST_DIEHARD
   Print("TEST_DIEHARD!!!");
   #endif 


   if (CheckInputs() == INIT_FAILED)
      return(INIT_FAILED);
  
   Label("Magic",33,40,"MagicNumber = ");
   Label("Magicvalue",170,40,string(in_MagicNumber));



   if(g_isClosedAll || in_CloseAll)
      return(INIT_SUCCEEDED);


   OrderSendOnce();

   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   DeleteLabelObj();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
   if(g_isClosedAll || in_CloseAll){
      CloseAll();
      return;
      }


   if (g_recoveryZone==False)
      ModifyStopLoss();


   LoopOnTrades(in_OpType);


  }
//+------------------------------------------------------------------+
