# frozen_string_literal: true

module AdminScreens
  class WorkspaceStats < Base
    key "workspace_stats"
    icon :chart_bar
    title "Workspace stats"
    subtitle "Review folders, pages, and recording activity for the current workspace"
    blast_radius :root

    query { |context| recordings_scope(context) }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[day week month], default: :day

    summary do
      label "Workspace items"
      change_good_when :up
    end

    class << self
      def recordings_scope(context)
        root_recording = context.root_recording
        return RecordingStudio::Recording.none unless root_recording

        RecordingStudio::Recording.where(
          root_recording_id: root_recording.id,
          trashed_at: nil,
          recordable_type: %w[Folder Page]
        ).where.not(id: root_recording.id)
      end

      def recordings_for(context, recordable_type: nil, time_range: nil)
        relation = recordings_scope(context)
        relation = relation.where(recordable_type: recordable_type) if recordable_type.present?
        relation = relation.where(created_at: time_range) if time_range
        relation
      end

      def recordable_label(recording)
        recordable = recording.recordable
        return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
        return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

        recording.recordable_type
      end

      def parent_label(recording)
        recordable = recording.parent_recording&.recordable
        return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
        return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

        recordable&.class&.name || "Workspace"
      end

      def badge_style_for(recordable_type)
        case recordable_type.to_s
        when "Folder" then :info
        when "Page" then :success
        else :default
        end
      end
    end
  end
end