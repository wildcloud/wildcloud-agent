# Copyright 2011 Marek Jelen
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'eventmachine'
require 'amqp'
require 'json'
require 'yaml'

require 'wildcloud/logger'
require 'wildcloud/logger/middleware/console'
require 'wildcloud/logger/middleware/amqp'
require 'wildcloud/logger/middleware/json'
require 'wildcloud/configuration'

require 'singleton'

require 'wildcloud/agent/load_monitor'
require 'wildcloud/agent/component_manager'
require 'wildcloud/agent/heartbeat'

module Wildcloud
  module Agent

    class Agent

      include Singleton

      attr_reader :component_manager, :load_monitor, :heartbeat

      def initialize
        trap("TERM") { stop }
        trap("INT") { stop }
        @node = self.config['node']['name']
        EventMachine.error_handler(&method(:handle_error))
        start_amqp
        start_component_manager
        start_load_monitor
        start_heartbeat
      end

      def handle_error(exception)
        logger.error('Agent', "Unhandled exception #{exception.message}")
      end

      def start_amqp
        # Connect AMQP
        $amqp = AMQP.connect(self.config['amqp'])
        # Redirect logging
        @logger.add(Wildcloud::Logger::Middleware::Json)
        @logger.add(Wildcloud::Logger::Middleware::Amqp,
                    :exchange => AMQP::Channel.new($amqp).topic('wildcloud.logger'),
                    :routing_key => proc { |message| message[:application] }
        )
        # Setup communication
        @channel = AMQP::Channel.new($amqp)
        @exchange = @channel.topic('wildcloud.monitor')
        @queue = @channel.queue("wildcloud.agent.#{@node}", :durable => false, :auto_delete => true)
        @queue.bind('wildcloud.agent', :routing_key => 'nodes').bind('wildcloud.agent', :routing_key => "node.#{@node}")
        @queue.subscribe(&method(:message))
      end

      def start_component_manager
        @component_manager = ComponentManager.new(self)
        @component_manager.auto_start
      end

      def start_load_monitor
        @load_monitor = LoadMonitor.new(self)
      end

      def start_heartbeat
        @heartbeat = Heartbeat.new(self)
      end

      def stop
        @component_manager.shutdown
        EventMachine.stop
      end

      def message(message)
        message = JSON.parse(message) if message.kind_of?(String)
        component = instance_variable_get("@#{message['module']}".to_sym)
        component.handle_message(message) if component
      end

      def publish(message, options = {})
        message[:reply_to] ||= @node
        message[:published_at] ||= Time.now.to_i
        @exchange.publish(JSON.dump(message), options)
      end

      def config
        return @configuration if @configuration
        config = Wildcloud::Configuration.load('agent')
        config.sources.each do |source|
          self.logger.info('Configuration', "Loaded configuration from #{source}")
        end
        @configuration = config.configuration
      end

      def logger
        return @logger if @logger
        @logger = Wildcloud::Logger::Logger.new
        @logger.application = ['wildcloud', 'agent', self.config['node']['name']].join('.')
        @logger.level = self.config['logger']['level'].to_s.to_sym if self.config['logger'] && self.config['logger']['level']
        @logger.add(Wildcloud::Logger::Middleware::Console)
        @logger
      end

    end

    def self.setup
      if EventMachine.reactor_running?
        start
      else
        EventMachine.run(&method(:start))
      end
    end

    def self.start
      Wildcloud::Agent::Agent.instance
    end

  end
end