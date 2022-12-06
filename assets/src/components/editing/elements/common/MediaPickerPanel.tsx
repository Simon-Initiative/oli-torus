import React, { useCallback, useState } from 'react';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from '../../../media/manager/MediaManager';
import { UrlOrUpload } from '../../../media/UrlOrUpload';
import { SlideOutPanel } from './SlideOutPanel';

export interface MediaInfo {
  url: string;
  mimeType?: string;
}

interface Props {
  projectSlug: string;
  mimeFilter?: string[];
  selectionType?: SELECTION_TYPES;
  initialSelectionPaths?: string[];
  onMediaChange: (media: MediaInfo[]) => void;
  open: boolean;
  onCancel: () => void;
}

/**
 * Component suitable for selecting an image from the media library, especially from within
 * an already open modal when we don't want to open modals on top of other modals. (which doesn't
 * work well with bootstrap style modals).
 *
 */
export const MediaPickerPanel: React.FC<Props> = ({
  projectSlug,
  onMediaChange,
  mimeFilter = MIMETYPE_FILTERS.IMAGE,
  selectionType = SELECTION_TYPES.SINGLE,
  initialSelectionPaths = [],
  open,
  onCancel,
}) => {
  const [url, setUrl] = useState(initialSelectionPaths.length > 0 ? initialSelectionPaths[0] : '');

  const onUrlChange = useCallback((url) => {
    setUrl(url);
  }, []);

  const onOk = useCallback(() => {
    onMediaChange([{ url, mimeType: 'image/png' }]);
  }, [onMediaChange, url]);

  return (
    <SlideOutPanel open={open}>
      <UrlOrUpload
        onUrlChange={onUrlChange}
        onMediaSelectionChange={onMediaChange}
        projectSlug={projectSlug}
        mimeFilter={mimeFilter}
        selectionType={selectionType}
        initialSelectionPaths={initialSelectionPaths}
      >
        <button className="btn btn-brimary" onClick={onOk}>
          Set External URL
        </button>
      </UrlOrUpload>
      <button className="btn btn-secondary" onClick={onCancel}>
        Cancel
      </button>
    </SlideOutPanel>
  );
};
