import React, { useCallback } from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { v4 } from 'uuid';
import * as ContentModel from 'data/content/model/elements/types';
import { Model } from '../../../../data/content/model/elements/factories';
import { Speaker } from '../../../Dialog';
import { CommandContext } from '../commands/interfaces';
import { InlineEditor } from '../common/settings/InlineEditor';
import { CursorInput } from './CursorInput';
import { selectPortrait } from './dialogActions';

export const DialogInlineEditor: React.FC<{
  dialog: ContentModel.Dialog;
  commandContext: CommandContext;
  onEdit: (definition: Partial<ContentModel.Dialog>) => void;
}> = ({ dialog, onEdit, commandContext }) => {
  const editor = useSlate();

  const resetFocus = useCallback(() => {
    /* On some operations, like deleting a speaker, focus is moved outside the editor. For those operations, we
       manually focus the editor again so things like ctrl-z to undo work. MER-2284 */
    setTimeout(() => {
      ReactEditor.focus(editor);
    }, 0);
  }, []);

  const onSpeakerEdit = useCallback(
    // Utility funtion to easily update a single speaker by index.
    (index: number, props: Partial<ContentModel.DialogSpeaker>) => {
      onEdit({
        speakers: dialog.speakers.map((speaker, i) =>
          i === index
            ? {
                ...speaker,
                ...props,
              }
            : speaker,
        ),
      });
    },
    [dialog.speakers, onEdit],
  );

  const onEditSpeakerName = useCallback(
    // Curried update function. Usage - onEditSpeakerName(index)(changeEvent)
    (index: number) => (name: string) => {
      onSpeakerEdit(index, { name });
    },
    [onSpeakerEdit],
  );

  const onBrowseImage = useCallback(
    (index: number) => () => {
      selectPortrait(commandContext.projectSlug).then((url: string | undefined) => {
        onSpeakerEdit(index, { image: url });
      });
    },
    [commandContext.projectSlug, onSpeakerEdit],
  );

  const onDeleteSpeaker = useCallback(
    // Curried delete function. Usage - onDeleteSpeaker(index)()
    (index: number) => () => {
      onEdit({
        speakers: dialog.speakers.filter((_, i) => i !== index),
      });
      resetFocus();
    },
    [dialog.speakers, onEdit],
  );

  const onLineEdit = useCallback(
    // Helper function for when a property on a DialogLine is edited.
    (index: number, props: Partial<ContentModel.DialogLine>) => {
      onEdit({
        lines: dialog.lines.map((line, i) =>
          i === index
            ? {
                ...line,
                ...props,
              }
            : line,
        ),
      });
    },
    [dialog.lines, onEdit],
  );

  const onEditTitle = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      onEdit({ title: event.target.value });
    },
    [onEdit],
  );

  const onNewLine = useCallback(() => {
    onEdit({
      lines: [...dialog.lines, Model.dialogLine(dialog.speakers[0]?.id || '')],
    });
    resetFocus();
  }, [dialog.lines, dialog.speakers, onEdit]);

  const onLineContentEdit = useCallback(
    (index: number) => (content: any[]) => {
      onLineEdit(index, { children: content });
    },
    [onLineEdit],
  );

  const onDeleteLine = useCallback(
    (index: number) => () => {
      onEdit({
        lines: dialog.lines.filter((_, i) => i !== index),
      });
      resetFocus();
    },
    [dialog.lines, onEdit],
  );

  const onCycleSpeaker = useCallback(
    (index: number) => () => {
      if (dialog.speakers.length === 0) return;
      const line = dialog.lines[index];
      if (!line) return;
      let speakerIndex = Math.max(
        dialog.speakers.findIndex((s) => s.id === line.speaker),
        0,
      );
      speakerIndex++;
      speakerIndex %= dialog.speakers.length;
      onLineEdit(index, { speaker: dialog.speakers[speakerIndex].id });
      resetFocus();
    },
    [dialog.lines, dialog.speakers, onLineEdit],
  );

  const onAddSpeaker = useCallback(() => {
    onEdit({
      speakers: [...dialog.speakers, Model.dialogSpeaker('Unknown')],
    });
    resetFocus();
  }, [dialog.speakers, onEdit]);

  const titleId = v4();

  return (
    <div>
      <div className="form-group">
        <label htmlFor={titleId}>Title</label>
        <input
          type="text"
          id={titleId}
          value={dialog.title}
          onChange={onEditTitle}
          className="form-control"
        />
      </div>

      <div className="form-group">
        <label>Speakers</label>
        <div className="speakers">
          {dialog.speakers.map((speaker, index) => (
            <div key={index} className="speaker-editor">
              {speaker.image ? (
                <img onClick={onBrowseImage(index)} src={speaker.image} alt={speaker.name} />
              ) : (
                speaker.image || (
                  <span onClick={onBrowseImage(index)} className="portrait-placeholder">
                    <i className="fa-solid fa-image-portrait"></i>
                  </span>
                )
              )}
              <CursorInput
                className="form-control form-control-sm"
                type="text"
                value={speaker.name}
                onChange={onEditSpeakerName(index)}
              />

              <button className="btn btn-sm browse-btn" onClick={onBrowseImage(index)}>
                <i className="fa-solid fa-folder"></i>
              </button>

              <button onClick={onDeleteSpeaker(index)} className="btn btn-sm delete-btn">
                <i className="fa-solid fa-trash"></i>
              </button>
            </div>
          ))}
          <div className="speaker-editor new-speaker">
            <button onClick={onAddSpeaker} className="btn btn-primary">
              <i className="fa-solid fa-plus"></i>
            </button>
          </div>
        </div>
      </div>

      <div className="form-group">
        <label>Lines</label>
        {dialog.lines.map((line: ContentModel.DialogLine, index: number) => (
          <div key={`dialog-${index}-${line.id}`} className="dialog-row">
            <Speaker
              onClick={onCycleSpeaker(index)}
              speaker={dialog.speakers.find((s) => s.id === line.speaker)}
            />
            <button onClick={onCycleSpeaker(index)} className="btn btn-primary cycle-speaker-btn">
              <i className="fa-solid fa-rotate"></i>
            </button>
            <div className="form-control dialog-input">
              <InlineEditor
                allowBlockElements={true}
                commandContext={commandContext}
                content={Array.isArray(line.children) ? line.children : []}
                onEdit={onLineContentEdit(index)}
              />
            </div>
            <button
              className="btn hover:text-danger mb-3"
              type="button"
              onClick={onDeleteLine(index)}
            >
              <i className="fa-solid fa-xmark fa-lg"></i>
            </button>
          </div>
        ))}
        <div className="dialog-row">
          <div className="dialog-speaker"></div>
          <button
            className="btn btn-outline-success"
            type="button"
            onClick={onNewLine}
            disabled={dialog.speakers.length === 0}
          >
            Add
          </button>
        </div>
      </div>
    </div>
  );
};
