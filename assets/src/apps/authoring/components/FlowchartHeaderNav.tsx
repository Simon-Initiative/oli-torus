import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../delivery/store/features/activities/slice';
import {
  selectIsAdmin,
  selectPaths,
  selectProjectSlug,
  selectReadOnly,
  selectRevisionSlug,
  setShowDiagnosticsWindow,
  setShowScoringOverview,
} from '../store/app/slice';
import AddComponentToolbar from './ComponentToolbar/AddComponentToolbar';
import ComponentSearchContextMenu from './ComponentToolbar/ComponentSearchContextMenu';
import UndoRedoToolbar from './ComponentToolbar/UndoRedoToolbar';
import { getScreenQuestionType } from './Flowchart/paths/path-options';
import { DiagnosticsTrigger } from './Modal/DiagnosticsWindow';
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

const FlowchartHeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
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

  const handleReadOnlyClick = () => {
    // TODO: show a modal offering to confirm if you want to disable read only
    // but changes that were made will be lost. better right now to just use browser refresh
  };

  const handleScoringOverviewClick = () => {
    dispatch(setShowScoringOverview({ show: true }));
  };

  return (
    paths && (
      <nav
        className={`aa-header-nav top-panel overflow-hidden${
          isVisible ? ' open' : ''
        } d-flex aa-panel-section-title-bar`}
        style={{
          alignItems: 'center',
          left: panelState['left'] ? '335px' : '65px', // 335 = PANEL_SIDE_WIDTH + 65px (torus sidebar width)
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
        }}
      >
        <div className="btn-toolbar" role="toolbar">
          <div className="btn-group pl-3 align-items-center" role="group" aria-label="Third group">
            <UndoRedoToolbar />
          </div>
          <div className="btn-group px-3 border-right align-items-center" role="group">
            <AddComponentToolbar
              frequentlyUsed={staticComponents}
              authoringContainer={props.authoringContainer}
              showMoreComponentsMenu={false}
              showPasteComponentOption={false}
            />

            <AddComponentToolbar
              disabled={hasQuestion}
              frequentlyUsed={questionComponents}
              authoringContainer={props.authoringContainer}
              showMoreComponentsMenu={false}
            />

            {/* <ComponentSearchContextMenu authoringContainer={props.authoringContainer} /> */}
          </div>

          <div className="btn-group pl-3 align-items-center" role="group" aria-label="Third group">
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
                <button className="px-2 btn btn-link" onClick={() => window.open(url, windowName)}>
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
            {/* <DiagnosticsTrigger onClick={handleDiagnosticsClick} />
            {isAdmin && (
              <OverlayTrigger
                placement="bottom"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    Revision History (Admin)
                  </Tooltip>
                }
              >
                <span>
                  <button
                    className="px-2 btn btn-link"
                    onClick={(e) => {
                      e.stopPropagation();
                      // open revistion history in same window
                      window.open(`/project/${projectSlug}/history/slug/${revisionSlug}`, '_self');
                    }}
                  >
                    <i
                      className="fa fa-history"
                      style={{ fontSize: 32, color: '#333', verticalAlign: 'middle' }}
                    />
                  </button>
                </span>
              </OverlayTrigger>
            )} */}

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
        </div>
      </nav>
    )
  );
};

export default FlowchartHeaderNav;
