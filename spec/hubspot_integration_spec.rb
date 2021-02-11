require 'spec_helper'
require "./hubspot_integration.rb"

RSpec.describe HubSpotIntegration do
  it "should run" do
    VCR.use_cassette("fetch_call") do
      response = main({id: 8020, livecall_api_key: 'Xq2L18bIWBDvgpMRwt5w3Q==', hub_spot_api_key: '8072f27f-f2f4-4310-8a87-cdf3d1f35799'})
      expect(response[:result]).to eq("ok")
    end
  end
end
