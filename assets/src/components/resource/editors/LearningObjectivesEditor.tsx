import React, { useEffect, useMemo, useState } from 'react';
import { Option, SelectModal } from 'components/modal/SelectModal';
import { modalActions } from 'actions/modal';
import {
  LearningObjectiveConfig,
  LearningObjectivesContent,
  LearningObjectivesContentMode,
  ResolvedLearningObjective,
} from 'data/content/resource';
import * as Persistence from 'data/persistence/resource';
import { classNames } from 'utils/classNames';
import { ContentBlock } from './ContentBlock';
import './LearningObjectivesEditor.scss';
import { Description, Icon, OutlineItem, OutlineItemProps } from './OutlineItem';

type LearningObjectivesEditorProps = {
  contentItem: LearningObjectivesContent;
  editMode: boolean;
  canRemove: boolean;
  projectSlug: string;
  onEdit: (contentItem: LearningObjectivesContent) => void;
  onRemove: (id: string) => void;
  resourceContext: {
    learningObjectives?: ResolvedLearningObjective[];
  };
};

type RecommendationKind = 'revisit_pages' | 'practice_pages';

const defaultConfig = (resourceId: number): LearningObjectiveConfig => ({
  resource_id: resourceId,
  enabled: true,
  revisit_pages: [],
  practice_pages: [],
});

export const LearningObjectivesEditor = ({
  contentItem,
  editMode,
  canRemove,
  projectSlug,
  onEdit,
  onRemove,
  resourceContext,
}: LearningObjectivesEditorProps) => {
  const objectives = resourceContext.learningObjectives || [];
  const [pages, setPages] = useState<Persistence.Page[]>([]);
  const [pagesLoadFailed, setPagesLoadFailed] = useState(false);
  const hasRecommendationIds = contentItem.learning_objectives.some(
    (config) => config.revisit_pages.length > 0 || config.practice_pages.length > 0,
  );

  useEffect(() => {
    if (contentItem.mode !== 'summary' || !hasRecommendationIds) {
      setPages([]);
      setPagesLoadFailed(false);
      return;
    }

    let active = true;

    setPages([]);
    setPagesLoadFailed(false);

    Persistence.pages(projectSlug)
      .then((result) => {
        if (!active) {
          return;
        }

        if (result.type === 'success') {
          setPages(result.pages);
          setPagesLoadFailed(false);
        } else {
          setPages([]);
          setPagesLoadFailed(true);
        }
      })
      .catch(() => {
        if (active) {
          setPages([]);
          setPagesLoadFailed(true);
        }
      });

    return () => {
      active = false;
    };
  }, [contentItem.mode, hasRecommendationIds, projectSlug]);

  const pagesById = useMemo(() => new Map(pages.map((page) => [page.id, page])), [pages]);
  const configByResourceId = useMemo(
    () => new Map(contentItem.learning_objectives.map((config) => [config.resource_id, config])),
    [contentItem.learning_objectives],
  );
  const orderedObjectives = useMemo(() => orderObjectives(objectives), [objectives]);

  const includeSubObjectives = contentItem.include_sub_objectives !== false;
  const visibleObjectives = orderedObjectives.filter(
    // Include Sub-Objectives is only a display filter for this element. Child
    // config rows stay preserved so toggling the checkbox does not discard
    // advisory remove/restore or recommendation state for those objectives.
    (objective) => includeSubObjectives || parentResourceIds(objective).length === 0,
  );

  const editContent = (updates: Partial<LearningObjectivesContent>) =>
    onEdit({ ...contentItem, ...updates });

  const configFor = (resourceId: number) =>
    configByResourceId.get(resourceId) || defaultConfig(resourceId);

  const updateConfig = (
    resourceId: number,
    update: (config: LearningObjectiveConfig) => LearningObjectiveConfig,
  ) => {
    const knownResourceIds = new Set(objectives.map((objective) => objective.resource_id));
    knownResourceIds.add(resourceId);

    const nextConfigs = Array.from(knownResourceIds).map((id) =>
      id === resourceId ? update(configFor(id)) : configFor(id),
    );

    editContent({ learning_objectives: nextConfigs });
  };

  const updateMode = (mode: LearningObjectivesContentMode) => {
    // Mode is only a rendering choice; recommendation and enabled state stay intact
    // so authors can switch between Introduction and Summary without losing work.
    editContent({ mode });
  };

  const toggleIncludeSubObjectives = () =>
    editContent({ include_sub_objectives: !includeSubObjectives });

  const toggleObjectiveEnabled = (resourceId: number) =>
    updateConfig(resourceId, (config) => ({ ...config, enabled: !config.enabled }));

  const addRecommendation = (resourceId: number, kind: RecommendationKind, pageId: number) =>
    updateConfig(resourceId, (config) => {
      const existing = config[kind];

      return existing.includes(pageId) ? config : { ...config, [kind]: [...existing, pageId] };
    });

  const removeRecommendation = (resourceId: number, kind: RecommendationKind, pageId: number) =>
    updateConfig(resourceId, (config) => ({
      ...config,
      [kind]: config[kind].filter((id) => id !== pageId),
    }));

  const openPageSelector = (resourceId: number, kind: RecommendationKind) => {
    const selectedPageIds = new Set(configFor(resourceId)[kind]);
    const toOptions = (pages: Persistence.Page[]) =>
      pages
        .filter((page) => !selectedPageIds.has(page.id))
        .map((page) => ({ value: page.id, title: page.title } as Option));

    window.oliDispatch(
      modalActions.display(
        <SelectModal
          title={kind === 'revisit_pages' ? 'Select Revisit Page' : 'Select Practice Page'}
          description="Select a Page"
          onFetchOptions={() =>
            // Keep author selections scoped to the current course; the backend
            // save path still normalizes IDs as the final enforcement point.
            pages.length > 0
              ? Promise.resolve(toOptions(pages))
              : Persistence.pages(projectSlug).then((result) => {
                  if (result.type === 'success') {
                    return toOptions(result.pages);
                  } else {
                    throw new Error(result.message || 'Unable to load course pages');
                  }
                })
          }
          onDone={(pageId: number) => {
            window.oliDispatch(modalActions.dismiss());
            addRecommendation(resourceId, kind, pageId);
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );
  };

  const pageOptionsUnavailable =
    contentItem.mode === 'summary' && pagesLoadFailed && pages.length === 0;

  return (
    <ContentBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={onRemove}
    >
      <div className="learning-objectives-editor mb-3">
        <div className="learning-objectives-editor__header">
          <h3 className="label">
            {contentItem.mode === 'summary'
              ? 'Learning Objective Summary'
              : 'Learning Objective Introduction'}
          </h3>
          <label className="sr-only" htmlFor={`${contentItem.id}-mode`}>
            Learning Objectives mode
          </label>
          <select
            id={`${contentItem.id}-mode`}
            className="custom-select learning-objectives-editor__mode"
            value={contentItem.mode}
            disabled={!editMode}
            onChange={(event) => {
              if (isLearningObjectivesContentMode(event.target.value)) {
                updateMode(event.target.value);
              }
            }}
          >
            <option value="introduction">Introduction</option>
            <option value="summary">Summary</option>
          </select>
        </div>

        <div className="custom-control custom-checkbox mb-3">
          <input
            id={`${contentItem.id}-include-sub-objectives`}
            type="checkbox"
            className="custom-control-input"
            checked={includeSubObjectives}
            disabled={!editMode}
            onChange={toggleIncludeSubObjectives}
          />
          <label
            className="custom-control-label"
            htmlFor={`${contentItem.id}-include-sub-objectives`}
          >
            Include Sub-Objectives
          </label>
        </div>

        {pageOptionsUnavailable && (
          <div className="alert alert-warning" role="alert">
            Unable to load course pages. Recommendation selectors are unavailable.
          </div>
        )}

        {visibleObjectives.length === 0 ? (
          <div className="alert alert-warning mb-0" role="alert">
            There are no learning objectives attached to activities in this container.
          </div>
        ) : (
          <ul className="learning-objectives-editor__list">
            {visibleObjectives.map((objective) => (
              <ObjectiveRow
                key={objective.resource_id}
                objective={objective}
                config={configFor(objective.resource_id)}
                mode={contentItem.mode}
                editMode={editMode}
                pagesById={pagesById}
                pageOptionsUnavailable={pageOptionsUnavailable}
                onToggleEnabled={toggleObjectiveEnabled}
                onAddRecommendation={openPageSelector}
                onRemoveRecommendation={removeRecommendation}
              />
            ))}
          </ul>
        )}
      </div>
    </ContentBlock>
  );
};

type ObjectiveRowProps = {
  objective: ResolvedLearningObjective;
  config: LearningObjectiveConfig;
  mode: LearningObjectivesContentMode;
  editMode: boolean;
  pagesById: Map<number, Persistence.Page>;
  pageOptionsUnavailable: boolean;
  onToggleEnabled: (resourceId: number) => void;
  onAddRecommendation: (resourceId: number, kind: RecommendationKind) => void;
  onRemoveRecommendation: (resourceId: number, kind: RecommendationKind, pageId: number) => void;
};

const ObjectiveRow = ({
  objective,
  config,
  mode,
  editMode,
  pagesById,
  pageOptionsUnavailable,
  onToggleEnabled,
  onAddRecommendation,
  onRemoveRecommendation,
}: ObjectiveRowProps) => {
  const isSubObjective = parentResourceIds(objective).length > 0;

  return (
    <li
      className={classNames(
        'learning-objectives-editor__objective',
        isSubObjective && 'learning-objectives-editor__objective--child',
        !config.enabled && 'learning-objectives-editor__objective--disabled',
      )}
    >
      <div className="learning-objectives-editor__objective-header">
        <div className="learning-objectives-editor__objective-copy">
          <div className="learning-objectives-editor__objective-title">{objective.title}</div>
          {objective.description && (
            <div className="learning-objectives-editor__objective-description">
              {objective.description}
            </div>
          )}
        </div>
        {!config.enabled && (
          <span className="learning-objectives-editor__removed-status">Removed</span>
        )}
        <button
          type="button"
          className={classNames('btn btn-link btn-sm', !config.enabled && 'text-primary')}
          disabled={!editMode}
          onClick={() => onToggleEnabled(objective.resource_id)}
          aria-label={`${config.enabled ? 'Remove' : 'Restore'} ${objective.title}`}
        >
          <i className={`fas fa-${config.enabled ? 'trash-alt' : 'undo-alt'}`}></i>
        </button>
      </div>

      {mode === 'summary' && config.enabled && (
        <div className="learning-objectives-editor__recommendations">
          <RecommendationList
            label="Pages students should revisit:"
            actionLabel="+ Add Page(s)"
            actionAriaLabel={`Add revisit pages for ${objective.title}`}
            kind="revisit_pages"
            objective={objective}
            pageIds={config.revisit_pages}
            pagesById={pagesById}
            pageOptionsUnavailable={pageOptionsUnavailable}
            editMode={editMode}
            onAddRecommendation={onAddRecommendation}
            onRemoveRecommendation={onRemoveRecommendation}
          />
          <RecommendationList
            label="Practice:"
            actionLabel="+ Add Practice"
            actionAriaLabel={`Add practice pages for ${objective.title}`}
            kind="practice_pages"
            objective={objective}
            pageIds={config.practice_pages}
            pagesById={pagesById}
            pageOptionsUnavailable={pageOptionsUnavailable}
            editMode={editMode}
            onAddRecommendation={onAddRecommendation}
            onRemoveRecommendation={onRemoveRecommendation}
          />
        </div>
      )}
    </li>
  );
};

type RecommendationListProps = {
  label: string;
  actionLabel: string;
  actionAriaLabel: string;
  kind: RecommendationKind;
  objective: ResolvedLearningObjective;
  pageIds: number[];
  pagesById: Map<number, Persistence.Page>;
  pageOptionsUnavailable: boolean;
  editMode: boolean;
  onAddRecommendation: (resourceId: number, kind: RecommendationKind) => void;
  onRemoveRecommendation: (resourceId: number, kind: RecommendationKind, pageId: number) => void;
};

const RecommendationList = ({
  label,
  actionLabel,
  actionAriaLabel,
  kind,
  objective,
  pageIds,
  pagesById,
  pageOptionsUnavailable,
  editMode,
  onAddRecommendation,
  onRemoveRecommendation,
}: RecommendationListProps) => (
  <div className="learning-objectives-editor__recommendation-row">
    <div className="learning-objectives-editor__recommendation-label">{label}</div>
    <div className="learning-objectives-editor__chips">
      {pageIds.map((pageId) => {
        const title = pagesById.get(pageId)?.title || `Page ${pageId}`;

        return (
          <span key={pageId} className="learning-objectives-editor__chip">
            {title}
            <button
              type="button"
              disabled={!editMode}
              onClick={() => onRemoveRecommendation(objective.resource_id, kind, pageId)}
              aria-label={`Remove ${title} from ${label} for ${objective.title}`}
            >
              <i className="fas fa-times"></i>
            </button>
          </span>
        );
      })}
      <button
        type="button"
        className="btn btn-link learning-objectives-editor__add-page"
        disabled={!editMode || pageOptionsUnavailable}
        onClick={() => onAddRecommendation(objective.resource_id, kind)}
        aria-label={actionAriaLabel}
      >
        {actionLabel}
      </button>
    </div>
  </div>
);

const orderObjectives = (objectives: ResolvedLearningObjective[]): ResolvedLearningObjective[] => {
  const byResourceId = new Map(objectives.map((objective) => [objective.resource_id, objective]));
  const childrenByParent = new Map<number, ResolvedLearningObjective[]>();
  const roots: ResolvedLearningObjective[] = [];

  objectives.forEach((objective) => {
    const inScopeParentResourceIds = parentResourceIds(objective).filter((parentResourceId) =>
      byResourceId.has(parentResourceId),
    );

    if (inScopeParentResourceIds.length === 0) {
      roots.push(objective);
      return;
    }

    inScopeParentResourceIds.forEach((parentResourceId) => {
      childrenByParent.set(parentResourceId, [
        ...(childrenByParent.get(parentResourceId) || []),
        objective,
      ]);
    });
  });

  const ordered: ResolvedLearningObjective[] = [];
  const emittedResourceIds = new Set<number>();

  const visit = (objective: ResolvedLearningObjective) => {
    if (emittedResourceIds.has(objective.resource_id) || isWaitingForParent(objective)) {
      return;
    }

    ordered.push(objective);
    emittedResourceIds.add(objective.resource_id);
    (childrenByParent.get(objective.resource_id) || []).forEach(visit);
  };

  const isWaitingForParent = (objective: ResolvedLearningObjective) =>
    parentResourceIds(objective)
      .filter((parentResourceId) => byResourceId.has(parentResourceId))
      .some((parentResourceId) => !emittedResourceIds.has(parentResourceId));

  roots.forEach(visit);
  objectives.filter((objective) => !emittedResourceIds.has(objective.resource_id)).forEach(visit);

  return ordered;
};

const parentResourceIds = (objective: ResolvedLearningObjective): number[] => {
  if (objective.parent_resource_ids && objective.parent_resource_ids.length > 0) {
    return objective.parent_resource_ids;
  }

  return objective.parent_resource_id == null ? [] : [objective.parent_resource_id];
};

const isLearningObjectivesContentMode = (value: string): value is LearningObjectivesContentMode =>
  value === 'introduction' || value === 'summary';

interface LearningObjectivesOutlineItemProps extends OutlineItemProps {
  contentItem: LearningObjectivesContent;
}

export const LearningObjectivesOutlineItem = (props: LearningObjectivesOutlineItemProps) => {
  const { contentItem } = props;

  return (
    <OutlineItem {...props}>
      <Icon iconName="fas fa-bullseye" />
      <Description title="Learning Objectives">
        {contentItem.mode === 'summary' ? 'Summary' : 'Introduction'}
      </Description>
    </OutlineItem>
  );
};
