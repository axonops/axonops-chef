#
# Cookbook:: axonops
# Recipe:: default
#
# Copyright:: 2024, AxonOps
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This is the default recipe that does nothing by itself
# Users should explicitly include the recipes they need:
#
# include_recipe 'axonops::agent'        # Install AxonOps agent
# include_recipe 'axonops::server'       # Install AxonOps server (self-hosted)
# include_recipe 'axonops::configure'    # Configure via API
# include_recipe 'axonops::cassandra'    # Install Apache Cassandra 5.0

Chef::Log.info('AxonOps cookbook loaded. Please include specific recipes for the components you need.')
Chef::Log.info('See the README for usage examples.')
