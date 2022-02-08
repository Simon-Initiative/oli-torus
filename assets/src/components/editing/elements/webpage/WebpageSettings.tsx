import React, { useState, useRef, useEffect } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { CommandContext } from 'components/editing/elements/commands/interfaces';

const onVisit = (href: string) => {
  window.open(href, '_blank');
};

const onCopy = (href: string) => {
  navigator.clipboard.writeText(href);
};

type YouTubeSettingsProps = {
  model: ContentModel.YouTube;
  onEdit: (model: ContentModel.YouTube) => void;
  onRemove: () => void;
  commandContext: CommandContext;
  editMode: boolean;
};

const toLink = (src: string) => src;

export const YouTubeSettings = (props: YouTubeSettingsProps) => {
  // Which selection is active, URL or in course page
  const [model, setModel] = useState(props.model);

  const ref = useRef();

  useEffect(() => {
    // Inits the tooltips, since this popover rendres in a react portal
    // this was necessary
    if (ref !== null && ref.current !== null) {
      (window as any).$('[data-toggle="tooltip"]').tooltip();
    }
  });

  const setSrc = (src: string) => setModel(Object.assign({}, model, { src }));
  const setAlt = (alt: string) => setModel(Object.assign({}, model, { alt }));

  const applyButton = (disabled: boolean) => (
    <button
      onClick={(e) => {
        e.stopPropagation();
        e.preventDefault();
        props.onEdit(model);
      }}
      disabled={disabled}
      className="btn btn-primary ml-1"
    >
      Apply
    </button>
  );

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>
        <div className="d-flex justify-content-between mb-2">
          <div>YouTube</div>

          <div>
            <Settings.Action
              icon="fab fa-youtube"
              tooltip="Open YouTube to Find a Video"
              onClick={() => onVisit('https://www.youtube.com')}
            />
            <Settings.Action
              icon="fas fa-external-link-alt"
              tooltip="Open link"
              onClick={() => onVisit(toLink(model.src ?? ''))}
            />
            <Settings.Action
              icon="far fa-copy"
              tooltip="Copy link"
              onClick={() => onCopy(toLink(model.src ?? ''))}
            />
            <Settings.Action
              icon="fas fa-trash"
              tooltip="Remove YouTube Video"
              id="remove-button"
              onClick={() => props.onRemove()}
            />
          </div>
        </div>

        <form className="form">
          <label>YouTube Video ID</label>
          <input
            type="text"
            value={model.src}
            onChange={(e) => setSrc(e.target.value)}
            className="form-control mr-sm-2"
          />
          <div className="mb-2">
            <small>
              e.g. https://www.youtube.com/watch?v=<strong>zHIIzcWqsP0</strong>
            </small>
          </div>

          <label>Alt Text</label>
          <input
            type="text"
            value={model.alt}
            onChange={(e) => setAlt(e.target.value)}
            onKeyPress={(e) => Settings.onEnterApply(e, () => props.onEdit(model))}
            className="form-control mr-sm-2"
          />
        </form>

        {applyButton(!props.editMode)}
      </div>
    </div>
  );
};
