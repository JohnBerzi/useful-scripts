# 1. Create a directory specific to the target IP (e.g., nmap/10.10.10.10)
mkdir -p "nmap/$1"

# 2. Run the fast full-port TCP scan and save inside the IP folder
sudo nmap -p- --min-rate 10000 -Pn "$1" -oN "nmap/$1/tcp_ports.txt"

# 3. Extract TCP ports from that specific folder and run the service scan
sudo nmap -p $(grep "open" "nmap/$1/ports.txt" | awk -F'/' '{print $1}' | paste -sd,) -sCV "$1" -oN "nmap/$1/services.txt"

# 4. Run a top 100 UDP ports scan and save inside the IP folder
sudo nmap -sU --top-ports 100 -Pn "$1" -oN "nmap/$1/udp_ports.txt"
