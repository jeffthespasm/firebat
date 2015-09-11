module Flare
  class Flow
    class << self
      def steps
        @_steps ||= []
      end

      def runners
        @_runners ||= {}
      end

      def step(service, action, options = {}, block = nil)
        steps << Runner.new(
          service: service,
          action: action,
          options: options,
          block: block
        )
      end
    end

    KNOWN_BEHAVIOR_KEYS = [
      :times,
      :with
    ]

    def self.non_behavioral_options(options = {})
      options.reject do |k, v|
        KNOWN_BEHAVIOR_KEYS.include?(k)
      end
    end

    def self.resolve(v)
      if v.is_a?(Flare::Runner)
        runners[v.service.to_sym] ||= v.service.new
        runners[v.service.to_sym].send(v.action)
      elsif v.is_a?(Symbol)
        self.send(v)
      elsif v.respond_to?(:call)
        v.call
      else
        v
      end
    end

    def self.resolve_options(options)
      options.inject({}) do |h, (k, v)|
        h.merge(k => resolve(v))
      end
    end

    def self.run!(input = {})
      @_input = input

      steps.each do |step|
        options = resolve(step.options)
        times = options.fetch(:times, 1).to_i
        with = options.fetch(:with, nil)

        set, operation =
          if with
            [resolve(with), :each]
          else
            [times, :times]
          end

        set.send(operation) do |item|
          options = options.merge(item) if operation == :each
          options = resolve_options(non_behavioral_options(options))
          runner = runners[step.service.to_sym] ||= step.service.new

          Flare.log \
            %Q(
              #{'='*100}
              #{runner.to_s} => #{step.action.to_s}
              #{options.inspect}
              #{'='*100}
            ) if DEBUG

          result = runner.send(step.action, options)
          if step.block && step.block.respond_to?(:call)
            step.block.call(result)
          elsif step.block && step.block.is_a?(Symbol)
            self.send(step.block, result)
          else
            result
          end
        end
      end

      self.result if self.respond_to?(:result)
    end
  end
end