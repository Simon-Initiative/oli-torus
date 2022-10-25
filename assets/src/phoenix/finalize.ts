import * as PageLifecycle from 'data/persistence/page_lifecycle';

export function finalize(
  buttonId: string,
  sectionSlug: string,
  revisionSlug: string,
  attemptGuid: string,
) {
  const el: HTMLElement | null = document.getElementById(buttonId);
  if (el !== null) {
    (el as HTMLButtonElement).disabled = true;
    (el as HTMLButtonElement).innerText = 'Submitting...';
  }

  PageLifecycle.finalizePageAttempt(sectionSlug, revisionSlug, attemptGuid).then((result) => {
    if (result.result === 'success') {
      if (result.commandResult === 'failure') {
        console.info('Page finaliztion failure ' + result.commandResult);
        console.info('Page finaliztion ' + result.reason);
      }
      location.href = result.redirectTo;
    } else {
      console.info('Unknown server error');
      location.reload();
    }
  });
}
