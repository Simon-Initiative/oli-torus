import { expect, test } from '@playwright/test';
import { StrictRunHandle, StrictRunOutcome } from '@tasks/AdaptiveStrictDriver';
import {
  GATED_RUN_DEFAULTS,
  GatedRunDeps,
  GatedRunInputs,
  runGatedLote,
} from '@tasks/AdaptiveStrictGatedRun';
import { ShadowHandle } from '@tasks/AdaptiveShadowCapture';
import { failureText } from '@tasks/AdaptiveStrictAnchor';
import { Violation } from '@tasks/AdaptiveOracle';

/**
 * Per-site fault injection over the routed failure boundary: every routed exit
 * site is ACTIVATED and proves its pinned producer, and no other, through the
 * real boundary. `runGatedLote` is that boundary; every external edge is a dep,
 * so each site is injected offline and asserted on three facts:
 *   1. the ORIGINAL error object crosses the boundary (identity, never a
 *      replacement — the displacement class);
 *   2. an armed strict journal is SEALED (finish('bail')) before the rethrow;
 *   3. an armed shadow capture attempts its bail dump with the total
 *      failureText cause — and a fault BEFORE arming produces neither.
 */

type Calls = string[];

const SENTINEL_VIOLATIONS: Violation[] = [];

function makeStrictHandle(calls: Calls): StrictRunHandle {
  return {
    journal: { token: 'journal' } as never,
    recorder: null as never,
    async correlate() {
      calls.push('strict.correlate');
      return true;
    },
    async finish(outcome) {
      calls.push(`strict.finish:${outcome}`);
      return outcome === 'green' ? 'accepted' : 'sealed';
    },
    snapshot() {
      calls.push('strict.snapshot');
      return { token: 'snapshot' } as never;
    },
  };
}

function makeShadowHandle(calls: Calls, dumps: Array<Record<string, unknown>>): ShadowHandle {
  return {
    recorder: null as never,
    visits: [],
    async correlate() {
      calls.push('shadow.correlate');
      return true;
    },
    async finish(outcome) {
      calls.push(`shadow.finish:${outcome}`);
      return 'accepted';
    },
    async dump(_dir, label, extra = {}) {
      calls.push(`shadow.dump:${label}`);
      dumps.push(extra);
      return `/private/${label}.json`;
    },
  };
}

type Harness = {
  calls: Calls;
  dumps: Array<Record<string, unknown>>;
  page: { goto: (path: string) => Promise<void> };
  inputs: GatedRunInputs;
  deps: GatedRunDeps;
};

function harness(
  over: Partial<GatedRunDeps> = {},
  inputsOver: Partial<GatedRunInputs> = {},
): Harness {
  const calls: Calls = [];
  const dumps: Array<Record<string, unknown>> = [];
  const strictHandle = makeStrictHandle(calls);
  const shadowHandle = makeShadowHandle(calls, dumps);
  const outcome: StrictRunOutcome = {
    kind: 'completed',
    runRecord: { visits: [], permits: [], receipts: [], operationFailures: [], plans: [] },
  };
  const page = {
    async goto(path: string) {
      calls.push(`page.goto:${path}`);
    },
  };
  const deps: GatedRunDeps = {
    armShadowCapture: async () => {
      calls.push('armShadowCapture');
      return shadowHandle;
    },
    armStrictRun: () => {
      calls.push('armStrictRun');
      return strictHandle;
    },
    armPoison: async () => {
      calls.push('armPoison');
      return { fired: () => false };
    },
    makeLessonTask: () => {
      calls.push('makeLessonTask');
      return {
        deck: { token: 'deck' },
        async openFromOutline() {
          calls.push('openFromOutline');
        },
      } as never;
    },
    makeHomeTask: () => {
      calls.push('makeHomeTask');
      return {
        async login() {
          calls.push('login');
        },
      } as never;
    },
    assertSetupAnchor: () => {
      calls.push('assertSetupAnchor');
    },
    driveStrictLesson: async () => {
      calls.push('driveStrictLesson');
      return outcome;
    },
    audit: () => {
      calls.push('audit');
      return SENTINEL_VIOLATIONS;
    },
    writeFile: (async () => {
      calls.push('writeFile');
    }) as never,
    now: () => 1_000,
    log: () => {},
    warn: (line: string) => calls.push(`warn:${line.slice(0, 40)}`),
    ...over,
  };
  const inputs: GatedRunInputs = {
    sectionSlug: 's-1',
    lessonTitle: 'Plate Tectonics',
    searchTerm: 'Plate',
    manifest: { token: 'manifest' } as never,
    shadowDir: '/private/dir',
    poisonScreen: null,
    ...inputsOver,
  };
  return { calls, dumps, page: page as never, inputs, deps };
}

const run = (h: Harness) => runGatedLote(h.page as never, h.inputs, h.deps);

const expectBailProducer = (
  h: Harness,
  fault: unknown,
  opts: { strictArmed: boolean; shadowArmed: boolean; frozen?: boolean; evidenceWritten?: boolean },
) => {
  if (opts.frozen) {
    // the fault fired AFTER the green freeze: the journal is already
    // terminal, so a second finish would be wrong — and is correctly absent
    expect(h.calls).toContain('strict.finish:green');
    expect(h.calls.filter((c) => c === 'strict.finish:bail')).toEqual([]);
  } else if (opts.strictArmed) {
    expect(h.calls).toContain('strict.finish:bail');
  } else {
    expect(h.calls.filter((c) => c.startsWith('strict.finish'))).toEqual([]);
  }
  if (opts.shadowArmed) {
    expect(h.calls.filter((c) => c === 'shadow.finish:bail').length).toBe(1);
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
    const bail = h.dumps[h.dumps.length - 1];
    expect(bail.outcome).toBe('bail');
    expect(bail.walkError).toBe(failureText(fault));
  } else {
    expect(h.calls.filter((c) => c.startsWith('shadow.dump'))).toEqual([]);
  }
  // EXACT producer set: one bail seal at most, one bail dump at most, and no
  // OTHER producer — no green dump anywhere, and the strict evidence write
  // only when the fault postdates it
  expect(h.calls.filter((c) => c === 'strict.finish:bail').length).toBeLessThanOrEqual(1);
  expect(h.calls.filter((c) => c === 'shadow.dump:lote-green')).toEqual([]);
  if (!opts.evidenceWritten) {
    expect(h.calls.filter((c) => c === 'writeFile')).toEqual([]);
  }
};

test.describe('gated run — the green path and the verdict identity', () => {
  test('the healthy run returns EXACTLY what deps.audit produced (identity)', async () => {
    const h = harness();
    const result = await run(h);
    expect(result.violations).toBe(SENTINEL_VIOLATIONS);
    expect(result.flavor).toBe('accepted');
    expect(result.outcome.kind).toBe('completed');
    expect(h.calls).toContain('writeFile');
    expect(h.calls).toContain('shadow.dump:lote-green');
    expect(h.calls.filter((c) => c === 'strict.finish:bail')).toEqual([]);
  });

  test('without a shadow dir, neither capture nor evidence write happens', async () => {
    const h = harness({}, { shadowDir: null });
    const result = await run(h);
    expect(result.flavor).toBe('accepted');
    expect(h.calls.filter((c) => c.startsWith('armShadowCapture') || c === 'writeFile')).toEqual(
      [],
    );
  });

  test('an aborted walk still freezes, audits and dumps a BAIL capture', async () => {
    const aborted: StrictRunOutcome = {
      kind: 'aborted',
      runRecord: { visits: [], permits: [], receipts: [], operationFailures: [], plans: [] },
      failure: null,
      cause: 'strict driver [2] stopped',
    };
    const h = harness({
      driveStrictLesson: async () => aborted,
    });
    const result = await run(h);
    expect(result.outcome.kind).toBe('aborted');
    expect(h.calls).toContain('shadow.dump:lote-bail');
    const bail = h.dumps[h.dumps.length - 1];
    expect(bail.walkError).toBe('strict driver [2] stopped');
  });
});

test.describe('gated run — per-site fault injection (EXIT-EM, routed layer)', () => {
  const fault = new Error('injected routed fault');

  test('armShadowCapture rejects: nothing armed, nothing sealed, original rethrown', async () => {
    const h = harness({
      armShadowCapture: async () => {
        throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: false, shadowArmed: false });
  });

  test('armStrictRun throws: shadow already armed, its bail dump still lands', async () => {
    const h = harness({
      armStrictRun: () => {
        throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: false, shadowArmed: true });
  });

  test('armPoison rejects: both armed, both producers fire', async () => {
    const h = harness(
      {
        armPoison: async () => {
          throw fault;
        },
      },
      { poisonScreen: 'q:1' },
    );
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true });
  });

  const midwalkSites: Array<[string, Partial<GatedRunDeps>, boolean]> = [
    [
      'makeLessonTask',
      {
        makeLessonTask: () => {
          throw fault;
        },
      },
      false,
    ],
    [
      'makeHomeTask',
      {
        makeHomeTask: () => {
          throw fault;
        },
      },
      false,
    ],
    [
      'assertSetupAnchor',
      {
        assertSetupAnchor: () => {
          throw fault;
        },
      },
      false,
    ],
    [
      'driveStrictLesson',
      {
        driveStrictLesson: async () => {
          throw fault;
        },
      },
      false,
    ],
    [
      'audit',
      {
        audit: () => {
          throw fault;
        },
      },
      true,
    ],
    [
      'now',
      {
        now: () => {
          throw fault;
        },
      },
      true,
    ],
    [
      'writeFile',
      {
        writeFile: (async () => {
          throw fault;
        }) as never,
      },
      true,
    ],
  ];
  midwalkSites.forEach(([name, over, frozen]) => {
    test(`${name} faults: ${frozen ? 'frozen journal kept': 'seal'} + bail dump + identical rethrow`, async () => {
      const h = harness(over);
      await expect(run(h)).rejects.toBe(fault);
      expectBailProducer(h, fault, {
        strictArmed: true,
        shadowArmed: true,
        frozen,
        evidenceWritten: name === 'writeFile',
      });
    });
  });

  test('page.goto rejects: seal + bail dump + identical rethrow', async () => {
    const h = harness();
    h.page.goto = async () => {
      throw fault;
    };
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true });
  });

  test('login rejects at its own site', async () => {
    const h = harness({
      makeHomeTask: () =>
        ({
          async login() {
            throw fault;
          },
        }) as never,
    });
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true });
  });

  test('openFromOutline rejects at its own site', async () => {
    const h = harness({
      makeLessonTask: () =>
        ({
          deck: {},
          async openFromOutline() {
            throw fault;
          },
        }) as never,
    });
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true });
  });

  test('a correlate returning false is the module’s own typed throw', async () => {
    const h = harness();
    const strict = makeStrictHandle(h.calls);
    strict.correlate = async () => false;
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toThrow(/correlation unavailable before the walk/);
    expect(h.calls).toContain('strict.finish:bail');
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('a rejecting correlate carries its own error through', async () => {
    const h = harness();
    const strict = makeStrictHandle(h.calls);
    strict.correlate = async () => {
      throw fault;
    };
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true });
  });

  test('shadow.correlate rejects at its own site', async () => {
    const h = harness();
    const shadow = makeShadowHandle(h.calls, h.dumps);
    shadow.correlate = async () => {
      throw fault;
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('strict.finish:bail');
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('a hostile log is an exit owned by the same catch', async () => {
    const h = harness({
      log: () => {
        throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('strict.finish:bail');
  });

  test('strict.finish(green) rejects: catch seals via the guarded bail arm', async () => {
    const h = harness();
    const strict = makeStrictHandle(h.calls);
    strict.finish = async (o) => {
      h.calls.push(`strict.finish:${o}`);
      if (o === 'green') throw fault;
      return 'sealed';
    };
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('strict.finish:bail');
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('strict.snapshot throws at its own site', async () => {
    const h = harness();
    const strict = makeStrictHandle(h.calls);
    strict.snapshot = () => {
      throw fault;
    };
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toBe(fault);
    expectBailProducer(h, fault, { strictArmed: true, shadowArmed: true, frozen: true });
  });

  test('green-path shadow.finish rejects: bail dump still lands', async () => {
    const h = harness();
    const shadow = makeShadowHandle(h.calls, h.dumps);
    let greenFinishes = 0;
    shadow.finish = async (o) => {
      h.calls.push(`shadow.finish:${o}`);
      if (o === 'green' && greenFinishes++ === 0) throw fault;
      return 'accepted';
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('green-path shadow.dump rejects: the CATCH dump still lands with the cause', async () => {
    const h = harness();
    const shadow = makeShadowHandle(h.calls, h.dumps);
    let dumpCalls = 0;
    const realDump = shadow.dump.bind(shadow);
    shadow.dump = async (dir, label, extra) => {
      if (label === 'lote-green' && dumpCalls++ === 0) {
        h.calls.push('shadow.dump:lote-green');
        throw fault;
      }
      return realDump(dir, label, extra);
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
    const bail = h.dumps[h.dumps.length - 1];
    expect(bail.walkError).toBe(failureText(fault));
  });
});

test.describe('gated run — the catch is fail-total: every cleanup step is guarded, per site', () => {
  const fault = new Error('the original boundary error');
  const cleanupFault = new Error('a cleanup fault that must NOT displace the original');

  test('a rejecting bail seal cannot displace the original error', async () => {
    const h = harness({
      driveStrictLesson: async () => {
        throw fault;
      },
    });
    const strict = makeStrictHandle(h.calls);
    strict.finish = async (o) => {
      h.calls.push(`strict.finish:${o}`);
      throw cleanupFault;
    };
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('a rejecting bail shadow.finish still attempts the dump (flavor sealed)', async () => {
    const h = harness({
      driveStrictLesson: async () => {
        throw fault;
      },
    });
    const shadow = makeShadowHandle(h.calls, h.dumps);
    shadow.finish = async (o) => {
      h.calls.push(`shadow.finish:${o}`);
      throw cleanupFault;
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
    const bail = h.dumps[h.dumps.length - 1];
    expect(bail.flavor).toBe('sealed');
    expect(bail.walkError).toBe(failureText(fault));
  });

  test('a rejecting bail dump is WARNED, never a displacement', async () => {
    const h = harness({
      driveStrictLesson: async () => {
        throw fault;
      },
    });
    const shadow = makeShadowHandle(h.calls, h.dumps);
    shadow.dump = async () => {
      h.calls.push('shadow.dump:lote-bail');
      throw cleanupFault;
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls.some((c) => c.startsWith('warn:') && c.includes('bail dump FAILED'))).toBe(true);
  });

  test('a hostile poison.fired() in the catch cannot displace the original', async () => {
    const h = harness(
      {
        armPoison: async () => ({
          fired: () => {
            throw cleanupFault;
          },
        }),
        driveStrictLesson: async () => {
          throw fault;
        },
      },
      { poisonScreen: 'q:1' },
    );
    await expect(run(h)).rejects.toBe(fault);
    const bail = h.dumps[h.dumps.length - 1];
    expect(bail.poisonFired).toBeNull();
    expect(bail.walkError).toBe(failureText(fault));
  });
});

test.describe('gated run — logging can NEVER displace the original error', () => {
  const fault = new Error('the original boundary error');
  const loggingFault = new Error('hostile logging sink');

  test('a hostile deps.log at the catch SUCCESS handler cannot displace', async () => {
    const h = harness({
      driveStrictLesson: async () => {
        throw fault;
      },
      // throws ONLY on the bail-capture success log, never earlier
      log: (line: string) => {
        if (line.includes('bail capture')) throw loggingFault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });

  test('a hostile deps.warn on a rejecting bail dump cannot displace', async () => {
    const h = harness({
      driveStrictLesson: async () => {
        throw fault;
      },
      warn: () => {
        throw loggingFault;
      },
    });
    const shadow = makeShadowHandle(h.calls, h.dumps);
    shadow.dump = async () => {
      h.calls.push('shadow.dump:lote-bail');
      throw new Error('dump refused');
    };
    h.deps.armShadowCapture = async () => {
      h.calls.push('armShadowCapture');
      return shadow;
    };
    await expect(run(h)).rejects.toBe(fault);
  });

  test('the exported defaults are frozen — no mutable outer boundary state', () => {
    expect(Object.isFrozen(GATED_RUN_DEFAULTS)).toBe(true);
  });

  test('a green-path poison.fired() throw is a boundary fault, typed and sealed', async () => {
    const h = harness(
      {
        armPoison: async () => ({
          fired: () => {
            throw fault;
          },
        }),
      },
      { poisonScreen: 'q:1' },
    );
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('shadow.dump:lote-bail');
  });
});

test.describe('gated run — the remaining routed edges, injected at their own site', () => {
  const fault = new Error('injected routed fault');

  test('a non-string shadowDir makes path.join throw at its own site', async () => {
    const h = harness({}, { shadowDir: 42 as never });
    await expect(run(h)).rejects.toThrow();
    // the fault postdates the freeze: frozen journal kept, bail dump lands
    expect(h.calls).toContain('strict.finish:green');
    expect(h.calls.filter((c) => c === 'strict.finish:bail')).toEqual([]);
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
  });

  test('a snapshot whose serialization throws faults at JSON.stringify', async () => {
    const h = harness();
    const strict = makeStrictHandle(h.calls);
    strict.snapshot = () => {
      h.calls.push('strict.snapshot');
      return {
        toJSON() {
          throw fault;
        },
      } as never;
    };
    h.deps.armStrictRun = () => {
      h.calls.push('armStrictRun');
      return strict;
    };
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('strict.finish:green');
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
  });

  test('a hostile normal-path log (correlated line) is a typed boundary fault', async () => {
    const h = harness({
      log: (line: string) => {
        if (line.includes('correlated=')) throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls.filter((c) => c === 'strict.finish:bail').length).toBe(1);
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
  });

  test('a hostile normal-path log (evidence line) faults after the freeze', async () => {
    const h = harness({
      log: (line: string) => {
        if (line.includes('run evidence')) throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    expect(h.calls).toContain('strict.finish:green');
    expect(h.calls.filter((c) => c === 'strict.finish:bail')).toEqual([]);
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
  });

  test('a hostile capture-log (green dump line) faults after the green dump', async () => {
    const h = harness({
      log: (line: string) => {
        if (line.includes('shadow] capture')) throw fault;
      },
    });
    await expect(run(h)).rejects.toBe(fault);
    // the green dump already happened; the catch still writes the bail record
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-green').length).toBe(1);
    expect(h.calls.filter((c) => c === 'shadow.dump:lote-bail').length).toBe(1);
  });
});
