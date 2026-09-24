STEP 1: Create Feature Branch
Explain: "First, we create a feature branch from develop. This follows Git Flow — all new work starts on a feature branch."


git checkout develop
git pull origin develop
git checkout -b feature/v1.10-add-customer-country
STEP 2: Create Migration Folder
Explain: "Each release gets its own folder under migrations/releases. The folder name matches our version number. Inside, each migration file is numbered in execution order — 001, 002, etc."


mkdir migrations/releases/v1.10
STEP 3: Create Migration Files
Explain: "We need 4 migration files: add the column to staging table, add to target table, update the view, and update the status function. Let me walk through each one."

File 1: migrations/releases/v1.10/001-add-stg-customer-country.xml
Explain: "First, we add the new column to the staging table. This is where raw data lands from source systems. We use Liquibase's addColumn with schemaName so it targets the correct schema (ASR_OWNER), since our pipeline runs as a deploy user. The rollback section ensures we can undo this change if needed."


<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="v1.10-001-add-stg-customer-country" author="asr-team" labels="v1.10">
        <addColumn schemaName="ASR_OWNER" tableName="STG_CUSTOMER">
            <column name="CUSTOMER_COUNTRY" type="VARCHAR2(100)"/>
        </addColumn>
        <rollback>
            <dropColumn schemaName="ASR_OWNER" tableName="STG_CUSTOMER" columnName="CUSTOMER_COUNTRY"/>
        </rollback>
    </changeSet>

</databaseChangeLog>
File 2: migrations/releases/v1.10/002-add-tgt-customer-country.xml
Explain: "Next, we add the same column to the target table. This is the final destination where processed/cleansed data lives. Notice the pattern — staging and target tables stay in sync structurally. Our dynamic package (PKG_CUSTOMER_LOAD) automatically discovers new columns using Oracle's data dictionary, so we don't need to modify the package — it will pick up CUSTOMER_COUNTRY automatically."


<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="v1.10-002-add-tgt-customer-country" author="asr-team" labels="v1.10">
        <addColumn schemaName="ASR_OWNER" tableName="TGT_CUSTOMER">
            <column name="CUSTOMER_COUNTRY" type="VARCHAR2(100)"/>
        </addColumn>
        <rollback>
            <dropColumn schemaName="ASR_OWNER" tableName="TGT_CUSTOMER" columnName="CUSTOMER_COUNTRY"/>
        </rollback>
    </changeSet>

</databaseChangeLog>
File 3: migrations/releases/v1.10/003-update-vw-customer-summary.xml
Explain: "Now we update the customer summary view to include the new column. This view is what our APEX application queries. We use runOnChange=true so if we modify this view definition later, Liquibase re-applies it automatically. The validCheckSum ANY prevents checksum conflicts on redeployments. The rollback restores the previous view definition without CUSTOMER_COUNTRY."


<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="v1.10-003-update-vw-customer-summary" author="asr-team" labels="v1.10" runOnChange="true">
        <validCheckSum>ANY</validCheckSum>
        <comment>Add CUSTOMER_COUNTRY to customer summary view</comment>
        <createView viewName="VW_CUSTOMER_SUMMARY" schemaName="ASR_OWNER" replaceIfExists="true">
            SELECT c.CUSTOMER_ID,
                   c.CUSTOMER_NAME,
                   c.CUSTOMER_EMAIL,
                   c.CUSTOMER_PHONE,
                   c.SOURCE_SYSTEM,
                   c.CREATED_DATE,
                   c.MODIFIED_DATE,
                   c.CUSTOMER_CATEGORY,
                   c.CUSTOMER_REGION,
                   c.CUSTOMER_INDUSTRY,
                   c.CUSTOMER_COUNTRY,
                   FN_CUSTOMER_STATUS(c.CUSTOMER_ID) AS CUSTOMER_STATUS,
                   (SELECT COUNT(*) FROM TGT_CUSTOMER_AUDIT a WHERE a.CUSTOMER_ID = c.CUSTOMER_ID) AS AUDIT_COUNT
            FROM TGT_CUSTOMER c
        </createView>
        <rollback>
            <createView viewName="VW_CUSTOMER_SUMMARY" schemaName="ASR_OWNER" replaceIfExists="true">
                SELECT c.CUSTOMER_ID,
                       c.CUSTOMER_NAME,
                       c.CUSTOMER_EMAIL,
                       c.CUSTOMER_PHONE,
                       c.SOURCE_SYSTEM,
                       c.CREATED_DATE,
                       c.MODIFIED_DATE,
                       c.CUSTOMER_CATEGORY,
                       c.CUSTOMER_REGION,
                       c.CUSTOMER_INDUSTRY,
                       FN_CUSTOMER_STATUS(c.CUSTOMER_ID) AS CUSTOMER_STATUS,
                       (SELECT COUNT(*) FROM TGT_CUSTOMER_AUDIT a WHERE a.CUSTOMER_ID = c.CUSTOMER_ID) AS AUDIT_COUNT
                FROM TGT_CUSTOMER c
            </createView>
        </rollback>
    </changeSet>

</databaseChangeLog>
File 4: migrations/releases/v1.10/004-update-fn-customer-status.xml
Explain: "Finally, we update the customer status function. This function calculates data completeness — it checks how many fields are filled. We're adding CUSTOMER_COUNTRY as the 7th field. If all 7 fields are populated, the status is COMPLETE. This function is used by the view and displayed in APEX. Again, runOnChange=true ensures future edits auto-deploy."


<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="v1.10-004-update-fn-customer-status" author="asr-team" labels="v1.10" runOnChange="true">
        <validCheckSum>ANY</validCheckSum>
        <comment>Include CUSTOMER_COUNTRY in completeness check</comment>
        <createProcedure dbms="oracle" schemaName="ASR_OWNER"><![CDATA[
CREATE OR REPLACE FUNCTION ASR_OWNER.FN_CUSTOMER_STATUS(p_customer_id IN NUMBER)
RETURN VARCHAR2
IS
    v_name      TGT_CUSTOMER.CUSTOMER_NAME%TYPE;
    v_email     TGT_CUSTOMER.CUSTOMER_EMAIL%TYPE;
    v_phone     TGT_CUSTOMER.CUSTOMER_PHONE%TYPE;
    v_category  TGT_CUSTOMER.CUSTOMER_CATEGORY%TYPE;
    v_region    TGT_CUSTOMER.CUSTOMER_REGION%TYPE;
    v_industry  TGT_CUSTOMER.CUSTOMER_INDUSTRY%TYPE;
    v_country   TGT_CUSTOMER.CUSTOMER_COUNTRY%TYPE;
    v_fields    NUMBER := 0;
    v_total     NUMBER := 7;
BEGIN
    SELECT CUSTOMER_NAME, CUSTOMER_EMAIL, CUSTOMER_PHONE,
           CUSTOMER_CATEGORY, CUSTOMER_REGION, CUSTOMER_INDUSTRY, CUSTOMER_COUNTRY
    INTO v_name, v_email, v_phone, v_category, v_region, v_industry, v_country
    FROM TGT_CUSTOMER
    WHERE CUSTOMER_ID = p_customer_id;

    IF v_name IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_email IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_phone IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_category IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_region IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_industry IS NOT NULL THEN v_fields := v_fields + 1; END IF;
    IF v_country IS NOT NULL THEN v_fields := v_fields + 1; END IF;

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
        ]]></createProcedure>
        <rollback>
            <createProcedure dbms="oracle" schemaName="ASR_OWNER"><![CDATA[
CREATE OR REPLACE FUNCTION ASR_OWNER.FN_CUSTOMER_STATUS(p_customer_id IN NUMBER)
RETURN VARCHAR2
IS
    v_name      TGT_CUSTOMER.CUSTOMER_NAME%TYPE;
    v_email     TGT_CUSTOMER.CUSTOMER_EMAIL%TYPE;
    v_phone     TGT_CUSTOMER.CUSTOMER_PHONE%TYPE;
    v_category  TGT_CUSTOMER.CUSTOMER_CATEGORY%TYPE;
    v_region    TGT_CUSTOMER.CUSTOMER_REGION%TYPE;
    v_industry  TGT_CUSTOMER.CUSTOMER_INDUSTRY%TYPE;
    v_fields    NUMBER := 0;
    v_total     NUMBER := 6;
BEGIN
    SELECT CUSTOMER_NAME, CUSTOMER_EMAIL, CUSTOMER_PHONE,
           CUSTOMER_CATEGORY, CUSTOMER_REGION, CUSTOMER_INDUSTRY
    INTO v_name, v_email, v_phone, v_category, v_region, v_industry
    FROM TGT_CUSTOMER
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
            ]]></createProcedure>
        </rollback>
    </changeSet>

</databaseChangeLog>
STEP 4: Update CSV Data File
Explain: "We also update our sample data file to include the new CUSTOMER_COUNTRY column. This CSV is loaded by the pipeline's Data Flow step into the staging table, then processed into the target table by our dynamic package."

Replace data/samples/customers.csv with:


SOURCE_SYSTEM,CUSTOMER_NAME,CUSTOMER_EMAIL,CUSTOMER_PHONE,CUSTOMER_CATEGORY,CUSTOMER_REGION,CUSTOMER_INDUSTRY,CUSTOMER_COUNTRY
CRM,Alpha Technologies,alpha@alphatech.com,+1-555-0201,GOLD,US-EAST,Technology,USA
CRM,Beta Solutions,info@betasol.com,+1-555-0202,SILVER,US-WEST,Healthcare,Canada
CRM,Gamma Financial,contact@gammafin.com,+1-555-0203,GOLD,US-CENTRAL,Finance,USA
CRM,Delta Manufacturing,sales@deltamfg.com,+1-555-0204,BRONZE,US-EAST,Manufacturing,Germany
CRM,Epsilon Retail,info@epsilonretail.com,+1-555-0205,SILVER,US-WEST,Retail,UK
STEP 5: Commit and Push
Explain: "Now we commit all our changes and push to the feature branch. This does NOT trigger the CI pipeline yet — CI only triggers when we create a Pull Request."


git add migrations/releases/v1.10/
git add data/samples/customers.csv
git commit -m "feat(v1.10): add CUSTOMER_COUNTRY column to STG, TGT, view, and status function"
git push origin feature/v1.10-add-customer-country
STEP 6: Create Pull Request (GitHub Web UI)
Explain: "Now we go to GitHub and create a Pull Request from our feature branch to develop. This triggers our CI pipeline — the PR Validation workflow."

Go to GitHub repo → Pull requests → New pull request
Base: develop ← Compare: feature/v1.10-add-customer-country
Title: feat(v1.10): Add CUSTOMER_COUNTRY column
Click Create pull request
Explain: "Watch the CI pipeline — it runs these validation gates automatically:

G2: Shell script validation
G3: Migration naming convention (checks our 001-, 002- pattern)
G4: Rollback existence (verifies every changeSet has a rollback)
G5: Security scan (no hardcoded passwords)
G6: SQL syntax validation (connects to DB, validates changelog)
G8: Dependency order (master changelog references exist)"
STEP 7: Merge PR → Triggers CD Pipeline
Explain: "Once CI passes (green check), we merge the PR into develop. This triggers the CD pipeline — Deploy to DEV — which actually applies the changes to our Oracle database."

Click Merge pull request → Confirm merge
Explain: "The CD pipeline runs these deployment gates:

Pre-Deploy: Tags database state (rollback point)
G9: Dry-run (previews SQL without executing)
G10: Execute migration (runs Liquibase update)
G11: Object validity (recompiles schema, checks all objects are VALID)
G14: Smoke tests (package callable, target table has data)
Data Flow: Loads CSV → Staging → Target via dynamic package
Audit record: Logs deployment in DATABASECHANGELOG"
STEP 8: Verify in APEX SQL Commands
Explain: "Now let's verify the changes directly in the database through APEX SQL Commands."

Check 1 — Column exists in both tables:


SELECT column_name FROM user_tab_columns WHERE table_name = 'TGT_CUSTOMER' AND column_name = 'CUSTOMER_COUNTRY';
Expected: CUSTOMER_COUNTRY row returned

Check 2 — Staging data has country values:


SELECT CUSTOMER_NAME, CUSTOMER_COUNTRY, PROCESS_FLAG FROM STG_CUSTOMER WHERE SOURCE_SYSTEM = 'CRM';
Expected: 5 rows with USA, Canada, USA, Germany, UK

Check 3 — Target table has country values:


SELECT CUSTOMER_NAME, CUSTOMER_EMAIL, CUSTOMER_INDUSTRY, CUSTOMER_COUNTRY FROM TGT_CUSTOMER ORDER BY CUSTOMER_ID DESC;
Expected: 5 rows with CUSTOMER_COUNTRY populated

Check 4 — View includes country:


SELECT CUSTOMER_NAME, CUSTOMER_COUNTRY, CUSTOMER_STATUS FROM VW_CUSTOMER_SUMMARY;
Expected: All rows show COMPLETE status (all 7 fields filled)

Check 5 — Deployment audit trail:


SELECT ID, AUTHOR, DATEEXECUTED FROM DATABASECHANGELOG WHERE LABELS = 'v1.10' ORDER BY ORDEREXECUTED;
Expected: 4 rows — our 4 migration changesets

STEP 9: Verify in APEX Customer Portal
Explain: "Finally, let's check the end-user experience in our APEX Customer Portal application."

Open the APEX Customer Portal app
Go to Customers page
Click Actions → Columns → Enable CUSTOMER_COUNTRY
Or click Synchronize Columns if available
"You can now see CUSTOMER_COUNTRY in the interactive report — USA, Canada, Germany, UK — flowing all the way from our CSV through the CI/CD pipeline to the end user's screen."

DEMO SUMMARY (Closing Statement)
"What we just demonstrated is a complete CI/CD pipeline for Oracle database changes:

Developer creates migration files in a version-controlled Git repo
Pull Request triggers automated CI validation — naming, rollbacks, security, syntax
Merge triggers automated CD deployment — dry-run, execute, validate, smoke test
Dynamic package automatically discovers new columns — no package changes needed
Data flows from CSV → Staging → Target → APEX in a fully automated pipeline
Every change is tracked, auditable, and rollback-ready
No manual SQL execution, no SSH into production, no human error"
