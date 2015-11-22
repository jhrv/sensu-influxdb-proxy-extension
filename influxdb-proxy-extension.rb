#!/usr/bin/env ruby

require 'net/http'
require 'multi_json'

module Sensu::Extension
  class Influx < Handler
    
    @@extension_name = 'influxdb-proxy-extension'

    def name
      @@extension_name
    end

    def description
      'Forwards metrics to InfluxDB'
    end

    def post_init
      influxdb_config = settings[@@extension_name]
      
      validate_config(influxdb_config)
       
      hostname         = influxdb_config[:hostname] 
      port             = influxdb_config[:port] || 8086
      database         = influxdb_config[:database]
      ssl              = influxdb_config[:ssl] || false
      precision        = influxdb_config[:precision] || 's'
      retention_policy = influxdb_config[:retention_policy]
      rp_queryparam    = if retention_policy.nil? then "" else "&rp=#{retention_policy}" end
      protocol         = if ssl then 'https' else 'http' end 
      username         = influxdb_config[:username]
      password         = influxdb_config[:password]
      auth_queryparam  = if username.nil? or password.nil? then "" else "&u=#{username}&p=#{password}" end
      @BUFFER_SIZE     = influxdb_config[:buffer_size] || 100

      @uri = URI("#{protocol}://#{hostname}:#{port}/write?db=#{database}&precision=#{precision}#{rp_queryparam}#{auth_queryparam}")
      @http = Net::HTTP::new(@uri.host, @uri.port)         
      @buffer = []

      @logger.info("#{@@extension_name}: Successfully initialized config: hostname: #{hostname}, port: #{port}, database: #{database}, uri: #{@uri.to_s}, username: #{username}, timeout: #{@timeout}, buffer_size: #{@BUFFER_SIZE}")
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

    def send_to_influxdb(payload)
        request = Net::HTTP::Post.new(@uri.request_uri)
        request.body = payload 
        
        @logger.debug("#{@@extension_name}: writing payload #{payload} to endpoint #{@uri.to_s}")
        response = @http.request(request)
        @logger.debug("#{@@extension_name}: influxdb http response code = #{response.code}, body = #{response.body}")
    end
    
    def run(event)
      begin
        event = MultiJson.load(event)
        output = event[:check][:output]

        output.split(/\r\n|\n/).each do |point|
            if @buffer.length >= @BUFFER_SIZE
                payload = @buffer.join("\n")
                send_to_influxdb(payload)
                @buffer = []
            end

            @buffer.push(point)
            logger.debug("#{@@extension_name}: stored point in buffer (#{@buffer.length}/#{@BUFFER_SIZE})")
        end
        
        @buffer.push(point)
        logger.debug("#{@@extension_name}: stored point in buffer (#{@buffer.length}/#{@BUFFER_SIZE})")
      rescue => e
        @logger.error("#{@@extension_name}: unable to post payload to influxdb for event #{event} - #{e.backtrace.to_s}")
      end

      yield("#{@@extension_name}: handler finished", 0)
    end
  end
end
