import React, { CSSProperties, useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { selectPageContent } from '../../store/features/page/slice';
import PageContent from './PageContent';

const AdaptivePageView: React.FC = () => {
  const page = useSelector(selectPageContent);
  const fieldRef = React.useRef<HTMLInputElement>(null);

  const defaultClasses: any[] = ['lesson-loaded', 'lessonView']; // TODO: 'previewView' instead based on context
  const [pageClasses, setPageClasses] = useState<any[]>([]);
  const [ensembleClasses, setEnsembleClasses] = useState<any[]>([]);

  // Background
  const backgroundClasses = ['background'];
  const backgroundStyles: CSSProperties = {};
  if (page?.custom?.backgroundImageURL) {
    backgroundStyles.backgroundImage = `url('${page.custom.backgroundImageURL}')`;
  }
  if (page?.custom?.backgroundImageScaleContent) {
    backgroundClasses.push(`background-scaled`);
  }

  useEffect(() => {
    // clear body classes on init for a clean slate
    document.body.className = '';
  }, []);

  useEffect(() => {
    if (!page) {
      return;
    }

    // set page class on change
    if (page?.custom?.viewerSkin) {
      setPageClasses([`skin-${page.custom.viewerSkin}`]);
    }
  }, [page]);

  useEffect(() => {
    // clear the body classes in prep for the real classes
    document.body.className = '';

    // strip whitespace and update body class list with page classes
    document.body.classList.add(...pageClasses);
  }, [pageClasses]);

  return (
    <div ref={fieldRef} className={ensembleClasses.join(' ')}>
      <div>PAGE HEADER</div>
      <div className={backgroundClasses.join(' ')} style={backgroundStyles} />
      {page ? <PageContent /> : <div>loading...</div>}
      <div>PAGE CHECK STATE</div>
      <div className="beagleContainer beagleContainer-behindStage" />
    </div>
  );
};

export default AdaptivePageView;
