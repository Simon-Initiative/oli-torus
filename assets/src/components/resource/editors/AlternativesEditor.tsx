import React, { PropsWithChildren, useState } from 'react';
import {
  AlternativeContent,
  AlternativesContent,
  createAlternative,
  ResourceContent,
} from 'data/content/resource';
import { EditorProps } from './createEditor';
import {
  Description,
  ExpandToggle,
  OutlineItem,
  OutlineItemProps,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import styles from './AlternativesEditor.modules.scss';
import contentBlockStyles from './ContentBlock.modules.scss';
import { DeleteButton } from 'components/misc/DeleteButton';
import { classNames } from 'utils/classNames';
import { Maybe } from 'tsmonad';
import { GroupEditor } from './GroupEditor';

interface AlternativesEditorProps extends EditorProps {
  contentItem: AlternativesContent;
}

export const AlternativesEditor = (props: AlternativesEditorProps) => {
  const { editMode, contentItem, index, parents, canRemove, onEdit, onRemove } = props;

  const [activeOptionId, setActiveOptionId] = useState(
    Maybe.maybe(contentItem.children.first<AlternativeContent>()).caseOf({
      just: (a) => a.id,
      nothing: () => '',
    }),
  );

  const activeOptionIndex = contentItem.children.findIndex((c) => c.id == activeOptionId);

  const onCreateAlternative = () => {
    const newAlt = createAlternative('new-alt');
    const update = {
      ...contentItem,
      children: contentItem.children.push(newAlt),
    };

    onEdit(update);
  };

  return (
    <AlternativesGroupBlock
      editMode={editMode}
      contentItem={contentItem}
      activeOptionId={activeOptionId}
      setActiveOptionId={setActiveOptionId}
      parents={parents}
      canRemove={canRemove}
      onRemove={onRemove}
      onCreateAlternative={onCreateAlternative}
    >
      <div className={styles.alternativesEditor}>
        {Maybe.maybe(contentItem.children.get(activeOptionIndex)).caseOf({
          just: (activeOption) => (
            <AlternativeEditor
              {...props}
              contentItem={activeOption}
              index={[...index, activeOptionIndex]}
              parents={[...parents, activeOption]}
            />
          ),
          nothing: () => (
            <div className={styles.alternativesEditor}>
              <div className="text-secondary text-center m-4">
                <div>No alternative content exists.</div>
                <div>
                  <button
                    className="btn btn-link btn-sm p-0 align-bottom"
                    onClick={onCreateAlternative}
                  >
                    Create{' '}
                  </button>{' '}
                  an alternative item to get started.
                </div>
              </div>
            </div>
          ),
        })}
      </div>
    </AlternativesGroupBlock>
  );
};

interface AlternativeEditorProps extends EditorProps {
  contentItem: AlternativeContent;
}

const AlternativeEditor = (props: AlternativeEditorProps) => {
  return <GroupEditor {...props} contentItem={props.contentItem} />;
};

interface AlternativesOutlineItemProps extends OutlineItemProps {
  contentItem: AlternativesContent;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
}

export const AlternativesOutlineItem = (props: AlternativesOutlineItemProps) => {
  const { id, contentItem, expanded, toggleCollapsibleGroup } = props;

  return (
    <OutlineItem {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={resourceGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineItem>
  );
};

interface AlternativeOutlineItemProps extends OutlineGroupProps {
  contentItem: AlternativeContent;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
}

export const AlternativeOutlineItem = (props: AlternativeOutlineItemProps) => {
  const { id, contentItem, expanded, toggleCollapsibleGroup } = props;

  return (
    <OutlineGroup {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={alternatveGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineGroup>
  );
};

const alternatveGroupTitle = (alternative: AlternativeContent) => alternative.value;

interface AlternativesGroupBlockProps {
  editMode: boolean;
  contentItem: AlternativesContent;
  activeOptionId: string;
  parents: ResourceContent[];
  canRemove: boolean;
  onCreateAlternative: () => void;
  onRemove: () => void;
  setActiveOptionId: (id: string) => void;
}
export const AlternativesGroupBlock = (props: PropsWithChildren<AlternativesGroupBlockProps>) => {
  const {
    editMode,
    contentItem,
    activeOptionId,
    canRemove,
    children,
    onRemove,
    onCreateAlternative,
    setActiveOptionId,
  } = props;

  const options = contentItem.children.map((option) => (
    <button
      key={option.id}
      className={classNames(
        'btn btn-sm',
        styles.option,
        option.id == activeOptionId && styles.active,
      )}
      onClick={() => setActiveOptionId(option.id)}
    >
      {option.value}
    </button>
  ));

  return (
    <div id={`resource-editor-${contentItem.id}`} className={contentBlockStyles.groupBlock}>
      <div className={styles.groupBlockHeader}>
        <div className={styles.options}>
          {options}
          <button
            key="add"
            className={classNames('btn btn-sm', styles.option, styles.add)}
            onClick={onCreateAlternative}
          >
            <i className="las la-plus"></i>
          </button>
        </div>
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      {children}
    </div>
  );
};
