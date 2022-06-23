require_relative 'spec_helper'
require_relative '../mts'

MtsConfig = YAML.load <<EOF
---
wildcard: superorg
subjectheader: HTTP_X_SSL_SUBJECT
EOF

default_max_age = Mts::MAXAGE_DEFAULT

RSpec.describe Mts do
    let (:params) { {app: 'a',name: 'TEST_CP_NAME/n.mp4',client: 'c',verb: 'v'} }
    let (:ticket) { instance_spy('Ticket', jwt: 'jwtok', to_hash: params) }
    let (:app) do
        Mts.configure MtsConfig
    end
    before :each do
        # Mock Ticket class
        allow(Ticket).to receive :secrets=
        allow(Ticket).to receive(:new) {ticket}
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
        xcontext 'when initialization fails' do
            before :each do
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
                    request '/' , params: params.merge(name: 'TEST_CP_NAME/a', app: 'p')
                end
                it_behaves_like 'valid request'
            end
            xcontext 'Content from other org is forbidden' do
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
        end
    end
end
