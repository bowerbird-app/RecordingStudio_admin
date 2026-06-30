# frozen_string_literal: true

require "test_helper"

class WidgetChangeSemanticsTest < Minitest::Test
  def test_up_polarity_marks_positive_change_as_success
    tone = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "+30%", good_when: :up)

    assert_equal :success, tone
  end

  def test_down_polarity_marks_positive_change_as_danger
    tone = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "+30%", good_when: :down)

    assert_equal :danger, tone
  end

  def test_down_polarity_marks_negative_change_as_success
    tone = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "-8%", good_when: :down)

    assert_equal :success, tone
  end

  def test_neutral_polarity_always_returns_muted
    tone = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "-8%", good_when: :neutral)

    assert_equal :muted, tone
  end

  def test_non_numeric_change_returns_muted
    tone = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "n/a", good_when: :up)

    assert_equal :muted, tone
  end

  def test_positive_and_negative_aliases_are_supported
    positive_alias = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "+2%", good_when: :positive)
    negative_alias = RecordingStudioAdmin::WidgetChangeSemantics.tone(change: "-2%", good_when: :negative)

    assert_equal :success, positive_alias
    assert_equal :success, negative_alias
  end
end
