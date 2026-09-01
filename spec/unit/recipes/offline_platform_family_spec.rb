#!/usr/bin/env ruby
#
# Pure-Ruby source-level spec (no ChefSpec/Berkshelf needed) asserting that
# every offline_install branch handles the `amazon` platform_family.
#
# Amazon Linux 2/2023 report platform_family 'amazon', not 'rhel'. A `case`
# statement that only matches 'rhel'/'fedora' declares no install resource at
# all on those hosts, so the converge succeeds while installing nothing.

require 'pathname'

RECIPES_DIR = Pathname.new(__dir__).join('..', '..', '..', 'recipes')

RSpec.describe 'offline install platform_family coverage' do
  {
    'server.rb' => 'axon-server',
    'dashboard.rb' => 'axon-dash',
    'agent.rb' => 'axon-agent',
    'opensearch.rb' => 'opensearch',
  }.each do |recipe, component|
    context recipe do
      let(:source) { RECIPES_DIR.join(recipe).read }

      # Every platform_family dispatch line that names an RPM family: the
      # `when` clauses of the offline `case node['platform_family']` and any
      # `platform_family?(...)` guard. All of them must also name 'amazon'.
      let(:rpm_dispatch_lines) do
        source.lines.map(&:strip).select { |l| l.match?(/'rhel'|'fedora'/) }
      end

      it "matches the amazon platform_family wherever rhel is matched (#{component})" do
        expect(rpm_dispatch_lines).not_to be_empty
        rpm_dispatch_lines.each do |line|
          expect(line).to include("'amazon'"),
                          "#{recipe}: `#{line}` does not match Amazon Linux"
        end
      end

      it 'fails loudly on an unhandled platform_family instead of skipping' do
        expect(source).to match(/AxonOpsOffline\.unsupported_platform!/),
                          "#{recipe}: unhandled platform_family silently installs nothing"
      end
    end
  end
end
