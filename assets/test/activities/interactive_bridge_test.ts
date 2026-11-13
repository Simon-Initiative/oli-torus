import { readFileSync } from 'fs';
import path from 'path';
import vm from 'vm';
import { DeliveryElementProps } from 'components/activities/DeliveryElement';
import {
  INTERACTIVE_CHANNEL,
  attachInteractiveBridge,
  createDeliveryHandler,
} from 'components/activities/interactive/deliveryBridge';
import { createPreviewSession } from 'components/activities/interactive/previewSession';
import { InteractiveModelSchema } from 'components/activities/interactive/schema';

const delivery = {
  mode: 'delivery',
  context: { sectionSlug: 'course' },
  state: { attemptGuid: 'attempt-1' },
} as DeliveryElementProps<InteractiveModelSchema>;

it('binds messages to the parent attempt and rejects sibling/wrong-origin requests', async () => {
  const frame = document.createElement('iframe');
  document.body.appendChild(frame);
  const send = jest.spyOn(frame.contentWindow!, 'postMessage').mockImplementation(() => undefined);
  global.fetch = jest
    .fn()
    .mockResolvedValue({ ok: true, json: async () => ({ result: { step: 2 } }) });
  const detach = attachInteractiveBridge(
    frame,
    'https://media.example.edu',
    createDeliveryHandler(delivery),
  );
  const data = {
    channel: INTERACTIVE_CHANNEL,
    id: '1',
    method: 'attempt.get',
    params: { key: 'progress', attemptGuid: 'forged' },
  };
  window.dispatchEvent(
    new MessageEvent('message', { source: window, origin: 'https://media.example.edu', data }),
  );
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://evil.example.edu',
      data,
    }),
  );
  expect(fetch).not.toHaveBeenCalled();
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://media.example.edu',
      data,
    }),
  );
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(fetch).toHaveBeenCalledWith(
    '/api/v1/state/course/course/activity_attempt/attempt-1/interactive?method=attempt.get&key=progress',
    expect.objectContaining({ method: 'GET', credentials: 'same-origin' }),
  );
  expect(send).toHaveBeenCalledWith(
    { channel: INTERACTIVE_CHANNEL, id: '1', result: { step: 2 } },
    'https://media.example.edu',
  );
  detach();
  frame.remove();
});

it('blocks review mutations and handles opaque-origin frames', async () => {
  const frame = document.createElement('iframe');
  document.body.appendChild(frame);
  const send = jest.spyOn(frame.contentWindow!, 'postMessage').mockImplementation(() => undefined);
  global.fetch = jest.fn();
  const detach = attachInteractiveBridge(
    frame,
    window.location.origin,
    createDeliveryHandler({
      ...delivery,
      mode: 'review',
    }),
  );
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'null',
      data: { channel: INTERACTIVE_CHANNEL, id: '2', method: 'parts.finalize', params: {} },
    }),
  );
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(fetch).not.toHaveBeenCalled();
  expect(send).toHaveBeenCalledWith(expect.objectContaining({ error: { code: 'read_only' } }), '*');
  detach();
  frame.remove();
});

it('SDK carries JSON state, refreshes finalization context and enforces completion', async () => {
  let receive: (event: any) => void = () => undefined;
  const messages: any[] = [];
  const parent = {
    postMessage: (message: any) => {
      messages.push(message);
      const result =
        message.method === 'context'
          ? { version: 1, readOnly: false, parts: [] }
          : message.method === 'activity.finalize'
          ? { readOnly: true, status: 'evaluated' }
          : message.method === 'attempt.get'
          ? { step: 2 }
          : { readOnly: false };
      receive({
        source: parent,
        origin: 'https://torus.test',
        data: { channel: INTERACTIVE_CHANNEL, id: message.id, result },
      });
    },
  };
  const scope: any = {
    parent,
    addEventListener: (_: string, listener: any) => {
      receive = listener;
    },
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval,
  };
  vm.runInNewContext(
    readFileSync(path.resolve(__dirname, '../../../priv/interactives/workspace/torus.js'), 'utf8'),
    { window: scope },
  );
  const torus = await scope.TorusInteractive.connect();
  expect(await torus.attempt.get('progress')).toEqual({ step: 2 });
  await torus.parts.finalize({ partId: 'measure', response: { value: 7 }, correct: false });
  expect(messages[2]).toEqual(
    expect.objectContaining({
      method: 'parts.finalize',
      params: { partId: 'measure', response: { value: 7 }, correct: false },
    }),
  );
  await torus.activity.finalize();
  expect(torus.context.status).toBe('evaluated');
  await expect(torus.activity.finalize()).resolves.toMatchObject({ status: 'evaluated' });
  await expect(torus.attempt.set('progress', 3)).rejects.toMatchObject({ code: 'read_only' });
});

it('author preview exercises persistence, retries and completion without HTTP or learner records', async () => {
  global.fetch = jest.fn();
  const preview = createPreviewSession(['measure', 'explain']);
  expect(await preview({ method: 'context' })).toMatchObject({ readOnly: false, status: 'active' });
  await preview({ method: 'attempt.set', params: { key: 'progress', value: { step: 2 } } });
  expect(await preview({ method: 'attempt.get', params: { key: 'progress' } })).toEqual({
    step: 2,
  });
  expect(await preview({ method: 'section.get', params: { key: 'progress' } })).toBeNull();
  await expect(preview({ method: 'activity.finalize' })).rejects.toThrow('incomplete_parts');
  await preview({
    method: 'parts.finalize',
    params: { partId: 'measure', response: 7, correct: false },
  });
  const retry = await preview({
    method: 'parts.finalize',
    params: { partId: 'measure', response: 4, correct: true },
  });
  expect(retry).toMatchObject({
    parts: [
      expect.objectContaining({
        id: 'measure',
        attemptNumber: 2,
        score: 1,
        response: { input: 4 },
      }),
      expect.anything(),
    ],
  });
  await preview({
    method: 'parts.finalize',
    params: { partId: 'explain', response: 'because', correct: true },
  });
  expect(await preview({ method: 'activity.finalize' })).toMatchObject({
    readOnly: true,
    status: 'evaluated',
    score: 2,
    outOf: 2,
  });
  await expect(preview({ method: 'attempt.set', params: { key: 'x', value: 1 } })).rejects.toThrow(
    'read_only',
  );
  expect(
    await createPreviewSession(['measure'])({ method: 'attempt.get', params: { key: 'progress' } }),
  ).toBeNull();
  expect(fetch).not.toHaveBeenCalled();
});

it('accepts content height only from this frame and origin', () => {
  const frame = document.createElement('iframe');
  document.body.appendChild(frame);
  const resize = jest.fn();
  const detach = attachInteractiveBridge(frame, 'https://media.example.edu', jest.fn(), resize);
  const data = { channel: INTERACTIVE_CHANNEL, type: 'resize', height: 1450.5 };
  window.dispatchEvent(
    new MessageEvent('message', { source: window, origin: 'https://media.example.edu', data }),
  );
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://wrong.example.edu',
      data,
    }),
  );
  expect(resize).not.toHaveBeenCalled();
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://media.example.edu',
      data,
    }),
  );
  expect(resize).toHaveBeenLastCalledWith(1451);
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://media.example.edu',
      data: { ...data, height: NaN },
    }),
  );
  expect(resize).toHaveBeenCalledTimes(1);
  detach();
  frame.remove();
});

it('retries only the initial context handshake when the parent has not attached yet', async () => {
  jest.useFakeTimers();
  try {
    let receive: (event: any) => void = () => undefined;
    const sent: any[] = [];
    const parent = {
      postMessage: (message: any) => {
        sent.push(message);
        if (sent.length > 1)
          receive({
            source: parent,
            origin: 'https://torus.test',
            data: {
              channel: INTERACTIVE_CHANNEL,
              id: message.id,
              result: { version: 1, readOnly: false, parts: [] },
            },
          });
      },
    };
    const scope: any = {
      parent,
      addEventListener: (_: string, callback: any) => {
        receive = callback;
      },
      setTimeout,
      clearTimeout,
      setInterval,
      clearInterval,
    };
    vm.runInNewContext(
      readFileSync(
        path.resolve(__dirname, '../../../priv/interactives/workspace/torus.js'),
        'utf8',
      ),
      { window: scope },
    );
    const connected = scope.TorusInteractive.connect();
    expect(sent).toHaveLength(1);
    jest.advanceTimersByTime(250);
    const torus = await connected;
    expect(torus.context.version).toBe(1);
    expect(sent).toHaveLength(2);
    expect(sent[0].id).toBe(sent[1].id);
    jest.advanceTimersByTime(1000);
    expect(sent).toHaveLength(2);
  } finally {
    jest.useRealTimers();
  }
});
