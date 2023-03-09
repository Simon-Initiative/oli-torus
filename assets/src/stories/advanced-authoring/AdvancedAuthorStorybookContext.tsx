import React from 'react';
import { Provider } from 'react-redux';
import adaptiveStore from '../../apps/authoring/store/storybook';

export const AdvancedAuthorStorybookContext: React.FC = ({ children }) => (
  <div className="flowchart-editor advanced-authoring storybook h-[450px]">
    <Provider store={adaptiveStore}>{children}</Provider>
  </div>
);

AdvancedAuthorStorybookContext.displayName = 'AdvancedAuthorStorybookContext';
