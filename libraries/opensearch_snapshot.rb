#
# Cookbook:: axonops
# Library:: opensearch_snapshot
#
# Helpers for the S3/GCS snapshot repository support in recipes/opensearch.rb.
# Credentials only ever go into opensearch.keystore; the non-secret client
# settings are rendered into opensearch.yml.
#
# Pure Ruby (no Chef dependency) so it can be unit tested with plain rspec.
#
require 'digest'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module AxonOpsOpenSearchSnapshot
  TYPES = %w(s3 gcs).freeze
  PROTOCOLS = ['', 'http', 'https'].freeze
  CREDENTIAL_KEYS = %w(access_key secret_key session_token).freeze
  CREDENTIAL_SUFFIXES = %w(access_key secret_key session_token credentials_file).freeze

  # Deep merge of the 'elastic' and 'opensearch' snapshot attribute hashes,
  # 'opensearch' winning key by key, with the repository name defaulted.
  def self.config(base, override = {})
    cfg = deep_merge(stringify(base || {}), stringify(override || {}))
    cfg['repository_name'] = "#{cfg['type']}-snapshots" if cfg['repository_name'].to_s.empty?
    cfg
  end

  def self.enabled?(cfg)
    cfg['enabled'] == true
  end

  # Raises ArgumentError listing every invalid setting.
  def self.validate!(cfg)
    s3 = cfg['s3'] || {}
    extra = s3['extra_settings']
    policy = cfg['policy']
    errors = []
    errors << "type must be one of #{TYPES.join(', ')}" unless TYPES.include?(cfg['type'])
    errors << 'bucket must be set' if cfg['bucket'].to_s.empty?
    errors << 'client must contain only letters, digits, _ and -' unless cfg['client'].to_s.match?(/\A[A-Za-z0-9_-]+\z/)
    errors << 'repository_name must contain only a-z, 0-9, _, - and .' unless cfg['repository_name'].to_s.match?(/\A[a-z0-9_.-]+\z/)
    if s3['access_key'].to_s.empty? != s3['secret_key'].to_s.empty?
      errors << 's3.access_key and s3.secret_key must be set together'
    end
    if !s3['session_token'].to_s.empty? && s3['access_key'].to_s.empty?
      errors << 's3.session_token needs s3.access_key and s3.secret_key'
    end
    errors << "s3.protocol must be 'http' or 'https'" unless PROTOCOLS.include?(s3['protocol'].to_s)
    if !extra.nil? && !extra.is_a?(Hash)
      errors << 's3.extra_settings must be a hash'
    elsif extra
      errors << 's3.extra_settings keys must contain only a-z, 0-9 and _' unless extra.keys.all? { |k| k.to_s.match?(/\A[a-z0-9_]+\z/) }
      errors << 's3.extra_settings must not hold credentials' if (extra.keys.map(&:to_s) & CREDENTIAL_KEYS).any?
    end
    errors.concat(gcs_credentials_errors((cfg['gcs'] || {})['credentials_json'])) if cfg['type'] == 'gcs'
    if !policy.nil? && !policy.is_a?(Hash)
      errors << 'policy must be a hash'
    elsif policy && !policy.empty? && !policy['name'].to_s.match?(/\A[A-Za-z0-9_.-]+\z/)
      errors << 'policy needs a name containing only letters, digits, _, - and .'
    end
    raise ArgumentError, "Invalid OpenSearch snapshot settings: #{errors.join('; ')}" unless errors.empty?

    true
  end

  # The repository-gcs plugin reads the credentials at startup, so a malformed
  # service-account JSON stops OpenSearch from starting at all. The plugin
  # only accepts PKCS#8 keys, so a PKCS#1 "BEGIN RSA PRIVATE KEY" is rejected.
  GCS_CREDENTIAL_FIELDS = %w(client_id client_email private_key private_key_id).freeze

  def self.gcs_credentials_errors(json)
    return [] if json.nil? || json.to_s.empty?

    parsed = json.is_a?(Hash) ? stringify(json) : JSON.parse(json.to_s)
    return ['gcs.credentials_json must be a JSON object'] unless parsed.is_a?(Hash)

    missing = GCS_CREDENTIAL_FIELDS.reject { |k| parsed[k].is_a?(String) && !parsed[k].empty? }
    return ["gcs.credentials_json lacks #{missing.join(', ')}"] unless missing.empty?
    return ['gcs.credentials_json private_key is not a PKCS#8 PEM private key'] unless parsed['private_key'].include?('-----BEGIN PRIVATE KEY-----')

    []
  rescue JSON::ParserError
    ['gcs.credentials_json is not valid JSON']
  end

  # Non-secret client settings for opensearch.yml, as setting => value.
  def self.client_settings(cfg)
    prefix = "#{cfg['type']}.client.#{cfg['client']}"
    settings = {}
    case cfg['type']
    when 's3'
      s3 = cfg['s3'] || {}
      %w(region endpoint protocol).each do |key|
        settings["#{prefix}.#{key}"] = s3[key].to_s unless s3[key].to_s.empty?
      end
      settings["#{prefix}.path_style_access"] = s3['path_style_access'] == true
      (s3['extra_settings'] || {}).each { |key, value| settings["#{prefix}.#{key}"] = value }
    when 'gcs'
      gcs = cfg['gcs'] || {}
      %w(project_id endpoint).each do |key|
        settings["#{prefix}.#{key}"] = gcs[key].to_s unless gcs[key].to_s.empty?
      end
    end
    settings
  end

  # Keystore entries wanted for +cfg+. Empty when no static credentials are
  # set: the client then uses the instance identity (EC2 instance profile or
  # IRSA for S3, GCE/GKE workload identity for GCS).
  def self.keystore_entries(cfg)
    prefix = "#{cfg['type']}.client.#{cfg['client']}"
    entries = {}
    case cfg['type']
    when 's3'
      s3 = cfg['s3'] || {}
      unless s3['access_key'].to_s.empty?
        entries["#{prefix}.access_key"] = s3['access_key'].to_s
        entries["#{prefix}.secret_key"] = s3['secret_key'].to_s
        entries["#{prefix}.session_token"] = s3['session_token'].to_s unless s3['session_token'].to_s.empty?
      end
    when 'gcs'
      json = (cfg['gcs'] || {})['credentials_json']
      json = JSON.generate(json) if json.is_a?(Hash)
      entries["#{prefix}.credentials_file"] = json.to_s unless json.to_s.empty?
    end
    entries
  end

  # The keystore is re-encrypted on every write, so its checksum cannot show
  # whether the stored values match. A digest of the wanted entries is kept
  # next to it instead.
  def self.keystore_digest(entries)
    Digest::SHA256.hexdigest(JSON.generate(entries.sort.to_h))
  end

  # Marker kept next to the keystore: the digest of the wanted entries and the
  # entry names this cookbook wrote, so a later run only removes its own.
  def self.marker(entries)
    JSON.generate('digest' => keystore_digest(entries), 'keys' => entries.keys.sort)
  end

  def self.parse_marker(content)
    parsed = JSON.parse(content.to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  # Credential entries to remove: those this cookbook wrote before (a renamed
  # client, a switch between s3 and gcs, static credentials dropped for the
  # instance identity) and any credential of the configured client that is not
  # wanted now. Entries of other clients added by hand are left alone.
  def self.unwanted_entries(listed, entries, cfg, previous_keys = [])
    client_entries = %w(s3 gcs).product(CREDENTIAL_SUFFIXES).map { |t, k| "#{t}.client.#{cfg['client']}.#{k}" }
    (listed & (client_entries | Array(previous_keys))) - entries.keys
  end

  def self.keystore_in_sync?(listed, entries, cfg, marker_content)
    stored = parse_marker(marker_content)
    unwanted = unwanted_entries(listed, entries, cfg, stored['keys'])
    return unwanted.empty? if entries.empty?

    unwanted.empty? && (entries.keys - listed).empty? && stored['digest'] == keystore_digest(entries)
  end

  def self.repository_body(cfg)
    settings = { 'bucket' => cfg['bucket'], 'client' => cfg['client'] }
    settings['base_path'] = cfg['base_path'] unless cfg['base_path'].to_s.empty?
    { 'type' => cfg['type'], 'settings' => settings }
  end

  # Policy request body: every key of cfg['policy'] except 'name', with
  # snapshot_config.repository defaulted to the repository name.
  def self.policy_body(cfg)
    body = stringify(cfg['policy'] || {}).reject { |k, _| k == 'name' }
    deep_merge({ 'snapshot_config' => { 'repository' => cfg['repository_name'] } }, body)
  end

  # The stored policy carries extra server-side fields, so it only needs an
  # update when the requested body is not already a subset of it.
  def self.policy_in_sync?(current, body)
    deep_merge(current, body) == current
  end

  # Version from a plugin's plugin-descriptor.properties, or nil.
  def self.plugin_version(descriptor)
    return if descriptor.nil?

    descriptor[/^version=(.+)$/, 1]&.strip
  end

  class RetryableError < StandardError; end

  # Minimal client for the OpenSearch REST API on this node.
  class Client
    def initialize(base_url, username: nil, password: nil)
      @uri = URI(base_url)
      @username = username
      @password = password
    end

    # [status, parsed JSON body or nil]
    def request(method, path, body = nil)
      req = Net::HTTP.const_get(method.to_s.capitalize).new(path)
      req.basic_auth(@username, @password) if @username && !@username.to_s.empty?
      if body
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.open_timeout = 10
      http.read_timeout = 60
      if @uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      response = http.request(req)
      [response.code.to_i, parse_json(response.body)]
    end

    def parse_json(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      nil
    end

    def safe_request(method, path, body)
      request(method, path, body)
    rescue SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise RetryableError, "failed: #{e.class}: #{e.message}"
    end

    # Right after a start or restart the node answers before system indices
    # (the Snapshot Management config index among them) have shards, and those
    # calls fail with 500/503 for a few seconds. Connection errors and those
    # statuses are retried.
    RETRY_STATUSES = [500, 502, 503].freeze

    def request!(method, path, body = nil, ok: [200], retries: 12, delay: 5)
      attempt = 0
      begin
        attempt += 1
        status, parsed = safe_request(method, path, body)
        raise RetryableError, "returned #{status}: #{JSON.generate(parsed)}" if RETRY_STATUSES.include?(status) && !ok.include?(status)
      rescue RetryableError => e
        raise "OpenSearch #{method.to_s.upcase} #{@uri}#{path} #{e.message}" if attempt > retries

        sleep delay
        retry
      end
      hint = status == 401 ? ' (set search_db username and password when the security plugin is enabled)' : ''
      raise "OpenSearch #{method.to_s.upcase} #{path} returned #{status}#{hint}: #{JSON.generate(parsed)}" unless ok.include?(status)

      [status, parsed]
    end
  end

  def self.stringify(value)
    case value
    when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
    when Array then value.map { |v| stringify(v) }
    else value
    end
  end

  def self.deep_merge(base, override)
    base.merge(override) do |_, old, new|
      old.is_a?(Hash) && new.is_a?(Hash) ? deep_merge(old, new) : new
    end
  end
end
