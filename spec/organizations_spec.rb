require_relative 'spec_helper'
require_relative '../organizations'

organizations_api_body =<<eos
{
"data": [
    {
      "or_id": "OR-w66976m",
      "cp_name": "TV-Oost West",
      "category": "Service Provider",
      "sector": "Cultuur",
      "cp_name_catpro": null,
      "contact_information": {
        "phone": null,
        "website": null,
        "email": null,
        "logoUrl": null
      }
    },
    {
      "or_id": "test_cp_id",
      "cp_name": "test_cp_name",
      "category": "Content Partner",
      "sector": "Cultuur",
      "cp_name_catpro": "AMVB",
      "contact_information": {
        "phone": "+32 2 209 06 01",
        "website": "www.amvb.be/",
        "email": "info@amvb.be",
        "logoUrl": null
      }
    }
]
}
eos
organizations_dirty_cache =<<eos
TEST_CP_NAME: dirtycache_cp_id
eos

organizations_clean_cache =<<eos
---
TVOOSTWEST: OR-w66976m
TEST_CP_NAME: test_cp_id
eos
organizations_cache_filename = 'tmp/organizations.yaml'

RSpec.describe Organizations do
    # Mock the organization api
    before :each do
        File.write organizations_cache_filename, organizations_dirty_cache
    end
    #subject { Organizations.new 'http://api.example.org' }
    let (:cached_organizations) { File.read organizations_cache_filename}

    context do
        before :each do
            stub_request(:get, "http://api.example.org")
                .to_return(body: organizations_api_body, status: 200)
            Organizations.new 'http://api.example.org'
        end
        it do
            expect(WebMock).to have_requested(:get, 'http://api.example.org')
        end
        it do
            expect(cached_organizations).to eq organizations_clean_cache
        end
        it do
            expect(cached_organizations).to eq organizations_clean_cache
        end
    end
    context 'configuration fails when the cache file is' do
        before :each do
            stub_request(:get, "http://api.example.org")
                .to_return(body: 'error', status: 500)
            Organizations.new 'http://api.example.org'
        end
        it do
            expect(WebMock).to have_requested(:get, 'http://api.example.org')
        end
        it do
            expect(cached_organizations).to eq organizations_dirty_cache
        end
    end
    context 'configuration fails when the cache file is missing' do
        before :each do
            File.delete organizations_cache_filename
            stub_request(:get, "http://api.example.org")
                .to_return(body: 'error', status: 500)
        end
        it { expect{Organizations.new 'http://api.example.org'}.to raise_error }
    end
end
