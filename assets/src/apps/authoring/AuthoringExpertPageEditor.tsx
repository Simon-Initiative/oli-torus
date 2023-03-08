import React, { useRef } from 'react';
import { BottomPanel } from './BottomPanel';
import { AdaptivityEditor } from './components/AdaptivityEditor/AdaptivityEditor';
import { InitStateEditor } from './components/AdaptivityEditor/InitStateEditor';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import HeaderNav from './components/HeaderNav';
import LeftMenu from './components/LeftMenu/LeftMenu';
import RightMenu from './components/RightMenu/RightMenu';
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
  currentRule: string;
}

export const AuthoringExpertPageEditor: React.FC<AuthoringPageEditorProps> = ({
  panelState,
  handlePanelStateChange,
  currentRule,
}) => {
  const authoringContainer = useRef<HTMLDivElement>(null);
  return (
    <div id="advanced-authoring" className={`advanced-authoring`} ref={authoringContainer}>
      <HeaderNav
        authoringContainer={authoringContainer}
        panelState={panelState}
        isVisible={panelState.top}
      />
      <SidePanel
        position="left"
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ left: !panelState.left })}
      >
        <LeftMenu />
      </SidePanel>
      <EditingCanvas />
      <BottomPanel
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ bottom: !panelState.bottom })}
      >
        {currentRule === 'initState' && <InitStateEditor authoringContainer={authoringContainer} />}
        {currentRule !== 'initState' && <AdaptivityEditor />}
      </BottomPanel>
      <SidePanel
        position="right"
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ right: !panelState.right })}
      >
        <RightMenu />
      </SidePanel>
    </div>
  );
};
