module FastJsonapi
  class Relationship
    attr_reader :key, :name, :id_method_name, :record_type, :object_method_name, :object_block, :serializer, :relationship_type, :cached, :polymorphic, :conditional_proc, :transform_method, :links, :lazy_load_data, :params

    def initialize(
      key:,
      name:,
      id_method_name:,
      record_type:,
      object_method_name:,
      object_block:,
      serializer:,
      relationship_type:,
      cached: false,
      polymorphic:,
      conditional_proc:,
      transform_method:,
      links:,
      lazy_load_data: false,
      params: nil
    )
      @key = key
      @name = name
      @id_method_name = id_method_name
      @record_type = record_type
      @object_method_name = object_method_name
      @object_block = object_block
      @serializer = serializer
      @relationship_type = relationship_type
      @cached = cached
      @polymorphic = polymorphic
      @conditional_proc = conditional_proc
      @transform_method = transform_method
      @links = links || {}
      @lazy_load_data = lazy_load_data
      @params = params
    end

    def serialize(record, extra_params, output_hash)
      extra_params = serialization_params(extra_params)

      if include_relationship?(record, extra_params)
        empty_case = relationship_type == :has_many ? [] : nil

        output_hash[key] = {}
        unless lazy_load_data
          output_hash[key][:data] = ids_hash_from_record_and_relationship(record, extra_params) || empty_case
        end
        add_links_hash(record, extra_params, output_hash) if links.present?
      end
    end

    def fetch_associated_object(record, extra_params)
      unless object_block.nil?
        extra_params = serialization_params(extra_params)
        return object_block.call(record, extra_params)
      end
      record.send(object_method_name)
    end

    def include_relationship?(record, extra_params)
      if conditional_proc.present?
        extra_params = serialization_params(extra_params)
        conditional_proc.call(record, extra_params)
      else
        true
      end
    end

    def serialization_params(extra_params = nil)
      return extra_params unless params
      extra_params ? extra_params.merge(params) : params
    end

    private

    def ids_hash_from_record_and_relationship(record, extra_params = {})
      extra_params = serialization_params(extra_params)
      return ids_hash(
        fetch_id(record, extra_params)
      ) unless polymorphic

      return unless associated_object = fetch_associated_object(record, extra_params)

      if relationship_type == :belongs_to
        return {
          id: fetch_id(record, extra_params),
          type: run_key_transform(associated_object.class.name.demodulize.underscore)
        }
      end

      return associated_object.map do |object|
        id_hash_from_record object, polymorphic
      end if associated_object.respond_to? :map

      id_hash_from_record associated_object, polymorphic
    end

    def id_hash_from_record(record, record_types)
      # memoize the record type within the record_types dictionary, then assigning to record_type:
      associated_record_type = record_types[record.class] ||= run_key_transform(record.class.name.demodulize.underscore)
      id_hash(record.id, associated_record_type)
    end

    def ids_hash(ids)
      return ids.map { |id| id_hash(id, record_type) } if ids.respond_to? :map
      id_hash(ids, record_type) # ids variable is just a single id here
    end

    def id_hash(id, record_type, default_return=false)
      if id.present?
        { id: id.to_s, type: record_type }
      else
        default_return ? { id: nil, type: record_type } : nil
      end
    end

    def fetch_id(record, extra_params)
      if object_block.present?
        extra_params = serialization_params(extra_params)
        object = object_block.call(record, extra_params)
        return object.map { |item| item.public_send(id_method_name) } if object.respond_to? :map
        return object.try(id_method_name)
      end
      record.public_send(id_method_name)
    end

    def add_links_hash(record, extra_params, output_hash)
      extra_params = serialization_params(extra_params)
      output_hash[key][:links] = links.each_with_object({}) do |(key, method), hash|
        Link.new(key: key, method: method).serialize(record, extra_params, hash)\
      end
    end

    def run_key_transform(input)
      if self.transform_method.present?
        input.to_s.send(*self.transform_method).to_sym
      else
        input.to_sym
      end
    end
  end
end
