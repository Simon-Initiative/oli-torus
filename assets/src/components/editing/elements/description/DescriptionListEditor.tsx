import React, { useCallback } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from '../../../../data/content/model/elements/types';
import { useEditModelCallback } from '../utils';
import { InlineEditor } from '../common/settings/InlineEditor';
import { CommandContext } from '../commands/interfaces';
import { useSelected } from 'slate-react';
import { Model } from '../../../../data/content/model/elements/factories';

type TitleType = ContentModel.Inline | ContentModel.TextBlock;

const TitleEditor: React.FC<{
  title: TitleType[];
  onEdit: (val: TitleType[]) => void;
  commandContext: CommandContext;
}> = ({ title, onEdit, commandContext }) => {
  return (
    <div className="figure-title-editor">
      <InlineEditor
        placeholder="Description List Title"
        allowBlockElements={false}
        commandContext={commandContext}
        content={Array.isArray(title) ? title : []}
        onEdit={onEdit}
      />
    </div>
  );
};

const ItemEditor: React.FC<{
  item: ContentModel.DescriptionListDefinition | ContentModel.DescriptionListTerm;
  commandContext: CommandContext;
  onEdit: (content: any[]) => void;
  onDelete: () => void;
}> = ({ item, commandContext, onEdit, onDelete }) => {
  const Root = item.type as keyof JSX.IntrinsicElements; // works out to <dt> or <dd>
  return (
    <Root>
      <InlineEditor
        placeholder={item.type === 'dt' ? 'Description List Term' : 'Description List Definition'}
        allowBlockElements={true}
        commandContext={commandContext}
        content={item.children}
        onEdit={onEdit}
      />
      <button
        className="btn btn-outline-danger btn-small delete-btn"
        type="button"
        onClick={onDelete}
      >
        <i className="fa-solid fa-trash"></i>
      </button>
    </Root>
  );
};

interface Props extends EditorProps<ContentModel.DescriptionList> {}
export const DescriptionListEditor: React.FC<Props> = ({
  model,
  attributes,
  children,
  commandContext,
}) => {
  const onEdit = useEditModelCallback(model);
  const selected = useSelected();

  const onAddTerm = useCallback(() => {
    onEdit({
      ...model,
      items: [...model.items, Model.dt()],
    });
  }, [model, onEdit]);

  const onAddDefinition = useCallback(() => {
    onEdit({
      ...model,
      items: [...model.items, Model.dd()],
    });
  }, [model, onEdit]);

  const onEditTitle = useCallback(
    (val: TitleType[]) => {
      onEdit({
        title: val,
      });
    },
    [onEdit],
  );

  const deleteItem = useCallback(
    (indexToDelete: number) => () => {
      onEdit({
        ...model,
        items: model.items.filter((_item, index) => index !== indexToDelete),
      });
    },
    [model, onEdit],
  );

  const editItem = useCallback(
    (itemIndex: number) => (val: any[]) => {
      onEdit({
        ...model,
        items: model.items.map((item, index) => {
          if (index === itemIndex) {
            return { ...item, children: val };
          }
          return item;
        }),
      });
    },
    [model, onEdit],
  );

  const editorClass = selected ? 'selected description-list-editor' : 'description-list-editor';

  return (
    <div {...attributes} className={editorClass} contentEditable={false}>
      <h4>
        <TitleEditor title={model.title} commandContext={commandContext} onEdit={onEditTitle} />
      </h4>

      <dl>
        {model.items.map((item, index) => (
          <ItemEditor
            key={index}
            commandContext={commandContext}
            item={item}
            onEdit={editItem(index)}
            onDelete={deleteItem(index)}
          />
        ))}
      </dl>

      <div className="description-list-editor-controls">
        <button className="btn btn-secondary btn-small" onClick={onAddTerm}>
          Add Term
        </button>
        <button className="btn btn-secondary btn-small" onClick={onAddDefinition}>
          Add Definition
        </button>
      </div>

      {children}
    </div>
  );
};
