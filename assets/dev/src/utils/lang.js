import * as i18n from './i18n';
export function gettext(msgid) {
    i18n.textdomain('default');
    return i18n.gettext(msgid);
}
export function dgettext(domain, msgid) {
    i18n.textdomain(domain);
    return i18n.gettext(msgid);
}
export function ngettext(msgid, msgidPlural, n) {
    return i18n.ngettext(msgid, msgidPlural, n);
}
//# sourceMappingURL=lang.js.map