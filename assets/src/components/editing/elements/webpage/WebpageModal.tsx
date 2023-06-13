import React, { useCallback, useState } from 'react';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import { MediaItem } from 'types/media';

interface ModalProps {
  onDone: (x: Partial<ContentModel.Webpage>) => void;
  onCancel: () => void;
  model: ContentModel.Webpage;
  projectSlug: string;
}
export const WebpageModal = ({ onDone, onCancel, model, projectSlug }: ModalProps) => {
  const [srcType, setSrcType] = useState<ContentModel.WebpageSrcType>(model.srcType || 'url');
  const [src, setSrc] = useState(model.src);
  const [alt, setAlt] = useState(model.alt ?? '');
  const [width, _setWidth] = useState(model.width);

  const onSrcTypeChange = useCallback(
    (v: ContentModel.WebpageSrcType) => {
      if (srcType !== v) {
        // Don't re-use generic url's as media library urls and vice versa
        setSrc('');
      }
      setSrcType(v);
    },
    [srcType],
  );

  return (
    <Modal
      title=""
      size={ModalSize.LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={() => onDone({ alt, width, src, srcType })}
    >
      <div>
        <h3 className="mb-2">Settings</h3>
        <h4 className="mb-2">Change Webpage Embed URL</h4>

        <LinkType linkType={srcType} setLinkType={onSrcTypeChange} />
        {srcType === 'url' && <URLEntry src={src || ''} setSrc={setSrc} />}
        {srcType === 'media_library' && (
          <MediaEntry href={src || ''} setHref={setSrc} projectSlug={projectSlug} />
        )}

        <h4 className="mb-2">Alternative Text</h4>
        <p className="mb-4">
          Specify alternative text to be rendered when the webpage cannot be rendered.
        </p>

        <input
          className="form-control"
          value={alt}
          onChange={(e) => setAlt(e.target.value)}
          placeholder="Enter a short description of this webpage"
        />
      </div>
    </Modal>
  );
};

const MediaEntry: React.FC<{
  href: string;
  setHref: (v: string) => void;
  projectSlug: string;
}> = ({ href, setHref, projectSlug }) => {
  const onMediaChange = useCallback(
    (items: MediaItem[]) => {
      if (items.length > 0) {
        setHref(items[0].url);
      } else {
        setHref('');
      }
    },
    [setHref],
  );
  return (
    <UrlOrUpload
      onUrlChange={setHref}
      onMediaSelectionChange={onMediaChange}
      projectSlug={projectSlug}
      mimeFilter={undefined}
      selectionType={SELECTION_TYPES.SINGLE}
      initialSelectionPaths={href ? [href] : []}
      externalUrlAllowed={false}
    ></UrlOrUpload>
  );
};

const URLEntry: React.FC<{
  src: string;
  setSrc: (v: string) => void;
}> = ({ src, setSrc }) => (
  <div className="mb-4">
    <span>
      Webpage Embed URL:
      <input
        className="form-control"
        value={src}
        onChange={(e) => setSrc(e.target.value)}
        placeholder="Webpage Embed URL"
      />
    </span>
  </div>
);

const LinkType: React.FC<{
  linkType: ContentModel.WebpageSrcType;
  setLinkType: (v: ContentModel.WebpageSrcType) => void;
}> = ({ linkType, setLinkType }) => (
  <div className="d-flex flex-column">
    <div className="form-check">
      <input
        className="form-check-input mr-2"
        defaultChecked={linkType === 'url'}
        onChange={() => setLinkType('url')}
        type="radio"
        name="inlineRadioOptions"
        id="inlineRadio1"
        value="url"
      />
      <label className="form-check-label" htmlFor="inlineRadio1">
        Link to URL
      </label>
    </div>
    <div className="form-check">
      <input
        className="form-check-input mr-2"
        defaultChecked={linkType === 'media_library'}
        onChange={() => setLinkType('media_library')}
        type="radio"
        name="inlineRadioOptions"
        id="inlineRadio2"
        value="media_library"
      />
      <label className="form-check-label" htmlFor="inlineRadio2">
        Link to Media Library
      </label>
    </div>
  </div>
);
