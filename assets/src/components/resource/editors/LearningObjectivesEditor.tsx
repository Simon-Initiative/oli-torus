import React, { useEffect, useMemo, useState } from 'react';
import {
  AlmondIcon,
  LargeTreeIcon,
  LearningObjectivesIcon,
  PottedPlantIcon,
  TrashIcon,
} from 'components/misc/icons/Icons';
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

const INTRODUCTION_DESCRIPTION =
  'Learners will be introduced to the learning objectives attached to activities in the container you place this page (ex. entire course, unit, module, or section).';

const SUMMARY_DESCRIPTION =
  'Learners will receive a proficiency summary regarding the learning objectives attached to activities in the container you place this page (ex. entire course, unit, module, or section).';

const SUMMARY_HELPER_TEXT =
  'Learners will see how their proficiency is on the objectives in this container. For objectives students have low and medium proficiency on, recommend pages to revisit and extra practice opportunities.';

const PROFICIENCY_DESCRIPTION =
  'Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work. Proficiency estimates become more reliable as you complete more activities.';

const PROFICIENCY_LEVELS = [
  {
    label: 'Not Enough Information',
    icon: <PottedPlantIcon />,
    className: 'learning-objectives-editor__proficiency-card--unknown',
    description: 'Complete a few more activities before we can estimate your proficiency.',
  },
  {
    label: 'Beginning Proficiency',
    icon: <AlmondIcon />,
    className: 'learning-objectives-editor__proficiency-card--beginning',
    description:
      'You are beginning to learn how to apply this learning objective. Continue practicing and reviewing feedback to strengthen your proficiency.',
  },
  {
    label: 'Growing Proficiency',
    icon: <LearningObjectivesIcon />,
    className: 'learning-objectives-editor__proficiency-card--growing',
    description:
      "You've clearly applied this learning objective. Continue practicing across more opportunities to strengthen your consistency.",
  },
  {
    label: 'Strong Proficiency',
    icon: <LargeTreeIcon />,
    className: 'learning-objectives-editor__proficiency-card--strong',
    description:
      'You are likely to successfully apply this learning objective in different contexts. Continue applying this learning objective as you progress through the course.',
  },
];

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
  const objectiveGroups = useMemo(
    () => groupObjectives(orderedObjectives, includeSubObjectives),
    [includeSubObjectives, orderedObjectives],
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
        .map((page) => ({ value: page.id, title: page.title }) as Option);

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
  const description =
    contentItem.mode === 'summary' ? SUMMARY_DESCRIPTION : INTRODUCTION_DESCRIPTION;

  return (
    <ContentBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={onRemove}
      headerActions={
        <>
          <label className="sr-only" htmlFor={`${contentItem.id}-mode`}>
            Learning Objectives mode
          </label>
          <span
            className="learning-objectives-editor__mode-wrapper"
            data-value={contentItem.mode === 'summary' ? 'Summary' : 'Introduction'}
          >
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
          </span>
        </>
      }
    >
      <div className="learning-objectives-editor mb-3">
        <div className="learning-objectives-editor__header">
          <h3 className="label">
            {contentItem.mode === 'summary'
              ? 'Learning Objective Summary'
              : 'Learning Objective Introduction'}
          </h3>
        </div>

        <p className="learning-objectives-editor__description">{description}</p>

        <div className="custom-control custom-checkbox learning-objectives-editor__sub-objectives">
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
            Include sub-objectives
          </label>
        </div>

        <div
          className={classNames(
            'learning-objectives-editor__panel',
            contentItem.mode === 'summary' && 'learning-objectives-editor__panel--summary',
          )}
        >
          {contentItem.mode === 'summary' && (
            <p className="learning-objectives-editor__summary-helper">{SUMMARY_HELPER_TEXT}</p>
          )}

          {pageOptionsUnavailable && (
            <div className="alert alert-warning learning-objectives-editor__warning" role="alert">
              Unable to load course pages. Recommendation selectors are unavailable.
            </div>
          )}

          {objectiveGroups.length === 0 ? (
            <div className="alert alert-warning learning-objectives-editor__warning" role="alert">
              <strong>Warning</strong>
              <span>
                There are no learning objectives attached to activities in this container.
              </span>
            </div>
          ) : (
            <ul className="learning-objectives-editor__list">
              {objectiveGroups.map((group) => (
                <ObjectiveCard
                  key={group.objective.resource_id}
                  group={group}
                  config={configFor(group.objective.resource_id)}
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

          <ProficiencyExplanation />
        </div>
      </div>
    </ContentBlock>
  );
};

type ObjectiveGroup = {
  objective: ResolvedLearningObjective;
  children: ResolvedLearningObjective[];
  ordinal: number;
};

type ObjectiveCardProps = {
  group: ObjectiveGroup;
  config: LearningObjectiveConfig;
  mode: LearningObjectivesContentMode;
  editMode: boolean;
  pagesById: Map<number, Persistence.Page>;
  pageOptionsUnavailable: boolean;
  onToggleEnabled: (resourceId: number) => void;
  onAddRecommendation: (resourceId: number, kind: RecommendationKind) => void;
  onRemoveRecommendation: (resourceId: number, kind: RecommendationKind, pageId: number) => void;
};

const ObjectiveCard = ({
  group,
  config,
  mode,
  editMode,
  pagesById,
  pageOptionsUnavailable,
  onToggleEnabled,
  onAddRecommendation,
  onRemoveRecommendation,
}: ObjectiveCardProps) => {
  const { objective, children, ordinal } = group;

  return (
    <li
      className={classNames(
        'learning-objectives-editor__objective',
        mode === 'summary' && 'learning-objectives-editor__objective--summary',
        !config.enabled && 'learning-objectives-editor__objective--disabled',
      )}
    >
      <div className="learning-objectives-editor__objective-header">
        <div className="learning-objectives-editor__objective-copy">
          <div className="learning-objectives-editor__objective-title-row">
            <span
              className="learning-objectives-editor__objective-number"
              style={{ color: '#757682' }}
            >
              LO {ordinal}
            </span>
            <span className="learning-objectives-editor__objective-title">{objective.title}</span>
          </div>
          {children.length > 0 && (
            <ul className="learning-objectives-editor__sub-objective-list">
              {children.map((child) => (
                <li key={child.resource_id} className="learning-objectives-editor__sub-objective">
                  {child.title}
                </li>
              ))}
            </ul>
          )}
        </div>
        {!config.enabled && (
          <span className="learning-objectives-editor__removed-status">Removed</span>
        )}
        <button
          type="button"
          className={classNames(
            'btn btn-link btn-sm learning-objectives-editor__objective-action',
            !config.enabled && 'text-primary',
          )}
          disabled={!editMode}
          onClick={() => onToggleEnabled(objective.resource_id)}
          aria-label={`${config.enabled ? 'Remove' : 'Restore'} ${objective.title}`}
        >
          {config.enabled ? <TrashIcon /> : <i className="fas fa-undo-alt"></i>}
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

const ProficiencyExplanation = () => (
  <details className="learning-objectives-editor__proficiency">
    <summary className="learning-objectives-editor__proficiency-summary">
      <span className="learning-objectives-editor__proficiency-title">
        <i className="fas fa-info-circle" aria-hidden="true"></i>
        <span>What is proficiency and how is it estimated?</span>
      </span>
      <i className="fas fa-chevron-down" aria-hidden="true"></i>
    </summary>
    <p className="learning-objectives-editor__proficiency-description">{PROFICIENCY_DESCRIPTION}</p>
    <div className="learning-objectives-editor__proficiency-cards">
      {PROFICIENCY_LEVELS.map((level) => (
        <div
          key={level.label}
          className={classNames('learning-objectives-editor__proficiency-card', level.className)}
        >
          {level.icon}
          <strong>{level.label}</strong>
          <span>{level.description}</span>
        </div>
      ))}
    </div>
  </details>
);

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
    {pageIds.length > 0 && (
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
      </div>
    )}
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
);

const groupObjectives = (
  objectives: ResolvedLearningObjective[],
  includeSubObjectives: boolean,
): ObjectiveGroup[] => {
  const byResourceId = new Map(objectives.map((objective) => [objective.resource_id, objective]));
  const childrenByParent = new Map<number, ResolvedLearningObjective[]>();

  objectives.forEach((objective) => {
    parentResourceIds(objective)
      .filter((parentResourceId) => byResourceId.has(parentResourceId))
      .forEach((parentResourceId) => {
        childrenByParent.set(parentResourceId, [
          ...(childrenByParent.get(parentResourceId) || []),
          objective,
        ]);
      });
  });

  const roots = objectives.filter(
    (objective) =>
      parentResourceIds(objective).filter((parentResourceId) => byResourceId.has(parentResourceId))
        .length === 0,
  );

  return roots.map((objective, index) => ({
    objective,
    children: includeSubObjectives ? childrenByParent.get(objective.resource_id) || [] : [],
    ordinal: index + 1,
  }));
};

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
      <Icon>
        <LearningObjectivesIcon width={20} height={20} />
      </Icon>
      <Description title="Learning Objectives">
        {contentItem.mode === 'summary' ? 'Summary' : 'Introduction'}
      </Description>
    </OutlineItem>
  );
};
