# frozen_string_literal: true

module Flows
  # Executes schema on a given data input
  module Executor
    class UnexpectedSignal < StandardError; end

    class << self
      def call(schema, data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        enter_point, nodes = schema

        current_node = nodes[enter_point]
        loop do
          return [current_node, data] if current_node.is_a?(Symbol)

          logic, route = current_node

          current_node = case route
                         when Symbol
                           data = logic.call(data)

                           nodes[route]
                         else # Hash
                           signal, data = logic.call(data)

                           unless route.key?(signal)
                             raise UnexpectedSignal, "Unexpected signal: #{signal}. Allowed signals: #{route.keys}"
                           end

                           nodes[route[signal]]
                         end
        end
      end
    end
  end
end
