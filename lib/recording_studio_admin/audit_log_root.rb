# frozen_string_literal: true

module RecordingStudioAdmin
  module AuditLogRoot
    extend ActiveSupport::Concern

    included do
      before_validation :assign_admin_audit_root_recording_id, on: :create
    end

    private

    def assign_admin_audit_root_recording_id
      return unless self.class.column_names.include?("root_recording_id")
      return if root_recording_id.present?
      return if try(:access_recording_id).blank?
      return unless defined?(::RecordingStudio::Recording)

      recording = ::RecordingStudio::Recording.find_by(id: access_recording_id)
      self.root_recording_id = recording&.root_recording_id.presence || recording&.id
    end
  end
end
