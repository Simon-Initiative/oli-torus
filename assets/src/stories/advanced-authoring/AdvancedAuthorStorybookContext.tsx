import React from 'react';
import { Provider } from 'react-redux';
import adaptiveStore from '../../apps/authoring/store/storybook';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { ModalContainer } from '../../apps/authoring/components/AdvancedAuthoringModal';

export const AdvancedAuthorStorybookContext: React.FC<{ className: string }> = ({
  children,
  className,
}) => (
  <div className={`flowchart-editor advanced-authoring storybook h-[450px] ${className}`}>
    <ModalContainer>
      <DndProvider backend={HTML5Backend}>
        <Provider store={adaptiveStore}>{children}</Provider>
      </DndProvider>
    </ModalContainer>
  </div>
);

AdvancedAuthorStorybookContext.displayName = 'AdvancedAuthorStorybookContext';
