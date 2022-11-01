import React, { PropsWithChildren, useEffect, useState } from 'react';
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
import { modalActions } from 'actions/modal';
import { SelectModal } from 'components/modal/SelectModal';
import * as Persistence from 'data/persistence/resource';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { makePageUndoable } from 'apps/page-editor/types';

interface AlternativesEditorProps extends EditorProps {
  contentItem: AlternativesContent;
}

export const AlternativesEditor = (props: AlternativesEditorProps) => {
  const {
    editMode,
    projectSlug,
    contentItem,
    index,
    parents,
    canRemove,
    onEdit,
    onRemove,
    onPostUndoable,
  } = props;

  const [alternativeOptions, setAlternativeOptions] = useState<
    Maybe<Persistence.AlternativesGroupOption[]>
  >(Maybe.nothing());
  const [alternativeOptionsError, setAlternativeOptionsError] = useState<Maybe<string>>(
    Maybe.nothing(),
  );
  const [activeOptionId, setActiveOptionId] = useState(
    Maybe.maybe(contentItem.children.first<AlternativeContent>()).caseOf({
      just: (a) => a.id,
      nothing: () => '',
    }),
  );

  useEffect(() => {
    Persistence.alternatives(projectSlug).then((result) => {
      if (result.type === 'success') {
        const group = result.alternatives.find((g) => g.id === contentItem.groupId);

        if (group) {
          setAlternativeOptions(Maybe.just(group.options));
        } else {
          setAlternativeOptionsError(
            Maybe.just('Options for alternative group could not be found'),
          );
        }
      } else {
        setAlternativeOptionsError(
          Maybe.just(`Failed to fetch options for alternative group: ${result.message}`),
        );
      }
    });
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium}>Loading...</LoadingSpinner>
  );

  const renderFailed = (errorMsg: string) => (
    <div className="alert alert-danger m-3">
      <p>Failed to load alternatives. Please try again or contact support.</p>
      <p>
        <b>Error:</b> {errorMsg}
      </p>
    </div>
  );

  const renderAlternatives = (alternativeOptions: Persistence.AlternativesGroupOption[]) => {
    const activeOptionIndex = contentItem.children.findIndex((c) => c.id == activeOptionId);

    const showCreateAlternativeModal = () =>
      window.oliDispatch(
        modalActions.display(
          <SelectModal
            title="Select Alternative"
            description="Select Alternative"
            onFetchOptions={() => {
              return Promise.resolve(
                alternativeOptions.map((o) => ({ value: o.id, title: o.name })),
              );
            }}
            onDone={(optionId: string) => {
              window.oliDispatch(modalActions.dismiss());

              const newAlt = createAlternative(optionId);
              const update = {
                ...contentItem,
                children: contentItem.children.push(newAlt),
              };

              onEdit(update);
              setActiveOptionId(newAlt.id);
            }}
            onCancel={() => window.oliDispatch(modalActions.dismiss())}
          />,
        ),
      );

    const onEditAlternative = (updatedOption: AlternativeContent) => {
      const update = {
        ...contentItem,
        children: contentItem.children.map((a) => (a.id === updatedOption.id ? updatedOption : a)),
      };

      onEdit(update);
    };

    const onDeleteAlternative = (optionId: string) => {
      const update = {
        ...contentItem,
        children: contentItem.children.filter((a) => a.id !== optionId),
      };

      onEdit(update);
      onPostUndoable(contentItem.id, makePageUndoable('Removed alternative', index, contentItem));
    };

    return (
      <AlternativesGroupBlock
        editMode={editMode}
        contentItem={contentItem}
        activeOptionId={activeOptionId}
        setActiveOptionId={setActiveOptionId}
        alternativeOptions={alternativeOptions}
        parents={parents}
        canRemove={canRemove}
        onRemove={onRemove}
        onCreateAlternative={showCreateAlternativeModal}
        onEditAlternative={onEditAlternative}
        onDeleteAlternative={onDeleteAlternative}
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
                      onClick={showCreateAlternativeModal}
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

  return alternativeOptionsError.caseOf({
    just: (errorMsg) => renderFailed(errorMsg),
    nothing: () =>
      alternativeOptions.caseOf({
        just: (alternativeOptions) => renderAlternatives(alternativeOptions),
        nothing: () => renderLoading(),
      }),
  });
};

interface AlternativeEditorProps extends EditorProps {
  contentItem: AlternativeContent;
}

const AlternativeEditor = (props: AlternativeEditorProps) => {
  return <GroupEditor {...props} contentItem={props.contentItem} />;
};

interface AlternativesGroupBlockProps {
  editMode: boolean;
  contentItem: AlternativesContent;
  activeOptionId: string;
  parents: ResourceContent[];
  canRemove: boolean;
  alternativeOptions: Persistence.AlternativesGroupOption[];
  onCreateAlternative: () => void;
  onEditAlternative: (update: AlternativeContent) => void;
  onDeleteAlternative: (optionId: string) => void;
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
    alternativeOptions,
    onRemove,
    onCreateAlternative,
    onEditAlternative,
    onDeleteAlternative,
    setActiveOptionId,
  } = props;

  const selectedOption = contentItem.children.find((o) => o.id === activeOptionId);

  const alternativeOptionsTitles = alternativeOptions.reduce(
    (acc, val) => ({ ...acc, [val.id]: val.name }),
    {} as Record<string, string>,
  );

  const showEditAlternative = () =>
    window.oliDispatch(
      modalActions.display(
        <SelectModal
          title="Edit Alternative"
          description="Edit Alternative"
          additionalControls={
            <>
              <button
                type="button"
                className="btn btn-danger"
                onClick={() => {
                  window.oliDispatch(modalActions.dismiss());
                  onDeleteAlternative(activeOptionId);
                }}
              >
                Delete
              </button>
            </>
          }
          onFetchOptions={() => {
            return Promise.resolve({
              options: alternativeOptions.map((o) => ({ value: o.id, title: o.name })),
              selectedValue: selectedOption?.value,
            });
          }}
          onDone={(optionId: string) => {
            window.oliDispatch(modalActions.dismiss());

            const update = contentItem.children.find((o) => o.id === activeOptionId);
            if (update) {
              onEditAlternative({
                ...update,
                value: optionId,
              });
            }
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );

  const options = contentItem.children.map((option) =>
    option.id == activeOptionId ? (
      <div
        key={option.id}
        className={classNames(
          'btn btn-sm',
          styles.option,
          option.id == activeOptionId && styles.active,
        )}
      >
        {alternativeOptionsTitles[option.value]}
        {option.id == activeOptionId && (
          <>
            <button className={classNames('btn btn-sm', styles.edit)} onClick={showEditAlternative}>
              <i className="las la-pen"></i>
            </button>
          </>
        )}
      </div>
    ) : (
      <button
        key={option.id}
        className={classNames(
          'btn btn-sm',
          styles.option,
          option.id == activeOptionId && styles.active,
        )}
        onClick={() => setActiveOptionId(option.id)}
      >
        {alternativeOptionsTitles[option.value]}
      </button>
    ),
  );

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

  const alternativeGroupTitle = (alternative: AlternativeContent) => alternative.value;

  return (
    <OutlineGroup {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={alternativeGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineGroup>
  );
};
