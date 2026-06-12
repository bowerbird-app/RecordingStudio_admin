# frozen_string_literal: true

class CreateAdminSummarySections < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_summary_sections, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :admin_summary_sections, :key, unique: true
  end
end
