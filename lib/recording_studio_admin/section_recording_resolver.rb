# frozen_string_literal: true

module RecordingStudioAdmin
  class SectionRecordingResolver
    def self.call(section:, context:)
      new(section, context).call
    end

    def initialize(section, context)
      @section = section
      @context = context
      @definition = section.recordable_definition
    end

    def call
      return unless @definition

      RecordingStudioAdmin::Authorization.authorize!(@context)

      parent_recording = resolve_parent_recording
      root_recording = RecordingStudio.root_recording_or_self(parent_recording)
      recordable = resolve_recordable
      recording = resolve_recording(recordable, root_recording, parent_recording)

      resolved_section_recording(recordable, recording, root_recording, parent_recording)
    end

    private

    def resolve_recordable
      recordable_class.find_or_create_by!(resolve_value(@definition.find_or_create_by))
    end

    def recordable_class
      class_name = @definition.class_name
      return class_name if class_name.respond_to?(:find_or_create_by!)

      class_name.to_s.split("::").reject(&:empty?).inject(Object) do |namespace, constant_name|
        namespace.const_get(constant_name)
      end
    end

    def resolve_parent_recording
      return resolve_value(@definition.parent_recording) if @definition.parent_recording

      RecordingStudio.root_recording_for(resolve_value(@definition.parent))
    end

    def find_recording(recordable, root_recording, parent_recording)
      RecordingStudio::Recording.unscoped.find_by(
        root_recording: root_recording,
        parent_recording: parent_recording,
        recordable: recordable,
        trashed_at: nil
      )
    end

    def record_child(recordable, root_recording, parent_recording)
      RecordingStudio.record!(
        action: @definition.action,
        recordable: recordable,
        root_recording: root_recording,
        parent_recording: parent_recording
      ).recording
    end

    def resolve_recording(recordable, root_recording, parent_recording)
      find_recording(recordable, root_recording, parent_recording) || record_child(
        recordable,
        root_recording,
        parent_recording
      )
    rescue StandardError => e
      raise unless unique_conflict_error?(e)

      find_recording(recordable, root_recording, parent_recording) || raise
    end

    def unique_conflict_error?(error)
      current_error = error
      while current_error
        return true if defined?(ActiveRecord::RecordNotUnique) && current_error.is_a?(ActiveRecord::RecordNotUnique)

        message = current_error.message.to_s.downcase
        return true if message.include?("duplicate key") || message.include?("unique constraint")

        current_error = current_error.cause
      end

      false
    end

    def resolved_section_recording(recordable, recording, root_recording, parent_recording)
      Results::ResolvedSectionRecording.new(
        recordable: recordable,
        recording: recording,
        root_recording: root_recording,
        parent_recording: parent_recording
      )
    end

    def resolve_value(value)
      return value unless value.respond_to?(:call)

      value.call(@section, @context)
    rescue ArgumentError
      begin
        value.call(@context)
      rescue ArgumentError
        value.call
      end
    end
  end
end
