/* eslint-disable react/prop-types */
import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectProjectSlug, selectRevisionSlug, selectPaths } from '../store/app/slice';

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const paths = useSelector(selectPaths);

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;
  return (
    <nav
      className={`aa-header-nav top-panel${
        isVisible ? ' open' : ''
      } d-flex justify-content-between`}
      style={{ alignItems: 'center' }}
    >
      <div>
        <div className="btn-group align-items-center" role="group">
          <div className="pr-3 border-right">INFINISCOPE{/* Place for Logo */}</div>
          <div className="pl-3">{content.title}</div>
        </div>
      </div>
      <div className="btn-toolbar" role="toolbar">
        <div className="btn-group pr-3 border-right align-items-center" role="group">
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Text
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-text.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Image
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-image.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Video
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-video.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
        </div>
        <div className="btn-group px-3 border-right align-items-center" role="group">
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Navigation Button
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-navButton.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Multiple Choice
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-multiChoice.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                User Input
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-userInput.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
        </div>
        <div className="btn-group pl-3 align-items-center" role="group">
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                All Components
              </Tooltip>
            }
          >
            <span>
              <button className="px-2 btn btn-link" disabled>
                <img src={`${paths.images}/icons/icon-componentList.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
        </div>
      </div>
      <div>
        <div className="btn-group align-items-center" role="group" aria-label="Third group">
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
  );
};

export default HeaderNav;
