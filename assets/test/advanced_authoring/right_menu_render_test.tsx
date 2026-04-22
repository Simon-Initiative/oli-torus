import React from 'react';
import { render } from '@testing-library/react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import RightMenu from '../../src/apps/authoring/components/RightMenu/RightMenu';

const renderWithState = (state: any) => {
  const store = configureStore({
    reducer: () => state,
  });

  return render(
    <Provider store={store}>
      <RightMenu />
    </Provider>,
  );
};

describe('RightMenu', () => {
  it('renders the simple author screen tab', () => {
    const activity = {
      id: 1,
      resourceId: 1,
      title: 'Welcome Screen',
      content: {
        custom: {
          width: 1000,
          height: 500,
          palette: {
            backgroundColor: '#ffffff',
          },
          mainBtnLabel: 'Next',
          applyBtnLabel: 'Try again',
          applyBtnFlag: false,
        },
        partsLayout: [],
      },
      authoring: {
        parts: [],
        flowchart: {
          screenType: 'welcome_screen',
          templateApplied: true,
          paths: [],
        },
      },
      objectives: {},
    };

    expect(() =>
      renderWithState({
        mainApp: {
          applicationMode: 'flowchart',
          editingMode: 'page',
          paths: { images: '/images' },
          isAdmin: false,
          projectSlug: 'demo',
          revisionSlug: 'rev',
          leftPanel: true,
          rightPanel: true,
          topPanel: true,
          bottomPanel: true,
          visible: true,
          hasEditingLock: true,
          rightPanelActiveTab: 'screen',
          currentRule: undefined,
          partComponentTypes: [],
          activityTypes: [],
          allObjectives: [],
          copiedPart: null,
          copiedPartActivityId: null,
          allowTriggers: true,
          readonly: false,
          showDiagnosticsWindow: false,
          showScoringOverview: false,
          sequenceEditorHeight: '100vh',
          topLeftPanel: true,
          bottomLeftPanel: true,
          sequenceEditorExpanded: false,
        },
        page: {
          title: 'Lesson',
          custom: {
            responsiveLayout: false,
          },
          additionalStylesheets: [],
        },
        parts: {
          currentSelection: '',
          currentPartPropertyFocus: true,
        },
        groups: {
          ids: [1],
          entities: {
            1: {
              id: 1,
              type: 'group',
              layout: 'deck',
              children: [
                {
                  type: 'activity-reference',
                  resourceId: 1,
                  custom: { sequenceId: 'seq-1' },
                },
              ],
            },
          },
          currentGroupId: 1,
        },
        activities: {
          ids: [1],
          entities: { 1: activity },
          currentActivityId: 1,
        },
      }),
    ).not.toThrow();
  });
});
