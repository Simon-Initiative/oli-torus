import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { Descendant, createEditor } from 'slate';
import { Slate, withReact } from 'slate-react';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { ToolbarContext } from 'components/editing/toolbar/hooks/useToolbar';

describe('DescriptiveButton', () => {
  it('executes a formatting command without submitting its surrounding form', () => {
    const execute = jest.fn();
    const closeSubmenus = jest.fn();
    const onSubmit = jest.fn((event) => event.preventDefault());
    const editor = withReact(createEditor());
    const value: Descendant[] = [{ type: 'p', children: [{ text: 'Welcome' }] } as any];
    const description: CommandDescription = {
      type: 'CommandDesc',
      icon: () => undefined,
      description: () => 'Bulleted List',
      command: {
        precondition: () => true,
        execute,
      },
    };

    render(
      <form onSubmit={onSubmit}>
        <Slate editor={editor} initialValue={value} onChange={jest.fn()}>
          <ToolbarContext.Provider
            value={{
              context: { projectSlug: 'project' },
              submenu: null,
              openSubmenu: jest.fn(),
              closeSubmenus,
            }}
          >
            <DescriptiveButton description={description} />
          </ToolbarContext.Provider>
        </Slate>
      </form>,
    );

    const button = screen.getByRole('button', { name: 'Bulleted List' });

    expect(button).toHaveAttribute('type', 'button');
    fireEvent.mouseDown(button);

    expect(execute).toHaveBeenCalledWith({ projectSlug: 'project' }, editor);
    expect(closeSubmenus).toHaveBeenCalled();
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
