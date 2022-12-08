import * as PageLifecycle from 'data/persistence/page_lifecycle';

/**
 * Finalizes an attempt, then redirects the browser to the 'redirectTo' URL received
 * as a result of the finalization.  Optionally can disable and change the text of
 * a button that invoked this function.
 * @param sectionSlug the section slug
 * @param revisionSlug  the page revision slug
 * @param attemptGuid the page resource attempt guid
 * @param buttonId optional - DOM id of the button that issued the submit
 */
export function finalize(
  sectionSlug: string,
  revisionSlug: string,
  attemptGuid: string,
  buttonId: string | null = null,
) {
  if (buttonId !== null) {
    const el: HTMLElement | null = document.getElementById(buttonId);
    if (el !== null) {
      (el as HTMLButtonElement).disabled = true;
      (el as HTMLButtonElement).innerText = 'Submitting...';
    }
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
