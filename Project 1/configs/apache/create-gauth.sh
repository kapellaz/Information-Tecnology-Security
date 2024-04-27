#!/bin/sh
 
# Parse arguments
USERNAME="$1"
 
if [ -z "$USERNAME" ]; then
  echo "Usage: $(basename $0) <username>"
  exit 2
fi
 
# Set the label the user will see when importing the token:
LABEL='OpenVPN Server'
 
su -c "google-authenticator -t -d -r3 -R30 -W -f -l \"${LABEL}\" -s /etc/openvpn/google-authenticator/${USERNAME}" - gauth

