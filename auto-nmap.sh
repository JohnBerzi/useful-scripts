# 1. Create a directory specific to the target IP (e.g., nmap/10.10.10.10)
mkdir -p "nmap/$1"

# 2. Run the fast full-port scan and save inside the IP folder
sudo nmap -p- --min-rate 10000 -Pn "$1" -oN "nmap/$1/ports.txt"

# 3. Extract ports from that specific folder and run the service scan
sudo nmap -p $(grep "open" "nmap/$1/ports.txt" | awk -F'/' '{print $1}' | paste -sd,) -sCV "$1" -oN "nmap/$1/services.txt"
