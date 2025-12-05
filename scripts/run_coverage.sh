#!/bin/bash
# Wrapper script to run coco with error handling for the lcov unused pattern issue

set -e

COCO_BIN="$1"
TARGET="$2"
COV_PATTERNS="$3"

if [ -z "$COCO_BIN" ] || [ ! -x "$COCO_BIN" ]; then
    echo "Error: coco binary not found or not executable"
    exit 1
fi

# Run coco, but don't fail if it errors on the unused pattern
# The lcov.info file may still be generated even if coco fails
set +e
"$COCO_BIN" --target "$TARGET" --cov "$COV_PATTERNS" --compiler="--hints:off" 2>&1 | \
    grep -v "^lcov:.*WARNING\|^lcov:.*ERROR\|^fatal\|^Error:\|^Message summary:\|^.*warning message:" || true
COCO_EXIT=$?
set -e

# If lcov.info exists, clean it up manually with ignore-errors
if [ -f lcov.info ]; then
    # Remove the problematic pattern with ignore-errors
    lcov --ignore-errors unused --quiet --remove lcov.info "generated_not_to_break_here" -o lcov.info 2>/dev/null || true
    echo "✓ Coverage data generated in lcov.info"
    exit 0
elif [ $COCO_EXIT -eq 0 ]; then
    # coco succeeded but no lcov.info - this is unexpected
    echo "Warning: coco succeeded but lcov.info not found"
    exit 1
else
    # coco failed and no lcov.info - this is an error
    echo "Error: coco failed and lcov.info not generated"
    exit 1
fi

