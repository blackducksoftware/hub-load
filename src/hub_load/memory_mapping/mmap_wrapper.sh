#!/bin/bash
#
# Memory Mapping Wrapper Script
# Provides easy interface to Python memory mapping functionality
#

SCRIPT_DIR=$(dirname "$0")
PYTHON_HANDLER="$SCRIPT_DIR/mmap_file_handler.py"

# Check if Python handler exists
if [ ! -f "$PYTHON_HANDLER" ]; then
    echo "ERROR: Python memory mapping handler not found: $PYTHON_HANDLER"
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required for memory mapping functionality"
    exit 1
fi

function show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --prepare-files <files...> --dest-dir <dir>  Prepare files for scanning"
    echo "  --info <files...>                           Show file information only"
    echo "  --max-files <number>                        Limit number of files to process"
    echo "  --verbose                                   Enable verbose output"
    echo "  --help                                      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --prepare-files /path/to/file1.tar /path/to/file2.tar --dest-dir /tmp/scan"
    echo "  $0 --info /path/to/large-file.tar"
    echo ""
}

# Parse command line arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Execute Python handler with all arguments
exec python3 "$PYTHON_HANDLER" "${ARGS[@]}"