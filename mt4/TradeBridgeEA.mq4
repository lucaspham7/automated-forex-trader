#property strict


// === Inputs ===
input string FilePath = "trade.txt";
input double RiskPercent = 3.0;
input int Slippage = 3;


// === Config Files ===
string LogFile     = "trade_log.txt";
string ProfitFile  = "daily_profit.txt";
string SymbolToTrade = "";


// === State ===
datetime lastCloseDay = 0;


// === StringTrim Helper ===
string StringTrim(string s) {
    // Trim leading spaces
    while (StringLen(s) > 0 && StringGetChar(s, 0) == ' ')
        s = StringSubstr(s, 1);


    // Trim trailing spaces
    while (StringLen(s) > 0 && StringGetChar(s, StringLen(s) - 1) == ' ')
        s = StringSubstr(s, 0, StringLen(s) - 1);


    return s;
}


// === Logging Helper ===
void Log(string message) {
    int handle = FileOpen(LogFile, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
    if (handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);
        FileWrite(handle, timestamp, " - ", message);
        FileClose(handle);
    }
    Print(message);
}


// === Profit Tracker (per symbol) ===
void UpdateDailyProfit(string symbol, double profit) {
    string today = TimeToString(TimeLocal(), TIME_DATE);
    string line;
    string updatedContent = "";
    bool dateFound = false;
    bool symbolUpdated = false;


    string fileContent = "";
    int handle = FileOpen(ProfitFile, FILE_READ | FILE_ANSI, '\n');
    if (handle != INVALID_HANDLE) {
        while (!FileIsEnding(handle)) {
            line = FileReadString(handle);
            fileContent += line + "\n";
        }
        FileClose(handle);
    }


    string lines[];
    int count = StringSplit(fileContent, '\n', lines);


    for (int i = 0; i < count; i++) {
        string currentLine = lines[i];


        if (StringTrim(currentLine) == today) {
            dateFound = true;
            updatedContent += currentLine + "\n";


            // Process following symbol-profit lines
            i++;
            while (i < count && StringLen(lines[i]) > 0 && StringFind(lines[i], " ") != -1 && StringFind(lines[i], "-") != -1) {
                string entry = lines[i];
                string parts[];
                int n = StringSplit(entry, ' ', parts);
                if (n == 2 && StringTrim(parts[0]) == symbol) {
                    double existingProfit = StrToDouble(parts[1]);
                    entry = symbol + " " + DoubleToString(existingProfit + profit, 2);
                    symbolUpdated = true;
                }
                updatedContent += entry + "\n";
                i++;
            }


            if (!symbolUpdated) {
                updatedContent += symbol + " " + DoubleToString(profit, 2) + "\n";
            }


            // Copy remaining lines
            for (; i < count; i++) {
                updatedContent += lines[i] + "\n";
            }


            break;
        } else {
            updatedContent += currentLine + "\n";
        }
    }


    if (!dateFound) {
        updatedContent += today + "\n";
        updatedContent += symbol + " " + DoubleToString(profit, 2) + "\n";
    }


    handle = FileOpen(ProfitFile, FILE_WRITE | FILE_ANSI);
    if (handle != INVALID_HANDLE) {
        FileWrite(handle, updatedContent);
        FileClose(handle);
    }
}


// === Close Trades at 12 PM Local Time Only ===
void CloseAllTradesAtFixedTimes() {
    datetime now = TimeLocal();
    int hour = TimeHour(now);
    int minute = TimeMinute(now);
    datetime today = StringToTime(TimeToString(now, TIME_DATE));
    datetime timeKey = today + hour * 3600;


    if ((hour == 12 && minute < 15) && lastCloseDay != timeKey) {
        Log("12 PM local time reached. Closing all open trades.");
        bool anyClosed = false;


        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                string sym = OrderSymbol();
                int type = OrderType();
                if (type == OP_BUY || type == OP_SELL) {
                    double closePrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
                    double lots = OrderLots();
                    int ticket = OrderTicket();
                    bool result = OrderClose(ticket, lots, closePrice, Slippage, clrRed);
                    if (result) {
                        anyClosed = true;
                        if (OrderSelect(ticket, SELECT_BY_TICKET)) {
                            double profit = OrderProfit() + OrderSwap() + OrderCommission();
                            Log("Closed order: " + IntegerToString(ticket) + " | Profit: " + DoubleToString(profit, 2));
                            UpdateDailyProfit(sym, profit);
                        } else {
                            Log("Closed order: " + IntegerToString(ticket) + " (could not reselect)");
                        }
                    } else {
                        Log("Failed to close order: " + IntegerToString(ticket) + " Error: " + IntegerToString(GetLastError()));
                    }
                }
            }
        }


        if (!anyClosed) {
            Log("No open trades to close at 12 PM.");
        }


        lastCloseDay = timeKey;
    }
}


// === Order Execution via Text File ===
void ExecuteTradeCommand() {
    if (!IsTradeAllowed() || !IsConnected()) {
        Log("Trade not allowed or not connected.");
        return;
    }


    if (!FileIsExist(FilePath)) return;


    int fileHandle = FileOpen(FilePath, FILE_READ | FILE_ANSI);
    if (fileHandle == INVALID_HANDLE) {
        Log("Failed to open trade file.");
        return;
    }


    string command = FileReadString(fileHandle);
    FileClose(fileHandle);
    FileDelete(FilePath);
    Log("Command read: " + command);


    string parts[];
    int n = StringSplit(command, ' ', parts);
    if (n < 2) {
        Log("Invalid command format.");
        return;
    }


    string direction = parts[0];
    string sym = parts[1];


    if (!SymbolSelect(sym, true)) {
        Log("Symbol not tradable: " + sym);
        return;
    }


    if (SymbolInfoInteger(sym, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED) {
        Log("Trading not allowed for: " + sym);
        return;
    }


    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() == sym && (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
                double closePrice = (OrderType() == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
                double lots = OrderLots();
                int ticket = OrderTicket();
                bool result = OrderClose(ticket, lots, closePrice, Slippage, clrRed);
                if (result) {
                    if (OrderSelect(ticket, SELECT_BY_TICKET)) {
                        double profit = OrderProfit() + OrderSwap() + OrderCommission();
                        Log("Closed existing: " + IntegerToString(ticket) + " | Profit: " + DoubleToString(profit, 2));
                        UpdateDailyProfit(sym, profit);
                    } else {
                        Log("Closed existing: " + IntegerToString(ticket) + " (could not reselect)");
                    }
                } else {
                    Log("Failed to close existing order: " + IntegerToString(ticket) + " Error: " + IntegerToString(GetLastError()));
                }
            }
        }
    }


    double equity = AccountEquity();
    double marginPerLot = MarketInfo(sym, MODE_MARGINREQUIRED);
    if (marginPerLot <= 0) {
        Log("Invalid margin requirement.");
        return;
    }


    double lotSize = (equity * RiskPercent / 100.0) / marginPerLot;
    double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);


    lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;


    if (lotSize < minLot) {
        Log("Lot size below minimum: " + DoubleToString(lotSize, 2));
        return;
    }


    double price = (direction == "BUY") ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
    if (price <= 0) {
        Log("Invalid market price.");
        return;
    }


    double freeMargin = AccountFreeMarginCheck(sym, (direction == "BUY") ? OP_BUY : OP_SELL, lotSize);
    if (freeMargin < 0) {
        Log("Insufficient margin.");
        return;
    }


    int orderType = (direction == "BUY") ? OP_BUY : OP_SELL;
    int ticket = OrderSend(sym, orderType, lotSize, price, Slippage, 0, 0, "Signal trade " + direction, 0, 0, clrBlue);


    if (ticket < 0) {
        Log("OrderSend failed. Error: " + IntegerToString(GetLastError()));
    } else {
        Log("Order placed: " + direction + " " + sym + " " + DoubleToString(lotSize, 2) + " | " + IntegerToString(ticket));
    }
}


// === Init and Deinit ===
int OnInit() {
    EventSetTimer(60); // Check every 60 seconds
    Log("EA Initialized.");
    return INIT_SUCCEEDED;
}


void OnDeinit(const int reason) {
    EventKillTimer();
    Log("EA Deinitialized.");
}


// === Timer and Tick ===
void OnTimer() {
    CloseAllTradesAtFixedTimes();
}


void OnTick() {
    ExecuteTradeCommand();
}