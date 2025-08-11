#!/usr/bin/env python3
"""
Mock AxonOps Agent implementation for testing
Simulates agent behavior including metrics collection and server communication
"""

import os
import sys
import json
import time
import logging
import random
import socket
import urllib.request
import urllib.error
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('axon-agent')

class MockAxonAgent:
    def __init__(self):
        self.config = self.load_config()
        self.agent_id = f"agent-{socket.gethostname()}-{os.getpid()}"
        self.registered = False

    def load_config(self):
        """Load agent configuration"""
        config_path = '/etc/axonops/axon-agent.yml'

        # Default config
        config = {
            'agent': {
                'name': socket.gethostname(),
                'tags': {
                    'environment': 'test',
                    'datacenter': 'dc1',
                    'rack': 'rack1'
                }
            },
            'server': {
                'hosts': ['localhost:8080'],
                'ssl': False
            },
            'cassandra': {
                'hosts': ['localhost:9042']
            },
            'monitoring': {
                'interval': 60
            }
        }

        # Try to load from file
        if os.path.exists(config_path):
            try:
                import yaml
                with open(config_path, 'r') as f:
                    file_config = yaml.safe_load(f)
                    if file_config:
                        # Merge configs
                        config.update(file_config)
            except:
                # If YAML not available, parse simple format
                logger.info("YAML not available, using basic parser")
                with open(config_path, 'r') as f:
                    content = f.read()
                    # Extract server host
                    if 'hosts:' in content:
                        import re
                        match = re.search(r'hosts:\s*\["([^"]+)"\]', content)
                        if match:
                            config['server']['hosts'] = [match.group(1)]

        return config

    def register(self):
        """Register with AxonOps server"""
        for server_host in self.config['server']['hosts']:
            try:
                url = f"http://{server_host}/api/v1/agents/register"
                data = {
                    'agent_id': self.agent_id,
                    'name': self.config['agent']['name'],
                    'host': socket.gethostname(),
                    'cluster': self.config['agent'].get('tags', {}).get('cluster', 'default'),
                    'datacenter': self.config['agent'].get('tags', {}).get('datacenter', 'dc1'),
                    'rack': self.config['agent'].get('tags', {}).get('rack', 'rack1'),
                    'cassandra_version': '5.0.4'
                }

                req = urllib.request.Request(
                    url,
                    data=json.dumps(data).encode('utf-8'),
                    headers={'Content-Type': 'application/json'}
                )

                with urllib.request.urlopen(req, timeout=10) as response:
                    result = json.loads(response.read())
                    logger.info(f"Successfully registered with server: {result}")
                    self.registered = True
                    return True

            except Exception as e:
                logger.error(f"Failed to register with {server_host}: {e}")

        return False

    def collect_metrics(self):
        """Collect mock metrics"""
        return {
            'cpu': {
                'usage_percent': random.uniform(20, 80),
                'load_1m': random.uniform(0.5, 2.0),
                'load_5m': random.uniform(0.5, 2.0),
                'load_15m': random.uniform(0.5, 2.0)
            },
            'memory': {
                'used_gb': random.uniform(2, 8),
                'total_gb': 16,
                'usage_percent': random.uniform(30, 70)
            },
            'disk': {
                'data_size_gb': random.uniform(10, 50),
                'usage_percent': random.uniform(20, 60)
            },
            'cassandra': {
                'read_latency_ms': random.uniform(1, 5),
                'write_latency_ms': random.uniform(0.5, 3),
                'pending_compactions': random.randint(0, 5),
                'active_connections': random.randint(10, 100)
            }
        }

    def send_heartbeat(self):
        """Send heartbeat with metrics to server"""
        if not self.registered:
            return False

        for server_host in self.config['server']['hosts']:
            try:
                url = f"http://{server_host}/api/v1/agents/{self.agent_id}/heartbeat"
                data = {
                    'timestamp': datetime.utcnow().isoformat(),
                    'metrics': self.collect_metrics()
                }

                req = urllib.request.Request(
                    url,
                    data=json.dumps(data).encode('utf-8'),
                    headers={'Content-Type': 'application/json'}
                )

                with urllib.request.urlopen(req, timeout=10) as response:
                    result = json.loads(response.read())
                    logger.debug(f"Heartbeat sent successfully: {result}")
                    return True

            except Exception as e:
                logger.error(f"Failed to send heartbeat to {server_host}: {e}")

        return False

    def check_cassandra_connection(self):
        """Check if Cassandra is accessible"""
        for host in self.config['cassandra']['hosts']:
            try:
                host_parts = host.split(':')
                hostname = host_parts[0]
                port = int(host_parts[1]) if len(host_parts) > 1 else 9042

                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((hostname, port))
                sock.close()

                if result == 0:
                    logger.info(f"Cassandra is accessible at {host}")
                    return True
                else:
                    logger.warning(f"Cannot connect to Cassandra at {host}")

            except Exception as e:
                logger.error(f"Error checking Cassandra connection: {e}")

        return False

    def run(self):
        """Main agent loop"""
        logger.info(f"Starting AxonOps Agent (mock) - ID: {self.agent_id}")
        logger.info(f"Configuration: {json.dumps(self.config, indent=2)}")

        # Check Cassandra connection
        self.check_cassandra_connection()

        # Register with server
        retry_count = 0
        while not self.registered and retry_count < 5:
            logger.info(f"Attempting to register with server (attempt {retry_count + 1}/5)...")
            if self.register():
                break
            retry_count += 1
            time.sleep(10)

        if not self.registered:
            logger.error("Failed to register with server after 5 attempts")
            return 1

        # Main monitoring loop
        interval = self.config['monitoring']['interval']
        logger.info(f"Starting monitoring loop with {interval}s interval")

        while True:
            try:
                # Send heartbeat with metrics
                self.send_heartbeat()

                # Log status
                logger.info(f"Agent running - Next heartbeat in {interval}s")

                # Sleep until next interval
                time.sleep(interval)

            except KeyboardInterrupt:
                logger.info("Shutting down agent...")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                time.sleep(10)

        return 0

def main():
    """Main entry point"""
    agent = MockAxonAgent()
    sys.exit(agent.run())

if __name__ == '__main__':
    main()
