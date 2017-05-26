require 'json'
require 'yaml'
require 'rack'
require_relative 'lib/ticket'

class Vts

    class << self

        def configure config
            Ticket.secrets = config['appsecrets']
            Ticket.seed = config['appseed']
            @@tenants = config["oridmap"]
            self
        end

        def call env
            request = self.new env
            return respond "unauthorized", 403 unless request.authorized?
            request.getticket
        rescue => e
            code = e.is_a?(TicketArgumentError) ? 400 : 500
            respond e.message, code
        end

        def respond body, status=200
            response = Rack::Response.new([], status)
            body = { error: body, status: status } unless response.successful?
            response.write body.to_json if body
            response.set_header('Content-Type', 'application/json')
            response.finish
        end

    end

    def respond *args
        self.class.respond *args
    end

    def initialize env
        request = Rack::Request.new env
        
        subject = request.get_header('HTTP_X_SSL_SUBJECT')
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

        @allowed_tenants = subject&.scan(%r{\bo=(\w+)})&.flatten! 
        @params[:app] ||= @allowed_tenants&.first
    end

    def name
        @params[:name]
    end

    def prefix
        name[%r{(\w+)/},1]
    end

    def authorized?
        tenantname = prefix
        return false unless tenantname
        @allowed_tenants.include? @@tenants[tenantname]
    end

    def getticket
        ticket = Ticket.new(@params)
        response = { jwt: ticket.jwt, context: ticket.to_hash }
        respond response
    end
end
