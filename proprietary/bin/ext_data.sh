#!/system/bin/sh

if [ "$1" = "-u" ]; then
	temp=`getprop sys.data.IPV6.disable`
	ifname=`getprop sys.data.net.addr`
	`echo ${temp} > /proc/sys/net/ipv6/conf/$ifname/disable_ipv6`
	`echo -1 > /proc/sys/net/ipv6/conf/$ifname/accept_dad`
	echo 1 > /proc/sys/net/ipv6/conf/$ifname/accept_ra_from_local

    	ifname=`getprop sys.data.setip`
	ip $ifname
	ifname=`getprop sys.data.setmtu`
	ip $ifname
	ifname=`getprop sys.ifconfig.up`
	ip $ifname
	ifname=`getprop sys.data.noarp`
	ip $ifname
    ifname=`getprop sys.data.noarp.ipv6`
    ip $ifname


##For Auto Test
	ethup=`getprop ril.gsps.eth.up`

	if [ "$ethup" = "1" ]; then

		ifname=`getprop sys.data.net.addr`
		localip=`getprop sys.gsps.eth.localip`

		iptype=`getprop sys.data.activating.type`

		if [ "$iptype" = "IPV4" ]; then

			pcv4addr=`getprop sys.gsps.eth.peerip`

			setprop ril.gsps.eth.up 0

			iptables -t nat --flush
			iptables -t mangle --flush
			iptables -t filter --flush
			ip rule del table 66
			ip route del table 66
			ip route add default via $localip dev $ifname
			ip route add default via $localip dev $ifname table 66
			ip route add local $localip dev $ifname proto kernel scope host src $localip
			ip rule add from all iif rndis0 lookup 66
			iptables -D FORWARD -j natctrl_FORWARD
			iptables -D natctrl_FORWARD -j DROP
			iptables -t nat -A PREROUTING -i $ifname -j DNAT --to-destination $pcv4addr
			iptables -I FORWARD 1 -i $ifname -d $pcv4addr -j ACCEPT
			iptables -A FORWARD -i rndis0 -o $ifname -j ACCEPT
			iptables -t nat -A POSTROUTING -s $pcv4addr -j SNAT --to-source $localip
			iptables -I FORWARD -o $ifname -p all ! -d $localip/24 -j DROP
			iptables -I OUTPUT -s $localip -p udp --dport 53 -j DROP
			iptables -I OUTPUT -s $localip -p udp --dport 123 -j DROP
		  	temp=`getprop net.$ifname.ip_type`
			if [ "$temp" = "1" ]; then #only v4
				echo 1 > proc/sys/net/ipv6/conf/$ifname/disable_ipv6
			fi
		elif [ "$iptype" = "IPV6" ]; then
			#start radvd and dhcp6s  for lan. @20150902@junjie.wang@6704#
			ndc tether radvd remove_upstream $ifname >/storage/sdcard0/radvd1.log
			ip -6 rule del iif rndis0 lookup 1002 pref 18500
			sleep 5

			ndc tether radvd add_upstream $ifname >/storage/sdcard0/radvd2.log
			#add rule for ipv6 route
			ip -6 rule add iif rndis0 lookup 1002 pref 18500
			#add default route to ifname
			ip -6 route add default dev $ifname
			temp=`getprop net.$ifname.ip_type`
			if [ "$temp" = "2" ]; then #only v6
				setprop ril.gsps.eth.up 0
			fi
		fi
	fi

	setprop sys.ifconfig.up done
	setprop sys.data.noarp done
elif [ "$1" = "-d" ]; then
	ifname=`getprop sys.ifconfig.down`
	ip $ifname
	ifname=`getprop sys.data.clearip`
	ip $ifname
	setprop sys.ifconfig.down done

	ethdown=`getprop ril.gsps.eth.down`
	if [ "$ethdown" = "1" ]; then
                iptables -X
		setprop ril.gsps.eth.down 0
		setprop sys.gsps.eth.ifname ""
		setprop sys.gsps.eth.localip ""
		setprop sys.gsps.eth.peerip ""
		#for ipv6 test@20150902@junjie.wang@6704#
		ndc tether radvd remove_upstream seth_lte0
		ip -6 rule del iif rndis0 lookup 1002 pref 18500
	fi

elif [ "$1" = "-e" ]; then
        iptables -A FORWARD -p udp --dport 53 -j DROP
        iptables -A INPUT -p udp --dport 53 -j DROP
        iptables -A OUTPUT -p udp --dport 53 -j DROP
        ip6tables -A FORWARD -p udp --dport 53 -j DROP
        ip6tables -A INPUT -p udp --dport 53 -j DROP
        ip6tables -A OUTPUT -p udp --dport 53 -j DROP

elif [ "$1" = "-c" ]; then
        iptables -D FORWARD -p udp --dport 53 -j DROP
        iptables -D INPUT -p udp --dport 53 -j DROP
        iptables -D OUTPUT -p udp --dport 53 -j DROP
        ip6tables -D FORWARD -p udp --dport 53 -j DROP
        ip6tables -D INPUT -p udp --dport 53 -j DROP
        ip6tables -D OUTPUT -p udp --dport 53 -j DROP

fi
