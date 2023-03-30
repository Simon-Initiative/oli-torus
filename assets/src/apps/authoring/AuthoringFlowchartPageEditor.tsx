import React, { useCallback, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../delivery/store/features/activities/slice';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import { applyTemplate } from './components/Flowchart/flowchart-actions/apply-template';
import { Template } from './components/Flowchart/template-types';
import { TemplatePicker } from './components/Flowchart/TemplatePicker';

import { ScreenList } from './components/ScreenList/ScreenList';

import { SidePanel } from './components/SidePanel';
import { changeEditMode } from './store/app/slice';
import FlowchartHeaderNav from './components/FlowchartHeaderNav';
import RightMenu from './components/RightMenu/RightMenu';

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
  const activity = useSelector(selectCurrentActivity);

  const requiresTemplateSelection = activity && !activity?.authoring?.flowchart?.templateApplied;
  const onApplyTemplate = useCallback(
    (template: Template) => {
      if (!activity || !template) return;
      dispatch(applyTemplate({ screenId: activity.id, template }));
    },
    [activity, dispatch],
  );

  return (
    <div
      id="advanced-authoring"
      className="advanced-authoring flowchart-editor "
      ref={authoringContainer}
    >
      <FlowchartHeaderNav
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
        <RightMenu />
        {requiresTemplateSelection && (
          <TemplatePicker
            screenType={activity?.authoring?.flowchart?.screenType}
            onPick={onApplyTemplate}
          />
        )}
      </SidePanel>
    </div>
  );
};
