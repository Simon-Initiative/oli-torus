/* eslint-disable react/prop-types */
import React from 'react';
import { useSelector } from 'react-redux';
import { selectProjectSlug, selectRevisionSlug } from '../store/app/slice';

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

  const url = `/authoring/project/${projectSlug}/preview/${revisionSlug}`;
  const windowName = `preview-${projectSlug}`;

  return (
    <nav className={`aa-header-nav top-panel${isVisible ? ' open' : ''}`}>
      {content.title}
      <PreviewButton url={url} windowName={windowName} />
    </nav>
  );
};

export default HeaderNav;
