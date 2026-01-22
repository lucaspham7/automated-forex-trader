# webhook_server.py




from flask import Flask, request, jsonify
from mt4_bridge import send_trade  # ✅ Import the function directly




app = Flask(__name__)




@app.route('/webhook', methods=['POST'])
def webhook():




    print()
    data = request.json
    print("Received alert:", data)




    if not data or 'signal' not in data:
        return jsonify({'status': 'error', 'message': 'Invalid payload'}), 400




    signal = data['signal']
    symbol = data.get('ticker', 'EURUSD')  # default




    if signal == 'buy':
        send_trade("buy", symbol)  # ✅ Call directly
    elif signal == 'sell':
        send_trade("sell", symbol)  # ✅ Call directly
    else:
        return jsonify({'status': 'ignored', 'message': 'No action'}), 200
        print("ignoring request")




    return jsonify({'status': 'success'}), 200




if __name__ == '__main__':
    app.run(port=5000)