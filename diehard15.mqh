//+------------------------------------------------------------------+
//|                                                      diehard.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//|                                             970704  By Maryam    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//|include                                                           |
//+------------------------------------------------------------------+
#include <diehard_core15.mqh>

//#define TEST_DIEHARD
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum Enum_Operation_Type
  {
   BUY=OP_BUY,                // Buy
   BUY_LIMIT=OP_BUYLIMIT,     // Buy Limit
   BUY_STOP=OP_BUYSTOP,       // Buy Stop
   SELL=OP_SELL,              // Sell 
   SELL_LIMIT=OP_SELLLIMIT,   // Sell Limit
   SELL_STOP=OP_SELLSTOP,     // Sell Stop
  };
//--- input parameters
extern   bool       in_CloseAll=False;       //Close All?
input    string   in_delimiter4="*********************************";//General Settings:
input Enum_Operation_Type  in_OpType=OP_BUY; //Operation Type
input   double      in_At_Price=0;                   //at Price(Pending)
input   double      in_Lots=0.01;                    //Lot
input    int        in_MagicNumber=666;             //Magic number

input    string   in_delimiter3="*********************************";//AntiMartingale Param:
#ifdef   TEST_DIEHARD
input    int        in_Gap=60;                         //gap (in point)
#else
input    int        in_Gap=220;                         //gap (in point)
#endif
extern   int        in_AmtTradeCount=1;                    //Count of Trades   
extern   double     in_AmtProfitDiff=0.3;                  //Diff from Profit Sum (in $) 
extern   bool       in_UseAmtTotalProfit=False;            //Using Total Profit?
extern   double     in_AmtTotalProfit;                 //Total Profit (in $) 
extern   int        in_AmtMulFactor=2;                   //Multiplicative factor(Zarib)

input    string   in_delimiter2="*********************************";//Stoploss1&2:

#ifdef   TEST_DIEHARD
extern   int        in_Price1=50;                  //Price1
extern   int        in_StopLoss1=40;               //Stop Loss1
extern   int        in_Price2=55;                  //Price2
extern   int        in_StopLoss2=45;               //Stop Loss2

#else 

extern   int        in_Price1=130;                  //Price1
extern   int        in_StopLoss1=30;               //Stop Loss1
extern   int        in_Price2=210;                  //Price2
extern   int        in_StopLoss2=100;               //Stop Loss2

#endif 


input    string   in_delimiter1="*********************************";//Recovery Zone Param:

#ifdef   TEST_DIEHARD
input    int        in_Length=60;                    //opposite side pending gap
#else 
input    int        in_Length=300;                    //opposite side pending gap
#endif 
//extern   double     in_RecProfitDiff=100;                  //Diff from Profit Sum (in Point) 
extern   int        in_RecProfitDiff=50;                  //Diff from Profit Sum (in Point) 
extern   bool       in_UseRecTotalProfit=False;            //Using Total Profit?
extern   double     in_RecTotalProfit;                 //Total Profit (in $) 

bool  g_SL1=False,g_SL2=False;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckInputs()
  {

   if(in_At_Price!=0 && in_OpType!=OP_BUYLIMIT && in_OpType!=OP_BUYSTOP && in_OpType!=OP_SELLLIMIT && in_OpType!=OP_SELLSTOP)
     {
      MessageBox("Please Define Pending! ","Error",MB_OK|MB_ICONERROR);
      return(INIT_FAILED); //*** EA is removed but happy face is not refereshed immidiately!!!
     }

   if(in_At_Price==0 && (in_OpType==OP_BUYLIMIT || in_OpType==OP_BUYSTOP || in_OpType==OP_SELLLIMIT || in_OpType==OP_SELLSTOP))
     {
      MessageBox("Please Define At Price! ","Error",MB_OK|MB_ICONERROR);
      return(INIT_FAILED);
     }

   if(in_Gap<in_StopLoss2)
     {
      MessageBox("Gap Should be Greater than Stoploss2! ","Error",MB_OK|MB_ICONERROR);
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OrderSendOnce()
  {

   int      ticket=0;
   bool     ret=False;
   double   volumeX=0;
   double   price=0;

   Print("g_isOrderSend = ",g_isOrderSend);

//*** Opened & Closed Before
   if(g_isClosedAll || g_isOrderSend)
      return;

//*** OrderSend If Not Doing Before

   if(FindInTrades()==True)
     {
      g_isOrderSend=True;
      return;
     }

   if(FindInTradesHistory()==True)
     {
      g_isOrderSend=True;
      return;
     }

   if(in_OpType==OP_BUY)
      ticket=OrderSendLow(Symbol(),in_OpType,in_Lots,Ask,5,0,0,"Main "+IntegerToString(in_MagicNumber),in_MagicNumber,0,Green);
   else
   if(in_OpType==OP_SELL)
      ticket=OrderSendLow(Symbol(),in_OpType,in_Lots,Bid,5,0,0,"Main "+IntegerToString(in_MagicNumber),in_MagicNumber,0,Green);

   else if((in_OpType==OP_BUYLIMIT) || (in_OpType==OP_BUYSTOP) || (in_OpType==OP_SELLLIMIT) || (in_OpType==OP_SELLSTOP))
     {
      OpenPending(in_OpType,in_Lots,in_At_Price,True);
     }

   if(ticket<0)
      return;

   g_isOrderSend=True;

   Print("OrderSend placed successfully");

   if(in_OpType==OP_BUY || in_OpType==OP_SELL)
      AfterOpenFirstPos(in_OpType,ticket);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool  FindInTradesHistory()
  {
   bool ret=False;

   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         //*** First of All, Check Magic

         if((OrderMagicNumber()==in_MagicNumber) && (OrderSymbol()==Symbol()) && isInLast24Hours(OrderCloseTime()))
           {
            ret=True;
            Print("Magic & Symbol is Found in Account History!!!  OrderCloseTime = ",OrderCloseTime());
            break;
           }

        }
     }

   return(ret);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isInLast24Hours(datetime inDate)
  {
   bool ret=False;
//*** First Day of Year
   if(TimeDayOfYear(inDate)==1)
      if(TimeYear(inDate)==Year()-1 && TimeMonth(inDate)==12 && TimeDay(inDate)==31 && TimeHour(inDate)>=Hour())
        {
         return(True);

        }

   if(TimeYear(inDate)!=Year())
      return(False);
//*** Today

   if(DayOfYear()==TimeDayOfYear(inDate))
     {
      return(True);
     }
//*** LastDay
   if(TimeDayOfYear(inDate)==(DayOfYear()-1))
     {
      if(TimeHour(inDate)>=Hour())
        {
         return(True);
        }

     }

   return(ret);


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool  FindInTrades()
  {
   bool ret=False;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if((OrderMagicNumber()==in_MagicNumber) && (OrderSymbol()==Symbol()))
           {
            ret=True;
            Print("Magic & Symbol is Found in Current Trades!!!");
            break;
           }

        }
     }

   return(ret);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyStopLoss()
  {

   double newStopLoss=-1;
   bool    ret;
   bool    firstStopLoss=False;
   int     del_opType=-1;

   if(g_recoveryZone)//*** we use Profit in this Case
      return;


   if(g_SL1 && g_SL2)
      return;

//--- Modify
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
           {
            continue;
           }

         //*** Do Not Change Pending Stoploss Based On New Market Price
         if((OrderType()==OP_BUYLIMIT) || (OrderType()==OP_BUYSTOP) || (OrderType()==OP_SELLLIMIT) || (OrderType()==OP_SELLSTOP))
            continue;

         //*** Buy
         if(OrderType()==OP_BUY)
           {
            //*** Reset newStopLoss           
            newStopLoss=0;

            if(g_SL1==False && Bid>=(OrderOpenPrice()+(in_Price1*Point)) && Bid<(OrderOpenPrice()+(in_Price2*Point)))
              {
               newStopLoss=OrderOpenPrice()+(in_StopLoss1*Point);
               firstStopLoss=True;
              }
            else
            if(g_SL2==False && Bid>=OrderOpenPrice()+(in_Price2*Point))
                                    newStopLoss=OrderOpenPrice()+(in_StopLoss2*Point);

            //*** Do NOT Modify StopLoss, if Less than Before
            if(newStopLoss<=OrderStopLoss())
               continue;

            Print(" buy .. newStopLoss= ",newStopLoss);

           }
         else

         //*** Sell
         if(OrderType()==OP_SELL)
           {
            newStopLoss=0;

            if(g_SL1==False && Ask<=(OrderOpenPrice()-(in_Price1*Point)) && Ask>(OrderOpenPrice()-(in_Price2*Point)))
              {
               newStopLoss=OrderOpenPrice()-(in_StopLoss1*Point);
               firstStopLoss=True;
              }
            else
            if(g_SL2==False && Ask<=(OrderOpenPrice()-(in_Price2*Point)))
                                    newStopLoss=OrderOpenPrice()-(in_StopLoss2*Point);

            if((newStopLoss==0) || (OrderStopLoss()!=0 && newStopLoss>=OrderStopLoss()))
               continue;

            Print(" sell .. newStopLoss= ",newStopLoss);

           }

         //*** Modify if Needed
         if(OrderStopLoss()!=newStopLoss)
           {
            Print(" newStopLoss= ",newStopLoss);
            ret=OrderModify(OrderTicket(),OrderOpenPrice(),newStopLoss,OrderTakeProfit(),OrderExpiration(),clrGreen);
            if(!ret)
              {
               Print("Order failed to update with error - ",GetLastError());
               return;
              }
            if(firstStopLoss)
               g_SL1=True;
            else
               g_SL2=True;

           }

         if(firstStopLoss)
           {
            Print("firstStopLoss ... Going to delete opposite");
            if(IsInputBuy(in_OpType))
               del_opType=OP_SELLSTOP;
            else
               del_opType=OP_BUYSTOP;

            DeleteFirstOppositePending(del_opType);//*** Note: Another pending is still there!
            g_antiMartingale=True;
            Print("anti martingale");
           }

        }

     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ShowComments()
  {
   string   str;
   Label("Profit",33,60,"Profit = ");
   Label("Profitvalue",170,60,string(g_totalProfit));

   if(g_antiMartingale==False && g_recoveryZone==False)
      str="Not Defined";
   else
   if(g_antiMartingale)
      str="Anti Martingale";
   else
   if(g_recoveryZone)
      str="Recovery Zone";

   Label("Strategy",33,80,"Strategy = ");
   Label("Strategyvalue",170,80,str);

   Label("Message",33,100,"I Love You!");

  }
//+------------------------------------------------------------------+
