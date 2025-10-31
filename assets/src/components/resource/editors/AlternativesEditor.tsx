import React, { PropsWithChildren, useState } from 'react';
import { Maybe } from 'tsmonad';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { Tooltip } from 'components/common/Tooltip';
import { AlternativesTypes, useAlternatives } from 'components/hooks/useAlternatives';
import { DeleteButton } from 'components/misc/DeleteButton';
import { SelectModal } from 'components/modal/SelectModal';
import { modalActions } from 'actions/modal';
import { makePageUndoable } from 'apps/page-editor/types';
import {
  AlternativeContent,
  AlternativesContent,
  ResourceContent,
  ResourceContext,
  createAlternative,
} from 'data/content/resource';
import * as Persistence from 'data/persistence/resource';
import { classNames } from 'utils/classNames';
import styles from './AlternativesEditor.modules.scss';
import contentBlockStyles from './ContentBlock.modules.scss';
import { GroupEditor } from './GroupEditor';
import {
  Description,
  ExpandToggle,
  OutlineGroup,
  OutlineGroupProps,
  OutlineItem,
  OutlineItemProps,
  resourceGroupTitle,
} from './OutlineItem';
import { EditorProps } from './createEditor';

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
    resourceContext,
    onEdit,
    onRemove,
    onPostUndoable,
  } = props;
  const alternativesContext = useAlternatives();

  const [activeOption, setActiveOption] = useState(contentItem.children.first());

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

  const renderAlternatives = (
    alternativeOptions: Persistence.AlternativesGroupOption[],
    alternativeOptionsTitles: Record<string, string>,
  ) => {
    const activeOptionIndex = contentItem.children.findIndex((c) => c.id == activeOption.id);

    const showCreateAlternativeModal = () => {
      const title =
        contentItem.strategy === 'upgrade_decision_point' ? 'Select Option' : 'Select Alternative';
      const description =
        contentItem.strategy === 'upgrade_decision_point' ? 'Select Option' : 'Select Alternative';
      const linkHref =
        contentItem.strategy === 'upgrade_decision_point'
          ? `/workspaces/course_author/${projectSlug}/experiments`
          : `/workspaces/course_author/${projectSlug}/alternatives`;
      const linkText =
        contentItem.strategy === 'upgrade_decision_point'
          ? 'Manage Upgrade Options'
          : 'Manage Alternatives Options';

      window.oliDispatch(
        modalActions.display(
          <SelectModal
            title={title}
            description={description}
            additionalControls={<ManageAlternativesLink linkHref={linkHref} linkText={linkText} />}
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
              setActiveOption(newAlt);
            }}
            onCancel={() => window.oliDispatch(modalActions.dismiss())}
          />,
        ),
      );
    };

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
      setActiveOption(contentItem.children.first());
    };
    const options =
      contentItem.strategy === 'upgrade_decision_point'
        ? 'No upgrade decision point option selected.'
        : 'No alternative option selected.';

    return (
      <AlternativesGroupBlock
        editMode={editMode}
        projectSlug={projectSlug}
        resourceContext={resourceContext}
        contentItem={contentItem}
        activeOption={activeOption}
        setActiveOption={setActiveOption}
        alternativeOptions={alternativeOptions}
        alternativeOptionsTitles={alternativeOptionsTitles}
        parents={parents}
        canRemove={canRemove}
        onRemove={() => onRemove(contentItem.id)}
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
                  <div>{options}</div>
                  <div>
                    <button
                      className="btn btn-link btn-sm p-0 align-bottom"
                      onClick={showCreateAlternativeModal}
                    >
                      Select{' '}
                    </button>{' '}
                    an option to get started.
                  </div>
                </div>
              </div>
            ),
          })}
        </div>
      </AlternativesGroupBlock>
    );
  };

  switch (alternativesContext.type) {
    case AlternativesTypes.REQUEST:
      return renderLoading();
    case AlternativesTypes.FAILURE:
      return renderFailed(alternativesContext.error);
    case AlternativesTypes.SUCCESS:
      const group = alternativesContext.alternatives.find(
        (a) => a.id === contentItem.alternatives_id,
      );
      const alternativeOptionsTitles =
        alternativesContext.alternativesOptionsTitles[contentItem.alternatives_id];

      switch (group) {
        case undefined:
          return renderFailed('Options for alternative group could not be found');
        default:
          return renderAlternatives(group.options, alternativeOptionsTitles);
      }
  }
};

interface ManageAlternativesLinkProps {
  linkHref: string;
  linkText: string;
}

export const ManageAlternativesLink = ({ linkHref, linkText }: ManageAlternativesLinkProps) => (
  <>
    <a className="btn btn-link" href={linkHref} target="_blank" rel="noreferrer">
      {linkText} <i className="fas fa-external-link-alt"></i>
    </a>
  </>
);

interface AlternativeEditorProps extends EditorProps {
  contentItem: AlternativeContent;
}

const AlternativeEditor = (props: AlternativeEditorProps) => {
  return <GroupEditor {...props} contentItem={props.contentItem} />;
};

interface AlternativesGroupBlockProps {
  editMode: boolean;
  projectSlug: string;
  resourceContext: ResourceContext;
  contentItem: AlternativesContent;
  activeOption: AlternativeContent;
  parents: ResourceContent[];
  canRemove: boolean;
  alternativeOptions: Persistence.AlternativesGroupOption[];
  alternativeOptionsTitles: Record<string, string>;
  onCreateAlternative: () => void;
  onEditAlternative: (update: AlternativeContent) => void;
  onDeleteAlternative: (optionId: string) => void;
  onRemove: () => void;
  setActiveOption: (option: AlternativeContent) => void;
}
export const AlternativesGroupBlock = (props: PropsWithChildren<AlternativesGroupBlockProps>) => {
  const {
    editMode,
    projectSlug,
    resourceContext,
    contentItem,
    activeOption,
    canRemove,
    children,
    alternativeOptions,
    alternativeOptionsTitles,
    onRemove,
    onCreateAlternative,
    onEditAlternative,
    onDeleteAlternative,
    setActiveOption,
  } = props;

  const selectedOption = contentItem.children.find((o) => o.id === activeOption.id);

  const showEditAlternative = () => {
    const title =
      contentItem.strategy === 'upgrade_decision_point' ? 'Edit Option' : 'Edit Alternative';
    const description =
      contentItem.strategy === 'upgrade_decision_point' ? 'Edit Option' : 'Edit Alternative';
    window.oliDispatch(
      modalActions.display(
        <SelectModal
          title={title}
          description={description}
          additionalControls={
            <>
              <button
                type="button"
                className="btn btn-danger"
                onClick={() => {
                  window.oliDispatch(modalActions.dismiss());
                  onDeleteAlternative(activeOption.id);
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

            const update = contentItem.children.find((o) => o.id === activeOption.id);
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
  };

  const optionIdCount = contentItem.children.reduce(
    (acc, option) => ({
      ...acc,
      [option.value]: acc[option.value] ? acc[option.value] + 1 : 1,
    }),
    {} as Record<string, number>,
  );

  const options = contentItem.children.map((option) => (
    <OptionPill
      key={option.id}
      option={option}
      activeOption={activeOption}
      alternativeOptionsTitles={alternativeOptionsTitles}
      isDuplicate={optionIdCount[option.value] > 1}
      onSetActiveOption={setActiveOption}
      onEditAlternativeClick={showEditAlternative}
    />
  ));

  const maybeConnectUpgrade = !resourceContext.hasExperiments && (
    <div className="mb-1">
      <i className="fas fa-exclamation-triangle text-warning mx-1"></i>This experiment is not
      integrated with UpGrade.
      <a
        className="btn btn-link"
        href={`/workspaces/course_author/${projectSlug}/experiments`}
        target="_blank"
        rel="noreferrer"
      >
        Enable A/B testing with UpGrade
      </a>
      to collect experiment data.
    </div>
  );

  const maybeUpgradeAB = contentItem.strategy === 'upgrade_decision_point' && (
    <div className="mb-1">
      {maybeConnectUpgrade}
      <h2>A/B Testing Decision Point</h2>
    </div>
  );

  return (
    <div id={`resource-editor-${contentItem.id}`} className={contentBlockStyles.groupBlock}>
      {maybeUpgradeAB}
      <div className={styles.groupBlockHeader}>
        <div className={styles.options}>
          {options}
          {contentItem.strategy !== 'upgrade_decision_point' && (
            <button
              key="add"
              className={classNames('btn btn-sm', styles.option)}
              onClick={onCreateAlternative}
            >
              <i className="fas fa-plus"></i>
            </button>
          )}
        </div>
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      {children}
    </div>
  );
};

type OptionPillProps = {
  option: AlternativeContent;
  activeOption: AlternativeContent;
  alternativeOptionsTitles: Record<string, string>;
  isDuplicate: boolean;
  onSetActiveOption: (option: AlternativeContent) => void;
  onEditAlternativeClick: () => void;
};

const OptionPill = ({
  option,
  activeOption,
  alternativeOptionsTitles,
  isDuplicate,
  onSetActiveOption,
  onEditAlternativeClick,
}: OptionPillProps): JSX.Element => {
  const title = alternativeOptionsTitles[option.value];

  const titleOrWarning = title ?? (
    <Tooltip title="This alternative value no longer exists and should be changed or removed">
      <span className="align-middle">
        <i className="fas fa-exclamation-circle text-danger"></i>
      </span>
    </Tooltip>
  );

  const maybeDuplicateWarning = isDuplicate && (
    <Tooltip title="This alternative has the same value as another. One or the other should be changed or removed">
      <span className="align-middle">
        <i className="fas fa-exclamation-triangle text-warning mx-1"></i>
      </span>
    </Tooltip>
  );

  if (option.id == activeOption.id) {
    return (
      <div key={option.id} className={classNames('btn btn-sm', styles.option, styles.active)}>
        {maybeDuplicateWarning}
        {titleOrWarning}
        <>
          <button
            className={classNames('btn btn-sm', styles.edit)}
            onClick={onEditAlternativeClick}
          >
            <i className="fas fa-ellipsis-h"></i>
          </button>
        </>
      </div>
    );
  }

  return (
    <button
      key={option.id}
      className={classNames('btn btn-sm', styles.option, !title && styles.warn)}
      onClick={() => onSetActiveOption(option)}
    >
      {maybeDuplicateWarning}
      {titleOrWarning}
    </button>
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
  parents: ResourceContent[];
  toggleCollapsibleGroup: (id: string) => void;
}

export const AlternativeOutlineItem = (props: AlternativeOutlineItemProps) => {
  const { id, contentItem, expanded, parents, toggleCollapsibleGroup } = props;
  const alternativesContext = useAlternatives();

  switch (alternativesContext.type) {
    case AlternativesTypes.REQUEST:
      return (
        <OutlineGroup {...props}>
          <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
          <Description
            title={<LoadingSpinner size={LoadingSpinnerSize.Medium} align="left"></LoadingSpinner>}
          >
            {contentItem.children.size} items
          </Description>
        </OutlineGroup>
      );
    case AlternativesTypes.FAILURE:
      return (
        <OutlineGroup {...props}>
          <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
          <Description>
            <Description
              title={
                <LoadingSpinner failed size={LoadingSpinnerSize.Medium} align="left">
                  An error occurred
                </LoadingSpinner>
              }
            ></Description>
          </Description>
        </OutlineGroup>
      );
    case AlternativesTypes.SUCCESS:
      const parent = parents[parents.length - 1] as AlternativesContent;
      const alternativeGroupTitle =
        alternativesContext.alternativesOptionsTitles[parent.alternatives_id][contentItem.value];

      return (
        <OutlineGroup {...props}>
          <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
          <Description title={alternativeGroupTitle}>{contentItem.children.size} items</Description>
        </OutlineGroup>
      );
  }
};
