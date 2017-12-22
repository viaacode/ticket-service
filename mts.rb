require 'json'
require 'yaml'
require 'net/http'
require 'rack'
require 'rest-client'
require_relative 'lib/ticket'
require_relative 'lib/swarmbucket'

class Mts

    MAXAGE_DEFAULT = 14400 # default TTL of the tickets

    class Error < StandardError
        def status
            500
        end
    end

    class Forbidden < Error
        def status
            403
        end
    end

    class NotFound < Error
        def status
            404
        end
    end

    class ArgumentError < Error
        def status
            400
        end
    end

    class << self

        def healthcheck
            if @@tenant2id && @@subjectheader
                response2json 'OK', 200
            else
                response2json 'NOK', 500
            end
        end

        def tenent_id_cache_file
            File.expand_path('tmp/orid.yaml', File.dirname(__FILE__))
        end

        def save_tenant_ids tenant2id
            File.write tenent_id_cache_file, tenant2id.to_yaml
        rescue
            $stderr.puts 'Warning failed to write tenantt ids to cache'
        end

        def load_tenant_ids
            YAML.load_file tenent_id_cache_file
        end

        def path organization
            organization["cp_name"].gsub(/\W/,'').upcase
        end

        def get_tenant_ids
           response = RestClient::Request.execute(method: :get,
                                                  url: @@organizations_api,
                                                  timeout: 10)
           tenant2id = JSON.parse(response.body)["data"].each_with_object({}) do |x,hash|
               hash[path x] = x["or_id"]
           end
           save_tenant_ids tenant2id
           tenant2id
        rescue StandardError => e
            $stderr.puts "Error fetchnig organizations from #{@@organizations_api}: #{e}"
            load_tenant_ids
        end

        def configure config
            Ticket.secrets = config['appsecrets']
            Ticket.seed = config['appseed']
            @@organizations_api = config["organizations_api"]
            @@subjectheader = config['subjectheader']
            @@maxage = config['maxage'] || MAXAGE_DEFAULT
            @@backend = config['backend']
            @@buckets = config['buckets']
            @@superorid = config['superorid']
            @@tenant2id = get_tenant_ids
            self
        end

        def call env
            request = new env
            raise Forbidden, 'unauthorized' unless request.authorized?
            response2json request.getticket
        rescue => e
            $stderr.puts e, e.backtrace
            case e
            when Ticket::ArgumentError
                status = 400
                message = e.message
            when Mts::Error
                status = e.status
                message = e.message
            else
                status = 500
                message = 'Internal error'
            end
            response2json({ error: message, status: status }, status)
        end

        def response2json body, status=200
            response = Rack::Response.new([], status)
            response.write body.to_json if body
            response.set_header('Content-Type', 'application/json')
            response.finish
        end

    end

    def initialize env
        @request = Rack::Request.new env
        @tenants = tenants_from_cert
        raise ArgumentError,
            'subject must have O' if @tenants.empty?
        @params = request_params
        @formats = @params.delete(:format)
        raies ArgumentError 'too many parameters' if @params.length > 6
        if @formats
            @basename, @type = split_name
        end
    end

    def getticket
        if @formats
            checktickets
        else
            ticket = Ticket.new(@params)
            { jwt: ticket.jwt, context: ticket.to_hash }
        end
    end

    def authorized?
        tenantname = prefix
        return false unless tenantname
        @tenants.include?(@@superorid) || @tenants.include?(@@tenant2id[tenantname])
    end

    private

    def split_name
        namesplit = /(.+)\.(\w+$)/.match(@params[:name])
        raise ArgumentError unless namesplit
        namesplit[1..2]
    end

    def body_params
        body = @request.body.read(384)
        return {} unless body
        bodyparams = JSON.parse(body, max_nesting: 2,
                                allow_nan: false,
                                symbolize_names: true)
        raise ArgumentError,
            'error parsing request body' unless bodyparams.is_a?(Hash)
        bodyparams
    end

    def uri_params
        @request.GET.each_with_object({}) do |p,hash|
            hash[p[0].to_sym] = p[1][0,128]
        end
    end

    def request_params
        params = uri_params.merge body_params
        params[:app] ||= @tenants&.first
        params[:maxage] ||= @@maxage
        # If no name has been supplied, use path info as name
        params[:name] ||= @request.path_info[%r{/(.*)},1]
        params
    end

    def tenants_from_cert
        subject = @request.get_header(@@subjectheader)
        raise ArgumentError, 'certificate missing' unless subject
        subject&.scan(%r{(?:[/,]|^)O=([^/,]+)})&.flatten
    end

    def check_types type
        case type
        when 'm3u8'
            ['ts.1', 'm3u8']
        else
            Array type
        end
    end

    def prefix
        @params[:name][%r{([^/]+)/},1]
    end

    def checktickets
        tickets = formats.each_with_object([]) do |type, mytickets|
            bucket = @@buckets[type] || @@buckets[@type]
            ttl = check_types(type).each_with_object([]) do |sfx, tl|
                tl << SwarmBucket.present?(
                    URI "http://#{@@backend}/#{bucket}/#{@basename}.#{sfx}"
                )
            end
            if ttl.all? { |tl| tl.is_a?(Integer) ? (tl&.> @params[:maxage]) : tl }
                ticket = Ticket.new( @params.merge(name: "#{@basename}.#{type}"))
                mytickets << { jwt: ticket.jwt }.merge(ticket.to_hash)
            end
        end
        raise NotFound, "#{@basename} not found" if tickets.empty?
        { total: tickets.length, name: @basename, results: tickets }
    end

    def formats
        raise ArgumentError, "unknown bucket #{@type}" unless @@buckets.keys.include?(@type)
        formats = case @formats
                  when Array then @formats
                  when String then Array(@formats.split ',')
                  else @@buckets.keys
                  end
        raise  ArgumentError, 'max 3 @formats elements' if formats.length > 3
        formats << @type unless formats.include?(@type)
        formats
    end

end
