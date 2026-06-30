import React from 'react';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import { Modal } from 'components/modal/Modal';

// Modal uses Bootstrap's jQuery plugin in an effect; stub it for jsdom.
beforeAll(() => {
  const jq: any = () => ({ modal: () => undefined, on: () => undefined });
  (window as any).$ = jq;
  (global as any).$ = jq;
});
afterAll(() => {
  delete (window as any).$;
  delete (global as any).$;
});

describe('Modal Escape containment', () => {
  it('stops Escape that originates inside the modal (ancestors must not also close)', () => {
    render(
      <Modal title="Inner" onCancel={jest.fn()}>
        <button>inside</button>
      </Modal>,
    );

    const e = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
    const spy = jest.spyOn(e, 'stopPropagation');

    screen.getByText('inside').dispatchEvent(e);

    expect(spy).toHaveBeenCalled();
  });

  it('does NOT stop Escape that originates outside the modal (e.g. a lingering dismiss-less modal)', () => {
    render(
      <Modal title="Inner" onCancel={jest.fn()}>
        <button>inside</button>
      </Modal>,
    );

    const e = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
    const spy = jest.spyOn(e, 'stopPropagation');

    document.body.dispatchEvent(e);

    expect(spy).not.toHaveBeenCalled();
  });
});
