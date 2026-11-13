import React from 'react';
import '@testing-library/jest-dom';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { invokeCreationFunc } from 'components/activities/creation';
import 'components/activities/interactive/authoring-entry';
import { InteractiveModelSchema } from 'components/activities/interactive/schema';
import { defaultInteractiveModel } from 'components/activities/interactive/utils';
import {
  ActivityEditorProps,
  InlineActivityEditor,
} from 'components/activity/InlineActivityEditor';
import { Objective } from 'data/content/objective';
import { ResourceContext } from 'data/content/resource';
import {
  cancelInteractiveBuild,
  getInteractiveBuild,
  startInteractiveBuild,
} from 'data/persistence/interactive';

jest.mock('data/persistence/interactive', () => ({
  cancelInteractiveBuild: jest.fn(),
  getInteractiveBuild: jest.fn(),
  startInteractiveBuild: jest.fn(),
}));
class MockEventSource {
  static instances: MockEventSource[] = [];
  onopen: (() => void) | null = null;
  onerror: (() => void) | null = null;
  listeners: Record<string, (event: any) => void> = {};
  close = jest.fn();
  constructor(public url: string) {
    MockEventSource.instances.push(this);
  }
  addEventListener(name: string, callback: (event: any) => void) {
    this.listeners[name] = callback;
  }
  emit(name: string, payload: unknown) {
    this.listeners[name]?.({ data: JSON.stringify(payload) });
  }
}
Object.defineProperty(window, 'EventSource', { value: MockEventSource, writable: true });
beforeEach(() => {
  jest.resetAllMocks();
  MockEventSource.instances = [];
  (getInteractiveBuild as jest.Mock).mockResolvedValue({ build: null });
});

jest.mock('components/TextEditor', () => ({ TextEditor: () => null }));
jest.mock('components/resource/Tags', () => ({ Tags: () => null }));
jest.mock('components/editing/elements/image/imageActions', () => ({ selectImage: jest.fn() }));
jest.mock('components/resource/objectives/ActivityLOs', () => ({
  ActivityLOs: () => <div data-testid="part-objectives" />,
}));

const objectives: Objective[] = [
  { id: 1, title: 'Chemistry', parentIds: null },
  { id: 2, title: 'Calculate concentrations', parentIds: [1] },
  { id: 3, title: 'Mix solutions', parentIds: [1] },
  { id: 4, title: 'Third-level objective', parentIds: [2] },
];

function editorProps(model: InteractiveModelSchema): ActivityEditorProps {
  return {
    model,
    objectives: { [model.authoring.parts[0].id]: [] },
    allObjectives: objectives,
    authoringElement: 'oli-interactive-authoring',
    typeSlug: 'oli_interactive',
    activitySlug: 'interactive-instance',
    activityId: 42,
    friendlyName: 'Interactive',
    description: 'Interactive',
    title: 'Interactive',
    editMode: true,
    projectSlug: 'chemistry',
    optionalContentTypes: { ecl: false, triggers: false },
    allTags: [],
    tags: [],
    variables: [],
    banked: false,
    revisionHistoryLink: false,
    canRemove: true,
    contentBreaksExist: false,
    onEdit: jest.fn(),
    onPostUndoable: jest.fn(),
    onRegisterNewObjective: jest.fn(),
    onRegisterNewTag: jest.fn(),
    onRemove: jest.fn(),
  };
}

it('registers both elements and creates independent models through normal activity creation', async () => {
  const create = () => invokeCreationFunc('oli-interactive-authoring', {} as ResourceContext);
  const first = (await create()) as InteractiveModelSchema;
  const second = (await create()) as InteractiveModelSchema;

  expect(customElements.get('oli-interactive-authoring')).toBeDefined();
  expect(customElements.get('oli-interactive-delivery')).toBeDefined();
  expect(first.authoring.parts).toHaveLength(1);
  expect(first.authoring.parts[0].id).not.toBe(second.authoring.parts[0].id);
  expect(first.authoring.prompt).toBe('');
  expect(first.authoring.selectedSkillIds).toEqual([]);
});

it('edits and reloads prompt and multiple skills through the page editor model update flow', async () => {
  const initialModel = defaultInteractiveModel();
  const initialProps = editorProps(initialModel);
  let saved = initialModel;
  function Editor() {
    const [model, setModel] = React.useState(saved);
    return (
      <InlineActivityEditor
        {...initialProps}
        model={model}
        onEdit={(update) => {
          saved = update.content as InteractiveModelSchema;
          setModel(saved);
        }}
      />
    );
  }

  const view = render(<Editor />);
  const concentrations = await screen.findByRole('checkbox', { name: 'Calculate concentrations' });
  expect(screen.queryByRole('checkbox', { name: 'Chemistry' })).not.toBeInTheDocument();
  expect(screen.queryByRole('checkbox', { name: 'Third-level objective' })).not.toBeInTheDocument();
  expect(screen.queryByTestId('part-objectives')).not.toBeInTheDocument();

  fireEvent.click(concentrations);
  fireEvent.click(screen.getByRole('checkbox', { name: 'Mix solutions' }));
  fireEvent.change(screen.getByLabelText('Author prompt'), {
    target: { value: 'Build a virtual chemistry lab.' },
  });
  expect(saved.authoring.selectedSkillIds).toEqual([2, 3]);
  expect(saved.authoring.prompt).toBe('Build a virtual chemistry lab.');
  expect(saved.authoring.parts).toEqual(initialModel.authoring.parts);

  view.unmount();
  render(<Editor />);
  expect(await screen.findByLabelText('Author prompt')).toHaveValue(
    'Build a virtual chemistry lab.',
  );
  expect(screen.getByRole('checkbox', { name: 'Calculate concentrations' })).toBeChecked();
  expect(screen.getByRole('checkbox', { name: 'Mix solutions' })).toBeChecked();
  fireEvent.click(screen.getByRole('checkbox', { name: 'Mix solutions' }));
  expect(saved.authoring.selectedSkillIds).toEqual([2]);
  expect(screen.getByRole('button', { name: 'Build' })).toBeEnabled();
});

it('launches with model, reasoning and the page lock, then applies generated parts and objective mappings', async () => {
  const model = defaultInteractiveModel();
  model.authoring.prompt = 'Make a lab';
  model.authoring.selectedSkillIds = [2];
  const completed = {
    ...model,
    bundle: {
      buildId: 'build-1',
      bucket: 'media',
      prefix: 'interactives/build-1',
      indexUrl: 'https://media/interactives/build-1/index.html',
    },
    authoring: { ...model.authoring, parts: [{ ...model.authoring.parts[0], id: 'measure' }] },
  };
  (startInteractiveBuild as jest.Mock).mockResolvedValue({
    build: { id: 'build-1', status: 'queued', error: null },
  });
  (getInteractiveBuild as jest.Mock).mockResolvedValueOnce({ build: null }).mockResolvedValue({
    build: { id: 'build-1', status: 'completed', error: null },
    activity: { model: completed, objectives: { measure: [2] } },
  });
  const props = editorProps(model);
  render(<InlineActivityEditor {...props} lockId={99} />);
  await screen.findByLabelText('Author prompt');
  await waitFor(() => expect(getInteractiveBuild).toHaveBeenCalled());
  fireEvent.click(screen.getByRole('button', { name: 'Build' }));
  await waitFor(() =>
    expect(startInteractiveBuild).toHaveBeenCalledWith('chemistry', 42, 99, model.authoring),
  );
  await waitFor(() =>
    expect(props.onEdit).toHaveBeenCalledWith(
      expect.objectContaining({ content: completed, objectives: { measure: [2] } }),
    ),
  );
});

it('persists model and reasoning selections and reports a launch failure', async () => {
  const model = defaultInteractiveModel();
  model.authoring.prompt = 'Make a lab';
  model.authoring.selectedSkillIds = [2];
  const props = editorProps(model);
  let saved = model;
  function Editor() {
    const [current, setCurrent] = React.useState(saved);
    return (
      <InlineActivityEditor
        {...props}
        model={current}
        onEdit={(update) => {
          saved = update.content as InteractiveModelSchema;
          setCurrent(saved);
        }}
      />
    );
  }
  (startInteractiveBuild as jest.Mock).mockRejectedValue({ message: 'The edit lock was lost.' });
  render(<Editor />);
  fireEvent.change(await screen.findByLabelText('Model'), { target: { value: 'gpt-6-sol' } });
  fireEvent.change(screen.getByLabelText('Reasoning level'), { target: { value: 'high' } });
  expect(saved.authoring.model).toBe('gpt-6-sol');
  expect(saved.authoring.reasoning).toBe('high');
  fireEvent.click(screen.getByRole('button', { name: 'Build' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('The edit lock was lost.');
  expect(screen.getByRole('button', { name: 'Build' })).toBeEnabled();
});

it('respects read-only editing and leaves other activity objective selectors in place', async () => {
  const props = editorProps(defaultInteractiveModel());
  const view = render(<InlineActivityEditor {...props} editMode={false} />);
  expect(await screen.findByLabelText('Author prompt')).toBeDisabled();
  expect(screen.getByRole('checkbox', { name: 'Mix solutions' })).toBeDisabled();
  view.rerender(<InlineActivityEditor {...props} typeSlug="oli_multiple_choice" />);
  expect(screen.getByTestId('part-objectives')).toBeInTheDocument();
});

it('revises built experiences while original and historical prompts remain read-only', async () => {
  const model = defaultInteractiveModel();
  model.authoring.prompt = 'Original lab request';
  model.authoring.revision_prompts = ['Add feedback'];
  model.authoring.selectedSkillIds = [2];
  model.bundle = {
    buildId: 'first',
    bucket: 'media',
    prefix: 'interactives/first',
    indexUrl: 'https://media.example.edu/first/index.html',
  };
  const props = editorProps(model);
  let saved = model;
  function Editor() {
    const [current, setCurrent] = React.useState(saved);
    return (
      <InlineActivityEditor
        {...props}
        model={current}
        onEdit={(change) => {
          saved = change.content as InteractiveModelSchema;
          setCurrent(saved);
        }}
      />
    );
  }
  (startInteractiveBuild as jest.Mock).mockResolvedValue({
    build: { id: 'next', status: 'queued', error: null },
  });
  render(<Editor />);
  expect(await screen.findByLabelText('Saved prompt')).toHaveValue('Original lab request');
  expect(screen.getByLabelText('Saved prompt')).toHaveAttribute('readonly');
  fireEvent.change(screen.getByLabelText('Prompt history'), { target: { value: '0' } });
  expect(screen.getByLabelText('Saved prompt')).toHaveValue('Add feedback');
  expect(screen.getByRole('button', { name: 'Revise', exact: true })).toBeDisabled();
  fireEvent.change(screen.getByLabelText('Revision prompt'), {
    target: { value: 'Make the graph harder' },
  });
  expect(saved.authoring.prompt).toBe('Original lab request');
  expect(saved.authoring.revision_prompts).toEqual(['Add feedback']);
  fireEvent.click(screen.getByRole('button', { name: 'Preview experience' }));
  const previous = screen.getByTitle('Interactive learning experience');
  fireEvent.click(screen.getByRole('button', { name: 'Restart preview' }));
  expect(previous).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: 'Revise', exact: true }));
  await waitFor(() =>
    expect(startInteractiveBuild).toHaveBeenCalledWith(
      'chemistry',
      42,
      42,
      expect.objectContaining({
        prompt: 'Original lab request',
        revision_prompt: 'Make the graph harder',
      }),
    ),
  );
});

it.each([false, true])(
  'reconnects an active session and cancellation restores the full prompt (revision=%s)',
  async (revision) => {
    const model = defaultInteractiveModel();
    model.authoring.prompt = 'Original experience';
    model.authoring.selectedSkillIds = [2];
    model.authoring.revision_prompt = 'Add an explanation';
    if (revision)
      model.bundle = {
        buildId: 'previous',
        bucket: 'media',
        prefix: 'interactives/previous',
        indexUrl: 'https://media.example.edu/previous/index.html',
      };
    const active = { id: 'running', status: 'running', error: null };
    (getInteractiveBuild as jest.Mock).mockResolvedValue({ build: active });
    const props = editorProps(model);
    const view = render(<InlineActivityEditor {...props} />);
    const label = revision ? 'Revision prompt' : 'Author prompt';
    const prompt = await screen.findByLabelText(label);
    await screen.findByLabelText('Agent output');
    expect(prompt).toHaveAttribute('readonly');
    expect(prompt).toHaveAttribute('rows', '3');
    expect(prompt).not.toBeDisabled();
    const first = MockEventSource.instances[0];
    act(() => first.emit('output', { text: 'Agent working\nReading the current files' }));
    expect(screen.getByLabelText('Agent output')).toHaveValue(
      'Agent working\nReading the current files',
    );
    act(() => first.onerror?.());
    expect(screen.getByText('Reconnecting…')).toBeInTheDocument();
    view.unmount();
    expect(first.close).toHaveBeenCalled();
    render(<InlineActivityEditor {...props} />);
    await screen.findByLabelText('Agent output');
    expect(MockEventSource.instances).toHaveLength(2);
    const second = MockEventSource.instances[1];
    act(() =>
      second.emit('output', {
        text: 'Agent working\nRecovered prior output\nRunning browser checks',
      }),
    );
    expect((screen.getByLabelText('Agent output') as HTMLTextAreaElement).value).toContain(
      'Recovered prior output',
    );
    const cancelled = { ...active, status: 'cancelled' };
    (cancelInteractiveBuild as jest.Mock).mockResolvedValue({ build: cancelled });
    (getInteractiveBuild as jest.Mock).mockResolvedValue({ build: cancelled });
    fireEvent.click(screen.getByRole('button', { name: 'Cancel session' }));
    await waitFor(() => expect(screen.queryByLabelText('Agent output')).not.toBeInTheDocument());
    expect(cancelInteractiveBuild).toHaveBeenCalledWith('chemistry', 42, 'running');
    expect(screen.getByLabelText(label)).toHaveAttribute('rows', '14');
    expect(screen.getByLabelText(label)).not.toHaveAttribute('readonly');
    expect(screen.getByLabelText(label)).toHaveValue(
      revision ? 'Add an explanation' : 'Original experience',
    );
    expect(second.close).toHaveBeenCalled();
  },
);

it('preserves reading position and resumes following when the author scrolls back to the end', async () => {
  const model = defaultInteractiveModel();
  (getInteractiveBuild as jest.Mock).mockResolvedValue({
    build: { id: 'scroll-session', status: 'running', error: null },
  });
  render(<InlineActivityEditor {...editorProps(model)} />);
  const output = (await screen.findByLabelText('Agent output')) as HTMLTextAreaElement;
  const stream = MockEventSource.instances[0];
  Object.defineProperties(output, {
    scrollHeight: { value: 1000, configurable: true },
    clientHeight: { value: 200, configurable: true },
  });
  output.scrollTop = 120;
  fireEvent.scroll(output);
  act(() => stream.emit('output', { text: 'New output while reading earlier work' }));
  expect(output.scrollTop).toBe(120);
  output.scrollTop = 800;
  fireEvent.scroll(output);
  act(() => stream.emit('output', { text: 'Follow this new output at the end' }));
  expect(output.scrollTop).toBe(1000);
});
