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
): ResolvedLearningObjective => ({
  resource_id: resourceId,
  title,
  description: null,
  parent_resource_id: parentResourceId,
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
  it('shows the Objectives content type at the page root and inserts the default element', () => {
    const onAddItem = jest.fn();
    const onSetTip = jest.fn();
    const onResetTip = jest.fn();

    render(
      <NonActivities
        index={[0]}
        parents={[]}
        onAddItem={onAddItem}
        onSetTip={onSetTip}
        onResetTip={onResetTip}
        featureFlags={{ adaptivity: false, equity: false, survey: true }}
        resourceContext={resourceContext([])}
      />,
    );

    const objectivesChoice = screen.getByRole('button', { name: 'Objectives' });

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
  });

  it('does not show the Objectives content type for nested insert positions', () => {
    render(
      <NonActivities
        index={[0, 0]}
        parents={[createGroup() as ResourceContent]}
        onAddItem={jest.fn()}
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

  it('stores Include Sub-Objectives as element-local state and can hide children', () => {
    const props = defaultEditorProps(element({ include_sub_objectives: false }));

    render(<LearningObjectivesEditor {...props} />);

    expect(screen.getByText('Linear equations')).toBeInTheDocument();
    expect(screen.queryByText('Slope intercept form')).not.toBeInTheDocument();

    fireEvent.click(screen.getByLabelText('Include Sub-Objectives'));

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
    const titles = screen.getAllByRole('listitem').map((element) => element.textContent);

    expect(titles).toEqual(expect.arrayContaining(['Linear equations', 'Slope intercept form']));
    expect(titles.indexOf('Linear equations')).toBeLessThan(titles.indexOf('Slope intercept form'));
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

  it('restores a disabled objective by flipping advisory enabled state', () => {
    const contentItem = element({
      learning_objectives: [
        { resource_id: 1, enabled: false, revisit_pages: [10], practice_pages: [] },
        { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
      ],
    });
    const props = defaultEditorProps(contentItem);

    render(<LearningObjectivesEditor {...props} />);

    fireEvent.click(screen.getByRole('button', { name: 'Restore Linear equations' }));

    expect(props.onEdit).toHaveBeenCalledWith({
      ...contentItem,
      learning_objectives: [
        { resource_id: 1, enabled: true, revisit_pages: [10], practice_pages: [] },
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
});
