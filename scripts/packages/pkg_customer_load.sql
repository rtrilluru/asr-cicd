CREATE OR REPLACE PACKAGE BODY ASR_OWNER.PKG_CUSTOMER_LOAD AS
    PROCEDURE PROCESS_STAGING IS
        v_start_time  TIMESTAMP := SYSTIMESTAMP;
        v_count       NUMBER := 0;
        v_cols        VARCHAR2(4000);
        v_update_set  VARCHAR2(4000);
        v_insert_cols VARCHAR2(4000);
        v_insert_vals VARCHAR2(4000);
        v_sql         VARCHAR2(8000);
    BEGIN
        SELECT LISTAGG(col, ', ') WITHIN GROUP (ORDER BY col),
               LISTAGG(CASE WHEN col != 'CUSTOMER_EMAIL'
                            THEN 't.' || col || ' = s.' || col END, ', ')
                   WITHIN GROUP (ORDER BY col),
               LISTAGG(col, ', ') WITHIN GROUP (ORDER BY col),
               LISTAGG('s.' || col, ', ') WITHIN GROUP (ORDER BY col)
        INTO   v_cols, v_update_set, v_insert_cols, v_insert_vals
        FROM (
            SELECT s.column_name AS col
            FROM   user_tab_columns s
            JOIN   user_tab_columns t ON t.column_name = s.column_name
                                      AND t.table_name = 'TGT_TABLE'
            WHERE  s.table_name = 'STG_TABLE'
            AND    s.column_name NOT IN ('CUSTOMER_ID','CREATED_DATE','MODIFIED_DATE',
                                         'STG_ID','PROCESS_FLAG','PROCESS_DATE')
        );

        v_update_set := LTRIM(v_update_set, ', ');

        v_sql := 'MERGE INTO TGT_TABLE t '
              || 'USING (SELECT ' || v_cols || ' FROM STG_TABLE WHERE PROCESS_FLAG = ''N'') s '
              || 'ON (t.CUSTOMER_EMAIL = s.CUSTOMER_EMAIL) '
              || 'WHEN MATCHED THEN UPDATE SET ' || v_update_set || ', t.MODIFIED_DATE = SYSDATE '
              || 'WHEN NOT MATCHED THEN INSERT (' || v_insert_cols || ', CREATED_DATE, MODIFIED_DATE) '
              || 'VALUES (' || v_insert_vals || ', SYSDATE, SYSDATE)';

        EXECUTE IMMEDIATE v_sql;
        v_count := SQL%ROWCOUNT;

        UPDATE STG_TABLE SET PROCESS_FLAG = 'Y' WHERE PROCESS_FLAG = 'N';
        COMMIT;

        INSERT INTO ETL_PROCESS_LOG (PROCESS_NAME, START_TIME, END_TIME, RECORDS_LOADED, STATUS)
        VALUES ('PROCESS_STAGING', v_start_time, SYSTIMESTAMP, v_count, 'COMPLETED');
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Processed ' || v_count || ' staging records');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            INSERT INTO ETL_PROCESS_LOG (PROCESS_NAME, START_TIME, END_TIME, RECORDS_LOADED, STATUS)
            VALUES ('PROCESS_STAGING', v_start_time, SYSTIMESTAMP, 0, 'FAILED');
            COMMIT;
            RAISE;
    END PROCESS_STAGING;
END PKG_CUSTOMER_LOAD;
/
