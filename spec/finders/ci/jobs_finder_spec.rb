# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobsFinder, '#execute' do
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:project) { create(:project, :private, public_builds: false) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:pending_job) { create(:ci_build, :pending) }
  let_it_be(:running_job) { create(:ci_build, :running) }
  let_it_be(:successful_job) { create(:ci_build, :success, pipeline: pipeline, name: 'build') }

  let(:params) { {} }

  context 'no project' do
    subject { described_class.new(current_user: current_user, params: params).execute }

    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode setting is disabled', :do_not_mock_admin_mode_setting do
        it { is_expected.to match_array([pending_job, running_job, successful_job]) }
      end

      context 'when admin mode setting is enabled' do
        context 'when in admin mode', :enable_admin_mode do
          it { is_expected.to match_array([pending_job, running_job, successful_job]) }
        end

        context 'when not in admin mode' do
          it { is_expected.to be_empty }
        end
      end
    end

    context 'with normal user' do
      let(:current_user) { user }

      it { is_expected.to be_empty }
    end

    context 'without user' do
      let(:current_user) { nil }

      it { is_expected.to be_empty }
    end

    context 'with scope', :enable_admin_mode do
      let(:current_user) { admin }
      let(:jobs) { [pending_job, running_job, successful_job] }

      using RSpec::Parameterized::TableSyntax

      where(:scope, :expected_jobs) do
        'pending'           | lazy { [pending_job] }
        'running'           | lazy { [running_job] }
        'finished'          | lazy { [successful_job] }
        %w[running success] | lazy { [running_job, successful_job] }
      end

      with_them do
        let(:params) { { scope: scope } }

        it { is_expected.to match_array(expected_jobs) }
      end
    end
  end

  context 'a project is present' do
    subject { described_class.new(current_user: user, project: project, params: params).execute }

    context 'user has access to the project' do
      before do
        project.add_maintainer(user)
      end

      it 'returns jobs for the specified project' do
        expect(subject).to match_array([successful_job])
      end
    end

    context 'user has no access to project builds' do
      before do
        project.add_guest(user)
      end

      it 'returns no jobs' do
        expect(subject).to be_empty
      end
    end

    context 'without user' do
      let(:user) { nil }

      it 'returns no jobs' do
        expect(subject).to be_empty
      end
    end
  end

  context 'when pipeline is present' do
    before_all do
      project.add_maintainer(user)
      successful_job.update!(retried: true)
    end

    let_it_be(:job_4) { create(:ci_build, :success, pipeline: pipeline, name: 'build') }

    subject { described_class.new(current_user: user, pipeline: pipeline, params: params).execute }

    it 'does not return retried jobs by default' do
      expect(subject).to match_array([job_4])
    end

    context 'when include_retried is false' do
      let(:params) { { include_retried: false } }

      it 'does not return retried jobs' do
        expect(subject).to match_array([job_4])
      end
    end

    context 'when include_retried is true' do
      let(:params) { { include_retried: true } }

      it 'returns retried jobs' do
        expect(subject).to match_array([successful_job, job_4])
      end
    end
  end

  context 'a runner is present' do
    let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }
    let_it_be(:job_4) { create(:ci_build, :success, runner: runner) }

    subject { described_class.new(current_user: user, runner: runner, params: params).execute }

    context 'user has access to the runner', :enable_admin_mode do
      let(:user) { admin }

      it 'returns jobs for the specified project' do
        expect(subject).to match_array([job_4])
      end
    end

    context 'user has no access to project builds' do
      let_it_be(:guest) { create(:user) }

      let(:user) { guest }

      before do
        project.add_guest(guest)
      end

      it 'returns no jobs' do
        expect(subject).to be_empty
      end
    end

    context 'without user' do
      let(:user) { nil }

      it 'returns no jobs' do
        expect(subject).to be_empty
      end
    end
  end
end
