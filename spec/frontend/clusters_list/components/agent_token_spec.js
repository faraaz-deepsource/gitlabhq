import { GlAlert, GlFormInputGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentToken from '~/clusters_list/components/agent_token.vue';
import {
  I18N_AGENT_TOKEN,
  INSTALL_AGENT_MODAL_ID,
  NAME_MAX_LENGTH,
} from '~/clusters_list/constants';
import { generateAgentRegistrationCommand } from '~/clusters_list/clusters_util';
import CodeBlock from '~/vue_shared/components/code_block.vue';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';

const kasAddress = 'kas.example.com';
const agentName = 'my-agent';
const agentToken = 'agent-token';
const kasVersion = '15.0.0';
const modalId = INSTALL_AGENT_MODAL_ID;

describe('InstallAgentModal', () => {
  let wrapper;

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCodeBlock = () => wrapper.findComponent(CodeBlock);
  const findCopyButton = () => wrapper.findComponent(ModalCopyButton);
  const findInput = () => wrapper.findComponent(GlFormInputGroup);

  const createWrapper = (newAgentName = agentName) => {
    const provide = {
      kasAddress,
      kasVersion,
    };

    const propsData = {
      agentName: newAgentName,
      agentToken,
      modalId,
    };

    wrapper = shallowMountExtended(AgentToken, {
      provide,
      propsData,
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('initial state', () => {
    it('shows basic agent installation instructions', () => {
      expect(wrapper.text()).toContain(I18N_AGENT_TOKEN.basicInstallTitle);
      expect(wrapper.text()).toContain(I18N_AGENT_TOKEN.basicInstallBody);
    });

    it('shows advanced agent installation instructions', () => {
      expect(wrapper.text()).toContain(I18N_AGENT_TOKEN.advancedInstallTitle);
    });

    it('shows agent token as an input value', () => {
      expect(findInput().props('value')).toBe(agentToken);
    });

    it('renders a copy button', () => {
      expect(findCopyButton().props()).toMatchObject({
        title: 'Copy command',
        text: generateAgentRegistrationCommand({
          name: agentName,
          token: agentToken,
          version: kasVersion,
          address: kasAddress,
        }),
        modalId,
      });
    });

    it('shows warning alert', () => {
      expect(findAlert().text()).toBe(I18N_AGENT_TOKEN.tokenSingleUseWarningTitle);
    });

    it('shows code block with agent installation command', () => {
      expect(findCodeBlock().props('code')).toContain(`helm upgrade --install ${agentName}`);
      expect(findCodeBlock().props('code')).toContain(`--namespace gitlab-agent-${agentName}`);
      expect(findCodeBlock().props('code')).toContain(`--set config.token=${agentToken}`);
      expect(findCodeBlock().props('code')).toContain(`--set config.kasAddress=${kasAddress}`);
      expect(findCodeBlock().props('code')).toContain(`--set image.tag=v${kasVersion}`);
    });

    it('truncates the namespace name if it exceeds the maximum length', () => {
      const newAgentName = 'agent-name-that-is-too-long-and-needs-to-be-truncated-to-use';
      createWrapper(newAgentName);

      expect(findCodeBlock().props('code')).toContain(
        `--namespace gitlab-agent-${newAgentName.substring(0, NAME_MAX_LENGTH)}`,
      );
    });
  });
});
