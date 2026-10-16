import { KeepScrollAtBottom } from 'hooks/keep_scroll_at_bottom';

it('scrolls the element the hook is attached to', () => {
  const messageContainer = document.createElement('div');
  Object.defineProperty(messageContainer, 'scrollHeight', { value: 240 });

  const updated = KeepScrollAtBottom.updated as (this: { el: HTMLElement }) => void;
  updated.call({ el: messageContainer });

  expect(messageContainer.scrollTop).toEqual(240);
});
