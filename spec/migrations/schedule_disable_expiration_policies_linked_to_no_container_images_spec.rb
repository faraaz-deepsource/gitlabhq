# frozen_string_literal: true

require 'spec_helper'

require_migration!

RSpec.describe ScheduleDisableExpirationPoliciesLinkedToNoContainerImages do
  let!(:projects) { table(:projects) }
  let!(:container_expiration_policies) { table(:container_expiration_policies) }
  let!(:container_repositories) { table(:container_repositories) }
  let!(:namespaces) { table(:namespaces) }
  let!(:namespace) { namespaces.create!(name: 'test', path: 'test') }

  let!(:policy1) { create_expiration_policy(id: 1, enabled: true) }
  let!(:policy2) { create_expiration_policy(id: 2, enabled: false) }
  let!(:policy3) { create_expiration_policy(id: 3, enabled: false) }
  let!(:policy4) { create_expiration_policy(id: 4, enabled: true) }
  let!(:policy5) { create_expiration_policy(id: 5, enabled: false) }
  let!(:policy6) { create_expiration_policy(id: 6, enabled: false) }
  let!(:policy7) { create_expiration_policy(id: 7, enabled: true) }
  let!(:policy8) { create_expiration_policy(id: 8, enabled: true) }
  let!(:policy9) { create_expiration_policy(id: 9, enabled: true) }

  it 'schedules background migrations', :aggregate_failures do
    stub_const("#{described_class}::BATCH_SIZE", 2)

    Sidekiq::Testing.fake! do
      freeze_time do
        migrate!

        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(2.minutes, 1, 4)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(4.minutes, 7, 8)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(6.minutes, 9, 9)

        expect(BackgroundMigrationWorker.jobs.size).to eq(3)
      end
    end
  end

  def create_expiration_policy(id:, enabled:)
    project = projects.create!(id: id, namespace_id: namespace.id, name: "gitlab-#{id}")
    container_expiration_policies.create!(
      enabled: enabled,
      project_id: project.id
    )
  end
end
