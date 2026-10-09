#!/bin/bash

REPORT_FILE="/var/log/daily_audit_report_$(date +%F).log"

{
    echo "=== Daily Audit Report for $(date) ==="
    echo ""

    echo "--- Failed Logins ---"
    ausearch -k auth_fail --success no | aureport -au --summary
    echo ""

    echo "--- Sudo Usage ---"
    ausearch -k sudo_usage | aureport -au --summary
    echo ""

    echo "--- Passwd Changes ---"
    ausearch -k passwd_changes | aureport -f --summary
    echo ""
} > "$REPORT_FILE"

echo "Report generated: $REPORT_FILE"
