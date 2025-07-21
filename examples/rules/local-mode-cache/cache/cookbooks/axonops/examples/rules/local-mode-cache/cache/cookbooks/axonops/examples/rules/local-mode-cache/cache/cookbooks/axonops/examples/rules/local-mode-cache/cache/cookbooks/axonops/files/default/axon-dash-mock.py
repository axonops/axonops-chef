#!/usr/bin/env python3
"""
Mock AxonOps Dashboard implementation for testing
Provides a simple web interface that connects to the AxonOps server
"""

import os
import sys
import logging
from flask import Flask, jsonify, render_template_string

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('axon-dash')

app = Flask(__name__)

# Simple HTML template
DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>AxonOps Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .status { margin: 20px 0; padding: 10px; background: #ecf0f1; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: white; border: 1px solid #ddd; border-radius: 5px; }
        .healthy { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AxonOps Dashboard</h1>
        <p>Mock implementation for testing</p>
    </div>
    
    <div class="status">
        <h2>Server Status</h2>
        <p>API Endpoint: {{ api_endpoint }}</p>
        <p>Status: <span class="healthy">Connected</span></p>
    </div>
    
    <div class="status">
        <h2>Cluster Overview</h2>
        <div class="metric">
            <h3>Nodes</h3>
            <p>Total: <span id="node-count">-</span></p>
        </div>
        <div class="metric">
            <h3>Clusters</h3>
            <p>Total: <span id="cluster-count">-</span></p>
        </div>
        <div class="metric">
            <h3>Agents</h3>
            <p>Connected: <span id="agent-count">-</span></p>
        </div>
    </div>
    
    <script>
        // Mock data updates
        function updateStats() {
            document.getElementById('node-count').textContent = Math.floor(Math.random() * 10) + 1;
            document.getElementById('cluster-count').textContent = Math.floor(Math.random() * 3) + 1;
            document.getElementById('agent-count').textContent = Math.floor(Math.random() * 10) + 1;
        }
        
        setInterval(updateStats, 5000);
        updateStats();
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Main dashboard page"""
    api_endpoint = os.environ.get('AXON_DASH_API_ENDPOINT', 'http://localhost:8080')
    return render_template_string(DASHBOARD_HTML, api_endpoint=api_endpoint)

@app.route('/api/status')
def status():
    """Dashboard status endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': '3.0.0-mock',
        'api_endpoint': os.environ.get('AXON_DASH_API_ENDPOINT', 'http://localhost:8080')
    })

def main():
    """Main entry point"""
    # Read config from environment or defaults
    host = os.environ.get('AXON_DASH_HOST', '0.0.0.0')
    port = int(os.environ.get('AXON_DASH_PORT', '3000'))
    
    logger.info(f"Starting AxonOps Dashboard (mock) on {host}:{port}")
    logger.info("This is a mock implementation for testing purposes")
    
    # Start Flask app
    app.run(host=host, port=port, debug=False)

if __name__ == '__main__':
    main()