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
  graded: boolean,
  buttonId: string | null = null,
) {
  setButtonContent(buttonId, graded ? 'Submitting...' : 'Resetting...');

  PageLifecycle.finalizePageAttempt(sectionSlug, revisionSlug, attemptGuid).then((result) => {
    if (result.result === 'success' && result.commandResult === 'success') {
      location.href = result.redirectTo;
    } else {
      if (result.result === 'success' && result.commandResult === 'failure') {
        console.info('Page finalization failure: ' + result.reason);
      } else {
        console.info('Page finalization failure');
      }

      setButtonContent(buttonId, 'An error occurred. Please reload the page and try again.', {
        error: true,
      });
    }
  });
}

function setButtonContent(id: string | null, content: string, opts?: { error?: boolean }) {
  if (id !== null) {
    const el: HTMLElement | null = document.getElementById(id);
    if (el !== null) {
      (el as HTMLButtonElement).disabled = true;
      (el as HTMLButtonElement).innerText = content;

      if (opts?.error) {
        (el as HTMLButtonElement).classList.add('!text-danger');
      } else {
        (el as HTMLButtonElement).classList.remove('!text-danger');
      }
    }
  }
}
