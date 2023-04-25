import React from 'react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { Provider } from 'react-redux';
import { ModalContainer } from '../../apps/authoring/components/AdvancedAuthoringModal';
import { setDebugConfig } from '../../apps/authoring/store/app/slice';
import adaptiveStore from '../../apps/authoring/store/storybook';

export const AdvancedAuthorStorybookContext: React.FC<{ className: string }> = ({
  children,
  className,
}) => {
  adaptiveStore.dispatch(setDebugConfig());

  return (
    <div className={`flowchart-editor advanced-authoring storybook h-[450px] ${className}`}>
      <ModalContainer>
        <DndProvider backend={HTML5Backend}>
          <Provider store={adaptiveStore}>{children}</Provider>
        </DndProvider>
      </ModalContainer>
    </div>
  );
};

AdvancedAuthorStorybookContext.displayName = 'AdvancedAuthorStorybookContext';
