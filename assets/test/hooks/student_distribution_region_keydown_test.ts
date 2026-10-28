import { StudentDistributionRegionKeydown } from '../../src/hooks/student_distribution_region_keydown';

function buildRegion(): HTMLElement {
  document.body.innerHTML = `
    <div id="region" phx-value-group="excelling"></div>
  `;
  return document.getElementById('region') as HTMLElement;
}

function keydown(el: HTMLElement, key: string) {
  return el.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }));
}

describe('StudentDistributionRegionKeydown', () => {
  test('pushes select_student_group with the region group on Enter', () => {
    const el = buildRegion();
    const pushEventTo = jest.fn();
    const hook = { el, pushEventTo } as any;

    StudentDistributionRegionKeydown.mounted!.call(hook);
    keydown(el, 'Enter');

    expect(pushEventTo).toHaveBeenCalledWith(el, 'select_student_group', { group: 'excelling' });
  });

  test('pushes select_student_group with the region group on Space', () => {
    const el = buildRegion();
    const pushEventTo = jest.fn();
    const hook = { el, pushEventTo } as any;

    StudentDistributionRegionKeydown.mounted!.call(hook);
    keydown(el, ' ');

    expect(pushEventTo).toHaveBeenCalledWith(el, 'select_student_group', { group: 'excelling' });
  });

  test('prevents the default action so Space does not scroll the page', () => {
    const el = buildRegion();
    const hook = { el, pushEventTo: jest.fn() } as any;

    StudentDistributionRegionKeydown.mounted!.call(hook);
    const notCancelled = keydown(el, ' ');

    expect(notCancelled).toBe(false);
  });

  test('ignores unrelated keys such as Tab', () => {
    const el = buildRegion();
    const pushEventTo = jest.fn();
    const hook = { el, pushEventTo } as any;

    StudentDistributionRegionKeydown.mounted!.call(hook);
    keydown(el, 'Tab');

    expect(pushEventTo).not.toHaveBeenCalled();
  });

  test('removes the keydown listener on destroyed', () => {
    const el = buildRegion();
    const pushEventTo = jest.fn();
    const hook = { el, pushEventTo } as any;

    StudentDistributionRegionKeydown.mounted!.call(hook);
    StudentDistributionRegionKeydown.destroyed!.call(hook);
    keydown(el, 'Enter');

    expect(pushEventTo).not.toHaveBeenCalled();
  });
});
