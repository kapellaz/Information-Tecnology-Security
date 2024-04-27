#DMZ
#	DNS: 23.214.219.130
#	mail: 23.214.219.131
#	smtp: 23.214.219.132
#	www: 23.214.219.133
#	vpn-gw: 23.214.219.134
#	local external interface: 87.248.214.89
#	external interface: 192.168.93.131

#INTERNAL:

#	DHCP Client 1: 192.168.10.2
#	DHCP Client 2: 192.168.10.3
#	DHCP Client 3: 192.168.10.4
#	FTP: 192.168.10.5
#	datastore: 192.168.10.6
#	local external interface: 87.248.214.89
#	external interface: 192.168.93.130

#ROUTER:
#	DMZ interface: 23.214.219.254
#	internal network interface: 192.168.10.254
#	local external network interface: 87.248.214.97
#	external network: 192.168.10.128
	


systemctl stop firewalld
systemctl disable firewalld
systemctl mask firewalld
systemctl enable iptables
systemctl start iptables

echo 1 > /proc/sys/net/ipv4/ip_forward


iptables -F
iptables -t nat -F

iptables -P INPUT DROP
iptables -P FORWARD DROP



# Firewall configuration to protect the router:

# DNS:

iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

#to test:
#	router :  nc -l -v -u -p 53
#	dmz: nc -v -u 23.214.219.130 53


#SSH:
 #vpn-gw:
iptables -A INPUT -s 23.214.219.134 -p tcp --dport ssh -j ACCEPT

 #internal-network:
iptables -A INPUT -s 192.168.10.0/24 -p tcp --dport ssh -j ACCEPT


# Firewall configuration to authorize direct communications (without NAT):

# Domain name resolutions using the dns server:

iptables -A FORWARD -d 23.214.219.130 -p udp --dport domain -j ACCEPT
iptables -A FORWARD -d 23.214.219.130 -p tcp --dport domain -j ACCEPT

#to test:
#	dmz: nc -l -v -u -p 53
#	internal: nc -v -u 23.214.219.130 53



# The dns server should be able to resolve names using DNS servers on the Internet (dns2 and also others):

iptables -A FORWARD -s 23.214.219.130 -d 87.248.214.0/24 -p udp --dport domain -j ACCEPT

iptables -A FORWARD -s 87.248.214.0/24 -d 23.214.219.130 -p udp --dport domain -j ACCEPT

iptables -A FORWARD -s 23.214.219.130 -d 87.248.214.0/24 -p udp --sport domain -j ACCEPT

iptables -A FORWARD -s 87.248.214.0/24 -d 23.214.219.130 -p udp --sport domain -j ACCEPT




# The dns and dns2 servers should be able to synchronize the contents of DNS zones: 
iptables -A FORWARD -d 23.214.219.132 -p tcp --dport smtp -j ACCEPT
iptables -A FORWARD -s 23.214.219.132 -p tcp --sport smtp -j ACCEPT

#to test:
#	dmz:  nc -l -v -p 25
#	internal: nc -v 23.214.219.132 25



# POP and IMAP connections to the mail server:

iptables -A FORWARD -d 23.214.219.131 -p tcp --dport pop3 -j ACCEPT
iptables -A FORWARD -s 23.214.219.131 -p tcp --sport pop3 -j ACCEPT
iptables -A FORWARD -d 23.214.219.131 -p tcp --dport imap -j ACCEPT
iptables -A FORWARD -s 23.214.219.131 -p tcp --sport imap -j ACCEPT



# test pop3: 
#	dmz: nc -l -v -p 110
#	internal: nc -v 23.214.219.131 110

# test imap: 
#	dmz: nc -l -v -p 143
#	internal: nc -v 23.214.219.131 143



# HTTP and HTTPS connections to the www server:

iptables -A FORWARD -d 23.214.219.133 -p tcp --dport http -j ACCEPT
iptables -A FORWARD -s 23.214.219.133 -p tcp --sport http -j ACCEPT
iptables -A FORWARD -d 23.214.219.133 -p tcp --dport https -j ACCEPT
iptables -A FORWARD -s 23.214.219.133 -p tcp --sport https -j ACCEPT

# test http: 
#	dmz: nc -l -v -p 80
#	internal: nc -v 23.214.219.133 80

# test http: 
#	dmz: nc -l -v -p 443
#	internal: nc -v 23.214.219.133 443




# OpenVPN connections to the vpn-gw server:

iptables -A FORWARD -d 23.214.219.134 -p tcp --dport openvpn -j ACCEPT
iptables -A FORWARD -s 23.214.219.134 -p tcp --sport openvpn -j ACCEPT


# test openvpn: 
#	dmz: nc -l -v -p 1194
#	internal: nc -v 23.214.219.134 1194



# VPN clients connected to the gateway (vpn-gw) should be able to connect to all services in the Internal network (assume the gateway does SNAT/MASQUERADING for communications received from clients)

iptables -A FORWARD -s 23.214.219.134 -d 192.168.10.0/24 -p tcp -j ACCEPT 
iptables -A FORWARD -d 23.214.219.134 -s 192.168.10.0/24 -p tcp -j ACCEPT 

# test vpn client: 
#	dmz: nc -l -v -p 1194
#	internal: nc -v 23.214.219.134 1194



# Firewall configuration for connections to the external IP address of the firewall (using NAT):

# FTP connections (in passive and active modes) to the ftp server:

modprobe nf_conntrack_ftp
modprobe nf_nat_ftp
echo 1 > /proc/sys/net/netfilter/nf_conntrack_helper

# active mode

iptables -t nat -A PREROUTING -s 87.248.214.0/24 -d 87.248.214.97 -p tcp --dport ftp -j DNAT --to-destination 192.168.10.5
iptables -A FORWARD -d 192.168.10.5 -p tcp --dport ftp -j ACCEPT
iptables -A FORWARD -s 192.168.10.5 -p tcp --sport ftp -j ACCEPT
iptables -A FORWARD -d 192.168.10.5 -p tcp --dport ftp-data -j ACCEPT
iptables -A FORWARD -s 192.168.10.5 -p tcp --sport ftp-data -j ACCEPT


# passive mode
iptables -t nat -A PREROUTING -s 87.248.214.0/24 -d 87.248.214.97 -p tcp --dport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j DNAT --to-destination 192.168.10.5


iptables -A FORWARD -d 87.248.214.97 -p tcp --dport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -A FORWARD -d 87.248.214.97 -p tcp --sport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT



# SSH connections to the datastore server, but only if originated at the eden or dns2 servers:

iptables -t nat -A PREROUTING -s 193.136.212.1 -d 87.248.214.97 -p tcp --dport ssh -j DNAT --to-destination 192.168.10.6
iptables -A FORWARD -s 193.136.212.1 -d 192.168.10.6 -p tcp --dport ssh -j ACCEPT
iptables -A FORWARD -s 192.168.10.6 -d 193.136.212.1 -p tcp --sport ssh -j ACCEPT
iptables -t nat -A PREROUTING -s 193.137.16.75 -d 87.248.214.97 -p tcp --dport ssh -j DNAT --to-destination 192.168.10.6
iptables -A FORWARD -s 193.137.16.75 -d 192.168.10.6 -p tcp --dport ssh -j ACCEPT
iptables -A FORWARD -s 192.168.10.6 -d 193.137.16.75 -p tcp --sport ssh -j ACCEPT



# PARA TESTAR:

iptables -t nat -A PREROUTING -s 87.248.214.89 -d 87.248.214.97 -p tcp --dport ssh -j DNAT --to-destination 192.168.10.6
iptables -A FORWARD -s 87.248.214.89 -d 192.168.10.6 -p tcp --dport ssh -j ACCEPT
iptables -A FORWARD -s 192.168.10.6 -d 87.248.214.89 -p tcp --sport ssh -j ACCEPT


# numa pc com rede externa de ip 87.248.214.89 para testar, mas que na realidade seriam 193.136.212.1 e 193.137.16.75
# ssh rui@192.168.10.6


# Firewall configuration for communications from the internal network to the outside (using NAT

iptables -A FORWARD -p udp -s 192.168.10.0/24 -d 87.248.214.0/24 --dport domain -j ACCEPT
iptables -A FORWARD -p udp -d 192.168.10.0/24 -s 87.248.214.0/24 --sport domain -j ACCEPT
iptables -t nat -A POSTROUTING -p udp -s 192.168.10.0/24 -d 87.248.214.0/24 --dport domain -j SNAT --to-source 87.248.214.97


iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 87.248.214.0/24 --dport domain -j ACCEPT
iptables -A FORWARD -p tcp -d 192.168.10.0/24 -s 87.248.214.0/24 --sport domain -j ACCEPT
iptables -t nat -A POSTROUTING -p tcp -s 192.168.10.0/24 -d 87.248.214.0/24 --dport domain -j SNAT --to-source 87.248.214.97



# test :
#	external: nc -l -v -u -p 53
#	internal: nc -v -u 87.248.214.89 53



# HTTP, HTTPS and SSH connections:


iptables -t nat -A POSTROUTING -p tcp -s 192.168.10.0/24 -d 192.168.93.0/24 --dport http -j SNAT --to-source 192.168.93.128 

iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 87.248.214.0/24   --dport http -j ACCEPT

iptables -A FORWARD -p tcp -d 192.168.10.0/24 -s 87.248.214.0/24   --sport http -j ACCEPT



iptables -t nat -A POSTROUTING -p tcp -s 192.168.10.0/24 -d  87.248.214.0/24 --dport https -j SNAT --to-source 87.248.214.97 

iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 87.248.214.0/24   --dport https -j ACCEPT

iptables -A FORWARD -p tcp -d 192.168.10.0/24 -s 87.248.214.0/24   --sport https -j ACCEPT




iptables -t nat -A POSTROUTING -p tcp -s 192.168.10.0/24 -d  87.248.214.0/24 --dport ssh -j SNAT --to-source 87.248.214.97 

iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 87.248.214.0/24   --dport ssh -j ACCEPT

iptables -A FORWARD -p tcp -d 192.168.10.0/24 -s 87.248.214.0/24   --sport ssh -j ACCEPT



# sudo lsof -i:<PORT> -> to see pid of processes using a port so you can kill them
# test :
#	external: nc -l -v -p 443 or 80 or 22
#	internal: nc -v 87.248.214.89 443 or 80 or 22


# FTP:


iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -d 87.248.214.0/24 -p tcp --dport ftp -j SNAT --to-source 87.248.214.97
iptables -A FORWARD -d 87.248.214.0/24 -p tcp --dport ftp -j ACCEPT
iptables -A FORWARD -s 87.248.214.0/24 -p tcp --sport ftp -j ACCEPT
iptables -A FORWARD -s 87.248.214.0/24 -p tcp --sport ftp-data -j ACCEPT
iptables -A FORWARD -d 87.248.214.0/24 -p tcp --dport ftp-data -j ACCEPT



iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -d 87.248.214.0/24 -p tcp --dport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j SNAT --to-source 87.248.214.97
iptables -A FORWARD -d 87.248.214.0/24 -p tcp --dport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -d 87.248.214.0/24 -p tcp --sport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -d 192.168.10.0/24 -p tcp --dport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -A FORWARD -d 192.168.10.0/24 -p tcp --sport 60000:60099 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT




# preparation for suricata
iptables - FORWARD -j NFQUEUE --queue-num 0



iptables-save > /etc/sysconfig/iptables
systemctl restart iptables
iptables -L -n 
iptables -t nat -L -n






