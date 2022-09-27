import React, { ChangeEvent, useCallback, useMemo } from 'react';
import { Conjugation, TableRow } from '../../../../data/content/model/elements/types';
import { CommandContext } from '../commands/interfaces';
import { InlineEditor } from '../common/settings/InlineEditor';
import { PronunciationEditor } from '../PronunciationEditor';
import {
  createEditor,
  Descendant,
  Editor,
  Editor as SlateEditor,
  Operation,
  Transforms,
} from 'slate';
import { withMarkdown } from '../../editor/overrides/markdown';
import { ReactEditor, withReact } from 'slate-react';
import { withHistory } from 'slate-history';
import { withTables } from '../../editor/overrides/tables';
import { withInlines } from '../../editor/overrides/inlines';
import { withVoids } from '../../editor/overrides/voids';
import { installNormalizer } from '../../editor/normalizers/normalizer';
import { Model } from '../../../../data/content/model/elements/factories';
import { convertLatexToSpeakableText } from 'mathlive';

interface Props {
  model: Conjugation;
  onEdit: (model: Conjugation) => void;
  commandContext: CommandContext;
}
export const ConjugationInlineEditor: React.FC<Props> = ({ model, onEdit, commandContext }) => {
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const tableEditorOverride = useMemo(() => createTableEditor(commandContext), []);
  const tableEditorContext = useMemo(
    () => ({ ...commandContext, editorType: 'conjugation' }),
    [commandContext],
  );

  const onTableEdit = useCallback(
    (newVal) => {
      const table = newVal.find((n: { type: string }) => n.type === 'table');
      onEdit({
        ...model,
        table,
      });
    },
    [model, onEdit],
  );

  const onEditPronunciation = useCallback(
    (newVal) => {
      onEdit({
        ...model,
        pronunciation: newVal,
      });
    },
    [model, onEdit],
  );

  const onAddRow = useCallback(() => {
    const path = ReactEditor.findPath(tableEditorOverride, model.table);
    const [, tablePath] = Editor.node(tableEditorOverride, path);

    const destination = [...tablePath, model.table.children.length];

    const row: TableRow = Model.tr([]);
    if (model.table.children.length == 0) {
      // No rows, add a header row
      for (let i = 1; i < 3; i += 1) {
        row.children.push(Model.th(''));
      }
    } else {
      const count = model.table.children[0].children.length;
      row.children.push(Model.th(''));
      for (let i = 1; i < count; i += 1) {
        row.children.push(Model.tc(''));
      }
    }
    Transforms.insertNodes(tableEditorOverride, row, { at: destination });
  }, [model.table, tableEditorOverride]);

  const onAddColumn = useCallback(() => {
    const path = ReactEditor.findPath(tableEditorOverride, model.table);
    const [, tablePath] = Editor.node(tableEditorOverride, path);

    Editor.withoutNormalizing(tableEditorOverride, () => {
      for (let i = 0; i < model.table.children.length; i += 1) {
        const destination = [...tablePath, i, model.table.children[i].children.length];
        const cell = i == 0 ? Model.th('') : Model.tc('');
        Transforms.insertNodes(tableEditorOverride, cell, { at: destination });
      }
    });
  }, [model.table, tableEditorOverride]);

  return (
    <div className="conjugation-editor">
      <div className="term">
        <label>Title</label>
        <input
          className="form-control"
          type="text"
          value={model.title}
          onChange={(e: ChangeEvent<HTMLInputElement>) =>
            onEdit({ ...model, title: e.target.value })
          }
        />
      </div>
      <div className="term">
        <label>Verb</label>
        <input
          className="form-control"
          type="text"
          value={model.verb}
          onChange={(e: ChangeEvent<HTMLInputElement>) =>
            onEdit({ ...model, verb: e.target.value })
          }
        />
      </div>
      <div className="pronunciation">
        <PronunciationEditor
          pronunciation={model.pronunciation}
          onEdit={onEditPronunciation}
          commandContext={commandContext}
        />
      </div>
      <div className="table">
        <InlineEditor
          editorOverride={tableEditorOverride}
          allowBlockElements={true}
          commandContext={tableEditorContext}
          content={model.table ? [model.table] : []}
          onEdit={onTableEdit}
        />
      </div>
      <div>
        <button className="btn" onClick={onAddRow}>
          Add Row
        </button>
        <button className="btn" onClick={onAddColumn}>
          Add Column
        </button>
      </div>
    </div>
  );
};

const createTableEditor = (commandContext: CommandContext): SlateEditor => {
  const editor = withMarkdown(commandContext)(
    withReact(withHistory(withTables(withInlines(withVoids(createEditor()))))),
  );

  installNormalizer(
    editor,
    {},
    { insertParagraphStartEnd: false, forceRootNode: Model.conjugationTable() },
  );
  return editor;
};
