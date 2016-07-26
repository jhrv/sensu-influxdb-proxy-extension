#!/usr/bin/env ruby

require 'net/http'
require 'json'

module Sensu::Extension
  class InfluxDBProxy < Handler

    @@extension_name = 'influxdb-proxy-extension'

    def name
      @@extension_name
    end

    def description
      'Forwards metrics to InfluxDB'
    end

    def run(event)
      begin
        if buffer_too_old? or buffer_too_big?
          flush_buffer
        end

        event = JSON.parse(event)
        output = event['check']['output']

        output.split(/\r\n|\n/).each do |point|
          @buffer.push(point)
          @logger.debug("#{@@extension_name}: stored point in buffer (#{@buffer.length}/#{@BUFFER_SIZE})")
        end
      rescue => e
        @logger.debug("#{@@extension_name}: unable to post payload to influxdb for event #{event} - #{e.backtrace.to_s}")
      end

      yield("#{@@extension_name}: handler finished", 0)
    end

    def post_init
      influxdb_config = settings[@@extension_name]
      validate_config(influxdb_config)
      
      hostname         = influxdb_config['hostname'] 
      port             = influxdb_config['port'] || 8086
      database         = influxdb_config['database']
      ssl              = influxdb_config['ssl'] || false
      precision        = influxdb_config['precision'] || 's'
      retention_policy = influxdb_config['retention_policy']
      rp_queryparam    = if retention_policy.nil? then "" else "&rp=#{retention_policy}" end
      protocol         = if ssl then 'https' else 'http' end 
      username         = influxdb_config['username']
      password         = influxdb_config['password']
      auth_queryparam  = if username.nil? or password.nil? then "" else "&u=#{username}&p=#{password}" end
      @BUFFER_SIZE     = influxdb_config['buffer_size'] || 100
      @BUFFER_MAX_AGE  = influxdb_config['buffer_max_age'] || 10

      @uri = URI("#{protocol}://#{hostname}:#{port}/write?db=#{database}&precision=#{precision}#{rp_queryparam}#{auth_queryparam}")
      @http = Net::HTTP::new(@uri.host, @uri.port)         
      @buffer = []
      @buffer_flushed = Time.now.to_i
      
      @logger.info("#{@@extension_name}: Successfully initialized config: hostname: #{hostname}, port: #{port}, database: #{database}, uri: #{@uri.to_s}, username: #{username}, buffer_size: #{@BUFFER_SIZE}, buffer_max_age: #{@BUFFER_MAX_AGE}")
    end
    
    def send_to_influxdb(payload)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.body = payload 
      
      @logger.debug("#{@@extension_name}: writing payload #{payload} to endpoint #{@uri.to_s}")
      response = @http.request(request)
      @logger.info("#{@@extension_name}: influxdb http response code = #{response.code}, body = #{response.body}")
    end
    
    def flush_buffer
      payload = @buffer.join("\n")
      send_to_influxdb(payload)
      @buffer = []
      @buffer_flushed = Time.now.to_i
    end

    def buffer_too_old?
      buffer_age = Time.now.to_i - @buffer_flushed
      buffer_age >= @BUFFER_MAX_AGE
    end 
    
    def buffer_too_big?
      @buffer.length >= @BUFFER_SIZE
    end 

    def validate_config(config)
      if config.nil?
        raise ArgumentError, "No configuration for #{@@extension_name} provided. Exiting..."
      end

      ["hostname", "database"].each do |required_setting| 
        if config[required_setting].nil? 
          raise ArgumentError, "Required setting #{required_setting} not provided to extension. This should be provided as JSON element with key '#{@@extension_name}'. Exiting..."
        end
      end
    end
  end
end
