import React, { FocusEventHandler, useCallback, useState } from 'react';
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
  onFocus?: FocusEventHandler | undefined;
}> = ({ title, onEdit, commandContext, onFocus }) => {
  return (
    <div className="figure-title-editor">
      <InlineEditor
        placeholder="Description List Title"
        allowBlockElements={false}
        commandContext={commandContext}
        content={Array.isArray(title) ? title : []}
        onEdit={onEdit}
        onFocus={onFocus}
      />
    </div>
  );
};

const ItemEditor: React.FC<{
  item: ContentModel.DescriptionListDefinition | ContentModel.DescriptionListTerm;
  commandContext: CommandContext;
  onEdit: (content: any[]) => void;
  onDelete: () => void;
  insertAt: boolean;
  onFocus?: FocusEventHandler | undefined;
  onBlur?: FocusEventHandler | undefined;
}> = ({ item, commandContext, insertAt, onEdit, onDelete, onFocus, onBlur }) => {
  const Root = item.type as keyof JSX.IntrinsicElements; // works out to <dt> or <dd>
  return (
    <Root className={insertAt ? 'insert-point' : ''}>
      <InlineEditor
        placeholder={item.type === 'dt' ? 'Description List Term' : 'Description List Definition'}
        allowBlockElements={true}
        commandContext={commandContext}
        content={item.children}
        onEdit={onEdit}
        onFocus={onFocus}
        onBlur={onBlur}
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

  const [focusedItem, setFocusedItem] = useState(-1);
  const onItemFocused = useCallback(
    (index: number) => () => {
      setFocusedItem(index);
    },
    [],
  );

  const onAddTerm = useCallback(() => {
    const items =
      focusedItem === -1
        ? [...model.items, Model.dt()]
        : [
            ...model.items.slice(0, focusedItem + 1),
            Model.dt(),
            ...model.items.slice(focusedItem + 1),
          ];

    onEdit({
      ...model,
      items,
    });
  }, [model, onEdit, focusedItem]);

  const onAddDefinition = useCallback(() => {
    const items =
      focusedItem === -1
        ? [...model.items, Model.dd()]
        : [
            ...model.items.slice(0, focusedItem + 1),
            Model.dd(),
            ...model.items.slice(focusedItem + 1),
          ];
    onEdit({
      ...model,
      items,
    });
  }, [model, onEdit, focusedItem]);

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

  const addControls = (
    <div className="description-list-editor-controls">
      <button className="btn btn-secondary btn-sm" onClick={onAddTerm}>
        Add Term
      </button>
      <button className="btn btn-secondary btn-sm" onClick={onAddDefinition}>
        Add Definition
      </button>
    </div>
  );

  return (
    <div {...attributes} className={editorClass} contentEditable={false}>
      <h4>
        <TitleEditor title={model.title} commandContext={commandContext} onEdit={onEditTitle} />
      </h4>

      <dl>
        {model.items.map((item, index) => {
          return (
            <>
              <ItemEditor
                key={`${index}-${model.items.length}`} // The editor won't reset if it's value changes, so we want to make sure to have new keys when items are added/removed
                commandContext={commandContext}
                item={item}
                onEdit={editItem(index)}
                onDelete={deleteItem(index)}
                onFocus={onItemFocused(index)}
                insertAt={index === focusedItem}
              />
              {index === focusedItem && <dt>{addControls}</dt>}
            </>
          );
        })}
      </dl>

      {focusedItem === -1 && addControls}

      {children}
    </div>
  );
};
