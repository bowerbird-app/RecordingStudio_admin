# frozen_string_literal: true

module RecordingStudioAdmin
  class WithinCatalog
    def initialize(context, definition)
      @context = context
      @definition = definition
    end

    def allowed_id(raw)
      text = id_text(raw)
      return if text.nil?

      recording = allowed_recordings.find { |item| item.id.to_s == text }
      recording&.id&.to_s
    end

    def subtree_ids(selected_id)
      recording = allowed_recordings.find { |item| item.id.to_s == selected_id.to_s }
      return [] unless recording

      ScopedRecordings.kept_subtree_ids(recording)
    end

    def choice_entries
      choices.entries
    end

    def visible_choices(selected_id)
      choices.visible(selected_id)
    end

    def choice_for(selected_id)
      choices.find(selected_id)
    end

    def search(query:, page:)
      choices.search(query: query, page: page)
    end

    def display_name(recording)
      choices.display_name(recording)
    end

    def self.narrow(relation, context, screen)
      within_definitions(screen).each do |definition|
        selected = Filters::WithinFilter.new(definition).normalize(context.params, context)
        next if selected.nil?

        relation = relation.where(id: context.within_catalog_for(definition).subtree_ids(selected))
      end
      relation
    end

    def self.within_definitions(screen)
      filters = Array(screen.filters) + Array(screen.table_value&.filters)
      filters.select { |entry| entry.type.to_sym == :within }.uniq
    end

    private

    def choices
      @choices ||= WithinChoices.new(allowed_recordings, @definition, @context)
    end

    def allowed_recordings
      return @allowed_recordings if defined?(@allowed_recordings)

      access = @context.access_recording
      @allowed_recordings = access ? load_allowed(access) : []
    end

    def load_allowed(access)
      recordings_for(ScopedRecordings.kept_subtree_ids(access)).select { |recording| actor_can_view?(recording) }
    end

    def recordings_for(ids)
      type_name = @definition.options[:recordable_type].to_s
      RecordingStudio::Recording.where(id: ids, recordable_type: type_name).includes(:recordable).to_a
    end

    def actor_can_view?(recording)
      ::RecordingStudioAccessible.authorized?(
        actor: @context.current_actor,
        recording: recording,
        role: RecordingStudioAdmin.configuration.required_access_role
      )
    end

    def id_text(raw)
      return if raw.nil? || raw.is_a?(Array) || raw.is_a?(Hash)

      text = raw.to_s
      text unless text.empty?
    end
  end

  class WithinChoices
    def initialize(recordings, definition, context)
      @recordings = recordings
      @definition = definition
      @context = context
    end

    def entries
      @entries ||= sorted_entries
    end

    def visible(selected_id)
      threshold = Integer(RecordingStudioAdmin.configuration.within_search_threshold)
      return entries unless entries.size > threshold

      page = entries.first(threshold)
      selected = find(selected_id)
      page << selected if selected && page.none? { |entry| entry[:value] == selected[:value] }
      page
    end

    def find(selected_id)
      text = selected_id.to_s
      return if text.empty?

      entries.find { |entry| entry[:value] == text }
    end

    def search(query:, page:)
      per_page = Integer(RecordingStudioAdmin.configuration.within_search_threshold)
      items = matching(query)
      start = (page_number(page) - 1) * per_page
      items.slice(start, per_page) || []
    end

    def display_name(recording)
      callable = @definition.options[:name]
      if callable.respond_to?(:call)
        text = invoke_name(callable, recording).to_s
        return text if text.present?
      end

      fallback_name(recording)
    end

    private

    def sorted_entries
      @recordings.map { |recording| entry_for(recording) }.sort_by do |entry|
        [entry[:label].downcase, entry[:value]]
      end
    end

    def entry_for(recording)
      { value: recording.id.to_s, label: display_name(recording) }
    end

    def matching(query)
      needle = RecordingScope.scalar_string(query)
      return entries unless needle

      downcased = needle.downcase
      entries.select { |entry| entry[:label].downcase.include?(downcased) }
    end

    def fallback_name(recording)
      recordable = recording.recordable if recording.respond_to?(:recordable)
      [recordable_text(recordable, :name), recordable_text(recordable, :title), recording.id].each do |candidate|
        text = candidate.to_s
        return text if text.present?
      end
    end

    def invoke_name(callable, recording)
      case callable.arity
      when 0 then callable.call
      when 1 then callable.call(recording)
      else callable.call(recording, @context)
      end
    end

    def recordable_text(recordable, method_name)
      return unless recordable.respond_to?(method_name)

      recordable.public_send(method_name)
    end

    def page_number(raw)
      number = raw.is_a?(Numeric) || raw.is_a?(String) ? raw.to_i : 1
      number = 1 if number < 1
      [number, Integer(RecordingStudioAdmin.configuration.max_page)].min
    end
  end
end
