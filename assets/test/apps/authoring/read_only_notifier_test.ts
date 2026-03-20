import {
  notifyReadOnlyEditBlocked,
  resetReadOnlyEditBlockedNotification,
} from 'apps/authoring/readOnlyNotifier';

describe('notifyReadOnlyEditBlocked', () => {
  const originalReactToLiveView = (window as any).ReactToLiveView;

  beforeEach(() => {
    resetReadOnlyEditBlockedNotification();
    (window as any).ReactToLiveView = {
      pushEvent: jest.fn(),
    };
  });

  afterEach(() => {
    resetReadOnlyEditBlockedNotification();
    (window as any).ReactToLiveView = originalReactToLiveView;
    jest.restoreAllMocks();
  });

  test('pushes a read-only blocked event to LiveView', () => {
    notifyReadOnlyEditBlocked();

    expect((window as any).ReactToLiveView.pushEvent).toHaveBeenCalledWith(
      'authoring_readonly_edit_blocked',
      {
        message: 'This page is in read-only mode. Toggle "Read only" off in the header to edit.',
      },
    );
  });

  test('throttles repeated notifications', () => {
    const nowSpy = jest.spyOn(Date, 'now');
    nowSpy.mockReturnValue(5000);
    notifyReadOnlyEditBlocked();

    nowSpy.mockReturnValue(6000);
    notifyReadOnlyEditBlocked();

    expect((window as any).ReactToLiveView.pushEvent).toHaveBeenCalledTimes(1);
  });
});
