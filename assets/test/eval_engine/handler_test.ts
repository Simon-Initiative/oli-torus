import { handleEvent, handler, validateRequestEvent } from 'eval_engine';
import { VM_TIMEOUT_MS, createVmOptions } from 'eval_engine/evaluator';

describe('eval-engine handler', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('returns single-evaluation results for valid first-generation payloads', async () => {
    await expect(
      handler({
        vars: [{ variable: 'V1', expression: '1 + 1' }],
      }),
    ).resolves.toEqual([{ variable: 'V1', result: 2, errored: false }]);
  });

  test('preserves batch response shape for valid batch payloads', async () => {
    const result = await handler({
      vars: [
        [{ variable: 'V1', expression: '1 + 1' }],
        [{ variable: 'module', expression: 'module.exports = { answer: 42 };' }],
      ],
      count: 2,
    });

    expect(result).toEqual([
      [{ variable: 'V1', result: 2, errored: false }],
      [{ variable: 'answer', result: 42, errored: false }],
    ]);
  });

  test('returns an empty evaluation list for empty module exports', async () => {
    const result = await handler({
      vars: [[{ variable: 'module', expression: 'module.exports = {};' }]],
      count: 1,
    });

    expect(result).toEqual([[]]);
  });

  test('sanitizes module-mode output into JSON-safe values', async () => {
    const result = await handler({
      vars: [
        {
          variable: 'module',
          expression:
            'module.exports = { fn: function(){ return 1; }, nested: { value: 2, skipped: undefined }, date: new Date("2024-01-01T00:00:00.000Z") };',
        },
      ],
    });

    expect(result).toEqual([
      { variable: 'fn', result: "Error - check this variable's code", errored: false },
      { variable: 'nested', result: { value: 2, skipped: null }, errored: false },
      { variable: 'date', result: '2024-01-01T00:00:00.000Z', errored: false },
    ]);
  });

  test('returns a validation error when vars is missing', async () => {
    await expect(handler({ count: 1 })).resolves.toEqual({
      error: {
        type: 'validation_error',
        message: 'vars is required.',
      },
    });
  });

  test('returns a validation error when count is invalid', async () => {
    await expect(
      handler({
        vars: [{ variable: 'V1', expression: '1 + 1' }],
        count: 0,
      }),
    ).resolves.toEqual({
      error: {
        type: 'validation_error',
        message: 'count must be an integer between 1 and 1000.',
      },
    });
  });

  test('returns a runtime error envelope when evaluator execution fails', async () => {
    const result = await handleEvent(
      {
        vars: [{ variable: 'V1', expression: '1 + 1' }],
      },
      () => {
        throw new Error('boom');
      },
    );

    expect(result).toEqual({
      error: {
        type: 'runtime_error',
        message: 'Evaluation request failed.',
      },
    });
  });

  test('logs sanitized success metadata with duration and counts', async () => {
    const infoSpy = jest.spyOn(console, 'info').mockImplementation(() => undefined);

    await handler({
      vars: [{ variable: 'V1', expression: '1 + 1' }],
      count: 1,
    });

    expect(infoSpy).toHaveBeenCalledWith(
      '[eval-engine] request completed',
      expect.objectContaining({
        outcome: 'ok',
        duration_ms: expect.any(Number),
        request_shape: 'single',
        batch_count: 1,
        variable_count: 1,
        requested_count: 1,
        response_shape: 'single',
        evaluation_count: 1,
      }),
    );

    expect(JSON.stringify(infoSpy.mock.calls)).not.toContain('1 + 1');
  });

  test('logs sanitized validation failures without payload data', async () => {
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);

    await handler({ count: 1 });

    expect(warnSpy).toHaveBeenCalledWith(
      '[eval-engine] request completed',
      expect.objectContaining({
        outcome: 'validation_error',
        duration_ms: expect.any(Number),
        request_shape: 'invalid',
        batch_count: 0,
        variable_count: 0,
        requested_count: 1,
        error_type: 'validation_error',
      }),
    );

    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain('1 + 1');
  });

  test('logs sanitized runtime failures without evaluator payload data', async () => {
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);

    await handleEvent(
      {
        vars: [{ variable: 'V1', expression: '1 + 1' }],
        count: 1,
      },
      () => {
        throw new Error('boom');
      },
    );

    expect(warnSpy).toHaveBeenCalledWith(
      '[eval-engine] request completed',
      expect.objectContaining({
        outcome: 'runtime_error',
        duration_ms: expect.any(Number),
        request_shape: 'single',
        batch_count: 1,
        variable_count: 1,
        requested_count: 1,
        error_type: 'runtime_error',
      }),
    );

    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain('1 + 1');
  });

  test('validates payload shape for single and batch requests', () => {
    expect(
      validateRequestEvent({
        vars: [{ variable: 'V1', expression: '1 + 1' }],
      }),
    ).toEqual({
      ok: true,
      request: {
        vars: [{ variable: 'V1', expression: '1 + 1' }],
        count: 1,
      },
    });

    expect(
      validateRequestEvent({
        vars: [[{ variable: 'V1', expression: '1 + 1' }]],
        count: 3,
      }),
    ).toEqual({
      ok: true,
      request: {
        vars: [[{ variable: 'V1', expression: '1 + 1' }]],
        count: 3,
      },
    });
  });
});

describe('eval-engine vm hardening', () => {
  test('uses bounded vm2 settings', () => {
    expect(createVmOptions({ em: {} })).toEqual({
      allowAsync: false,
      eval: false,
      sandbox: { em: {} },
      timeout: VM_TIMEOUT_MS,
      wasm: false,
    });
  });
});
