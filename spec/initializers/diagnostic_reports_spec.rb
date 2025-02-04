# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'diagnostic reports' do
  subject(:load_initializer) do
    load Rails.root.join('config/initializers/diagnostic_reports.rb')
  end

  shared_examples 'does not modify worker startup hooks' do
    it do
      expect(Gitlab::Cluster::LifecycleEvents).not_to receive(:on_worker_start)
      expect(Gitlab::Cluster::LifecycleEvents).not_to receive(:on_worker_stop)
      expect(Gitlab::Memory::ReportsDaemon).not_to receive(:instance)

      load_initializer
    end
  end

  context 'when GITLAB_DIAGNOSTIC_REPORTS_ENABLED is set to true' do
    before do
      stub_env('GITLAB_DIAGNOSTIC_REPORTS_ENABLED', true)
    end

    context 'when run in Puma context' do
      before do
        allow(::Gitlab::Runtime).to receive(:puma?).and_return(true)
      end

      let(:report_daemon) { instance_double(Gitlab::Memory::ReportsDaemon) }
      let(:reporter) { instance_double(Gitlab::Memory::Reporter) }

      it 'modifies worker startup hooks, starts Gitlab::Memory::ReportsDaemon' do
        expect(Gitlab::Cluster::LifecycleEvents).to receive(:on_worker_start).and_call_original
        expect_next_instance_of(Gitlab::Memory::ReportsDaemon) do |daemon|
          expect(daemon).to receive(:start)
        end

        load_initializer
      end

      context 'when GITLAB_MEMWD_DUMP_HEAP is set' do
        before do
          stub_env('GITLAB_MEMWD_DUMP_HEAP', '1')
        end

        it 'writes scheduled heap dumps in on_worker_stop' do
          expect(Gitlab::Cluster::LifecycleEvents).to receive(:on_worker_start)
          expect(Gitlab::Cluster::LifecycleEvents).to receive(:on_worker_stop).and_call_original
          expect(Gitlab::Memory::Reporter).to receive(:new).and_return(reporter)
          expect(reporter).to receive(:run_report).with(an_instance_of(Gitlab::Memory::Reports::HeapDump))

          load_initializer
          # This is necessary because this hook normally fires during worker shutdown.
          Gitlab::Cluster::LifecycleEvents.do_worker_stop
        end
      end

      context 'when GITLAB_MEMWD_DUMP_HEAP is not set' do
        it 'does not write heap dumps' do
          expect(Gitlab::Cluster::LifecycleEvents).to receive(:on_worker_start)
          expect(Gitlab::Cluster::LifecycleEvents).not_to receive(:on_worker_stop)

          load_initializer
        end
      end
    end

    context 'when run in non-Puma context, such as rails console, tests, Sidekiq' do
      before do
        allow(::Gitlab::Runtime).to receive(:puma?).and_return(false)
      end

      include_examples 'does not modify worker startup hooks'
    end
  end

  context 'when GITLAB_DIAGNOSTIC_REPORTS_ENABLED is not set' do
    before do
      allow(::Gitlab::Runtime).to receive(:puma?).and_return(true)
    end

    include_examples 'does not modify worker startup hooks'
  end

  context 'when GITLAB_DIAGNOSTIC_REPORTS_ENABLED is set to false' do
    before do
      stub_env('GITLAB_DIAGNOSTIC_REPORTS_ENABLED', false)
      allow(::Gitlab::Runtime).to receive(:puma?).and_return(true)
    end

    include_examples 'does not modify worker startup hooks'
  end
end
