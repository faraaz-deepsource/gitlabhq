# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::AgentTokensFinder do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:agent) { create(:cluster_agent, project: project) }
    let(:user) { create(:user, maintainer_projects: [project]) }

    let_it_be(:active_agent_tokens) do
      [
        create(:cluster_agent_token, agent: agent),
        create(:cluster_agent_token, agent: agent)
      ]
    end

    let_it_be(:revoked_agent_tokens) do
      [
        create(:cluster_agent_token, :revoked, agent: agent),
        create(:cluster_agent_token, :revoked, agent: agent)
      ]
    end

    let_it_be(:token_for_different_agent) { create(:cluster_agent_token, agent: create(:cluster_agent)) }

    subject(:execute) { described_class.new(agent, user).execute }

    it { is_expected.to match_array(active_agent_tokens + revoked_agent_tokens) }

    context 'when filtering by status=active' do
      subject(:execute) { described_class.new(agent, user, status: 'active').execute }

      it { is_expected.to match_array(active_agent_tokens) }
    end

    context 'when filtering by status=revoked' do
      subject(:execute) { described_class.new(agent, user, status: 'revoked').execute }

      it { is_expected.to match_array(revoked_agent_tokens) }
    end

    context 'when user does not have permission' do
      let(:user) { create(:user) }

      before do
        project.add_reporter(user)
      end

      it { is_expected.to eq ::Clusters::AgentToken.none }
    end

    context 'when current_user is nil' do
      it 'returns an empty list' do
        result = described_class.new(agent, nil).execute
        expect(result).to eq ::Clusters::AgentToken.none
      end
    end

    context 'when agent is nil' do
      it 'returns an empty list' do
        result = described_class.new(nil, user).execute
        expect(result).to eq ::Clusters::AgentToken.none
      end
    end
  end
end
