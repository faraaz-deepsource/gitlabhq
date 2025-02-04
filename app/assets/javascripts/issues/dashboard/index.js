import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import IssuesDashboardApp from './components/issues_dashboard_app.vue';

export function mountIssuesDashboardApp() {
  const el = document.querySelector('.js-issues-dashboard');

  if (!el) {
    return null;
  }

  Vue.use(VueApollo);

  const {
    calendarPath,
    emptyStateSvgPath,
    hasBlockedIssuesFeature,
    hasIssuableHealthStatusFeature,
    hasIssueWeightsFeature,
    hasScopedLabelsFeature,
    isPublicVisibilityRestricted,
    isSignedIn,
    rssPath,
  } = el.dataset;

  return new Vue({
    el,
    name: 'IssuesDashboardRoot',
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(),
    }),
    provide: {
      calendarPath,
      emptyStateSvgPath,
      hasBlockedIssuesFeature: parseBoolean(hasBlockedIssuesFeature),
      hasIssuableHealthStatusFeature: parseBoolean(hasIssuableHealthStatusFeature),
      hasIssueWeightsFeature: parseBoolean(hasIssueWeightsFeature),
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
      isPublicVisibilityRestricted: parseBoolean(isPublicVisibilityRestricted),
      isSignedIn: parseBoolean(isSignedIn),
      rssPath,
    },
    render: (createComponent) => createComponent(IssuesDashboardApp),
  });
}
