#!/usr/bin/env python3
"""
Mock AxonOps Server implementation for testing
Provides realistic API endpoints and behavior
"""

import os
import sys
import json
import logging
import time
from datetime import datetime
from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('axon-server')

app = Flask(__name__)

# In-memory storage for testing
agents = {}
metrics = []
clusters = {}

@app.route('/api/v1/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '3.0.0-mock',
        'components': {
            'elasticsearch': 'connected',
            'cassandra': 'connected',
            'api': 'ready'
        }
    })

@app.route('/api/v1/agents', methods=['GET'])
def list_agents():
    """List all connected agents"""
    return jsonify({
        'agents': list(agents.values()),
        'total': len(agents),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/v1/agents/register', methods=['POST'])
def register_agent():
    """Register a new agent"""
    data = request.get_json()
    agent_id = data.get('agent_id', f"agent-{len(agents) + 1}")
    
    agents[agent_id] = {
        'id': agent_id,
        'name': data.get('name', 'unknown'),
        'host': data.get('host', request.remote_addr),
        'cluster': data.get('cluster', 'default'),
        'datacenter': data.get('datacenter', 'dc1'),
        'rack': data.get('rack', 'rack1'),
        'cassandra_version': data.get('cassandra_version', '5.0.4'),
        'status': 'connected',
        'registered_at': datetime.utcnow().isoformat(),
        'last_heartbeat': datetime.utcnow().isoformat()
    }
    
    logger.info(f"Agent registered: {agent_id} from {agents[agent_id]['host']}")
    
    return jsonify({
        'agent_id': agent_id,
        'status': 'registered',
        'message': 'Agent successfully registered'
    }), 201

@app.route('/api/v1/agents/<agent_id>/heartbeat', methods=['POST'])
def agent_heartbeat(agent_id):
    """Receive heartbeat from agent"""
    if agent_id in agents:
        agents[agent_id]['last_heartbeat'] = datetime.utcnow().isoformat()
        agents[agent_id]['status'] = 'connected'
        
        # Process metrics if provided
        data = request.get_json() or {}
        if 'metrics' in data:
            metrics.append({
                'agent_id': agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'metrics': data['metrics']
            })
        
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'error': 'Agent not found'}), 404

@app.route('/api/v1/metrics/nodes', methods=['GET'])
def node_metrics():
    """Get node metrics"""
    # Return mock metrics data
    return jsonify({
        'nodes': [
            {
                'id': agent['id'],
                'name': agent['name'],
                'metrics': {
                    'cpu_usage': 45.2,
                    'memory_usage': 62.8,
                    'disk_usage': 35.4,
                    'read_latency_ms': 2.3,
                    'write_latency_ms': 1.8,
                    'compactions_pending': 2
                }
            } for agent in agents.values()
        ],
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/v1/clusters', methods=['GET'])
def list_clusters():
    """List all clusters"""
    cluster_list = {}
    for agent in agents.values():
        cluster_name = agent['cluster']
        if cluster_name not in cluster_list:
            cluster_list[cluster_name] = {
                'name': cluster_name,
                'nodes': 0,
                'datacenters': set(),
                'status': 'healthy'
            }
        cluster_list[cluster_name]['nodes'] += 1
        cluster_list[cluster_name]['datacenters'].add(agent['datacenter'])
    
    # Convert sets to lists for JSON serialization
    for cluster in cluster_list.values():
        cluster['datacenters'] = list(cluster['datacenters'])
    
    return jsonify({
        'clusters': list(cluster_list.values()),
        'total': len(cluster_list),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/v1/config', methods=['GET'])
def get_config():
    """Get server configuration"""
    return jsonify({
        'server': {
            'version': '3.0.0-mock',
            'listen_address': '0.0.0.0',
            'listen_port': 8080
        },
        'storage': {
            'elasticsearch': {
                'url': 'http://localhost:9200',
                'index_prefix': 'axonops'
            },
            'cassandra': {
                'hosts': ['localhost:9142'],
                'keyspace': 'axonops_data'
            }
        },
        'features': {
            'metrics': True,
            'logs': True,
            'backups': True,
            'repairs': True,
            'alerts': True
        }
    })

@app.route('/', methods=['GET'])
def index():
    """Root endpoint"""
    return jsonify({
        'service': 'AxonOps Server',
        'version': '3.0.0-mock',
        'api_version': 'v1',
        'endpoints': [
            '/api/v1/health',
            '/api/v1/agents',
            '/api/v1/metrics/nodes',
            '/api/v1/clusters',
            '/api/v1/config'
        ]
    })

def main():
    """Main entry point"""
    # Read config from environment or defaults
    host = os.environ.get('AXON_SERVER_HOST', '0.0.0.0')
    port = int(os.environ.get('AXON_SERVER_PORT', '8080'))
    
    logger.info(f"Starting AxonOps Server (mock) on {host}:{port}")
    logger.info("This is a mock implementation for testing purposes")
    
    # Start Flask app
    app.run(host=host, port=port, debug=False)

if __name__ == '__main__':
    main()