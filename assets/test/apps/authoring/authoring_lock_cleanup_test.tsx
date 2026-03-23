import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { act, render } from '@testing-library/react';
import Authoring, { AuthoringProps } from 'apps/authoring/Authoring';
import { releaseEditingLock } from 'apps/authoring/store/app/actions/locking';
import { flushPendingActivitySaves } from 'apps/authoring/store/activities/actions/saveActivity';
import { flushPendingPageSave } from 'apps/authoring/store/page/actions/savePage';

jest.mock('react-redux', () => ({
  useDispatch: jest.fn(),
  useSelector: jest.fn(),
  connect:
    () =>
    <T,>(Component: T): T =>
      Component,
}));

jest.mock('components/misc/DarkModeSelector', () => ({
  getModeFromLocalStorage: jest.fn(() => 'light'),
}));

jest.mock('utils/browser', () => ({
  isFirefox: false,
}));

jest.mock('components/common/ErrorBoundary', () => {
  const mockReact = jest.requireActual('react');
  const MockErrorBoundary = ({ children }: { children: React.ReactNode }) => <>{children}</>;
  const MockAppsignalContext = mockReact.createContext(null);

  return {
    AppsignalContext: MockAppsignalContext,
    ErrorBoundary: MockErrorBoundary,
  };
});

jest.mock('apps/authoring/AuthoringExpertPageEditor', () => ({
  AuthoringExpertPageEditor: () => <div data-testid="expert-editor" />,
}));

jest.mock('apps/authoring/AuthoringFlowchartPageEditor', () => ({
  AuthoringFlowchartPageEditor: () => <div data-testid="flowchart-page-editor" />,
}));

jest.mock('apps/authoring/components/Flowchart/FlowchartEditor', () => ({
  FlowchartEditor: () => <div data-testid="flowchart-editor" />,
}));

jest.mock('apps/authoring/components/AdvancedAuthoringModal', () => ({
  ModalContainer: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

jest.mock('apps/authoring/components/Flowchart/onboard-wizard/OnboardWizard', () => ({
  OnboardWizard: () => <div data-testid="onboard-wizard" />,
}));

jest.mock('apps/authoring/components/Modal/DiagnosticsWindow', () => {
  function MockDiagnosticsWindow() {
    return <div data-testid="diagnostics-window" />;
  }

  return MockDiagnosticsWindow;
});

jest.mock('apps/authoring/components/Modal/ScoringOverview', () => {
  function MockScoringOverview() {
    return <div data-testid="scoring-overview" />;
  }

  return MockScoringOverview;
});

jest.mock('apps/authoring/components/Flowchart/toolbar/InvalidScreenWarning', () => ({
  InvalidScreenWarning: () => <div data-testid="invalid-screen-warning" />,
}));

jest.mock('utils/appsignal', () => ({
  initAppSignal: jest.fn(() => null),
}));

jest.mock('apps/authoring/components/Flowchart/flowchart-actions/onboard-wizard-complete', () => ({
  onboardWizardComplete: jest.fn(),
}));

jest.mock('apps/authoring/components/Flowchart/flowchart-actions/verify-flowchart-lesson', () => ({
  verifyFlowchartLesson: jest.fn(() => ({ type: 'verifyFlowchartLesson' })),
}));

jest.mock('apps/authoring/components/Flowchart/screens/screen-validation', () => ({
  validateScreen: jest.fn(() => []),
}));

jest.mock('apps/authoring/readOnlyBridge', () => ({
  handleShellReadOnlyToggle: jest.fn(),
}));

jest.mock('apps/authoring/store/page/actions/initializeFromContext', () => ({
  initializeFromContext: jest.fn(() => ({ type: 'page/initializeFromContext' })),
}));

jest.mock('apps/authoring/store/page/actions/savePage', () => ({
  savePage: Object.assign(jest.fn(), {
    fulfilled: 'page/savePage/fulfilled',
    rejected: 'page/savePage/rejected',
  }),
  flushPendingPageSave: jest.fn(() => Promise.resolve()),
}));

jest.mock('apps/authoring/store/activities/actions/saveActivity', () => ({
  flushPendingActivitySaves: jest.fn(() => Promise.resolve()),
}));

jest.mock('apps/authoring/store/app/actions/locking', () => {
  const acquireEditingLock = Object.assign(jest.fn(), {
    fulfilled: 'app/acquireEditingLock/fulfilled',
    rejected: 'app/acquireEditingLock/rejected',
  });

  const releaseEditingLock = Object.assign(
    jest.fn(() => ({ type: 'app/releaseEditingLock' })),
    {
      fulfilled: 'app/releaseEditingLock/fulfilled',
      rejected: 'app/releaseEditingLock/rejected',
    },
  );

  return {
    acquireEditingLock,
    releaseEditingLock,
  };
});

const mockedUseDispatch = useDispatch as jest.Mock;
const mockedUseSelector = useSelector as jest.Mock;

const baseProps: AuthoringProps = {
  isAdmin: false,
  projectSlug: 'project-slug',
  revisionSlug: 'revision-slug',
  resourceId: 101,
  paths: {},
  appsignalKey: null,
  initialSidebarExpanded: true,
  content: {
    projectSlug: 'project-slug',
    resourceSlug: 'revision-slug',
    resourceId: 101,
    title: 'Adaptive Page',
    graded: false,
    ai_enabled: false,
    objectives: [],
    allObjectives: [],
    activities: {},
    content: {
      model: [{ type: 'group', children: [] }],
      custom: { contentMode: 'expert' },
      additionalStylesheets: [],
      customCss: '',
      customScript: '',
      displayApplicationChrome: true,
    },
  } as any,
};

const buildState = ({
  hasEditingLock,
  readonly,
}: {
  hasEditingLock: boolean;
  readonly: boolean;
}) => ({
  mainApp: {
    applicationMode: 'expert',
    editingMode: 'page',
    paths: {},
    isAdmin: false,
    projectSlug: 'project-slug',
    revisionSlug: 'revision-slug',
    leftPanel: true,
    rightPanel: true,
    topPanel: true,
    bottomPanel: true,
    visible: false,
    hasEditingLock,
    rightPanelActiveTab: 'lesson',
    currentRule: undefined,
    partComponentTypes: [],
    activityTypes: [],
    allObjectives: [],
    copiedPart: null,
    copiedPartActivityId: null,
    allowTriggers: false,
    readonly,
    showDiagnosticsWindow: false,
    showScoringOverview: false,
    sequenceEditorHeight: '100vh',
    topLeftPanel: true,
    bottomLeftPanel: true,
    sequenceEditorExpanded: false,
  },
  activities: {
    ids: [],
    entities: {},
    currentActivityId: null,
  },
  groups: {
    ids: [],
    entities: {},
    currentGroupId: -1,
  },
});

describe('Authoring lock cleanup', () => {
  beforeEach(() => {
    mockedUseDispatch.mockReset();
    mockedUseSelector.mockReset();
    (window as any).ReactToLiveView = { pushEvent: jest.fn() };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('releases the adaptive edit lock when the editor unmounts', async () => {
    const dispatch = jest.fn().mockResolvedValue(undefined);
    const state = buildState({ hasEditingLock: true, readonly: false });

    mockedUseDispatch.mockReturnValue(dispatch);
    mockedUseSelector.mockImplementation((selector) => selector(state));

    const { unmount } = render(<Authoring {...baseProps} />);

    await Promise.resolve();
    dispatch.mockClear();

    unmount();

    await act(async () => {
      await Promise.resolve();
    });

    expect(flushPendingPageSave).toHaveBeenCalledTimes(1);
    expect(flushPendingActivitySaves).toHaveBeenCalledTimes(1);
    expect(releaseEditingLock).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledWith({ type: 'app/releaseEditingLock' });
  });

  test('does not release a lock on unmount when no adaptive lock is held', async () => {
    const dispatch = jest.fn().mockResolvedValue(undefined);
    const state = buildState({ hasEditingLock: false, readonly: true });

    mockedUseDispatch.mockReturnValue(dispatch);
    mockedUseSelector.mockImplementation((selector) => selector(state));

    const { unmount } = render(<Authoring {...baseProps} />);

    await Promise.resolve();
    dispatch.mockClear();

    unmount();

    await act(async () => {
      await Promise.resolve();
    });

    expect(flushPendingPageSave).not.toHaveBeenCalled();
    expect(flushPendingActivitySaves).not.toHaveBeenCalled();
    expect(releaseEditingLock).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });
});
