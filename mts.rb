require 'json'
require 'yaml'
require 'rack'
require_relative 'lib/ticket'

class Mts

    MAXAGE_DEFAULT = 14400 # default TTL of the tickets

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
            self
        end

        def call env
            request = new env
            if request.authorized?
                set_response request.getticket
            else
                set_response "unauthorized", 403
            end
        rescue => e
            code = e.is_a?(TicketArgumentError) ? 400 : 500
            set_response e.message, code
        end

        def set_response body, status=200
            response = Rack::Response.new([], status)
            body = { error: body, status: status } unless response.successful?
            response.write body.to_json if body
            response.set_header('Content-Type', 'application/json')
            response.finish
        end

    end

    def initialize env
        request = Rack::Request.new env

        subject = request.get_header(@@subjectheader)
        fail TicketArgumentError, 'certificate missing' unless subject

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
        fail TicketArgumentError, 'subject must have O' if @allowed_tenants.empty?
        @params[:app] ||= @allowed_tenants&.first
        @params[:maxage] ||= @@maxage
    end

    def name
        @params[:name]
    end

    def prefix
        name[%r{([^/]+)/},1]
    end

    def authorized?
        tenantname = prefix
        return false unless tenantname
        @allowed_tenants.include? @@tenants[tenantname]
    end

    def getticket
        ticket = Ticket.new(@params)
        { jwt: ticket.jwt, context: ticket.to_hash }
    end
end
