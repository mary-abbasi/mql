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
//|                                                                  |
//+------------------------------------------------------------------+

const int RECOVERY_EXIT_MARGIN_LEVEL=200;
const int RECOVERY_EXIT_REVERSE_POINT=150;

bool     g_isOrderSend=False;
double   g_totalProfit=0;
bool     g_isClosedAll=False;
bool     g_recoveryZone=False;
bool     g_antiMartingale=False;
double   g_AmtExitProfit=0;
bool     g_StartCheckProfit=False;
int      g_PositionCount=0;
int      g_in_GapOld=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool CheckOrderVolume(double volume)
  {

   if(volume>=MarketInfo(Symbol(),MODE_MINLOT) && volume<=MarketInfo(Symbol(),MODE_MAXLOT))
      return(True);
   else
     {
      Print("volume= ",volume,"should be between ",MarketInfo(Symbol(),MODE_MINLOT),"and ",MarketInfo(Symbol(),MODE_MAXLOT));
      return(False);
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int OrderSendLow(string   symbol,int      cmd,double   volume,double   price,int      slippage,double   stoploss,double   takeprofit,
                 string   comment,int      magic,datetime expiration,color    arrow_color)
  {
   int ticket=0;
   bool k;
   int cnt=0;

   Print("OrderSendLow Param = "," ",symbol," ",cmd," ",volume," ",price," ",slippage," ",stoploss," ",takeprofit," ",comment," ",magic," ",expiration," ",arrow_color);

   if(g_antiMartingale)
     {
      if(CheckOrdersTotal()==False)
         return(-1);
     }

   if(CheckOrderVolume(volume)==False)
      return(-1);

   ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);

   if(ticket<0)
     {
      Print("OrderSend failed with error #",GetLastError());
     }
   else
     {
      if(cmd==OP_BUY || cmd==OP_SELL)
        {
         g_PositionCount++;
         Print("g_PositionCount= ",g_PositionCount);
        }
      return(ticket);
     }

//*** Loop if not succeed

/*   if(cmd==OP_BUY || cmd==OP_SELL)
     {
      Print("Position but failed!");
      return(ticket);
     }

   slippage=3;*/

//*** Open pending
   k=True;
//   while(k)
   while(cnt<500)
     {
      cnt++;
      if(cmd==OP_BUY)
         price=MarketInfo(symbol,MODE_ASK);
      else
      if(cmd==OP_SELL)
         price=MarketInfo(symbol,MODE_BID);
      ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
      if(ticket!=-1)
         break;
      else
         Print("OrderSend Retry Error ",GetLastError()," cnt= ",cnt);

      Sleep(500);
     }

   Print("ordersend retry count = ",cnt,"ticket= ",ticket);
   if(ticket>0 && (cmd==OP_BUY || cmd==OP_SELL))
     {
      g_PositionCount++;
      Print("g_PositionCount= ",g_PositionCount);
     }

   return(ticket);


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


double GetLastPosLot()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            return(OrderLots());
        }
     }

   return(-1);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastPosPrice()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            return(OrderOpenPrice());
        }
     }

   return(-1);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrdersTotal()
  {
   int cnt=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         cnt++;
        }
     }

   if(cnt>=in_AmtTradeCount+1) //*** tradecount + first pos
     {
      Print("Max Trade Count is reached- OrdersTotal by Magic is = ",cnt);
      return(False);
     }

   return(True);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool  IsInputBuy(int opType)
  {

   if(opType==OP_BUY || opType==OP_BUYLIMIT || opType==OP_BUYSTOP)
      return (True);
   else
      return (False);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AfterOpenFirstPos(int opType,int ticket)
  {
   bool     ret=False;
   double   volumeX=0;
   double   price=0;

   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      volumeX=OrderLots();
      price=OrderOpenPrice();
     }
   else
     {
      Print("AfterOpenFirstPos: ticket is not Found!! , ticket= ",ticket);
      return;
     }

//*** Open Pending at the same side  ********************   
//Pos Instead of pending in same side

//*** Before Defining Antinartingale, CheckOrdersTotal
//                                  if tradecount=0 do not open first same side pending
   if(opType==OP_BUY && CheckOrdersTotal()==True)
     {
      OpenPending(OP_BUYSTOP,volumeX*in_AmtMulFactor,price+(in_Gap*Point));
     }

   else
   if(opType==OP_SELL && CheckOrdersTotal()==True)
     {
      OpenPending(OP_SELLSTOP,volumeX*in_AmtMulFactor,price -(in_Gap*Point));
     }

//*** Open Pending at the opposite side  ********************   

   if(opType==OP_BUY)
     {
      OpenPending(OP_SELLSTOP,volumeX*3,price -(in_Length*Point));
     }

   else
   if(opType==OP_SELL)
     {
      OpenPending(OP_BUYSTOP,volumeX*3,price+(in_Length*Point));
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPending(int opType,double volume,double at_price,bool mainFlg=False)
  {
   int      ticket=0;
   string    comment;

   if(mainFlg)
      comment="Main "+IntegerToString(in_MagicNumber);
   else
      comment=IntegerToString(in_MagicNumber);

//*** Open Pending at the same side  ********************   
   ticket=OrderSendLow(Symbol(),opType,volume,at_price,5,0,0,comment,in_MagicNumber,0,Green);

   if(ticket<0)
      return;
   else
     {
      Print("pending is here!!");
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void OpenRecoveryPending()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            break;
        }
     }

   Print("OpenRecoveryPending ...");

   if(OrderType()==OP_BUY)
      OpenPending(OP_SELLSTOP,OrderLots()*2,OrderOpenPrice()-(in_Length*Point));//Open or Close Price???
   else
      OpenPending(OP_BUYSTOP,OrderLots()*2,OrderOpenPrice()+(in_Length*Point));//Open or Close Price???

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AnyPending()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderType()!=OP_SELL && OrderType()!=OP_BUY)
            return(True);

        }
     }

   return(False);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AnySellPos()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_SELL)
            return(True);

        }
     }

   return(False);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AnyBuyPos()
  {

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY)
            return(True);

        }
     }

   return(False);

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void   CalculateAmtExitProfit()
  {
//*** Get Previous Position Lots to calculate Exit Profit

   int cnt=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            cnt++;

         if(cnt==2)
            break;

        }
     }

   if(cnt!=2)
     {
      Print("Error-Could not Find Previous Position!! cnt= ",cnt);
      return;
     }

//Print("CalculateAmtExitProfit...1 ticket= ",OrderTicket()," ,OrderLots()=",OrderLots());

   g_AmtExitProfit=(OrderLots()/0.01)*in_AmtProfitDiff;

//Print("CalculateAmtExitProfit...2 g_AmtExitProfit= ",g_AmtExitProfit," ,(OrderLots()/0.01)*in_AmtProfitDiff = ",(OrderLots()/0.01)*in_AmtProfitDiff);

//Label("Strategyvalue",220,80," Exit Profit= "+DoubleToStr(g_AmtExitProfit,2));

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateRecExitProfit()
  {

//tik*point*lot

   double lotbuy=0;
   double lotsell=0;
   double diff=0,result=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==in_MagicNumber && OrderSymbol()==Symbol())
           {
            if(OrderType()==OP_BUY)
               lotbuy+=OrderLots();

            else if(OrderType()==OP_SELL)
               lotsell+=OrderLots();
           }
     }

   diff=MathAbs(lotbuy-lotsell);

//Print("CalculateRecExitProfit: "," , " ,lotbuy," , ",lotsell," , ",diff," , ",MarketInfo(Symbol(),MODE_TICKVALUE));

   if(diff==0)
      result=-1;
   else
      result=diff*MarketInfo(Symbol(),MODE_TICKVALUE)*in_RecProfitDiff;

//   Label("Strategyvalue",220,80," Exit Profit= "+DoubleToStr(result,2));
//   Label("Strategyvalue",170,80,str);

   return result;
  }
//+------------------------------------------------------------------+
//| StopLossToZero, to use Profit instead of StopLoss to Risk Free   |
//+------------------------------------------------------------------+
void StopLossToZero()
  {
   bool ret=False;

   int itotal=OrdersTotal();

   for(int icnt=0;icnt<itotal;icnt++)//*** First Position
     {
      if(OrderSelect(icnt,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderStopLoss()!=0 && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            Print("StopLossToZero ticket= ",OrderTicket());
            ret=OrderModify(OrderTicket(),OrderOpenPrice(),0,OrderTakeProfit(),OrderExpiration(),clrGreen);
            if(!ret)
               Print("Order failed to update with error - ",GetLastError());
            return;//*** Just First Pos   
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  DeleteFirstOppositePending(int del_OpType)
  {

   int total=OrdersTotal();
   bool ret=False;
   int opType=-1;

   for(int cnt=0; cnt<total; cnt++)
     {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
           {
            //Print("symbol is changed!!!! ","OrderSymbol() = ",OrderSymbol(),"Symbol() = ",Symbol());
            continue;
           }

         //*** this code is replaced to wrong one 
         //         if(OrderType()==OP_BUYSTOP || (OrderType()==OP_SELLSTOP))
         if(OrderType()==del_OpType)
           {
            Print("DeleteOppositePending:  Going to Delete Ticket = ",OrderTicket());
            if(OrderDelete(OrderTicket())==False)
              {
               Print("error ",GetLastError());
               Print("Could not OrderDelete Pending Ticket = ",OrderTicket());
               cnt=0;total=OrdersTotal();
              }
           }

        }

     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPendingIfFirstIsPending(int OpType)
  {

   if(g_recoveryZone==True || g_antiMartingale==True)
      return;

   if(OpType==OP_BUY || OpType==OP_SELL)
      return;



   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
           {
            AfterOpenFirstPos(OrderType(),OrderTicket());
            break;
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CheckMarginLevel()
  {
   double price=0,margin_level=0;
   bool  ret=False;

   if(g_recoveryZone==False)
      return True;

   margin_level=NormalizeDouble(AccountEquity()/AccountMargin()*100,2);
   if(margin_level>RECOVERY_EXIT_MARGIN_LEVEL)
      return True;



   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
           {
            ret=True;
            break;
           }

        }
     }

   if(ret==False)
     {
      Print("magic= ",in_MagicNumber," * ",__FUNCTION__," : There is not any position!");
      return True;
     }

   if(OrderType()==OP_BUY)
     {
      price=OrderOpenPrice()-(RECOVERY_EXIT_REVERSE_POINT*Point);
      if(Bid<=price)
        {
         Print("magic= ",in_MagicNumber," * ",__FUNCTION__," Bid= ",Bid," OrderOpenPrice()= ",OrderOpenPrice(),
               " price= ",price," margin_level= ",margin_level);
         return False;
        }
     }
   else
     {
      price=OrderOpenPrice()+(RECOVERY_EXIT_REVERSE_POINT*Point);
      if(Ask>=price)
         Print("magic= ",in_MagicNumber," * ",__FUNCTION__," Ask= ",Ask," OrderOpenPrice()= ",OrderOpenPrice(),
               " price= ",price," margin_level= ",margin_level);
      return False;
     }

   return True;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckBeforeClose()
  {
   double profit=0;

//*** Close if Reach To Total Profit
   if(g_antiMartingale==True && in_UseAmtTotalProfit && in_AmtTotalProfit!=0 && g_totalProfit>=in_AmtTotalProfit)
     {
      Print("g_totalProfit>=in_AmtTotalProfit --- ",g_totalProfit,">=",in_AmtTotalProfit);
      CloseAll();
      return True;
     }

   if(g_recoveryZone==True && in_UseRecTotalProfit==True && g_totalProfit>=in_RecTotalProfit)
     {
      Print("g_totalProfit>=in_RecTotalProfit --- ",g_totalProfit,">=",in_RecTotalProfit);
      CloseAll();
      return True;
     }

//*** Anti Martingale Min Profit Check
   if(g_antiMartingale && g_StartCheckProfit)
     {
      CalculateAmtExitProfit();
      if(g_totalProfit<=g_AmtExitProfit)
        {
         Print("g_totalProfit<=g_AmtExitProfit --- ",g_totalProfit,"<=",g_AmtExitProfit);
         CloseAll();
         return True;
        }
     }
//*** Recovery Zone Min Profit Check
   if(g_recoveryZone==True)
     {
      profit=CalculateRecExitProfit();
      if(g_totalProfit>=profit)
        {
         Print("g_totalProfit>=CalculateRecExitProfit() --- ",g_totalProfit,">=",profit);
         CloseAll();
         return True;
        }
     }

//*** Main Position is closed Manually or By Stoploss
   if(g_antiMartingale)
     {
      if(IsMainPosExist()==False)
        {
         Print("Main Position is closed Manually or By Stoploss!, So Close All");
         CloseAll();
         return True;

        }
     }

   if(g_recoveryZone)
      if(CheckMarginLevel()==False)
        {
         Print("magic= ",in_MagicNumber," * ","Margin Level Check is False, So Close All");
         return True;

        }

   return False;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoopOnTrades(int OpType)
  {

   double lots=0;
   string str;
   double price=0;
   bool   isNextOpened=False;
   int    del_opType=-1;
   int    newPosCount=0;
   bool   pendingIsActivated=False;

   g_totalProfit=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //*** First of All, Check Magic
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         g_totalProfit=g_totalProfit+OrderProfit()+OrderSwap()+OrderCommission();

         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            newPosCount++;

        }
     }

   if(newPosCount>g_PositionCount)
     {
      Print("*pendingIsActivated: newPosCount ",newPosCount," > "," g_PositionCount ",g_PositionCount);
      pendingIsActivated=True;
      g_PositionCount=newPosCount;
     }

//*** First Time, Define recoveryZone & delete opposite pending
   if(g_recoveryZone==False && g_antiMartingale==False)
     {
      if((IsInputBuy(OpType) && AnySellPos()) || (IsInputBuy(OpType)==False && AnyBuyPos()))
        {
         g_recoveryZone=True;

         if(IsInputBuy(OpType))
            del_opType=OP_BUYSTOP;
         else
            del_opType=OP_SELLSTOP;

         DeleteFirstOppositePending(del_opType);
         Print("*** g_recoveryZone");
         OpenRecoveryPending();
         return;
        }
     }

//***************************************  Close All Conditions 
   if(CheckBeforeClose())
     {
      CloseAll();
      return;
     }

//***************************************  End of Close All Conditions

//********** Pending is Changed **************

   if(pendingIsActivated)
     {
      Print("pending is changed to Trade");
      Print("1... g_recoveryZone= ",g_recoveryZone," g_antiMartingale= ",g_antiMartingale);

      //*** First OpType was pending, So Open Next 2 Pending
      if(g_recoveryZone==False && g_antiMartingale==False)
         if(OpType!=OP_BUY && OpType!=OP_SELL)
            OpenPendingIfFirstIsPending(OpType);

      if(g_antiMartingale)
        {
         StopLossToZero();
         lots=GetLastPosLot();
         price=GetLastPosPrice();
         if(lots<0)
           {
            Print("Invalid lots!");
            return;
           }
         Print("lots= ",lots);
         if(IsInputBuy(OpType))
            OpenPending(OP_BUYSTOP,in_AmtMulFactor*lots,price+(in_Gap*Point));
         else
            OpenPending(OP_SELLSTOP,in_AmtMulFactor*lots,price -(in_Gap*Point));

         CalculateAmtExitProfit();
         g_StartCheckProfit=True;

        }

      if(g_recoveryZone)
        {
         OpenRecoveryPending();
         g_StartCheckProfit=True;
        }

     } //*** End of Pending Changed To Position

   if(in_Gap!=g_in_GapOld)
     {
      ModifyAmtPendingPrice(OpType);
      g_in_GapOld=in_Gap;
     }

   ShowComments();

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  ModifyAmtPendingPrice(int OpType)
  {
   double price=0;

//   if(g_antiMartingale==False)
//      return;

   if(g_recoveryZone)
      return;

//******* AntiMartingale or Not Defined

   price=GetLastPosPrice();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderMagicNumber()!=in_MagicNumber || OrderSymbol()!=Symbol())
            continue;

         if(IsInputBuy(OpType) && OrderType()==OP_BUYSTOP)
            price=price+(in_Gap*Point);
         else
         if(IsInputBuy(OpType)==False && OrderType()==OP_SELLSTOP)
            price=price-(in_Gap*Point);
         else
            continue;

         Print("Modify Pending Price: ticket= ",OrderTicket()," in_Gap= ",in_Gap," new price= ",price);
         if(OrderModify(OrderTicket(),price,OrderStopLoss(),OrderTakeProfit(),OrderExpiration(),clrGreen)==False)
            Print("Order failed to update with error : ",GetLastError());
         return;
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool  IsMainPosExist()
  {
   int total=OrdersTotal();

   for(int cnt=0; cnt<total; cnt++)
     {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         if(OrderLots()==in_Lots)
            return True;

        }
     }

   return False;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetOrdersTotal()
  {
   int order_cnt=0,total=OrdersTotal();

   for(int cnt=0; cnt<total; cnt++)
     {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         order_cnt++;
        }
     }
   return order_cnt;


  }


void  CloseAll()
  {

//*** endless loop warning ????

   DeleteLabelObj();
   Label("Magic",33,40,"Magic = ");
   Label("Magicvalue",170,40,string(in_MagicNumber));
   Label("CloseAll",33,60,"Going To Close All Position And Pending ...");

   int total=OrdersTotal();
   bool ret=False;
   int error;

   for(int cnt=0; cnt<total; cnt++)
     {
           
      if(GetOrdersTotal()==0)     
         break;
         
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderMagicNumber()!=in_MagicNumber)
            continue;

         if(OrderSymbol()!=Symbol())
            continue;

         Print("CloseAll: Going to Delete Ticket = ",OrderTicket());

         //*** Delete Pending
         if((OrderType()==OP_BUYLIMIT) || (OrderType()==OP_BUYSTOP) || (OrderType()==OP_SELLLIMIT) || (OrderType()==OP_SELLSTOP))
           {

            Print("CloseAll: Going to Delete Pending Ticket = ",OrderTicket());
            if(OrderDelete(OrderTicket())==False)
              {
               Print("error ",GetLastError());
               Print("Could not OrderDelete Pending Ticket = ",OrderTicket());
               //cnt=0;total=OrdersTotal();
              }

           }

         else
           {

            if(OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),3)==false)
              {
               //cnt=0;total=OrdersTotal();

               error=GetLastError();                 // Failed :(
               Print("OrderClose Error= ",error," ticket= ",OrderTicket());
               RefreshRates();
               /*switch(error) // Overcomable errors
                 {
                  case 135:Print("The price has changed. Retrying..");
                  //RefreshRates();                     // Update data
                  continue;                           // At the next iteration
                  case 136:Print("No prices. Waiting for a new tick..");
                  while(RefreshRates()==false)        // To the new tick
                     Sleep(1);                        // Cycle sleep
                  continue;                           // At the next iteration
                  case 146:Print("Trading subsystem is busy. Retrying..");
                  Sleep(500);                         // Simple solution
                  RefreshRates();                     // Update data
                  continue;                           // At the next iteration
                 }*/
              }
           }
         cnt=0;total=OrdersTotal();
        }
     }

   g_isClosedAll=True;
   g_StartCheckProfit=False;
   g_PositionCount=0;
   DeleteLabelObj();
   Label("Magic",33,40,"Magic = ");
   Label("Magicvalue",170,40,string(in_MagicNumber));
   Label("CloseAll",33,60,"All Position And Pending Are Closed!");

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void DeleteLabelObj()
  {

   ObjectDelete(0,"Magic");
   ObjectDelete(0,"Magicvalue");
   ObjectDelete(0,"Profit");
   ObjectDelete(0,"Profitvalue");
   ObjectDelete(0,"Profitvalue");
   ObjectDelete(0,"Strategy");
   ObjectDelete(0,"Strategyvalue");
   ObjectDelete(0,"Message");
   ObjectDelete(0,"CloseAll");
   ObjectDelete(0,"Time");
   ObjectDelete(0,"Timevalue");
   ObjectDelete(0,"Start");
   ObjectDelete(0,"Startvalue");
   ObjectDelete(0,"End");
   ObjectDelete(0,"Endvalue");
   ObjectDelete(0,"Settings");

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool Label(const string            name="Label",             // اسم
           const int               x=0,                      // X فاصله محور
           const int               y=0,                      // Y فاصله محور
           const string            text="Label")             // متن

  {

   long              chart_ID=0;               // ای دی چارت
   int               sub_window=0;             // شماره پنجره
   ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER; // انتخاب گوشه چارت
   string            font="Arial";             // فونت
   int               font_size=14;             // اندازه فونت
   color             clr=clrGold;               // رنگ
   double            angle=0.0;                // زاویه نوشته
   ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER; // نقطه اتکا نوشته
   bool              back=false;               // قرار گرفتن در پشت
   bool              selection=false;          // قابلیت حرکت
   bool              hidden=true;              // مخفی شدن از لیست
   long              z_order=0;                // اولویت برای کلیک ماوس




   ResetLastError();
   if(ObjectFind(name)==sub_window) // در صورت وجود داشتن ابجیکت
     {
      ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
      ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
      ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
      ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
      ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
      ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
      ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
      ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
      ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
      ChartRedraw();
      return(true);
        }else{
      if(ObjectCreate(chart_ID,name,OBJ_LABEL,sub_window,0,0))
        {
         ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
         ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
         ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
         ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
         ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
         ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
         ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
         ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
         ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
         ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
         ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
         ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
         ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
         ChartRedraw();
         return(true);
        }
      else
        {
         Print(__FUNCTION__,
               ": failed to create => ",name," object! Error code = ",GetLastError());
         return(false);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
