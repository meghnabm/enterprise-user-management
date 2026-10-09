#!/bin/bash

INPUT_FILE="users.csv"
LOG_FILE="/var/log/enterprise_user_creation.log"

# Skip header row by using tail -n +2
tail -n +2 “$INPUT_FILE” | while IFS=',' read -r username primary_group secondary_groups
do
    echo "Processing user: $username" | tee -a $LOG_FILE
    
    # Ensure primary group exists
    if ! getent group “$primary_group” > /dev/null; then
        groupadd “$primary_group” 
        echo "Group $primary_group created." | tee -a $LOG_FILE
    fi
    
    # Create user with home directory
    useradd -m -g “$primary_group” -s /bin/bash “$username”
    
    # Add secondary group if provided
    if [ -n "$secondary_groups" ]; then
        if ! getent group “$secondary_groups” > /dev/null; then
            groupadd “$secondary_groups”
            echo "Group $secondary_groups created." | tee -a “$LOG_FILE”
        fi
        usermod -aG “$secondary_groups” “$username”
    fi
    
    # Set default password and force change
    echo "$username:Password123” | chpasswd
    chage -d 0 “$username”
    
    echo "User $username created successfully." | tee -a $LOG_FILE
done
