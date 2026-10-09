# Enterprise User Management Project

## 📌 Goals
- Create 100+ users from a CSV file using a Bash script
- Assign them to groups (e.g., dev, ops, finance)
- Configure sudo policies so only certain groups can run privileged commands
- Audit failed logins with PAM (`pam_faillock`) and auditd

## ⚙️ Implementation Steps

### Step 1: Install Required Packages
```bash
sudo apt update
sudo apt install auditd -y
```

### Step 2: Prepare User CSV File
Example: `users.csv`

### Step 3: Write User Creation Script
See `create_users.sh` for full script.
Features:
- Creates users with home directories
- Ensures groups exist
- Assigns secondary groups
- Sets default password and forces reset
- Logs all actions to /var/log/enterprise_user_creation.log

### Step 4: Validate Script
Check syntax and debug before execution.
-	Syntax check: `bash -n create_enterprise_users.sh`
-	Static analysis: `shellcheck create_enterprise_users.sh`
-	Debug run: `bash -x create_enterprise_users.sh`

Check:
```
groups alice
sudo cat /var/log/enterprise_user_creation.log
```
### Step 5: Configure Group-Based Policies
Edit sudoers (visudo): `sudo visudo`
```
# Dev group: full sudo
%dev ALL=(ALL) ALL

# Ops group: restart services only
%ops ALL=(ALL) /bin/systemctl restart *

# Finance group: no sudo privileges
```
-	Add %dev ALL=(ALL) ALL → full sudo
-	Add %ops ALL=(ALL) /bin/systemctl restart * → limited sudo
-	Finance group: no sudo entry

### Step 6: Verify Role-Based Access
```
sudo -l -U alice    # should have full sudo
sudo -l -U bob      # only restart services
sudo -l -U charlie  # no sudo
```
I tested my sudoers configuration by verifying group membership, running commands as each user, and checking with sudo -l. <br>
Devs had full sudo, ops could only restart services, and finance had no sudo privileges. <br>
This confirmed role-based access control was working correctly.

### Step 7: Configure PAM for Failed Login Tracking
Edit `/etc/pam.d/common-auth`:
```
auth required pam_faillock.so preauth silent deny=3 unlock_time=600
auth [success=1 default=bad] pam_unix.so nullok
auth [default=die] pam_faillock.so authfail deny=3 unlock_time=600
auth sufficient pam_unix.so try_first_pass
auth required pam_deny.so
```
deny=3 → lock account after 3 failed attempts<br>
unlock_time=600 → auto-unlock after 10 minutes

*	Check failed attempts: `faillock --user alice`<br>
*	Reset counters: `faillock --user alice --reset`

### Step 8: Configure Auditd Rules
Add `/etc/audit/rules.d/auth.rules`:
```
-w /var/log/auth.log -p wa -k auth_fail
-w /var/log/sudo.log -p wa -k sudo_usage
-w /etc/passwd -p wa -k passwd_changes
```
Load rules:
```
sudo augenrules --load
sudo auditctl -l
```
Steps before testing:
Run below steps so that we get required output for test.
- Attempt wrong SSH login: `ssh alice@localhost`
- Run: `sudo ls /root`
- `sudo touch /etc/passwd`

Test: 
```
sudo ausearch -k auth_fail
sudo ausearch -k sudo_usage
sudo ausearch -k passwd_changes
```

Instead of reading raw logs, use these commands:
- Failed logins:
`sudo ausearch -k auth_fail --success no`<br>
→ Shows only failed login attempts.

- Sudo usage:
`sudo ausearch -k sudo_usage | aureport -au`<br>
→ Summarizes which users ran sudo.

- Password file changes:
`sudo ausearch -k passwd_changes | aureport -f`<br>
→ Summarizes file access/change events.

### Step 9: Automate Daily Audit Reports with Cron
- Added `scripts/daily_audit_report.sh` to generate summaries of failed logins, sudo usage, and passwd changes.
- Configured cron to run daily at 11 PM: `0 23 * * * /path/to/scripts/daily_audit_report.sh`
- Reports are stored in `/var/log/daily_audit_report_<date>.log`.


