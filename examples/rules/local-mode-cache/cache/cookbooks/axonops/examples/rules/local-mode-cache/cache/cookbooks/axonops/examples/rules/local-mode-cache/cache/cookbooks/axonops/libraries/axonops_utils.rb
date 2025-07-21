require 'chef/mixin/deep_merge'
require 'net/http'
require 'uri'
require 'json'
require 'cgi'


module AxonOpsUtils
  
  # Chef-style property definitions for AxonOps resources
  def self.base_properties
    {
      base_url: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_URL'] }
      },
      org: {
        kind_of: String,
        required: true,
        default: lazy { ENV['AXONOPS_ORG'] }
      },
      cluster: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_CLUSTER'] }
      },
      auth_token: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_TOKEN'] },
        sensitive: true
      },
      username: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_USERNAME'] }
      },
      password: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_PASSWORD'] },
        sensitive: true
      },
      cluster_type: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_CLUSTER_TYPE'] || 'cassandra' }
      },
      api_token: {
        kind_of: String,
        required: false,
        default: lazy { ENV['AXONOPS_API_TOKEN'] },
        sensitive: true
      },
      override_saas: {
        kind_of: [TrueClass, FalseClass],
        required: false,
        default: lazy { string_to_bool(ENV['AXONOPS_OVERRIDE_SAAS']) || false }
      }
    }
  end


  def do_request(rel_url, method: 'GET', ok_codes: [200, 201, 204], data: nil, json_data: nil, form_field: '')
    # Perform a GET request to AxonOps and return the response or an error
    
    # bearer empty is for anonymous
    bearer = ''
    # 
    api_token = ''
    
    # if we have auth_token, use it
    bearer = @auth_token if @auth_token
    
    # if we have an api token for on prem axonserver instances
    api_token = @api_token if @api_token
    
    # if we have jwt, use it
    bearer = @jwt if @jwt
    
    full_url = @base_url + '/' + rel_url.sub(/^\/+/, '')
    
    if data.nil? && !json_data.nil?
      data = JSON.generate(json_data)
    end
    
    headers = {
      'Accept' => 'application/json',
      'User-Agent' => 'AxonOps Chef Cookbook'
    }
    
    if !bearer.empty?
      headers['Authorization'] = "Bearer #{bearer}"
    end
    
    if !api_token.empty?
      headers['Authorization'] = "AxonApi #{api_token}"
    end
    
    if !form_field.empty?
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      data = "#{form_field}=#{CGI.escape(data)}"
    elsif !data.nil?
      headers['Content-Type'] = 'application/json'
    end
    
    begin
      uri = URI(full_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      
      # Create the request
      case method.upcase
      when 'GET'
        request = Net::HTTP::Get.new(uri)
      when 'POST'
        request = Net::HTTP::Post.new(uri)
        request.body = data if data
      when 'PUT'
        request = Net::HTTP::Put.new(uri)
        request.body = data if data
      when 'DELETE'
        request = Net::HTTP::Delete.new(uri)
      when 'PATCH'
        request = Net::HTTP::Patch.new(uri)
        request.body = data if data
      else
        return [nil, "Unsupported HTTP method: #{method}"]
      end
      
      # Set headers
      headers.each { |key, value| request[key] = value }
      
      # Make the request
      response = http.request(request)
      
      unless ok_codes.include?(response.code.to_i)
        return [nil, "#{full_url} return code is #{response.code}"]
      end
      
      content = response.body
      
    rescue => e
      return [nil, "#{e.message} #{full_url}"]
    end
    
    # Not all requests return a response so ignore json decoding errors
    begin
      return [JSON.parse(content), nil]
    rescue JSON::ParserError
      return [nil, nil]
    end
  end
  # END do_request
  # Helper method to merge base properties with resource-specific properties
  def self.make_properties(resource_properties = {})
    Chef::Mixin::DeepMerge.deep_merge(base_properties, resource_properties)
  end

  # Alternative method for getting configuration from environment or parameters
  def self.get_config(options = {})
    config = {}
    
    config[:base_url] = options[:base_url] || ENV['AXONOPS_URL']
    config[:org] = options[:org] || ENV['AXONOPS_ORG']
    config[:cluster] = options[:cluster] || ENV['AXONOPS_CLUSTER']
    config[:auth_token] = options[:auth_token] || ENV['AXONOPS_TOKEN']
    config[:username] = options[:username] || ENV['AXONOPS_USERNAME']
    config[:password] = options[:password] || ENV['AXONOPS_PASSWORD']
    config[:cluster_type] = options[:cluster_type] || ENV['AXONOPS_CLUSTER_TYPE'] || 'cassandra'
    config[:api_token] = options[:api_token] || ENV['AXONOPS_API_TOKEN']
    config[:override_saas] = options.key?(:override_saas) ? options[:override_saas] : 
                              string_to_bool(ENV['AXONOPS_OVERRIDE_SAAS']) || false

    # Validate required parameters
    raise ArgumentError, 'org parameter is required' if config[:org].nil? || config[:org].empty?

    config
  end

  # Check if two dictionaries are different
  def self.dicts_are_different(hash_a, hash_b)
    """
    Check if the hashes a and b are different
    """
    # check the keys
    return true if hash_a.keys.to_set != hash_b.keys.to_set

    # check the content of the keys
    hash_a.each do |key, value_a|
      value_b = hash_b[key]
      return true if value_a != value_b
    end

    false # Hashes are identical
  end

  # Find items in an array of hashes by searching a particular field for a value
  def self.find_by_field(hashes, field, value)
    """
    Find items in an array of hashes by searching a particular field for a value.
    - Returns nil if no matching items are found.
    - Returns a single item if only one match is found.
    - Returns an array of items if multiple matches are found.
    """
    return nil if hashes.nil?

    matches = hashes.select { |hash| hash[field] == value || hash[field.to_s] == value }

    case matches.length
    when 0
      nil
    when 1
      matches.first
    else
      matches
    end
  end

  # Convert string to boolean
  def self.string_to_bool(value)
    return false if value.nil?
    value.to_s.downcase.match?(/^(true|t|1|yes|y)$/)
  end

  # Convert boolean to string
  def self.bool_to_string(value)
    value ? 'true' : 'false'
  end

  # Convert string to nil if it represents null/none
  def self.string_or_none(value)
    return nil if value.nil?
    return nil if value.to_s.downcase.match?(/^(none|null)$/)
    value
  end

  # Recursively normalize numbers and arrays in a hash for consistent comparison
  def self.normalize_numbers(data)
    """
    Recursively normalizes numbers and arrays in a hash:
    - Converts all integers and floats to floats to ensure consistent comparison.
    - Sorts arrays for consistent comparison, unless they contain hashes.
    """
    case data
    when Hash
      data.transform_values { |value| normalize_numbers(value) }
    when Array
      # Only sort the array if it contains non-hash elements
      if data.all? { |item| item.is_a?(Numeric) || item.is_a?(String) }
        data.map { |item| normalize_numbers(item) }.sort
      else
        data.map { |item| normalize_numbers(item) }
      end
    when Integer, Float
      data.to_f # Convert all numbers to floats
    when String
      data.strip # Handle strings by stripping whitespace
    else
      data
    end
  end

  # Function to get the ID by name from integration definitions
  def self.get_integration_id_by_name(data, target_name)
    definitions = data['Definitions'] || data[:Definitions] || []

    definitions.each do |definition|
      params = definition['Params'] || definition[:Params] || {}
      name = params['name'] || params[:name]
      if name == target_name
        return definition['ID'] || definition[:ID]
      end
    end

    nil
  end

  # Search in a Value/Name hash structure
  def self.get_value_by_name(checked_filters, filter_name)
    """
    search in a Value / Name hash structure
    """
    return nil if checked_filters.nil?

    checked_filters.each do |checked_filter|
      name = checked_filter['Name'] || checked_filter[:Name]
      if name == filter_name
        return checked_filter['Value'] || checked_filter[:Value]
      end
    end

    nil
  end

  # Chef-specific helper to validate required properties
  def self.validate_required_properties(new_resource)
    raise ArgumentError, 'org property is required' if new_resource.org.nil? || new_resource.org.empty?
  end

  # Helper method to extract AxonOps configuration from a Chef resource
  def self.extract_axonops_config(new_resource)
    {
      org_name: new_resource.org,
      auth_token: new_resource.auth_token || '',
      base_url: new_resource.base_url || '',
      username: new_resource.username || '',
      password: new_resource.password || '',
      cluster_type: new_resource.cluster_type || 'cassandra',
      api_token: new_resource.api_token || '',
      override_saas: new_resource.override_saas || false
    }
  end

  # Helper method for Chef resources to create AxonOps client
  def self.create_axonops_client(new_resource)
    validate_required_properties(new_resource)
    config = extract_axonops_config(new_resource)
    AxonOps.new(**config)
  end
end

# Chef-specific mixin for resources that need AxonOps functionality
module AxonOpsMixin
  def axonops_client
    @axonops_client ||= AxonOpsUtils.create_axonops_client(new_resource)
  end

  def with_error_handling
    yield
  rescue => e
    Chef::Log.error("AxonOps operation failed: #{e.message}")
    raise e
  end
end