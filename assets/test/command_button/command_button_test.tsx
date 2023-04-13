import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { CommandButton } from '../../src/components/common/CommandButton';
import { CommandButton as CommandButtonModel } from '../../src/data/content/model/elements/types';

describe('Command Button', () => {
  it('should render a command button and trigger an event on click', async () => {
    const buttonConfig: CommandButtonModel = {
      type: 'command_button',
      id: 'command_button',
      children: [{ text: 'Click Me' }],
      message: 'Test Message',
      target: 'test_target',
      style: 'button',
    };

    const de = document.dispatchEvent;
    document.dispatchEvent = jest.fn();

    render(<CommandButton commandButton={buttonConfig}>Click Me</CommandButton>);

    expect(screen.getByText('Click Me')).toBeDefined();

    await fireEvent(
      screen.getByText('Click Me'),
      new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
      }),
    );

    const mock = document.dispatchEvent as jest.Mock;
    expect(mock.mock.calls.length).toBe(1);
    expect(mock.mock.calls[0][0].type).toBe('oli-command-button-click');
    expect(mock.mock.calls[0][0].detail).toEqual({
      forId: 'test_target',
      message: 'Test Message',
    });

    document.dispatchEvent = de;
  });
});
