import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { NonActivities } from 'components/content/add_resource_content/NonActivities';
import { LearningObjectivesEditor } from 'components/resource/editors/LearningObjectivesEditor';
import {
  LearningObjectivesContent,
  ResolvedLearningObjective,
  ResourceContent,
  ResourceContext,
  createGroup,
} from 'data/content/resource';
import * as Persistence from 'data/persistence/resource';

const resolvedObjective = (
  resourceId: number,
  title: string,
  parentResourceId: number | null = null,
  parentResourceIds: number[] = parentResourceId == null ? [] : [parentResourceId],
): ResolvedLearningObjective => ({
  resource_id: resourceId,
  title,
  description: null,
  parent_resource_id: parentResourceId,
  parent_resource_ids: parentResourceIds,
  children: [],
  related_activity_ids: [],
  directly_matched: true,
});

const element = (updates: Partial<LearningObjectivesContent> = {}): LearningObjectivesContent => ({
  type: 'learning_objectives',
  id: 'lo-element',
  mode: 'introduction',
  include_sub_objectives: true,
  learning_objectives: [
    { resource_id: 1, enabled: true, revisit_pages: [10], practice_pages: [] },
    { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
  ],
  ...updates,
});

const resourceContext = (learningObjectives: ResolvedLearningObjective[]): ResourceContext =>
  ({
    graded: false,
    authorEmail: 'author@example.edu',
    projectSlug: 'project-1',
    resourceSlug: 'page-1',
    resourceId: 100,
    hasExperiments: false,
    title: 'Page 1',
    content: { model: [] },
    objectives: { attached: [] },
    allObjectives: [],
    learningObjectives,
    allTags: [],
    activityContexts: [],
    optionalContentTypes: { ecl: false, triggers: false },
  } as ResourceContext);

const unresolvedLearningObjectivesContext = (): ResourceContext => {
  const context = resourceContext([]);
  delete context.learningObjectives;

  return context;
};

const defaultEditorProps = (contentItem: LearningObjectivesContent) => ({
  contentItem,
  editMode: true,
  canRemove: true,
  projectSlug: 'project-1',
  onEdit: jest.fn(),
  onRemove: jest.fn(),
  resourceContext: resourceContext([
    resolvedObjective(1, 'Linear equations'),
    resolvedObjective(2, 'Slope intercept form', 1),
  ]),
});

describe('Learning Objectives insert menu', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('shows the Objectives content type at the page root and inserts the default element', async () => {
    const resolved = [
      resolvedObjective(1, 'Linear equations'),
      resolvedObjective(2, 'Slope intercept form', 1),
    ];
    jest.spyOn(Persistence, 'learningObjectives').mockResolvedValue({
      type: 'success',
      learningObjectives: resolved,
    });

    const onAddItem = jest.fn();
    const onStartLearningObjectivesRefresh = jest.fn();
    const onRefreshLearningObjectives = jest.fn();
    const onFinishLearningObjectivesRefresh = jest.fn();
    const onSetTip = jest.fn();
    const onResetTip = jest.fn();

    render(
      <NonActivities
        index={[0]}
        parents={[]}
        onAddItem={onAddItem}
        onStartLearningObjectivesRefresh={onStartLearningObjectivesRefresh}
        onRefreshLearningObjectives={onRefreshLearningObjectives}
        onFinishLearningObjectivesRefresh={onFinishLearningObjectivesRefresh}
        onSetTip={onSetTip}
        onResetTip={onResetTip}
        featureFlags={{ adaptivity: false, equity: false, survey: true }}
        resourceContext={resourceContext([])}
      />,
    );

    const objectivesChoice = screen.getByRole('button', { name: 'Objectives' });

    expect(objectivesChoice.querySelector('.resource-choice-icon svg')).toBeInTheDocument();
    expect(objectivesChoice.querySelector('.resource-choice-icon')).not.toHaveClass('fa-bullseye');

    fireEvent.focus(objectivesChoice);

    expect(onSetTip).toHaveBeenCalledWith('Render a learning objective introduction or summary');

    fireEvent.blur(objectivesChoice);

    expect(onResetTip).toHaveBeenCalled();

    fireEvent.click(objectivesChoice);

    expect(onAddItem).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'learning_objectives',
        mode: 'introduction',
        include_sub_objectives: true,
        learning_objectives: [],
      }),
      [0],
    );

    const inserted = onAddItem.mock.calls[0][0] as LearningObjectivesContent;

    expect(onStartLearningObjectivesRefresh).toHaveBeenCalledWith(inserted.id);
    await waitFor(() =>
      expect(onRefreshLearningObjectives).toHaveBeenCalledWith(inserted.id, resolved),
    );
    expect(onFinishLearningObjectivesRefresh).not.toHaveBeenCalled();
  });

  it('uses already resolved learning objectives from context when inserting', async () => {
    const resolved = [
      resolvedObjective(1, 'Linear equations'),
      resolvedObjective(2, 'Slope intercept form', 1),
    ];
    const learningObjectivesSpy = jest.spyOn(Persistence, 'learningObjectives').mockResolvedValue({
      type: 'success',
      learningObjectives: [],
    });
    const onAddItem = jest.fn();
    const onStartLearningObjectivesRefresh = jest.fn();
    const onRefreshLearningObjectives = jest.fn();
    const onFinishLearningObjectivesRefresh = jest.fn();

    render(
      <NonActivities
        index={[0]}
        parents={[]}
        onAddItem={onAddItem}
        onStartLearningObjectivesRefresh={onStartLearningObjectivesRefresh}
        onRefreshLearningObjectives={onRefreshLearningObjectives}
        onFinishLearningObjectivesRefresh={onFinishLearningObjectivesRefresh}
        onSetTip={jest.fn()}
        onResetTip={jest.fn()}
        featureFlags={{ adaptivity: false, equity: false, survey: true }}
        resourceContext={resourceContext(resolved)}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Objectives' }));

    const inserted = onAddItem.mock.calls[0][0] as LearningObjectivesContent;

    expect(onStartLearningObjectivesRefresh).toHaveBeenCalledWith(inserted.id);
    await waitFor(() =>
      expect(onRefreshLearningObjectives).toHaveBeenCalledWith(inserted.id, resolved),
    );
    expect(learningObjectivesSpy).not.toHaveBeenCalled();
    expect(onFinishLearningObjectivesRefresh).not.toHaveBeenCalled();
  });

  it('does not show the Objectives content type for nested insert positions', () => {
    render(
      <NonActivities
        index={[0, 0]}
        parents={[createGroup() as ResourceContent]}
        onAddItem={jest.fn()}
        onStartLearningObjectivesRefresh={jest.fn()}
        onRefreshLearningObjectives={jest.fn()}
        onFinishLearningObjectivesRefresh={jest.fn()}
        onSetTip={jest.fn()}
        onResetTip={jest.fn()}
        featureFlags={{ adaptivity: false, equity: false, survey: true }}
        resourceContext={resourceContext([])}
      />,
    );

    expect(screen.queryByRole('button', { name: 'Objectives' })).not.toBeInTheDocument();
  });
});

describe('LearningObjectivesEditor', () => {
  beforeEach(() => {
    jest.spyOn(Persistence, 'pages').mockResolvedValue({
      type: 'success',
      pages: [
        { id: 10, slug: 'intro', title: 'Intro Page' },
        { id: 20, slug: 'practice', title: 'Practice Page' },
      ],
    });
    (window as any).oliDispatch = jest.fn();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('renders the Introduction description and base authoring panel', () => {
    const props = defaultEditorProps(element());

    render(<LearningObjectivesEditor {...props} />);

    expect(
      screen.getByText(
        'Learners will be introduced to the learning objectives attached to activities in the container you place this page (ex. entire course, unit, module, or section).',
      ),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('Include sub-objectives')).toBeChecked();
    expect(screen.getByText('What is proficiency and how is it estimated?')).toBeInTheDocument();
  });

  it('renders the Summary description and helper text', () => {
    const props = defaultEditorProps(
      element({
        mode: 'summary',
        learning_objectives: [
          { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [] },
          { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
        ],
      }),
    );

    render(<LearningObjectivesEditor {...props} />);

    expect(
      screen.getByText(
        'Learners will receive a proficiency summary regarding the learning objectives attached to activities in the container you place this page (ex. entire course, unit, module, or section).',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        'Learners will see how their proficiency is on the objectives in this container. For objectives students have low and medium proficiency on, recommend pages to revisit and extra practice opportunities.',
      ),
    ).toBeInTheDocument();
  });

  it('renders Summary recommendation controls as stacked authoring groups', async () => {
    const props = defaultEditorProps(element({ mode: 'summary' }));

    const { container } = render(<LearningObjectivesEditor {...props} />);

    await waitFor(() => expect(screen.getByText('Intro Page')).toBeInTheDocument());

    expect(
      container.querySelector('.learning-objectives-editor__panel--summary'),
    ).toBeInTheDocument();

    const recommendationRows = container.querySelectorAll(
      '.learning-objectives-editor__recommendation-row',
    );
    const revisitRow = recommendationRows[0];

    expect(revisitRow.children[0]).toHaveTextContent('Pages students should revisit:');
    expect(revisitRow.children[1]).toHaveClass('learning-objectives-editor__chips');
    expect(revisitRow.children[2]).toHaveTextContent('+ Add Page(s)');
  });

  it('disables Summary add actions with a tooltip when all pages are already selected', async () => {
    const props = defaultEditorProps(
      element({
        mode: 'summary',
        learning_objectives: [
          { resource_id: 1, enabled: true, revisit_pages: [10, 20], practice_pages: [] },
          { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
        ],
      }),
    );

    render(<LearningObjectivesEditor {...props} />);

    await waitFor(() => expect(screen.getByText('Intro Page')).toBeInTheDocument());

    const addRevisitPages = screen.getByRole('button', {
      name: 'Add revisit pages for Linear equations',
    });

    expect(addRevisitPages).toBeDisabled();
    expect(addRevisitPages.closest('.learning-objectives-editor__add-page-wrapper')).toHaveClass(
      'learning-objectives-editor__add-page-wrapper--disabled',
    );
    expect(
      addRevisitPages.closest('.learning-objectives-editor__add-page-wrapper'),
    ).toHaveAttribute('data-tooltip', 'No more pages are available to select.');
    expect(
      addRevisitPages.closest('.learning-objectives-editor__add-page-wrapper'),
    ).not.toHaveAttribute('tabIndex');
  });

  it('changes mode without dropping advisory objective config', () => {
    const contentItem = element();
    const props = defaultEditorProps(contentItem);

    render(<LearningObjectivesEditor {...props} />);

    const modeSelector = screen.getByLabelText('Learning Objectives mode');

    modeSelector.focus();
    expect(modeSelector).toHaveFocus();

    fireEvent.keyDown(modeSelector, { key: 'ArrowDown' });
    fireEvent.change(modeSelector, {
      target: { value: 'summary' },
    });

    expect(props.onEdit).toHaveBeenCalledWith({
      ...contentItem,
      mode: 'summary',
    });
  });

  it('stores Include sub-objectives as element-local state and can hide children', () => {
    const props = defaultEditorProps(element({ include_sub_objectives: false }));

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.getByText('Linear equations')).toBeInTheDocument();
    expect(screen.queryByText('Slope intercept form')).not.toBeInTheDocument();
    expect(
      screen.getByText('Linear equations').closest('.learning-objectives-editor__objective-header'),
    ).toHaveClass('learning-objectives-editor__objective-header--single-line');

    fireEvent.click(screen.getByLabelText('Include sub-objectives'));

    expect(props.onEdit).toHaveBeenCalledWith({
      ...props.contentItem,
      include_sub_objectives: true,
    });
  });

  it('renders objective parents before sub-objectives even when resolver order differs', () => {
    const props = defaultEditorProps(element());
    props.resourceContext = resourceContext([
      resolvedObjective(2, 'Slope intercept form', 1),
      resolvedObjective(1, 'Linear equations'),
    ]);

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.getByText('LO 1')).toBeInTheDocument();
    expect(screen.getByText('Linear equations')).toBeInTheDocument();
    expect(screen.getByText('Slope intercept form')).toBeInTheDocument();
    expect(
      screen
        .getByText('Linear equations')
        .compareDocumentPosition(screen.getByText('Slope intercept form')),
    ).toBe(Node.DOCUMENT_POSITION_FOLLOWING);
  });

  it('does not expose separate remove or restore controls for rendered sub-objectives', () => {
    const props = defaultEditorProps(element());

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.getByText('Slope intercept form')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Remove Slope intercept form' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Restore Slope intercept form' })).toBeNull();
  });

  it('renders every parent before a shared sub-objective', () => {
    const props = defaultEditorProps(element());
    props.resourceContext = resourceContext([
      resolvedObjective(3, 'Shared strategy', 1, [1, 2]),
      resolvedObjective(1, 'Linear equations'),
      resolvedObjective(2, 'Graphing equations'),
    ]);

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.getByText('LO 1')).toBeInTheDocument();
    expect(screen.getByText('LO 2')).toBeInTheDocument();
    expect(screen.getByText('Linear equations')).toBeInTheDocument();
    expect(screen.getByText('Graphing equations')).toBeInTheDocument();
    expect(screen.getAllByText('Shared strategy')).toHaveLength(2);
    expect(
      screen
        .getByText('Linear equations')
        .compareDocumentPosition(screen.getAllByText('Shared strategy')[0]),
    ).toBe(Node.DOCUMENT_POSITION_FOLLOWING);
    expect(
      screen
        .getByText('Graphing equations')
        .compareDocumentPosition(screen.getAllByText('Shared strategy')[1]),
    ).toBe(Node.DOCUMENT_POSITION_FOLLOWING);
  });

  it('updates objective enabled state without deleting the config row', () => {
    const contentItem = element();
    const props = defaultEditorProps(contentItem);

    render(<LearningObjectivesEditor {...props} />);

    fireEvent.click(screen.getByRole('button', { name: 'Remove Linear equations' }));

    expect(props.onEdit).toHaveBeenCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: false, revisit_pages: [10], practice_pages: [] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
  });

  it('restores a disabled objective by flipping advisory enabled state', async () => {
    const contentItem = element({
      mode: 'summary',
      learning_objectives: [
        { resource_id: 1, enabled: false, revisit_pages: [10], practice_pages: [20] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
    const props = defaultEditorProps(contentItem);

    render(<LearningObjectivesEditor {...props} />);

    const restoreButton = screen.getByRole('button', { name: 'Restore Linear equations' });

    expect(restoreButton).not.toHaveTextContent('Restore');
    expect(screen.getByText('Removed')).toBeInTheDocument();
    expect(screen.getByText('Linear equations').closest('li')).toHaveClass(
      'bg-Surface-surface-secondary-muted',
      'learning-objectives-editor__objective--disabled',
    );
    expect(screen.getAllByText('Pages students should revisit:').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Practice:').length).toBeGreaterThan(0);
    await waitFor(() => expect(screen.getByText('Intro Page')).toBeInTheDocument());
    expect(screen.getByText('Practice Page')).toBeInTheDocument();

    fireEvent.click(restoreButton);

    expect(props.onEdit).toHaveBeenCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [10], practice_pages: [20] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
  });

  it('adds and removes Summary recommendation pages through course-scoped page selection', async () => {
    const contentItem = element({ mode: 'summary' });
    const props = defaultEditorProps(contentItem);

    render(<LearningObjectivesEditor {...props} />);

    await waitFor(() => expect(screen.getByText('Intro Page')).toBeInTheDocument());

    fireEvent.click(
      screen.getByRole('button', {
        name: 'Remove Intro Page from Pages students should revisit: for Linear equations',
      }),
    );

    expect(props.onEdit).toHaveBeenCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });

    fireEvent.click(
      screen.getByRole('button', { name: 'Add practice pages for Linear equations' }),
    );

    const displayAction = ((window as any).oliDispatch as jest.Mock).mock.calls[0][0];
    await expect(displayAction.component.props.onFetchOptions()).resolves.toEqual([
      { value: 10, title: 'Intro Page' },
      { value: 20, title: 'Practice Page' },
    ]);
    expect(Persistence.pages).toHaveBeenCalledWith('project-1');

    displayAction.component.props.onDone(20);

    expect(props.onEdit).toHaveBeenLastCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [10], practice_pages: [20] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });

    ((window as any).oliDispatch as jest.Mock).mockClear();

    fireEvent.click(screen.getByRole('button', { name: 'Add revisit pages for Linear equations' }));

    const revisitDisplayAction = ((window as any).oliDispatch as jest.Mock).mock.calls[0][0];
    revisitDisplayAction.component.props.onDone(20);

    expect(props.onEdit).toHaveBeenLastCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [10, 20], practice_pages: [] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });

    const practiceContentItem = element({
      mode: 'summary',
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [20] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
    const practiceProps = defaultEditorProps(practiceContentItem);

    render(<LearningObjectivesEditor {...practiceProps} />);

    await waitFor(() => expect(screen.getAllByText('Practice Page')[0]).toBeInTheDocument());

    fireEvent.click(
      screen.getByRole('button', {
        name: 'Remove Practice Page from Practice: for Linear equations',
      }),
    );

    expect(practiceProps.onEdit).toHaveBeenCalledWith({
      ...practiceContentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
  });

  it('throws typed errors when recommendation page options cannot be fetched', async () => {
    jest.spyOn(Persistence, 'pages').mockResolvedValue({
      type: 'error',
      message: 'failed to resolve pages',
    } as any);
    const props = defaultEditorProps(
      element({
        mode: 'summary',
        learning_objectives: [
          { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [] },
          { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
        ],
      }),
    );

    render(<LearningObjectivesEditor {...props} />);

    fireEvent.click(screen.getByRole('button', { name: 'Add revisit pages for Linear equations' }));

    const displayAction = ((window as any).oliDispatch as jest.Mock).mock.calls[0][0];

    await expect(displayAction.component.props.onFetchOptions()).rejects.toThrow(
      'failed to resolve pages',
    );
  });

  it('shows one alert and disables recommendation selectors when course pages fail to load', async () => {
    jest.spyOn(Persistence, 'pages').mockRejectedValue(new Error('failed'));
    const props = defaultEditorProps(element({ mode: 'summary' }));

    render(<LearningObjectivesEditor {...props} />);

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Unable to load course pages. Recommendation selectors are unavailable.',
    );
    expect(screen.getAllByRole('alert')).toHaveLength(1);
    expect(
      screen.getByRole('button', { name: 'Add revisit pages for Linear equations' }),
    ).toBeDisabled();
    expect(
      screen.getByRole('button', { name: 'Add practice pages for Linear equations' }),
    ).toBeDisabled();
  });

  it('places the empty learning objectives warning inside the base panel', () => {
    const props = defaultEditorProps(element());
    props.resourceContext = resourceContext([]);

    const { container } = render(<LearningObjectivesEditor {...props} />);

    const warning = screen.getByRole('alert');

    expect(warning).toHaveTextContent('Warning');
    expect(warning).toHaveTextContent(
      'There are no learning objectives attached to activities in this container.',
    );
    expect(warning).toHaveClass('bg-Fill-Accent-fill-accent-orange');
    expect(
      container.querySelector('svg.learning-objectives-editor__empty-warning-icon path'),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Dismiss warning' })).toBeInTheDocument();
    expect(screen.getByText('What is proficiency and how is it estimated?')).toBeInTheDocument();
  });

  it('does not show the empty learning objectives warning while objectives are unresolved', () => {
    const props = defaultEditorProps(element());
    props.resourceContext = unresolvedLearningObjectivesContext();

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(screen.queryByText('Linear equations')).not.toBeInTheDocument();
    expect(screen.getByText('What is proficiency and how is it estimated?')).toBeInTheDocument();
  });

  it('does not show the empty learning objectives warning while inserted objectives are refreshing', () => {
    const contentItem = element();
    const props = defaultEditorProps(contentItem);
    props.resourceContext = {
      ...resourceContext([]),
      learningObjectivesRefreshPendingFor: contentItem.id,
    };

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(screen.getByText('What is proficiency and how is it estimated?')).toBeInTheDocument();
  });

  it('dismisses the empty learning objectives warning without removing the base panel content', () => {
    const props = defaultEditorProps(element());
    props.resourceContext = resourceContext([]);

    render(<LearningObjectivesEditor {...props} />);

    fireEvent.click(screen.getByRole('button', { name: 'Dismiss warning' }));

    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(screen.getByText('What is proficiency and how is it estimated?')).toBeInTheDocument();
  });
});
