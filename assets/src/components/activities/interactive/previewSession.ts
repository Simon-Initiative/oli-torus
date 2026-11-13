import { InteractiveError, InteractiveRequestHandler } from './deliveryBridge';

type Part = {
  id: string;
  status: 'active' | 'evaluated';
  attemptNumber: number;
  response: unknown;
  score: number | null;
  outOf: number | null;
};

/** A disposable author-preview session implementing the same capabilities without learner records. */
export function createPreviewSession(
  partIds: string[],
  readOnly = false,
): InteractiveRequestHandler {
  const attempt = new Map<string, unknown>();
  const section = new Map<string, unknown>();
  const parts: Part[] = partIds.map((id) => ({
    id,
    status: 'active',
    attemptNumber: 1,
    response: null,
    score: null,
    outOf: null,
  }));
  let completed = false;
  const context = () => ({
    version: 1,
    readOnly: readOnly || completed,
    status: completed ? 'evaluated' : 'active',
    score: completed ? parts.reduce((sum, part) => sum + (part.score ?? 0), 0) : null,
    outOf: completed ? parts.length : null,
    parts,
  });
  return async ({ method, params }) => {
    if (method === 'context') return context();
    if (method === 'attempt.get' || method === 'section.get') {
      return (method === 'attempt.get' ? attempt : section).get(params?.key) ?? null;
    }
    if (method === 'activity.finalize' && completed) return context();
    if (readOnly || completed) throw new InteractiveError('read_only');
    switch (method) {
      case 'attempt.set':
      case 'section.set':
        if (
          typeof params?.key !== 'string' ||
          !Object.prototype.hasOwnProperty.call(params, 'value')
        )
          throw new InteractiveError('invalid_request');
        (method === 'attempt.set' ? attempt : section).set(params.key, params.value);
        return params.value;
      case 'parts.finalize': {
        const part = parts.find((p) => p.id === params?.partId);
        if (!part) throw new InteractiveError('unknown_part');
        if (
          typeof params?.correct !== 'boolean' ||
          !Object.prototype.hasOwnProperty.call(params, 'response')
        )
          throw new InteractiveError('invalid_request');
        if (part.status === 'evaluated') part.attemptNumber += 1;
        Object.assign(part, {
          status: 'evaluated',
          response: { input: params.response },
          score: params.correct ? 1 : 0,
          outOf: 1,
        });
        return context();
      }
      case 'activity.finalize':
        if (!parts.length || parts.some((part) => part.status !== 'evaluated'))
          throw new InteractiveError('incomplete_parts');
        completed = true;
        return context();
      default:
        throw new InteractiveError('invalid_request');
    }
  };
}
