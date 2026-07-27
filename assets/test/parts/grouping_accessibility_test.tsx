import React from 'react';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import GroupingBoard from '../../src/components/parts/janus-item-bank/GroupingBoard';
import GroupingItemContent from '../../src/components/parts/janus-item-bank/GroupingItemContent';
import { GroupingModel } from '../../src/components/parts/janus-item-bank/schema';

const waitForKeyboardSensor = () =>
  act(async () => {
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 0);
    });
  });

const model: GroupingModel = {
  x: 0,
  y: 0,
  z: 0,
  width: '100%',
  height: 425,
  customCssClass: '',
  enabled: true,
  themeColor: '#0070F3',
  customCss: '',
  categories: [
    { id: 'category-one', title: 'Category One' },
    { id: 'category-two', title: 'Category Two' },
  ],
  items: [
    {
      id: 'text-item',
      type: 'text',
      label: 'text-item-label',
      text: 'A full glass of milk',
    },
    {
      id: 'image-item',
      type: 'image',
      label: 'image-item-label',
      text: 'A visible water caption',
      imageSrc: 'https://example.com/water.png',
      alt: 'A glass of water',
    },
    {
      id: 'caption-fallback',
      type: 'image',
      label: 'caption-fallback-label',
      text: 'A visible soda caption',
      imageSrc: 'https://example.com/soda.png',
      alt: '',
    },
    {
      id: 'label-fallback',
      type: 'image',
      label: 'label fallback',
      text: '',
      imageSrc: 'https://example.com/juice.png',
      alt: '',
    },
  ],
  layoutPlacements: {},
  correctAnswer: {},
  showHints: false,
  showCorrect: false,
};

describe('GroupingBoard accessibility', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('announces learner-facing item content and current locations', () => {
    render(
      <GroupingBoard
        id="grouping-one"
        model={model}
        placements={{ 'text-item': 'category-one' }}
        onMove={jest.fn()}
      />,
    );

    expect(
      screen.getByRole('button', {
        name: 'A full glass of milk, currently in Category One.',
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', {
        name: 'A full glass of milk, currently in Category One.',
      }),
    ).toHaveTextContent('A full glass of milk');
    expect(
      screen.getByRole('button', {
        name: 'A glass of water, currently in Item Bank.',
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', {
        name: 'A visible soda caption, currently in Item Bank.',
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', {
        name: 'label fallback, currently in Item Bank.',
      }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /text-item-label/ })).not.toBeInTheDocument();
  });

  test('exposes image content once using alt, caption, then label fallbacks', () => {
    const { container, rerender } = render(<GroupingItemContent item={model.items[1]} />);

    expect(screen.getByRole('img', { name: 'A glass of water' })).toBeInTheDocument();

    rerender(<GroupingItemContent item={model.items[2]} />);

    expect(screen.getAllByText('A visible soda caption')).toHaveLength(1);
    expect(container.querySelector('img')).toHaveAttribute('alt', '');

    rerender(<GroupingItemContent item={model.items[3]} />);

    expect(screen.getByRole('img', { name: 'label fallback' })).toBeInTheDocument();
  });

  test('provides keyboard instructions once at the board level', () => {
    const { container } = render(
      <GroupingBoard id="grouping-one" model={model} placements={{}} onMove={jest.fn()} />,
    );

    const introduction = screen.getByRole('group', { name: 'Grouping activity' });
    const instructionsId = introduction.getAttribute('aria-describedby');
    const instructions = instructionsId ? document.getElementById(instructionsId) : null;

    expect(introduction).toHaveAttribute('tabindex', '0');
    expect(instructionsId).toBe('grouping-one-grouping-instructions');
    expect(instructions).toHaveTextContent(
      'Tab to an item, then press Space or Enter to pick it up.',
    );
    expect(instructions).toHaveTextContent(
      'use Tab, Right Arrow, or Down Arrow for the next location',
    );
    expect(instructions).toHaveTextContent(
      'Shift plus Tab, Left Arrow, or Up Arrow for the previous location',
    );

    screen.getAllByRole('button').forEach((item) => {
      expect(item).not.toHaveAttribute('aria-describedby');
      expect(item).toHaveAttribute('aria-roledescription', 'draggable');
      expect(item).not.toHaveClass('is-disabled');
    });
    container.querySelectorAll('.grouping-dropzone').forEach((dropzone) => {
      expect(dropzone).toHaveAttribute('aria-dropeffect', 'move');
    });
    expect(screen.getAllByText('Drop items here')).toHaveLength(2);
  });

  test('removes actionable drag instructions when the board is disabled', () => {
    const { container } = render(
      <GroupingBoard
        id="grouping-disabled"
        model={model}
        placements={{}}
        onMove={jest.fn()}
        enabled={false}
      />,
    );

    const introduction = screen.getByRole('group', { name: 'Grouping activity' });

    expect(introduction).toHaveAttribute('tabindex', '-1');
    expect(introduction).not.toHaveAttribute('aria-describedby');
    expect(document.getElementById('grouping-disabled-grouping-instructions')).toBeNull();
    screen.getAllByRole('button').forEach((item) => {
      expect(item).toHaveAttribute('tabindex', '-1');
      expect(item).toHaveAttribute('aria-disabled', 'true');
      expect(item).not.toHaveAttribute('aria-roledescription');
      expect(item).toHaveClass('is-disabled');
    });
    container.querySelectorAll('.grouping-dropzone').forEach((dropzone) => {
      expect(dropzone).not.toHaveAttribute('aria-dropeffect');
    });
    expect(screen.queryByText('Drop items here')).not.toBeInTheDocument();
    expect(screen.getAllByText('No items')).toHaveLength(2);
  });

  test('keeps authored text and the focused item exposed while dragging', async () => {
    const helloModel: GroupingModel = {
      ...model,
      items: model.items.map((item) =>
        item.id === 'text-item' ? { ...item, text: 'Hello World' } : item,
      ),
    };
    render(
      <GroupingBoard
        id="grouping-one"
        model={helloModel}
        placements={{ 'text-item': 'category-one' }}
        onMove={jest.fn()}
      />,
    );

    const item = screen.getByRole('button', {
      name: 'Hello World, currently in Category One.',
    });

    fireEvent.keyDown(item, { key: ' ', code: 'Space' });

    await waitFor(() =>
      expect(
        screen.getByText('Picked up Hello World. Current location: Category One.'),
      ).toBeInTheDocument(),
    );
    expect(item).not.toHaveAttribute('aria-hidden');
    expect(item).toHaveAttribute('aria-pressed', 'true');
    expect(document.querySelector('.grouping-item.is-overlay')).toHaveAttribute(
      'aria-hidden',
      'true',
    );
    await waitForKeyboardSensor();

    fireEvent.keyDown(document, { key: 'Escape', code: 'Escape' });
    await waitFor(() => expect(item).not.toHaveAttribute('aria-pressed'));
  });

  test('navigates with Tab, drops explicitly, and cancels without moving', async () => {
    const rect = (left: number, top: number, width: number, height: number): DOMRect => ({
      left,
      top,
      width,
      height,
      right: left + width,
      bottom: top + height,
      x: left,
      y: top,
      toJSON: () => ({}),
    });

    jest
      .spyOn(HTMLElement.prototype, 'getBoundingClientRect')
      .mockImplementation(function getGroupingRect() {
        if (this.classList.contains('grouping-item')) {
          return rect(10, 10, 80, 40);
        }
        const section = this.closest('section');
        const sectionName = section?.getAttribute('aria-label') || '';
        if (sectionName.startsWith('Category One')) {
          return rect(200, 0, 160, 200);
        }
        if (sectionName.startsWith('Category Two')) {
          return rect(400, 0, 160, 200);
        }
        return rect(0, 0, 160, 200);
      });

    const onMove = jest.fn();
    render(<GroupingBoard id="grouping-one" model={model} placements={{}} onMove={onMove} />);

    const itemBankScrollIntoView = jest.fn();
    const categoryOneScrollIntoView = jest.fn();
    const categoryTwoScrollIntoView = jest.fn();
    const itemBankDropZone = document.getElementById('grouping-one-grouping-zone-bank');
    const categoryOneDropZone = document.getElementById('grouping-one-grouping-zone-category-one');
    const categoryTwoDropZone = document.getElementById('grouping-one-grouping-zone-category-two');
    if (itemBankDropZone) {
      itemBankDropZone.scrollIntoView = itemBankScrollIntoView;
    }
    if (categoryOneDropZone) {
      categoryOneDropZone.scrollIntoView = categoryOneScrollIntoView;
    }
    if (categoryTwoDropZone) {
      categoryTwoDropZone.scrollIntoView = categoryTwoScrollIntoView;
    }

    const item = screen.getByRole('button', {
      name: 'A full glass of milk, currently in Item Bank.',
    });
    item.focus();

    fireEvent.keyDown(item, { key: ' ', code: 'Space' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Item Bank.'),
      ).toBeInTheDocument(),
    );
    await waitForKeyboardSensor();

    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category One.'),
      ).toBeInTheDocument(),
    );
    expect(categoryOneScrollIntoView).toHaveBeenCalledWith({
      behavior: 'auto',
      block: 'nearest',
      inline: 'nearest',
    });
    expect(onMove).not.toHaveBeenCalled();
    expect(item).toHaveFocus();

    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category Two.'),
      ).toBeInTheDocument(),
    );
    expect(categoryTwoScrollIntoView).toHaveBeenCalledWith({
      behavior: 'auto',
      block: 'nearest',
      inline: 'nearest',
    });
    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab', shiftKey: true });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category One.'),
      ).toBeInTheDocument(),
    );
    expect(categoryOneScrollIntoView).toHaveBeenCalledTimes(2);

    fireEvent.keyDown(document, { key: 'Enter', code: 'Enter' });
    await waitFor(() => expect(onMove).toHaveBeenCalledWith('text-item', 'category-one'));
    expect(onMove).toHaveBeenCalledTimes(1);
    expect(item).toHaveFocus();

    fireEvent.keyDown(item, { key: 'Enter', code: 'Enter' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Item Bank.'),
      ).toBeInTheDocument(),
    );
    await waitForKeyboardSensor();
    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab', shiftKey: true });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category Two.'),
      ).toBeInTheDocument(),
    );
    fireEvent.keyDown(document, { key: 'Escape', code: 'Escape' });

    await waitFor(() =>
      expect(
        screen.getByText('Move cancelled. A full glass of milk remains in Item Bank.'),
      ).toBeInTheDocument(),
    );
    expect(onMove).toHaveBeenCalledTimes(1);
    await waitFor(() => expect(item).not.toHaveAttribute('aria-pressed'));
    expect(item).toHaveFocus();
    expect(itemBankScrollIntoView).toHaveBeenCalledWith({
      behavior: 'auto',
      block: 'nearest',
      inline: 'nearest',
    });

    fireEvent.keyDown(item, { key: ' ', code: 'Space' });
    await waitForKeyboardSensor();
    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category One.'),
      ).toBeInTheDocument(),
    );
    fireEvent.keyDown(document, { key: 'Tab', code: 'Tab' });
    await waitFor(() =>
      expect(
        screen.getByText('A full glass of milk. Current location: Category Two.'),
      ).toBeInTheDocument(),
    );
    fireEvent.keyDown(document, { key: 'Escape', code: 'Escape' });
    await waitFor(() => {
      expect(item).not.toHaveAttribute('aria-pressed');
      expect(itemBankScrollIntoView).toHaveBeenCalledTimes(2);
    });
    expect(onMove).toHaveBeenCalledTimes(1);
  });
});
