import React from 'react';
import { CustomDnDSchema } from './schema';
import { TextInput } from 'components/common/TextInput';
import { RemoveButton } from 'components/activities/common/authoring/RemoveButton';

export type PartManagerProps = {
  model: CustomDnDSchema;
  currentPartId: string;
  onSelectPart: (partId: string) => void;
  onAddPart: () => void;
  onRemovePart: (partId: string) => void;
  onEditPart: (oldPartId: string, newPartId: string) => void;
  editMode: boolean;
};

export const PartManager: React.FC<PartManagerProps> = (props: PartManagerProps) => {
  return (
    <div className="d-flex justify-content-between">
      <div>
        <span className="mr-3">
          <strong>Part identifiers:</strong>
        </span>
        <div className="btn-group">
          <button
            className="btn btn-primary btn-sm dropdown-toggle"
            type="button"
            data-bs-toggle="dropdown"
            aria-haspopup="true"
            aria-expanded="false"
          >
            {props.currentPartId}
          </button>
          <div className="dropdown-menu">
            {props.model.authoring.parts.map((p) => (
              <button
                key={p.id}
                onClick={() => props.onSelectPart(p.id)}
                className="dropdown-item"
                type="button"
              >
                {p.id}
              </button>
            ))}
            <div
              key={'the-divider-that-separates-the-action-to-add'}
              className="dropdown-divider"
            ></div>
            <button
              key={'the-action-to-add-a-new-item'}
              className="dropdown-item"
              type="button"
              onClick={() => props.onAddPart()}
            >
              Add new part
            </button>
          </div>
        </div>
      </div>
      <div className="d-flex justify-content-between">
        <TextInput
          editMode={props.editMode}
          value={props.currentPartId}
          type="text"
          label=""
          onEdit={(value: string) => props.onEditPart(props.currentPartId, value)}
        />
        <RemoveButton
          editMode={props.editMode}
          onClick={() => props.onRemovePart(props.currentPartId)}
        />
      </div>
    </div>
  );
};
