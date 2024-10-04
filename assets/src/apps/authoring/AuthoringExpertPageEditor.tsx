import React, { useRef } from 'react';
import { useToggle } from '../../components/hooks/useToggle';
import { BottomPanel } from './BottomPanel';
import { AdaptivityEditor } from './components/AdaptivityEditor/AdaptivityEditor';
import { InitStateEditor } from './components/AdaptivityEditor/InitStateEditor';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import ExpertHeaderNav from './components/ExpertHeaderNav';
import { TemplateExporter } from './components/Flowchart/TemplateExporter';
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
  initialSidebarExpanded?: boolean;
}

export const AuthoringExpertPageEditor: React.FC<AuthoringPageEditorProps> = ({
  panelState,
  handlePanelStateChange,
  currentRule,
  initialSidebarExpanded,
}) => {
  const authoringContainer = useRef<HTMLDivElement>(null);
  const [exportOpen, toggleExport] = useToggle();

  return (
    <div id="advanced-authoring" className={`advanced-authoring`} ref={authoringContainer}>
      <ExpertHeaderNav
        onToggleExport={toggleExport}
        authoringContainer={authoringContainer}
        panelState={panelState}
        isVisible={panelState.top}
        initialSidebarExpanded={initialSidebarExpanded}
      />
      <SidePanel
        position="left"
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ left: !panelState.left })}
        initialSidebarExpanded={initialSidebarExpanded}
      >
        <LeftMenu />
      </SidePanel>
      <EditingCanvas />
      <BottomPanel
        panelState={panelState}
        onToggle={() => handlePanelStateChange({ bottom: !panelState.bottom })}
        initialSidebarExpanded={initialSidebarExpanded}
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
      {exportOpen && <TemplateExporter onToggleExport={toggleExport} />}
    </div>
  );
};
