import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
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
import { DiagnosticsTrigger } from '../components/Modal/DiagnosticsWindow';
interface HeaderNavProps {
  panelState: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { panelState, isVisible } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const paths = useSelector(selectPaths);
  const isReadOnly = useSelector(selectReadOnly);
  const isAdmin = useSelector(selectIsAdmin);
  const PANEL_SIDE_WIDTH = '270px';

  const dispatch = useDispatch();

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  const handleReadOnlyClick = () => {
    // TODO: show a modal offering to confirm if you want to disable read only
    // but changes that were made will be lost. better right now to just use browser refresh
  };

  const handleDiagnosticsClick = () => {
    dispatch(setShowDiagnosticsWindow({ show: true }));
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
            <AddComponentToolbar />
            <ComponentSearchContextMenu />
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
            <DiagnosticsTrigger onClick={handleDiagnosticsClick} />
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
            )}
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

export default HeaderNav;
