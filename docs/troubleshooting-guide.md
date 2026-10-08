# ASR CI/CD Pipeline — Troubleshooting Guide

## 1. CI Pipeline — ORA-01430 False Positive

**Cause:** The grep pattern `^ERROR|ORA-|SP2-|SEVERE|\.exception\.` matched SQLcl formatting lines like "Error starting at line" and "Error report -". These lines appear when DDL scripts encounter benign "already exists" errors (ORA-01430, ORA-00955). The `^ERROR` prefix matched these lines even after the ORA_EXCLUDE filter removed the actual ORA codes.

**Fix:** Removed `^ERROR|` from the grep pattern in all 5 workflow files (ci-validation.yml, cd-deploy-dev.yml, cd-deploy-sit.yml, cd-deploy-uat.yml, cd-deploy-prod.yml).

**Final pattern:**
```bash
grep -viE "$ORA_EXCLUDE" | grep -qiE "ORA-|SP2-|SEVERE|\.exception\."
```

---

## 2. DEV Deploy — CSV Column Mismatch

**Cause:** The `data/samples/customers.csv` file had old columns (CUSTOMER_PHONE, CUSTOMER_CATEGORY, CUSTOMER_REGION, CUSTOMER_INDUSTRY, CUSTOMER_COUNTRY) that didn't match the actual STG_TABLE columns (CUSTOMER_NAME, CUSTOMER_EMAIL, SOURCE_SYSTEM).

**Fix:** Rewrote customers.csv to match the current table structure with only CUSTOMER_NAME, CUSTOMER_EMAIL, SOURCE_SYSTEM columns.

---

## 3. SIT EC2 — oracle-database-preinstall-21c Not Found

**Cause:** RHEL 8 doesn't include Oracle's preinstall package in its repositories. This package is only available on Oracle Linux.

**Fix:** Manually installed prerequisites:
```bash
sudo dnf install -y libnsl bc compat-openssl10 libaio libaio-devel libgcc libnsl2 libstdc++ make smartmontools sysstat unzip wget
```
Then installed Oracle XE RPM with `sudo rpm -ivh --nodeps` to skip the missing dependency check.

---

## 4. SIT EC2 — Oracle Configure Listener Failed (oraInstaller)

**Cause:** `java.lang.UnsatisfiedLinkError: no oraInstaller in java.library.path` — the Oracle installer's native library couldn't be found because `/etc/oraInst.loc` was missing (not created by the preinstall package since it wasn't available on RHEL 8).

**Fix:** Created the inventory file manually:
```bash
echo -e "inventory_loc=/opt/oracle/oraInventory\ninst_group=oinstall" | sudo tee /etc/oraInst.loc
sudo mkdir -p /opt/oracle/oraInventory
sudo chown -R oracle:oinstall /opt/oracle/oraInventory
```

---

## 5. SIT EC2 — SQLcl ClassNotFoundException

**Cause:** `Error: Could not find or load main class oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli` on the SIT server. Same Java (OpenJDK 17.0.20.1) and same SQLcl version (26.2.1.222.1617) worked on DEV but not on SIT. Root cause was the broken Oracle XE installation (installed with `--nodeps`) leaving the environment in an inconsistent state.

**Fix:** Abandoned the manual SIT installation entirely. Created an AMI from the working DEV EC2 instance and launched a new SIT instance from it. This gave an identical, working environment with Oracle XE, SQLcl, and Java all preconfigured.

---

## 6. SIT EC2 — Listener Using Old DEV Hostname After AMI Clone

**Cause:** After launching SIT from the DEV AMI, the Oracle listener config still referenced the DEV hostname (`ip-172-31-18-208.ec2.internal`). The listener failed to start with `TNS-12545: Connect failed because target host or object does not exist`.

**Fix:** Updated the listener config at the correct path (not `$ORACLE_HOME/network/admin/` but the actual path Oracle reads):
```bash
cat > /opt/oracle/homes/OraDBHome21cXE/network/admin/listener.ora << 'LISTEOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    )
  )
LISTEOF
```
**Key learning:** Check `lsnrctl status` output for `Listener Parameter File` path — that's the actual config file Oracle uses.

---

## 7. SIT EC2 — Listener Shows "No Services" After Start

**Cause:** After starting the listener, the Oracle database hadn't registered its services yet. The `local_listener` parameter still pointed to the old DEV hostname.

**Fix:**
```bash
sqlplus / as sysdba <<'EOF'
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
EXIT
EOF
```
Wait 10 seconds, then `lsnrctl status` should show `xepdb1` as READY.

---

## 8. SIT EC2 — Oracle Not Running After Reboot

**Cause:** After stopping and restarting the SIT EC2 instance, Oracle XE, the listener, and the PDB don't auto-start. The AMI clone didn't preserve the systemd auto-start properly.

**Fix:** After every SIT reboot, manually start Oracle:
```bash
sudo su - oracle
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export ORACLE_SID=XE
export PATH=$ORACLE_HOME/bin:$PATH

lsnrctl start
sqlplus / as sysdba <<'EOF'
STARTUP
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
EXIT
EOF
```
**Permanent fix:** Enable auto-start:
```bash
sudo systemctl enable oracle-xe-21c
```

---

## 9. SIT Pipeline — Silent Failure (No Error Output)

**Cause:** GitHub Actions runs bash with `-e -o pipefail` flags. When `sql` command exits with non-zero (connection failure, SQL error), the `OUTPUT=$(sql ...)` assignment fails and `bash -e` kills the entire script immediately — before `echo "$OUTPUT"` can print the error.

**Fix:** Added `|| true` to the sql command in the SIT workflow:
```bash
OUTPUT=$(sql -S ${DB_OWNER_USER}/${DB_OWNER_PASSWORD}@${DB_CONNECTION} <<EOSQL || true
SET ECHO ON
SET SERVEROUTPUT ON
@${script}
EXIT
EOSQL
)
```
This ensures the output is always captured and the grep error-checking logic handles pass/fail.

---

## 10. SIT Pipeline — Wrong IP in DB_CONNECTION Secret

**Cause:** The `DB_CONNECTION` secret in the GitHub `DB-SIT` environment had an incorrect IP address (`107.22.135.163` instead of the SIT private IP `172.31.32.48`). The runner on DEV couldn't reach SIT, resulting in `ORA-12170: Cannot connect. TCP connect timeout`.

**Fix:** Updated the `DB_CONNECTION` secret in GitHub → repo Settings → Environments → DB-SIT to `172.31.32.48:1521/XEPDB1`.

**Key learning:** Always use the **private IP** for cross-EC2 connections within the same VPC. Public IPs change on stop/start and traffic goes through the internet gateway unnecessarily.

---

## 11. SIT Pipeline — Missing Data Flow Step

**Cause:** The SIT workflow (`cd-deploy-sit.yml`) didn't have a "Data Flow Verification" step to load CSV data into STG_TABLE and process it to TGT_TABLE. The DEV workflow had this step but SIT didn't. The smoke test then failed because TGT_TABLE was empty.

**Fix:** Added the Data Flow step (CSV → STG_TABLE → TGT_TABLE via PKG_CUSTOMER_LOAD.PROCESS_STAGING) to the SIT workflow, placed before the Smoke Tests step.

---

## 12. Merge Conflicts on PR to develop

**Cause:** Feature branch had changes that conflicted with existing files on develop — workflow files and old Liquibase migration XML files.

**Fix:**
- Workflow files: `git checkout --ours` to keep the feature branch version
- Old migration files: `git rm -f` to remove obsolete Liquibase files

---

## Quick Reference — Error Pattern Cheat Sheet

| Error | Likely Cause | First Check |
|-------|-------------|-------------|
| `ORA-12541: TNS:no listener` | Listener not running | `lsnrctl start` |
| `ORA-12514: listener does not currently know of service` | PDB not open or not registered | `ALTER PLUGGABLE DATABASE ALL OPEN; ALTER SYSTEM REGISTER;` |
| `ORA-12547: TNS:lost contact` | Oracle instance not running | `sqlplus / as sysdba` then `STARTUP` |
| `ORA-12170: TCP connect timeout` | Wrong IP, security group, or firewall | Check DB_CONNECTION IP, security group port 1521 |
| `ORA-12545: target host does not exist` | Listener config has wrong hostname | Update listener.ora with `HOST = 0.0.0.0` |
| `ClassNotFoundException: SqlCli` | Broken SQLcl installation | Use AMI from working server |
| `no oraInstaller in java.library.path` | Missing /etc/oraInst.loc | Create oraInst.loc manually |
| Silent pipeline failure (no output) | `bash -e` killing script | Add `\|\| true` to sql command |
| `^ERROR` false positive in grep | SQLcl formatting lines matching | Remove `^ERROR` from grep pattern |
