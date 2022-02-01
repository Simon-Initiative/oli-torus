import React, { useEffect, useRef, useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { CommandContext } from 'components/editing/elements/commands/interfaces';

type TableSettingsProps = {
  model: ContentModel.Table;
  onEdit: (model: ContentModel.Table) => void;
  onRemove: () => void;
  commandContext: CommandContext;
  editMode: boolean;
};

export const TableSettings = (props: TableSettingsProps) => {
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

  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));

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
          <div>Table</div>

          <div>
            <Settings.Action
              icon="fas fa-trash"
              tooltip="Remove Table"
              id="remove-button"
              onClick={() => props.onRemove()}
            />
          </div>
        </div>

        {applyButton(!props.editMode)}
      </div>
    </div>
  );
};
