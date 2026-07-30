import React, { PropsWithChildren, useEffect, useMemo, useState } from 'react';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { Tooltip } from 'components/common/Tooltip';
import { AlternativesTypes, useAlternatives } from 'components/hooks/useAlternatives';
import { DeleteButton } from 'components/misc/DeleteButton';
import {
  AlternativeContent,
  AlternativesContent,
  ResourceContent,
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
  const { editMode, contentItem, index, parents, canRemove, onEdit, onRemove } = props;
  const alternativesContext = useAlternatives();

  const [activeOptionId, setActiveOptionId] = useState<string | undefined>(
    contentItem.children.first()?.id,
  );
  const selectedGroup =
    alternativesContext.type === AlternativesTypes.SUCCESS
      ? alternativesContext.alternatives.find((group) => group.id === contentItem.alternatives_id)
      : undefined;
  const reconciledChildren = useMemo(
    () =>
      selectedGroup
        ? reconcileAlternativeOptions(contentItem.children, selectedGroup.options)
        : contentItem.children,
    [contentItem.children, selectedGroup],
  );
  const activeOption =
    reconciledChildren.find((option) => option.id === activeOptionId) ?? reconciledChildren.first();

  useEffect(() => {
    if (selectedGroup && !contentItem.children.equals(reconciledChildren)) {
      onEdit({ ...contentItem, children: reconciledChildren });
    }
  }, [contentItem, onEdit, reconciledChildren, selectedGroup]);

  useEffect(() => {
    if (activeOption && activeOption.id !== activeOptionId) {
      setActiveOptionId(activeOption.id);
    }
  }, [activeOption, activeOptionId]);

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

  const renderAlternatives = (alternativeOptionsTitles: Record<string, string>) => {
    const reconciledContent = { ...contentItem, children: reconciledChildren };
    const activeOptionIndex = activeOption
      ? reconciledChildren.findIndex((option) => option.id === activeOption.id)
      : -1;

    const onEditAlternative = (updatedContent: ResourceContent) => {
      if (updatedContent.type === 'alternative') {
        onEdit(updateAlternativeContent(reconciledContent, updatedContent));
      }
    };

    return (
      <AlternativesGroupBlock
        editMode={editMode}
        contentItem={reconciledContent}
        groupTitle={selectedGroup?.title ?? ''}
        activeOption={activeOption}
        setActiveOption={(option) => setActiveOptionId(option.id)}
        alternativeOptionsTitles={alternativeOptionsTitles}
        parents={parents}
        canRemove={canRemove}
        onRemove={() => onRemove(contentItem.id)}
      >
        <div className={styles.alternativesEditor}>
          {Maybe.maybe(reconciledChildren.get(activeOptionIndex)).caseOf({
            just: (activeOption) => (
              <>
                {!alternativeOptionsTitles[activeOption.value] && (
                  <StaleOptionNotice projectSlug={props.projectSlug} />
                )}
                <AlternativeEditor
                  {...props}
                  contentItem={activeOption}
                  index={[...index, activeOptionIndex]}
                  parents={[...parents, activeOption]}
                  onEdit={onEditAlternative}
                />
              </>
            ),
            nothing: () => <EmptyOptionsNotice projectSlug={props.projectSlug} />,
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
          return renderAlternatives(alternativeOptionsTitles);
      }
  }
};

export const reconcileAlternativeOptions = (
  children: Immutable.List<AlternativeContent>,
  options: Persistence.AlternativesGroupOption[],
): Immutable.List<AlternativeContent> => {
  const currentOptionIds = new Set(options.map((option) => option.id));
  const childrenByOptionId = children.reduce((byOptionId, child) => {
    const matches = byOptionId.get(child.value) ?? [];
    matches.push(child);
    byOptionId.set(child.value, matches);
    return byOptionId;
  }, new Map<string, AlternativeContent[]>());
  const currentChildren = options.flatMap((option) => {
    const matches = childrenByOptionId.get(option.id) ?? [];
    return matches.length > 0 ? matches : [createAlternative(option.id)];
  });
  const staleChildren = children.filter((child) => !currentOptionIds.has(child.value)).toArray();

  return Immutable.List([...currentChildren, ...staleChildren]);
};

export const updateAlternativeContent = (
  content: AlternativesContent,
  updatedOption: AlternativeContent,
): AlternativesContent => ({
  ...content,
  children: content.children.map((option) =>
    option.id === updatedOption.id ? updatedOption : option,
  ),
});

export const StaleOptionNotice = ({ projectSlug }: { projectSlug: string }) => (
  <div className="alert alert-warning m-3" role="alert">
    This content belongs to an option that no longer exists. It has been preserved and was not
    assigned to another option.{' '}
    <ManageAlternativesLink
      linkHref={`/workspaces/course_author/${projectSlug}/alternatives`}
      linkText="Review options in Manage Alternatives"
    />
  </div>
);

export const EmptyOptionsNotice = ({ projectSlug }: { projectSlug: string }) => (
  <div className="text-secondary text-center m-4">
    This alternatives group has no options.{' '}
    <ManageAlternativesLink
      linkHref={`/workspaces/course_author/${projectSlug}/alternatives`}
      linkText="Add options in Manage Alternatives"
    />
  </div>
);

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
  contentItem: AlternativesContent;
  groupTitle: string;
  activeOption: AlternativeContent | undefined;
  parents: ResourceContent[];
  canRemove: boolean;
  alternativeOptionsTitles: Record<string, string>;
  onRemove: () => void;
  setActiveOption: (option: AlternativeContent) => void;
}
export const AlternativesGroupBlock = (props: PropsWithChildren<AlternativesGroupBlockProps>) => {
  const {
    editMode,
    contentItem,
    groupTitle,
    activeOption,
    canRemove,
    children,
    alternativeOptionsTitles,
    onRemove,
    setActiveOption,
  } = props;
  const panelId = `alternatives-panel-${contentItem.id}`;

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
      panelId={panelId}
    />
  ));

  const onTabKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;

    const tabs = Array.from(event.currentTarget.querySelectorAll<HTMLElement>('[role="tab"]'));
    const currentIndex = tabs.indexOf(event.target as HTMLElement);
    if (currentIndex === -1) return;

    event.preventDefault();
    const nextIndex =
      event.key === 'Home'
        ? 0
        : event.key === 'End'
        ? tabs.length - 1
        : (currentIndex + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;

    tabs[nextIndex]?.focus();
    tabs[nextIndex]?.click();
  };

  return (
    <div id={`resource-editor-${contentItem.id}`} className={contentBlockStyles.groupBlock}>
      <div className={styles.groupBlockHeader}>
        <h2 className="h4 mb-0">{groupTitle}</h2>
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      <div className={styles.groupBlockHeader}>
        <div
          className={styles.options}
          role="tablist"
          aria-label="Alternative content options"
          onKeyDown={onTabKeyDown}
        >
          {options}
        </div>
      </div>
      <div
        id={panelId}
        role="tabpanel"
        aria-labelledby={activeOption ? `alternative-tab-${activeOption.id}` : undefined}
      >
        {children}
      </div>
    </div>
  );
};

type OptionPillProps = {
  option: AlternativeContent;
  activeOption: AlternativeContent | undefined;
  alternativeOptionsTitles: Record<string, string>;
  isDuplicate: boolean;
  onSetActiveOption: (option: AlternativeContent) => void;
  panelId: string;
};

const OptionPill = ({
  option,
  activeOption,
  alternativeOptionsTitles,
  isDuplicate,
  onSetActiveOption,
  panelId,
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

  const selected = option.id === activeOption?.id;
  return (
    <button
      key={option.id}
      id={`alternative-tab-${option.id}`}
      role="tab"
      type="button"
      aria-selected={selected}
      aria-controls={panelId}
      tabIndex={selected ? 0 : -1}
      className={classNames(
        'btn btn-sm',
        styles.option,
        selected && styles.active,
        !title && styles.warn,
      )}
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
