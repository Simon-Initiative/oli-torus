/* eslint-disable react/prop-types */
import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectPaths, selectProjectSlug, selectRevisionSlug } from '../store/app/slice';
import AddComponentToolbar from './ComponentToolbar/AddComponentToolbar';
import ComponentSearchContextMenu from './ComponentToolbar/ComponentSearchContextMenu';

interface HeaderNavProps {
  panelState: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { panelState, isVisible } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const paths = useSelector(selectPaths);
  const PANEL_SIDE_WIDTH = '270px';

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  return (
    paths && (
      <nav
        className={`aa-header-nav top-panel${
          isVisible ? ' open' : ''
        } d-flex aa-panel-section-title-bar`}
        style={{
          alignItems: 'center',
          left: panelState['left'] ? '335px' : '65px', // 335 = PANEL_SIDE_WIDTH + 65px (torus sidebar width)
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
        }}
      >
        <div className="btn-toolbar" role="toolbar">
          <AddComponentToolbar />
          <div className="btn-group px-3 border-right align-items-center" role="group">
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
                  Publish
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" disabled>
                  <img src={`${paths.images}/icons/icon-publish.svg`}></img>
                </button>
              </span>
            </OverlayTrigger>
          </div>
        </div>
      </nav>
    )
  );
};

export default HeaderNav;
