# frozen_string_literal: true

module RecordingStudioAdmin
  module BlastRadius
    VALUES = %i[recording root site].freeze
    DEFAULT = :recording
    RANKS = VALUES.each_with_index.to_h.freeze

    module_function

    def normalize(value, owner: "Definition")
      normalized = (value || DEFAULT).to_s.downcase.to_sym
      return normalized if VALUES.include?(normalized)

      raise InvalidDefinition, "#{owner} has unsupported blast_radius #{value.inspect}"
    end

    def value_for(definition)
      return normalize(definition, owner: "Blast radius") unless definition.respond_to?(:blast_radius)

      definition.blast_radius
    end

    def max(*values)
      values.compact.map { |value| normalize(value) }.max_by { |value| RANKS.fetch(value) } || DEFAULT
    end

    def allowed?(definition, context:, recording: context.access_recording, container: nil)
      radius = value_for(definition)
      return false if container && wider_than?(radius, value_for(container))

      !wider_than?(radius, allowed_radius(context, recording: recording))
    end

    def authorize!(definition, context:, recording: context.access_recording, container: nil, label: nil)
      return true if allowed?(definition, context: context, recording: recording, container: container)

      radius = value_for(definition)
      allowed = allowed_radius(context, recording: recording)
      subject = label || blast_radius_label(definition)
      if container && wider_than?(radius, value_for(container))
        raise AuthorizationFailed,
              "#{subject} has blast_radius #{radius.inspect} wider than container #{value_for(container).inspect}"
      end

      raise AuthorizationFailed,
            "#{subject} has blast_radius #{radius.inspect} but current access recording only allows #{allowed.inspect}"
    end

    def allowed_radius(context, recording: context.access_recording)
      return :site if site_admin_recording?(context, recording)
      return :root if root_recording?(recording)

      :recording
    end

    def wider_than?(left, right)
      RANKS.fetch(normalize(left)) > RANKS.fetch(normalize(right))
    end

    def site_admin_recording?(context, recording)
      site_admin_recording = context.site_admin_recording if context.respond_to?(:site_admin_recording)
      return false unless site_admin_recording && recording

      site_admin_recording == recording
    end

    def root_recording?(recording)
      return false unless recording
      return recording.parent_recording.nil? if recording.respond_to?(:parent_recording)
      if recording.respond_to?(:root_recording) && recording.root_recording
        return recording.root_recording == recording
      end

      RecordingStudioAdmin::Authorization.resolve_root_recording(recording) == recording
    end

    def blast_radius_label(definition)
      return definition.key.inspect if definition.respond_to?(:key)
      return definition.name.inspect if definition.respond_to?(:name)

      definition.class.name
    end
  end
end