import React, { useCallback, useRef } from 'react';
import { useDispatch } from 'react-redux';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import { SimplifiedRightMenu } from './components/RightMenu/SimplifiedRightMenu';
import { ScreenList } from './components/ScreenList/ScreenList';

import { SidePanel } from './components/SidePanel';
import { changeEditMode } from './store/app/slice';

interface PanelState {
  left: boolean;
  right: boolean;
  top: boolean;
  bottom: boolean;
}

interface AuthoringPageEditorProps {
  panelState: PanelState;
  handlePanelStateChange: (p: Partial<PanelState>) => void;
}

export const AuthoringFlowchartPageEditor: React.FC<AuthoringPageEditorProps> = ({
  panelState,
  handlePanelStateChange,
}) => {
  const authoringContainer = useRef<HTMLDivElement>(null);
  const dispatch = useDispatch();
  const onFlowchartMode = useCallback(() => {
    dispatch(changeEditMode({ mode: 'flowchart' }));
  }, [dispatch]);

  return (
    <div id="advanced-authoring" className="advanced-authoring flowchart-editor ">
      <HeaderNav
        panelState={panelState}
        isVisible={panelState.top}
        authoringContainer={authoringContainer}
      />
      <SidePanel
        position="left"
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ left: !panelState.left })}
      >
        <ScreenList onFlowchartMode={onFlowchartMode} />
      </SidePanel>

      <EditingCanvas />

      <SidePanel
        position="right"
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ right: !panelState.right })}
      >
        <SimplifiedRightMenu />
      </SidePanel>
    </div>
  );
};
