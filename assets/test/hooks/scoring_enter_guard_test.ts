import { ScoringEnterGuard } from '../../src/hooks/scoring_inputs';

const mountForm = () => {
  document.body.innerHTML = `
    <form id="scoring-form">
      <input id="score" type="number" />
      <input id="out_of" type="text" readonly />
      <textarea id="feedback"></textarea>
      <button id="chip" type="button">50%</button>
      <button id="apply" type="submit">Apply Score and Feedback</button>
    </form>`;
  ScoringEnterGuard.mounted.call({ el: document.getElementById('scoring-form') });
};

const pressEnter = (id: string) => {
  const event = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true });
  (document.getElementById(id) as HTMLElement).dispatchEvent(event);
  return event.defaultPrevented;
};

describe('ScoringEnterGuard', () => {
  test('Enter in any input of the scoring form, the read-only Out Of included, does not submit it', () => {
    mountForm();

    expect(pressEnter('score')).toBe(true);
    expect(pressEnter('out_of')).toBe(true);
  });

  test('Enter keeps its own meaning in the feedback and on the buttons', () => {
    mountForm();
    expect(pressEnter('out_of')).toBe(true);

    expect(pressEnter('feedback')).toBe(false);
    expect(pressEnter('chip')).toBe(false);
    expect(pressEnter('apply')).toBe(false);
  });
});
