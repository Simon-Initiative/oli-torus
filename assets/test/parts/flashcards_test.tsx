import { act, waitFor } from '@testing-library/react';
import '../../src/components/parts/janus-flashcards/authoring-entry';
import { stripFlashcardImageDimensions } from '../../src/components/parts/janus-flashcards/flashcardContent';
import {
  computeCardsPerRow,
  computeFlashcardsLayoutHeight,
  resolveCardHeightForLayout,
  resolveCardsPerRowBounds,
  resolveContainerWidth,
} from '../../src/components/parts/janus-flashcards/schema';

const fourCardModel = {
  width: 480,
  height: 180,
  cardHeight: 180,
  cards: Array.from({ length: 4 }, (_, index) => ({ id: `card-${index + 1}` })),
  minCardsPerRow: 1,
  maxCardsPerRow: 3,
  customCssClass: '',
  enabled: true,
  randomize: false,
  flipDuration: 600,
  correctFeedback: '',
  incorrectFeedback: '',
};

const fiveCardResponsiveModel = {
  ...fourCardModel,
  width: '100%',
  responsiveLayoutWidth: 470,
  height: 376,
  cards: Array.from({ length: 5 }, (_, index) => ({ id: `responsive-card-${index + 1}` })),
};

describe('flashcard layout helpers', () => {
  test('normalizes row bounds and computes the four-card layout', () => {
    const bounds = resolveCardsPerRowBounds({ minCardsPerRow: 4, maxCardsPerRow: 2 });

    expect(bounds).toEqual({ min: 2, max: 4 });
    expect(computeCardsPerRow(480, { min: 1, max: 3 })).toBe(2);
    expect(computeFlashcardsLayoutHeight(4, 480, fourCardModel)).toBe(376);
  });

  test('derives card height from a manually selected layout height', () => {
    expect(resolveCardHeightForLayout({ ...fourCardModel, height: 416 }, 480, 4)).toBe(200);
  });

  test('uses the responsive part width when the component width is 100%', () => {
    const containerWidth = resolveContainerWidth(
      fiveCardResponsiveModel.width,
      fiveCardResponsiveModel.responsiveLayoutWidth,
    );

    expect(containerWidth).toBe(470);
    expect(computeFlashcardsLayoutHeight(5, containerWidth, fiveCardResponsiveModel)).toBe(572);
  });
});

describe('stripFlashcardImageDimensions', () => {
  test('removes nested image dimensions without changing other styles', () => {
    const nodes = [
      {
        tag: 'p',
        style: {},
        children: [
          {
            tag: 'img',
            style: { width: '320px', height: '180px', objectFit: 'cover' },
            children: [],
          },
        ],
      },
    ];

    const stripped = stripFlashcardImageDimensions(nodes as any);

    expect(stripped[0].children?.[0].style).toEqual({ objectFit: 'cover' });
    expect(nodes[0].children[0].style).toEqual({
      width: '320px',
      height: '180px',
      objectFit: 'cover',
    });
  });
});

describe('FlashcardAuthor custom element', () => {
  test('honors lowercase editmode and emits one complete resize update', async () => {
    const resizePayloads: any[] = [];
    const element = document.createElement('janus-flashcards') as any;

    element.setAttribute('id', 'flashcards-1');
    element.setAttribute('editmode', 'true');
    element.setAttribute('configuremode', 'false');
    element.setAttribute('model', JSON.stringify(fourCardModel));
    element.addEventListener('ready', (event: CustomEvent) => {
      event.detail.callback(undefined);
    });
    element.addEventListener('resize', (event: CustomEvent) => {
      resizePayloads.push(event.detail.payload);
      event.detail.callback(undefined);
    });

    document.body.appendChild(element);

    await waitFor(() => expect(resizePayloads).toHaveLength(1));
    expect(resizePayloads[0]).toEqual({
      id: 'flashcards-1',
      settings: {
        height: { value: 376 },
        cardHeight: { value: 180 },
      },
    });

    await act(async () => {
      element.model = JSON.stringify({ ...fourCardModel, height: 376 });
    });
    expect(resizePayloads).toHaveLength(1);

    element.model = JSON.stringify({ ...fourCardModel, height: 416 });

    await waitFor(() => expect(resizePayloads).toHaveLength(2));
    expect(resizePayloads[1]).toEqual({
      id: 'flashcards-1',
      settings: {
        height: { value: 416 },
        cardHeight: { value: 200 },
      },
    });

    element.remove();
  });

  test('emits the complete height for a responsive half-width layout', async () => {
    const resizePayloads: any[] = [];
    const element = document.createElement('janus-flashcards') as any;

    element.setAttribute('id', 'responsive-flashcards');
    element.setAttribute('editmode', 'true');
    element.setAttribute('configuremode', 'false');
    element.setAttribute('model', JSON.stringify(fiveCardResponsiveModel));
    element.addEventListener('ready', (event: CustomEvent) => {
      event.detail.callback(undefined);
    });
    element.addEventListener('resize', (event: CustomEvent) => {
      resizePayloads.push(event.detail.payload);
      event.detail.callback(undefined);
    });

    document.body.appendChild(element);

    await waitFor(() => expect(resizePayloads).toHaveLength(1));
    expect(resizePayloads[0]).toEqual({
      id: 'responsive-flashcards',
      settings: {
        height: { value: 572 },
        cardHeight: { value: 180 },
      },
    });

    element.remove();
  });

  test('uses the measured responsive width when it differs from the persisted width', async () => {
    const resizePayloads: any[] = [];
    const element = document.createElement('janus-flashcards') as any;
    const rectSpy = jest.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({
      bottom: 0,
      height: 0,
      left: 0,
      right: 360,
      top: 0,
      width: 360,
      x: 0,
      y: 0,
      toJSON: () => ({}),
    });

    element.setAttribute('id', 'measured-responsive-flashcards');
    element.setAttribute('editmode', 'true');
    element.setAttribute('configuremode', 'false');
    element.setAttribute('model', JSON.stringify(fiveCardResponsiveModel));
    element.addEventListener('ready', (event: CustomEvent) => {
      event.detail.callback(undefined);
    });
    element.addEventListener('resize', (event: CustomEvent) => {
      resizePayloads.push(event.detail.payload);
      event.detail.callback(undefined);
    });

    document.body.appendChild(element);

    try {
      await waitFor(() =>
        expect(
          resizePayloads.some(
            (payload) =>
              payload.settings.height.value === 964 && payload.settings.cardHeight.value === 180,
          ),
        ).toBe(true),
      );
    } finally {
      element.remove();
      rectSpy.mockRestore();
    }
  });

  test('does not auto-resize during a canvas resize and synchronizes on release', async () => {
    const resizePayloads: any[] = [];
    const element = document.createElement('janus-flashcards') as any;
    let ready = false;

    element.setAttribute('id', 'resized-flashcards');
    element.setAttribute('editmode', 'true');
    element.setAttribute('configuremode', 'false');
    element.setAttribute('layoutchanging', 'true');
    element.setAttribute('model', JSON.stringify({ ...fourCardModel, height: 376 }));
    element.addEventListener('ready', (event: CustomEvent) => {
      ready = true;
      event.detail.callback(undefined);
    });
    element.addEventListener('resize', (event: CustomEvent) => {
      resizePayloads.push(event.detail.payload);
      event.detail.callback(undefined);
    });

    document.body.appendChild(element);

    await waitFor(() => expect(ready).toBe(true));
    expect(resizePayloads).toHaveLength(0);

    await act(async () => {
      element.model = JSON.stringify({ ...fourCardModel, width: 600, height: 500 });
    });
    expect(resizePayloads).toHaveLength(0);

    element.setAttribute('layoutchanging', 'false');

    await waitFor(() => expect(resizePayloads).toHaveLength(1));
    expect(resizePayloads[0]).toEqual({
      id: 'resized-flashcards',
      settings: {
        height: { value: 500 },
        cardHeight: { value: 242 },
      },
    });

    element.remove();
  });

  test('preserves height when a fixed width changes', async () => {
    const resizePayloads: any[] = [];
    const element = document.createElement('janus-flashcards') as any;
    const model = {
      ...fourCardModel,
      height: 572,
      cards: Array.from({ length: 5 }, (_, index) => ({ id: `fixed-card-${index + 1}` })),
    };

    element.setAttribute('id', 'width-resized-flashcards');
    element.setAttribute('editmode', 'true');
    element.setAttribute('configuremode', 'false');
    element.setAttribute('model', JSON.stringify(model));
    element.addEventListener('ready', (event: CustomEvent) => {
      event.detail.callback(undefined);
    });
    element.addEventListener('resize', (event: CustomEvent) => {
      resizePayloads.push(event.detail.payload);
      event.detail.callback(undefined);
    });

    document.body.appendChild(element);

    await waitFor(() => expect(resizePayloads).toHaveLength(1));

    element.model = JSON.stringify({ ...model, width: 600 });

    await waitFor(() => expect(resizePayloads).toHaveLength(2));
    expect(resizePayloads[1]).toEqual({
      id: 'width-resized-flashcards',
      settings: {
        height: { value: 572 },
        cardHeight: { value: 278 },
      },
    });

    element.remove();
  });
});
