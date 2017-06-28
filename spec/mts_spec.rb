require_relative 'spec_helper'
require_relative '../mts'

MtsConfig = YAML.load <<EOF
---
oridmap:
    p: org1
subjectheader: 'HTTP_X_SSL_SUBJECT'
EOF

MaxageConfig = YAML.load <<EOF
---
maxage: 28800
EOF

describe Mts do

    let (:params) { {app: 'a',name: 'p/n',useragent: 'u',client: 'c',verb: 'v'} }
    let (:ticket) { instance_double('Ticket', jwt: 'jwtok', to_hash: params) }
    let (:maxage) { {maxage: 14400} }
    before :each do
        allow(Ticket).to receive(:new) {ticket}
    end
    shared_examples 'valid request' do
        it { expect(Ticket).to have_received(:new).with(params.merge maxage) }
        it { expect(last_response.status).to eq 200 }
        context 'response body' do
            subject { JSON.parse last_response.body, symbolize_names: true }
            it { is_expected.to include(jwt: 'jwtok') }
            it { is_expected.to include(context: params) }
        end
    end

    context 'without subject header header' do
        let (:app) do
            Mts.configure MtsConfig
        end
        before :each do
            request '/' , params: params
        end
        subject {last_response }
        it { expect(subject.status).to eq 400 }
        it { expect(subject.body).to include 'certificate missing' }
        context 'response body' do
            subject { JSON.parse last_response.body, symbolize_names: true }
            it { is_expected.to include(status: 400) }
            #it { is_expected.to include(message: cert) }
        end
    end
    context 'with subject header header' do
        before :each do
            header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=org1,O=org2,DC=jwt'
        end
        context "maxage in config overrides default" do
            let (:maxage) { {maxage: 28800} } #maxage is used in shared example
            let (:app) do
                Mts.configure MtsConfig.merge(MaxageConfig)
            end
            before :each do
                env :input, params.to_json 
                request '/' 
            end
            it_behaves_like 'valid request'
        end
        context "with default maxage" do
            let (:app) do
                Mts.configure MtsConfig
            end
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
                let (:maxage) { {maxage: 28800} } #maxage is used in shared example
                before :each do
                    env :input, params.merge(maxage).to_json 
                    request '/' 
                end
                it_behaves_like 'valid request'
            end
            context 'body parameters override url parameters' do
                before :each do
                    env :input, params.to_json 
                    request '/' , params: params.merge(name: 'p/a', app: 'p', useragent: 's')
                end
                it_behaves_like 'valid request'
            end
            context 'with name in the url parameters' do
                context 'name in url only' do
                    before :each do
                        params_without_name = params.dup
                        params_without_name.delete(:name)
                        request '/p/n', params: params_without_name
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
                    header 'X-SSL-SUBJECT', 'emailAddress=inf@exaple.org,O=a,O=org1,DC=jwt'
                    params_without_app = params.dup
                    params_without_app.delete(:app)
                    request '/', params: params_without_app
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject ends with o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'DC=jwt,O=org1'
                    request '/', params: params
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject starts with o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'O=org1,DC=jwt'
                    request '/', params: params
                end
                it_behaves_like 'valid request'
            end
            context 'x-ssl-subject has no o' do
                before :each do
                    header 'X-SSL-SUBJECT', 'OU=org1,DC=jwt'
                    request '/', params: params
                end
                subject {last_response }
                it { expect(subject.status).to eq 400 }
                it { expect(subject.body).to include ' O' }
                context 'response body' do
                    subject { JSON.parse last_response.body, symbolize_names: true }
                    it { is_expected.to include(status: 400) }
                    #it { is_expected.to include(message: cert) }
                end
            end
        end
    end
end
