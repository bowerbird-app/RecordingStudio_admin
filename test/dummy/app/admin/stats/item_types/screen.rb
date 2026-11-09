# frozen_string_literal: true

module AdminScreens
  class ItemTypes < Base
    key "item_types"
    icon :rectangle_stack
    title "Item types"
    subtitle "What's in this workspace, by type"
    blast_radius :root

    query { |context| items_for_current_root(context) }
    filter :type,
           field: :recordable_type,
           options: lambda { |context|
             items_for_current_root(context).distinct.order(:recordable_type).pluck(:recordable_type)
           }

    summary do
      label "Items"
      change_good_when :up
    end

    class << self
      def items_for_current_root(context)
        root_recording = context.controller.current_root_recording
        return RecordingStudio::Recording.none unless root_recording

        RecordingStudio::Recording.where(
          RecordingStudio::Recording.recording_studio_trashable_kept_sql
        ).where(
          root_recording_id: root_recording.id,
          recordable_type: [ "Folder", "Page" ]
        ).where.not(id: root_recording.id)
      end

      def item_label(recording)
        recordable = recording.recordable
        return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
        return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

        recording.recordable_type
      end
    end
  end
end
