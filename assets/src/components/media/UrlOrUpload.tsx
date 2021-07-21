import React, { useState } from 'react';
import { Media, MediaItem } from 'types/media';
import { MediaManager, SELECTION_TYPES } from './manager/MediaManager.controller';

type Source = 'upload' | 'url';
interface Props {
  toggleDisableInsert?: (b: boolean) => void;
  onUrlChange: (url: string) => void;
  projectSlug: string;
  mimeFilter?: string[] | undefined;
  selectionType: SELECTION_TYPES;
  initialSelectionPaths: string[];
  onEdit: (updated: Media) => void;
  onMediaSelectionChange: (items: MediaItem[]) => void;
}
export const UrlOrUpload = (props: Props) => {
  const { toggleDisableInsert, onUrlChange } = props;
  const [source, setSource] = useState<Source>('url');
  const [url, setUrl] = useState('');

  const onChangeSource = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value === 'url') {
      setSource('url');
    }
    setSource(value === 'upload' ? 'upload' : 'url');
  };

  return (
    <>
      <div className="mb-2">
        <div className="form-check">
          <label
            className="form-check-label"
            htmlFor="inlineRadio2"
            onClick={() => setSource('url')}
          >
            <input
              className="form-check-input"
              defaultChecked={source === 'url'}
              onChange={onChangeSource}
              checked={source === 'url'}
              type="radio"
              name="inlineRadioOptions"
              id="inlineRadio2"
              value="url"
            />
            Use external media item
          </label>
          <div className="media-url mb-4">
            <input
              className="form-control w-100"
              placeholder="Enter the media URL address"
              value={url}
              disabled={source === 'upload'}
              onChange={({ target: { value } }) => {
                setUrl(value);
                onUrlChange(value);

                if (!toggleDisableInsert) {
                  return;
                }
                return value.trim() ? toggleDisableInsert(false) : toggleDisableInsert(true);
              }}
            />
          </div>
        </div>
        <div className="form-check mb-3">
          <label
            className="form-check-label"
            htmlFor="inlineRadio1"
            onClick={() => setSource('upload')}
          >
            <input
              className="form-check-input"
              defaultChecked={source === 'upload'}
              onChange={onChangeSource}
              checked={source !== 'url'}
              type="radio"
              name="inlineRadioOptions"
              id="inlineRadio1"
              value="upload"
            />
            Upload new or use existing media library item
          </label>
        </div>
      </div>
      <MediaManager
        disabled={source === 'url'}
        toggleDisableInsert={props.toggleDisableInsert}
        projectSlug={props.projectSlug}
        // eslint-disable-next-line
        onEdit={() => {}}
        mimeFilter={props.mimeFilter}
        selectionType={SELECTION_TYPES.SINGLE}
        initialSelectionPaths={props.initialSelectionPaths}
        onSelectionChange={props.onMediaSelectionChange}
      />
    </>
  );
};
