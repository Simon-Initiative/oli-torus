import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectIsAdmin,
  selectProjectSlug,
  selectRevisionSlug,
  setShowDiagnosticsWindow,
  setShowScoringOverview,
} from '../store/app/slice';
import AddComponentToolbar from './ComponentToolbar/AddComponentToolbar';
import ComponentSearchContextMenu from './ComponentToolbar/ComponentSearchContextMenu';
import UndoRedoToolbar from './ComponentToolbar/UndoRedoToolbar';
import { DiagnosticsTrigger } from './Modal/DiagnosticsWindow';

interface HeaderNavProps {
  panelState: any;
  isVisible: boolean;
  authoringContainer: React.RefObject<HTMLElement>;
  onToggleExport?: () => void;
  sidebarExpanded?: boolean;
}

const ExpertHeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { panelState, isVisible, sidebarExpanded } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const isAdmin = useSelector(selectIsAdmin);
  const PANEL_SIDE_WIDTH = '270px';

  const dispatch = useDispatch();

  const handleDiagnosticsClick = () => {
    dispatch(setShowDiagnosticsWindow({ show: true }));
  };

  const handleScoringOverviewClick = () => {
    dispatch(setShowScoringOverview({ show: true }));
  };

  return (
    <nav
      className={`aa-header-nav top-panel overflow-hidden${
        isVisible ? ' open' : ''
      }  aa-panel-section-title-bar ${!sidebarExpanded ? '' : 'ml-[135px]'}`}
      style={{
        alignItems: 'center',
        left: panelState['left'] ? '335px' : '65px', // 335 = PANEL_SIDE_WIDTH + 65px (torus sidebar width)
        right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
      }}
    >
      <div className="btn-toolbar" role="toolbar">
        <div className="btn-group pl-3 align-items-center" role="group" aria-label="Third group">
          <UndoRedoToolbar />
          <AddComponentToolbar authoringContainer={props.authoringContainer} />
          <ComponentSearchContextMenu authoringContainer={props.authoringContainer} />
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
              <button
                className="px-2 btn btn-link"
                onClick={handleScoringOverviewClick}
                aria-label="Scoring Overview"
              >
                <i
                  className="fa fa-star"
                  style={{
                    fontSize: 24,
                    color: '#333',
                    verticalAlign: 'text-bottom',
                    paddingBottom: '4px',
                  }}
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
                  aria-label="Revision History"
                  onClick={(e) => {
                    e.stopPropagation();
                    // open revistion history in same window
                    window.open(`/project/${projectSlug}/history/slug/${revisionSlug}`, '_self');
                  }}
                >
                  <i
                    className="fa fa-history"
                    style={{
                      fontSize: 24,
                      color: '#333',
                      verticalAlign: 'text-bottom',
                      paddingBottom: '4px',
                    }}
                  />
                </button>
              </span>
            </OverlayTrigger>
          )}

          {isAdmin && props.onToggleExport && (
            <OverlayTrigger
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  Template Export
                </Tooltip>
              }
            >
              <span>
                <button
                  className="px-2 btn btn-link"
                  onClick={props.onToggleExport}
                  aria-label="Template Export"
                >
                  <i
                    className="fa fa-file-export"
                    style={{
                      fontSize: 24,
                      color: '#333',
                      verticalAlign: 'text-bottom',
                      paddingBottom: '4px',
                    }}
                  />
                </button>
              </span>
            </OverlayTrigger>
          )}
        </div>
      </div>
    </nav>
  );
};

export default ExpertHeaderNav;
