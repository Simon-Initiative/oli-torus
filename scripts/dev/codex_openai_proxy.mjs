/*
 * Local Codex OpenAI-compatible proxy for Torus DOT dev mode.
 *
 * First configure Torus to use the local Codex service:
 *   mix gen_ai.setup_local_codex
 *
 * Run:
 *   node scripts/dev/codex_openai_proxy.mjs
 *
 * Optional environment variables:
 *   PORT=4001
 *   CODEX_BIN=codex
 *   CODEX_CWD=/path/to/your/repo
 *   CODEX_MODEL=<codex-model-name>
 *
 * Example:
 *   PORT=4001 CODEX_CWD=/path/to/your/repo node scripts/dev/codex_openai_proxy.mjs
 *
 * Health check:
 *   curl http://localhost:4001/health
 */

import crypto from 'node:crypto';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { promises as fs } from 'node:fs';

const PORT = Number(process.env.PORT || 4001);
const CODEX_BIN = process.env.CODEX_BIN || 'codex';
const CODEX_CWD = process.env.CODEX_CWD || process.cwd();
const CODEX_MODEL = process.env.CODEX_MODEL || '';

function writeJson(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function startSse(res) {
  res.writeHead(200, {
    'cache-control': 'no-cache, no-transform',
    connection: 'keep-alive',
    'content-type': 'text/event-stream',
  });
}

function writeSse(res, payload) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

function finishSse(res) {
  res.write('data: [DONE]\n\n');
  res.end();
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';

    req.on('data', (chunk) => {
      body += chunk;
    });

    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function renderMessages(messages = []) {
  return messages
    .map((message) => {
      const role = message.role || 'user';
      const name = message.name ? ` name=${message.name}` : '';
      const content =
        typeof message.content === 'string'
          ? message.content
          : JSON.stringify(message.content ?? '');

      return `[${role}${name}]\n${content}`;
    })
    .join('\n\n');
}

function buildOutputSchema(functions = []) {
  if (!functions.length) {
    return {
      additionalProperties: false,
      properties: {
        content: { type: 'string' },
        type: { enum: ['message'], type: 'string' },
      },
      required: ['type', 'content'],
      type: 'object',
    };
  }

  return {
    additionalProperties: false,
    properties: {
      arguments: {
        anyOf: [buildArgumentsSchema(functions), { type: 'null' }],
      },
      content: { type: ['string', 'null'] },
      name: {
        anyOf: [{ enum: functions.map((fn) => fn.name), type: 'string' }, { type: 'null' }],
      },
      type: { enum: ['message', 'function_call'], type: 'string' },
    },
    required: ['type', 'name', 'arguments', 'content'],
    type: 'object',
  };
}

function buildArgumentsSchema(functions) {
  const normalizedSchemas = functions.map((fn) => normalizeSchema(fn.parameters || {}));

  if (normalizedSchemas.length === 1) {
    return normalizedSchemas[0];
  }

  return {
    anyOf: normalizedSchemas,
  };
}

function normalizeSchema(schema) {
  if (Array.isArray(schema)) {
    return schema.map((item) => normalizeSchema(item));
  }

  if (!schema || typeof schema !== 'object') {
    return schema;
  }

  const normalized = Object.fromEntries(
    Object.entries(schema).map(([key, value]) => [key, normalizeSchema(value)]),
  );

  if (normalized.type === 'object') {
    return {
      ...normalized,
      additionalProperties: false,
      properties: normalized.properties || {},
    };
  }

  return normalized;
}

function buildPrompt({ functions, messages }) {
  const instructions = [
    'You are acting as an OpenAI-compatible chat completion backend for a local development proxy.',
    'Return exactly one JSON object matching the provided schema.',
    'Do not wrap the JSON in markdown.',
    'Do not put a second JSON object inside the content string.',
  ];

  const functionInstructions = functions.length
    ? [
        'If calling a function is the best next step, return:',
        '{"type":"function_call","name":"FUNCTION_NAME","arguments":{...},"content":null}',
        'Otherwise return:',
        '{"type":"message","content":"...","name":null,"arguments":null}',
        'Always include all four keys: type, name, arguments, content.',
        'Set unused keys to null.',
      ]
    : ['Return {"type":"message","content":"..."}'];

  return [
    ...instructions,
    ...functionInstructions,
    '',
    `Available functions:\n${JSON.stringify(functions, null, 2)}`,
    '',
    `Conversation:\n${renderMessages(messages)}`,
  ].join('\n');
}

async function runCodex({ functions, messages }) {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'codex-openai-proxy-'));
  const schemaPath = path.join(tmpDir, 'schema.json');
  const outputPath = path.join(tmpDir, 'output.json');

  await fs.writeFile(schemaPath, JSON.stringify(buildOutputSchema(functions), null, 2), 'utf8');

  const args = [
    'exec',
    '--skip-git-repo-check',
    '--sandbox',
    'read-only',
    '--output-schema',
    schemaPath,
    '--output-last-message',
    outputPath,
    '-',
  ];

  if (CODEX_MODEL) {
    args.unshift(CODEX_MODEL);
    args.unshift('--model');
  }

  try {
    await new Promise((resolve, reject) => {
      const child = spawn(CODEX_BIN, args, {
        cwd: CODEX_CWD,
        env: process.env,
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      let stderr = '';

      child.stderr.on('data', (chunk) => {
        stderr += chunk.toString();
      });

      child.on('error', reject);

      child.on('close', (code) => {
        switch (code) {
          case 0:
            resolve();
            break;

          default:
            reject(new Error(stderr || `codex exited with code ${code}`));
        }
      });

      child.stdin.write(buildPrompt({ functions, messages }));
      child.stdin.end();
    });

    return normalizeResult(JSON.parse(await fs.readFile(outputPath, 'utf8')));
  } finally {
    await fs.rm(tmpDir, { force: true, recursive: true });
  }
}

function tryParseJson(value) {
  if (typeof value !== 'string') {
    return null;
  }

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function isStructuredResult(value) {
  return !!value && typeof value === 'object' && typeof value.type === 'string';
}

function normalizeResult(result) {
  if (!isStructuredResult(result)) {
    return result;
  }

  if (result.type !== 'message' || typeof result.content !== 'string') {
    return result;
  }

  const nested = tryParseJson(result.content);

  if (!isStructuredResult(nested)) {
    return result;
  }

  switch (nested.type) {
    case 'message':
    case 'function_call':
      return nested;

    default:
      return result;
  }
}

function completionId() {
  return `chatcmpl_${crypto.randomUUID().replaceAll('-', '')}`;
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function asChatCompletion(result, model) {
  switch (result.type) {
    case 'function_call':
      return {
        choices: [
          {
            finish_reason: 'function_call',
            index: 0,
            message: {
              content: null,
              function_call: {
                arguments: JSON.stringify(result.arguments ?? {}),
                name: result.name,
              },
              role: 'assistant',
            },
          },
        ],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion',
      };

    default:
      return {
        choices: [
          {
            finish_reason: 'stop',
            index: 0,
            message: {
              content: result.content ?? '',
              role: 'assistant',
            },
          },
        ],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion',
      };
  }
}

function streamChatCompletion(res, result, model) {
  startSse(res);

  switch (result.type) {
    case 'function_call':
      writeSse(res, {
        choices: [
          {
            delta: {
              function_call: {
                arguments: JSON.stringify(result.arguments ?? {}),
                name: result.name,
              },
            },
            index: 0,
          },
        ],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion.chunk',
      });

      writeSse(res, {
        choices: [{ finish_reason: 'function_call', index: 0 }],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion.chunk',
      });
      break;

    default:
      writeSse(res, {
        choices: [
          {
            delta: {
              content: result.content ?? '',
            },
            index: 0,
          },
        ],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion.chunk',
      });

      writeSse(res, {
        choices: [{ finish_reason: 'stop', index: 0 }],
        created: nowSeconds(),
        id: completionId(),
        model,
        object: 'chat.completion.chunk',
      });
      break;
  }

  finishSse(res);
}

const server = http.createServer(async (req, res) => {
  try {
    switch (`${req.method} ${req.url}`) {
      case 'GET /health':
        writeJson(res, 200, { ok: true });
        return;

      case 'POST /v1/chat/completions':
        break;

      default:
        writeJson(res, 404, { error: 'not_found' });
        return;
    }

    const body = JSON.parse(await readBody(req));
    const functions = Array.isArray(body.functions) ? body.functions : [];
    const messages = Array.isArray(body.messages) ? body.messages : [];
    const model = body.model || 'codex-proxy';
    const result = await runCodex({ functions, messages });

    switch (body.stream) {
      case true:
        streamChatCompletion(res, result, model);
        break;

      default:
        writeJson(res, 200, asChatCompletion(result, model));
        break;
    }
  } catch (error) {
    writeJson(res, 500, {
      error: {
        message: error.message || String(error),
        type: 'proxy_error',
      },
    });
  }
});

server.listen(PORT, () => {
  console.log(`codex-openai-proxy listening on http://localhost:${PORT}`);
});
