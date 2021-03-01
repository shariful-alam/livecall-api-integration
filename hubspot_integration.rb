require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem "hubspot-ruby", "0.9.0"
end


require 'hubspot-ruby'
require 'uri'
require 'net/http'
require 'openssl'

class HubSpotIntegration
  HUBPOST_API_KEY = '8072f27f-f2f4-4310-8a87-cdf3d1f35799'

  def self.main(params)
    set_api_key
    call_attributes = {}
    call = make_http_request("https://api.t.livecall.io/v2/calls/#{params[:id]}", params[:livecall_api_key])
    call_attributes[:body_string] = generate_info_string(call["data"]["attributes"])
    call_attributes[:phone_number] = call["data"]["attributes"]["phone_number"]
    call_attributes[:kind] = call["data"]["attributes"]["kind"]
    call_attributes[:duration] = call["data"]["attributes"]["duration"]
    call_attributes[:name] = ""
    call_attributes[:email] = ""
    call_attributes[:from_number] = ""
    unless call["data"]["relationships"]["user"]["links"]["related"].nil?
      user_id = call["data"]["relationships"]["user"]["links"]["related"].split("/").last.to_i
      user = make_http_request("https://api.t.livecall.io/v2/users/#{user_id}", params[:livecall_api_key])
      call_attributes[:user_name] = user["data"]["attributes"]["name"]
      call_attributes[:email] = user["data"]["attributes"]["email"]
      call_attributes[:from_number] = user["data"]["attributes"]["phone_number"]
    end
    contact = retrieve_contact(call_attributes[:phone_number])
    if contact.nil?
      if !call_attributes[:kind].eql?("external") && !call_attributes[:kind].eql?("external_text")
        contact = Hubspot::Contact.create!(
          call_attributes[:email], {
          firstname: call_attributes[:user_name],
          phone: call_attributes[:phone_number]
        })
        create_engagement("CALL", call_attributes, contact.vid)
        return { result: "ok" }
      end
    else
      if call_attributes[:kind].eql?("external_text")
        call_attributes[:body_string] = "Description: This is an SMS. " + call_attributes[:body_string]
        create_engagement("NOTE", call_attributes, contact.vid)
        return { result: "ok" }
      else
        create_engagement("CALL", call_attributes, contact.vid)
        return { result: "ok" }
      end
    end
  rescue Exception => error
    return error
  end

  private

  def self.create_engagement(type, attributes = {}, contact_id)
    if type.eql?("CALL")
      Hubspot::Engagement.create!({
                                    engagement: {
                                      type: type,
                                      active: true
                                    },
                                    associations: {
                                      contactIds: [contact_id]
                                    },
                                    metadata: {
                                      toNumber: attributes[:phone_number],
                                      fromNumber: attributes[:from_number],
                                      status: "COMPLETED",
                                      durationMilliseconds: attributes[:duration],
                                      body: attributes[:body_string]
                                    }
                                  })
    elsif type.eql?("NOTE")
      Hubspot::Engagement.create!({
                                    engagement: {
                                      type: type,
                                      active: true
                                    },
                                    associations: {
                                      contactIds: [contact_id]
                                    },
                                    metadata: {
                                      body: attributes[:body_string]
                                    }
                                  })
    end
  end

  def self.retrieve_contact(phone_number)
    contact = Hubspot::Contact.search(phone_number)["contacts"][0]
    if contact.nil?
      contact = Hubspot::Contact.search(phone_number.gsub(/\s/, ""))["contacts"][0]
    end
    if contact.nil?
      contact = Hubspot::Contact.search(phone_number.gsub(/^\+/, ""))["contacts"][0]
    end
    if contact.nil?
      contact = Hubspot::Contact.search(phone_number.gsub(/[\+\s]/, ""))["contacts"][0]
    end
    if contact.nil?
      contact = Hubspot::Contact.search(phone_number.gsub(/^\+\d+\s/, ""))["contacts"][0]
    end
    contact
  end

  def self.set_api_key
    Hubspot.configure(hapikey: HUBPOST_API_KEY)
  end

  def self.make_http_request(url, api_key)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Token #{api_key}"
    request["Content-Type"] = 'application/json'
    response = http.request(request)
    response = JSON.parse(response.body)
    response
  end

  def self.generate_info_string(attributes = {})
    info_string = "Phone number: #{attributes["phone_number"]}, Kind: #{attributes["kind"].split('_').map(&:capitalize).join(' ')}"
    unless attributes["started_at"].nil?
      info_string = info_string + ", Time: #{attributes["started_at"]}"
    end
    unless attributes["duration"].nil?
      info_string = info_string + ", Duration: #{attributes["duration"]}"
    end
    unless attributes["direction"].nil?
      info_string = info_string + ", Direction: #{attributes["direction"]}"
    end
    unless attributes["text_content"].nil?
      info_string = info_string + ", SMS Content: #{attributes["text_content"]}"
    end
    unless attributes["comment"].nil?
      info_string = info_string + ", Comment: #{attributes["comment"]}"
    end
    info_string
  end
end


def main(parameters = {})
  HubSpotIntegration.main(parameters)
end
