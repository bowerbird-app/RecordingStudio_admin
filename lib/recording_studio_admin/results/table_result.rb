# frozen_string_literal: true

module RecordingStudioAdmin
  module Results
    TableResult = Data.define(:rows, :total_count, :current_page, :per_page, :total_pages, :sort, :direction, :mode,
                              :has_more, :count_pending)
  end
end
