import fs from 'node:fs';
import path from 'node:path';
import { FrameLocator, Page } from '@playwright/test';

export const STUB_SIM_URL = 'https://capi-stub.test/sim.html';

export enum CapiType {
  HANDSHAKE_REQUEST = 1,
  HANDSHAKE_RESPONSE = 2,
  ON_READY = 3,
  VALUE_CHANGE = 4,
  CONFIG_CHANGE = 5,
  CHECK_REQUEST = 7,
  CHECK_COMPLETE_RESPONSE = 8,
  GET_DATA_REQUEST = 9,
  GET_DATA_RESPONSE = 10,
  SET_DATA_REQUEST = 11,
  SET_DATA_RESPONSE = 12,
  INITIAL_SETUP_COMPLETE = 14,
  CHECK_START_RESPONSE = 15,
  RESIZE_PARENT_CONTAINER_REQUEST = 18,
  RESIZE_PARENT_CONTAINER_RESPONSE = 19,
}

export interface CapiMessage {
  handshake: { requestToken: string; authToken: string; config: Record<string, unknown> };
  options?: unknown;
  type: CapiType;
  values: any;
}

const stubHtml = fs.readFileSync(path.resolve(__dirname, 'stub-sim.html'), 'utf8');

/** Intercept the stub URL so the seeded iframe loads our stub sim. */
export const serveStubSim = async (page: Page) => {
  await page.route(STUB_SIM_URL, (route) =>
    route.fulfill({ status: 200, contentType: 'text/html', body: stubHtml }),
  );
};

/** The CAPI iframe inside the adaptive delivery page. */
export const stubFrame = (page: Page): FrameLocator =>
  page.frameLocator(`iframe[src="${STUB_SIM_URL}"]`);

export const sendFromStub = (
  frame: FrameLocator,
  type: CapiType,
  values?: unknown,
  handshakeOverrides?: Record<string, unknown>,
) =>
  frame.locator('body').evaluate(
    (_el, args) => (window as any).__capiSend(args.type, args.values, args.handshakeOverrides),
    { type, values, handshakeOverrides },
  );

export const sendRawFromStub = (frame: FrameLocator, raw: string) =>
  frame.locator('body').evaluate((_el, value) => (window as any).__capiSendRaw(value), raw);

export const startHandshake = (frame: FrameLocator) =>
  frame.locator('body').evaluate(() => (window as any).__capiHandshake());

export const receivedMessages = (
  frame: FrameLocator,
  type: CapiType,
): Promise<CapiMessage[]> =>
  frame
    .locator('body')
    .evaluate((_el, t) => (window as any).__capiReceived(t), type) as Promise<CapiMessage[]>;

export const allMessages = (frame: FrameLocator): Promise<CapiMessage[]> =>
  frame.locator('body').evaluate(() => (window as any).__capiLog) as Promise<CapiMessage[]>;

export const countOf = async (frame: FrameLocator, type: CapiType): Promise<number> =>
  (await receivedMessages(frame, type)).length;

/** Send a VALUE_CHANGE from the stub. vars: { key: { type, value, allowedValues? } } */
export const sendValueChange = (frame: FrameLocator, vars: Record<string, unknown>) =>
  sendFromStub(frame, CapiType.VALUE_CHANGE, vars);
