import React, { useState, useEffect, useRef } from 'react';
import * as ContentModel from 'data/content/model';
import { CommandContext } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { selectAudio } from '../../commands/AudioCmd';

type AudioSettingsProps = {
  model: ContentModel.Audio,
  onEdit: (model: ContentModel.Audio) => void,
  onRemove: () => void,
  commandContext: CommandContext,
  editMode: boolean,
};

export const AudioSettings = (props: AudioSettingsProps) => {

  // Which selection is active, URL or in course page
  const [model, setModel] = useState(props.model);

  const ref = useRef();

  useEffect(() => {

    // Inits the tooltips, since this popover rendres in a react portal
    // this was necessary
    if (ref !== null && ref.current !== null) {
      ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    }
  });

  const setSrc = (src: string) => setModel(Object.assign({}, model, { src }));
  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));
  const setAlt = (alt: string) => setModel(Object.assign({}, model, { alt }));

  const applyButton = (disabled: boolean) => <button onClick={(e) => {
    e.stopPropagation();
    e.preventDefault();
    props.onEdit(model);
  }}
  disabled={disabled}
  className="btn btn-primary ml-1">Apply</button>;

  const fileName = model.src.substr(model.src.lastIndexOf('/') + 1);

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>

        <div className="d-flex justify-content-between mb-2">
          <div>
            Audio
          </div>

          <div>
            <Settings.Action icon="fas fa-trash" tooltip="Remove YouTube Video" id="remove-button"
              onClick={() => props.onRemove()}/>
          </div>
        </div>

        <form className="form">
        <label>File</label>
          <div className="input-group mb-3 mr-sm-2">
            <input type="text" readOnly value={fileName} className="form-control"/>
            <div className="input-group-append">
              <button
                onClick={() => selectAudio(
                  props.commandContext.projectSlug, model).then(img => setSrc(img.src))}
                className="btn btn-outline-primary" type="button">Select</button>
            </div>
          </div>

          <label>Caption</label>
          <input type="text" value={model.caption} onChange={e => setCaption(e.target.value)}
            onKeyPress={e => Settings.onEnterApply(e, () => props.onEdit(model))}
            className="form-control mr-sm-2"/>

          <label>Alt Text</label>
          <input type="text" value={model.alt} onChange={e => setAlt(e.target.value)}
            onKeyPress={e => Settings.onEnterApply(e, () => props.onEdit(model))}
            className="form-control mr-sm-2"/>
        </form>

        {applyButton(!props.editMode)}

      </div>
    </div>
  );
};
