import React, { useState, useEffect, useRef } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { selectAudio } from 'components/editing/elements/audio/audioActions';
import { CommandContext } from 'components/editing/elements/commands/interfaces';

type AudioSettingsProps = {
  model: ContentModel.Audio;
  onEdit: (model: ContentModel.Audio) => void;
  onRemove: () => void;
  commandContext: CommandContext;
  editMode: boolean;
};

// const onRemove = () => {
//   ($('#remove-button') as any).tooltip('hide');

//   const path = ReactEditor.findPath(editor, model);
//   Transforms.removeNodes(editor, { at: path });

//   setIsPopoverOpen(false);
// };

export const AudioSettings = (props: AudioSettingsProps) => {
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

  const fileName = model.src ? model.src.substr(model.src.lastIndexOf('/') + 1) : '';

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>
        <div className="d-flex justify-content-between mb-2">
          <div>Audio</div>

          <div>
            <Settings.Action
              icon="fas fa-trash"
              tooltip="Remove YouTube Video"
              id="remove-button"
              onClick={() => props.onRemove()}
            />
          </div>
        </div>

        <form className="form">
          <label>File</label>
          <div className="input-group mb-3 mr-sm-2">
            <input type="text" readOnly value={fileName} className="form-control" />
            <div className="input-group-append">
              <button
                onClick={() =>
                  selectAudio(props.commandContext.projectSlug, model).then((_img) => null)
                }
                className="btn btn-outline-primary"
                type="button"
              >
                Select
              </button>
            </div>
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
