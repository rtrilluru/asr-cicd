CREATE OR REPLACE FUNCTION ASR_OWNER.FN_CUSTOMER_STATUS(p_customer_id IN NUMBER)
RETURN VARCHAR2
IS
    v_name      TGT_TABLE.CUSTOMER_NAME%TYPE;
    v_email     TGT_TABLE.CUSTOMER_EMAIL%TYPE;
    v_fields    NUMBER := 0;
    v_total     NUMBER := 2;
BEGIN
    SELECT CUSTOMER_NAME, CUSTOMER_EMAIL
    INTO v_name, v_email
    FROM TGT_TABLE
    WHERE CUSTOMER_ID = p_customer_id;

    IF v_name IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_email IS NOT NULL THEN v_fields := v_fields + 1; END IF;

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
