import React from 'react';
import '@testing-library/jest-dom';
import { act, render, screen } from '@testing-library/react';
import { DeliveryElementProps } from 'components/activities/DeliveryElement';
import { InteractiveExperience } from 'components/activities/interactive/InteractiveDelivery';
import { InteractiveModelSchema } from 'components/activities/interactive/schema';

const bundle = {
  buildId: 'build-1',
  bucket: 'media',
  prefix: 'interactives/build-1',
  indexUrl: 'https://media.example.edu/interactives/build-1/index.html',
};

it('renders the stored bundle from a delivery model without authoring data and reloads a replaced bundle', () => {
  const view = render(<InteractiveExperience model={{ bundle }} />);
  const frame = screen.getByTitle('Interactive learning experience');
  expect(frame).toHaveAttribute('src', bundle.indexUrl);
  expect(frame).toHaveAttribute('sandbox', 'allow-scripts allow-same-origin');
  expect(frame).toHaveAttribute('referrerpolicy', 'no-referrer');
  expect(frame).toHaveAttribute('height', '576');
  expect(frame).not.toHaveAttribute('srcdoc');
  expect(frame).not.toHaveAttribute('allow');

  const updated = {
    ...bundle,
    indexUrl: 'https://media.example.edu/interactives/build-2/index.html',
  };
  view.rerender(<InteractiveExperience model={{ bundle: updated }} />);
  expect(screen.getByTitle('Interactive learning experience')).toHaveAttribute(
    'src',
    updated.indexUrl,
  );
  expect(frame).not.toBeInTheDocument();
});

it('retains opaque-origin sandboxing when assets share the Torus origin', () => {
  render(
    <InteractiveExperience
      model={{
        bundle: {
          ...bundle,
          indexUrl: `${window.location.origin}/interactives/build-1/index.html`,
        },
      }}
    />,
  );
  expect(screen.getByTitle('Interactive learning experience')).toHaveAttribute(
    'sandbox',
    'allow-scripts',
  );
});

it.each([
  undefined,
  'javascript:alert(1)',
  'data:text/html,<script>alert(1)</script>',
  'not a URL',
  'https://user:password@media.example.edu/index.html',
])(
  'shows an unavailable state rather than embedding an absent or invalid bundle URL: %s',
  (indexUrl) => {
    const model = indexUrl ? { bundle: { ...bundle, indexUrl } } : {};
    const view = render(<InteractiveExperience model={model} />);
    expect(screen.getByRole('status')).toHaveTextContent('This interactive is not available yet.');
    expect(view.container.querySelector('iframe')).toBeNull();
  },
);

it('remounts the experience when Torus creates a fresh activity attempt', () => {
  const delivery = {
    mode: 'delivery',
    context: { sectionSlug: 'course' },
    state: { attemptGuid: 'first' },
  } as DeliveryElementProps<InteractiveModelSchema>;
  const view = render(<InteractiveExperience model={{ bundle }} delivery={delivery} />);
  const previous = screen.getByTitle('Interactive learning experience');
  view.rerender(
    <InteractiveExperience
      model={{ bundle }}
      delivery={{ ...delivery, state: { ...delivery.state, attemptGuid: 'second' } }}
    />,
  );
  expect(previous).not.toBeInTheDocument();
});

it('returns an in-flight bridge response when Torus rerenders the same activity', async () => {
  let finish: (value: any) => void = () => undefined;
  global.fetch = jest.fn(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  ) as jest.Mock;
  const delivery = {
    mode: 'delivery',
    context: { sectionSlug: 'course' },
    state: { attemptGuid: 'same' },
  } as DeliveryElementProps<InteractiveModelSchema>;
  const view = render(<InteractiveExperience model={{ bundle }} delivery={delivery} />);
  const frame = screen.getByTitle('Interactive learning experience') as HTMLIFrameElement;
  const reply = jest.spyOn(frame.contentWindow!, 'postMessage').mockImplementation(() => undefined);
  window.dispatchEvent(
    new MessageEvent('message', {
      source: frame.contentWindow,
      origin: 'https://media.example.edu',
      data: { channel: 'torus.interactive.v1', id: 'connect', method: 'context' },
    }),
  );
  view.rerender(<InteractiveExperience model={{ bundle }} delivery={{ ...delivery }} />);
  await act(async () => {
    finish({
      ok: true,
      json: async () => ({ result: { version: 1, parts: [], readOnly: false } }),
    });
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
  expect(reply).toHaveBeenCalledWith(
    expect.objectContaining({ id: 'connect', result: expect.objectContaining({ version: 1 }) }),
    'https://media.example.edu',
  );
});

it('loads a managed runtime for a saved media bundle and grows/shrinks with its content', () => {
  const delivery = {
    mode: 'delivery',
    context: { sectionSlug: 'course' },
    state: { attemptGuid: 'resize' },
  } as DeliveryElementProps<InteractiveModelSchema>;
  render(
    <InteractiveExperience
      model={{ bundle: { ...bundle, buildId: 'e591269c-9245-44ed-b0b0-a3259f7c0e8f' } }}
      delivery={delivery}
    />,
  );
  const frame = screen.getByTitle('Interactive learning experience') as HTMLIFrameElement;
  expect(frame).toHaveAttribute(
    'src',
    '/interactives/runtime/e591269c-9245-44ed-b0b0-a3259f7c0e8f',
  );
  for (const height of [1500, 700]) {
    act(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          source: frame.contentWindow,
          origin: 'https://media.example.edu',
          data: { channel: 'torus.interactive.v1', type: 'resize', height },
        }),
      );
    });
    expect(frame).toHaveAttribute('height', String(height));
  }
});
