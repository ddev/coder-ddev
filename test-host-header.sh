#!/bin/bash
# Test script to verify if Coder forwards Host headers to DDEV router
# Run this inside a workspace with a running DDEV project

echo "=== Testing Coder Host Header Forwarding ==="
echo ""
echo "This script checks if the DDEV router receives the correct Host header from Coder."
echo ""

# Check if DDEV is running
if ! ddev describe >/dev/null 2>&1; then
    echo "ERROR: No DDEV project is running in the current directory."
    echo "Please run 'ddev start' first."
    exit 1
fi

# Get project info
PROJECT_NAME=$(ddev describe | grep "Name:" | awk '{print $2}')
ROUTER_URL=$(ddev describe | grep "http://" | head -1 | awk '{print $2}')

echo "DDEV Project: $PROJECT_NAME"
echo "Expected Router URL: $ROUTER_URL"
echo ""

# Test 1: Check if router is running
echo "Test 1: Checking if DDEV router is accessible on port 80..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 >/dev/null 2>&1; then
    echo "✓ Router is responding on port 80"
else
    echo "✗ Router is not responding on port 80"
    echo "  Make sure router is enabled (remove host_webserver_port from global_config.yaml)"
    exit 1
fi
echo ""

# Test 2: Check what hostname the router expects
echo "Test 2: Testing router with expected hostname..."
RESPONSE=$(curl -s -H "Host: ${PROJECT_NAME}.ddev.site" http://localhost:80 | head -c 100)
if [ -n "$RESPONSE" ]; then
    echo "✓ Router responds to Host: ${PROJECT_NAME}.ddev.site"
else
    echo "✗ Router does not respond to expected hostname"
fi
echo ""

# Test 3: Show router configuration
echo "Test 3: Current router configuration..."
if [ -f .ddev/config.yaml ]; then
    echo "additional_fqdns:"
    grep -A5 "additional_fqdns" .ddev/config.yaml || echo "  (none configured)"
else
    echo "  No .ddev/config.yaml found"
fi
echo ""

echo "=== Next Steps ==="
echo "1. Access your DDEV site through Coder's port forwarding"
echo "2. Open browser dev tools and check the 'Host' header in the request"
echo "3. If Host header shows the Coder subdomain (e.g., ddev-web--workspace--user.domain),"
echo "   then we can configure DDEV to accept it."
echo ""
echo "To add the Coder hostname to DDEV:"
echo "  ddev config --additional-fqdns=ddev-web--workspace--user--id.coder.domain"
echo "  ddev restart"
