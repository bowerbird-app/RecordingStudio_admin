# frozen_string_literal: true

# Accessible 0.41 still calls this class method. Trashable 0.16 removed it.
# The stand-in is dummy-only so this app can boot. It is not part of Admin.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end
