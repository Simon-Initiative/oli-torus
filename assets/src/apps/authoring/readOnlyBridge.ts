import { releaseEditingLock } from './store/app/actions/locking';
import { attemptDisableReadOnly } from './store/app/actions/readonly';
import { setReadonly } from './store/app/slice';

type DispatchResult = {
  meta?: {
    requestStatus?: string;
  };
  payload?: {
    error?: string;
    msg?: string;
  };
};

type Dispatch = (action: any) => Promise<DispatchResult> | DispatchResult;

interface HandleShellReadOnlyToggleParams {
  desiredReadOnly: boolean;
  hasEditingLock: boolean;
  dispatch: Dispatch;
  reload: () => void;
}

interface HandleShellReadOnlyToggleResult {
  readonly: boolean;
  errorMessage?: string;
  sessionExpired?: boolean;
}

export async function handleShellReadOnlyToggle({
  desiredReadOnly,
  hasEditingLock,
  dispatch,
  reload,
}: HandleShellReadOnlyToggleParams): Promise<HandleShellReadOnlyToggleResult> {
  if (desiredReadOnly) {
    dispatch(setReadonly({ readonly: true }));

    if (hasEditingLock) {
      const releaseResult = (await dispatch(releaseEditingLock())) as DispatchResult;

      if (releaseResult.meta?.requestStatus !== 'fulfilled') {
        return {
          readonly: true,
          errorMessage:
            'Unable to release the edit lock. Refresh the page if editing remains enabled.',
        };
      }
    }

    return { readonly: true };
  }

  const attemptResult = (await dispatch(attemptDisableReadOnly())) as DispatchResult;

  if (attemptResult.meta?.requestStatus !== 'fulfilled') {
    const errorCode = attemptResult.payload?.error;

    if (errorCode == 'SESSION_EXPIRED') {
      reload();
      return { readonly: true, sessionExpired: true };
    }

    return {
      readonly: true,
      errorMessage: attemptResult.payload?.msg || 'Unable to disable read-only mode.',
    };
  }

  return { readonly: false };
}
