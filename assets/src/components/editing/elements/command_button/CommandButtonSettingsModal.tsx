import React, { ChangeEvent, ChangeEventHandler, useCallback, useState } from 'react';
import { v4 } from 'uuid';
import { Modal, ModalSize } from 'components/modal/Modal';
import { CommandButton, CommandButtonToggleState } from 'data/content/model/elements/types';
import { CommandContext } from '../commands/interfaces';
import { CommandMessageEditor } from './CommandMessageEditor';
import { CommandTarget as CommandTargetType } from './commandButtonTypes';
import { useCommandInventory } from './useCommandInventory';

const CommandTarget: React.FC<{
  target: CommandTargetType;
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
      <label className="form-check-label mx-5 inline-block" htmlFor={id}>
        <b>{target.componentType}</b>
        <br />
        <i>{target.label}</i>
      </label>
    </div>
  );
};

interface Props {
  model: CommandButton;
  onEdit: (attrs: Partial<CommandButton>) => void;
  commandContext: CommandContext;
  onCancel: () => void;
  onDone: () => void;
}

type ToggleStateRow = CommandButtonToggleState & { uiKey: string };

export const CommandButtonSettingsModal: React.FC<Props> = ({
  model,
  onEdit,
  onCancel,
  onDone,
}) => {
  const [workingCopy, setWorkingCopy] = useState<CommandButton>({ ...model });
  const initialToggleStates =
    model.toggleStates && model.toggleStates.length > 0 ? model.toggleStates : null;
  const [messageMode, setMessageMode] = useState<'single' | 'toggle'>(
    initialToggleStates ? 'toggle' : 'single',
  );
  const [toggleStates, setToggleStates] = useState<ToggleStateRow[]>(
    initialToggleStates
      ? initialToggleStates.map((state) => ({ ...state, uiKey: v4() }))
      : [
          { title: 'State 1', message: workingCopy.message || '', uiKey: v4() },
          { title: 'State 2', message: '', uiKey: v4() },
        ],
  );
  const onSubmit = useCallback(() => {
    if (messageMode === 'toggle') {
      const cleaned = toggleStates.filter(
        (m) => m.title.trim().length > 0 || m.message.trim().length > 0,
      );
      const toggleStatesToSave = cleaned.length > 0 ? cleaned : toggleStates.slice(0, 1);
      const persistedStates: CommandButtonToggleState[] = toggleStatesToSave.map(
        ({ title, message }) => ({
          title,
          message,
        }),
      );
      onEdit({
        ...workingCopy,
        message: persistedStates[0]?.message ?? '',
        toggleStates: persistedStates,
      });
    } else {
      onEdit({ ...workingCopy, toggleStates: undefined });
    }
    onDone();
  }, [messageMode, onDone, onEdit, toggleStates, workingCopy]);

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

  const onToggleMessageChanged = useCallback((index: number, message: string) => {
    setToggleStates((prev) => prev.map((item, i) => (i === index ? { ...item, message } : item)));
  }, []);

  const onToggleTitleChanged = useCallback((index: number, title: string) => {
    setToggleStates((prev) => prev.map((item, i) => (i === index ? { ...item, title } : item)));
  }, []);

  const addToggleMessage = useCallback(() => {
    setToggleStates((prev) => [
      ...prev,
      { title: `State ${prev.length + 1}`, message: '', uiKey: v4() },
    ]);
  }, []);

  const removeToggleMessage = useCallback((index: number) => {
    setToggleStates((prev) => prev.filter((_item, i) => i !== index));
  }, []);

  const target = targets.find((t) => t.id === workingCopy.target);

  const switchToSingleMode = useCallback(() => setMessageMode('single'), []);

  const switchToToggleMode = useCallback(() => {
    setMessageMode('toggle');
    setToggleStates((prev) => {
      if (prev.length > 0) return prev;
      return [
        { title: 'State 1', message: workingCopy.message || '', uiKey: v4() },
        { title: 'State 2', message: '', uiKey: v4() },
      ];
    });
  }, [workingCopy.message]);

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
        Command buttons allow you to trigger actions in other components. An example of this is
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
            <label className="form-check-label mx-5 inline-block" htmlFor="button-style-button">
              Button
              <br />
              <span className="btn btn-primary command-button mx-15 my-3 inline-block">
                Example Button
              </span>
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
            <label className="form-check-label mx-5 inline-block" htmlFor="button-style-link">
              Link
              <br />
              <span className="btn btn-link command-button mx-15 my-3 inline-block">
                Example Link
              </span>
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
      <fieldset className="mb-2">
        <legend className="h6 mb-2">Message Mode</legend>
        <div className="form-check form-check-inline">
          <input
            className="form-check-input"
            type="radio"
            name="message-mode"
            id="message-mode-single"
            checked={messageMode === 'single'}
            onChange={switchToSingleMode}
          />
          <label className="form-check-label" htmlFor="message-mode-single">
            Single Message
          </label>
        </div>
        <div className="form-check form-check-inline">
          <input
            className="form-check-input"
            type="radio"
            name="message-mode"
            id="message-mode-toggle"
            checked={messageMode === 'toggle'}
            onChange={switchToToggleMode}
          />
          <label className="form-check-label" htmlFor="message-mode-toggle">
            Toggle Messages
          </label>
        </div>
      </fieldset>

      {messageMode === 'single' ? (
        <CommandMessageEditor
          onChange={onCommandChanged}
          value={workingCopy.message}
          target={target}
        />
      ) : (
        <>
          {toggleStates.map((entry, index) => (
            <div className="border rounded p-2 mb-2" key={entry.uiKey}>
              <div className="form-group">
                <label htmlFor={`toggle-title-${entry.uiKey}`}>Button Title</label>
                <input
                  id={`toggle-title-${entry.uiKey}`}
                  type="text"
                  className="form-control"
                  value={entry.title}
                  onChange={(e) => onToggleTitleChanged(index, e.target.value)}
                />
              </div>
              <CommandMessageEditor
                onChange={(message) => onToggleMessageChanged(index, message)}
                value={entry.message}
                target={target}
              />
              {toggleStates.length > 2 && (
                <button
                  type="button"
                  className="btn btn-sm btn-outline-danger mt-2"
                  onClick={() => removeToggleMessage(index)}
                >
                  Remove State
                </button>
              )}
            </div>
          ))}
          <button
            type="button"
            className="btn btn-sm btn-outline-primary"
            onClick={addToggleMessage}
          >
            Add State
          </button>
        </>
      )}
    </Modal>
  );
};
