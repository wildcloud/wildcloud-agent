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

require 'sigar'

module Wildcloud
  module Agent
    class LoadMonitor

      def initialize(agent)
        @sigar = Sigar.new
        @agent = agent
        @cpu_load = [:user, :sys, :nice, :idle, :wait, :irq, :soft_irq, :stolen, :total]
        @memory = [:total, :ram, :used, :free, :actual_used, :actual_free, :used_percent, :free_percent]
        @swap = [:total, :used, :free, :page_in, :page_out]
      end

      def system_configuration
      end

      def report
        report = {
            :memory => {
                :ram => {},
                :swap => {}
            },
            :cpu => {
                :avg => @sigar.loadavg,
                :detail => []
            },
            :uptime => @sigar.uptime.uptime
        }
        stats = @sigar.mem
        @memory.each do |info|
          report[:memory][:ram][info] = stats.send(info)
        end
        stats = @sigar.swap
        @swap.each do |info|
          report[:memory][:swap][info] = stats.send(info)
        end
        @sigar.cpu_list.each do |cpu|
          report[:cpu][:detail] << {}
          @cpu_load.each do |info|
            report[:cpu][:detail].last[info] = cpu.send(info)
          end
        end
        report
      end

    end
  end
end