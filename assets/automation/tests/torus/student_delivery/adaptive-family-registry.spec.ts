import { expect, test } from '@playwright/test';
import {
  PartInventory,
  registeredKeys,
  resolveFamily,
} from '../../../src/systems/torus/tasks/AdaptiveFamilyRegistry';

/**
 * Registry contract matrix (spec §3.6; the strict contract rowsand the
 * part-scoping half of ). Resolution is fail-closed BY NAME: every
 * rejection below names the key dimension that failed.
 */

const capiPart = (id: string, src: string) => ({ id, type: 'janus-capi-iframe', src });
const janusPart = (id: string, type: string) => ({ id, type, src: null });

const MATCHING_SRC = 'https://reflector.argos.education/reflector/sim/spr-widget-matching/prod/2.*';
const FITB_SRC =
  'https://reflector.argos.education/reflector/sim/spr-widget-fill-in-the-blanks/prod/2.*';
const DND_SRC =
  'https://reflector.argos.education/reflector/widget/spr-widget-general-drag-drop/6.*';

test.describe('registry resolution — accept', () => {
  test('every registered key resolves to exactly its own entry', () => {
    const keys = registeredKeys();
    expect(keys.length).toBe(6);
    keys.forEach((key) => {
      const entry = resolveFamily(key);
      expect(entry.family).toBe(key.family);
      expect(entry.version).toBe(key.version);
      expect(entry.mode).toBe(key.mode);
    });
  });

  test('the two janus-mcq modes are distinct entries under one family+version', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    const boxes = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'checkboxes' });
    expect(radio).not.toBe(boxes);
    expect(
      radio.expectedPayload(janusPart('m1', 'janus-mcq'), { pick: 'x' }, { receipts: [] }),
    ).toEqual([{ part_path_prefix: 'stage.m1.selectedChoice' }]);
    expect(
      boxes.expectedPayload(janusPart('m1', 'janus-mcq'), { picks: ['x'] }, { receipts: [] }),
    ).toEqual([{ part_path_prefix: 'stage.m1.selectedChoices' }]);
  });
});

test.describe('registry resolution — reject by name', () => {
  test('unknown family', () => {
    expect(() => resolveFamily({ family: 'janus-nope', version: '1' })).toThrow(
      /unknown family "janus-nope"/,
    );
  });

  test('absent version', () => {
    expect(() => resolveFamily({ family: 'janus-mcq', mode: 'radio' })).toThrow(
      /version is required/,
    );
  });

  test('unknown version lists the known ones', () => {
    expect(() => resolveFamily({ family: 'spr-widget-matching', version: '3' })).toThrow(
      /has no version "3" \(known: 2\)/,
    );
  });

  test('absent mode on a moded family', () => {
    expect(() => resolveFamily({ family: 'janus-mcq', version: '1' })).toThrow(/mode is required/);
  });

  test('unknown mode on a moded family', () => {
    expect(() => resolveFamily({ family: 'janus-mcq', version: '1', mode: 'dropdown' })).toThrow(
      /unknown mode/,
    );
  });

  test('a mode supplied to a mode-less family does not silently resolve', () => {
    expect(() =>
      resolveFamily({ family: 'spr-widget-matching', version: '2', mode: 'radio' }),
    ).toThrow(/unknown mode/);
  });
});

test.describe('directive validation is fail-closed per family', () => {
  test('janus-mcq radio requires a pick', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    expect(() => radio.validateDirective({})).toThrow(/missing required field "pick"/);
    expect(() => radio.validateDirective({ pick: '' })).toThrow(/pick must be a non-empty string/);
    expect(() => radio.validateDirective({ pick: 'a', part_id: '' })).toThrow(/part_id/);
    radio.validateDirective({ pick: 'a' });
  });

  test('janus-mcq checkboxes require a non-empty pick list', () => {
    const boxes = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'checkboxes' });
    expect(() => boxes.validateDirective({})).toThrow(/missing required field "picks"/);
    expect(() => boxes.validateDirective({ picks: [] })).toThrow(/non-empty string list/);
    expect(() => boxes.validateDirective({ picks: ['a', 2] })).toThrow(/non-empty string list/);
    boxes.validateDirective({ picks: ['a', 'b'] });
  });

  test('matching requires both sides of every link', () => {
    const entry = resolveFamily({ family: 'spr-widget-matching', version: '2' });
    expect(() => entry.validateDirective({ links: [] })).toThrow(/non-empty list/);
    expect(() => entry.validateDirective({ links: [{ left: 'a' }] })).toThrow(
      /every link needs left and right/,
    );
    entry.validateDirective({ links: [{ left: 'a', right: 'b' }] });
  });

  test('drag-drop requires placements and a detect selector', () => {
    const entry = resolveFamily({ family: 'spr-widget-general-drag-drop', version: '6' });
    expect(() => entry.validateDirective({ placements: [{ item: 'a', zone: 'z' }] })).toThrow(
      /missing required field "detect"/,
    );
    expect(() => entry.validateDirective({ placements: [{ item: 'a' }], detect: '.x' })).toThrow(
      /every placement needs item and zone/,
    );
    entry.validateDirective({ placements: [{ item: 'a', zone: 'z' }], detect: '.x' });
  });

  test('fill-in-the-blanks requires values and a ready selector', () => {
    const entry = resolveFamily({ family: 'spr-widget-fill-in-the-blanks', version: '2' });
    expect(() => entry.validateDirective({ values: {} })).toThrow(/non-empty object/);
    expect(() => entry.validateDirective({ values: { 'drop-1': 'a' } })).toThrow(
      /missing required field "ready_selector"/,
    );
    entry.validateDirective({ values: { 'drop-1': 'a' }, ready_selector: '.combo' });
  });
});

test.describe('detect — ownership is structural, ambiguity is a manifest error', () => {
  test('a unique janus part is owned without part_id', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    const parts: PartInventory = [
      janusPart('m1', 'janus-mcq'),
      janusPart('t1', 'janus-input-text'),
    ];
    expect(radio.detect(parts, { pick: 'a' })?.id).toBe('m1');
  });

  test('two parts of the family without part_id throw instead of picking one', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    const parts: PartInventory = [janusPart('m1', 'janus-mcq'), janusPart('m2', 'janus-mcq')];
    expect(() => radio.detect(parts, { pick: 'a' })).toThrow(/must declare part_id/);
  });

  test('part_id selects the named owner and rejects an absent one', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    const parts: PartInventory = [janusPart('m1', 'janus-mcq'), janusPart('m2', 'janus-mcq')];
    expect(radio.detect(parts, { pick: 'a', part_id: 'm2' })?.id).toBe('m2');
    expect(() => radio.detect(parts, { pick: 'a', part_id: 'm9' })).toThrow(
      /no .* part with id "m9"/,
    );
  });

  test('no candidate part yields null — a legal cross-screen screen (§3.6)', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    expect(radio.detect([janusPart('t1', 'janus-input-text')], { pick: 'a' })).toBeNull();
  });

  test('text_input owns either janus text type', () => {
    const entry = resolveFamily({ family: 'janus-input-text', version: '1' });
    expect(entry.detect([janusPart('t1', 'janus-multi-line-text')], { value: 'x' })?.id).toBe('t1');
    expect(entry.detect([janusPart('t2', 'janus-input-text')], { value: 'x' })?.id).toBe('t2');
  });
});

test.describe('detect — CAPI ownership is by widget identity and major version', () => {
  test('the matching widget is owned by its family segment in the src', () => {
    const entry = resolveFamily({ family: 'spr-widget-matching', version: '2' });
    const parts: PartInventory = [capiPart('c1', MATCHING_SRC), capiPart('c2', FITB_SRC)];
    expect(entry.detect(parts, { links: [{ left: 'a', right: 'b' }] })?.id).toBe('c1');
  });

  test("a different family's iframe is not owned", () => {
    const entry = resolveFamily({ family: 'spr-widget-matching', version: '2' });
    expect(entry.detect([capiPart('c2', DND_SRC)], { links: [] })).toBeNull();
  });

  test('a live major that disagrees with the declared version throws', () => {
    const entry = resolveFamily({ family: 'spr-widget-general-drag-drop', version: '6' });
    const stale = capiPart(
      'c9',
      'https://reflector.argos.education/reflector/widget/spr-widget-general-drag-drop/5.*',
    );
    expect(() => entry.detect([stale], { placements: [], detect: '.x' })).toThrow(
      /live widget major "5" does not match the declared version "6"/,
    );
  });

  test('two iframes of the same family are ambiguous', () => {
    const entry = resolveFamily({ family: 'spr-widget-matching', version: '2' });
    const parts: PartInventory = [capiPart('c1', MATCHING_SRC), capiPart('c2', MATCHING_SRC)];
    expect(() => entry.detect(parts, { links: [] })).toThrow(/ambiguous ownership/);
  });
});

test.describe('savedBarrier — CAPI clusters only', () => {
  test('CAPI families demand a deferred save of their cluster', () => {
    const entry = resolveFamily({ family: 'spr-widget-matching', version: '2' });
    expect(entry.savedBarrier(capiPart('c1', MATCHING_SRC), { links: [] })).toEqual(['stage.c1.']);
  });

  test('janus families write synchronously and declare no barrier', () => {
    const radio = resolveFamily({ family: 'janus-mcq', version: '1', mode: 'radio' });
    const text = resolveFamily({ family: 'janus-input-text', version: '1' });
    expect(radio.savedBarrier(janusPart('m1', 'janus-mcq'), { pick: 'a' })).toEqual([]);
    expect(text.savedBarrier(janusPart('t1', 'janus-input-text'), { value: 'x' })).toEqual([]);
  });
});
