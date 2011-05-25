class Network
  def self.external_ip
    %x[curl -s www.icanhazip.com].strip
  end

  def self.ips
    ips = []
    ifconfig = %x[ifconfig]
    m = ifconfig.scan /^\s*inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i
    m.each { |ip| ips << ip[0] } if m
    ips
  end

  def self.interface_list
    interfaces = []
    rx = /^(\w+\d+):.*\s(?:^\s+.*\s)+/i
    ifconfig = %x[ifconfig]
    m = ifconfig.scan rx
    m.each { |iif| interfaces << iif[0] }
    interfaces
  end

  def self.ip_for_interface iif
    rx = /(?:inet)\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/i
    ifconfig = %x[ifconfig #{iif}]
    m = rx.match ifconfig
    return nil unless m
    m[1]
  end

  def self.default_gateway
    routes = %x[netstat -nr]
    rx = /^default\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i
    m = rx.match routes
    return nil unless m
    m[1]
  end

  def self.ping host
    ping = `ping -c 1 -t 1 #{host} 2>&1`
    return nil if ping =~ /Unknown host$/i
    return -1 if ping =~ /100(?:\.0)?% packet loss/i
    m = /time=(\d+(?:\.\d+)) ms/i.match ping
    m[1].to_f
  end

  def self.site_up? host, timeout = 1000
    ping = self.ping host
    return false if ping.nil?
    return true unless ( ping < 0 || ping > timeout )
  end

  def self.on_network network
    ips.each do |ip|
      return true if ip_matches_pattern ip, network
    end

    # nope :(
    false
  end

  def self.ip_matches_pattern ip, pattern
    # Simple test to identify if you are on the specified network
    # at the end it will turn the network specified into a ^REGEX
    #
    # Can use * wildcard which will translate to \d{1,3} in regex parlance

    rx_str = "^#{pattern}"
    rx_str.gsub! '*', '\d{1,3}'
    rx_str.gsub! '.', '\.'
    rx = Regexp.new rx_str
    return true if rx.match ip
    false
  end
end