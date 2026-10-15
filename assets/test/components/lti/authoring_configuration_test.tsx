import React from 'react';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { LTIExternalTool } from 'components/activities/lti_external_tool/LTIExternalToolAuthoring';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';

jest.mock('components/activities/AuthoringElementProvider', () => ({
  useAuthoringElementContext: jest.fn(),
}));
jest.mock('data/persistence/lti_platform', () => ({
  getLtiExternalToolDetails: jest.fn(),
}));
const details = {
  name: 'Test Tool',
  status: 'enabled',
  deep_linking_enabled: true,
  can_configure_tool: true,
  request_id: 'active',
  request_token: 'request-token',
  launch_params: { login_url: 'https://tool.example/login', login_hint: 'hint' },
};
let context: any;
const handlers = new Map<Element, (event: any) => void>();
beforeAll(() => {
  const jq = (element: Element) => ({
    modal: () => undefined,
    on: (name: string, handler: (event: any) => void) => {
      if (name === 'hide.bs.modal') handlers.set(element, handler);
    },
  });
  (window as any).$ = jq;
  (global as any).$ = jq;
});
afterAll(() => {
  delete (window as any).$;
  delete (global as any).$;
});
beforeEach(() => {
  jest.clearAllMocks();
  handlers.clear();
  jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation(() => undefined);
  (getLtiExternalToolDetails as jest.Mock).mockResolvedValue(details);
  context = {
    model: {
      openInNewTab: false,
      authoring: { parts: [] },
      deepLink: { type: 'ltiResourceLink', text: 'Task description' },
    },
    editMode: true,
    mode: 'authoring',
    projectSlug: 'project',
    activityId: 42,
    authoringContext: { supportsLtiConfiguration: true },
    onEdit: jest.fn(),
    onCustomEvent: jest.fn((name: string) =>
      Promise.resolve(
        name === 'ltiAuthoringPrepare' ? details : name === 'ltiAuthoringClose' ? 'closed' : true,
      ),
    ),
  };
  (useAuthoringElementContext as jest.Mock).mockImplementation(() => context);
});
afterEach(() => jest.restoreAllMocks());
async function selectDeep() {
  await screen.findByRole('button', { name: 'Launch Tool' });
  fireEvent.change(screen.getByLabelText('Launch type'), { target: { value: 'deep_link' } });
  fireEvent.click(screen.getByRole('button', { name: 'Change Selection from Tool' }));
}
function result(container: HTMLElement, data: unknown) {
  const frame = container.querySelector('iframe') as HTMLIFrameElement;
  act(() => {
    window.dispatchEvent(
      new MessageEvent('message', {
        source: frame.contentWindow,
        origin: window.location.origin,
        data: { type: 'lti_authoring_deep_link_response', ...(data as any) },
      }),
    );
  });
}

it('unsupported hosts keep Regular preview and omit configuration', async () => {
  context.authoringContext = {};
  render(<LTIExternalTool />);
  await screen.findByRole('button', { name: 'Launch Tool' });
  expect(screen.queryByRole('option', { name: 'Deep Link' })).toBeNull();
  fireEvent.click(screen.getByRole('button', { name: 'Launch Tool' }));
  await waitFor(() =>
    expect(getLtiExternalToolDetails).toHaveBeenLastCalledWith('projects', 'project', '42', {
      role: 'developer',
      launch_type: 'regular',
    }),
  );
  expect(context.onCustomEvent).not.toHaveBeenCalled();
});

it('shows portable metadata fallback and an accessible preparation state', async () => {
  let prepare!: (value: typeof details) => void;
  context.onCustomEvent.mockImplementation(
    () =>
      new Promise((resolve) => {
        prepare = resolve;
      }),
  );
  render(<LTIExternalTool />);
  await selectDeep();
  expect(screen.getByText('Selection: Task description')).toBeTruthy();
  expect(screen.getByRole('status').textContent).toContain('Preparing');
  expect(
    screen.getByRole('button', { name: 'Change Selection from Tool' }).matches(':disabled'),
  ).toBe(true);
  await act(async () => prepare(details));
  expect(screen.getByRole('dialog')).toBeTruthy();
});

it.each(['developer', 'instructor'])(
  'passes the selected %s role to host preparation',
  async (role) => {
    const { container } = render(<LTIExternalTool />);
    await screen.findByLabelText('Launch as');
    fireEvent.change(screen.getByLabelText('Launch as'), { target: { value: role } });
    await selectDeep();
    await waitFor(() => expect(container.querySelector('iframe')).not.toBeNull());
    expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringPrepare', { role });
  },
);

it('submits the signed token once, ignores old returns and closes after host acknowledgement without a second save message', async () => {
  const { container } = render(<LTIExternalTool />);
  await selectDeep();
  await waitFor(() => expect(container.querySelector('iframe')).not.toBeNull());
  result(container, { request_id: 'old', token: 'old-token' });
  expect(context.onCustomEvent).not.toHaveBeenCalledWith('ltiAuthoringSave', expect.anything());
  let save!: (value: boolean) => void;
  context.onCustomEvent.mockImplementation((name: string) =>
    name === 'ltiAuthoringSave'
      ? new Promise((resolve) => {
          save = resolve;
        })
      : Promise.resolve('closed'),
  );
  result(container, { request_id: 'active', token: 'result-token' });
  result(container, { request_id: 'active', token: 'duplicate' });
  await waitFor(() =>
    expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringSave', {
      token: 'result-token',
    }),
  );
  expect(context.onEdit).not.toHaveBeenCalled();
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(screen.queryByText('Saving selection…')).toBeNull();
  await act(async () => save(true));
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(screen.queryByRole('dialog')).toBeNull();
  expect(
    context.onCustomEvent.mock.calls.filter(([name]: [string]) => name === 'ltiAuthoringSave'),
  ).toHaveLength(1);
});

it('retains the previous model, announces save failure and releases its editor controls', async () => {
  const { container } = render(<LTIExternalTool />);
  await selectDeep();
  await waitFor(() => expect(container.querySelector('iframe')).not.toBeNull());
  context.onCustomEvent.mockImplementation((name: string) =>
    name === 'ltiAuthoringSave'
      ? Promise.reject(new Error('Save failed'))
      : Promise.resolve('closed'),
  );
  result(container, { request_id: 'active', token: 'result-token' });
  await waitFor(() => expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringClose', {}));
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(context.onEdit).not.toHaveBeenCalled();
  expect(
    screen.getAllByRole('alert').some((alert) => alert.textContent?.includes('Save failed')),
  ).toBe(true);
});

it('closes without saving and ignores returns after the modal is gone', async () => {
  const { container } = render(<LTIExternalTool />);
  await selectDeep();
  await waitFor(() => expect(container.querySelector('iframe')).not.toBeNull());
  const event = { preventDefault: jest.fn() };
  act(() => handlers.get(screen.getByRole('dialog'))!(event));
  expect(event.preventDefault).toHaveBeenCalled();
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringClose', {});
  expect(context.onCustomEvent).not.toHaveBeenCalledWith('ltiAuthoringSave', expect.anything());
});

it('restores keyboard focus to the launch trigger after Close', async () => {
  render(<LTIExternalTool />);
  await screen.findByRole('button', { name: 'Launch Tool' });
  fireEvent.change(screen.getByLabelText('Launch type'), { target: { value: 'deep_link' } });
  const trigger = screen.getByRole('button', { name: 'Change Selection from Tool' });
  trigger.focus();
  fireEvent.click(trigger);
  await screen.findByRole('dialog');
  act(() => handlers.get(screen.getByRole('dialog'))!({ preventDefault: jest.fn() }));
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  expect(document.activeElement).toBe(trigger);
});
