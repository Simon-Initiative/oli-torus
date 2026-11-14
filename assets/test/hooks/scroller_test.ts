import { nearestScrollDelta } from '../../src/hooks/scroller';

// Viewport of 800px with a 63px sticky header offset: 737px of visible area.
const OFFSET = 63;
const VIEWPORT = 800;

const delta = (top: number, height: number) =>
  nearestScrollDelta({ top, bottom: top + height }, OFFSET, VIEWPORT);

describe('nearestScrollDelta', () => {
  it('does not scroll when the target is fully visible', () => {
    expect(delta(100, 300)).toBe(0);
    expect(delta(OFFSET, VIEWPORT - OFFSET)).toBe(0);
  });

  it('scrolls down just enough to reveal a target cut off at the bottom', () => {
    // Bottom edge at 1000 -> 200px hidden below the viewport.
    expect(delta(300, 700)).toBe(200);
  });

  it('scrolls up to align a target hidden behind the offset', () => {
    expect(delta(20, 300)).toBe(20 - OFFSET);
    expect(delta(-150, 300)).toBe(-150 - OFFSET);
  });

  it('keeps a target taller than the visible area top-aligned instead of hiding its top edge', () => {
    // 80px of space above, 200px overflowing below: scrolling 200px would push the top edge
    // 120px behind the offset, so the scroll is capped at the 80px of space above.
    const top = OFFSET + 80;
    const height = VIEWPORT + 200 - top;

    expect(delta(top, height)).toBe(80);
  });

  it('aligns an oversized target hidden behind the offset to the offset', () => {
    expect(delta(-300, 2000)).toBe(-300 - OFFSET);
  });
});
