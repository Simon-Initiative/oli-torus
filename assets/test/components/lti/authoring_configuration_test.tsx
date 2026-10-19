import React from 'react';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { LTIExternalTool } from 'components/activities/lti_external_tool/LTIExternalToolAuthoring';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { deferred, message, mockBootstrapModal, waitForFrame } from './test_helpers';

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
const dismissModal = mockBootstrapModal();
beforeEach(() => {
  jest.clearAllMocks();
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
async function renderConfiguration() {
  const rendered = render(<LTIExternalTool />);
  await selectDeep();
  return { ...rendered, frame: await waitForFrame(rendered.container) };
}
function result(frame: HTMLIFrameElement, data: Record<string, unknown>) {
  message(frame, { type: 'lti_authoring_deep_link_response', ...data });
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
  const prepare = deferred<typeof details>();
  context.onCustomEvent.mockReturnValue(prepare.promise);
  render(<LTIExternalTool />);
  await selectDeep();
  expect(screen.getByText('Selection: Task description')).toBeTruthy();
  expect(screen.getByRole('group', { name: 'Tool launch options' })).toBeTruthy();
  expect(screen.getByRole('status').textContent).toContain('Preparing');
  expect(
    screen.getByRole('button', { name: 'Change Selection from Tool' }).matches(':disabled'),
  ).toBe(true);
  await act(async () => prepare.resolve(details));
  expect(screen.getByRole('dialog')).toBeTruthy();
});

it.each(
  ['developer', 'instructor'].flatMap((role) =>
    ['regular', 'deep_link'].map((launchType) => ({ role, launchType })),
  ),
)('launches $launchType with the selected $role role', async ({ role, launchType }) => {
  const { container } = render(<LTIExternalTool />);
  await screen.findByLabelText('Launch as');
  (getLtiExternalToolDetails as jest.Mock).mockClear();
  fireEvent.change(screen.getByLabelText('Launch as'), { target: { value: role } });
  fireEvent.change(screen.getByLabelText('Launch type'), { target: { value: launchType } });
  fireEvent.click(
    screen.getByRole('button', {
      name: launchType === 'regular' ? 'Launch Tool' : 'Change Selection from Tool',
    }),
  );
  await waitForFrame(container);
  if (launchType === 'regular') {
    expect(getLtiExternalToolDetails).toHaveBeenCalledWith('projects', 'project', '42', {
      role,
      launch_type: 'regular',
    });
    expect(context.onCustomEvent).not.toHaveBeenCalled();
  } else {
    expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringPrepare', { role });
    expect(getLtiExternalToolDetails).not.toHaveBeenCalled();
  }
});

it('submits the signed token once, ignores old returns and closes after host acknowledgement without a second save message', async () => {
  const { frame } = await renderConfiguration();
  result(frame, { request_id: 'old', token: 'old-token' });
  expect(context.onCustomEvent).not.toHaveBeenCalledWith('ltiAuthoringSave', expect.anything());
  const save = deferred<boolean>();
  context.onCustomEvent.mockImplementation((name: string) =>
    name === 'ltiAuthoringSave' ? save.promise : Promise.resolve('closed'),
  );
  result(frame, { request_id: 'active', token: 'result-token' });
  result(frame, { request_id: 'active', token: 'duplicate' });
  await waitFor(() =>
    expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringSave', {
      token: 'result-token',
    }),
  );
  expect(context.onEdit).not.toHaveBeenCalled();
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(screen.queryByText('Saving selection…')).toBeNull();
  await act(async () => save.resolve(true));
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(screen.queryByRole('dialog')).toBeNull();
  expect(
    context.onCustomEvent.mock.calls.filter(([name]: [string]) => name === 'ltiAuthoringSave'),
  ).toHaveLength(1);
});

it('retains the previous model, announces save failure and releases its editor controls', async () => {
  const { frame } = await renderConfiguration();
  context.onCustomEvent.mockImplementation((name: string) =>
    name === 'ltiAuthoringSave'
      ? Promise.reject(new Error('Save failed'))
      : Promise.resolve('closed'),
  );
  result(frame, { request_id: 'active', token: 'result-token' });
  await waitFor(() => expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringClose', {}));
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(context.onEdit).not.toHaveBeenCalled();
  expect(
    screen.getAllByRole('alert').some((alert) => alert.textContent?.includes('Save failed')),
  ).toBe(true);
});

it('closes without saving and ignores returns after the modal is gone', async () => {
  const { frame } = await renderConfiguration();
  const event = dismissModal(screen.getByRole('dialog'));
  expect(event.preventDefault).toHaveBeenCalled();
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  expect(context.onCustomEvent).toHaveBeenCalledWith('ltiAuthoringClose', {});
  result(frame, { request_id: 'active', token: 'late-result' });
  expect(context.onCustomEvent).not.toHaveBeenCalledWith('ltiAuthoringSave', expect.anything());
});
