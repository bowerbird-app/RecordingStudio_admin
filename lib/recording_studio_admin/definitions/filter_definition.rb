# frozen_string_literal: true

module RecordingStudioAdmin
  module Definitions
    FilterDefinition = Struct.new(:key, :type, :options) do
      def param_key
        (options[:param] || key).to_sym
      end

      def normalize(params, context = nil)
        implementation = filter
        if implementation.method(:normalize).parameters.any? { |_kind, name| name == :context }
          implementation.normalize(params, context)
        else
          implementation.normalize(params)
        end
      end

      def apply(relation, value, context)
        return relation unless applies_to_relation?(relation)

        filter.apply(relation, value, context)
      end

      def allowed_values(context = nil)
        present_entries(context).map { |entry| self.class.choice_value(entry).to_s }
      end

      def label_text(context = nil)
        raw = options[:label]
        raw = resolve_label(raw, context) if raw.respond_to?(:call)
        self.class.display_label(key, raw)
      end

      def present_entries(context = nil)
        return within_present_entries(context) if type.to_sym == :within

        Array(resolved_entries(context)).map { |entry| entry.is_a?(Hash) ? entry : entry.to_s }
      end

      def self.choice_value(entry)
        return entry[:value] || entry["value"] if entry.is_a?(Hash)

        entry
      end

      def self.choice_label(entry, humanize: true, blank_label: nil)
        unless entry.is_a?(Hash)
          return blank_label.to_s if blank_label.present? && entry.to_s.empty?
          return entry.to_s unless humanize

          return entry.to_s.humanize
        end

        (entry[:label] || entry["label"] || choice_value(entry)).to_s
      end

      def self.display_label(key, raw)
        return key.to_s.humanize if raw.nil? || raw.to_s.strip.empty?
        return I18n.t(raw.to_s, default: key.to_s.humanize) if translate_label?(raw)

        raw.to_s
      end

      def self.translate_label?(raw)
        return true if raw.is_a?(Symbol)

        raw.is_a?(String) && raw.include?(".") && I18n.exists?(raw)
      end

      private

      def within_present_entries(context)
        all_entry = { value: "", label: all_option_label(context) }
        return [all_entry] unless context

        [all_entry, *context.within_catalog_for(self).visible_choices(context.filter_value(key))]
      end

      def all_option_label(context)
        raw = options[:all_label]
        return default_all_label(context) if raw.nil?
        return all_label_from_callable(raw, context) if raw.respond_to?(:call)

        self.class.display_label(key, raw)
      end

      def default_all_label(context)
        label = label_text(context).to_s.downcase.pluralize
        I18n.t("recording_studio.admin.screens.filters.all_labeled", label: label, default: "All #{label}")
      end

      def all_label_from_callable(raw, context)
        return raw.call.to_s if raw.arity.zero?
        return key.to_s.humanize if context.nil?

        raw.call(context).to_s
      end

      def resolved_entries(context)
        raw = options[:values] || options[:options]
        return raw unless raw.respond_to?(:call)
        return [] if context.nil? && !raw.arity.zero?

        context ? Callable.resolve(raw, context) : raw.call
      end

      def resolve_label(raw, context)
        return key.to_s.humanize if context.nil? && !raw.arity.zero?

        Callable.resolve(raw, context)
      end

      def filter
        case type.to_sym
        when :date_range then Filters::DateRangeFilter.new(self)
        when :group_by then Filters::GroupByFilter.new(self)
        when :recordable_type then Filters::RecordableTypeFilter.new(self)
        when :within then Filters::WithinFilter.new(self)
        else Filters::SelectFilter.new(self)
        end
      end

      def applies_to_relation?(relation)
        relation.respond_to?(:where) || options[:apply].respond_to?(:call)
      end
    end
  end
end
