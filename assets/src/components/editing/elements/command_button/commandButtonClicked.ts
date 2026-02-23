import { makeCommandButtonEvent } from '../../../../data/events';
import {
  parseToggleStatesFromDataAttribute,
  selectCurrentAndNextToggleState,
} from '../../../common/commandButtonToggle';

/**
 * During preview/delivery, this is the function that gets called when the user clicks on the
 * command button. It's hooked up over in app.ts in a jquery-style event handler.
 **/
export const commandButtonClicked = (event: any) => {
  const fromCurrentTarget =
    event?.currentTarget instanceof HTMLElement ? event.currentTarget : null;
  const fromTargetElement = event?.target instanceof HTMLElement ? event.target : null;
  const fromTargetParent =
    event?.target && event.target.parentElement instanceof HTMLElement
      ? event.target.parentElement
      : null;

  const buttonEl =
    fromCurrentTarget ||
    ((fromTargetElement || fromTargetParent)?.closest?.(
      '[data-action="command-button"]',
    ) as HTMLElement | null);

  const target = buttonEl?.getAttribute('data-target') || undefined;
  const rawToggleStates = buttonEl?.getAttribute('data-toggle-states') || undefined;
  const rawMessage = buttonEl?.getAttribute('data-message') || undefined;

  if (!target) {
    console.error('Missing target for command button.');
    return;
  }
  if (!rawMessage && !rawToggleStates) {
    console.error('Missing message for command button.');
    return;
  }

  let message = rawMessage || '';
  const toggleStates = parseToggleStatesFromDataAttribute(rawToggleStates);
  if (toggleStates) {
    const currentTitle = buttonEl?.textContent?.trim();
    const { currentState, nextState } = selectCurrentAndNextToggleState(toggleStates, currentTitle);
    message = currentState.message;
    if (buttonEl) {
      buttonEl.textContent = nextState.title;
    }
  }

  const eventToSend = makeCommandButtonEvent({ forId: target, message });
  document.dispatchEvent(eventToSend);
};
