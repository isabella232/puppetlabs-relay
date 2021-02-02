require 'spec_acceptance_helper'

describe 'Relay reporting' do
  let(:params) do
    # Rubocop says this is a useless assignment
    # relay_config = bolt_config['remote']

    {
      reports_url: 'https://api.stage.relay-infra.net/api/events',
      access_token: ENV['RELAY_ACCESS_TOKEN'],
    }
  end
  let(:setup_manifest) do
    to_manifest(declare('Service', 'pe-puppetserver'), declare('class', 'relay::reporting', params))
  end

  include_context 'reporting test setup'

  it 'sends a node_report event' do
    set_sitepp_content(declare('notify', 'foo'))
    trigger_puppet_run(master, acceptable_exit_codes: [2])
    event = Helpers.get_single_record('em_event', query)
    expect(event['source']).to eql('Puppet')
    expect(event['type']).to eql('node_report_changed')
    expect(event['severity']).to eql('1')
    expect(event['message_key']).not_to be_empty
    expect(event['node']).not_to be_empty
    expect(event['event_class']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
    expect(event['description']).to match(%r{Resource Statuses:})
    expect(event['description']).to match(%r{Notify\[foo\]\/message: defined 'message' as 'foo'})
    expect(event['description']).to match(%r{manifests\/site.pp:2})
    expect(event['description']).to match(%r{== Facts ==})
    expect(event['description']).to match(%r{id: root})
    expect(event['description']).to match(%r{os.distro:\s+codename:[\s\S]*description})
    expect(event['additional_information']).to match(%r{"facts"})
    expect(event['additional_information']).to match(%r{"chassistype": "Other"})
    expect(event['additional_information']).to match(%r{"manufacturer": "VMware, Inc."})
    expect(event['additional_information']).to match(%r{"domain": "delivery.puppetlabs.net"})
    expect(event['additional_information']).to match(%r{"kernel": "Linux"})
    # Check that the PE console URL is included
    expect(event['description']).to match(Regexp.new(Regexp.escape(master.uri)))
  end
end
