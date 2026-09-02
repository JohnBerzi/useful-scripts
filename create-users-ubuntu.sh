#!/bin/bash

# Ensure the script is run with sudo / root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo."
  exit 1
fi

# Check for correct arguments
if [ -z "$1" ]; then
  echo "Usage: sudo $0 <team_file.txt> [user_to_delete]"
  echo "Example: sudo $0 users.txt cyber-team"
  exit 1
fi

INPUT_FILE="$1"
USER_TO_DELETE="$2"

# Check if the input file actually exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' not found."
  exit 1
fi

# ==============================================================================
#  SECTION 1: DYNAMIC USER REMOVAL
# ==============================================================================
if [ -n "$USER_TO_DELETE" ]; then
  echo "=========================================="
  echo " Checking for user to remove: '$USER_TO_DELETE'..."
  echo "=========================================="

  if id "$USER_TO_DELETE" &>/dev/null; then
    if [ "$SUDO_USER" == "$USER_TO_DELETE" ]; then
      echo "  Warning: You are currently running this script via sudo as '$USER_TO_DELETE'."
      echo "   To avoid immediately disconnecting your session, this user will NOT be deleted."
    else
      echo "  Deleting user '$USER_TO_DELETE' and removing their home directory..."
      userdel -rf "$USER_TO_DELETE" 2>/dev/null
      echo " Successfully removed '$USER_TO_DELETE'."
    fi
  else
    echo "  User '$USER_TO_DELETE' does not exist on this server. Skipping removal."
  fi
fi

# ==============================================================================
# SECTION 2: GLOBAL PRIVILEGES SECURING
# ==============================================================================
echo "=========================================="
echo "Securing Global Privileges..."
echo "=========================================="

# Lock the root password completely
echo "Locking the root password..."
passwd -l root

# Configure passwordless sudo for the sudo group
SUDOERS_FILE="/etc/sudoers.d/90-passwordless-sudo"
if [ ! -f "$SUDOERS_FILE" ]; then
  echo "🛠️  Configuring passwordless sudo for admin users..."
  echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
  chmod 0440 "$SUDOERS_FILE"
fi

# Ensure the docker group exists on the system
if ! getent group docker > /dev/null; then
  echo "Creating 'docker' group as it does not exist..."
  groupadd docker
fi

# ==============================================================================
# SECTION 3: AUTOMATED TEAM USER CREATION (SSH Only)
# ==============================================================================
echo "=========================================="
echo "Starting automated team user creation (SSH Only)..."
echo "=========================================="

# Clean Windows line endings (\r) on the fly to prevent broken SSH keys
sed 's/\r//g' "$INPUT_FILE" | while read -r username ssh_key || [ -n "$username" ]; do
  
  # Trim spaces from username
  username=$(echo "$username" | tr -d '[:space:]')

  # Skip empty lines or comment lines starting with #
  if [ -z "$username" ] || [[ "$username" =~ ^# ]]; then
    continue
  fi

  # Clean trailing whitespaces/newlines from the SSH key itself
  ssh_key=$(echo "$ssh_key" | sed 's/[[:space:]]*$//')

  # Check if an SSH key was actually provided for this user
  if [ -z "$ssh_key" ]; then
    echo "Error: No SSH key found in file for user '$username'. Skipping."
    continue
  fi

  # Check if the user already exists on the Ubuntu system
  if id "$username" &>/dev/null; then
    echo "Skipping: User '$username' already exists."
  else
    # 1. Create the user cleanly. Try --badname first, fall back to standard useradd if needed.
    useradd -m -s /bin/bash -p '!' --badname "$username" 2>/dev/null || useradd -m -s /bin/bash -p '!' "$username" 2>/dev/null

    if [ $? -eq 0 ]; then
      USER_HOME="/home/$username"

      # 2. Set up the secure .ssh directory structure
      mkdir -p "$USER_HOME/.ssh"
      echo "$ssh_key" > "$USER_HOME/.ssh/authorized_keys"

      # 3. Apply strict Linux permissions for SSH to function
      chmod 700 "$USER_HOME/.ssh"
      chmod 600 "$USER_HOME/.ssh/authorized_keys"
      chown -R "$username":"$username" "$USER_HOME/.ssh"

      # 4. Add user to 'sudo' and 'docker' groups
      usermod -aG sudo,docker "$username"

      echo "✅ Created: $username | SSH Key Configured (Passwordless Sudo & Docker enabled)"
    else
      echo "❌ Failed to create user: $username"
    fi
  fi
done

echo "=========================================="
echo "Task completed successfully!"
echo "=========================================="
