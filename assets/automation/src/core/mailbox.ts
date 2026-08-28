import { APIRequestContext } from '@playwright/test';

type MailboxMessage = {
  id: string;
  subject: string;
  to: string[];
  sent_at: string;
};

type MailboxMessageDetail = MailboxMessage & {
  html_body: string | null;
  text_body: string | null;
};

type WaitForEmailOptions = {
  baseUrl: string;
  recipient: string;
  subject: string;
  token: string;
  timeoutMs?: number;
};

const DEFAULT_TIMEOUT_MS = 30_000;
const POLL_INTERVAL_MS = 250;

export async function waitForMailboxEmail(
  request: APIRequestContext,
  options: WaitForEmailOptions,
): Promise<MailboxMessageDetail> {
  const deadline = Date.now() + (options.timeoutMs ?? DEFAULT_TIMEOUT_MS);

  while (Date.now() < deadline) {
    const messages = await listMailboxEmails(request, options);

    if (messages.length > 0) {
      return getMailboxEmail(request, options, messages[0].id);
    }

    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }

  throw new Error(
    `Timed out waiting for '${options.subject}' email sent to '${options.recipient}'.`,
  );
}

async function listMailboxEmails(
  request: APIRequestContext,
  options: WaitForEmailOptions,
): Promise<MailboxMessage[]> {
  const url = new URL('/test/emails', options.baseUrl);
  url.searchParams.set('to', options.recipient);
  url.searchParams.set('subject', options.subject);

  const response = await request.get(url.toString(), { headers: authHeaders(options.token) });

  if (!response.ok()) {
    throw new Error(`Mailbox list request failed (${response.status()}): ${await response.text()}`);
  }

  return ((await response.json()) as { emails: MailboxMessage[] }).emails;
}

async function getMailboxEmail(
  request: APIRequestContext,
  options: WaitForEmailOptions,
  id: string,
): Promise<MailboxMessageDetail> {
  const url = new URL(`/test/emails/${encodeURIComponent(id)}`, options.baseUrl);
  const response = await request.get(url.toString(), { headers: authHeaders(options.token) });

  if (!response.ok()) {
    throw new Error(
      `Mailbox detail request failed (${response.status()}): ${await response.text()}`,
    );
  }

  return ((await response.json()) as { email: MailboxMessageDetail }).email;
}

function authHeaders(token: string) {
  return { 'x-playwright-scenario-token': token };
}

export function extractAccountLink(
  htmlBody: string | null,
  textBody: string | null,
  segment: 'authors' | 'users',
  action: 'confirm' | 'reset_password',
): string {
  const path = `/${segment}/${action}/`;
  const source = [htmlBody, textBody].filter(Boolean).join(' ');
  const match = source.match(new RegExp(`https?:\\/\\/[^\\s"'<]+${path}[^\\s"'<]+`));

  if (!match) {
    throw new Error(`Expected an account ${action} URL under ${path} in the email.`);
  }

  return match[0].replace(/&amp;/g, '&');
}
