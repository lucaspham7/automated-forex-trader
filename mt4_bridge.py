import sys
import os
from datetime import datetime


def send_trade(signal, symbol):
    now = datetime.now()
    current_hour = now.hour


    # Allow trading 8:00 - 11:59 AM
    if (8 <= current_hour < 12):
        file_path = r"C:\Users\lukie\AppData\Roaming\MetaQuotes\Terminal\7E6C4A6F67D435CAE80890D8C1401332\MQL4\Files\trade.txt"
        try:
            with open(file_path, "w") as f:
                f.write(f"{signal.upper()} {symbol}")
            print(f"Signal sent: {signal.upper()} {symbol}")
        except Exception as e:
            print(f"Error writing trade file: {e}")
    else:
        print(f"Trade signal '{signal.upper()} {symbol}' ignored: Not within allowed time window (8 AM - 12 PM).")


# Optional: CLI usage
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python mt4_bridge.py [buy/sell] [symbol]")
    else:
        send_trade(sys.argv[1], sys.argv[2])