// MyComponent.story.ts|tsx

import React from 'react';
import { ComponentMeta } from '@storybook/react';
import '../../../styles/index.scss';

import { AdvancedAuthorStorybookContext } from './AdvancedAuthorStorybookContext';
import { OnboardWizard } from '../../apps/authoring/components/Flowchart/onboard-wizard/OnboardWizard';

export const OnboardWizardStep1 = () => {
  return (
    <div className="advanced-authoring" id="advanced-authoring">
      <AdvancedAuthorStorybookContext className="">
        <OnboardWizard onSetupComplete={() => true} startStep={0} />
      </AdvancedAuthorStorybookContext>
    </div>
  );
};

export const OnboardWizardStep2 = () => {
  return (
    <div className="advanced-authoring" id="advanced-authoring">
      <AdvancedAuthorStorybookContext className="">
        <OnboardWizard onSetupComplete={() => true} startStep={1} />
      </AdvancedAuthorStorybookContext>
    </div>
  );
};

export const OnboardWizardStep3 = () => {
  return (
    <div className="advanced-authoring" id="advanced-authoring">
      <AdvancedAuthorStorybookContext className="">
        <OnboardWizard onSetupComplete={() => true} startStep={2} />
      </AdvancedAuthorStorybookContext>
    </div>
  );
};

export default {
  /* 👇 The title prop is optional.
   * See https://storybook.js.org/docs/react/configure/overview#configure-story-loading
   * to learn how to generate automatic titles
   */
  title: 'Advanced Authoring/Onboard Wizard',
  component: OnboardWizard,
} as ComponentMeta<typeof OnboardWizard>;
