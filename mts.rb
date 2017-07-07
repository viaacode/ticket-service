require 'json'
require 'yaml'
require 'net/http'
require 'rack'
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
            if @@tenants &&
                    #Ticket.seed &&
                    #Ticket.secrets &&
                    @@subjectheader
                set_response 'OK', 200
            else
                set_response 'NOK', 500
            end
        end

        def configure config
            Ticket.secrets = config['appsecrets']
            Ticket.seed = config['appseed']
            @@tenants = config["oridmap"]
            @@subjectheader = config['subjectheader']
            @@maxage = config['maxage'] || MAXAGE_DEFAULT
            @@backend = config['backend']
            @@buckets = config['buckets']
            self
        end

        def call env
            request = new env
            raise Forbidden, 'unauthorized' unless request.authorized?
            set_response request.getticket
        rescue => e
            puts e#, e.backtrace
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
            set_response({ error: message, status: status }, status)
        end

        def set_response body, status=200
            response = Rack::Response.new([], status)
            response.write body.to_json if body
            response.set_header('Content-Type', 'application/json')
            response.finish
        end

    end

    def initialize env
        request = Rack::Request.new env
        subject = request.get_header(@@subjectheader)
        raise ArgumentError, 'certificate missing' unless subject
        body = request.body.read(384)
        bodyparams = JSON.parse(body, max_nesting: 1,
                                allow_nan: false,
                                symbolize_names: true) if body
        bodyparams = {} unless bodyparams.is_a? Hash
        uriparams = request.GET.each_with_object({}) do |p,hash|
            hash[p[0].to_sym] = p[1][0,128]
        end
        # If no name has been supplied, use path info as name
        uriparams[:name] ||= request.path_info[%r{/(.*)},1]
        @params = uriparams.merge bodyparams
        @allowed_tenants = subject&.scan(%r{(?:[/,]|^)O=([^/,]+)})&.flatten
        raise ArgumentError,
            'subject must have O' if @allowed_tenants.empty?
        @params[:app] ||= @allowed_tenants&.first
        @params[:maxage] ||= @@maxage
        check = @params.delete :check
        if check
            raise ArgumentError unless
            match = /(.*)\.(\w+$)/.match(@params[:name])  
            @basename = match[1]
            @type = match[2]
            raise ArgumentError, "unknown bucket for type: #{@type}" unless
            @@buckets.keys.include?(@type)
            @check = case check
                     when Array then check
                     when String then Array(check)
                     else []
                     end
            @check << @type unless @check.include?(@type)
            raise  ArgumentError, 'max 3 check elements' if @check.length > 3
        end
    end

    def suffix type
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

    def authorized?
        tenantname = prefix
        return false unless tenantname
        @allowed_tenants.include? @@tenants[tenantname]
    end

    def checktickets
        tickets = []
        @check.each do |type|
            bucket = @@buckets[type]
            ttl = suffix(type).each_with_object([]) do |sfx, tl|
                tl << SwarmBucket.present?(
                    URI "http://#{@@backend}/#{bucket}/#{@basename}.#{sfx}"
                ) 
            end
            if ttl.all? do |tl|
                ( tl.is_a?(TrueClass) or tl&.> @params[:maxage])
            end
            tickets << singleticket(
                @params.merge(name: "#{@basename}.#{type}")) 
            end
        end
        raise NotFound, "#{@basename} not found" if tickets.empty?
        { total: tickets.length, name: @basename, results: tickets }
    end

    def singleticket params
        ticket = Ticket.new(params)
        { jwt: ticket.jwt, context: ticket.to_hash }
    end

    def getticket
        if @check
            checktickets
        else
            singleticket @params
        end
    end
end
