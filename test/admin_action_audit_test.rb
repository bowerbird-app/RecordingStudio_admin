# frozen_string_literal: true

require "test_helper"

class AdminActionAuditTest < Minitest::Test
  AuditedRecord = Struct.new(:id, :previous_changes, keyword_init: true)

  class AuditedSection < RecordingStudioAdmin::Section
    key "audited"
    title "Audited"
  end

  class AuditedResource < RecordingStudioAdmin::Resource
    key "audited"
    section "audited"

    action :edit,
           text: "Edit",
           url: "/admin/audited/1/edit",
           required_role: :admin

    action :flag,
           text: "Flag",
           url: "/admin/audited/1/flag",
           method: :post
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    @original_configuration = RecordingStudioAdmin.instance_variable_get(:@configuration)
    @events = []
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.instance_variable_set(:@configuration, RecordingStudioAdmin::Configuration.new)
    RecordingStudioAdmin.configuration.admin_action_auditor = ->(event) { @events << event }
    RecordingStudioAdmin.register_section(AuditedSection)
    RecordingStudioAdmin.register_resource(AuditedResource)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
    RecordingStudioAdmin.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_performed_admin_action_records_one_event_with_changes
    record = AuditedRecord.new(id: 1, previous_changes: { "name" => %w[Old New], "updated_at" => [1, 2] })
    notifications = []

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      ActiveSupport::Notifications.subscribed(lambda { |*args|
        notifications << ActiveSupport::Notifications::Event.new(*args)
      }, RecordingStudioAdmin::AdminActionAudit::NOTIFICATION_NAME) do
        result = controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :edit, record,
                                             audit_action: :update) do
          true
        end

        assert_equal true, result
      end
    end

    assert_equal 1, @events.size
    event = @events.first
    assert_equal @events.first.to_h, notifications.first.payload
    assert_equal "audited", event.resource_key
    assert_equal "update", event.action_key
    assert_equal "performed", event.outcome
    assert_equal :admin, event.required_role
    assert_equal({ changes: { "name" => %w[Old New] } }, event.metadata)
  end

  def test_sensitive_changes_are_masked_in_the_audit_and_the_notification
    with_rails_filter_parameters(%i[passw token]) do
      record = AuditedRecord.new(
        id: 1,
        previous_changes: {
          "name" => %w[Old New],
          "password" => %w[old-secret new-secret],
          "api_token" => %w[old-token new-token],
          "updated_at" => [1, 2]
        }
      )
      notifications = []

      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        ActiveSupport::Notifications.subscribed(lambda { |*args|
          notifications << ActiveSupport::Notifications::Event.new(*args)
        }, RecordingStudioAdmin::AdminActionAudit::NOTIFICATION_NAME) do
          controller_for(record).send(
            :perform_recording_studio_admin_action!,
            "audited",
            :edit,
            record,
            audit_action: :update,
            metadata: { api_token: "caller-token", reason: "review" }
          ) { true }
        end
      end

      event = @events.first
      masked = [ActiveSupport::ParameterFilter::FILTERED, ActiveSupport::ParameterFilter::FILTERED]

      assert_equal event.to_h, notifications.first.payload
      assert_equal %w[Old New], event.metadata.dig(:changes, "name")
      assert_equal masked, event.metadata.dig(:changes, "password")
      assert_equal masked, event.metadata.dig(:changes, "api_token")
      refute event.metadata[:changes].key?("updated_at")
      assert_equal ActiveSupport::ParameterFilter::FILTERED, event.metadata[:api_token]
      assert_equal "review", event.metadata[:reason]
      metadata = notifications.first.payload.fetch(:metadata)
      refute_includes metadata.to_s, "old-secret"
      refute_includes metadata.to_s, "new-token"
      refute_includes metadata.to_s, "caller-token"
    end
  end

  def test_audit_filtered_attributes_masks_a_configured_column
    RecordingStudioAdmin.configuration.audit_filtered_attributes = [:badge_code, /employee_number/]
    record = AuditedRecord.new(
      id: 1,
      previous_changes: {
        "badge_code" => %w[hidden visible],
        "employee_number" => %w[1 2],
        "name" => %w[A B]
      }
    )

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :edit, record,
                                  audit_action: :update) { true }
    end

    changes = @events.first.metadata.fetch(:changes)
    masked = [ActiveSupport::ParameterFilter::FILTERED, ActiveSupport::ParameterFilter::FILTERED]

    assert_equal masked, changes["badge_code"]
    assert_equal masked, changes["employee_number"]
    assert_equal %w[A B], changes["name"]
  end

  def test_recording_studio_event_metadata_is_filtered
    with_rails_filter_parameters(%i[token]) do
      record = AuditedRecord.new(id: 1, previous_changes: {})
      recorded_attributes = []

      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        with_singleton_stub(RecordingStudio, :record!, lambda { |**attributes|
          recorded_attributes << attributes
          :recording_event
        }) do
          controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :flag, record) do |audit|
            audit.recording_studio_event(
              recordable: record,
              action: "admin.flagged",
              metadata: { reason: "review", api_token: "caller-token" }
            )
            true
          end
        end
      end

      metadata = recorded_attributes.first.fetch(:metadata)

      assert_equal "review", metadata.fetch(:reason)
      assert_equal ActiveSupport::ParameterFilter::FILTERED, metadata.fetch(:api_token)
      assert_equal @events.first.id, metadata.fetch(:admin_audit_event_id)
      refute_includes metadata.to_s, "caller-token"
    end
  end

  def test_validation_failure_records_validation_failed_outcome
    record = AuditedRecord.new(id: 1, previous_changes: {})

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      result = controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :edit, record,
                                           audit_action: :update) do
        false
      end

      assert_equal false, result
    end

    assert_equal "validation_failed", @events.first.outcome
    assert_empty @events.first.metadata
  end

  def test_authorization_denial_records_denied_outcome_when_opted_in
    record = AuditedRecord.new(id: 1, previous_changes: {})

    with_singleton_stub(RecordingStudioAccessible, :authorized?, false) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.authorize_resource!(
          key: "audited",
          action: :edit,
          context: context_for(record),
          record: record,
          audit: true,
          audit_action: :update
        )
      end
    end

    assert_equal 1, @events.size
    assert_equal "denied", @events.first.outcome
    assert_equal "update", @events.first.action_key
    assert_equal "RecordingStudioAdmin::AuthorizationFailed", @events.first.error_class
  end

  def test_failed_admin_action_records_error_and_reraises
    record = AuditedRecord.new(id: 1, previous_changes: {})
    error = RuntimeError

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      assert_raises(error) do
        controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :flag, record) do
          raise error, "boom"
        end
      end
    end

    assert_equal "failed", @events.first.outcome
    assert_equal error.name, @events.first.error_class
    assert_equal "boom", @events.first.error_message
  end

  def test_optional_recording_studio_event_is_correlated_to_admin_audit_event
    record = AuditedRecord.new(id: 1, previous_changes: {})
    recorded_attributes = []

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      with_singleton_stub(RecordingStudio, :record!, lambda { |**attributes|
        recorded_attributes << attributes
        :recording_event
      }) do
        controller_for(record).send(:perform_recording_studio_admin_action!, "audited", :flag, record) do |audit|
          audit.recording_studio_event(recordable: record, action: "admin.flagged", metadata: { reason: "review" })
          true
        end
      end
    end

    assert_equal :recording_event, @events.first.recording_studio_event
    assert_equal "admin.flagged", recorded_attributes.first.fetch(:action)
    assert_equal record, recorded_attributes.first.fetch(:recordable)
    assert_equal :actor, recorded_attributes.first.fetch(:actor)
    assert_equal "review", recorded_attributes.first.fetch(:metadata).fetch(:reason)
    assert_equal @events.first.id, recorded_attributes.first.fetch(:metadata).fetch(:admin_audit_event_id)
  end

  private

  def with_rails_filter_parameters(filters)
    application = Struct.new(:config).new(Struct.new(:filter_parameters).new(filters))
    original = Rails.method(:application)
    with_warnings_silenced do
      Rails.define_singleton_method(:application) { application }
    end
    yield
  ensure
    if original
      with_warnings_silenced do
        Rails.define_singleton_method(:application) { original.call }
      end
    end
  end

  def controller_for(record)
    context = context_for(record)
    Class.new do
      include RecordingStudioAdmin::AdminActionAuditing

      define_method(:recording_studio_admin_context) { context }
    end.new
  end

  def context_for(_record)
    access_recording = Object.new
    request = Struct.new(:request_id, :remote_ip, :user_agent).new("request-1", "203.0.113.10", "Minitest")
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { access_recording }
      define_method(:request) { request }
    end.new

    RecordingStudioAdmin::Context.new(current_actor: :actor, controller: controller)
  end
end
