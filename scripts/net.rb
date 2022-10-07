require "json"
require "resolv"
require "ipaddr"

cwd = File.dirname(__FILE__)
Dir.chdir(cwd)
load "util.rb"

###

template = File.read("../template/servers.json")
ca = File.read("../static/ca.pem")
tls_wrap = read_tls_wrap("auth", 1, "../static/ta.key", 1)

cfg = {
  ca: ca,
  tlsWrap: tls_wrap,
  cipher: "AES-256-CBC",
  digest: "SHA1",
  compressionFraming: 0
}

recommended = {
  id: "default",
  name: "Default",
  comment: "256-bit encryption",
  ovpn: {
    cfg: cfg
  }
}

defaults = {
  :username => "ivpnXXXXXXXX",
  :country => "US"
}

###

json = JSON.parse(template)

endpoints = []
all_ports = json["config"]["ports"]
all_ports["openvpn"].each { |map|
  single_port = map["port"]
  next if single_port.nil?
  proto = map["type"]
  endpoints << "#{proto}:#{single_port}"
}

recommended[:ovpn][:endpoints] = endpoints
presets = [recommended]

###

servers = []

json["openvpn"].each { |server|
  hostname = server["gateway"]
  hostname_comps = hostname.split(".")

  id = hostname_comps[0]
  country = server["country_code"]
  category = ""
  area = server["city"]
  extraCountry = nil

  resolved = server["hosts"].map { |h|
    h["host"]
  }

  addresses = nil
  if resolved.nil?
    if hostname.nil?
      next
    end
    if ARGV.include? "noresolv"
      addresses = []
    else
      addresses = Resolv.getaddresses(hostname)
    end
    addresses.map! { |a|
      IPAddr.new(a).to_i
    }
  else
    addresses = resolved.map { |a|
      IPAddr.new(a).to_i
    }
  end

  server = {
    :id => id,
    :country => country.upcase
  }
  server[:category] = category if !category.empty?
  server[:extra_countries] = [extraCountry.upcase] if !extraCountry.nil?
  server[:area] = area if !area.nil?
  if hostname.empty?
    server[:resolved] = true
  else
    server[:hostname] = hostname
  end
  server[:addrs] = addresses
  servers << server
}

###

infra = {
  :servers => servers,
  :presets => presets,
  :defaults => defaults
}

puts infra.to_json
puts
