require 'json'
require 'uri'
require 'net/http'
require 'net/https'

class AxonOps
  CLOUD_URL = 'https://dash.axonops.cloud'

  attr_reader :org_name, :auth_token, :api_token, :username, :password, 
              :cluster_type, :base_url, :jwt, :integrations_output, :errors

  def initialize(org_name: '', auth_token: '', base_url: '', username: '',
                 password: '', cluster_type: 'cassandra', api_token: '',
                 override_saas: false)
    @org_name = org_name.empty? ? (ENV['AXONOPS_ORG'] || '') : nil
    @auth_token = auth_token.empty? ? (ENV['AXONOPS_TOKEN'] || '') : auth_token
    @base_url = base_url.empty? ? (ENV['AXONOPS_URL'] || '') : base_url
    @api_token = api_token.empty? ? (ENV['AXONOPS_API_TOKEN'] || '') : api_token
    @username = username.empty? ? (ENV['AXONOPS_USERNAME'] || '') : username
    @password = password.empty? ? (ENV['AXONOPS_PASSWORD'] || '') : password
    @cluster_type = cluster_type || ENV['AXONOPS_CLUSTER_TYPE'] || 'cassandra'
    @jwt = ''

    # save the integration output to a var so we can use it multiple times
    @integrations_output = {}

    # collect the errors, will check it on every module
    @errors = []

    Chef::Log.info("Initializing AxonOps client for org: #{@org_name}, cluster type: #{@cluster_type}")
    Chef::Log.debug("Base URL: #{@base_url}, Auth Token: #{@auth_token}, Username: #{@username}")
    # set the base url
    if !@base_url.empty?
      # if saas is overridden, the url will always be treated as saas
      if override_saas
        @base_url = base_url.chomp('/') + '/' + org_name
      else
        # if saas is not overridden, it is treated as on-prem
        @base_url = base_url.chomp('/')
      end
    else
      # if nothing is specified, it is AxonOps Cloud
      @base_url = CLOUD_URL + '/' + @org_name
    end

    # if you have a username and password, it will be used for the login
    if !@username.empty? && !@password.empty?
      @jwt = get_jwt
    end
  end

  def get_cluster_type
    """
    getter for cluster_type
    """
    @cluster_type
  end

  def get_jwt
    """
    Get the JWT from the login endpoint
    """
    Chef::Log.debug("Getting JWT for #{@username} on #{@base_url}/api/login")
    # if you have it already, use it
    return @jwt unless @jwt.empty?

    json_data = {
      'username' => @username,
      'password' => @password
    }

    Chef::Log.info("Getting JWT for #{@username} on #{@base_url}/api/login")
    result, return_error = do_request('/api/login', json_data: json_data, method: 'POST')

    if return_error
      Chef::Log.error("Failed to get JWT: #{return_error}")
      @errors << return_error
    end

    if !result || !result.key?('token')
      @errors << "#{@base_url}/api/login returned an invalid result #{result} #{return_error}"
      Chef::Log.error(@errors.last)
      return nil
    end

    @jwt = result['token']
    @jwt
  end

  def dash_url
    @base_url
  end

  def do_request(rel_url, method: 'GET', ok_codes: [200, 201, 204], 
                 data: nil, json_data: nil, form_field: '')
    """
    Perform a request to AxonOps and return the response or an error
    """
    # bearer empty is for anonymous
    bearer = ''
    api_token = ''

    # if we have auth_token, use it
    bearer = @auth_token unless @auth_token.empty?

    # if we have an api token for on prem axonserver instances
    api_token = @api_token unless @api_token.empty?

    # if we have jwt, use it
    bearer = @jwt if @jwt && !@jwt.empty?

    full_url = @base_url + '/' + rel_url.sub(/^\//, '')

    if data.nil? && !json_data.nil?
      data = json_data.to_json
    end

    headers = {
      'Accept' => 'application/json',
      'User-agent' => 'AxonOps Ruby Client'
    }

    headers['Authorization'] = "Bearer #{bearer}" unless bearer.empty?
    headers['Authorization'] = "AxonApi #{api_token}" unless api_token.empty?

    if !form_field.empty?
      headers['Content-type'] = 'application/x-www-form-urlencoded'
      data = "#{form_field}=#{URI.encode_www_form_component(data)}"
    elsif !data.nil?
      headers['Content-type'] = 'application/json'
    end

    begin
      uri = URI(full_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      #http.set_debug_output($stderr)

      case method.upcase
      when 'GET'
        request = Net::HTTP::Get.new(uri.request_uri)
      when 'POST'
        request = Net::HTTP::Post.new(uri.request_uri)
        request.body = data if data
      when 'PUT'
        request = Net::HTTP::Put.new(uri.request_uri)
        request.body = data if data
      when 'DELETE'
        request = Net::HTTP::Delete.new(uri.request_uri)
      else
        return nil, "Unsupported HTTP method: #{method}"
      end

      headers.each { |key, value| request[key] = value }

      response = http.request(request)

      unless ok_codes.include?(response.code.to_i)
        Chef::Log.debug("Response from #{full_url}: #{response.code} #{response.message}: #{response.body}")
        return nil, "#{full_url} return code is #{response.code}: #{response.body}"
      end

      content = response.body

    rescue => e
      Chef::Log.debug("Error during HTTP request: #{e.message} #{full_url}")
      return nil, "#{e.message} #{full_url}"
    end

    # Not all requests return a response so ignore json decoding errors
    if content.nil? || content.empty?
      Chef::Log.debug("No content returned from #{full_url}")
      return nil, nil
    end
    begin
      return JSON.parse(content), nil
    rescue JSON::ParserError
      return nil, nil
    end
  end

  def get_integration_output(cluster)
    """
    get the integration output from local variable if present, or from API
    """
    # if we don't have already the integration API output, call the API
    unless @integrations_output.key?(cluster)
      integrations, error = do_request("/api/v1/integrations/#{@org_name}/#{get_cluster_type}/#{cluster}")
      return nil, error if error

      # save the integration output for the next time
      @integrations_output[cluster] = integrations
    end

    [@integrations_output[cluster], nil]
  end

  def find_integration_by_name_and_type(cluster, integration_type, name)
    """
    get the integration by the name and type
    """
    # Get the list of current integrations
    integrations, error = get_integration_output(cluster)
    return nil, error if error

    definitions = integrations.key?('Definitions') ? integrations['Definitions'] : []

    # Check if the named integration already exists
    if definitions
      definitions.each do |definition|
        if definition.key?('Type') && definition.key?('Params') && 
           definition['Params'].key?('name') &&
           definition['Type'] == integration_type && 
           definition['Params']['name'] == name
          return definition, nil
        end
      end
    end

    [nil, nil]
  end

  def find_integration_id_by_name(cluster, name)
    """
    get the integration by the name
    """
    # Get the list of current integrations
    integrations, error = get_integration_output(cluster)
    return nil, error if error

    definitions = integrations.key?('Definitions') ? integrations['Definitions'] : []

    # Check if the named integration already exists
    if definitions
      definitions.each do |definition|
        if definition.key?('Params') && definition['Params'].key?('name') &&
           definition['Params']['name'] == name
          return definition['ID'], nil
        end
      end
    end

    [nil, nil]
  end

  def find_integration_name_by_id(cluster, integration_id)
    """
    get the integration by the ID
    """
    # Get the list of current integrations
    integrations, error = get_integration_output(cluster)
    return nil, error if error

    definitions = integrations.key?('Definitions') ? integrations['Definitions'] : []

    # find the definition
    if definitions
      definitions.each do |definition|
        if definition['ID'] == integration_id
          return definition['Params']['name'], nil
        end
      end
    end

    [nil, nil]
  end

  def find_nodes_ids(nodes, org, cluster)
    nodes_returned, error = do_request("api/v1/nodes/#{org}/#{get_cluster_type}/#{cluster}")
    return nil, error if error

    list_of_ids = []

    nodes.each do |node|
      nodes_returned.each do |node_returned|
        details = node_returned['Details']
        if node == details['human_readable_identifier'] || node == node_returned['HostIP']
          list_of_ids << node_returned['host_id']
          break
        end
      end
    end

    [list_of_ids, nil]
  end
end