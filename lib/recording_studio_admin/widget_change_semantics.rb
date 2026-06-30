# frozen_string_literal: true

module RecordingStudioAdmin
  class WidgetChangeSemantics
    SUCCESS = :success
    DANGER = :danger
    MUTED = :muted

    class << self
      def tone(change:, good_when: :up)
        parsed = parse_change(change)
        return MUTED unless parsed

        direction = direction_for(parsed)
        return MUTED if direction == :flat

        case normalize_good_when(good_when)
        when :up
          direction == :up ? SUCCESS : DANGER
        when :down
          direction == :down ? SUCCESS : DANGER
        else
          MUTED
        end
      end

      private

      def parse_change(change)
        return change.to_f if change.is_a?(Numeric)

        match = change.to_s.match(/[+-]?\d+(?:\.\d+)?/)
        match ? match[0].to_f : nil
      end

      def direction_for(value)
        return :up if value.positive?
        return :down if value.negative?

        :flat
      end

      def normalize_good_when(value)
        normalized = (value || :up).to_s.downcase.to_sym
        normalized = :up if normalized == :positive
        normalized = :down if normalized == :negative
        normalized
      end
    end
  end
end
