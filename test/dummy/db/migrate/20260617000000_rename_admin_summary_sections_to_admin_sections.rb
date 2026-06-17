# frozen_string_literal: true

class RenameAdminSummarySectionsToAdminSections < ActiveRecord::Migration[8.1]
  def up
    if table_exists?(:admin_summary_sections) && table_exists?(:admin_sections)
      merge_admin_summary_sections_into_admin_sections
      drop_table :admin_summary_sections
    elsif table_exists?(:admin_summary_sections)
      rename_table :admin_summary_sections, :admin_sections
    end

    rename_index :admin_sections, :index_admin_summary_sections_on_key, :index_admin_sections_on_key if index_name_exists?(:admin_sections, :index_admin_summary_sections_on_key)

    update_recordable_type("AdminSummarySection", "AdminSection")
    update_admin_section_names("Admin summary", "Admin section")
  end

  def down
    update_admin_section_names("Admin section", "Admin summary")
    update_recordable_type("AdminSection", "AdminSummarySection")

    rename_index :admin_sections, :index_admin_sections_on_key, :index_admin_summary_sections_on_key if index_name_exists?(:admin_sections, :index_admin_sections_on_key)
    rename_table :admin_sections, :admin_summary_sections if table_exists?(:admin_sections)
  end

  private

  def merge_admin_summary_sections_into_admin_sections
    execute <<~SQL.squish
      INSERT INTO #{quote_table_name(:admin_sections)} (id, key, name, created_at, updated_at)
      SELECT id, key, name, created_at, updated_at
      FROM #{quote_table_name(:admin_summary_sections)}
      ON CONFLICT (key) DO UPDATE
      SET name = EXCLUDED.name,
          updated_at = EXCLUDED.updated_at
    SQL
  end

  def update_recordable_type(old_type, new_type)
    update_recording_studio_table(:recording_studio_recordings, old_type, new_type)
    update_recording_studio_table(:recording_studio_events, old_type, new_type)
  end

  def update_recording_studio_table(table_name, old_type, new_type)
    return unless table_exists?(table_name)

    execute <<~SQL.squish
      UPDATE #{quote_table_name(table_name)}
      SET recordable_type = #{quote(new_type)}
      WHERE recordable_type = #{quote(old_type)}
    SQL
  end

  def update_admin_section_names(old_name, new_name)
    return unless table_exists?(:admin_sections)

    execute <<~SQL.squish
      UPDATE #{quote_table_name(:admin_sections)}
      SET name = #{quote(new_name)}
      WHERE name = #{quote(old_name)}
    SQL
  end
end
