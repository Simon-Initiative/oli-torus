import * as i18n from './i18n';

export function gettext(msgid: string): string {
  i18n.textdomain('default');
  return i18n.gettext(msgid);
}

export function dgettext(domain: string, msgid: string): string {
  i18n.textdomain(domain);
  return i18n.gettext(msgid);
}

export function ngettext(msgid: string, msgidPlural: any, n: any): string {
  return i18n.ngettext(msgid, msgidPlural, n);
}
