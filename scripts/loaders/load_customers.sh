#!/bin/bash
# ============================================================
# ASR Data Loader — Load Customer CSV into Staging
# ============================================================
# Usage: load_customers.sh <csv_file>
# Env vars required: DB_USER, DB_PASSWORD, DB_CONNECTION
# Flow: CSV File → STG_CUSTOMER → PKG_CUSTOMER_LOAD → TGT_CUSTOMER
# ============================================================

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CSV_FILE="${1:?Usage: $SCRIPT_NAME <csv_file>}"

: "${DB_USER:?DB_USER environment variable not set}"
: "${DB_PASSWORD:?DB_PASSWORD environment variable not set}"
: "${DB_CONNECTION:?DB_CONNECTION environment variable not set}"

# Validate input file
if [ ! -f "$CSV_FILE" ]; then
    echo "ERROR: File not found: $CSV_FILE"
    exit 1
fi

ROW_COUNT=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
if [ "$ROW_COUNT" -eq 0 ]; then
    echo "ERROR: CSV file is empty (no data rows)"
    exit 1
fi

echo "════════════════════════════════════════════════════"
echo "  ASR Customer Data Loader"
echo "════════════════════════════════════════════════════"
echo "  File: $CSV_FILE"
echo "  Rows: $ROW_COUNT"
echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════"
echo ""

# Step 1: Build INSERT statements from CSV (dynamic — reads header)
echo "Step 1: Loading CSV into STG_CUSTOMER..."
HEADER=$(head -1 "$CSV_FILE" | xargs)

SQL_INSERTS=""
while IFS= read -r line; do
    IFS=',' read -ra FIELDS <<< "$line"
    VALUES=""
    for field in "${FIELDS[@]}"; do
        val=$(echo "$field" | xargs | sed "s/'/''/g")
        if [ -z "$VALUES" ]; then
            VALUES="'${val}'"
        else
            VALUES="${VALUES}, '${val}'"
        fi
    done
    SQL_INSERTS="${SQL_INSERTS}INSERT INTO STG_CUSTOMER (${HEADER}) VALUES (${VALUES});
"
done < <(tail -n +2 "$CSV_FILE")

# Step 2: Execute inserts and process staging
OUTPUT=$(sql -S "${DB_USER}/${DB_PASSWORD}@${DB_CONNECTION}" <<EOF
SET SERVEROUTPUT ON

${SQL_INSERTS}
COMMIT;

DECLARE
    v_stg_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_stg_count FROM STG_CUSTOMER WHERE PROCESS_FLAG = 'N';
    DBMS_OUTPUT.PUT_LINE('  Rows loaded to STG_CUSTOMER: ' || v_stg_count);
END;
/

PROMPT
PROMPT Step 2: Processing staging to target (PKG_CUSTOMER_LOAD)...
BEGIN
    PKG_CUSTOMER_LOAD.PROCESS_STAGING;
    DBMS_OUTPUT.PUT_LINE('  PROCESS_STAGING completed successfully');
END;
/

PROMPT
PROMPT Step 3: Verification
SELECT 'TGT_CUSTOMER rows: ' || COUNT(*) AS result FROM TGT_CUSTOMER;

SELECT PROCESS_NAME, STATUS, RECORDS_LOADED,
       TO_CHAR(START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS STARTED
FROM ETL_PROCESS_LOG
ORDER BY LOG_ID DESC
FETCH FIRST 3 ROWS ONLY;

EXIT
EOF
)

echo "$OUTPUT"

if echo "$OUTPUT" | grep -qiE "^ERROR|ORA-|SP2-|SEVERE|Exception"; then
    echo ""
    echo "ERROR: Data loading failed!"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  DATA LOAD COMPLETE"
echo "════════════════════════════════════════════════════"
