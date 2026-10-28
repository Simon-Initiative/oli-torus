import { ScoringRevealFocus } from '../../src/hooks/scoring_inputs';

const hook = ScoringRevealFocus as any;
let resize: () => void;
let observer: { observe: jest.Mock; disconnect: jest.Mock };
let instance: any;
let left: number;
let content: number;
const panel = () => document.getElementById('scoring-panel')!;

beforeEach(() => {
  left = 600;
  content = 756;
  document.body.innerHTML = `<div id="scoring-page"><div id="scoring-submission"></div>
    <div id="scoring-panel"><div id="panel-heading"></div><form id="scoring-form"></form></div></div>`;
  document.getElementById('scoring-submission')!.getBoundingClientRect = () =>
    ({ height: left } as DOMRect);
  document.getElementById('panel-heading')!.getBoundingClientRect = () =>
    ({ top: 100, bottom: 200 } as DOMRect);
  document.getElementById('scoring-form')!.getBoundingClientRect = () =>
    ({ top: 200, bottom: 100 + content } as DOMRect);
  observer = { observe: jest.fn(), disconnect: jest.fn() };
  global.ResizeObserver = jest.fn((callback) => {
    resize = callback;
    return observer;
  }) as any;
  instance = { el: document.getElementById('scoring-page') };
});

afterEach(() => hook.destroyed?.call(instance));

test('a submission shorter than the full panel uses page scrolling', () => {
  hook.mounted.call(instance);
  expect(panel().dataset.pageScroll).toBe('true');
});

test('a long submission keeps independent panel scrolling', () => {
  left = 1400;
  hook.mounted.call(instance);
  expect(panel().dataset.pageScroll).toBe('false');
});

test('equal heights need no independent panel scroll', () => {
  left = content;
  hook.mounted.call(instance);
  expect(panel().dataset.pageScroll).toBe('true');
});

test('a resize reclassifies growing and shrinking submissions', () => {
  hook.mounted.call(instance);
  left = 1400;
  resize?.();
  expect(panel().dataset.pageScroll).toBe('false');
  left = 400;
  resize?.();
  expect(panel().dataset.pageScroll).toBe('true');
});

test('removing help text or replacing the form after Apply remeasures natural content', () => {
  hook.mounted.call(instance);
  content = 350;
  const replacement = document.createElement('form');
  replacement.id = 'scoring-form';
  replacement.getBoundingClientRect = () => ({ bottom: 100 + content } as DOMRect);
  document.getElementById('scoring-form')!.replaceWith(replacement);
  hook.updated?.call(instance);
  expect(panel().dataset.pageScroll).toBe('false');
  expect(observer.observe).toHaveBeenCalledWith(document.getElementById('scoring-form'));
});

test('a LiveView patch restores the layout attribute without changing server classes or styles', () => {
  hook.mounted.call(instance);
  panel().removeAttribute('data-page-scroll');
  panel().className = 'server-classes';
  panel().style.color = 'red';
  hook.updated?.call(instance);
  expect(panel().dataset.pageScroll).toBe('true');
  expect(panel().className).toBe('server-classes');
  expect(panel().style.color).toBe('red');
});

test('the observer watches intrinsic content and releases its subscriptions on destruction', () => {
  hook.mounted.call(instance);
  expect(observer.observe).toHaveBeenCalledWith(document.getElementById('scoring-submission'));
  expect(observer.observe).toHaveBeenCalledWith(document.getElementById('panel-heading'));
  expect(observer.observe).toHaveBeenCalledWith(document.getElementById('scoring-form'));
  hook.destroyed?.call(instance);
  expect(observer.disconnect).toHaveBeenCalled();
});

test('internal scroll offsets do not change the full panel height used for comparison', () => {
  document.getElementById('panel-heading')!.getBoundingClientRect = () =>
    ({ top: -300 } as DOMRect);
  document.getElementById('scoring-form')!.getBoundingClientRect = () =>
    ({ bottom: -300 + content } as DOMRect);
  hook.mounted.call(instance);
  expect(panel().dataset.pageScroll).toBe('true');
});
