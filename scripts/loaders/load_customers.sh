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

# Step 1: Build INSERT statements from CSV
echo "Step 1: Loading CSV into STG_CUSTOMER..."
SQL_INSERTS=""
while IFS=',' read -r sys name email phone; do
    sys=$(echo "$sys" | xargs)
    name=$(echo "$name" | xargs)
    email=$(echo "$email" | xargs)
    phone=$(echo "$phone" | xargs)
    SQL_INSERTS="${SQL_INSERTS}INSERT INTO STG_CUSTOMER (SOURCE_SYSTEM, CUSTOMER_NAME, CUSTOMER_EMAIL, CUSTOMER_PHONE) VALUES ('${sys}', '${name}', '${email}', '${phone}');
"
done < <(tail -n +2 "$CSV_FILE")

# Step 2: Execute inserts and process staging
sql -S "${DB_USER}/${DB_PASSWORD}@${DB_CONNECTION}" <<EOF
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

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Data loading failed!"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  DATA LOAD COMPLETE"
echo "════════════════════════════════════════════════════"
