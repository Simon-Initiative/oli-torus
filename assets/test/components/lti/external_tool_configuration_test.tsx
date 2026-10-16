import React from 'react';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { ConfigureDeepLinkingModal } from 'components/activities/lti_external_tool/LTIExternalToolDelivery';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import {
  cancelLtiExternalToolDeepLinking,
  getLtiExternalToolDeepLinkingDetails,
} from 'data/persistence/lti_platform';
import { deferred, message, mockBootstrapModal, waitForFrame } from './test_helpers';

jest.mock('data/persistence/lti_platform', () => ({
  getLtiExternalToolDeepLinkingDetails: jest.fn(),
  cancelLtiExternalToolDeepLinking: jest.fn(),
}));

const details = {
  name: 'Test Tool',
  status: 'enabled',
  deep_linking_enabled: true,
  can_configure_tool: true,
  request_id: 'configuration-request',
  request_token: 'signed-request',
  launch_params: { login_url: 'https://tool.example/login', login_hint: 'hint' },
};

const modalProps = {
  sectionSlug: 'course',
  activityId: '42',
  resourceId: '42',
  onDone: jest.fn(),
  onCancel: jest.fn(),
};

const dismissModal = mockBootstrapModal();

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation(() => undefined);
  (getLtiExternalToolDeepLinkingDetails as jest.Mock).mockResolvedValue(details);
  (cancelLtiExternalToolDeepLinking as jest.Mock).mockResolvedValue('cancelled');
});

afterEach(() => jest.restoreAllMocks());

async function renderConfiguration() {
  const rendered = render(<ConfigureDeepLinkingModal {...modalProps} />);
  return { ...rendered, frame: await waitForFrame(rendered.container) };
}

it('mounts configuration in its own frame alongside an embedded regular launch', async () => {
  const { container } = render(
    <>
      <LTIExternalToolFrame
        {...details}
        mode="delivery"
        resourceId="42"
        launchParams={details.launch_params}
      />
      <ConfigureDeepLinkingModal {...modalProps} />
    </>,
  );
  await waitFor(() => expect(container.querySelectorAll('iframe')).toHaveLength(2));
  const frames = Array.from(container.querySelectorAll('iframe'));
  expect(frames[0].name).not.toBe(frames[1].name);
  expect(frames[1].closest('[role=dialog]')).not.toBeNull();
  expect(Array.from(container.querySelectorAll('form')).map((form) => form.target)).toEqual(
    frames.map((frame) => frame.name),
  );
});

it('shows a return error without reporting success or cancelling the modal', async () => {
  const { frame } = await renderConfiguration();
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'error',
    error_description: 'Selection was rejected',
  });
  expect(modalProps.onDone).not.toHaveBeenCalled();
  expect(modalProps.onCancel).not.toHaveBeenCalled();
  expect(screen.getByText('Selection was rejected')).toBeTruthy();
  await waitFor(() =>
    expect(cancelLtiExternalToolDeepLinking).toHaveBeenCalledWith(
      'course',
      '42',
      details.request_token,
    ),
  );
});

it('closes without claiming success when the user finishes manually', async () => {
  const { container } = await renderConfiguration();
  fireEvent.click(container.querySelector('.modal-footer button') as HTMLButtonElement);
  await waitFor(() => expect(modalProps.onCancel).toHaveBeenCalledTimes(1));
  expect(modalProps.onDone).not.toHaveBeenCalled();
});

it('treats a close request from the return frame as cancellation', async () => {
  const { frame } = await renderConfiguration();
  message(frame, { type: 'lti_close_modal' });
  await waitFor(() => expect(modalProps.onCancel).toHaveBeenCalledTimes(1));
  expect(modalProps.onDone).not.toHaveBeenCalled();
});

it('reports success once only for the active request', async () => {
  const { frame } = await renderConfiguration();
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'success',
    request_id: 'old-request',
  });
  expect(modalProps.onDone).not.toHaveBeenCalled();
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'success',
    request_id: details.request_id,
  });
  message(frame, { type: 'lti_close_modal' });
  expect(modalProps.onDone).toHaveBeenCalledTimes(1);
  expect(modalProps.onCancel).not.toHaveBeenCalled();
});

it('shows a details-fetch failure without reporting a saved selection', async () => {
  (getLtiExternalToolDeepLinkingDetails as jest.Mock).mockRejectedValue(
    new Error('Configuration unavailable'),
  );
  const { container } = render(<ConfigureDeepLinkingModal {...modalProps} />);
  await screen.findByText('Configuration unavailable');
  expect(container.querySelector('iframe')).toBeNull();
  expect(modalProps.onDone).not.toHaveBeenCalled();
});

it('controls Bootstrap dismissal until cancellation succeeds', async () => {
  const acknowledgement = deferred<'cancelled'>();
  (cancelLtiExternalToolDeepLinking as jest.Mock).mockReturnValue(acknowledgement.promise);
  const { container } = await renderConfiguration();
  const dialog = container.querySelector('[role=dialog]')!;
  const event = dismissModal(dialog);
  expect(event.preventDefault).toHaveBeenCalled();
  await waitFor(() => expect(cancelLtiExternalToolDeepLinking).toHaveBeenCalledTimes(1));
  expect(screen.getByRole('status').textContent).toContain('Closing');
  dismissModal(dialog, event);
  expect(cancelLtiExternalToolDeepLinking).toHaveBeenCalledTimes(1);
  expect(modalProps.onCancel).not.toHaveBeenCalled();
  await act(async () => acknowledgement.resolve('cancelled'));
  expect(modalProps.onCancel).toHaveBeenCalledTimes(1);
  expect(modalProps.onDone).not.toHaveBeenCalled();
});

it('keeps cancellation failures visible and allows Close to retry', async () => {
  (cancelLtiExternalToolDeepLinking as jest.Mock).mockRejectedValueOnce(new Error('Network error'));
  const { container } = await renderConfiguration();
  fireEvent.click(container.querySelector('.modal-footer button')!);
  await screen.findByText('Could not close configuration. Please try Close again.');
  expect(modalProps.onCancel).not.toHaveBeenCalled();
  fireEvent.click(container.querySelector('.modal-footer button')!);
  await waitFor(() => expect(modalProps.onCancel).toHaveBeenCalledTimes(1));
  expect(cancelLtiExternalToolDeepLinking).toHaveBeenCalledTimes(2);
});

it('refreshes a selection committed before cancellation acknowledgement', async () => {
  (cancelLtiExternalToolDeepLinking as jest.Mock).mockResolvedValue('completed');
  const { container } = await renderConfiguration();
  fireEvent.click(container.querySelector('.modal-footer button')!);
  await waitFor(() => expect(modalProps.onDone).toHaveBeenCalledTimes(1));
  expect(modalProps.onCancel).not.toHaveBeenCalled();
});

it('cancels after preparation resolves when Close is pressed during loading', async () => {
  const prepare = deferred<typeof details>();
  (getLtiExternalToolDeepLinkingDetails as jest.Mock).mockReturnValue(prepare.promise);
  const { container } = render(<ConfigureDeepLinkingModal {...modalProps} />);
  fireEvent.click(container.querySelector('.modal-footer button')!);
  expect(modalProps.onCancel).not.toHaveBeenCalled();
  await act(async () => prepare.resolve(details));
  await waitFor(() => expect(modalProps.onCancel).toHaveBeenCalledTimes(1));
  expect(cancelLtiExternalToolDeepLinking).toHaveBeenCalledWith(
    'course',
    '42',
    details.request_token,
  );
});
