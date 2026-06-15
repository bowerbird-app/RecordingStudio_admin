# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class DateRangeFilter
      RangeValue = Data.define(:start_date, :end_date, :preset_key)

      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        start_key = (@definition.options[:start_param] || :start_date).to_sym
        end_key = (@definition.options[:end_param] || :end_date).to_sym
        start_date = parse_date(params[start_key] || params[start_key.to_s])
        end_date = parse_date(params[end_key] || params[end_key.to_s])
        return default_range if !start_date && !end_date && default_range

        RangeValue.new(start_date, end_date, nil)
      end

      def apply(relation, value, _context)
        field = @definition.options.fetch(:field, :created_at)
        scoped = relation
        if value.start_date.respond_to?(:beginning_of_day)
          scoped = scoped.where(field => value.start_date.beginning_of_day..)
        end
        scoped = scoped.where(field => ..value.end_date.end_of_day) if value.end_date.respond_to?(:end_of_day)
        scoped
      end

      private

      def parse_date(value)
        return if value.nil? || value.to_s.strip.empty?

        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def default_range
        return unless @definition.options[:default] == :last_30_days && defined?(Date)

        today = Date.respond_to?(:current) ? Date.current : Date.today
        RangeValue.new(today - 30, today, :last_30_days)
      end
    end
  end
end
