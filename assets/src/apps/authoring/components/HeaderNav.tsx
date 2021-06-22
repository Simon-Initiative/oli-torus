/* eslint-disable react/prop-types */
import React from 'react';
import { useSelector } from 'react-redux';
import { selectProjectSlug, selectRevisionSlug, selectPaths } from '../store/app/slice';

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const PreviewButton: React.FC<{ url: string; windowName?: string }> = (props) => (
  <a
    className="btn btn-sm btn-outline-primary"
    onClick={() => window.open(props.url, props.windowName)}
  >
    Preview <i className="las la-external-link-alt ml-1"></i>
  </a>
);

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  const projectSlug = useSelector(selectProjectSlug);
  const revisionSlug = useSelector(selectRevisionSlug);
  const paths = useSelector(selectPaths);

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;
  return (
    <nav className={`aa-header-nav top-panel${isVisible ? ' open' : ''} d-flex justify-content-between`}
          style={{alignItems:'center'}}>
      <div>
        <div className="btn-group" role="group">
          <div className="pr-3 border-right">
            INFINISCOPE{/* Place for Logo */}
          </div>
          <div className="pl-3">
            {content.title}
          </div>
        </div>
      </div>
      <div className="btn-toolbar" role="toolbar">
        <div className="btn-group pr-3 border-right" role="group">
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-text.svg`}></img>
          </div>
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-image.svg`}></img>
          </div>
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-video.svg`}></img>
          </div>
        </div>
        <div className="btn-group px-3 border-right" role="group">
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-navButton.svg`}></img>
          </div>
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-multiChoice.svg`}></img>
          </div>
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-userInput.svg`}></img>
          </div>
        </div>
        <div className="btn-group pl-3" role="group">
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-componentList.svg`}></img>
          </div>
        </div>
      </div>
      <div>
        <div className="btn-group" role="group" aria-label="Third group">
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-preview.svg`}></img>
            <PreviewButton url={url} windowName={windowName} />
          </div>
          <div className="px-2">
            <img src={`${paths.images}/icons/icon-publish.svg`}></img>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default HeaderNav;
