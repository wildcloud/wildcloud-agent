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

module Wildcloud
  module Agent

    class ComponentManager

      attr_reader :components

      def initialize(agent)
        @agent = agent
        @components = []
        @settings = {}
        @shutdown = false
      end

      def handle_message(message)
        action = message['action']
        handler = "handle_#{action}".to_sym
        if respond_to?(handler)
          send(handler, message)
        else
          @agent.logger.error('ComponentManager') { "Invalid action #{action}" }
        end
      end

      def handle_start(message)
        component = message['component']
        message['persistent'] ||= false
        @settings[component] = {}

        if @components.include?(component)
          @agent.logger.error('ComponentManager') { "Component #{component} is already running" }
          return
        end

        @agent.logger.info('ComponentManager') { "Component #{component} is being started" }

        started = proc do |process|
          @settings[component].merge!(message)
          @components << component
          @agent.logger.info('ComponentManager') { "Component #{component} started" }
        end

        stopped = proc do |out, status|
          @components.delete(component)
          @agent.logger.info('ComponentManager') { "Component #{component} stopped with status #{status.exitstatus}" }
          if !@shutdown && @settings[component]['persistent']
            @agent.logger.info('ComponentManager') { "Component #{component} will be restarted" }
            EventMachine.add_timer(5) do
              handle_start(@settings[component])
            end
          end
        end

        command = "wildcloud-#{component}"

        command = "cd #{message['directory']} && #{command}" if message['directory']

        command = "su #{message['user']} -c 'source /etc/profile && #{command}'" if message['user']

        @settings[component][:pid] = EventMachine.system(command, started, stopped)

      end

      def active_components
        @components
      end

      def shutdown
        @shutdown = true
        @settings.each do |component, settings|
          Process.kill('TERM', settings[:pid])
        end
      end

      def auto_start
        (@agent.config['autostart'] ||= []).each do |component|
          options = {'action' => 'start', 'persistent' => true}
          if component.kind_of?(Hash)
            options['component'] = component['component']
            options['user'] = component['user']
            options['directory'] = component['directory']
          else
            options['component'] = component.to_s
          end
          handle_message(options)
        end
      end

    end

  end
end