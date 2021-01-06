import React, { useState } from 'react'
import {valueOr} from 'utils/common'

type Source = 'upload' | 'url'
interface Props {
  mediaLibrary: JSX.Element;
  toggleDisableInsert?: (b: boolean) => void;
}
export const UrlOrUpload = (props: Props) => {

  const { mediaLibrary, toggleDisableInsert } = props;
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
            Enter a URL to external media
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
        ? mediaLibrary
        : <div className="media-url">
            <input
              placeholder="URL"
              value={url}
              onChange={({ target: { value } }) => {
                setUrl(value)
                if (!toggleDisableInsert) {
                  return;
                }
                return value.trim()
                  ? toggleDisableInsert(false)
                  : toggleDisableInsert(true)
              }}
            />
          </div>
      }
    </>
  )
}