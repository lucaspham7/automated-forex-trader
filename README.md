# Automated Forex Trader

## Overview
A Python–MetaTrader4 automated trading system that executes forex trades based on external webhook alerts.  
The system receives buy/sell signals via a Flask webhook, validates them locally, and delivers approved trade instructions to MetaTrader4 using a file-based communication bridge.

This architecture enables fully automated trade execution while keeping MetaTrader4 isolated from direct network access.

---

## Architecture
External Alert  
→ Flask Webhook  
→ Python Validation  
→ Local Trade File  
→ MT4 Expert Advisor  
→ Trade Execution

---

## Project Structure
webhook_server.py # Flask server receiving webhook alerts
mt4_bridge.py # Python bridge writing trade instructions to MT4
mt4/ # MetaTrader4 Expert Advisor (MQL4)

---

## How It Works

### 1. Webhook Server (Flask)
- Exposes a `/webhook` POST endpoint
- Accepts JSON payloads containing a trade signal (`buy` or `sell`)
- Validates incoming requests before execution
- Passes approved signals to the MT4 bridge

### 2. Signal Validation & Time Window
- Trade execution is restricted to a predefined window (8:00 AM – 12:00 PM)
- Signals received outside this window are ignored
- Prevents unintended or off-hours trade execution

### 3. Python–MT4 File-Based Bridge
- Approved trade signals are written to a local file (`trade.txt`)
- File is placed inside the MT4 `MQL4/Files` directory
- Serves as a lightweight IPC mechanism between Python and MetaTrader4
- Avoids direct socket or network communication, aligning with MT4 sandbox constraints

### 4. Trade Execution (MT4 Expert Advisor)
- The MQL4 Expert Advisor continuously monitors the trade file
- When a new instruction is detected, the EA:
  - Executes the trade
  - Applies dynamic position sizing
  - Reconciles open positions
  - Logs trade outcomes and profit persistently
- Optional scheduled liquidation logic closes positions at predefined times

---

## Features
- Flask-based webhook receiver
- Secure, time-gated trade execution
- Python → MT4 file-based IPC bridge
- Fully automated buy/sell execution
- Dynamic risk-based position sizing
- Automated position reconciliation
- Scheduled trade liquidation
- Persistent P&L logging
