#!/usr/bin/env ruby
class Network
  def self.external_ip
    %x[curl -s www.icanhazip.com].strip
  end

  def self.ips
    interface_list.collect{ |iff| iff[:ip] }.reject{|ip| ip.to_s.empty? }
  end

  def self.interface_list
    interfaces = []
    rx = /^(\w+\d+):.*\s(?:^\s+.*\s)+/i
    ifconfig = %x[ifconfig]
    m = ifconfig.scan rx
    m.each { |iif| interfaces << iif[0] }

    info = []
    interfaces.each do |iif|
      info << Network.interface_info(iif)
    end
    info
  end

  def self.ip_for_interface iif
    rx = /(?:inet)\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/i
    ifconfig = %x[ifconfig #{iif}]
    m = rx.match ifconfig
    return nil unless m
    m[1]
  end

  def self.interface_info interface
    ip_rx     = /(?:inet)\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/i
    mac_rx    = /(?:ether|lladdr)\s+((?:[a-z0-9]{2}:?)+)/i
    status_rx = /(?:status):\s+(\w+)/i
    ifconfig  = %x[ifconfig #{interface}]

    info = {
      :name             => interface,
      :hardware_address => nil,
      :ip               => nil,
      :status           => :inactive
    }
    m = ip_rx.match(ifconfig)
    info[:ip] = m[1] if m

    m = mac_rx.match(ifconfig)
    info[:hardware_address] = m[1] if m

    m = status_rx.match(ifconfig)
    if m
      info[:status] = :active if m[1].downcase.strip == 'active'
    else
      # I am guessing that there may be more adapaters like PPP/TUN so if they
      # are on the list and have an IP then make 'em active
    #elsif info[:name] =~ /^(u?tun|ppp)/i
      # PPP/TUN adapters don't have status, they just come and go
      # so if they are here then they are active
      info[:status] = :active if info[:ip]
    end
    # Make sure that we don't mark an interface without an IP active
    info[:status] = :inactive if info[:ip].to_s.empty?

    info
  end

  def self.default_gateway
    routes = %x[netstat -nr]
    rx = /^default\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i
    m = rx.match routes
    return nil unless m
    m[1]
  end

  def self.ping host
    return nil if host.to_s.empty?
    ping = `ping -c 1 -t 2 #{host} 2>&1`
    return nil if ping =~ /Unknown host$/i
    return -1 if ping =~ /100(?:\.0)?% packet loss/i
    m = /time=(\d+(?:\.\d+)) ms/i.match ping
    return nil unless m
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

if $0 == __FILE__
  ifs = Network.interface_list
  puts %Q{
  Default Gateway: #{Network.default_gateway}
  Interfaces (#{ifs.size}):}
  ifs.each do |iff|
    puts "    #{iff[:name]}"
    puts "         MAC: #{iff[:hardware_address]}"
    puts "          IP: #{iff[:ip]}"
    puts "      STATUS: #{iff[:status]}"
  end

  puts "\n\n  IPs:"
  Network.ips.each do |ip|
    puts "    #{ip}"
  end

  locations = %w[127.0.0.* 192.168.0.* 192.168.1.* 192.168.85.* 10.0.0.* 10.0.1.* 10.8.0.*]
  puts %Q{
  Location\n}
  locations.each do |net|
    puts "    %15s: #{Network.on_network net}" % net
  end
end
