require 'rack'
require_relative 'organizations'
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

        # Class configuration and class state data is stored in class instance
        # variables which are exposed via the attr_reader methods
        # This to avoid class variabels
        attr_reader :config, :organizations

        def configure config
            config = config.clone # clone the object because it will be changed
            # Delete secrets when no longer needed.
            Ticket.secrets = config.delete('appsecrets')
            Ticket.seed = config.delete('appseed')
            config['maxage'] ||= MAXAGE_DEFAULT
            @config = config
            @organizations = Organizations.new config["organizations_api"]
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

        def healthcheck
            if !organizations&.empty? && config['subjectheader']
                response2json 'OK', 200
            else
                response2json 'NOK', 500
            end
        rescue => e
            $stderr.puts e
            response2json 'NOK', 500
        end

        private

        def response2json body, status=200
            response = Rack::Response.new([], status)
            response.write body.to_json if body
            response.set_header('Content-Type', 'application/json')
            response.finish
        end

    end

    def initialize env
        @request = Rack::Request.new env
        @orgs_allowed = organizations_from_cert
        raise ArgumentError,
            'subject must have O' if @orgs_allowed.empty?
        @params = request_params
        $stderr.puts @params
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
        organization_name = prefix
        return false unless organization_name
        @orgs_allowed.include?(config['wildcard']) ||
            @orgs_allowed.include?(organizations[organization_name])
    end

    private

    def config
        self.class.config
    end

    def organizations
        self.class.organizations
    end

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
        puts @request.GET
        @request.GET.each_with_object({}) do |p,hash|
            hash[p[0].to_sym] = p[1][0,128]
        end
    end

    def request_params
        params = uri_params.merge body_params
        params[:app] ||= @orgs_allowed&.first
        params[:maxage] = params[:maxage]&.to_i || config['maxage']
        # If no name has been supplied, use path info as name
        params[:name] ||= @request.path_info[%r{/(.*)},1]
        params
    end

    def organizations_from_cert
        subject = @request.get_header(config['subjectheader'])
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
            bucket = config['buckets'][type] || config['buckets'][@type]
            ttl = check_types(type).each_with_object([]) do |sfx, tl|
                tl << SwarmBucket.present?(
                    URI "http://#{config['backend']}/#{bucket}/#{@basename}.#{sfx}"
                )
            end
            if ttl.all? { |tl| tl.is_a?(Integer) ? (tl&.> @params[:maxage]) : tl }
                ticket = Ticket.new( @params.merge(name: "#{@basename}.#{type}"))
                mytickets << { jwt: ticket.jwt }.merge(ticket.to_hash)
            end
        end
        raise NotFound, "#{@basename} not found" if tickets.empty?
        $stderr.puts tickets
        { total: tickets.length, name: @basename, results: tickets }
    end

    def formats
        raise ArgumentError, "unknown bucket #{@type}" unless config['buckets'].keys.include?(@type)
        formats = case @formats
                  when Array then @formats
                  when String then Array(@formats.split ',')
                  else config['buckets'].keys
                  end
        raise  ArgumentError, 'max 3 @formats elements' if formats.length > 3
        formats << @type unless formats.include?(@type)
        formats
    end

end
