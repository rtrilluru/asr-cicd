-- ============================================================
-- CLEANUP: Drop everything and start fresh for demo
-- Run this manually on the database before the demo
-- ============================================================

-- Drop dependent objects first
DROP VIEW ASR_OWNER.VW_CUSTOMER_SUMMARY;
DROP TRIGGER TRG_CUSTOMER_AUDIT;
DROP PACKAGE PKG_CUSTOMER_LOAD;
DROP FUNCTION FN_CUSTOMER_STATUS;
DROP PROCEDURE SP_REFRESH_STAGING;

-- Drop tables
DROP TABLE TGT_TABLE_AUDIT PURGE;
DROP TABLE ETL_PROCESS_LOG PURGE;
DROP TABLE TGT_TABLE PURGE;
DROP TABLE STG_TABLE PURGE;

-- ============================================================
-- Recreate base tables with simple columns (demo starting point)
-- ============================================================

CREATE TABLE STG_TABLE (
    CUSTOMER_ID      NUMBER GENERATED ALWAYS AS IDENTITY,
    CUSTOMER_NAME    VARCHAR2(200),
    CUSTOMER_EMAIL   VARCHAR2(200),
    SOURCE_SYSTEM    VARCHAR2(50),
    CREATED_DATE     DATE DEFAULT SYSDATE
);

CREATE TABLE TGT_TABLE (
    CUSTOMER_ID      NUMBER GENERATED ALWAYS AS IDENTITY,
    CUSTOMER_NAME    VARCHAR2(200),
    CUSTOMER_EMAIL   VARCHAR2(200),
    SOURCE_SYSTEM    VARCHAR2(50),
    CREATED_DATE     DATE DEFAULT SYSDATE
);

CREATE TABLE TGT_TABLE_AUDIT (
    AUDIT_ID         NUMBER GENERATED ALWAYS AS IDENTITY,
    CUSTOMER_ID      NUMBER,
    ACTION           VARCHAR2(10),
    OLD_NAME         VARCHAR2(200),
    NEW_NAME         VARCHAR2(200),
    CHANGE_DATE      DATE DEFAULT SYSDATE,
    CHANGED_BY       VARCHAR2(100)
);

CREATE TABLE ETL_PROCESS_LOG (
    LOG_ID           NUMBER GENERATED ALWAYS AS IDENTITY,
    PROCESS_NAME     VARCHAR2(100),
    STATUS           VARCHAR2(20),
    START_TIME       DATE,
    END_TIME         DATE,
    RECORDS_PROCESSED NUMBER,
    ERROR_MESSAGE    VARCHAR2(4000)
);

COMMIT;

-- Verify
SELECT table_name FROM user_tables ORDER BY table_name;
