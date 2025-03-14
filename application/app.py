from flask import Flask, jsonify

app = Flask(__name__)

# Simple root endpoint
@app.route('/get', methods=['GET'])
def get_root():
    return jsonify({"message": "Hello from the Python Flask app!"})

# Endpoint with a parameter
@app.route('/get/<name>', methods=['GET'])
def get_name(name):
    return jsonify({"greeting": f"Hello, {name}!"})

# Health check endpoint
@app.route('/get/health', methods=['GET'])
def get_health():
    return jsonify({"status": "healthy", "port": 5000})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)