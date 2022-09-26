import React, { useState } from 'react';
import { MediaItem } from 'types/media';
import { classNames } from 'utils/classNames';
import { MediaManager, SELECTION_TYPES } from './manager/MediaManager.controller';

type Source = 'library' | 'url';

interface Props {
  projectSlug: string;
  mimeFilter?: string[] | undefined;
  selectionType: SELECTION_TYPES;
  initialSelectionPaths?: string[];
  onMediaSelectionChange: (items: MediaItem[]) => void;
  onUrlChange: (url: string) => void;
}

export const UrlOrUpload = (props: Props) => {
  const { onUrlChange } = props;
  const [source, setSource] = useState<Source>('library');
  const [url, setUrl] = useState('');

  const whenActive = (s: Source, c: string) => s === source && c;

  return (
    <>
      <div className="nav nav-tabs mb-1">
        <button
          className={classNames('nav-link', whenActive('library', 'active'))}
          onClick={() => setSource('library')}
        >
          Media Library
        </button>
        <button
          className={classNames('nav-link', whenActive('url', 'active'))}
          onClick={() => setSource('url')}
        >
          External URL
        </button>
      </div>
      <div className="tab-content py-3">
        <div
          className={classNames('tab-pane fade', whenActive('library', 'show active'))}
          id="home"
          role="tabpanel"
          aria-labelledby="home-tab"
        >
          <MediaManager
            projectSlug={props.projectSlug}
            mimeFilter={props.mimeFilter}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={props.initialSelectionPaths}
            onSelectionChange={props.onMediaSelectionChange}
          />
        </div>
        <div
          className={classNames('tab-pane fade', whenActive('url', 'show active'))}
          id="profile"
          role="tabpanel"
          aria-labelledby="profile-tab"
        >
          <div className="media-url mb-4">
            <input
              className="form-control w-100"
              placeholder="Enter the media URL address"
              value={url}
              onChange={({ target: { value } }) => {
                setUrl(value);
                onUrlChange(value);
              }}
            />
          </div>
        </div>
      </div>
    </>
  );
};
