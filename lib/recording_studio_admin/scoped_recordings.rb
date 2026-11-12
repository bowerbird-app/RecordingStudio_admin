# frozen_string_literal: true

module RecordingStudioAdmin
  class ScopedRecordings
    def self.relation_for(context)
      new(context).relation
    end

    def initialize(context)
      @context = context
    end

    def relation
      recording = @context.access_recording
      return recording_class.none unless recording
      return kept(recording_class, [recording.id]) unless screen&.scopeable?

      scoped_relation(recording)
    end

    private

    def scoped_relation(recording)
      request = choice
      ids = request[:mode] == "subtree" ? subtree_ids(recording) : [recording.id]
      kept(recording_class, ids).where(recordable_type: types_for(request))
    end

    def screen
      @context.screen_definition || RecordingStudioAdmin.screen_for(param(:key))
    end

    def choice
      RecordingScope.choice(
        @context.params,
        allowed_types: screen.scopeable_recordable_types,
        scope_key: RecordingScope.param_key(screen, :scope),
        type_key: RecordingScope.param_key(screen, :recordable_type)
      )
    end

    def types_for(request)
      return [request[:recordable_type]] if request[:recordable_type]

      screen.scopeable_recordable_types
    end

    def subtree_ids(recording)
      descendant_ids = descendant_ids_for(recording)
      limit = scope_limit
      raise ScopeLimitExceeded, limit if descendant_ids.size > limit

      [recording.id, *kept_branch_ids(recording, descendant_ids)]
    end

    def kept_branch_ids(recording, descendant_ids)
      return descendant_ids if descendant_ids.empty?
      return [] if recording.respond_to?(:trashed_at) && recording.trashed_at.present?
      return descendant_ids unless recording_class.respond_to?(:recording_studio_trashable_kept_sql)

      drop_trashed_branches(recording.id, descendant_ids)
    end

    def drop_trashed_branches(root_id, descendant_ids)
      parents, trashed = trash_index(descendant_ids)
      descendant_ids.reject { |id| trashed_branch?(id, root_id, parents, trashed) }
    end

    def trash_index(descendant_ids)
      parents = {}
      trashed = {}
      rows = recording_class.where(id: descendant_ids).pluck(:id, :parent_recording_id, :trashed_at)
      rows.each do |id, parent_id, trashed_at|
        parents[id] = parent_id
        trashed[id] = true if trashed_at
      end
      [parents, trashed]
    end

    def trashed_branch?(id, root_id, parents, trashed)
      seen = {}
      current = id
      while current && current != root_id
        return true if trashed[current] || seen[current]

        seen[current] = true
        current = parents[current]
      end
      false
    end

    def descendant_ids_for(recording)
      root_id = recording.root_recording_id if recording.respond_to?(:root_recording_id)
      RecordingStudio::Tree.descendant_ids(recording.id, root_recording_id: root_id)
    end

    def kept(klass, ids)
      relation = klass.where(id: ids)
      return relation unless klass.respond_to?(:recording_studio_trashable_kept_sql)

      relation.where(klass.recording_studio_trashable_kept_sql)
    end

    def recording_class
      RecordingStudio::Recording
    end

    def scope_limit
      Integer(RecordingStudioAdmin.configuration.max_scoped_recordings)
    end

    def param(key)
      RecordingScope.read_param(@context.params, key)
    end
  end
end
