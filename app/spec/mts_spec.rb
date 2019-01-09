require_relative 'spec_helper'
require_relative '../mts'

MtsConfig = YAML.load <<EOF
---
wildcard: superorg
subjectheader: HTTP_X_SSL_SUBJECT
organizations_api: http://api.example.org
backend: backend.example.org
buckets:
  mp4: 'viaa'
  m3u8: 'fragments'
EOF

default_max_age = Mts::MAXAGE_DEFAULT

RSpec.describe Mts do
    let (:params) { {app: 'a',name: 'TEST_CP_NAME/n.mp4',useragent: 'u',client: 'c',verb: 'v'} }
    let (:ticket) { instance_spy('Ticket', jwt: 'jwtok', to_hash: params) }
    let (:app) do
        Mts.configure MtsConfig
    end
    before :each do
        # Mock Ticket class
        allow(Ticket).to receive :secrets=
        allow(Ticket).to receive(:new) {ticket}
        allow(Organizations).to receive(:new).and_return( { 'TEST_CP_NAME' => 'test_cp_id', 'TVOOSTWEST' => 'OR-w66976m' })
    end
    shared_examples 'valid request' do |maxage|
        it { expect(Ticket).to have_received(:new)
            .with(params.merge({maxage: maxage || default_max_age})) }
        it { expect(last_response.status).to eq 200 }
        context 'response body' do
            subject { JSON.parse last_response.body, symbolize_names: true }
            it { is_expected.to be_a Hash }
            it { is_expected.to include(jwt: 'jwtok') }
            it { is_expected.to include(context: params) }
        end
    end

    context ':healthcheck' do
        let (:app) do
            lambda { |env| Mts.healthcheck }
        end
        subject { last_response.status }
        context 'when not initialized' do
            before :each do
                request '/'
            end
            it { is_expected.to be 500 }
        end
        context 'when initialized' do
            before :each do
                Mts.configure MtsConfig #.merge(b: 'p')
                request '/'
            end
            it { is_expected.to be 200 }
        end
        context 'when initialization fails' do
            before :each do
                allow(Organizations).to receive(:new).and_return({})
                Mts.configure MtsConfig
                request '/'
            end
            it { is_expected.to be 500 }
        end
    end

    context 'application initialization' do
        before :each do
            app
        end
        it do
            expect(Ticket).to have_received(:secrets=)
        end
        it do
            expect(Organizations).to have_received(:new).with("http://api.example.org")
        end
    end
    context 'without subject header header' do
        before :each do
            request '/' , params: params
        end
        subject {last_response }
        it { expect(subject.status).to eq 400 }
        it { expect(subject.body).to include 'certificate missing' }
        context 'response body' do
            subject { JSON.parse last_response.body, symbolize_names: true }
            it { is_expected.to include(status: 400) }
            it { is_expected.to include(error: 'certificate missing') }
        end
    end
    context 'with subject header header' do
        before :each do
            header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=test_cp_id,O=org2,DC=jwt'
        end
        context "maxage in config overrides default" do
            let (:app) do
                Mts.configure MtsConfig.merge({"maxage" => default_max_age * 2})
            end
            before :each do
                env :input, params.to_json
                request '/'
            end
            it_behaves_like 'valid request', default_max_age * 2
        end
        context "with default maxage" do
            context 'with url parameters' do
                before :each do
                    request '/' , params: params
                end
                it_behaves_like 'valid request'
            end
            context 'with body parameters' do
                before :each do
                    env :input, params.to_json
                    request '/'
                end
                it_behaves_like 'valid request'
            end
            context 'maxage parameter overides default' do
                before :each do
                    env :input, params.merge(maxage: 28800).to_json
                    request '/'
                end
                it_behaves_like 'valid request', 28800
            end
            context 'body parameters override url parameters' do
                before :each do
                    env :input, params.to_json
                    request '/' , params: params.merge(name: 'TEST_CP_NAME/a', app: 'p', useragent: 's')
                end
                it_behaves_like 'valid request'
            end
            context 'Content from other org is forbidden' do
                before :each do
                    params_without_name = params.dup
                    params_without_name.delete(:name)
                    request '/r/n.mp4', params: params_without_name
                end
                subject { last_response }
                it { is_expected.to be_forbidden }
            end
            context 'Superorg has access to all content' do
                before :each do
                    header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=superorg,DC=jwt'
                    request '/' , params: params
                end
                subject { last_response }
                it_behaves_like 'valid request'
            end
            context 'Superorg has access to all content' do
                before :each do
                    header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=superorg,O=org2,DC=jwt'
                    request '/' , params: params
                end
                subject { last_response }
                it_behaves_like 'valid request'
            end
            context 'with name in the url parameters' do
                context 'name in url only' do
                    before :each do
                        params_without_name = params.dup
                        params_without_name.delete(:name)
                        request '/TEST_CP_NAME/n.mp4', params: params_without_name
                    end
                    it_behaves_like 'valid request'
                end
                context 'name in body overrides url' do
                    before :each do
                        env :input, params.to_json
                        request '/a'
                    end
                    it_behaves_like 'valid request'
                end
            end
            context 'app is taken from x-ssl-subject' do
                before :each do
                    header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=a,O=test_cp_id,DC=jwt'
                    params_without_app = params.dup
                    params_without_app.delete(:app)
                    request '/', params: params_without_app
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject ends with o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'DC=jwt,O=test_cp_id'
                    request '/', params: params
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject starts with o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'O=test_cp_id,DC=jwt'
                    request '/', params: params
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject has no o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'OU=test_cp_id,DC=jwt'
                    request '/', params: params
                end
                subject {last_response }
                it { expect(subject.status).to eq 400 }
                it { expect(subject.body).to include ' O' }
                context 'response body' do
                    subject { JSON.parse last_response.body, symbolize_names: true }
                    it { is_expected.to include(status: 400) }
                    it { is_expected.to include(error: 'subject must have O') }
                end
            end
            context 'with format: false' do
                before :each do
                    env :input, params.merge(format: false).to_json
                    request '/'
                end
                it_behaves_like 'valid request'
            end
            [ 'm3u8', ['m3u8'], ['m3u8', 'mp4'], ['mp4', 'm3u8'], ['mp4', 'm3u8', 'webm'], true ].each do |format|
                context "with format: #{format}" do
                    let (:params2) { params.merge(name: 'TEST_CP_NAME/n.m3u8') }
                    let (:ticket2) { instance_double('Ticket', jwt: 'jwtok2', to_hash: params2) }
                    let (:mp4_age) { true }
                    let (:ts_age) { true }
                    let (:m3u8_age) { true }
                    before :each do
                        allow(SwarmBucket).to receive(:present?) do |uri|
                            case uri.to_s
                            when /backend.example.org\/viaa\/.*mp4$/
                                mp4_age
                            when /backend.example.org\/fragments\/.*ts.1$/
                                ts_age
                            when /backend.example.org\/fragments\/.*m3u8$/
                                m3u8_age
                            else
                                nil
                            end
                        end
                        allow(Ticket).to receive(:new) do |params|
                            case params[:name]
                            when /mp4$/ then ticket
                            else ticket2
                            end
                        end
                        env :input, params.merge(format: format).to_json
                        request '/'
                    end
                    subject { JSON.parse last_response.body, symbolize_names: true }
                    it { is_expected.to be_a Hash }
                    context 'when mp4 and m3u8 exist' do
                        let (:mp4_age) { true }
                        let (:m3u8_age) { 14401 }
                        let (:ts_age) { 14401 }
                        it 'requests two tickets' do
                            expect(Ticket).to have_received(:new)
                                .with(params.merge({maxage: default_max_age}))
                            expect(Ticket).to have_received(:new)
                                .with(params2.merge({maxage: default_max_age}))
                        end
                        context 'response body' do
                            it { expect(last_response.status).to eq 200 }
                            it { is_expected.to include(name: 'TEST_CP_NAME/n') }
                            it { is_expected.to include(total: 2) }
                            it { is_expected.to include(:results) }
                            it { expect(subject[:results].length).to eq 2 }
                            it { expect(subject[:results])
                                .to include({jwt:'jwtok'}.merge params) }
                            it { expect(subject[:results])
                                .to include({jwt:'jwtok2'}.merge params2) }
                            if format.is_a?(Array)
                                it { expect(subject[:results][0][:name])
                                    .to match %r{.#{format[0]}} }
                            end
                        end
                    end
                    3.times do |i|
                        context "when mp4 exists but m3u8 not #{i}" do
                            let (:m3u8_age) { 14400 + i/2 } # absent  absent  present
                            let (:ts_age) { 14400 + i%2 }   # absent  present absent
                            it 'requests two tickets' do
                                expect(Ticket).to have_received(:new)
                                    .with(params.merge({maxage: default_max_age}))
                                expect(Ticket).not_to have_received(:new)
                                    .with(params2.merge({maxage: default_max_age}))
                            end
                            context 'response body' do
                                it { expect(last_response.status).to eq 200 }
                                it { is_expected.to include(name: 'TEST_CP_NAME/n') }
                                it { is_expected.to include(total: 1) }
                                it { is_expected.to include(:results) }
                                it { expect(subject[:results].length).to eq 1 }
                                it { expect(subject[:results]).to include(
                                    {jwt:'jwtok'}.merge params
                                ) }
                                it { expect(subject[:results]).not_to include(
                                    {jwt:'jwtok2'}.merge params2
                                ) }
                            end
                        end
                    end
                    context "when mp4 nor m3u8 exists" do
                        let (:m3u8_age) { 14400 } # absent
                        let (:mp4_age) { 14400 }  # absent
                        let (:ts_age) { 14401 }
                        it { expect(Ticket).not_to have_received(:new) }
                        context 'response body' do
                            it { expect(last_response.status).to eq 404 }
                            it { is_expected.not_to include(:name) }
                            it { is_expected.not_to include(:total) }
                            it { is_expected.not_to include(:results) }
                            it { is_expected.to include(error: "TEST_CP_NAME/n not found") }
                        end
                    end
                    context "when m3u8 exists, but mp4 not" do
                        let (:m3u8_age) { 14401 } # present
                        let (:mp4_age) { 14400 }  # absent
                        let (:ts_age) { 14401 } # present
                        it 'requests two tickets' do
                            expect(Ticket).not_to have_received(:new)
                                .with(params.merge({maxage: default_max_age}))
                            expect(Ticket).to have_received(:new)
                                .with(params.merge({maxage: default_max_age})
                                .merge(name: 'TEST_CP_NAME/n.m3u8'))
                        end
                        context 'response body' do
                            it { expect(last_response.status).to eq 200 }
                            it { is_expected.to include(name: 'TEST_CP_NAME/n') }
                            it { is_expected.to include(total: 1) }
                            it { is_expected.to include(:results) }
                            it { expect(subject[:results].length).to eq 1 }
                            it { expect(subject[:results]).not_to include(
                                {jwt:'jwtok'}.merge params
                            ) }
                            it { expect(subject[:results]).to include(
                                {jwt:'jwtok2'}.merge params2
                            ) }
                        end
                    end
                end
            end
        end
    end
end
