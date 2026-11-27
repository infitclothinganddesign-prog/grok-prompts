# ICT Team EA: setup guide (Mac, Deriv-Demo MT5)

**Status: written but NEVER compiled or run.** I can't run MT5 here. Treat it as a first draft. The first job is to compile it and send me every error message so I can fix it.

## What it does

| Part | What it does in this file |
|---|---|
| Scout | Every closed 15-minute bar, inside the kill zones, checks EURUSD, GBPUSD, USDJPY. 4H and 1H bias must agree and Daily must not oppose. Then it looks for: liquidity sweep → market structure shift → fair value gap → retrace into the gap. |
| Shield | Blocks any setup that breaks a limit. Stops the bot on 2% daily loss, 3 losses in a row, or 10% total loss. After a stop, only you can restart it. It never closes your trades; open trades keep their stops. |
| Pilot | Sends the order only after your APPROVE click and a fresh Shield check. Stop and target go in the same request. One order per setup, never resent. |
| Journal | Appends every event to `ICT_Journal.csv` (never edits old lines). |
| Coordinator | Chart panel with APPROVE / SKIP buttons, pop-up alerts, optional phone notifications, and one daily summary at 21:00 GMT. |

## Install (about 10 minutes, no coding)

1. Open MT5 on your Mac, logged in to **Deriv-Demo**.
2. Menu **File → Open Data Folder**. Go to `MQL5 → Experts`. Copy `ICT_Team_EA.mq5` into it.
3. In MT5 press **F4** (MetaEditor). Open the file, press **F7** to compile.
4. **Copy every error or warning and send it to me.** Don't change anything yourself.
5. When it compiles with 0 errors: in MT5 open a **EURUSD M15** chart. In the Navigator panel, find `ICT_Team_EA`, drag it onto the chart.
6. In the dialog: tick **Allow Algo Trading**. Leave the inputs as they are. Click OK. Make sure the Algo Trading button at the top is on.
7. Keep the Mac awake: System Settings → turn off sleep while MT5 runs. Keep MT5 open.

## Before it trades: check these first

- **Symbol names.** Deriv may name pairs differently (a suffix, for example). If the EA fails to start with "Symbol not available", tell me the exact names in Market Watch.
- **Minimum lot and spread** for EURUSD: Market Watch → right-click → Specification. Send me the minimum volume and spread.
- **Time zone.** Kill zones are in GMT (London 07-10, New York 12-15). These are my proposals, not your confirmed times.

## Safety built in

- Refuses to start on a real account unless you set `InpGoLive = true`. Do not do this until we have agreed that you're ready.
- If the smallest allowed trade would risk more than 0.5% of $1,000 ($5), Shield blocks it and tells you why.
- Setups expire after 30 minutes, or if price moves more than 0.25R from the planned entry.
- If prices stop updating for over 2 minutes, Scout stays silent and orders are blocked.

## Restarting after a Shield stop

Set `InpClearStop = true` in the EA inputs, click OK, then set it back to `false`.

## Testing (Lab) in MT5's Strategy Tester

Not yet done. Open View → Strategy Tester, pick this EA, one symbol, M15, a date range, and "Every tick based on real ticks" if Deriv provides it. Set `InpTesterAutoApprove = true` **in the tester only**. Send me the report. I will not quote any numbers until I see your real ones.

## Known limits (honest list)

- Not compiled or tested. Expect errors on first compile.
- The rules are my proposals from plan section 6. You have not confirmed them.
- One pending setup at a time; others found meanwhile are ignored.
- Phone notifications need MT5 mobile set up separately; I haven't verified this.
- Reported lot sizes, margin and costs on Deriv-Demo are unknown until you send the Specification.
