import { ScoringRevealFocus } from '../../src/hooks/scoring_inputs';

const control = (id: string, top: number, { height = 40, keyboard = true } = {}) => {
  const el = document.getElementById(id) as HTMLElement;
  el.style.scrollMarginTop = '64px';
  el.getBoundingClientRect = () => ({ top, bottom: top + height, height } as DOMRect);
  el.matches = (selector: string) => selector === ':focus-visible' && keyboard;
  el.scrollIntoView = jest.fn();
  return el;
};

const mountPage = () => {
  document.body.innerHTML = `
    <div id="scoring-page">
      <textarea id="feedback"></textarea>
      <input id="score" />
    </div>`;
  ScoringRevealFocus.mounted.call({ el: document.getElementById('scoring-page') });
};

describe('ScoringRevealFocus', () => {
  test('a control that gets keyboard focus inside its top scroll margin is brought down to it', () => {
    mountPage();
    const feedback = control('feedback', 27);

    feedback.focus();

    expect(feedback.scrollIntoView).toHaveBeenCalledTimes(1);
    expect(feedback.scrollIntoView).toHaveBeenCalledWith({ block: 'start' });
  });

  test('a control that gets focus at or below its top scroll margin is left where it is', () => {
    mountPage();
    const feedback = control('feedback', 63);
    const score = control('score', 64);

    feedback.focus();
    expect(feedback.scrollIntoView).toHaveBeenCalledTimes(1);

    score.focus();
    expect(score.scrollIntoView).not.toHaveBeenCalled();
  });

  test('a control that gets focus without :focus-visible, as a reading region does on a click, is left where it is', () => {
    mountPage();
    const feedback = control('feedback', 27);
    const score = control('score', 27, { keyboard: false });

    feedback.focus();
    expect(feedback.scrollIntoView).toHaveBeenCalledTimes(1);

    score.focus();
    expect(score.scrollIntoView).not.toHaveBeenCalled();
  });

  test('a control taller than the window below its scroll margin is brought down to its top too', () => {
    Object.defineProperty(window, 'innerHeight', { configurable: true, value: 450 });
    mountPage();
    const feedback = control('feedback', -13, { height: 387 });

    feedback.focus();

    expect(feedback.scrollIntoView).toHaveBeenCalledTimes(1);
    expect(feedback.scrollIntoView).toHaveBeenCalledWith({ block: 'start' });
  });
});
