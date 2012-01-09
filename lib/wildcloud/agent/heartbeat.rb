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

    class Heartbeat

      def initialize(agent)
        @agent = agent
        @interval = @agent.config['heartbeat']['interval']
        @agent.logger.info('Heartbeat', "Will be reporting every #{@interval} seconds")
        @timer = EventMachine.add_periodic_timer(@interval, &method(:heartbeat))
      end

      def heartbeat
        message = {
            :components => @agent.component_manager.active_components,
            :load => @agent.load_monitor.report,
            :topic => :heartbeat
        }
        @agent.publish(message, :routing_key => 'heartbeat')
      end

    end

  end
end