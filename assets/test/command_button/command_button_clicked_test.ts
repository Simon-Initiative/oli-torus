import { commandButtonClicked } from '../../src/components/editing/elements/command_button/commandButtonClicked';

describe('commandButtonClicked', () => {
  it('dispatches simple command from data-message', () => {
    const button = document.createElement('span');
    button.setAttribute('data-action', 'command-button');
    button.setAttribute('data-target', 'targetx');
    button.setAttribute('data-message', 'innerOrbitsShown.png');
    button.textContent = 'Show Inner Orbits';

    const dispatchSpy = jest.spyOn(document, 'dispatchEvent').mockReturnValue(true);

    commandButtonClicked({ target: button });

    expect(dispatchSpy).toHaveBeenCalledTimes(1);
    expect((dispatchSpy.mock.calls[0][0] as CustomEvent).detail).toEqual({
      forId: 'targetx',
      message: 'innerOrbitsShown.png',
    });

    dispatchSpy.mockRestore();
  });

  it('uses toggleStates data and advances displayed title', () => {
    const button = document.createElement('span');
    button.setAttribute('data-action', 'command-button');
    button.setAttribute('data-target', 'water');
    button.setAttribute(
      'data-toggle-states',
      JSON.stringify([
        { title: 'Turn Spin On', message: "script('spin on');" },
        { title: 'Turn Spin Off', message: "script('spin off');" },
      ]),
    );
    const child = document.createElement('strong');
    child.textContent = 'Turn Spin On';
    button.appendChild(child);

    const dispatchSpy = jest.spyOn(document, 'dispatchEvent').mockReturnValue(true);

    commandButtonClicked({ target: child });

    expect(dispatchSpy).toHaveBeenCalledTimes(1);
    expect((dispatchSpy.mock.calls[0][0] as CustomEvent).detail).toEqual({
      forId: 'water',
      message: "script('spin on');",
    });
    expect(button.textContent).toBe('Turn Spin Off');

    dispatchSpy.mockRestore();
  });

  it('uses currentTarget when click target is a text node (SSR/jQuery path)', () => {
    const button = document.createElement('span');
    button.setAttribute('data-action', 'command-button');
    button.setAttribute('data-target', 'targetx');
    button.setAttribute('data-message', 'innerOrbitsShown.png');
    button.appendChild(document.createTextNode('Show Inner Orbits'));

    const dispatchSpy = jest.spyOn(document, 'dispatchEvent').mockReturnValue(true);

    commandButtonClicked({ currentTarget: button, target: button.firstChild });

    expect(dispatchSpy).toHaveBeenCalledTimes(1);
    expect((dispatchSpy.mock.calls[0][0] as CustomEvent).detail).toEqual({
      forId: 'targetx',
      message: 'innerOrbitsShown.png',
    });

    dispatchSpy.mockRestore();
  });
});
