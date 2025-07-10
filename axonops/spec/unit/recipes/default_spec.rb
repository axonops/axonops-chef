require 'spec_helper'

describe 'axonops::default' do
  include_context 'chef_run'
  
  let(:node_attributes) { {} }

  it 'includes the java recipe' do
    expect(chef_run).to include_recipe('axonops::java')
  end

  it 'includes the common recipe' do
    expect(chef_run).to include_recipe('axonops::common')
  end

  context 'when agent is enabled' do
    let(:node_attributes) do
      {
        'axonops' => {
          'agent' => {
            'enabled' => true
          }
        }
      }
    end

    it 'includes the agent recipe' do
      expect(chef_run).to include_recipe('axonops::agent')
    end
  end

  context 'when server is enabled' do
    let(:node_attributes) do
      {
        'axonops' => {
          'server' => {
            'enabled' => true
          }
        }
      }
    end

    it 'includes the server recipe' do
      expect(chef_run).to include_recipe('axonops::server')
    end
  end

  context 'when dashboard is enabled' do
    let(:node_attributes) do
      {
        'axonops' => {
          'dashboard' => {
            'enabled' => true
          }
        }
      }
    end

    it 'includes the dashboard recipe' do
      expect(chef_run).to include_recipe('axonops::dashboard')
    end
  end
end