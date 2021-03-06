module Moneta
  module Api
    module DataMapper
      def self.included(base)
        base.extend ClassMethods

        base.class_eval do
          def fill(data)
            properties.each do |property, type|
              value = data[ property ]
              if value
                property_value = type.nil? ? value : build_complex_value(type, value)
                instance_variable_set("@#{ property }", property_value)
              end
            end

            self
          end

          def to_hash
            properties.each_with_object({}) do |(property, _), hash|
              value = send(property)
              unless value.nil?
                hash[ property.to_s.classify_with_lower ] = to_hash_complex_value(value)
              end
            end
          end

          private

          def build_complex_value(type, value)
            value.kind_of?(Array) ?
              value.map { |v| type.build(v) } :
              type.build(value)
          end

          def to_hash_complex_value(value)
            if value.kind_of?(Array)
              value.map(&:to_hash)
            elsif value.respond_to?(:to_hash)
              value.to_hash
            else
              value
            end
          end
        end
      end

      module ClassMethods
        def property(name, base_type=nil)
          attr_accessor(name)

          # Сохраняем свойста и перезаписываем instance метод
          current_properties = instance_variable_get('@properties') || {}
          properties = instance_variable_set('@properties',
            current_properties.merge(name => base_type).merge(parents_properties)
          )

          send(:define_method, :properties) { properties }
        end

        def build(data)
          self.new.tap { |object| object.fill(data) }
        end

        private

        def parents_properties
          instance_variable_get('@parents_properties') ||
            instance_variable_set('@parents_properties', ancestors.each_with_object({}) do |klass, hash|
              if klass.name.match(/Moneta::Api::(Types|Requests|Responses)/)
                hash.merge!(klass.instance_variable_get('@properties') || {})
              end
            end
          )
        end
      end
    end
  end
end
