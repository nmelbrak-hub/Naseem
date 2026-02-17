#!/bin/bash

# Hill Cipher + Playfair Cipher Testing Script
# Author: Jie Lin, Ph.D.
# Affilation: University of Central Florida
#
# This script compiles and tests student implementations of the Hill Cipher + Playfair Cipher
# Supports C (.c), C++ (.cpp), and Rust (.rs) source files
# Tests all permutations against expected results in the expected_results folder

# Configuration (update here for reuse in other projects)
SOURCE_BASENAME="hillplayfair"
DEFAULT_C_SOURCE="$SOURCE_BASENAME.c"
DEFAULT_CPP_SOURCE="$SOURCE_BASENAME.cpp"
DEFAULT_RS_SOURCE="$SOURCE_BASENAME.rs"
OUTPUT_BIN="$SOURCE_BASENAME"
EXPECTED_DIR="expected_results"
TEST_CASES_DIR="test_cases"
STUDENT_OUTPUT_DIR="student_output"
FAILED_OUTPUT_DIR="failed_cases"
KEY_DIR="$TEST_CASES_DIR/hill_cipher_keys"
PLAINTEXT_DIR="$TEST_CASES_DIR/plaintexts"
KEYWORD_DIR="$TEST_CASES_DIR/playfair_keywords"
COMPILE_TIMEOUT_SEC=20
RUN_TIMEOUT_SEC=5

# Check if source file argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <source_file>"
    echo "Supported files: */$DEFAULT_C_SOURCE, */$DEFAULT_CPP_SOURCE, */$DEFAULT_RS_SOURCE"
    echo ""
    echo "This script will:"
    echo "  1. Compile your source code"
    echo "  2. Run all test cases from the test_cases directory"
    echo "  3. Compare your output with expected results"
    echo "  4. Provide detailed feedback on any differences"
    exit 1
fi

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

now_seconds() {
    if [ -x /usr/bin/perl ]; then
        /usr/bin/perl -MTime::HiRes -e 'print Time::HiRes::time()'
        return 0
    fi
    date +%s
}

format_seconds() {
    local value=$1
    if command -v awk >/dev/null 2>&1; then
        awk -v v="$value" 'BEGIN { printf "%.3f", v }'
    else
        echo "$value"
    fi
}

run_with_timeout() {
    local timeout=$1
    shift

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout" "$@"
        return $?
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" "$@"
        return $?
    fi

    if [ -x /usr/bin/perl ]; then
        /usr/bin/perl -e 'alarm shift; exec @ARGV' "$timeout" "$@"
        return $?
    fi

    print_status $YELLOW "WARN: Timeout tool not found; running without a timeout."
    "$@"
}

is_timeout_status() {
    case $1 in
        124|137|142|143) return 0 ;;
        *) return 1 ;;
    esac
}

# Determine source file type and compile accordingly
case $1 in
    *"$DEFAULT_C_SOURCE")
        print_status $BLUE "INFO: Compiling C source file: $1"
        rm -f -- "$OUTPUT_BIN"
        run_with_timeout "$COMPILE_TIMEOUT_SEC" gcc -Wall -Wextra -std=c99 -O2 "$1" -o "$OUTPUT_BIN" -lm
        compile_status=$?
        if is_timeout_status $compile_status; then
            print_status $RED "FAIL: Compilation timed out after ${COMPILE_TIMEOUT_SEC}s"
            exit 1
        fi
        if [ $compile_status -ne 0 ]; then
            print_status $RED "FAIL: Compilation of $DEFAULT_C_SOURCE failed"
            echo "Please fix compilation errors and try again."
            exit 1
        fi
        EXE="./$OUTPUT_BIN"
        LANG="C"
        ;;
    *"$DEFAULT_CPP_SOURCE")
        print_status $BLUE "INFO: Compiling C++ source file: $1"
        rm -f -- "$OUTPUT_BIN"
        run_with_timeout "$COMPILE_TIMEOUT_SEC" g++ -Wall -Wextra -std=c++17 -O2 "$1" -o "$OUTPUT_BIN"
        compile_status=$?
        if is_timeout_status $compile_status; then
            print_status $RED "FAIL: Compilation timed out after ${COMPILE_TIMEOUT_SEC}s"
            exit 1
        fi
        if [ $compile_status -ne 0 ]; then
            print_status $RED "FAIL: Compilation of $DEFAULT_CPP_SOURCE failed"
            echo "Please fix compilation errors and try again."
            exit 1
        fi
        EXE="./$OUTPUT_BIN"
        LANG="C++"
        ;;
    *"$DEFAULT_RS_SOURCE")
        print_status $BLUE "INFO: Compiling Rust source file: $1"
        rm -f -- "$OUTPUT_BIN"
        run_with_timeout "$COMPILE_TIMEOUT_SEC" rustc -O "$1" -o "$OUTPUT_BIN"
        compile_status=$?
        if is_timeout_status $compile_status; then
            print_status $RED "FAIL: Compilation timed out after ${COMPILE_TIMEOUT_SEC}s"
            exit 1
        fi
        if [ $compile_status -ne 0 ]; then
            print_status $RED "FAIL: Compilation of $DEFAULT_RS_SOURCE failed"
            echo "Please fix compilation errors and try again."
            exit 1
        fi
        EXE="./$OUTPUT_BIN"
        LANG="Rust"
        ;;
    *)
        print_status $RED "FAIL: Invalid source file name: $1"
        echo "Supported files: */$DEFAULT_C_SOURCE, */$DEFAULT_CPP_SOURCE, */$DEFAULT_RS_SOURCE"
        echo "Only C, C++, and Rust are supported"
        exit 1
        ;;
 esac

print_status $GREEN "PASS: Compilation of $1 succeeded using $LANG"
echo ""

# Create output directories (fresh each run)
rm -rf "$STUDENT_OUTPUT_DIR" "$FAILED_OUTPUT_DIR"
mkdir -p "$STUDENT_OUTPUT_DIR" "$FAILED_OUTPUT_DIR"

# Initialize test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_status $CYAN "INFO: Starting comprehensive test evaluation..."
echo "============================================================"

# Check if expected_results directory exists
if [ ! -d "$EXPECTED_DIR" ]; then
    print_status $RED "FAIL: Expected results directory not found!"
    echo "Please ensure the '$EXPECTED_DIR' directory exists with all test case results."
    exit 1
fi

record_failure() {
    local test_name=$1
    local reason=$2
    local key_file=$3
    local text_file=$4
    local keyword_file=$5
    local expected_file=$6
    local student_output=$7

    local case_dir="$FAILED_OUTPUT_DIR/$test_name"
    mkdir -p "$case_dir"
    {
        echo "Test Case: $test_name"
        echo "Reason: $reason"
        echo "Key: $key_file"
        echo "Plaintext: $text_file"
        echo "Keyword: $keyword_file"
        echo "Expected: $expected_file"
        echo "Student Output: $student_output"
    } > "$case_dir/info.txt"
}

# Function to run a single test case
run_test_case() {
    local key_file=$1
    local text_file=$2
    local keyword_file=$3
    local expected_file=$4
    local test_name=$5

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    print_status $PURPLE "INFO: Test Case: $test_name"
    echo "   Mode: encrypt, Key: $key_file, Text: $text_file, Keyword: $keyword_file"

    # Check if input files exist
    if [ ! -f "$key_file" ]; then
        print_status $RED "   FAIL: Key file $key_file not found"
        record_failure "$test_name" "Missing key file" "$key_file" "$text_file" "$keyword_file" "$expected_file" ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    if [ ! -f "$text_file" ]; then
        print_status $RED "   FAIL: Text file $text_file not found"
        record_failure "$test_name" "Missing plaintext file" "$key_file" "$text_file" "$keyword_file" "$expected_file" ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    if [ ! -f "$keyword_file" ]; then
        print_status $RED "   FAIL: Keyword file $keyword_file not found"
        record_failure "$test_name" "Missing keyword file" "$key_file" "$text_file" "$keyword_file" "$expected_file" ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    if [ ! -f "$expected_file" ]; then
        print_status $RED "   FAIL: Expected result file $expected_file not found"
        record_failure "$test_name" "Missing expected result file" "$key_file" "$text_file" "$keyword_file" "$expected_file" ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Run student program and capture output
    local student_output="$STUDENT_OUTPUT_DIR/${test_name}_output.txt"
    run_with_timeout "$RUN_TIMEOUT_SEC" "$EXE" encrypt "$key_file" "$text_file" "$keyword_file" > "$student_output" 2>&1
    run_status=$?

    if is_timeout_status $run_status; then
        print_status $RED "   FAIL: Program timed out after ${RUN_TIMEOUT_SEC}s"
        echo "   Partial output saved to: $student_output"
        record_failure "$test_name" "Program timed out" "$key_file" "$text_file" "$keyword_file" "$expected_file" "$student_output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    if [ $run_status -ne 0 ]; then
        print_status $RED "   FAIL: Program execution failed"
        echo "   Error output saved to: $student_output"
        record_failure "$test_name" "Program execution failed" "$key_file" "$text_file" "$keyword_file" "$expected_file" "$student_output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Compare with expected output, ignoring blank lines and whitespace differences
    if diff -B -w "$student_output" "$expected_file" > /dev/null 2>&1; then
        print_status $GREEN "   PASS: Output matches expected result"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        print_status $RED "   FAIL: Output differs from expected result"
        echo "   Student output: $student_output"
        echo "   Expected output: $expected_file"
        echo "   First few differences (blank lines and whitespace ignored):"
        diff -B -w "$student_output" "$expected_file" | head -10
        record_failure "$test_name" "Output mismatch" "$key_file" "$text_file" "$keyword_file" "$expected_file" "$student_output"
        diff -B -w "$student_output" "$expected_file" > "$FAILED_OUTPUT_DIR/$test_name/diff.txt" || true
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Run all test cases by scanning expected_results directory
echo "INFO: Scanning expected_results directory for test cases..."

# Find all expected result files and extract test parameters
START_TIME=$(now_seconds)
for expected_file in "$EXPECTED_DIR"/*.txt; do
    if [ -f "$expected_file" ]; then
        # Extract filename without path and extension
        filename=$(basename "$expected_file" .txt)

        # Expected format: key<N>_plaintext<M>_keyword<K>
        if [[ $filename =~ key([0-9]+)_plaintext([0-9]+)_keyword([0-9]+) ]]; then
            key_num="${BASH_REMATCH[1]}"
            plaintext_num="${BASH_REMATCH[2]}"
            keyword_num="${BASH_REMATCH[3]}"

            key_file="$KEY_DIR/hill_key_${key_num}.txt"
            plaintext_file="$PLAINTEXT_DIR/plaintext_${plaintext_num}.txt"
            keyword_file="$KEYWORD_DIR/playfair_keyword_${keyword_num}.txt"

            run_test_case "$key_file" "$plaintext_file" "$keyword_file" "$expected_file" "$filename"
        else
            print_status $YELLOW "   WARN: Skipping file with unrecognized format: $filename"
        fi
    fi
done
END_TIME=$(now_seconds)

TOTAL_TIME_RAW=$(awk -v end="$END_TIME" -v start="$START_TIME" 'BEGIN { printf "%.6f", (end - start) }')
if [ "$TOTAL_TESTS" -gt 0 ]; then
    AVG_TIME_RAW=$(awk -v total="$TOTAL_TIME_RAW" -v count="$TOTAL_TESTS" 'BEGIN { printf "%.6f", (total / count) }')
else
    AVG_TIME_RAW="0"
fi

echo "============================================================"
if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_RATE_RAW=$(awk -v passed="$PASSED_TESTS" -v total="$TOTAL_TESTS" 'BEGIN { printf "%.2f", (passed / total) * 100 }')
else
    PASS_RATE_RAW="0.00"
fi

SUMMARY_COLOR=$GREEN
if [ $FAILED_TESTS -ne 0 ]; then
    SUMMARY_COLOR=$RED
fi

print_status $SUMMARY_COLOR "Test Summary"
echo "   Total Tests:       $TOTAL_TESTS"
echo "   Passed:            $PASSED_TESTS"
echo "   Failed:            $FAILED_TESTS"
echo "   Pass Rate:         ${PASS_RATE_RAW}%"
echo "   Grade:             ${PASS_RATE_RAW}%"
echo "   Total Time:        $(format_seconds "$TOTAL_TIME_RAW") s"
echo "   Avg Time per Test: $(format_seconds "$AVG_TIME_RAW") s"

if [ $FAILED_TESTS -ne 0 ]; then
    rm -f -- "$OUTPUT_BIN"
    exit 1
fi

rm -f -- "$OUTPUT_BIN"
