require "cora"
require "siri_objects"
require "pp"
require "rest_client" # HTTP requests
require "json" # Parse Hue responses

################################################################################
#
# Hue got me babe
#
################################################################################


class HueEntity

@@hueIP = "192.168.1.10" #change this in the config.yml - not here
@@hueKey ="asdaskjdksjbkjbfkjb" #change this in the config.yml - not here

  attr_accessor :type
  attr_accessor :name
  attr_accessor :number


  def initialize (capturedString,hue_ip,hue_hash)
    log(capturedString)
    @@hueIP = hue_ip #set in config.yml 
    @@hueKey = hue_hash #set in config.yml
    response = RestClient.get("#{@@hueIP}/api/#{@@hueKey}")
    data = JSON.parse(response)
    lights = data["lights"].map do |key, light|
      {type: :light, name: light["name"].to_s, number: key.to_i}
    end
    lights.push({type: :group, name: "all", number: 0})
    result = lights.select { |light| light[:name].to_s.downcase == capturedString }
    result = result[0]

    if result.nil?
      return false 
    end

    @type = result[:type]
    @number = result[:number]
    @name = result[:name]
  end

  def power (value)
    if self.type == :group
      url = "#{@@hueIP}/api/#{@@hueKey}/groups/#{@number}/action"
    else
      url = "#{@@hueIP}/api/#{@@hueKey}/lights/#{@number}/state"
    end
    RestClient.put(url, {on: value}.to_json, content_type: :json)
  end

  def brightness (*args)
    if args.size < 1
      url = "#{@@hueIP}/api/#{@@hueKey}/lights/#{@number}"
      response = RestClient.get(url)
      data = JSON.parse(response)
      brightness = data["state"]["bri"].to_i
      return brightness
    elsif args.size == 1
      value = args[0]
      if (value > 254) then value = 254
      elsif (value < 0) then value = 0
      end
      url = "#{@@hueIP}/api/#{@@hueKey}/lights/#{@number}/state"
      RestClient.put(url, {:bri => value}.to_json, content_type: :json)
    end
  end
  def color (hue)
    url = "#{@@hueIP}/api/#{@@hueKey}/lights/#{@number}/state"
    RestClient.put(url, {hue: 182*hue, sat: 254}.to_json, content_type: :json)
  end
end

class SiriProxy::Plugin::Hue < SiriProxy::Plugin
  attr_accessor :hue_ip
  attr_accessor :hue_hash
    
    def initialize(config = {})
        self.hue_ip = config["ip"]
        self.hue_hash = config["hash"]
    end
  
  def parseNumbers (value)
    value = value.sub_numbers
    if (value =~ /%/)
      value = value.delete("%").to_i * 254 / 100
    end
  end

  def is_numeric?(obj)
    obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
  end

  # test
  listen_for /lighting special/i 
    # test four lights
    url = "#{self.hue_ip}/api/#{self.hue_hash}/groups/0/action"
    hue = 182
    
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    sleep(3)
       hue = hue +4000
    RestClient.put(url, {hue: hue, sat: 254}.to_json, content_type: :json)
    
    say "Lighting scene one enabled."
    request_completed
  end

  # Binary state
  listen_for /turn (on|off)(?: the)? ([a-z]*)/i do |state, entity|
  
    unless(matchedEntity = HueEntity.new(entity,hue_ip,hue_hash))
      say "I couldn't find any lights by that name."
      request_completed
    end

    if (state == "on") then matchedEntity.power(true)
    else matchedEntity.power(false)
    end
    if matchedEntity.type == :group
      if matchedEntity.name == "all"
        say "I've turned #{state} all of the lights for you."
      else
        say "I've turned #{state} the #{entity} lights for you."
      end
    else
      say "I've turned #{state} the #{entity} light for you."
    end

    request_completed
  end

  # Relative brightness change
  listen_for /turn (up|down)(?: the)? ([a-z]*)/i do |change, entity|

    unless(matchedEntity = HueEntity.new(entity,hue_ip,hue_hash))
      say "I couldn't find any lights by that name."
      request_completed
    end

    currentBrightness = matchedEntity.brightness

    if (change == "up") then newBrightness = currentBrightness + 50
    else newBrightness = currentBrightness - 50
    end
    matchedEntity.brightness(newBrightness)

    response = ask "Is that enough?"

    if (response =~ /yes/i)
      say "I'm happy to help."
    elsif (response =~ /more|no/i)
      if (change == "up") then newBrightness += 50
      else newBrightness -= 50
      end
      matchedEntity.brightness(newBrightness)
      say "You're right, that does look better"
    end

    request_completed
  end

  # Absolute brightness/color change
  #   Numbers (0-254) and percentages (0-100) are treated as brightness values
  #   Strings are used as a color query to lookup HSV values
  listen_for /set(?: the)? ([a-z]*) to ([a-z0-9%]*)/i do |entity, value|
    unless(matchedEntity = HueEntity.new(entity,hue_ip,hue_hash))
      say "I couldn't find any lights by that name."
      request_completed
    end

    if (is_numeric? value)
      value = parseNumbers(value)
      log value
      matchedEntity.brightness(value.to_i)
    else
      # query color for hsl value
      query = "http://www.colourlovers.com/api/colors?keywords=#{value}&numResults=1&format=json"
      # set entity to color value
    end

    say "There you go."

    request_completed
  end


  
  
end
