//+------------------------------------------------------------------+
//| ICT_Team_EA.mq5                                                  |
//| Semi-automatic forex helper: Scout + Shield + Pilot + Journal.   |
//| DEMO / PAPER ONLY by default. Nothing is traded without your     |
//| click on APPROVE. NOT YET COMPILED OR TESTED - see README.       |
//+------------------------------------------------------------------+
#property copyright "Owner"
#property version   "0.10"
#property strict

#include <Trade\Trade.mqh>

//--- Symbols
input string InpSymbols          = "EURUSD,GBPUSD,USDJPY"; // pairs Scout watches
input string InpSuffix           = "";        // broker symbol suffix, if any
//--- Shield limits (approved by owner)
input double InpVirtualBalance   = 1000.0;    // paper balance in account currency
input double InpRiskPct          = 0.5;       // risk per trade, % of virtual equity
input double InpDailyLossPct     = 2.0;       // daily loss cap, %
input int    InpMaxLossStreak    = 3;         // stop after N losses in a row
input double InpTotalLossPct     = 10.0;      // total loss cap from start, %
input int    InpMaxOpenTrades    = 2;
input double InpMaxSpreadPips    = 2.0;       // PROPOSED, check Deriv's real spread
input int    InpMaxTickAgeSec    = 30;        // stale-feed limit for orders
input int    InpApprovalMinutes  = 30;        // approval expires after this
input double InpMaxDriftR        = 0.25;      // max price move from entry, in R
//--- Rule parameters (PROPOSED, owner has not yet confirmed - see plan section 6)
input double InpRR               = 2.0;       // target = RR x risk
input double InpMinFVGPips       = 2.0;
input double InpSLBufferPips     = 1.0;
input double InpMinSLPips        = 8.0;
input double InpMaxSLPips        = 40.0;
input int    InpLookbackBars     = 40;        // 15-minute bars to search
//--- Kill zones, GMT hours (PROPOSED)
input int    InpLondonStartGMT   = 7;
input int    InpLondonEndGMT     = 10;
input int    InpNYStartGMT       = 12;
input int    InpNYEndGMT         = 15;
input int    InpDailyMsgHourGMT  = 21;        // daily summary time
//--- Switches
input bool   InpGoLive           = false;     // must be true to allow a REAL account
input bool   InpClearStop        = false;     // set true once to clear a Shield stop, then set back to false
input bool   InpTesterAutoApprove= false;     // Strategy Tester only: auto-approve (never on a live chart)
input long   InpMagic            = 26112701;
input string InpJournalFile      = "ICT_Journal.csv";

//--- Types
struct Setup
  {
   string   id;
   string   sym;
   int      dir;        // +1 buy, -1 sell
   double   entry;
   double   sl;
   double   tp;
   double   lots;
   double   riskMoney;
   datetime created;
   string   rules;
  };

//--- State
CTrade   trade;
string   g_syms[];
int      g_n = 0;
datetime g_lastBar[];
string   g_lastId[];
bool     g_stale[];
Setup    g_pend;
bool     g_hasPend = false;
int      g_cntSetups = 0, g_cntBlocked = 0, g_cntSkipped = 0, g_cntOrders = 0;
int      g_lastMsgDay = -1;
const string GV_STOP  = "ICT_STOPPED";
const string GV_START = "ICT_START_TIME";

//+------------------------------------------------------------------+
//| Journal: append-only                                             |
//+------------------------------------------------------------------+
string ModeText()
  {
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) ? "PAPER" : "LIVE";
  }

void Journal(string ev, string sym, string details)
  {
   StringReplace(details, ",", ";");
   string line = TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS) + " GMT," + ModeText() + "," + ev + "," + sym + "," + details;
   int h = FileOpen(InpJournalFile, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
     {
      Print("JOURNAL ERROR: cannot open file, error ", GetLastError());
      return;
     }
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
   Print(line);
  }

void Notify(string msg)
  {
   Print(msg);
   Alert(msg);
   string m = msg;
   if(StringLen(m) > 250)
      m = StringSubstr(m, 0, 250);
   SendNotification(m);   // works only if MT5 mobile notifications are set up
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double Pip(string s)
  {
   int d = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
   double p = SymbolInfoDouble(s, SYMBOL_POINT);
   return (d == 3 || d == 5) ? p * 10.0 : p;
  }

bool InSession()
  {
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   return ((h >= InpLondonStartGMT && h < InpLondonEndGMT) || (h >= InpNYStartGMT && h < InpNYEndGMT));
  }

datetime StartTime()
  {
   if(!GlobalVariableCheck(GV_START))
      GlobalVariableSet(GV_START, (double)TimeCurrent());
   return (datetime)GlobalVariableGet(GV_START);
  }

double RealizedSince(datetime from)
  {
   double sum = 0.0;
   if(!HistorySelect(from, TimeCurrent() + 86400))
      return 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      long typ = HistoryDealGetInteger(tk, DEAL_TYPE);
      if(typ != DEAL_TYPE_BUY && typ != DEAL_TYPE_SELL) continue;
      sum += HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_COMMISSION) + HistoryDealGetDouble(tk, DEAL_SWAP);
     }
   return sum;
  }

double FloatingPnL()
  {
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return sum;
  }

double VirtualEquity()
  {
   return InpVirtualBalance + RealizedSince(StartTime()) + FloatingPnL();
  }

int OpenCount(string sym = "")
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(sym != "" && PositionGetString(POSITION_SYMBOL) != sym) continue;
      c++;
     }
   return c;
  }

int LossStreak()
  {
   int streak = 0;
   if(!HistorySelect(StartTime(), TimeCurrent() + 86400))
      return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      long en = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(en != DEAL_ENTRY_OUT && en != DEAL_ENTRY_OUT_BY) continue;
      double net = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_COMMISSION) + HistoryDealGetDouble(tk, DEAL_SWAP);
      if(net < 0) streak++;
      else break;
     }
   return streak;
  }

//+------------------------------------------------------------------+
//| SHIELD                                                           |
//+------------------------------------------------------------------+
bool IsStopped() { return GlobalVariableCheck(GV_STOP); }

// Returns "" if no stop condition, otherwise the reason.
string StopReason()
  {
   double base = InpVirtualBalance;
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   double dayPnL = RealizedSince(dayStart) + FloatingPnL();
   double totPnL = RealizedSince(StartTime()) + FloatingPnL();
   if(dayPnL <= -base * InpDailyLossPct / 100.0)
      return StringFormat("Daily loss cap hit: %.2f", dayPnL);
   if(LossStreak() >= InpMaxLossStreak)
      return StringFormat("%d losses in a row", InpMaxLossStreak);
   if(totPnL <= -base * InpTotalLossPct / 100.0)
      return StringFormat("Total loss cap hit: %.2f", totPnL);
   return "";
  }

void DoStop(string reason)
  {
   if(IsStopped()) return;
   GlobalVariableSet(GV_STOP, (double)TimeCurrent());
   g_hasPend = false;
   ClearPanel();
   Journal("STOP_ALL", "", reason);
   Notify("SHIELD STOP ALL: " + reason + ". No new trades. Open trades keep their stops; only you can close them. Restart: set InpClearStop=true once.");
  }

// Shield check for a setup. Returns "" if approved, else the blocking reason.
string ShieldCheck(const Setup &s, bool forOrder)
  {
   if(IsStopped()) return "Bot is stopped by Shield";
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO && !InpGoLive)
      return "Real account detected and InpGoLive is false";
   if(s.sl <= 0.0) return "No stop loss";
   if(s.lots <= 0.0) return "Position size is zero";
   if(!InSession()) return "Outside kill zones";
   if(OpenCount() >= InpMaxOpenTrades) return "Max open trades reached";
   if(OpenCount(s.sym) > 0) return "Already a trade on this pair";
   double pip = Pip(s.sym);
   double spreadPips = (SymbolInfoDouble(s.sym, SYMBOL_ASK) - SymbolInfoDouble(s.sym, SYMBOL_BID)) / pip;
   if(spreadPips > InpMaxSpreadPips) return StringFormat("Spread too high: %.1f pips", spreadPips);
   long tt = SymbolInfoInteger(s.sym, SYMBOL_TIME);
   if(!MQLInfoInteger(MQL_TESTER) && (TimeTradeServer() - (datetime)tt) > InpMaxTickAgeSec)
      return "Price feed stale";
   if(forOrder && GlobalVariableCheck("ICT_DONE_" + s.id)) return "Duplicate: this setup was already sent";
   string sr = StopReason();
   if(sr != "") return sr;
   return "";
  }

//+------------------------------------------------------------------+
//| SCOUT: structure                                                 |
//+------------------------------------------------------------------+
bool PivotHigh(const MqlRates &r[], int i, int k)
  {
   for(int j = 1; j <= k; j++)
      if(!(r[i].high > r[i - j].high && r[i].high > r[i + j].high)) return false;
   return true;
  }

bool PivotLow(const MqlRates &r[], int i, int k)
  {
   for(int j = 1; j <= k; j++)
      if(!(r[i].low < r[i - j].low && r[i].low < r[i + j].low)) return false;
   return true;
  }

// +1 bullish, -1 bearish, 0 none. Uses closed bars only.
int Bias(string sym, ENUM_TIMEFRAMES tf)
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, tf, 0, 120, r) < 60) return 0;
   double hi[2], lo[2];
   int nh = 0, nl = 0;
   for(int i = 3; i < 110 && (nh < 2 || nl < 2); i++)
     {
      if(nh < 2 && PivotHigh(r, i, 2)) hi[nh++] = r[i].high;
      if(nl < 2 && PivotLow(r, i, 2))  lo[nl++] = r[i].low;
     }
   if(nh < 2 || nl < 2) return 0;
   if(hi[0] > hi[1] && lo[0] > lo[1]) return 1;
   if(hi[0] < hi[1] && lo[0] < lo[1]) return -1;
   return 0;
  }

// Position size so that loss at the stop is <= riskMoney. Returns lots, 0 if impossible.
double SizeLots(string sym, int dir, double entry, double sl, double riskMoney, double &actualRisk)
  {
   double p = 0.0;
   ENUM_ORDER_TYPE ot = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(ot, sym, 1.0, entry, sl, p)) return 0.0;
   double lossPerLot = MathAbs(p);
   if(lossPerLot <= 0.0) return 0.0;
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double lots = MathFloor(riskMoney / lossPerLot / step + 1e-9) * step;
   if(lots > vmax) lots = vmax;
   if(lots < vmin)
     {
      actualRisk = vmin * lossPerLot;   // what the smallest allowed trade would risk
      return 0.0;
     }
   actualRisk = lots * lossPerLot;
   return lots;
  }

// Looks for sweep -> market structure shift -> fair value gap -> retrace. dir: +1 buy, -1 sell.
bool FindSetup(string sym, int dir, Setup &s)
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = InpLookbackBars * 2 + 10;
   if(CopyRates(sym, PERIOD_M15, 0, need, r) < need - 5) return false;
   double pip = Pip(sym);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   // 1. Liquidity sweep: newest bar that pokes beyond a prior swing point and closes back inside
   int sw = -1, piv = -1;
   for(int si = 1; si <= InpLookbackBars && sw < 0; si++)
     {
      for(int p = si + 3; p <= si + InpLookbackBars; p++)
        {
         if(p + 2 >= need) break;
         if(dir > 0)
           {
            if(PivotLow(r, p, 2) && r[si].low < r[p].low && r[si].close > r[p].low) { sw = si; piv = p; break; }
           }
         else
           {
            if(PivotHigh(r, p, 2) && r[si].high > r[p].high && r[si].close < r[p].high) { sw = si; piv = p; break; }
           }
        }
     }
   if(sw < 0) return false;

   // 2. Market structure shift after the sweep
   double ref;
   int m = -1;
   if(dir > 0)
     {
      ref = r[sw + 1].high;
      for(int k = sw + 1; k <= piv; k++) if(r[k].high > ref) ref = r[k].high;
      for(int k = sw - 1; k >= 1; k--) if(r[k].close > ref) { m = k; break; }
     }
   else
     {
      ref = r[sw + 1].low;
      for(int k = sw + 1; k <= piv; k++) if(r[k].low < ref) ref = r[k].low;
      for(int k = sw - 1; k >= 1; k--) if(r[k].close < ref) { m = k; break; }
     }
   if(m < 0) return false;

   // 3. Fair value gap formed after the sweep (most recent one), with a retrace bar after it
   int c = -1;
   double zLow = 0, zHigh = 0;
   for(int k = 2; k <= sw - 1 && c < 0; k++)   // k = newest bar of the 3-candle pattern; k>=2 leaves bar 1 as retrace
     {
      if(k + 2 > sw + 1) break;
      if(dir > 0 && r[k + 2].high < r[k].low && (r[k].low - r[k + 2].high) >= InpMinFVGPips * pip)
        { c = k; zLow = r[k + 2].high; zHigh = r[k].low; }
      if(dir < 0 && r[k + 2].low > r[k].high && (r[k + 2].low - r[k].high) >= InpMinFVGPips * pip)
        { c = k; zLow = r[k].high; zHigh = r[k + 2].low; }
     }
   if(c < 0) return false;

   // 4. Retrace: last closed bar traded into the gap but did not close through it
   if(dir > 0 && !(r[1].low <= zHigh && r[1].close > zLow)) return false;
   if(dir < 0 && !(r[1].high >= zLow && r[1].close < zHigh)) return false;

   // Entry, stop, target
   double entry = (dir > 0) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   double sl = (dir > 0) ? r[sw].low - InpSLBufferPips * pip : r[sw].high + InpSLBufferPips * pip;
   double dist = MathAbs(entry - sl);
   if(dist < InpMinSLPips * pip || dist > InpMaxSLPips * pip) return false;
   double tp = (dir > 0) ? entry + InpRR * dist : entry - InpRR * dist;

   s.sym = sym;
   s.dir = dir;
   s.entry = NormalizeDouble(entry, digits);
   s.sl = NormalizeDouble(sl, digits);
   s.tp = NormalizeDouble(tp, digits);
   s.created = TimeCurrent();
   s.id = sym + "_" + (string)(long)r[sw].time + "_" + (dir > 0 ? "B" : "S");
   s.rules = "4H+1H bias aligned; liquidity sweep; structure shift; fair value gap retrace; stop beyond sweep; RR " + DoubleToString(InpRR, 1);
   return true;
  }

//+------------------------------------------------------------------+
//| COORDINATOR panel                                                |
//+------------------------------------------------------------------+
void ClearPanel()
  {
   ObjectDelete(0, "ICT_BTN_OK");
   ObjectDelete(0, "ICT_BTN_NO");
   Comment("");
  }

void MakeButton(string name, string text, int x, color bg)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 32);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

void ShowPanel(const Setup &s)
  {
   string txt = StringFormat("SETUP %s [%s]\n%s %s\nEntry %s  Stop %s  Target %s\nSize %.2f lots  Risk %.2f (%.1f%% of %.0f virtual)\nRules: %s\nShield: APPROVED. Expires in %d min.",
                             s.id, ModeText(), (s.dir > 0 ? "BUY" : "SELL"), s.sym,
                             DoubleToString(s.entry, (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS)),
                             DoubleToString(s.sl, (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS)),
                             DoubleToString(s.tp, (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS)),
                             s.lots, s.riskMoney, InpRiskPct, InpVirtualBalance, s.rules, InpApprovalMinutes);
   Comment(txt);
   MakeButton("ICT_BTN_OK", "APPROVE", 20, clrSeaGreen);
   MakeButton("ICT_BTN_NO", "SKIP", 150, clrFireBrick);
  }

//+------------------------------------------------------------------+
//| PILOT                                                            |
//+------------------------------------------------------------------+
void Approve()
  {
   if(!g_hasPend) return;
   Setup s = g_pend;
   g_hasPend = false;
   ClearPanel();
   Journal("APPROVED", s.sym, "owner approved " + s.id);

   if(TimeCurrent() - s.created > InpApprovalMinutes * 60)
     {
      Journal("EXPIRED", s.sym, s.id);
      Notify("Setup " + s.id + " expired before approval. Nothing sent.");
      return;
     }

   // Re-price at the moment of approval
   double now = (s.dir > 0) ? SymbolInfoDouble(s.sym, SYMBOL_ASK) : SymbolInfoDouble(s.sym, SYMBOL_BID);
   double dist = MathAbs(s.entry - s.sl);
   bool wrongSide = (s.dir > 0 && now <= s.sl) || (s.dir < 0 && now >= s.sl);
   if(wrongSide || MathAbs(now - s.entry) > InpMaxDriftR * dist)
     {
      Journal("BLOCKED", s.sym, "price moved too far from entry before approval");
      g_cntBlocked++;
      Notify("Setup " + s.id + " blocked: price moved too far from entry. Nothing sent.");
      return;
     }
   s.entry = now;
   double newDist = MathAbs(s.entry - s.sl);
   s.tp = (s.dir > 0) ? s.entry + InpRR * newDist : s.entry - InpRR * newDist;
   int digits = (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS);
   s.tp = NormalizeDouble(s.tp, digits);
   double actual = 0.0;
   s.lots = SizeLots(s.sym, s.dir, s.entry, s.sl, VirtualEquity() * InpRiskPct / 100.0, actual);
   s.riskMoney = actual;

   string why = ShieldCheck(s, true);
   if(why != "")
     {
      Journal("BLOCKED", s.sym, why);
      g_cntBlocked++;
      Notify("Shield blocked " + s.id + ": " + why);
      return;
     }

   // Mark done BEFORE sending so a retry can never create a duplicate
   GlobalVariableSet("ICT_DONE_" + s.id, (double)TimeCurrent());
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFillingBySymbol(s.sym);
   bool ok = (s.dir > 0) ? trade.Buy(s.lots, s.sym, 0.0, s.sl, s.tp, s.id)
                         : trade.Sell(s.lots, s.sym, 0.0, s.sl, s.tp, s.id);
   uint rc = trade.ResultRetcode();
   g_cntOrders++;
   Journal("ORDER_SENT", s.sym, StringFormat("%s %.2f lots sl=%s tp=%s retcode=%u", (s.dir > 0 ? "BUY" : "SELL"), s.lots,
           DoubleToString(s.sl, digits), DoubleToString(s.tp, digits), rc));
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
     {
      string t = StringFormat("FILL %s %s: price %s, volume %.2f of %.2f requested. Stop %s attached.",
                              s.id, ModeText(), DoubleToString(trade.ResultPrice(), digits), trade.ResultVolume(), s.lots,
                              DoubleToString(s.sl, digits));
      if(rc == TRADE_RETCODE_DONE_PARTIAL) t += " PARTIAL FILL: stop covers the filled amount only.";
      Journal("FILL", s.sym, t);
      Notify(t);
     }
   else
     {
      // Never resend. Check whether the order actually went through.
      bool exists = (OpenCount(s.sym) > 0);
      string t = StringFormat("ORDER PROBLEM %s: retcode %u (%s). Position found on broker: %s. NOT RESENT.",
                              s.id, rc, trade.ResultRetcodeDescription(), exists ? "YES" : "NO");
      Journal("ORDER_PROBLEM", s.sym, t);
      Notify(t);
     }
  }

void Skip()
  {
   if(!g_hasPend) return;
   Journal("SKIPPED", g_pend.sym, g_pend.id);
   g_cntSkipped++;
   g_hasPend = false;
   ClearPanel();
  }

//+------------------------------------------------------------------+
//| SCOUT: scan one symbol on a new closed 15-minute bar             |
//+------------------------------------------------------------------+
void ScanSymbol(int idx)
  {
   if(g_hasPend || IsStopped() || !InSession()) return;
   string sym = g_syms[idx];
   int b4 = Bias(sym, PERIOD_H4);
   int b1 = Bias(sym, PERIOD_H1);
   int bd = Bias(sym, PERIOD_D1);
   if(b4 == 0 || b4 != b1) return;
   if(bd == -b4) return;

   Setup s;
   if(!FindSetup(sym, b4, s)) return;
   if(s.id == g_lastId[idx]) return;
   g_lastId[idx] = s.id;
   g_cntSetups++;

   double actual = 0.0;
   double riskMoney = VirtualEquity() * InpRiskPct / 100.0;
   s.lots = SizeLots(sym, s.dir, s.entry, s.sl, riskMoney, actual);
   s.riskMoney = actual;
   Journal("SETUP", sym, StringFormat("%s %s entry=%s sl=%s tp=%s", s.id, (s.dir > 0 ? "BUY" : "SELL"),
           DoubleToString(s.entry, 5), DoubleToString(s.sl, 5), DoubleToString(s.tp, 5)));

   string why;
   if(s.lots <= 0.0)
      why = StringFormat("Smallest allowed trade would risk %.2f, above the %.2f limit", actual, riskMoney);
   else
      why = ShieldCheck(s, false);
   if(why != "")
     {
      g_cntBlocked++;
      Journal("BLOCKED", sym, why);
      Notify("Setup " + s.id + " BLOCKED by Shield: " + why);
      return;
     }
   g_pend = s;
   g_hasPend = true;
   Journal("AWAITING_APPROVAL", sym, s.id);
   Notify(StringFormat("SETUP %s %s %s lots %.2f risk %.2f. Open MT5 and click APPROVE or SKIP.",
                       (s.dir > 0 ? "BUY" : "SELL"), sym, s.id, s.lots, s.riskMoney));
   ShowPanel(s);
   if(MQLInfoInteger(MQL_TESTER) && InpTesterAutoApprove)
      Approve();
  }

//+------------------------------------------------------------------+
//| COORDINATOR: daily message                                       |
//+------------------------------------------------------------------+
void DailyMessage()
  {
   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   if(t.hour != InpDailyMsgHourGMT || t.day_of_year == g_lastMsgDay) return;
   g_lastMsgDay = t.day_of_year;

   string mkt = "";
   for(int i = 0; i < g_n; i++)
     {
      double c1 = iClose(g_syms[i], PERIOD_D1, 1), c2 = iClose(g_syms[i], PERIOD_D1, 2);
      if(c1 > 0 && c2 > 0)
         mkt += StringFormat("%s %+.2f%%  ", g_syms[i], (c1 - c2) / c2 * 100.0);
     }
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   string msg = StringFormat("DAILY [%s] source: broker feed, %s GMT | Market (last daily close): %s| Setups %d, blocked %d, skipped %d, orders %d | Open trades %d | Today P&L %.2f | Virtual equity %.2f | Status: %s | Decision needed: %s",
                             ModeText(), TimeToString(TimeGMT(), TIME_DATE | TIME_MINUTES), mkt,
                             g_cntSetups, g_cntBlocked, g_cntSkipped, g_cntOrders, OpenCount(),
                             RealizedSince(dayStart) + FloatingPnL(), VirtualEquity(),
                             IsStopped() ? "STOPPED by Shield" : "running",
                             IsStopped() ? "restart or leave stopped?" : (g_hasPend ? "approve or skip pending setup" : "none"));
   Journal("DAILY", "", msg);
   Notify(msg);
   g_cntSetups = g_cntBlocked = g_cntSkipped = g_cntOrders = 0;
  }

//+------------------------------------------------------------------+
//| Events                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpClearStop && GlobalVariableCheck(GV_STOP))
     {
      GlobalVariableDel(GV_STOP);
      Journal("STOP_CLEARED", "", "owner cleared the Shield stop");
     }
   StartTime();
   g_n = StringSplit(InpSymbols, ',', g_syms);
   if(g_n <= 0) return INIT_PARAMETERS_INCORRECT;
   ArrayResize(g_lastBar, g_n);
   ArrayResize(g_lastId, g_n);
   ArrayResize(g_stale, g_n);
   for(int i = 0; i < g_n; i++)
     {
      StringTrimLeft(g_syms[i]);
      StringTrimRight(g_syms[i]);
      g_syms[i] += InpSuffix;
      g_lastBar[i] = 0;
      g_lastId[i] = "";
      g_stale[i] = false;
      if(!SymbolSelect(g_syms[i], true))
        {
         Print("Symbol not available on this account: ", g_syms[i]);
         return INIT_FAILED;
        }
     }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO && !InpGoLive)
     {
      Alert("REAL account detected and InpGoLive is false. EA refuses to start.");
      return INIT_FAILED;
     }
   EventSetTimer(5);
   Journal("STARTED", "", StringFormat("virtual balance %.2f, risk %.2f%%, daily cap %.2f%%, streak %d, total cap %.2f%%",
           InpVirtualBalance, InpRiskPct, InpDailyLossPct, InpMaxLossStreak, InpTotalLossPct));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ClearPanel();
   Journal("STOPPED_EA", "", "EA removed or terminal closed, reason code " + IntegerToString(reason));
  }

void OnTimer()
  {
   if(!IsStopped())
     {
      string r = StopReason();
      if(r != "") DoStop(r);
     }

   // Expire pending approval
   if(g_hasPend && TimeCurrent() - g_pend.created > InpApprovalMinutes * 60)
     {
      Journal("EXPIRED", g_pend.sym, g_pend.id);
      Notify("Setup " + g_pend.id + " expired. Nothing sent.");
      g_hasPend = false;
      ClearPanel();
     }

   for(int i = 0; i < g_n; i++)
     {
      // Stale-feed warning during kill zones
      if(InSession() && !MQLInfoInteger(MQL_TESTER))
        {
         long tt = SymbolInfoInteger(g_syms[i], SYMBOL_TIME);
         bool stale = (TimeTradeServer() - (datetime)tt) > 120;
         if(stale && !g_stale[i])
           {
            g_stale[i] = true;
            Journal("FEED_STALE", g_syms[i], "no new price for over 2 minutes; no setups, orders blocked");
            Notify("FEED STALE on " + g_syms[i] + ". Orders blocked until prices resume.");
           }
         if(!stale) g_stale[i] = false;
         if(stale) continue;
        }
      datetime bt = iTime(g_syms[i], PERIOD_M15, 0);
      if(bt == 0) continue;
      if(bt != g_lastBar[i])
        {
         bool first = (g_lastBar[i] == 0);
         g_lastBar[i] = bt;
         if(!first) ScanSymbol(i);
        }
     }
   DailyMessage();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == "ICT_BTN_OK")
     {
      ObjectSetInteger(0, "ICT_BTN_OK", OBJPROP_STATE, false);
      Approve();
     }
   else if(sparam == "ICT_BTN_NO")
     {
      ObjectSetInteger(0, "ICT_BTN_NO", OBJPROP_STATE, false);
      Skip();
     }
  }

// Log closed trades and re-check stop rules the moment a loss lands
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
   long en = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(en != DEAL_ENTRY_OUT && en != DEAL_ENTRY_OUT_BY) return;
   double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) + HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   Journal("CLOSED", HistoryDealGetString(trans.deal, DEAL_SYMBOL),
           StringFormat("net result %.2f price %s", net, DoubleToString(HistoryDealGetDouble(trans.deal, DEAL_PRICE), 5)));
   string r = StopReason();
   if(r != "") DoStop(r);
  }

void OnTick() { }
//+------------------------------------------------------------------+
