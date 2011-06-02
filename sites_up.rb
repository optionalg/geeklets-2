#!/usr/bin/env ruby -I.

require "framework/colors"
require "framework/network"

def get_sites_to_check
  # Network checks
  on_whf     = Network.on_network '10.32.*.*'
  on_natrona = Network.on_network '172.16.*.*'
  on_home    = Network.on_network '10.0.1.*'

  sites_to_check = []

  # Always do GW, first
  gw = Network.default_gateway
  sites_to_check << ["GW: #{gw}", gw]

  # Natrona County
  if on_natrona
    sites_to_check << ['IT34',   'it34.natrona.net']
  end

  # WHF
  if on_whf
    sites_to_check << ['WHF AD',    '10.32.10.2']
    sites_to_check << ['WHF DB',    '10.32.10.4']
    sites_to_check << ['TuxBox',    '10.32.10.47']
  end

  # Home Stuff
  if on_home
    sites_to_check << ['Home Server (Internal)', '10.0.1.200']
  else
    sites_to_check << ['Home Server (External)', 'home.batcavern.com']
  end

  # Always
  [
    # Display   Host Address
    ['Google', 'www.google.com']
  ].each {|s| sites_to_check << s}
  sites_to_check
end

def get_site_string site_info
  is_up = Network.site_up? site_info[1]
  status = " UP "
  status = "DOWN" unless is_up

  # color it
  if is_up
    status = "#{Colors.green}#{status}#{Colors.normal}"
  else
    status = "#{Colors.red}#{status}#{Colors.normal}"
  end

  "[#{status}] #{site_info[0]}"
end

#Get sites


# Do default gateway before other sites

# now other sites
sites = get_sites_to_check
sites.each do |site_info|
  puts get_site_string site_info
end