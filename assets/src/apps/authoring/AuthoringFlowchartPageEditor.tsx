import React, { useCallback, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../delivery/store/features/activities/slice';
import EditingCanvas from './components/EditingCanvas/EditingCanvas';
import { FlowchartErrorDisplay } from './components/Flowchart/FlowchartErrorMessages';
import { TemplatePicker } from './components/Flowchart/TemplatePicker';
import { applyTemplate } from './components/Flowchart/flowchart-actions/apply-template';
import { Template } from './components/Flowchart/template-types';
import FlowchartHeaderNav from './components/Flowchart/toolbar/FlowchartHeaderNav';
import RightMenu from './components/RightMenu/RightMenu';
import { ScreenList } from './components/ScreenList/ScreenList';
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
  sidebarExpanded?: boolean;
}

export const AuthoringFlowchartPageEditor: React.FC<AuthoringPageEditorProps> = ({
  panelState,
  sidebarExpanded,
}) => {
  const authoringContainer = useRef<HTMLDivElement>(null);
  const dispatch = useDispatch();
  const onFlowchartMode = useCallback(() => {
    dispatch(changeEditMode({ mode: 'flowchart' }));
  }, [dispatch]);
  const activity = useSelector(selectCurrentActivity);

  const requiresTemplateSelection = activity && !activity?.authoring?.flowchart?.templateApplied;

  const onCancelTemplate = useCallback(() => {
    if (!activity) return;
    dispatch(applyTemplate({ screenId: activity.id, template: null }));
  }, [activity, dispatch]);

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
      className={`advanced-authoring flowchart-editor ${!sidebarExpanded ? '' : 'ml-[135px]'}`}
      ref={authoringContainer}
    >
      <FlowchartHeaderNav
        panelState={panelState}
        isVisible={panelState.top}
        authoringContainer={authoringContainer}
      />
      <ScreenList onFlowchartMode={onFlowchartMode} />
      <EditingCanvas />
      <div className="fixed-right-panel">
        <RightMenu />
      </div>
      {requiresTemplateSelection && (
        <TemplatePicker
          screenType={activity?.authoring?.flowchart?.screenType}
          onPick={onApplyTemplate}
          onCancel={onCancelTemplate}
        />
      )}
      <FlowchartErrorDisplay />
    </div>
  );
};
