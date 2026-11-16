# frozen_string_literal: true

require "active_support/parameter_filter"

module RecordingStudioAdmin
  class AuditMetadataFilter
    PROBE = "audit-filter-probe"

    def self.call(metadata)
      new.call(metadata)
    end

    def call(metadata)
      return metadata unless metadata.is_a?(Hash)

      changes_keys = changes_keys_for(metadata)
      filtered = parameter_filter.filter(metadata.except(*changes_keys))
      changes_keys.each do |key|
        filtered[key] = filter_changes(metadata[key])
      end
      filtered
    end

    private

    def changes_keys_for(metadata)
      keys = []
      keys << :changes if metadata.key?(:changes)
      keys << "changes" if metadata.key?("changes")
      keys
    end

    def filter_changes(changes)
      return changes unless changes.is_a?(Hash)

      changes.each_with_object({}) do |(attribute, value), filtered|
        filtered[attribute] = sensitive?(attribute) ? masked_change(value) : value
      end
    end

    def sensitive?(attribute)
      parameter_filter.filter_param(attribute, PROBE) == ActiveSupport::ParameterFilter::FILTERED
    end

    def masked_change(value)
      mask = ActiveSupport::ParameterFilter::FILTERED
      return value.map { mask } if value.is_a?(Array)

      mask
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(filter_parameters)
    end

    def filter_parameters
      rails_filter_parameters + Array(RecordingStudioAdmin.configuration.audit_filtered_attributes)
    end

    def rails_filter_parameters
      return [] unless defined?(::Rails) && Rails.application

      Array(Rails.application.config.filter_parameters)
    end
  end
end
