# frozen_string_literal: true

module RecordingStudioAdmin
  ResourceActionDefinition = Data.define(:key, :text, :url, :icon, :method, :confirm, :destructive, :visible_if,
                                         :required_role, :blast_radius) do
    def required_access_role
      normalize_required_role(required_role || inferred_required_role)
    end

    def visible?(record, context)
      return true unless visible_if

      resolve_value(visible_if, record, context)
    end

    def resolve(record, context)
      return unless visible?(record, context)

      resolved_url = RecordingStudioAdmin::UrlSafety.safe_href(resolve_value(url, record, context))
      return if resolved_url.blank?

      Results::ResolvedRowAction.new(
        name: key,
        text: resolve_value(text, record, context),
        url: resolved_url,
        icon: resolve_value(icon, record, context),
        method: normalize_method(resolve_value(method, record, context)),
        confirm: resolve_value(confirm, record, context),
        destructive: resolve_value(destructive, record, context)
      )
    end

    private

    def normalize_method(value)
      normalized = value.to_s.downcase.presence
      return if normalized.blank? || normalized == "get"

      normalized.to_sym
    end

    def inferred_required_role
      resolved_method = normalize_method(method)
      return :admin if destructive || resolved_method.present?

      RecordingStudioAdmin.configuration.required_access_role
    end

    def normalize_required_role(value)
      value.to_s.downcase.to_sym
    end

    def resolve_value(value, record, context)
      return value unless value.respond_to?(:call)

      case value.arity
      when 0 then value.call
      when 1, -1 then value.call(record)
      else value.call(record, context)
      end
    end
  end

  class Resource < Definitions::Base
    class << self
      attr_reader :section_key_value, :actions_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@actions_value, {})
      end

      def section(value = nil)
        @section_key_value = value.to_s if value
        @section_key_value
      end

      def action(name, text:, url:, icon: nil, method: nil, confirm: nil, destructive: nil, visible_if: nil,
             required_role: nil, blast_radius: nil)
        definition = ResourceActionDefinition.new(
          name.to_sym,
          text,
          url,
          icon,
          method,
          confirm,
          destructive,
          visible_if,
          required_role,
          RecordingStudioAdmin::BlastRadius.normalize(blast_radius, owner: "Resource action #{key}.#{name}")
        )
        @actions_value[definition.key] = definition
        definition
      end

      def section_key = section_key_value

      def section_key!
        section_key.presence || raise(InvalidDefinition, "Resource #{key.inspect} does not define a section")
      end

      def actions
        @actions_value || {}
      end

      def action_for(key)
        actions[key.to_s.downcase.to_sym]
      end
    end
  end
end