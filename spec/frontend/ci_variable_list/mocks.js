import {
  ADD_MUTATION_ACTION,
  DELETE_MUTATION_ACTION,
  UPDATE_MUTATION_ACTION,
  variableTypes,
  groupString,
  instanceString,
  projectString,
} from '~/ci_variable_list/constants';

import addAdminVariable from '~/ci_variable_list/graphql/mutations/admin_add_variable.mutation.graphql';
import deleteAdminVariable from '~/ci_variable_list/graphql/mutations/admin_delete_variable.mutation.graphql';
import updateAdminVariable from '~/ci_variable_list/graphql/mutations/admin_update_variable.mutation.graphql';
import addGroupVariable from '~/ci_variable_list/graphql/mutations/group_add_variable.mutation.graphql';
import deleteGroupVariable from '~/ci_variable_list/graphql/mutations/group_delete_variable.mutation.graphql';
import updateGroupVariable from '~/ci_variable_list/graphql/mutations/group_update_variable.mutation.graphql';
import addProjectVariable from '~/ci_variable_list/graphql/mutations/project_add_variable.mutation.graphql';
import deleteProjectVariable from '~/ci_variable_list/graphql/mutations/project_delete_variable.mutation.graphql';
import updateProjectVariable from '~/ci_variable_list/graphql/mutations/project_update_variable.mutation.graphql';

import getAdminVariables from '~/ci_variable_list/graphql/queries/variables.query.graphql';
import getGroupVariables from '~/ci_variable_list/graphql/queries/group_variables.query.graphql';
import getProjectEnvironments from '~/ci_variable_list/graphql/queries/project_environments.query.graphql';
import getProjectVariables from '~/ci_variable_list/graphql/queries/project_variables.query.graphql';

export const devName = 'dev';
export const prodName = 'prod';

export const mockVariables = (kind) => {
  return [
    {
      __typename: `Ci${kind}Variable`,
      id: 1,
      key: 'my-var',
      masked: false,
      protected: true,
      value: 'variable_value',
      variableType: variableTypes.envType,
    },
    {
      __typename: `Ci${kind}Variable`,
      id: 2,
      key: 'secret',
      masked: true,
      protected: false,
      value: 'another_value',
      variableType: variableTypes.fileType,
    },
  ];
};

export const mockVariablesWithScopes = (kind) =>
  mockVariables(kind).map((variable) => {
    return { ...variable, environmentScope: '*' };
  });

const createDefaultVars = ({ withScope = true, kind } = {}) => {
  let base = mockVariables(kind);

  if (withScope) {
    base = mockVariablesWithScopes(kind);
  }

  return {
    __typename: `Ci${kind}VariableConnection`,
    limit: 200,
    pageInfo: {
      startCursor: 'adsjsd12kldpsa',
      endCursor: 'adsjsd12kldpsa',
      hasPreviousPage: false,
      hasNextPage: true,
    },
    nodes: base,
  };
};

const defaultEnvs = {
  __typename: 'EnvironmentConnection',
  nodes: [
    {
      __typename: 'Environment',
      id: 1,
      name: prodName,
    },
    {
      __typename: 'Environment',
      id: 2,
      name: devName,
    },
  ],
};

export const mockEnvs = defaultEnvs.nodes;

export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 1,
      environments: defaultEnvs,
    },
  },
};

export const mockProjectVariables = {
  data: {
    project: {
      __typename: 'Project',
      id: 1,
      ciVariables: createDefaultVars({ kind: projectString }),
    },
  },
};

export const mockGroupVariables = {
  data: {
    group: {
      __typename: 'Group',
      id: 1,
      ciVariables: createDefaultVars({ kind: groupString }),
    },
  },
};

export const mockAdminVariables = {
  data: {
    ciVariables: createDefaultVars({ withScope: false, kind: instanceString }),
  },
};

export const newVariable = {
  id: 3,
  environmentScope: 'new',
  key: 'AWS_RANDOM_THING',
  masked: true,
  protected: false,
  value: 'devops',
  variableType: variableTypes.variableType,
};

export const createProjectProps = () => {
  return {
    componentName: 'ProjectVariable',
    entity: 'project',
    fullPath: '/namespace/project/',
    id: 'gid://gitlab/Project/20',
    mutationData: {
      [ADD_MUTATION_ACTION]: addProjectVariable,
      [UPDATE_MUTATION_ACTION]: updateProjectVariable,
      [DELETE_MUTATION_ACTION]: deleteProjectVariable,
    },
    queryData: {
      ciVariables: {
        lookup: (data) => data?.project?.ciVariables,
        query: getProjectVariables,
      },
      environments: {
        lookup: (data) => data?.project?.environments,
        query: getProjectEnvironments,
      },
    },
  };
};

export const createGroupProps = () => {
  return {
    componentName: 'GroupVariable',
    entity: 'group',
    fullPath: '/my-group',
    id: 'gid://gitlab/Group/20',
    mutationData: {
      [ADD_MUTATION_ACTION]: addGroupVariable,
      [UPDATE_MUTATION_ACTION]: updateGroupVariable,
      [DELETE_MUTATION_ACTION]: deleteGroupVariable,
    },
    queryData: {
      ciVariables: {
        lookup: (data) => data?.group?.ciVariables,
        query: getGroupVariables,
      },
    },
  };
};

export const createInstanceProps = () => {
  return {
    componentName: 'InstanceVariable',
    entity: '',
    mutationData: {
      [ADD_MUTATION_ACTION]: addAdminVariable,
      [UPDATE_MUTATION_ACTION]: updateAdminVariable,
      [DELETE_MUTATION_ACTION]: deleteAdminVariable,
    },
    queryData: {
      ciVariables: {
        lookup: (data) => data?.ciVariables,
        query: getAdminVariables,
      },
    },
  };
};

export const createGroupProvide = () => ({
  isGroup: true,
  isProject: false,
});

export const createProjectProvide = () => ({
  isGroup: false,
  isProject: true,
});
