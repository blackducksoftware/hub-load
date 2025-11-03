HUB_URL="https:/"
  TOKEN="jjj=="

  # Test Container
  echo "========================================"
  echo "Testing CONTAINER scans..."
  echo "========================================"
  source src/hub_load/config/reset_env.sh
  source src/hub_load/config/debug_container_scan.sh && \
    MAX_SCANS=1 BD_HUB_URL=$HUB_URL API_TOKEN=$TOKEN \
    ./src/hub_load/core/hub_load_main.sh

  # Test Binary
  echo "========================================"
  echo "Testing BINARY scans..."
  echo "========================================"
  source src/hub_load/config/reset_env.sh
  source src/hub_load/config/debug_binary_scan.sh && \
    MAX_SCANS=1 BD_HUB_URL=$HUB_URL API_TOKEN=$TOKEN \
    ./src/hub_load/core/hub_load_main.sh

  # Test Signature
  echo "========================================"
  echo "Testing SIGNATURE scans..."
  echo "========================================"
  source src/hub_load/config/reset_env.sh
  source src/hub_load/config/debug_signature_scan.sh && \
    MAX_SCANS=1 BD_HUB_URL=$HUB_URL API_TOKEN=$TOKEN \
    ./src/hub_load/core/hub_load_main.sh

  # Test Snippet
  echo "========================================"
  echo "Testing SNIPPET scans..."
  echo "========================================"
  source src/hub_load/config/reset_env.sh
  source src/hub_load/config/debug_snippet_scan.sh && \
    MAX_SCANS=1 BD_HUB_URL=$HUB_URL API_TOKEN=$TOKEN \
    ./src/hub_load/core/hub_load_main.sh

  echo "========================================"
  echo "All scan types tested!"
  echo "========================================"