import React, { useState } from 'react';
import { Media, MediaItem } from 'types/media';
import { MediaManager, SELECTION_TYPES } from './manager/MediaManager.controller';

type Source = 'upload' | 'url';
interface Props {
  toggleDisableInsert?: (b: boolean) => void;
  onUrlChange: (url: string) => void;
  model: Media;
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
          <input
            className="form-check-input"
            defaultChecked={source === 'url'}
            onChange={onChangeSource}
            type="radio"
            name="inlineRadioOptions"
            id="inlineRadio2"
            value="url" />
          <label className="form-check-label" htmlFor="inlineRadio2">
            External media item
          </label>
        </div>
        <div className="form-check">
          <input
            className="form-check-input"
            defaultChecked={source === 'upload'}
            onChange={onChangeSource}
            type="radio"
            name="inlineRadioOptions"
            id="inlineRadio1"
            value="upload" />
          <label className="form-check-label" htmlFor="inlineRadio1">
            Upload new media
          </label>
        </div>
      </div>
      {source === 'upload'
        ? <MediaManager model={props.model}
            toggleDisableInsert={props.toggleDisableInsert}
            projectSlug={props.projectSlug}
            onEdit={() => { }}
            mimeFilter={props.mimeFilter}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={props.initialSelectionPaths}
            onSelectionChange={props.onMediaSelectionChange} />
        : <div className="media-url">
            <input
              className="w-100"
              placeholder="Enter the media URL address"
              value={url}
              onChange={({ target: { value } }) => {
                setUrl(value);
                onUrlChange(value);

                if (!toggleDisableInsert) {
                  return;
                }
                return value.trim()
                  ? toggleDisableInsert(false)
                  : toggleDisableInsert(true);
              }}
            />
          </div>
      }
    </>
  );
};
