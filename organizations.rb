require 'yaml'
require 'rest-client'
# Organizations fetches organization data from the api or local file and caches 
# it in memory. The data is available via a 'hash' interface.
class Organizations

    def initialize url
        @organizations = get_from_api url
        save_to_file
    rescue StandardError => e
        $stderr.puts "Error fetchnig organizations from #{url}: #{e}"
        @organizations = load_from_file
    end

    # Let the object behave like the @organizations hash
    def method_missing(method, *args, &block)
        @organizations.send(method, *args, &block)
    end

    def cache_filename
        File.expand_path('tmp/organizations.yaml', File.dirname(__FILE__))
    end

    def save_to_file
        File.write cache_filename, @organizations.to_yaml
    rescue
        $stderr.puts 'Warning failed to write organizationt ids to cache'
    end

    def load_from_file
        YAML.load_file cache_filename
    end

    def get_from_api url
        response = RestClient::Request
            .execute(method: :get, url: url, timeout: 5)
        data = JSON.parse(response.body)["data"]
        data.each_with_object({}) do |x,hash|
            hash[prefix x] = x["or_id"]
        end
    end

    def prefix organization
        organization["cp_name"].gsub(/\W/,'').upcase
    end

end

