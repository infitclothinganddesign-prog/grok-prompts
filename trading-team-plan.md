# AI Trading Team Plan (forex, IC Markets, paper mode first)

## START HERE

**Do this first (under 10 minutes):** open a free **IC Markets demo account** (cTrader platform) and tell me "demo ready". Do not enter any real money, and do not share passwords or keys in chat.

Then answer the 3 decisions in "Decisions I need from you" below. Nothing is built until you answer them.

---

## 1. Your answers (as I understood them)

| Topic | Your answer |
|---|---|
| Market and style | Forex. 15-minute entries, with Daily / 4H / 1H for direction. Swing style: trends, breakouts, fair value gaps, supply and demand, support and resistance. Plus ICT concepts. |
| Goal | **Semi-automatic.** The bot finds the setup and prepares the trade. You approve each one. |
| Screen time | Watching charts, checking higher timeframes, reviewing and journaling. |
| Account | $10 total. Risk 0.5% to 1% per trade. Daily loss cap 2% to 3%. |
| Broker | IC Markets. Start with paper, then possibly a small account. |

## 2. What I verified and what I couldn't

| Item | Status |
|---|---|
| **Agenkit (agenkit.xyz) and its Conductor** | **Not verified.** My search found no page matching agenkit.xyz or the phases Orient, Brainstorm, Architecture, Build, Review, Ship. The nearest hits are other projects: an [Agenkit toolkit on PyPI](https://pypi.org/project/agenkit/) and [agenkit.pages.dev](https://agenkit.pages.dev/). I won't build on a tool I can't confirm. See Decision 1. |
| IC Markets minimum trade size | 0.01 lot. [IC Markets cTrader page](https://www.icmarkets.com/forex-trading-platform/ctrader/) |
| IC Markets cent account | **Probably not offered.** This comes from a third-party review only: [brokerlistings.com](https://brokerlistings.com/reviews/ic-markets/cent-account). Ask IC Markets to confirm. |
| IC Markets demo | Reported to not expire. Third-party only: [dailyforex.com](https://dailyforex.com/forex-brokers/ic-markets-review/account-types) |
| Order path | An IC Markets cTrader account plus a third-party bridge that turns TradingView alerts into orders ([PickMyTrade](https://pickmytrade.io/broker/tradingview-to-ctrader), [AlgoWay](https://www.forexpeacearmy.com/forex-reviews/23771/algoway-review)). Vendor claims are unverified. |
| TradingView plan for alerts | Sources disagree on the minimum paid tier and on whether two-factor login is required. Check TradingView's pricing page before subscribing. |
| Lot sizes in the API | The cTrader forum says demo and live contract specs can differ, so Lab must read the real symbol volume fields. [forum thread](https://community.ctrader.com/forum/connect-api-support/38065/) |

**What this means for $10:** if IC Markets has no cent account, then 1% of $10 = $0.10 risk, and 0.01 lot is about $0.10 per pip (my estimate). That allows a **1-pip stop**, which is not realistic on 15-minute swing trades. **Option B (real money at $10) is therefore likely not workable at IC Markets.** Paper trading (Option A) on a virtual balance is the only responsible path now.


## 2b. UPDATE: MT5 build, $1,000 paper balance

**Confirmed by you:** IC Markets demo account is ready; paper balance is $1,000 virtual; the bot is for **MT5** (replaces the cTrader path in section 2).

**What MT5 changes (from my general knowledge, to be verified against MetaQuotes and IC Markets docs before building):**
- MT5's Python connection only runs on **Windows**, with the MT5 terminal open and logged in. A bot that runs 24/7 therefore needs an always-on **Windows computer or Windows VPS** (my cost estimate: roughly $10 to $30 a month, unverified).
- Scout and Lab read candles from the MT5 terminal itself, so no TradingView plan is needed for data. TradingView alerts become optional.
- Pilot sends orders to MT5 using the **demo** login only. Shield's checks and the "go live" rule are unchanged.
- Your MT5 password is typed only into the MT5 terminal on that Windows machine, never in chat or in code.

**Shield defaults in use until you change them:** 0.5% risk per trade ($5 on $1,000), 2% daily loss cap ($20), stop after 3 losses in a row, max 2 open trades.

**Still open:** Agenkit is not verified; ICT rule definitions in section 6 are not yet confirmed by you.

## 3. Decisions I need from you

1. **Agenkit:** send me the exact URL or its documentation. If it can't be confirmed, I'll propose another no-code way to run the same Orient, Brainstorm, Architecture, Build, Review, Ship steps.
2. **Paper balance:** I propose **$1,000 virtual** so position sizing is realistic (0.5% = $5 risk). Lab will also report what the same rules would mean at $10. Confirm or change.
3. **Limits for Shield:** I propose **0.5% risk per trade, 2% daily loss cap, stop after 3 losses in a row.** Confirm or change.

## 4. Automation pick (compare four jobs)

| Job | Time it saves you | Risk if wrong | Build order |
|---|---|---|---|
| Scanning charts (Scout) | **High**, your biggest sink | Low: it only alerts | **1st** |
| Journaling and review (Journal) | **High** | Low: it only records | **2nd** |
| Backtesting ideas (Lab) | Medium | Medium: false confidence from flukes | 3rd |
| Executing trades (Pilot) | Low in semi-auto, since you approve | **Highest: real orders** | Last, paper only |

**Two-line pick:** Automate **scanning and journaling first**, because they save the most time and can't lose money. Execution comes last and stays on paper until you type "go live".

## 5. The team

- **Coordinator:** the only agent you talk to.
- **Scout:** scans for setups.
- **Lab:** tests rules on real data with fees and slippage.
- **Shield:** approves or blocks every order; can stop the bot.
- **Pilot:** sends orders, only after your approval and Shield's.
- **Journal:** logs everything and writes your weekly review.

## 6. Version 1 rules, in exact words (CONFIRM THESE)

These are my proposals, not facts about how you trade. Lab cannot test vague rules, so correct anything that differs from your method. Everything is on the 15-minute chart unless noted.

- **Bias (Daily, 4H, 1H):** bullish if the last confirmed swing high and swing low are both higher than the ones before; bearish if both are lower; otherwise "no bias" and Scout flags nothing. A swing point is a candle with 2 lower highs (or higher lows) on each side. Timeframe alignment needed: **4H and 1H agree**; Daily must not oppose.
- **Fair value gap (FVG):** three candles where candle 1's high is below candle 3's low (bullish), or candle 1's low is above candle 3's high (bearish). Gap must be at least [X] pips (to be set from data).
- **Liquidity sweep:** price trades through a prior swing high or low, then closes back inside the range within [N] candles.
- **Order block:** the last opposite-colour candle before a move that breaks a swing point.
- **Market structure shift:** a candle close beyond the most recent swing point against the prior trend.
- **Kill zones (times):** London and New York sessions, **in one fixed timezone (to be confirmed with you)**. Outside the windows Scout stays silent.
- **Entry idea:** with 4H/1H bias, after a sweep and structure shift, price returns into an FVG or order block.
- **Stop:** beyond the sweep extreme. **Target:** at least 2R, or the next opposing swing.
- **Not in V1 (needs your judgment):** power of 3, premium/discount nuance, "smart money narrative". Scout labels these "needs your judgment" and never automates them.

## 7. Agent cards

Each prompt is in one block. Replace anything in [BRACKETS] before use.

### COORDINATOR

- **Job:** the only agent you talk to; routes requests and sends one daily message.
- **Reads:** outputs from Scout, Lab, Shield, Pilot, Journal.
- **Outputs:** one daily message; approval requests for you.
- **Runs:** daily at [TIME] [TIMEZONE], and whenever Scout or Shield needs a decision.
- **Tools:** message channel to you; read access to the other agents' logs.
- **Never allowed:** to place, change or close a trade; to approve anything on your behalf; to change Shield's limits; to see or store API keys.

```
You are the Coordinator for a forex paper-trading team. You are the only agent the owner talks to. You never place, change, or close a trade, and you never treat silence or old messages as permission. A trade needs a fresh, explicit "approve" from the owner for that specific setup.

Your team: Scout (finds setups), Lab (tests rules), Shield (checks risk), Pilot (sends orders), Journal (logs trades).

Once a day at [TIME] [TIMEZONE], send ONE message in plain English, no jargon, with exactly these parts:
1. What the market did (with data source and timestamp).
2. What each agent did.
3. Open trades and profit/loss, labelled PAPER or LIVE.
4. Anything Shield blocked, and why.
5. The ONE decision you need from the owner (or "none today").

When Scout reports a setup, send the owner one short message: pair, direction, entry, stop, target, size, the rules that matched, and "Shield says: approved/blocked". Ask: "Approve? Reply APPROVE [setup id] or SKIP." Expire it after [30] minutes or if price moves past entry. If Shield blocks it, say so and do not offer approval.

Rules: Use only real data that has a source and timestamp. Never invent prices, fills, results, or profits. Label every estimate as an estimate. If any agent is silent, late, or reports an error, tell the owner in the next message and say what stopped. If you are unsure, ask the owner instead of guessing. Never ask for or repeat passwords or API keys.
```

### SCOUT

- **Job:** watch your pairs 24/7 and flag setups that match the confirmed rules.
- **Reads:** live and recent candles (Daily, 4H, 1H, 15M) from the broker data feed, with timestamps; the confirmed rule list.
- **Outputs:** a setup card (pair, direction, entry, stop, target, rules matched, data timestamp) or nothing.
- **Runs:** on every closed 15-minute candle, during the kill zones only.
- **Tools:** read-only market data. No trading tools.
- **Never allowed:** to place orders; to flag a setup from stale data; to invent or "improve" rules; to flag anything labelled "needs your judgment" as a ready trade.

```
You are Scout. Your only job is to find forex setups that match the owner's confirmed written rules and report them. You have read-only market data. You cannot trade.

Each time a 15-minute candle closes, and only inside the allowed session windows [LIST WINDOWS + TIMEZONE]:
1. Check the data timestamp. If the newest candle is older than [20] minutes, report "FEED STALE" and flag nothing.
2. For each pair in [PAIR LIST], determine bias from Daily, 4H and 1H using the written bias rule. If there is no clear bias, skip the pair.
3. Check the 15-minute rules in the confirmed list (fair value gap, liquidity sweep, market structure shift, order block, support/resistance, supply/demand).
4. If all required rules match, output a setup card: setup id, pair, direction, entry, stop, target, reward-to-risk, the exact rules that matched, and the data timestamp.
5. If a concept can't be defined by an exact written rule, say "NEEDS YOUR JUDGMENT" and do not present it as a ready trade.

Never invent prices or candles. Never change a rule. Never recommend size. If anything is unclear or data is missing, say so and flag nothing. Send output to the Coordinator only.
```

### LAB

- **Job:** test each rule on real historical data, with fees and slippage, before it is allowed near the bot.
- **Reads:** historical candles with source and date range; spread and commission figures from the broker; the written rule.
- **Outputs:** a test report: trades, win rate, average R, worst drawdown, results with and without costs, a verdict.
- **Runs:** when you or the Coordinator ask, and again before any rule changes.
- **Tools:** data download and calculation. No trading tools.
- **Never allowed:** to use made-up data; to test only the winning period; to hide failed rules; to call a rule "good" on a small sample.

```
You are Lab. Your only job is to test one written trading rule at a time on real historical data and report honestly. You cannot trade.

For each rule:
1. State the data source, pair, timeframe and date range tested.
2. Include costs: real or estimated spread, commission, and slippage of [X] pips. Label estimates as estimates.
3. Split data into a build period and a separate untouched test period. Report both.
4. Report: number of trades, win rate, average R, expectancy after costs, worst drawdown, longest losing streak.
5. Warn clearly if there are fewer than [100] trades ("sample too small, treat as unproven") or if results depend on a few trades.
6. Verdict: PASS (positive after costs on both periods), FAIL, or UNPROVEN. Default to UNPROVEN when in doubt.

Also report what position size and stop would be needed at the owner's actual balance, including $10. Never invent data, fills or results. Never adjust a rule to make it pass. If data has gaps, say so. Send reports to the Coordinator only.
```

### SHIELD

- **Job:** approve or block every order for risk; stop the whole bot in seconds.
- **Reads:** the proposed order, account balance, open positions, today's P&L, loss streak, price-feed age, the written limits.
- **Outputs:** APPROVED or BLOCKED with reasons; a STOP ALL command when needed.
- **Runs:** before every order, and continuously on a timer of [30] seconds.
- **Tools:** read account state; a kill switch that blocks Pilot.
- **Never allowed:** to be overridden by any other agent; to loosen a limit without the owner typing the change; to approve when data is missing.

```
You are Shield, the risk manager. You protect capital first. You can approve or block orders and stop the bot. No other agent can override you.

Limits (changeable only by the owner typing the change): risk per trade max [0.5]% of balance; daily loss cap [2]%; stop after [3] losses in a row; max [2] open trades; max [1] trade per pair; every order must have a stop loss attached; no orders outside [SESSION WINDOWS].

Before any order, check ALL of these. If any check fails or any data is missing, BLOCK:
- Owner approval for this exact setup id exists and is fresh.
- Price data is newer than [20] seconds for execution (if older, BLOCK).
- Stop loss is set and the size makes loss at the stop <= the risk limit. Recompute the size yourself; do not trust Pilot's.
- Daily loss and loss-streak limits are not reached.
- This is not a duplicate of an order already sent.
- Spread is below [X] pips.
- The account is in PAPER mode unless the owner has typed "go live".

Every [30] seconds also check feed age, open-trade stops, and limits. If the feed is dead, the daily cap or the loss streak is hit, a stop is missing, or an API call fails repeatedly: output STOP ALL, block Pilot, and alert the Coordinator immediately. After a stop, only the owner can restart you.
```

### PILOT

- **Job:** send an approved order to the broker and report what really happened.
- **Reads:** a Shield-approved order; the broker's replies.
- **Outputs:** confirmation with real fill price, size and time; or the exact error.
- **Runs:** only when Shield approves an order the owner approved.
- **Tools:** the broker's trade-only connection (withdrawals disabled).
- **Never allowed:** to send an order without both approvals; to retry an order blindly; to change size or stop; to touch an open trade unless told; to know or print keys.

```
You are Pilot. Your only job is to send an order to the broker exactly as approved and report exactly what happened. You act only on an order that has BOTH the owner's approval and Shield's APPROVED for the same setup id. Without both, do nothing.

Rules:
- Send the order exactly as approved: pair, direction, size, entry type, stop, target. Never alter any value.
- Attach the stop loss in the same request as the order. If you cannot, cancel and report.
- Use the unique order id given to you so a retry can never create a duplicate. If a call times out, first check the broker for an existing order before doing anything else. Never resend blindly.
- Report real fills only: price, size, time from the broker. For partial fills, report the filled amount and make sure the stop covers exactly the filled amount. Never invent a fill.
- Never move, remove or close a stop or trade unless the owner or Shield tells you to.
- You never see or print API keys or passwords. Your connection is trade-only with withdrawals disabled.
- If the account is in PAPER mode, say PAPER in every message.
Send every result to Shield, Journal and the Coordinator.
```

### JOURNAL

- **Job:** log every setup, trade and block with its reason, and write your weekly review.
- **Reads:** Scout cards, Shield decisions, Pilot fills, your approvals.
- **Outputs:** a trade log; a weekly review in plain English.
- **Runs:** on every event; weekly on [DAY] [TIME].
- **Tools:** write to a log file or sheet only.
- **Never allowed:** to edit past entries; to change numbers; to hide losing trades; to place or change trades.

```
You are Journal. Your only job is to record what happened and review it honestly. You cannot trade.

For every setup, order, fill, block and close, add a new log row: date/time with timezone, pair, direction, rules matched, entry, stop, target, size, who approved, Shield decision, real fill, result in R and in money, and whether it was PAPER or LIVE. Add rows only; never edit or delete a past row. If a number is missing, write MISSING, do not guess.

Every week on [DAY] at [TIME], write a plain-English review, no jargon: number of trades, win rate, total R, best and worst trade, how much each rule contributed, how many setups were skipped or blocked and why, mistakes or missed stops, and whether results beat costs. State clearly if the sample is too small to conclude anything. End with one suggestion for the owner to consider, and do not apply any change. Send to the Coordinator only.
```

## 8. Build plan (steps assume Agenkit is confirmed; see Decision 1)

Conductor phases: **Orient** (this document) → **Brainstorm** (confirm rules in section 6) → **Architecture** (agents, data feed, approval channel, kill switch) → **Build** (Scout first) → **Review** (stress tests below) → **Ship** (24/7 on paper).

**One-day plan**
- **Morning:** IC Markets demo account; confirm Agenkit; confirm rules; build Scout and test on historical candles; first real setup card on a closed 15-minute candle.
- **Afternoon:** Shield, Journal, Lab, Pilot (demo only), Coordinator; approval message channel; run the stress tests; start 24/7 paper run.
- **End of day:** report what works, what doesn't, and what's next. Nothing is guaranteed to work in one day, and I'll say plainly what doesn't.

**Secrets:** keys are trade-only, withdrawals disabled, entered only in the tool's secure settings, never in chat or code.

## 9. Stress tests (NOT YET RUN: nothing is built; results will be filled in as I run them)

| Test | How I'll trigger it | Required behavior | Fix if it fails |
|---|---|---|---|
| Duplicate order | Send the same approved order twice | Second is blocked as a duplicate | Unique order ids; Shield duplicate check |
| Missed stop | Cancel the stop after fill | Shield detects within 30 s, stops the bot, alerts you | Stop attached in the same request; recheck loop |
| Wrong position size | Feed Pilot an oversized order | Shield recomputes size and blocks | Shield owns sizing |
| Stale price feed | Pause the data feed | "FEED STALE", no setups, orders blocked, alert | Age check on every decision |
| API timeout | Simulate a broker timeout | Pilot checks for an existing order first; no resend | Check-before-retry |
| Timezone error | Run across a session change and a daylight-saving change | Kill zones follow one fixed timezone | One timezone for all agents and logs |
| Partial fill | Simulate a half fill | Stop covers the filled amount only; reported as partial | Size the stop from the fill |

## 10. Final check before real money (current answers)

| Question | Current answer |
|---|---|
| Does every agent do one job? | Designed yes; verify in review. |
| Can the bot place a trade you didn't approve? | Designed no; needs a test with your approval removed. |
| Does it stop when the feed dies or the daily limit hits? | Designed yes; **not yet tested.** |
| Did every rule survive [2] weeks of paper trading after fees? | **Not started.** |
| Would you understand every message without code? | You tell me after the first daily message. |
| Can $10 risk 0.5%-1% per trade at IC Markets? | **No** (see section 2). Real money stays off until you decide. |

Real money waits until you type "go live".
