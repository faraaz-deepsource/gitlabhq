# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController, type: :request do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo, name: 'awesome project', group: group) }
  let_it_be(:projects) { create_list(:project, 5, :public, :repository, :wiki_repo) }

  before do
    login_as(user)
  end

  def send_search_request(params)
    get search_path, params: params
  end

  shared_examples 'an efficient database result' do
    it 'avoids N+1 database queries' do
      create(object, *creation_traits, creation_args)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { send_search_request(params) }
      expect(response.body).to include('search-results') # Confirm there are search results to prevent false positives

      projects.each do |project|
        creation_args[:source_project] = project if creation_args.key?(:source_project)
        creation_args[:project] = project if creation_args.key?(:project)
        create(object, *creation_traits, creation_args)
      end

      expect { send_search_request(params) }.not_to exceed_all_query_limit(control).with_threshold(threshold)
      expect(response.body).to include('search-results') # Confirm there are search results to prevent false positives
    end
  end

  describe 'GET /search' do
    let(:creation_traits) { [] }

    context 'for issues scope' do
      let(:object) { :issue }
      let(:creation_args) { { project: project, title: 'foo' } }
      let(:params) { { search: 'foo', scope: 'issues' } }
      # some N+1 queries still exist
      # each issue runs an extra query for group namespaces
      let(:threshold) { 1 }

      it_behaves_like 'an efficient database result'
    end

    context 'for merge_requests scope' do
      let(:creation_traits) { [:unique_branches] }
      let(:object) { :merge_request }
      let(:creation_args) { { source_project: project, title: 'bar' } }
      let(:params) { { search: 'bar', scope: 'merge_requests' } }
      # some N+1 queries still exist
      # each merge request runs an extra query for project routes
      let(:threshold) { 4 }

      it_behaves_like 'an efficient database result'
    end

    context 'for projects scope' do
      let(:creation_traits) { [:public] }
      let(:object) { :project }
      let(:creation_args) { { name: 'project' } }
      let(:params) { { search: 'project', scope: 'projects' } }
      # some N+1 queries still exist
      # each project requires 3 extra queries
      #   - one count for forks
      #   - one count for open MRs
      #   - one count for open Issues
      # there are 4 additional queries run for the logged in user:
      # (1) user preferences, (1) user statuses, (1) user details, (1) users
      let(:threshold) { 17 }

      it_behaves_like 'an efficient database result'
    end

    context 'for milestones scope' do
      let(:object) { :milestone }
      let(:creation_args) { { project: project } }
      let(:params) { { search: 'title', scope: 'milestones' } }
      let(:threshold) { 0 }

      it_behaves_like 'an efficient database result'
    end

    context 'for users scope' do
      let(:object) { :user }
      let(:creation_args) { { name: 'georgia' } }
      let(:params) { { search: 'georgia', scope: 'users' } }
      let(:threshold) { 0 }

      it_behaves_like 'an efficient database result'
    end

    context 'for notes scope' do
      let(:creation_traits) { [:on_commit] }
      let(:object) { :note }
      let(:creation_args) { { project: project, note: 'hello world' } }
      let(:params) { { search: 'hello world', scope: 'notes', project_id: project.id } }
      let(:threshold) { 0 }

      it_behaves_like 'an efficient database result'
    end

    context 'for blobs scope' do
      # blobs are enabled for project search only in basic search
      let(:params_for_one) { { search: 'test', project_id: project.id, scope: 'blobs', per_page: 1 } }
      let(:params_for_many) { { search: 'test', project_id: project.id, scope: 'blobs', per_page: 5 } }

      it 'avoids N+1 database queries' do
        control = ActiveRecord::QueryRecorder.new { send_search_request(params_for_one) }
        expect(response.body).to include('search-results') # Confirm search results to prevent false positives

        expect { send_search_request(params_for_many) }.not_to exceed_query_limit(control.count)
        expect(response.body).to include('search-results') # Confirm search results to prevent false positives
      end
    end

    context 'for commits scope' do
      let(:params_for_one) { { search: 'test', project_id: project.id, scope: 'commits', per_page: 1 } }
      let(:params_for_many) { { search: 'test', project_id: project.id, scope: 'commits', per_page: 5 } }

      it 'avoids N+1 database queries' do
        control = ActiveRecord::QueryRecorder.new { send_search_request(params_for_one) }
        expect(response.body).to include('search-results') # Confirm search results to prevent false positives

        expect { send_search_request(params_for_many) }.not_to exceed_query_limit(control.count)
        expect(response.body).to include('search-results') # Confirm search results to prevent false positives
      end
    end

    context 'when searching by SHA' do
      let(:sha) { '6d394385cf567f80a8fd85055db1ab4c5295806f' }

      it 'finds a commit and redirects to its page' do
        send_search_request({ search: sha, scope: 'projects', project_id: project.id })

        expect(response).to redirect_to(project_commit_path(project, sha))
      end

      it 'finds a commit in uppercase and redirects to its page' do
        send_search_request( { search: sha.upcase, scope: 'projects', project_id: project.id })

        expect(response).to redirect_to(project_commit_path(project, sha))
      end

      it 'finds a commit with a partial sha and redirects to its page' do
        send_search_request( { search: sha[0..10], scope: 'projects', project_id: project.id })

        expect(response).to redirect_to(project_commit_path(project, sha))
      end

      it 'redirects to the commit even if another scope result is returned' do
        create(:note, project: project, note: "This is the #{sha}")
        send_search_request( { search: sha, scope: 'projects', project_id: project.id })

        expect(response).to redirect_to(project_commit_path(project, sha))
      end

      it 'goes to search results with the force_search_results param set' do
        send_search_request({ search: sha, force_search_results: true, project_id: project.id })

        expect(response).not_to redirect_to(project_commit_path(project, sha))
      end

      context 'when user cannot read_code' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_code, project).and_return(false)
        end

        it 'does not redirect' do
          send_search_request({ search: sha, project_id: project.id })

          expect(response).not_to redirect_to(project_commit_path(project, sha))
        end
      end

      it 'does not redirect if commit sha not found in project' do
        send_search_request({ search: '23594bc765e25c5b22c17a8cca25ebd50f792598', project_id: project.id })

        expect(response).not_to redirect_to(project_commit_path(project, sha))
      end

      it 'does not redirect if not using project scope' do
        send_search_request({ search: sha, group_id: project.root_namespace.id })

        expect(response).not_to redirect_to(project_commit_path(project, sha))
      end
    end
  end
end
