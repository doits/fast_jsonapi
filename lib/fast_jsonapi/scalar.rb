module FastJsonapi
  class Scalar
    attr_reader :key, :method, :conditional_proc

    def initialize(key:, method:, options: {})
      @key = key
      @method = method
      @conditional_proc = options[:if]
    end

    def serialize(record, serialization_params, output_hash)
      if conditionally_allowed?(record, serialization_params)
        output_hash[key] = if method.is_a?(Proc)
          FastJsonapi.call_proc(method, record, serialization_params)
        else
          record.public_send(method)
        end
      end
    end

    def conditionally_allowed?(record, serialization_params)
      if conditional_proc.present?
        FastJsonapi.call_proc(conditional_proc, record, serialization_params, key: key)
      else
        true
      end
    end
  end
end
