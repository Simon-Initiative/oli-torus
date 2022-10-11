import React, { ChangeEvent, ChangeEventHandler, useCallback, useState } from 'react';
import { v4 } from 'uuid';
import * as ContentModel from '../../../../data/content/model/elements/types';
import { Modal, ModalSize } from '../../../modal/Modal';
import { CommandContext } from '../commands/interfaces';
import { CommandTarget } from './commandButtonTypes';
import { CommandMessageEditor } from './CommandMessageEditor';
import { useCommandInventory } from './useCommandInventory';

interface Props {
  model: ContentModel.CommandButton;
  onEdit: (attrs: Partial<ContentModel.CommandButton>) => void;
  commandContext: CommandContext;
  onCancel: () => void;
  onDone: () => void;
}

export const CommandButtonSettingsModal: React.FC<Props> = ({
  model,
  onEdit,
  onCancel,
  onDone,
}) => {
  const [workingCopy, setWorkingCopy] = useState<ContentModel.CommandButton>({ ...model });
  const onSubmit = useCallback(() => {
    onEdit(workingCopy);
    onDone();
  }, [onDone, onEdit, workingCopy]);

  const targets = useCommandInventory();

  const onTargetSelected = useCallback((event: ChangeEvent<HTMLInputElement>) => {
    console.info('target selected', event.target.value);
    setWorkingCopy((wc) => ({ ...wc, target: event.target.value }));
  }, []);

  const onButtonStyleChange = useCallback((event: ChangeEvent<HTMLInputElement>) => {
    setWorkingCopy((wc) => ({ ...wc, style: event.target.value as 'link' | 'button' }));
  }, []);

  const onCommandChanged = useCallback((message: string) => {
    setWorkingCopy((wc) => ({ ...wc, message }));
  }, []);

  return (
    <Modal
      title="Edit Command Button"
      size={ModalSize.X_LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={onSubmit}
    >
      <p className="alert alert-info">
        Command buttons allow you to triger actions in other components. An example of this is
        playing a video at a specific cue point.
      </p>
      <h4 className="mb-2">Button Style</h4>
      <div className="container">
        <div className="row">
          <div className="form-check col-sm">
            <input
              onChange={onButtonStyleChange}
              checked={workingCopy.style === 'button'}
              name="button-style"
              value="button"
              className="form-check-input"
              type="radio"
              id="button-style-button"
            />
            <label className="form-check-label" htmlFor="button-style-button">
              Button
              <br />
              <span className="btn btn-primary command-button">Example Button</span>
            </label>
          </div>
          <div className="form-check col-sm">
            <input
              onChange={onButtonStyleChange}
              checked={workingCopy.style === 'link'}
              name="button-style"
              value="link"
              className="form-check-input"
              type="radio"
              id="button-style-link"
            />
            <label className="form-check-label" htmlFor="button-style-link">
              Link
              <br />
              <span className="btn btn-link command-button">Example Link</span>
            </label>
          </div>
        </div>
      </div>

      <hr />

      <h4 className="mb-2">Command Target</h4>
      {targets.length == 0 && <div>No command targets found. Please add one to the page.</div>}
      {targets
        .filter((t) => !!t)
        .map((target) => (
          <CommandTarget
            onChange={onTargetSelected}
            key={target.id}
            target={target}
            selected={target.id === workingCopy.target}
          />
        ))}

      <hr />
      <h4 className="mb-2">Command Message</h4>
      <CommandMessageEditor
        onChange={onCommandChanged}
        value={workingCopy.message}
        target={targets.find((t) => t.id === workingCopy.target)}
      />
    </Modal>
  );
};

const CommandTarget: React.FC<{
  target: CommandTarget;
  selected: boolean;
  onChange: ChangeEventHandler<HTMLInputElement>;
}> = ({ target, selected, onChange }) => {
  const id = v4();
  return (
    <div className="form-check">
      <input
        onChange={onChange}
        checked={selected}
        name="target-radio"
        value={target.id}
        className="form-check-input"
        type="radio"
        id={id}
      />
      <label className="form-check-label" htmlFor={id}>
        <b>{target.componentType}</b>
        <br />
        <i>{target.label}</i>
      </label>
    </div>
  );
};
