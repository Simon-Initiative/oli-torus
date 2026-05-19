import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { CommandButton } from '../../src/components/common/CommandButton';
import { CommandButton as CommandButtonModel } from '../../src/data/content/model/elements/types';

describe('Command Button Toggle', () => {
  it('cycles toggle states by sending current message then advancing title', async () => {
    const buttonConfig: CommandButtonModel = {
      type: 'command_button',
      id: 'toggle_button',
      children: [{ text: 'Turn Spin On' }],
      message: "script('spin on');",
      target: 'water',
      style: 'button',
      toggleStates: [
        { title: 'Turn Spin On', message: "script('spin on');" },
        { title: 'Turn Spin Off', message: "script('spin off');" },
      ],
    };

    const dispatchSpy = jest.spyOn(document, 'dispatchEvent').mockReturnValue(true);

    render(<CommandButton commandButton={buttonConfig}>Turn Spin On</CommandButton>);

    await fireEvent.click(screen.getByText('Turn Spin On'));
    expect(dispatchSpy).toHaveBeenCalledTimes(1);
    expect((dispatchSpy.mock.calls[0][0] as CustomEvent).detail).toEqual({
      forId: 'water',
      message: "script('spin on');",
    });
    expect(screen.getByText('Turn Spin Off')).toBeInTheDocument();

    await fireEvent.click(screen.getByText('Turn Spin Off'));
    expect(dispatchSpy).toHaveBeenCalledTimes(2);
    expect((dispatchSpy.mock.calls[1][0] as CustomEvent).detail).toEqual({
      forId: 'water',
      message: "script('spin off');",
    });
    expect(screen.getByText('Turn Spin On')).toBeInTheDocument();

    dispatchSpy.mockRestore();
  });
});
