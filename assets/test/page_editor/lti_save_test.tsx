import React from 'react';
import { act, render, screen, waitFor } from '@testing-library/react';
import { createCopy } from 'components/activity/DuplicateActivity';
import { Editors } from 'components/resource/editors/Editors';
import { PageEditor } from 'apps/page-editor/PageEditor';
import * as ActivityPersistence from 'data/persistence/activity';
import { acquireLock, releaseLock } from 'data/persistence/lock';
import { saveAuthoringDeepLink, startAuthoringDeepLink } from 'data/persistence/lti_platform';
import * as ResourcePersistence from 'data/persistence/resource';
import { deferred } from '../components/lti/test_helpers';

jest.mock('data/persistence/lock', () => ({ acquireLock: jest.fn(), releaseLock: jest.fn() }));
jest.mock('data/persistence/lti_platform', () => ({
  saveAuthoringDeepLink: jest.fn(),
  startAuthoringDeepLink: jest.fn(),
}));
jest.mock('data/persistence/activity', () => ({ edit: jest.fn() }));
jest.mock('components/activity/DuplicateActivity', () => ({ createCopy: jest.fn() }));
jest.mock('components/resource/editors/Editors', () => ({
  Editors: jest.fn((props: any) => (
    <div>{props.activityContexts.first()?.model.deepLink?.title}</div>
  )),
}));
jest.mock('components/resource/editors/ContentOutline', () => ({ ContentOutline: () => null }));
jest.mock('components/resource/objectives/ObjectivesSelection', () => ({
  ObjectivesSelection: () => null,
}));

const entry = {
  activityId: 42,
  activitySlug: 'tool',
  authoringElement: 'lti-external-tool-authoring',
  typeSlug: 'tool',
  title: 'Tool',
  objectives: {},
  tags: [],
  model: { deepLink: { title: 'Draft' }, authoring: { parts: [] } },
};
const props: any = {
  projectSlug: 'project',
  resourceSlug: 'page',
  resourceId: 10,
  title: 'Lesson',
  graded: false,
  objectives: { attached: [] },
  allObjectives: [],
  allTags: [],
  learningObjectives: [],
  content: { model: [] },
  activityContexts: [entry],
  optionalContentTypes: {},
  editorMap: {},
  featureFlags: {},
  appsignalKey: null,
  defaultEditor: 'slate',
  onLoadPreferences: jest.fn(),
};
function event(name: string, payload: unknown = {}): Promise<unknown> {
  return new Promise((resolve, reject) => {
    window.dispatchEvent(
      new CustomEvent('customEvent', {
        detail: {
          payload: { eventName: name, payload },
          props: { projectSlug: 'project', activityId: 42 },
          continuation: (result: unknown, error: unknown) =>
            error ? reject(error) : resolve(result),
        },
      }),
    );
  });
}
beforeAll(() => {
  Object.defineProperty(HTMLElement.prototype, 'scrollIntoView', {
    configurable: true,
    value: jest.fn(),
  });
});
afterAll(() => {
  delete (HTMLElement.prototype as any).scrollIntoView;
});

beforeEach(() => {
  jest.clearAllMocks();
  (acquireLock as jest.Mock).mockResolvedValue({ type: 'acquired' });
  (releaseLock as jest.Mock).mockResolvedValue({ type: 'acquired' });
  (startAuthoringDeepLink as jest.Mock).mockResolvedValue({ request_id: 'request' });
});
afterEach(() => jest.restoreAllMocks());

async function renderEditablePage(overrides: Record<string, unknown> = {}) {
  const page = React.createRef<PageEditor>();
  render(<PageEditor {...props} {...overrides} ref={page} />);
  await waitFor(() => expect(page.current?.state.editMode).toBe(true));
  return page;
}

it('edits, duplicates and restores references using resource IDs while retaining slug metadata', async () => {
  const reference = { type: 'activity-reference', id: 'original', activity_id: 42, children: [] };
  const page = await renderEditablePage({ content: { model: [reference] } });
  jest
    .spyOn(ResourcePersistence, 'edit')
    .mockResolvedValue({ type: 'success', revisionSlug: 'page' });
  (ActivityPersistence.edit as jest.Mock).mockResolvedValue({ result: 'success' });

  act(() => {
    page.current!.onEditActivity('42', { ...entry, content: entry.model });
  });
  await act(async () => {
    await page.current!.activityPersistence['42'].flushPendingChangesAsync?.(false);
  });
  expect(ActivityPersistence.edit).toHaveBeenCalledWith(
    'project',
    10,
    42,
    expect.objectContaining({ content: entry.model }),
    false,
  );
  expect(page.current!.state.activityContexts.get('42')?.activitySlug).toBe('tool');

  (createCopy as jest.Mock).mockImplementation((_project, _editor, _original, _scope, onAdded) => {
    onAdded({ ...entry, activityId: 43, activitySlug: 'copied-revision' }, 'tool');
  });
  act(() => {
    const calls = (Editors as jest.Mock).mock.calls;
    calls[calls.length - 1][0].onDuplicate(entry);
  });
  expect(page.current!.state.content.toPersistence().model).toEqual([
    expect.objectContaining({ activity_id: 43 }),
    reference,
  ]);
  expect(page.current!.state.content.toPersistence().model[0]).not.toHaveProperty('activitySlug');
  expect(page.current!.state.activityContexts.get('43')?.activitySlug).toBe('copied-revision');

  act(() => page.current!.onRemove('original'));
  expect(page.current!.state.content.find('original')).toBeUndefined();
  const undoId = page.current!.state.undoables.keySeq().last()!;
  act(() => page.current!.onInvokeUndo(undoId));
  expect(page.current!.state.content.find('original')).toEqual(reference);
  await act(async () => {
    await page.current!.persistence.flushPendingChangesAsync?.(false);
  });
  const calls = (ResourcePersistence.edit as jest.Mock).mock.calls;
  expect(calls[calls.length - 1][2].content.model).toEqual([
    expect.objectContaining({ activity_id: 43 }),
    reference,
  ]);
});

it('uses the existing Saving / All changes saved indicator and synchronizes the saved model', async () => {
  await renderEditablePage();
  await act(async () => {
    await event('ltiAuthoringPrepare', { role: 'instructor' });
  });
  const response = deferred<any>();
  (saveAuthoringDeepLink as jest.Mock).mockReturnValue(response.promise);
  let saving!: Promise<unknown>;
  act(() => {
    saving = event('ltiAuthoringSave', { token: 'signed-result' });
  });
  expect(screen.getByText('Saving...').closest('[role="status"]')).not.toBeNull();
  expect(screen.queryByText('All changes saved')).toBeNull();
  expect(screen.getByText('Draft')).toBeTruthy();
  await act(async () => {
    response.resolve({
      model: { deepLink: { title: 'Review' }, authoring: { parts: [] } },
      title: 'Tool',
      objectives: {},
      tags: [],
    });
    await saving;
  });
  expect(screen.getByText('All changes saved').closest('[role="status"]')).not.toBeNull();
  expect(screen.getByText('Review')).toBeTruthy();
  expect(screen.queryByText('Selection saved.')).toBeNull();
  expect(saveAuthoringDeepLink).toHaveBeenCalledWith('project', '42', 'signed-result');
});

it('retains the prior model and does not display All changes saved after a failed selection save', async () => {
  await renderEditablePage();
  await act(async () => {
    await event('ltiAuthoringPrepare', { role: 'developer' });
  });
  (saveAuthoringDeepLink as jest.Mock).mockRejectedValue(new Error('Could not save selection'));
  await act(async () => {
    await expect(event('ltiAuthoringSave', { token: 'signed-result' })).rejects.toThrow(
      'Could not save',
    );
  });
  expect(screen.getByText('Draft')).toBeTruthy();
  expect(screen.queryByText('All changes saved')).toBeNull();
  expect(screen.getByText(/Your changes weren't saved/)).toBeTruthy();
});

it.each(['page', 'activity', 'new activity'])(
  'restores normal %s autosave feedback after configuration preparation fails',
  async (target) => {
    const page = await renderEditablePage();
    if (target === 'new activity') {
      jest.spyOn(ResourcePersistence, 'edit').mockResolvedValue({
        type: 'success',
        revisionSlug: 'page',
        revision_slug: 'page',
      });
      const editorCalls = (Editors as jest.Mock).mock.calls;
      const editorProps = editorCalls[editorCalls.length - 1][0];
      act(() => {
        editorProps.onAddItem(
          { id: 'new-reference', type: 'activity-reference', activity_id: 43 },
          [0],
          { ...entry, activityId: 43, activitySlug: 'new-tool' },
        );
      });
    }
    (startAuthoringDeepLink as jest.Mock).mockRejectedValueOnce(new Error('Launch unavailable'));

    await act(async () => {
      await expect(event('ltiAuthoringPrepare', { role: 'developer' })).rejects.toThrow(
        'Launch unavailable',
      );
    });
    expect(screen.queryByText('All changes saved')).toBeNull();

    const persistence =
      target === 'page'
        ? page.current!.persistence
        : page.current!.activityPersistence[target === 'new activity' ? '43' : '42'];
    const response = deferred<void>();
    let saving!: Promise<void>;
    act(() => {
      persistence.save(() => response.promise);
      saving = persistence.flushPendingChangesAsync!(false);
    });
    expect(screen.getByText('Saving...')).toBeTruthy();
    expect(screen.queryByText('All changes saved')).toBeNull();

    await act(async () => {
      response.resolve();
      await saving;
    });
    expect(screen.getByText('All changes saved')).toBeTruthy();
    expect(screen.getByText(/Your changes weren't saved/)).toBeTruthy();
    expect(screen.getByText('Draft')).toBeTruthy();
  },
);

it('flushes the existing page/activity autosaves before preparing and blocks launch when they fail', async () => {
  const page = await renderEditablePage();
  const order: string[] = [];
  page.current!.persistence.save(() => {
    order.push('page');
    return Promise.resolve();
  });
  page.current!.activityPersistence['42'].save(() => {
    order.push('activity');
    return Promise.resolve();
  });
  (startAuthoringDeepLink as jest.Mock).mockImplementation(() => {
    order.push('launch');
    return Promise.resolve({ request_id: 'request' });
  });
  await act(async () => {
    await event('ltiAuthoringPrepare', { role: 'developer' });
  });
  expect(order).toEqual(['page', 'activity', 'launch']);
  await act(async () => {
    await event('ltiAuthoringClose');
  });
  page.current!.activityPersistence['42'].save(() =>
    Promise.reject(new Error('Pending edit failed')),
  );
  await act(async () => {
    await expect(event('ltiAuthoringPrepare', { role: 'developer' })).rejects.toThrow(
      'Pending edit failed',
    );
  });
  expect(startAuthoringDeepLink).toHaveBeenCalledTimes(1);
  expect(ActivityPersistence.edit).not.toHaveBeenCalled();
});
