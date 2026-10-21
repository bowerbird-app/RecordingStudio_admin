# frozen_string_literal: true

namespace :recording_studio_admin do
  namespace :audit_logs do
    desc "Rebuild Logs daily admin audit summaries for FROM..TO (inclusive UTC days)"
    task backfill_summaries: :environment do
      from = Date.iso8601(ENV.fetch("FROM"))
      to = Date.iso8601(ENV.fetch("TO"))
      RecordingStudioAdmin::Services::RebuildAdminAuditLogSummaries.backfill!(from: from, to: to)
    end
  end
end
