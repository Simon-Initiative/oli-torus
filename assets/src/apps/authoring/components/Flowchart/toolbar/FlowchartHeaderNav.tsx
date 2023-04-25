import React, { useCallback } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../../delivery/store/features/activities/slice';
import {
  selectPaths,
  selectProjectSlug,
  selectReadOnly,
  selectRevisionSlug,
  setShowScoringOverview,
} from '../../../store/app/slice';
import AddComponentToolbar from '../../ComponentToolbar/AddComponentToolbar';
import UndoRedoToolbar from '../../ComponentToolbar/UndoRedoToolbar';
import { verifyFlowchartLesson } from '../flowchart-actions/verify-flowchart-lesson';
import { getScreenQuestionType } from '../paths/path-options';

interface HeaderNavProps {
  panelState: any;
  isVisible: boolean;
  authoringContainer: React.RefObject<HTMLElement>;
  onToggleExport?: () => void;
}

// 'janus-fill-blanks'
// 'janus-navigation-button'

const staticComponents: string[] = [
  'janus_text_flow',
  'janus_image',
  'janus_video',
  //'janus_image_carousel',
  'janus_popup',
  'janus_audio',
  'janus_capi_iframe',
];
const questionComponents: string[] = [
  'janus_mcq',
  'janus_input_text',
  'janus_dropdown',
  'janus_input_number',
  'janus_slider',
  'janus_multi_line_text',
];

export const FlowchartHeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { panelState, isVisible } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const paths = useSelector(selectPaths);
  const dispatch = useDispatch();
  const isReadOnly = useSelector(selectReadOnly);
  const currentActivity = useSelector(selectCurrentActivity);

  const questionType = getScreenQuestionType(currentActivity);
  const hasQuestion = questionType !== 'none';

  const PANEL_SIDE_WIDTH = '270px';

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  const previewLesson = useCallback(async () => {
    await dispatch(verifyFlowchartLesson({}));
    window.open(url, windowName);
  }, [dispatch, url, windowName]);

  const handleReadOnlyClick = () => {
    // TODO: show a modal offering to confirm if you want to disable read only
    // but changes that were made will be lost. better right now to just use browser refresh
  };

  const handleScoringOverviewClick = () => {
    dispatch(setShowScoringOverview({ show: true }));
  };

  return (
    paths && (
      <div className="component-toolbar">
        <div className="toolbar-column" style={{ flexBasis: '10%' }}>
          <label>Undo</label>
          <button className="undo-redo-button">U</button>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '10%' }}>
          <label>Undo</label>
          <button className="undo-redo-button">R</button>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '42%' }}>
          <label>Static Components</label>
          <div className="toolbar-buttons">
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
          </div>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '42%' }}>
          <label>Question Components</label>
          <div className="toolbar-buttons">
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
            <button className="component-button">?</button>
          </div>
        </div>

        <div className="toolbar-column" style={{ flexBasis: '14%' }}>
          <label>Scoring</label>
          <div className="toolbar-buttons">
            <button className="component-button">?</button>
            <button className="component-button">?</button>
          </div>
        </div>

        {/* <div className="btn-toolbar" role="toolbar">
          <div className="btn-group pl-3 align-items-center" role="group">
            <UndoRedoToolbar />
          </div>
          <div className="btn-group px-3 border-right align-items-center" role="group">
            <div>
              <label>Static Components</label>
              <AddComponentToolbar
                frequentlyUsed={staticComponents}
                authoringContainer={props.authoringContainer}
                showMoreComponentsMenu={false}
                showPasteComponentOption={false}
              />
            </div>

            <div>
              <label>Question Components</label>

              <AddComponentToolbar
                disabled={hasQuestion}
                frequentlyUsed={questionComponents}
                authoringContainer={props.authoringContainer}
                showMoreComponentsMenu={false}
              />
            </div>
          </div>

          <div className="btn-group pl-3 align-items-center" role="group">
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Preview
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" onClick={previewLesson}>
                  <img src={`${paths.images}/icons/icon-preview.svg`}></img>
                </button>
              </span>
            </OverlayTrigger>
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Scoring Overview
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" onClick={handleScoringOverviewClick}>
                  <i
                    className="fa fa-star"
                    style={{ fontSize: 32, color: '#333', verticalAlign: 'middle' }}
                  />
                </button>
              </span>
            </OverlayTrigger>

            {isReadOnly && (
              <OverlayTrigger
                placement="bottom"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    Read Only
                  </Tooltip>
                }
              >
                <span>
                  <button className="px-2 btn btn-link" onClick={handleReadOnlyClick}>
                    <i
                      className="fa fa-exclamation-triangle"
                      style={{ fontSize: 40, color: 'goldenrod' }}
                    />
                  </button>
                </span>
              </OverlayTrigger>
            )}
          </div>
        </div> */}
      </div>
    )
  );
};

export default FlowchartHeaderNav;
