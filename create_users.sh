#!/bin/bash

# Check if the user list file is provided as an argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <user_list_file>"
  exit 1
fi

# Define the user list file from the argument
USER_FILE="$1"

# Check if the user list file exists
if [ ! -f "$USER_FILE" ]; then
  echo "User list file $USER_FILE not found!"
  exit 1
fi

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure the log and password files exist
sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE
mkdir -p /var/secure
sudo touch $PASSWORD_FILE
sudo chmod 666 $PASSWORD_FILE

# Function to generate a random password
generate_password() {
  < /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+=' | head -c 12
}

# Read the user file
while IFS=';' read -r username groups || [ -n "$username" ]; do
    if id "$username" &>/dev/null; then
        echo "User $username already exists." | tee -a $LOG_FILE
    else
    # Create the user with a home directory
    sudo useradd -m -s /bin/bash "$username"
    echo "Created user $username." | tee -a $LOG_FILE

    # Generate and set a random password
    password=$(generate_password)
    echo "$username:$password" | sudo chpasswd
    echo "$username:$password" >> $PASSWORD_FILE
    echo "Password for user $username set." | tee -a $LOG_FILE

    # Set ownership and permissions for the home directory
    sudo chown "$username:$username" /home/$username
    sudo chmod 700 /home/$username
    echo "Home directory permissions set for $username." | tee -a $LOG_FILE

    # Handle groups
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
      if getent group "$group" &>/dev/null; then
        echo "Group $group already exists." | tee -a $LOG_FILE
      else
        sudo groupadd "$group"
        echo "Created group $group." | tee -a $LOG_FILE
      fi
      sudo usermod -aG "$group" "$username"
      echo "Added user $username to group $group." | tee -a $LOG_FILE
    done
  fi
done < "$USER_FILE"