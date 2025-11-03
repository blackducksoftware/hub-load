#!/bin/bash
#
# Test Script: Enhanced Scan Summary
#
# This script demonstrates the new comprehensive scan summary features:
# - Size-specific distribution (SMALL, MEDIUM, LARGE, XLARGE)
# - Detailed results table with all scan metadata
# - Files used, timestamps, BOM URLs, etc.
#
# Usage:
#   ./test_enhanced_summary.sh
#

# Set your Black Duck credentials
HUB_URL="https://rg-250sph-2025-7-1.saas-staging.blackduck.com"
TOKEN="your-api-token-here"

echo "========================================"
echo "Enhanced Scan Summary Test"
echo "========================================"
echo ""
echo "This test will run 4 scans to demonstrate:"
echo "  1. Size-specific distribution reporting"
echo "  2. Comprehensive results table"
echo "  3. Detailed scan metadata tracking"
echo ""
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

# Reset environment
source src/hub_load/config/reset_env.sh 2>/dev/null || echo "Reset script not found, continuing..."

# Load debug configuration for signature scans (includes all sizes)
source src/hub_load/config/debug_signature_scan.sh

echo ""
echo "========================================"
echo "Running 4 scans with size distribution:"
echo "  - SMALL, MEDIUM, LARGE, XLARGE"
echo "========================================"
echo ""

# Run the scans
BD_HUB_URL="$HUB_URL" \
API_TOKEN="$TOKEN" \
MAX_SCANS=4 \
./src/hub_load/core/hub_load_main.sh

echo ""
echo "========================================"
echo "Test Complete!"
echo "========================================"
echo ""
echo "Check the output above for:"
echo "  1. Scan Type Distribution with size breakdown"
echo "  2. Detailed Scan Results table showing:"
echo "     - Scan type and size"
echo "     - Status and timestamps"
echo "     - Project, version, codelocation"
echo "     - Files used for scanning"
echo "     - BOM URLs"
echo "     - Log file locations"
echo ""
