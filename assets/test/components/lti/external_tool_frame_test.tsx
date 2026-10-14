import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';

const props = {
  mode: 'delivery' as const,
  name: 'Test Tool',
  resourceId: 'activity-42',
  status: 'enabled',
  launchParams: { login_url: 'https://tool.example/login', login_hint: 'hint' },
};

beforeEach(() => {
  jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

function message(frame: HTMLIFrameElement, data: unknown, origin = window.location.origin) {
  act(() => {
    window.dispatchEvent(
      new MessageEvent('message', { source: frame.contentWindow, origin, data }),
    );
  });
}

it('keeps same-resource instances distinct and targets each mounted frame', () => {
  const { container, rerender } = render(
    <>
      <LTIExternalToolFrame {...props} />
      <LTIExternalToolFrame {...props} />
    </>,
  );
  const frames = Array.from(container.querySelectorAll('iframe'));
  const forms = Array.from(container.querySelectorAll('form'));
  expect(frames).toHaveLength(2);
  expect(frames[0].name).not.toBe(frames[1].name);
  expect(forms.map((form) => form.target)).toEqual(frames.map((frame) => frame.name));
  const names = frames.map((frame) => frame.name);

  rerender(
    <>
      <LTIExternalToolFrame {...props} height={700} />
      <LTIExternalToolFrame {...props} height={800} />
    </>,
  );
  expect(Array.from(container.querySelectorAll('iframe')).map((frame) => frame.name)).toEqual(
    names,
  );
  expect(HTMLFormElement.prototype.submit).toHaveBeenCalledTimes(2);
});

it('retains new-window launches without mounting an embedded delivery frame', () => {
  const { container } = render(<LTIExternalToolFrame {...props} openInNewTab />);
  expect(container.querySelector('iframe')).toBeNull();
  expect(container.querySelector('form')?.target).toBe('_blank');
  expect(screen.getByRole('button', { name: 'Load Test Tool in a new window' })).toBeTruthy();
  expect(HTMLFormElement.prototype.submit).not.toHaveBeenCalled();
});

it('ignores messages from another instance or an external origin', () => {
  const onDone = jest.fn();
  const { container } = render(
    <>
      <LTIExternalToolFrame {...props} onDeepLinkingComplete={onDone} />
      <LTIExternalToolFrame {...props} />
    </>,
  );
  const [first, second] = Array.from(container.querySelectorAll('iframe'));
  const result = { type: 'lti_deep_linking_response', status: 'success' };
  message(second, result);
  message(first, result, 'https://tool.example');
  expect(onDone).not.toHaveBeenCalled();
  message(first, result);
  expect(onDone).toHaveBeenCalledTimes(1);
});

it('never treats a failed return as successful completion', () => {
  const onDone = jest.fn();
  const { container } = render(<LTIExternalToolFrame {...props} onDeepLinkingComplete={onDone} />);
  const frame = container.querySelector('iframe') as HTMLIFrameElement;
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'error',
    error_description: 'Rejected',
  });
  expect(onDone).not.toHaveBeenCalled();
});

it('accepts a successful return only once and ignores the following close event', () => {
  const onDone = jest.fn();
  const onClose = jest.fn();
  const { container } = render(
    <LTIExternalToolFrame {...props} onDeepLinkingComplete={onDone} onCloseModal={onClose} />,
  );
  const frame = container.querySelector('iframe') as HTMLIFrameElement;
  message(frame, { type: 'lti_deep_linking_response', status: 'success' });
  message(frame, { type: 'lti_close_modal' });
  message(frame, { type: 'lti_deep_linking_response', status: 'success' });
  expect(onDone).toHaveBeenCalledTimes(1);
  expect(onClose).not.toHaveBeenCalled();
});

it('mounts an authoring frame on launch and keeps the form associated with it', () => {
  const { container } = render(<LTIExternalToolFrame {...props} mode="authoring" />);
  expect(container.querySelector('iframe')).toBeNull();
  container.querySelector('form')?.addEventListener('submit', (event) => event.preventDefault());
  fireEvent.click(screen.getByRole('button', { name: 'Load Test Tool' }));
  expect(container.querySelector('form')?.target).toBe(container.querySelector('iframe')?.name);
});

it('requires the active configuration request before reporting success', () => {
  const onDone = jest.fn();
  const { container } = render(
    <LTIExternalToolFrame
      {...props}
      deepLinkRequestId="active-request"
      onDeepLinkingComplete={onDone}
    />,
  );
  const frame = container.querySelector('iframe') as HTMLIFrameElement;
  message(frame, { type: 'lti_deep_linking_response', status: 'success' });
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'success',
    request_id: 'old-request',
  });
  expect(onDone).not.toHaveBeenCalled();
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'success',
    request_id: 'active-request',
  });
  expect(onDone).toHaveBeenCalledTimes(1);
});

it('keeps an error terminal and ignores a later success for that frame', () => {
  const onDone = jest.fn();
  const onError = jest.fn();
  const { container } = render(
    <LTIExternalToolFrame {...props} onDeepLinkingComplete={onDone} onDeepLinkingError={onError} />,
  );
  const frame = container.querySelector('iframe') as HTMLIFrameElement;
  message(frame, {
    type: 'lti_deep_linking_response',
    status: 'error',
    error_description: 'Save failed',
  });
  message(frame, { type: 'lti_deep_linking_response', status: 'success' });
  expect(onError).toHaveBeenCalledWith('Save failed');
  expect(onDone).not.toHaveBeenCalled();
});
