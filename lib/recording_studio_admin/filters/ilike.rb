# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    # Shared ILIKE search for admin screens: declare columns, escape user input
    # with +sanitize_sql_like+, and match case-insensitively with leading and
    # trailing wildcards.
    #
    # Columns are trusted developer SQL fragments (plain names, table-qualified
    # names, or expressions such as +CAST(id AS TEXT)+). User input is never
    # interpolated into the column side.
    module Ilike
      module_function

      # Apply an OR of +column ILIKE :q+ clauses. Blank +value+ leaves
      # +relation+ unchanged.
      #
      #   RecordingStudioAdmin::Filters::Ilike.apply(
      #     relation,
      #     value,
      #     columns: %i[path status]
      #   )
      #
      # Pass +strip: true+ when the screen should ignore leading and trailing
      # spaces in the search text (some AI and terms screens do this).
      def apply(relation, value, columns:, strip: false)
        column_list = normalize_columns(columns)
        text = normalize_text(value, strip: strip)
        return relation if text.blank?

        relation.where(sql_for(column_list), q: pattern_for(text))
      end

      # Escaped partial-match pattern for custom SQL (joins, expressions, or a
      # bind name other than +:q+).
      #
      #   q = RecordingStudioAdmin::Filters::Ilike.pattern(value)
      #   relation.where("path ILIKE ?", q)
      def pattern(value, strip: false)
        pattern_for(normalize_text(value, strip: strip))
      end

      # Returns a +filter :search, apply:+ callable that searches the given
      # columns.
      #
      #   filter :search, apply: RecordingStudioAdmin::Filters::Ilike.on(
      #     :resource_key, :action_key, :outcome
      #   )
      def on(*columns, strip: false)
        column_list = normalize_columns(columns)
        lambda do |relation, value, _context|
          RecordingStudioAdmin::Filters::Ilike.apply(
            relation,
            value,
            columns: column_list,
            strip: strip
          )
        end
      end

      def normalize_columns(columns)
        list = Array(columns).flatten.compact.map { |column| column.to_s.strip }.reject(&:empty?)
        raise ArgumentError, "ILIKE filter requires at least one column" if list.empty?

        list
      end
      private_class_method :normalize_columns

      def normalize_text(value, strip:)
        text = value.to_s
        strip ? text.strip : text
      end
      private_class_method :normalize_text

      def pattern_for(text)
        "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
      end
      private_class_method :pattern_for

      def sql_for(columns)
        columns.map { |column| "#{column} ILIKE :q" }.join(" OR ")
      end
      private_class_method :sql_for
    end
  end
end
