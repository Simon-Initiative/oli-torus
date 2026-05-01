import React from 'react';
import { act, render } from '@testing-library/react';
import PopupAuthor from '../../src/components/parts/janus-popup/PopupAuthor';

const mockScreenAuthor = jest.fn((_: any) => <div data-testid="screen-author" />);

jest.mock('../../src/components/activities/adaptive/components/authoring/ScreenAuthor', () => ({
  __esModule: true,
  default: (props: any) => mockScreenAuthor(props),
}));

const popupModel = {
  width: 100,
  height: 100,
  visible: true,
  defaultURL: 'info',
  iconURL: '',
  description: 'More information',
  popup: {
    id: 'popup-screen',
    custom: {
      width: 300,
      height: 200,
      x: 0,
      y: 0,
      z: 0,
      palette: {},
    },
    partsLayout: [],
  },
};

const textPartRegistration = {
  slug: 'janus_text_flow',
  title: 'Text',
  description: 'Text block',
  icon: 'icon-part-text.svg',
  authoring_element: 'janus-text-flow',
  delivery_element: 'janus-text-flow',
};

describe('PopupAuthor', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    mockScreenAuthor.mockClear();
    document.body.innerHTML = '<div id="popup-portal"></div>';
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('passes available part registrations to the nested popup screen author', async () => {
    render(
      <PopupAuthor
        id="popup-1"
        type="janus-popup"
        model={popupModel as any}
        state={{}}
        editMode={true}
        configuremode={true}
        portal="popup-portal"
        onClick={jest.fn()}
        onConfigure={jest.fn()}
        onSaveConfigure={jest.fn()}
        onCancelConfigure={jest.fn()}
        onInit={jest.fn().mockResolvedValue({
          context: {
            partComponentTypes: [textPartRegistration],
          },
        })}
        onReady={jest.fn().mockResolvedValue(undefined)}
        onSave={jest.fn()}
        onSubmit={jest.fn()}
        onResize={jest.fn().mockResolvedValue(undefined)}
      />,
    );

    await act(async () => {
      jest.advanceTimersByTime(10);
    });

    expect(mockScreenAuthor).toHaveBeenCalledWith(
      expect.objectContaining({
        partComponentTypes: [textPartRegistration],
      }),
    );
  });
});
