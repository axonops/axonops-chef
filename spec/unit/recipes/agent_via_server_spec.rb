#!/usr/bin/env ruby
require 'spec_helper'

# axonops::server installs its own metrics-storage Cassandra through a
# *nested* include_recipe 'axonops::cassandra' (recipes/server.rb), which
# never shows up in node.run_list — only the literal 'recipe[axonops::server]'
# entry does. axonops::agent's java_agent_package selection originally only
# recognised a literal 'recipe[axonops::cassandra]' run_list entry (plus a
# converge-time-only cassandra_detected, always false during this compile-only
# ChefSpec run — see spec/unit/recipes/dse_detection_spec.rb's note), so a
# node whose run_list was just [..., 'recipe[axonops::server]', ...] fell
# through to "Could not detect Cassandra or Kafka" and never installed the
# java agent — Cassandra then started without it (issue: examples/nodes/
# axon-server-ldap-node.json, "Error opening zip file ... agent-jdk17.jar").
describe 'axonops::server' do
  let(:chef_run) do
    ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.override['axonops']['agent']['org_key'] = 'test-org-key'
      node.override['axonops']['agent']['org_name'] = 'test-org'
      node.override['axonops']['server']['org_name'] = 'test-org'
      node.override['axonops']['server']['cassandra']['install'] = true
      node.override['axonops']['server']['elastic']['install'] = false
    end
  end

  before do
    allow(::File).to receive(:exist?).and_return(false)
    allow(::Dir).to receive(:glob).and_return([])
  end

  it 'installs the Cassandra java agent package even though axonops::cassandra is never in run_list' do
    chef_run.converge(described_recipe)
    expect(chef_run.node.run_list.map(&:to_s)).not_to include('recipe[axonops::cassandra]')
    expect(chef_run).to install_package('axon-cassandra5.0-agent-jdk17')
  end
end
