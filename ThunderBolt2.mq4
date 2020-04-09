//+------------------------------------------------------------------+
//|                                             Zeus Thunderbolt.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

//TODO: dili mugana ang close BE

enum TypeNS
  {
   INVEST=0,   // Investing.com
   DAILYFX=1,  // Dailyfx.com
  };
 string   LabelDisplay        = "Used to Adjust Overlay";
// Turns the display on and off
 bool     displayOverlay      = true;
// Turns off copyright and icon
 bool     displayLogo         = true;
// Turns off the CCI display
 bool     displayCCI          = true;
// Show BE, TP and TS lines
 bool     displayLines        = true;
// Moves display left and right
 int      displayXcord        = 10;
// Moves display up and down
 int      displayYcord        = 22;
// Moves CCI display left and right
 int      displayCCIxCord     = 10;
//Display font
 string   displayFont         = "Verdana";
// Changes size of display characters
 int      displayFontSize     = 10;
// Changes space between lines
 int      displaySpacing      = 14;
// Ratio to increase label width spacing
 double   displayRatio        = 1;
// default color of display characters
 color    displayColor        = clrWhite;
// default color of profit display characters
 color    displayColorProfit  = Green;
// default color of loss display characters
 color    displayColorLoss    = OrangeRed;
// default color of ForeGround Text display characters
 color    displayColorFGnd    = White;

 // In pips, used in conjunction with logic to offset first trade entry
 extern string   labelStrat=                                                    "----------Entry Settings ------------";//-
 bool     SR_Entry            =true;                                            //Enable S/R Strategy
 extern double   EntryOffset           = 0;                                     //Offset (in pips)
 extern int      BAR_TO_START_SCAN_FROM =2;                                     //S/R Bar Start Scan


extern string   labelTrailing=                                                  "---------- Trade Management ------------";//-
 extern double Risk= 2;                                                          //Risk Per Trade
 extern double SL=15;                                                            //SL
 extern double TP = 20 ;                                                         //TP
extern bool   ProfitTrailing = True;                                             //Profit Trailing
extern double    TrailingStop   = 1.7;                                              //Trailing Stop
extern double    TrailingStep   = 0.2;                                              //Trailing Step

extern string   labelRecovery=                                                  "---------- Recovery Settings ------------";//-
extern bool     useHedge = true;                                                  //Hedge
extern double   HedgeTakeProfit=20;                                               //hedge TP
extern double   HedgeSL=10;                                                       //hedge SL
extern double   HedgeMultiplier = 1.5;                                            //Hedge Multiplier

 extern string   LabelNews=                                                     "---------- News Filter Settings ------------";//-
 TypeNS SourceNews=INVEST;                                                      //Source News
extern int  GMTplus                  =3;                                         //GMT
extern bool     LowNews             = false;                                      
extern int      LowIndentBefore     = 15;                                       
extern int      LowIndentAfter      = 15;
extern bool     MidleNews           = false;
extern int      MidleIndentBefore   = 30;
extern int      MidleIndentAfter    = 30;
extern bool     HighNews            = true;
extern int      HighIndentBefore    = 60;
extern int      HighIndentAfter     = 60;
extern bool     NFPNews             = true;
extern int      NFPIndentBefore     = 180;
extern int      NFPIndentAfter      = 180;

extern string   LabelOtherSettings=                                             "---------- Extra Settings ------------";//-
extern int magicNumber = 1101991;                                               //Magic #
extern string TradeComment = "Zeus Thunderbolt";                                //Trade Comment

 bool    DrawNewsLines        = true;
 color   LowColor             = clrGreen;
 color   MidleColor           = clrBlue;
 color   HighColor            = clrRed;
 int     LineWidth            = 1;
 ENUM_LINE_STYLE LineStyle    = STYLE_DOT;
 bool    OnlySymbolNews       = true;



int NomNews=0,Now=0,MinBefore=0,MinAfter=0;
string NewsArr[4][1000];
datetime LastUpd;
string ValStr;
int   Upd            = 86400;      // Period news updates in seconds
bool  Next           = false;      // Draw only the future of news line
bool  Signal         = false;      // Signals on the upcoming news
datetime TimeNews[300];
string Valuta[300],News[300],Vazn[300];
datetime lastbar_timeopen;

double RiskLoss;
double Lots;
double lotDecimal;
double ASK,BID,OldHigh,OldLow,TotalOrders;

bool SELL,BUY;
double maxDD=0;
double maxDDPC=0;
double ProfitTotal=0;
double LOT;

//+-----------------------------------------------------------------+
//| Hedging                                                         |
//+-----------------------------------------------------------------+



double buyprice;
bool result;

int    MagicNumberHedge=magicNumber+1991;

double        pips;
int           err,T;
int OnInit()
  {
   checkDemoOrLive();
  
   double ticksize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(ticksize==0.00001 || Point==0.01){  
      pips=ticksize*10;
    } else{ pips=ticksize;}
   SL = SL*10;
   TP = TP*10;
   EntryOffset = EntryOffset*10;
   TrailingStop = TrailingStop*10;
   TrailingStep = TrailingStep*10;
   
   if(IsTesting()){
      LowNews             = false;                                      
      MidleNews           = false;
      HighNews            = false;
      NFPNews             = false;  
   }

   
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, C'46,48,67');
   labelCreateDashboard();
   lotDecimal = getLotDecimal();
   string v1=StringSubstr(_Symbol,0,3); string v2=StringSubstr(_Symbol,3,3);
   ValStr=v1+","+v2;
   DrawRectangle();
   
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   Comment("");
	deleteLines();
   del("NS_");
   LabelDelete();

  }
 void LabelDelete()
{
   for (int Object = ObjectsTotal(); Object >= 0; Object--)
   {
      if (StringSubstr(ObjectName(Object), 0, 4) == "Zeus")
         ObjectDelete(ObjectName(Object));
   }
}

void OnTick()
  {
    //recovery
     if(useHedge){
        BUY_RECOVERY();
        SELL_RECOVERY();
     }
     maxDrawdown();
     getProfit();
     ObjSetTxt("ZeusBalanceV", DTS(AccountBalance(),2), 0, CLR_NONE);
     ObjSetTxt("ZeusLotV", getLot(), 0, CLR_NONE);
    
     for (int i=0; i<OrdersTotal(); i++) {
       if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderMagicNumber()==magicNumber){
         TrailingPositions();
         }
       }
     
     }
     
   //run news filter
     NewsFilter();

   return;
  }
//+-----------------------------------------------------------------+
//| MANAGE TRADE HERE                                               |
//+-----------------------------------------------------------------+
void deleteLines(){
    ObjectDelete("Z_Resistance");
    ObjectDelete("Z_Support");
}
void BreakoutStrategy(){
   TotalOrders = OrdersTotal();
   //+----------------------------------------------------------------+
   //| Breakout Order Entry                                           |
   //+----------------------------------------------------------------+
   if (SR_Entry && TotalOrders ==0)
   {
      double bHi = ObjectGet("Z_Resistance", OBJPROP_PRICE1)+EntryOffset*_Point;
      double bLo = ObjectGet("Z_Support", OBJPROP_PRICE1)-EntryOffset*_Point;
      
    
      if (Bid > bHi && bHi >0.01)
      {  
         ObjectDelete("Z_Resistance");
         BUY = true; SELL = false;
      }
     
      else if (Ask<bLo && bLo >0.01)
      {
         ObjectDelete("Z_Support");
         BUY = false; SELL = true;
       
      }
      else{
         BUY =false; SELL = false;
      }  
      
      //take orders
     double AskLo_dif = Ask-bLo; //difference from LOW and Ask price
     double BidHi_dif = bHi-Bid; //diference from HIG and Bid price
      if(BUY){
         int ticket;
         ticket = SendOrder(Symbol(),OP_BUY,getLot(),0,0,Ask-SL*_Point,Ask+TP*_Point,magicNumber,clrBisque,TradeComment);

           if(ticket>=0){
               LOT = getLot();
           }
           
           
           //int ticket2 = OrderSend(Symbol(), OP_SELLSTOP, 
           //            getLot()*2,                              //Lot
           //            Bid-(SL/2)*_Point,                       //price
           //            0,                                       //SLip
           //            Ask+TP*_Point,                           //SL
           //            Ask-SL*_Point,                           //TP
           //            TradeComment,                            //Comment   
           //            12920192,                                //Magic
           //            0, clrBisque);                           //COLOR

      }
     if(SELL) {
       int ticket;
       ticket = SendOrder(Symbol(),OP_SELL,getLot(),0,0,Bid+SL*_Point,Bid-TP*_Point,magicNumber,clrBisque,TradeComment);
           if(ticket>=0){
               LOT = getLot();
           }        
      }
  }
}
void closeOrders(){
  int total = OrdersTotal();
  for(int i=total-1;i>=0;i--)
  {
    OrderSelect(i, SELECT_BY_POS);
    int type   = OrderType();

    bool result = false;
    
    switch(type)
    {
      //Close opened long positions
      case OP_BUY       : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5, Red );
                          break;
      
      //Close opened short positions
      case OP_SELL      : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 5, Red );
                          
    }
    
    if(result == false)
    {
      Alert("Order " , OrderTicket() , " failed to close. Error:" , GetLastError() );
    }  
  }
}

void ManageTrade()
  {  
  //draw support and resistance
   drawResistance(getUpperFractalBar(Period(), BAR_TO_START_SCAN_FROM));
   drawSupport(getLowerFractalBar(Period(), BAR_TO_START_SCAN_FROM));
	
 //run breakout trades
  BreakoutStrategy();
  return;
}



//+----------------------------------------------------------------+
//| Trailing stops                                               |
//+----------------------------------------------------------------+

void TrailingPositions() {
  double pBid, pAsk, pp;

  pp = MarketInfo(OrderSymbol(), MODE_POINT);
  if (OrderType()==OP_BUY && (OrderMagicNumber()==magicNumber || OrderMagicNumber()==MagicNumberHedge)) {
    pBid = MarketInfo(OrderSymbol(), MODE_BID);
    if (!ProfitTrailing || (pBid-OrderOpenPrice())>TrailingStop*pp) {
      if (OrderStopLoss()<pBid-(TrailingStop+TrailingStep-1)*pp) {
        ModifyStopLoss(pBid-TrailingStop*pp);
        return;
      }
    }
  }
  if (OrderType()==OP_SELL && (OrderMagicNumber()==magicNumber || OrderMagicNumber()==MagicNumberHedge)) {
    pAsk = MarketInfo(OrderSymbol(), MODE_ASK);
    if (!ProfitTrailing || OrderOpenPrice()-pAsk>TrailingStop*pp) {
      if (OrderStopLoss()>pAsk+(TrailingStop+TrailingStep-1)*pp || OrderStopLoss()==0) {
        ModifyStopLoss(pAsk+TrailingStop*pp);
        return;
      }
    }
  }
}
void ModifyStopLoss(double ldStopLoss) {
  bool fm;
  fm=OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);
}

void maxDrawdown(){
   double Profit = 0;
      for (int i=0; i<OrdersTotal(); i++) {
       if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if((OrderMagicNumber()==magicNumber || OrderMagicNumber()==MagicNumberHedge)
             && OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL )){
            Profit = Profit+ OrderProfit();
         }
       }
     }
   if(Profit<maxDD){
          maxDD=Profit;
          maxDDPC = ND((maxDD/AccountBalance())*100,2);
          ObjSetTxt("ZeusDDV",  DTS(maxDD,2), 0, CLR_NONE);
          ObjSetTxt("ZeusDDPcV",  DTS(maxDDPC,2)+" %", 0, CLR_NONE);
     }
   
}
void getProfit(){
   double Profit = 0;
      for (int i=0; i<OrdersHistoryTotal(); i++) {
       if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
         if((OrderMagicNumber()==magicNumber || OrderMagicNumber()==MagicNumberHedge)
          && OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL ) ){
            double p = (OrderProfit() + OrderSwap() + OrderCommission());
            Profit = Profit+p;
         }
       }
     }
    ProfitTotal = ND(Profit,2);
    ObjSetTxt("ZeusProfitV", DTS(ProfitTotal,2), 0, CLR_NONE);
}
double getLot(){
   double tick=MarketInfo(Symbol(),MODE_TICKVALUE);
   double minlot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxlot=MarketInfo(Symbol(),MODE_MAXLOT);
   double spread=MarketInfo(Symbol(),MODE_SPREAD);
   RiskLoss=(Risk/100)*AccountBalance();
   Lots=RiskLoss/((SL)*tick);
   Lots= StringToDouble(DTS(Lots,2));
   return  Lots;
}
void simpletrade(){
   int tkt=0;
   if(iOpen(_Symbol,PERIOD_H1,1)<iClose(_Symbol,PERIOD_H1,0) && OrdersTotal()<1)
     {
      tkt=OrderSend(Symbol(),OP_BUY,0.01,Ask,2,Ask-100*_Point,Ask+100*_Point,"",0,0,clrBlue);
     }
   if(iOpen(_Symbol,PERIOD_H1,1)>iClose(_Symbol,PERIOD_H1,0) && OrdersTotal()<1)
     {
      tkt=OrderSend(Symbol(),OP_SELL,0.01,Bid,2,Bid+100*_Point,Bid-100*_Point,"",0,0,clrRed);
     }
}
int getLotDecimal(){
   int LotDecimal=3;
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double MinLotSize = MarketInfo(Symbol(), MODE_MINLOT);
   double MinLot = MathMin(MinLotSize, LotStep);
   if (MinLot < 0.01)
      LotDecimal = 3;
   else if (MinLot < 0.1)
      LotDecimal = 2;
   else if (MinLot < 1)
      LotDecimal = 1;
   else
      LotDecimal = 0;  
  
   return LotDecimal;
 }
bool isNewBar()
{
    static datetime bartime=0; 
    datetime currbar_time=iTime(Symbol(),Period(),0);
    if(bartime!=currbar_time)
    {
       bartime=currbar_time;
       lastbar_timeopen=bartime;
       return (true);
     }
    return (false);
}
string DTS(double Value, int Precision)
{
   return (DoubleToStr(Value, Precision));
}
double ND(double Value, int Precision)
{
   return (NormalizeDouble(Value, Precision));
}
//+-----------------------------------------------------------------+
//| BREAKOUT Strategy Methods                                       |
//+-----------------------------------------------------------------+
int getUpperFractalBar(int timeframe, int starting_bar) {
	for(int bar = starting_bar; bar < Bars; bar++)
		if(isUpperFractal(timeframe, bar)) return(bar);
	return (-1);
}

bool isUpperFractal(int timeframe, int bar) {
	for(int offset = -2; offset <= 2; offset++)
		if( (offset != 0) && (iHigh(Symbol(), timeframe, bar + offset) > iHigh(Symbol(), timeframe, bar)) ) return(false);
	return (true);
}

int getLowerFractalBar(int timeframe, int starting_bar) {
	for(int bar = starting_bar; bar < Bars; bar++)
		if(isLowerFractal(timeframe, bar)) return(bar);
	return (-1);
}

bool isLowerFractal(int timeframe, int bar) {
	for(int offset = -2; offset <= 2; offset++)
		if( (offset != 0) && (iLow(Symbol(), timeframe, bar + offset) < iLow(Symbol(), timeframe, bar)) ) return(false);
	return (true);
}

void drawResistance(int bar_index) {
	if(bar_index > 0){
	double HIGH = iHigh(Symbol(),Period(), bar_index);
	if(Bid<HIGH && OldHigh!=HIGH){
	   drawTrendLine("Z_Resistance", HIGH);
	   OldHigh = HIGH;
	  }
	}
}

void drawSupport(int bar_index) {
	if(bar_index > 0) {
	double LOW =iLow(Symbol(), Period(), bar_index);
	if(Ask>LOW && OldLow!=LOW){
	   drawTrendLine("Z_Support",LOW);
	   OldLow = LOW;
	   }
	}
}

void drawResistance2(int bar_index) {
	if(bar_index > 0){
	double HIGH = iHigh(Symbol(), PERIOD_H1, bar_index);
	   drawTrendLine("Z_Resistance2", HIGH);
	}
}

void drawSupport2(int bar_index) {
	if(bar_index > 0) {
	double LOW =iLow(Symbol(), PERIOD_H1, bar_index);
	drawTrendLine("Z_Support2",LOW);
	}
}

void drawTrendLine(string object_name, double price) {
	ObjectDelete(object_name);
	if(TotalOrders==0)
	  {
	   	ObjectCreate(object_name, OBJ_HLINE, 0, Time[0], price, Time[Bars - 1], price);
	      ObjectSet(object_name, OBJPROP_COLOR, clrBurlyWood);
	      ObjectSet(object_name, OBJPROP_STYLE, STYLE_DOT);
	  }

}


int SendOrder(string OSymbol, int OCmd, double OLot, double OPrice, int OSlip,double OSl, double OTp, int OMagic, color OColor = CLR_NONE, string comment = "")
{
   int Error;
   int Ticket = 0;
   int Tries = 0;
   int OType = (int)MathMod(OCmd, 2);
   double OrderPrice;

   while (Tries < 5)
   {
      Tries ++;

      while (IsTradeContextBusy())
         Sleep(100);

      if (IsStopped())
         return (-1);
      else if (OType == 0)
         OrderPrice = ND(MarketInfo(OSymbol, MODE_ASK) + OPrice, (int)MarketInfo(OSymbol, MODE_DIGITS));
      else
         OrderPrice = ND(MarketInfo(OSymbol, MODE_BID) + OPrice, (int)MarketInfo(OSymbol, MODE_DIGITS));
     
      
      Ticket = OrderSend(OSymbol, OCmd, OLot, OrderPrice, OSlip, OSl, OTp, comment, OMagic, 0, OColor);
    

      if (Ticket < 0)
      {
         Error = GetLastError();
         switch (Error)
         {
            case ERR_TRADE_DISABLED:
               Print("Broker has disallowed EAs on this account");
               Tries = 5;
               break;
            case ERR_OFF_QUOTES:
            case ERR_INVALID_PRICE:
               Sleep(5000);
            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
               RefreshRates();
            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
               Tries++;
               break;
            case 149://ERR_TRADE_HEDGE_PROHIBITED:
               Tries = 5;
               break;
            default:
               Tries = 5;
         }
      }
      else
      {
     
         break;
      }
   }

   return (Ticket);
}

//+-----------------------------------------------------------------+
//+-----------------------------------------------------------------+
  
void NewsFilter(){
   string TextDisplay="";

/*  Check News   */
   bool trade=true; string nstxt=""; int NewsPWR=0; datetime nextSigTime=0;
   if(LowNews || MidleNews || HighNews || NFPNews)
     {
      if(SourceNews==0)
        {// Investing
         if(CheckInvestingNews(NewsPWR,nextSigTime)){ trade=false; } // news time
        }
      if(SourceNews==1)
        {//DailyFX
         if(CheckDailyFXNews(NewsPWR,nextSigTime)){ trade=false; } // news time
        }
     }
   if(trade)
     {// No News, Trade enabled
      nstxt="No News";
      if(ObjectFind(0,"NS_Label")!=-1){ ObjectDelete(0,"NS_Label"); }

        }else{// waiting news , check news power
      color clrT=LowColor;
      if(NewsPWR>3)
        {
         nstxt= "Waiting Non-farm Payrolls News";
         clrT = HighColor;
           }else{
         if(NewsPWR>2)
           {
            nstxt= "Waiting High News";
            clrT = HighColor;
              }else{
            if(NewsPWR>1)
              {
               nstxt= "Waiting Midle News";
               clrT = MidleColor;
                 }else{
               nstxt= "Waiting Low News";
               clrT = LowColor;
              }
           }
        }
      // Make Text Label
      if(nextSigTime>0){ nstxt=nstxt+" "+TimeToString(nextSigTime,TIME_MINUTES); }
      if(ObjectFind(0,"NS_Label")==-1)
        {
         LabelCreate(StringConcatenate(nstxt),clrT);
        }
      if(ObjectGetInteger(0,"NS_Label",OBJPROP_COLOR)!=clrT)
        {
         ObjectDelete(0,"NS_Label");
         LabelCreate(StringConcatenate(nstxt),clrT);
        }
     }
   nstxt="\n"+nstxt;
/*  End Check News   */

   if(IsTradeAllowed() && trade)
     {
      // No news and Trade Allowed
      ManageTrade();
     }
    else{
     //delete support and resistance
      deleteLines();
    }

   TextDisplay=TextDisplay+nstxt;
 //  Comment(TextDisplay);

}  
string ReadCBOE()
  {

   string cookie=NULL,headers;
   char post[],result[];     string TXT="";
   int res;
//--- to work with the server, you must add the URL "https://www.google.com/finance"  
//--- the list of allowed URL (Main menu-> Tools-> Settings tab "Advisors"): 
   string google_url="http://ec.forexprostools.com/?columns=exc_currency,exc_importance&importance=1,2,3&calType=week&timeZone=15&lang=1";
//--- 
   ResetLastError();
//--- download html-pages
   int timeout=5000; //--- timeout less than 1,000 (1 sec.) is insufficient at a low speed of the Internet
   res=WebRequest("GET",google_url,cookie,NULL,timeout,post,0,result,headers);
//--- error checking
   if(res==-1)
     {
      Print("WebRequest error, err.code  =",GetLastError());
      MessageBox("You must add the address 'http://ec.forexprostools.com/' in the list of allowed URL tab 'Advisors' "," Error ",MB_ICONINFORMATION);
      //--- You must add the address ' "+ google url"' in the list of allowed URL tab 'Advisors' "," Error "
     }
   else
     {
      //--- successful download
      //PrintFormat("File successfully downloaded, the file size in bytes  =%d.",ArraySize(result)); 
      //--- save the data in the file
      int filehandle=FileOpen("news-log.html",FILE_WRITE|FILE_BIN);
      //--- проверка ошибки 
      if(filehandle!=INVALID_HANDLE)
        {
         //---save the contents of the array result [] in file 
         FileWriteArray(filehandle,result,0,ArraySize(result));
         //--- close file 
         FileClose(filehandle);

         int filehandle2=FileOpen("news-log.html",FILE_READ|FILE_BIN);
         TXT=FileReadString(filehandle2,ArraySize(result));
         FileClose(filehandle2);
           }else{
         Print("Error in FileOpen. Error code =",GetLastError());
        }
     }

   return(TXT);
  }
//+------------------------------------------------------------------+
datetime TimeNewsFunck(int nomf)
  {
   string s=NewsArr[0][nomf];
   string time=StringConcatenate(StringSubstr(s,0,4),".",StringSubstr(s,5,2),".",StringSubstr(s,8,2)," ",StringSubstr(s,11,2),":",StringSubstr(s,14,4));
   return((datetime)(StringToTime(time) + GMTplus*3600));
  }
void UpdateNews()
  {
   string TEXT=ReadCBOE();
   int sh = StringFind(TEXT,"pageStartAt>")+12;
   int sh2= StringFind(TEXT,"</tbody>");
   TEXT=StringSubstr(TEXT,sh,sh2-sh);

   sh=0;
   while(!IsStopped())
     {
      sh = StringFind(TEXT,"event_timestamp",sh)+17;
      sh2= StringFind(TEXT,"onclick",sh)-2;
      if(sh<17 || sh2<0)break;
      NewsArr[0][NomNews]=StringSubstr(TEXT,sh,sh2-sh);

      sh = StringFind(TEXT,"flagCur",sh)+10;
      sh2= sh+3;
      if(sh<10 || sh2<3)break;
      NewsArr[1][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      if(OnlySymbolNews && StringFind(ValStr,NewsArr[1][NomNews])<0)continue;

      sh = StringFind(TEXT,"title",sh)+7;
      sh2= StringFind(TEXT,"Volatility",sh)-1;
      if(sh<7 || sh2<0)break;
      NewsArr[2][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      if(StringFind(NewsArr[2][NomNews],"High")>=0 && !HighNews)continue;
      if(StringFind(NewsArr[2][NomNews],"Moderate")>=0 && !MidleNews)continue;
      if(StringFind(NewsArr[2][NomNews],"Low")>=0 && !LowNews)continue;

      sh=StringFind(TEXT,"left event",sh)+12;
      int sh1=StringFind(TEXT,"Speaks",sh);
      sh2=StringFind(TEXT,"<",sh);
      if(sh<12 || sh2<0)break;
      if(sh1<0 || sh1>sh2)NewsArr[3][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      else NewsArr[3][NomNews]=StringSubstr(TEXT,sh,sh1-sh);

      NomNews++;
      if(NomNews==300)break;
     }
  }
//+------------------------------------------------------------------+
int del(string name) 
  {
   for(int n=ObjectsTotal()-1; n>=0; n--)
     {
      string Obj_Name=ObjectName(n);
      if(StringFind(Obj_Name,name,0)!=-1)
        {
         ObjectDelete(Obj_Name);
        }
     }
   return 0;                                      // Выход из deinit()
  }
//+------------------------------------------------------------------+
bool CheckInvestingNews(int &pwr,datetime &mintime)
  {

   bool CheckNews=false; pwr=0; int maxPower=0;
   if(LowNews || MidleNews || HighNews || NFPNews)
     {
      if(TimeCurrent()-LastUpd>=Upd){Print("Investing.com News Loading...");UpdateNews();LastUpd=TimeCurrent();Comment("");}
      WindowRedraw();
      //---Draw a line on the chart news--------------------------------------------
      if(DrawNewsLines)
        {
         for(int i=0;i<NomNews;i++)
           {
            string Name=StringSubstr("NS_"+TimeToStr(TimeNewsFunck(i),TIME_MINUTES)+"_"+NewsArr[1][i]+"_"+NewsArr[3][i],0,63);
            if(NewsArr[3][i]!="")if(ObjectFind(Name)==0)continue;
            if(OnlySymbolNews && StringFind(ValStr,NewsArr[1][i])<0)continue;
            if(TimeNewsFunck(i)<TimeCurrent() && Next)continue;

            color clrf=clrNONE;
            if(HighNews && StringFind(NewsArr[2][i],"High")>=0)clrf=HighColor;
            if(MidleNews && StringFind(NewsArr[2][i],"Moderate")>=0)clrf=MidleColor;
            if(LowNews && StringFind(NewsArr[2][i],"Low")>=0)clrf=LowColor;

            if(clrf==clrNONE)continue;

            if(NewsArr[3][i]!="")
              {
               ObjectCreate(0,Name,OBJ_VLINE,0,TimeNewsFunck(i),0);
               ObjectSet(Name,OBJPROP_COLOR,clrf);
               ObjectSet(Name,OBJPROP_STYLE,LineStyle);
               ObjectSetInteger(0,Name,OBJPROP_WIDTH,LineWidth);
               ObjectSetInteger(0,Name,OBJPROP_BACK,true);
              }
           }
        }
      //---------------event Processing------------------------------------
      int ii;
      CheckNews=false;
      for(ii=0;ii<NomNews;ii++)
        {
         int power=0;
         if(HighNews && StringFind(NewsArr[2][ii],"High")>=0){ power=3; MinBefore=HighIndentBefore; MinAfter=HighIndentAfter; }
         if(MidleNews && StringFind(NewsArr[2][ii],"Moderate")>=0){ power=2; MinBefore=MidleIndentBefore; MinAfter=MidleIndentAfter; }
         if(LowNews && StringFind(NewsArr[2][ii],"Low")>=0){ power=1; MinBefore=LowIndentBefore; MinAfter=LowIndentAfter; }
         if(NFPNews && StringFind(NewsArr[3][ii],"Nonfarm Payrolls")>=0){ power=4; MinBefore=NFPIndentBefore; MinAfter=NFPIndentAfter; }
         if(power==0)continue;

         if(TimeCurrent()+MinBefore*60>TimeNewsFunck(ii) && TimeCurrent()-MinAfter*60<TimeNewsFunck(ii) && (!OnlySymbolNews || (OnlySymbolNews && StringFind(ValStr,NewsArr[1][ii])>=0)))
           {
            if(power>maxPower){   maxPower=power; mintime=TimeNewsFunck(ii); }
              }else{
            CheckNews=false;
           }
        }
      if(maxPower>0){ CheckNews=true; }
     }
   pwr=maxPower;
   return(CheckNews);
  }
bool LabelCreate(const string text="Label",const color clr=clrRed)
  {
   long x_distance;  long y_distance; long chart_ID=0;  string name="NS_Label"; int sub_window=0;
   ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER;
   string font="Arial"; int font_size=28; double angle=0.0; ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER;
   bool back=false; bool selection=false;  bool hidden=true;  long z_order=0;
//--- определим размеры окна 
   ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,x_distance);
   ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,y_distance);
   ResetLastError();
   if(!ObjectCreate(chart_ID,name,OBJ_LABEL,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create text label! Error code = ",GetLastError());
      return(false);
     }
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,(int)(x_distance/2.7));
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,(int)(y_distance/1.5));
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
   return(true);
  }
void UpdateDFX()
  {
   string DF=""; string MF="";
   int DeltaGMT=GMTplus; 
   int ChasPoyasServera=DeltaGMT;
   datetime NowTimeD1=Time[0];
   datetime LastSunday=NowTimeD1-TimeDayOfWeek(NowTimeD1)*86399;
   int DayFile=TimeDay(LastSunday);
   if(DayFile<10) DF="0"+(string)DayFile;
   else DF=(string)DayFile;
   int MonthFile=TimeMonth(LastSunday);
   if(MonthFile<10) MF="0"+(string)MonthFile;
   else MF=(string)MonthFile;
   int YearFile=TimeYear(LastSunday);
   string DateFile=MF+"-"+DF+"-"+(string)YearFile;
   string FileName= DateFile+"_dfx.csv";
   int handle;

   if(!FileIsExist(FileName))
     {
      string url="http://www.dailyfx.com/files/Calendar-"+DateFile+".csv";
      string cookie=NULL,headers;
      char post[],result[]; string TXT=""; int res; string text="";
      ResetLastError();
      int timeout=5000;
      res=WebRequest("GET",url,cookie,NULL,timeout,post,0,result,headers);
      if(res==-1)
        {
         Print("WebRequest error, err.code  =",GetLastError());
         MessageBox("You must add the address 'http://www.dailyfx.com/' in the list of allowed URL tab 'Advisors' "," Error ",MB_ICONINFORMATION);
        }
      else
        {
         int filehandle=FileOpen(FileName,FILE_WRITE|FILE_BIN);
         if(filehandle!=INVALID_HANDLE)
           {
            FileWriteArray(filehandle,result,0,ArraySize(result));
            FileClose(filehandle);
              }else{
            Print("Error in FileOpen. Error code =",GetLastError());
           }
        }
     }
   handle=FileOpen(FileName,FILE_READ|FILE_CSV);
   string data,time,month,valuta;
   int startStr=0;
   if(handle!=INVALID_HANDLE)
     {
      while(!FileIsEnding(handle))
        {
         int str_size=FileReadInteger(handle,INT_VALUE);
         string str=FileReadString(handle,str_size);
         string value[10];
         int k=StringSplit(str,StringGetCharacter(",",0),value);
         data = value[0];
         time = value[1];
         if(time==""){ continue; }
         month=StringSubstr(data,4,3);
         if(month=="Jan") month="01";
         if(month=="Feb") month="02";
         if(month=="Mar") month="03";
         if(month=="Apr") month="04";
         if(month=="May") month="05";
         if(month=="Jun") month="06";
         if(month=="Jul") month="07";
         if(month=="Aug") month="08";
         if(month=="Sep") month="09";
         if(month=="Oct") month="10";
         if(month=="Nov") month="11";
         if(month=="Dec") month="12";
         TimeNews[startStr]=StrToTime((string)YearFile+"."+month+"."+StringSubstr(data,8,2)+" "+time)+ChasPoyasServera*3600;
         valuta=value[3];
         if(valuta=="eur" ||valuta=="EUR")Valuta[startStr]="EUR";
         if(valuta=="usd" ||valuta=="USD")Valuta[startStr]="USD";
         if(valuta=="jpy" ||valuta=="JPY")Valuta[startStr]="JPY";
         if(valuta=="gbp" ||valuta=="GBP")Valuta[startStr]="GBP";
         if(valuta=="chf" ||valuta=="CHF")Valuta[startStr]="CHF";
         if(valuta=="cad" ||valuta=="CAD")Valuta[startStr]="CAD";
         if(valuta=="aud" ||valuta=="AUD")Valuta[startStr]="AUD";
         if(valuta=="nzd" ||valuta=="NZD")Valuta[startStr]="NZD";
         News[startStr]=value[4];
         News[startStr]=StringSubstr(News[startStr],0,60);
         Vazn[startStr]=value[5];
         if(Vazn[startStr]!="High" && Vazn[startStr]!="HIGH" && Vazn[startStr]!="Medium" && Vazn[startStr]!="MEDIUM" && Vazn[startStr]!="MED" && Vazn[startStr]!="Low" && Vazn[startStr]!="LOW")Vazn[startStr]=FileReadString(handle);
         startStr++;
        }
        }else{
      PrintFormat("Error in FileOpen = %s. Error code= %d",FileName,GetLastError());
     }
   NomNews=startStr-1;
   FileClose(handle);
  }

bool CheckDailyFXNews(int &pwr,datetime &mintime)
  {

   bool CheckNews=false; pwr=0; int maxPower=0; color clrf=clrNONE; mintime=0;
   if(LowNews || MidleNews || HighNews || NFPNews)
     {
      if(Time[0]-LastUpd>=Upd){Print("News DailyFX Loading...");UpdateDFX();LastUpd=Time[0];}
      WindowRedraw();
      //---Draw a line on the chart news--------------------------------------------
      if(DrawNewsLines)
        {
         for(int i=0;i<NomNews;i++)
           {
            string Lname=StringSubstr("NS_"+TimeToStr(TimeNews[i],TIME_MINUTES)+"_"+News[i],0,63);
            if(News[i]!="")if(ObjectFind(0,Lname)==0){  continue; }
            if(TimeNews[i]<TimeCurrent() && Next){ continue; }
            if((Vazn[i]=="High" || Vazn[i]=="HIGH") && HighNews==false){ continue; }
            if((Vazn[i]=="Medium" || Vazn[i]=="MEDIUM" || Vazn[i]=="MED") && MidleNews==false){ continue; }
            if((Vazn[i]=="Low" || Vazn[i]=="LOW") && LowNews==false){ continue; }
            if(Vazn[i]=="High" || Vazn[i]=="HIGH"){ clrf=HighColor; }
            if(Vazn[i]=="Medium" || Vazn[i]=="MEDIUM" || Vazn[i]=="MED"){ clrf=MidleColor; }
            if(Vazn[i]=="Low" || Vazn[i]=="LOW"){ clrf=LowColor; }
            if(News[i]!="" && ObjectFind(0,Lname)<0)
              {
               if(OnlySymbolNews && (Valuta[i]!=StringSubstr(_Symbol,0,3) && Valuta[i]!=StringSubstr(_Symbol,3,3))){ continue; }
               ObjectCreate(0,Lname,OBJ_VLINE,0,TimeNews[i],0);
               ObjectSet(Lname,OBJPROP_COLOR,clrf);
               ObjectSet(Lname,OBJPROP_STYLE,LineStyle);
               ObjectSetInteger(0,Lname,OBJPROP_WIDTH,LineWidth);
               ObjectSetInteger(0,Lname,OBJPROP_BACK,true);
              }
           }
        }
      //---------------event Processing------------------------------------
      for(int i=0;i<NomNews;i++)
        {
         int power=0;
         if(HighNews && (Vazn[i]=="High" || Vazn[i]=="HIGH")){ power=3; MinBefore=HighIndentBefore; MinAfter=HighIndentAfter; }
         if(MidleNews && (Vazn[i]=="Medium" || Vazn[i]=="MEDIUM" || Vazn[i]=="MED")){ power=2; MinBefore=MidleIndentBefore; MinAfter=MidleIndentAfter; }
         if(LowNews && (Vazn[i]=="Low" || Vazn[i]=="LOW")){ power=1; MinBefore=LowIndentBefore; MinAfter=LowIndentAfter; }
         if(NFPNews && StringFind(News[i],"Non-farm Payrolls")>=0){ power=4; MinBefore=NFPIndentBefore; MinAfter=NFPIndentAfter; }
         if(power==0)continue;

         if(TimeCurrent()+MinBefore*60>TimeNews[i] && TimeCurrent()-MinAfter*60<TimeNews[i] && (!OnlySymbolNews || (OnlySymbolNews && (StringSubstr(Symbol(),0,3)==Valuta[i] || StringSubstr(Symbol(),3,3)==Valuta[i]))))
           {
            if(power>maxPower){ maxPower=power; mintime=TimeNews[i]; }
           }
         else
           {
            CheckNews=false;
           }
        }
      if(maxPower>0){ CheckNews=true; }
     }
   pwr=maxPower;
   return(CheckNews);
  }


void ObjSetTxt(string Name, string Text, int FontSize = 0, color Colour = CLR_NONE, string Font = "")
{
   FontSize += displayFontSize;

   if (Font == "")
      Font = displayFont;

   if (Colour == CLR_NONE)
      Colour = displayColor;

   ObjectSetText(Name, Text, FontSize, Font, Colour);
}

//+-----------------------------------------------------------------+
//| Create Label Function (OBJ_LABEL ONLY)                          |
//+-----------------------------------------------------------------+
void CreateLabel(string Name, string Text, int FontSize, int Corner, int XOffset, double YLine, color Colour = CLR_NONE, string Font = "")
{
   double XDistance = 0, YDistance = 0;

   if (Font == "")
      Font = displayFont;

   FontSize += displayFontSize;
   YDistance = displayYcord + displaySpacing * YLine;

   if (Corner == 0)
      XDistance = displayXcord + (XOffset * displayFontSize / 9 * displayRatio);
   else if (Corner == 1)
      XDistance = displayCCIxCord + XOffset * displayRatio;
   else if (Corner == 2)
      XDistance = displayXcord + (XOffset * displayFontSize / 9 * displayRatio);
   else if (Corner == 3)
   {
      XDistance = XOffset * displayRatio;
      YDistance = YLine;
   }
   else if (Corner == 5)
   {
      XDistance = XOffset * displayRatio;
      YDistance = 14 * YLine;
      Corner = 1;
   }

   if (Colour == CLR_NONE)
      Colour = displayColor;

   ObjectCreate(Name, OBJ_LABEL, 0, 0, 0);
   ObjectSetText(Name, Text, FontSize, Font, Colour);
   ObjectSet(Name, OBJPROP_CORNER, Corner);
   ObjectSet(Name, OBJPROP_XDISTANCE, XDistance);
   ObjectSet(Name, OBJPROP_YDISTANCE, YDistance);

    
}
void labelCreateDashboard(){
      CreateLabel("ZeusName", "Zeus Thunderbolt", 5, 0, 0, 1,White);
      CreateLabel("ZeusLine1", "=========================", 0, 0, 0, 3);
      CreateLabel("ZeusBalance", "Account Balance", 0, 0, 0,4);
      CreateLabel("ZeusBalanceV", AccountBalance(), 0, 0, 140, 4);
      
      CreateLabel("ZeusRisk", "Risk Per Trade", 0, 0, 0,5);
      CreateLabel("ZeusRiskV", Risk +"%", 0, 0, 140, 5);
      
      CreateLabel("ZeusLot", "Lot Size", 0, 0, 0,6);
      CreateLabel("ZeusLotV", getLot(), 0, 0, 140, 6);
      
      CreateLabel("ZeusDD", "Max DD:", 0, 0, 0,7);
      CreateLabel("ZeusDDV", "0", 0, 0, 140, 7);
       CreateLabel("ZeusDDPc", "Max DD %:", 0, 0, 0,8);
       CreateLabel("ZeusDDPcV", "0%", 0, 0, 140, 8);

       CreateLabel("ZeusProfit", "Profit:",0, 0, 0,9);
       CreateLabel("ZeusProfitV", "0",0, 0, 140,9);
     
       DrawRectangle();DrawRectangle_Resize();
}
void DrawRectangle_Resize(){
    int y_dist;//,x_dist,x_size,y_size,x_1;
    
    int x_dist=ObjectGetInteger(ChartID(),"ZeusProfitV",OBJPROP_XDISTANCE);
    //x_size=ObjectGetInteger(ChartID(),"AiskoLabeline1",OBJPROP_WIDTH);
    y_dist=ObjectGetInteger(ChartID(),"ZeusProfitV",OBJPROP_YDISTANCE);
  //  int x_dist2=ObjectGetInteger(ChartID(),"ZeusBalanceV",OBJPROP_XDISTANCE);

    //x_1=x_dist+x_size;
    //Print("x_dist",x_dist," x_size",x_size," y_dist",y_dist," y_size",y_size);
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_XSIZE,270);//270
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_YSIZE,y_dist);//410
}
void DrawRectangle() {
    ChartSetInteger(ChartID(),CHART_FOREGROUND,0,true);
    
    ObjectCreate(ChartID(),"ZeusRect",OBJ_RECTANGLE_LABEL,0,0,0) ;
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_BGCOLOR,clrDarkSlateBlue);
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_BORDER_TYPE,DRAW_FILLING);

    int x_dist=ObjectGetInteger(ChartID(),"ZeusName",OBJPROP_XDISTANCE);
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_XDISTANCE,0);
    ObjectSetInteger(ChartID(),"ZeusRect",OBJPROP_YDISTANCE,30);
    ObjectSet("ZeusRect",OBJPROP_BACK,true);

}

void checkDemoOrLive(){   
   if(IsDemo()){
 
   }else{
      Print("This is just a demo version, under alpha testing.");
      MessageBox("Live account is not allowed on this robot. Robot still under alpha version with further forward testing. Thanks!","Robot Message",48);
      ExpertRemove();
   }  
}

//+-----------------------------------------------------------------+
//|REOVERY AREA                                                     |
//+-----------------------------------------------------------------+
void SELL_RECOVERY()
  {
//                                    TRADE 1+ 2 ZONE RECOVERY2 1 LOT SELL ITERATION + 1.4 LOT- BUY ITERATION
// ===================================================================================================================== 
   int iCount=0;
   int countHedgeBuy=0;
   if(OrdersTotal()>=1)
     {
      for(iCount=0;iCount<OrdersTotal();iCount++)
        {
         for(int sell1=OrdersTotal()-1;sell1>=0;sell1--)
           {
            if(countHedgeBuy<1){
               if(OrderSelect(sell1,SELECT_BY_POS,MODE_TRADES)){
                  if(OrderMagicNumber()==magicNumber){
                     if(OrderSymbol()==Symbol()){
                        if(OrderType()==OP_SELL){
                           if(OrderOpenPrice()+7*pips<Ask){
                              Print("Hedge pls ON SELL");
                              int ticket66=OrderSend(Symbol(),OP_BUY,LOT*HedgeMultiplier,Ask,0,OrderOpenPrice()-HedgeSL*pips,OrderOpenPrice()+HedgeTakeProfit*pips,TradeComment+" Rec_Hedge",MagicNumberHedge,0,Green);               
                              }}}}}}
            countHedgeBuy++;
           }
      }
  }
  }
void BUY_RECOVERY()
  {
   int iCount=0;
   int countHedgeSell=0;

   if(OrdersTotal()>=1)
     {
      for(iCount=0;iCount<OrdersTotal();iCount++)
        {

         for(int buy1=OrdersTotal()-1;buy1>=0;buy1--)
           {
            if(countHedgeSell<1){
               if(OrderSelect(buy1,SELECT_BY_POS,MODE_TRADES)){
                  if(OrderMagicNumber()==magicNumber){
                     if(OrderSymbol()==Symbol()){
                        if(OrderType()==OP_BUY){
                           if((OrderOpenPrice()-7*pips>Bid) && (OrderOpenPrice()>Bid)){
                               Print("Hedge pls ON BUY");
                              int ticket2=OrderSend(Symbol(),OP_SELL,LOT*HedgeMultiplier,Bid,0,OrderOpenPrice()+HedgeSL*pips,OrderOpenPrice()-HedgeTakeProfit*pips,TradeComment+" Rec_Hedge",MagicNumberHedge,0,Green);
                               }}}}}}
            countHedgeSell++;
           }
        }
     }
  }

  