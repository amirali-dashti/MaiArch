#!/bin/bash

# Set the output file for Archinstall
OUTPUT_FILE="user_config.json"

# Function to create JSON configuration
create_json() {
    cat <<EOF > "$OUTPUT_FILE"
{
    "!users": [
        {
            "sudo": $1,
            "username": "$2"
        }
    ]
}
EOF
}

# Use dialog to get user input
dialog --title "User Configuration for Archinstall" --clear --inputbox "Enter username for the new user:" 8 40 "archinstall" 2> temp_username.txt

# Read the username from the temp file
USERNAME=$(<temp_username.txt)

# Confirm sudo privileges
dialog --title "Sudo Privileges" --yesno "Should this user have sudo privileges?" 7 60

if [ $? -eq 0 ]; then
    SUDO="true"
else
    SUDO="false"
fi

# Create the JSON configuration file
create_json "$SUDO" "$USERNAME"

# Cleanup
rm temp_username.txt

# Notify the user that the configuration file has been created
dialog --title "Configuration Complete" --msgbox "The configuration file has been created: $OUTPUT_FILE" 6 40

# End the script
exit 0
