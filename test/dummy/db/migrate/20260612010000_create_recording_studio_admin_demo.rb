class CreateRecordingStudioAdminDemo < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_roots, id: :uuid do |t|
      t.string :name, null: false, default: "Admin"
      t.timestamps
    end

    create_table :api_requests, id: :uuid do |t|
      t.string :path, null: false
      t.string :method, null: false
      t.integer :status, null: false
      t.integer :latency_ms, null: false
      t.timestamps
    end

    create_table :api_errors, id: :uuid do |t|
      t.string :message, null: false
      t.string :error_class, null: false
      t.string :path, null: false
      t.integer :status, null: false
      t.timestamps
    end

    create_table :user_activities, id: :uuid do |t|
      t.string :email, null: false
      t.string :action, null: false
      t.string :status, null: false
      t.timestamps
    end

    create_table :background_job_runs, id: :uuid do |t|
      t.string :job_class, null: false
      t.string :queue, null: false
      t.string :status, null: false
      t.integer :duration_ms, null: false
      t.timestamps
    end
  end
end
