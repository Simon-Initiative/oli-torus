import React from 'react';
import { render, screen, waitFor, within } from '@testing-library/react';
import 'components/parts/janus-image/delivery-entry';
import PopupWindow from 'components/parts/janus-popup/PopupWindow';
import 'components/parts/janus-text-flow/delivery-entry';

test('focuses the full text from asynchronously initialized real text and image parts', async () => {
  render(
    <PopupWindow
      accessibleName="What is Ω?"
      config={{ width: 400, height: 300 }}
      context={{ currentActivity: 'test', mode: 'delivery' }}
      parts={[
        {
          id: 'chemistry',
          type: 'janus-text-flow',
          custom: {
            x: 0,
            y: 0,
            width: 400,
            visible: true,
            palette: { useHtmlProps: true },
            nodes: [
              {
                tag: 'p',
                children: [
                  { tag: 'text', text: 'Ω is equal to ([Ca', children: [] },
                  { tag: 'sup', text: '2+', children: [] },
                  { tag: 'text', text: ']).', children: [] },
                ],
              },
              {
                tag: 'p',
                text: 'The more soluble a substance, the higher its value.',
                children: [],
              },
              { tag: 'p', text: 'Last paragraph: carbonate concentration.', children: [] },
            ],
          },
        },
        {
          id: 'diagram',
          type: 'janus-image',
          custom: { x: 0, y: 200, width: 100, height: 100, src: '/test.png', alt: 'Oyster reef' },
        },
      ]}
    />,
  );

  const dialog = screen.getByRole('dialog', { name: 'What is Ω?' });
  await waitFor(() => {
    expect(document.activeElement).toHaveTextContent(
      'Ω is equal to ([Ca2+]). The more soluble a substance, the higher its value. Last paragraph: carbonate concentration. Oyster reef',
    );
    expect(dialog).toContainElement(document.activeElement as HTMLElement);
    expect(document.activeElement).toHaveAttribute('tabindex', '-1');
  });
  const description = document.activeElement;
  expect(description).toHaveClass('sr-only');
  expect(description).not.toHaveAttribute('hidden');
  expect(dialog).not.toHaveAttribute('aria-describedby');
  expect(description?.childNodes).toHaveLength(1);
  expect(within(dialog).getByText('2+', { selector: 'sup' })).toBeVisible();
  expect(within(dialog).getByRole('img', { name: 'Oyster reef' })).toBeVisible();
  expect(within(dialog).getByRole('button', { name: 'Close' })).toBeVisible();
});
