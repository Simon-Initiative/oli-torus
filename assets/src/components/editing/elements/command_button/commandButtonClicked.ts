import { makeCommandButtonEvent } from '../../../../data/events';

/**
 * During preview/delivery, this is the function that gets called when the user clicks on the
 * command button. It's hooked up over in app.ts in a jquery-style event handler.
 **/
export const commandButtonClicked = (event: any) => {
  const target = event.target?.attributes?.getNamedItem('data-target')?.value;
  const message = event.target?.attributes?.getNamedItem('data-message')?.value;

  if (!target) {
    console.error('Missing target for command button.');
    return;
  }
  if (!message) {
    console.error('Missing message for command button.');
    return;
  }

  const eventToSend = makeCommandButtonEvent({ forId: target, message: message });
  console.info('Command sent', eventToSend);
  document.dispatchEvent(eventToSend);
};
