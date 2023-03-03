import React, { useRef } from 'react';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import { SimplifiedRightMenu } from './components/RightMenu/SimplifiedRightMenu';
import SequenceEditor from './components/SequenceEditor/SequenceEditor';
import { SidePanel } from './components/SidePanel';

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

  return (
    <div id="advanced-authoring" className={`advanced-authoring`}>
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
        <SequenceEditor />
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
