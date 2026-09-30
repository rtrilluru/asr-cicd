CREATE OR REPLACE FUNCTION ASR_OWNER.FN_CUSTOMER_STATUS(p_customer_id IN NUMBER)
RETURN VARCHAR2
IS
    v_name      TGT_TABLE.CUSTOMER_NAME%TYPE;
    v_email     TGT_TABLE.CUSTOMER_EMAIL%TYPE;
    v_phone     TGT_TABLE.CUSTOMER_PHONE%TYPE;
    v_category  TGT_TABLE.CUSTOMER_CATEGORY%TYPE;
    v_region    TGT_TABLE.CUSTOMER_REGION%TYPE;
    v_industry  TGT_TABLE.CUSTOMER_INDUSTRY%TYPE;
    v_fields    NUMBER := 0;
    v_total     NUMBER := 6;
BEGIN
    SELECT CUSTOMER_NAME, CUSTOMER_EMAIL, CUSTOMER_PHONE,
           CUSTOMER_CATEGORY, CUSTOMER_REGION, CUSTOMER_INDUSTRY
    INTO v_name, v_email, v_phone, v_category, v_region, v_industry
    FROM TGT_TABLE
    WHERE CUSTOMER_ID = p_customer_id;

    IF v_name IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_email IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_phone IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_category IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_region IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_industry IS NOT NULL THEN v_fields := v_fields + 1; END IF;

    IF v_fields = v_total THEN
        RETURN 'COMPLETE';
    ELSIF v_fields >= 1 THEN
        RETURN 'PARTIAL';
    ELSE
        RETURN 'INCOMPLETE';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NOT_FOUND';
END FN_CUSTOMER_STATUS;
/
