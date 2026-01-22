# Automated Forex Trader

## Overview
Python + MetaTrader4 system for automated forex trading via external webhook signals.

## Structure
- `webhook_server.py` – Flask server receiving external alerts
- `mt4_bridge.py` – Python bridge sending signals to MT4
- `mt4/` – MetaTrader4 Expert Advisor (MQL4) executing trades, handling risk, and logging profits

## Features
- Validates external buy/sell signals
- Executes trades via MT4 with risk-based sizing
- Scheduled trade liquidation and persistent P&L tracking