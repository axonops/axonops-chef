#!/bin/bash
# Verification script for AxonOps full-stack deployment
set -e

echo "=== AxonOps Full Stack Test Verification ==="
echo ""

# Track overall status
FAILED=0

# Function to check component
check_component() {
  local name=$1
  local check_cmd=$2
  echo -n "Checking $name... "
  if eval "$check_cmd"; then
    echo "✓"
  else
    echo "✗ FAILED"
    FAILED=$((FAILED + 1))
  fi
}

echo "==== Core Components ===="

# Check users
check_component "axonops user" "id axonops >/dev/null 2>&1"
check_component "cassandra user" "id cassandra >/dev/null 2>&1"

echo ""
echo "==== AxonOps Server ===="
check_component "server binary" "[ -x /usr/bin/axon-server ]"
check_component "server config" "[ -f /etc/axonops/axon-server.yml ]"
check_component "server service" "[ -f /etc/systemd/system/axon-server.service ]"

echo ""
echo "==== AxonOps Dashboard ===="
check_component "dashboard installation" "[ -x /usr/bin/axon-dash ] || [ -d /opt/axonops/dashboard/dist ]"
check_component "dashboard config" "[ -f /etc/axonops/axon-dash.yml ]"
check_component "dashboard service" "[ -f /etc/systemd/system/axon-dash.service ]"

echo ""
echo "==== AxonOps Agent ===="
check_component "agent binary" "[ -x /usr/bin/axon-agent ]"
check_component "agent config" "[ -f /etc/axonops/axon-agent.yml ]"
check_component "agent service" "[ -f /etc/systemd/system/axon-agent.service ]"

echo ""
echo "==== Elasticsearch (AxonOps Storage) ===="
check_component "elasticsearch directory" "[ -d /opt/elasticsearch ]"
check_component "elasticsearch service" "[ -f /etc/systemd/system/axonops-elasticsearch.service ]"
check_component "elasticsearch config" "[ -f /opt/elasticsearch/config/elasticsearch.yml ]"

echo ""
echo "==== Cassandra (AxonOps Storage) ===="
check_component "cassandra directory" "[ -d /opt/cassandra ]"
check_component "cassandra service" "[ -f /etc/systemd/system/axonops-cassandra.service ]"
check_component "cassandra config" "[ -f /opt/cassandra/conf/cassandra.yaml ]"

echo ""
echo "==== User Application Cassandra ===="
check_component "app cassandra binary" "[ -x /usr/bin/cassandra ] || [ -x /opt/cassandra/bin/cassandra ]"
check_component "app cassandra config" "[ -f /etc/cassandra/cassandra.yaml ]"
check_component "app cassandra service" "[ -f /etc/systemd/system/cassandra.service ] || [ -f /usr/lib/systemd/system/cassandra.service ]"

echo ""
echo "==== Directory Structure ===="
for dir in /etc/axonops /var/log/axonops /var/lib/axonops /opt/axonops /data/cassandra; do
  check_component "directory $dir" "[ -d $dir ]"
done

echo ""
echo "==== Service Ports (if running) ===="
echo "Note: These may not be listening if services aren't started"
echo -n "  AxonOps Server (8080)... "
nc -z localhost 8080 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo -n "  AxonOps Dashboard (3000)... "
nc -z localhost 3000 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo -n "  AxonOps Agent (9916)... "
nc -z localhost 9916 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo -n "  Elasticsearch (9200)... "
nc -z localhost 9200 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo -n "  Cassandra CQL (9042)... "
nc -z localhost 9042 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo -n "  Cassandra Storage (7000)... "
nc -z localhost 7000 2>/dev/null && echo "✓ listening" || echo "- not listening"

echo ""
echo "==== System Configuration ===="
echo -n "  vm.max_map_count... "
max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "unknown")
if [ "$max_map_count" -ge 1048575 ] 2>/dev/null; then
  echo "✓ ($max_map_count)"
else
  echo "✗ current: $max_map_count (required: >= 1048575)"
  FAILED=$((FAILED + 1))
fi

echo -n "  File descriptor limits... "
if [ -f /etc/security/limits.d/cassandra.conf ]; then
  echo "✓ configured"
else
  echo "- not configured (may use defaults)"
fi

echo ""
echo "==== Integration Points ===="
echo -n "Checking agent → server connectivity config... "
if grep -q "agents\.axonops\.cloud\|localhost:8080" /etc/axonops/axon-agent.yml 2>/dev/null; then
  echo "✓"
else
  echo "✗ not configured"
  FAILED=$((FAILED + 1))
fi

echo -n "Checking Java installation... "
if command -v java >/dev/null 2>&1; then
  java_version=$(java -version 2>&1 | head -1)
  echo "✓ ($java_version)"
else
  echo "✗ Java not found"
  FAILED=$((FAILED + 1))
fi

echo ""
echo "========================================="
if [ $FAILED -eq 0 ]; then
  echo "✅ All components verified successfully!"
else
  echo "❌ $FAILED component(s) failed verification"
  exit 1
fi