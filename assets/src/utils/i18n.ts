/*! gettext.js - Guillaume Potier - MIT Licensed */

/*eslint-disable */

// default values that could be overriden in i18n() construct
const defaults = {
  domain: 'messages',
  locale: (document !== undefined ? document.documentElement.getAttribute('lang') : false) || 'en',
  plural_func: (n: any) => {
    return { nplurals: 2, plural: n !== 1 ? 1 : 0 };
  },
  ctxt_delimiter: String.fromCharCode(4), // \u0004
};

// handy mixins taken from underscode.js
const _ = {
  isObject: (obj: any) => {
    const type = typeof obj;
    return type === 'function' || (type === 'object' && !!obj);
  },
  isArray: (obj: any) => {
    return toString.call(obj) === '[object Array]';
  },
};

const pluralFuncs: any = {};
let locale = defaults.locale;
let domain = defaults.domain;
const dictionary: any = {};
const pluralForms: any = {};
const ctxtDelimiter = defaults.ctxt_delimiter;

// sprintf equivalent, takes a string and some arguments to make a computed string
// eg: strfmt("%1 dogs are in %2", 7, "the kitchen"); => "7 dogs are in the kitchen"
// eg: strfmt("I like %1, bananas and %1", "apples"); => "I like apples, bananas and apples"
// NB: removes msg context if there is one present
const strfmt = function (fmt: any) {
  const args = arguments;

  return (
    fmt
      // put space after double % to prevent placeholder replacement of such matches
      .replace(/%%/g, '%% ')
      // replace placeholders
      .replace(/%(\d+)/g, (str: any, p1: any) => {
        return args[p1];
      })
      // replace double % and space with single %
      .replace(/%% /g, '%')
  );
};

const removeContext = function (str: any) {
  // if there is context, remove it
  if (str.indexOf(ctxtDelimiter) !== -1) {
    const parts = str.split(ctxtDelimiter);
    return parts[1];
  }

  return str;
};

const expandLocale = function (localeParam: any) {
  let locale = localeParam;
  const locales = [locale];
  let i = locale.lastIndexOf('-');
  while (i > 0) {
    locale = locale.slice(0, i);
    locales.push(locale);
    i = locale.lastIndexOf('-');
  }
  return locales;
};

const getPluralFunc = function (pluralForm: any) {
  // Plural form string regexp
  // taken from https://github.com/Orange-OpenSource/gettext.js/blob/master/lib.gettext.js
  // plural forms list available here
  // http://localization-guide.readthedocs.org/en/latest/l10n/pluralforms.html
  const pfRe = new RegExp(
    '^\\s*nplurals\\s*=\\s*[0-9]+\\s*;\\s*plural\\s*=\\s*(?:\\s|[-\\?\\|&=!<>+*/%:;n0-9_()])+',
  );

  if (!pfRe.test(pluralForm)) {
    throw new Error(`The plural form "${pluralForm}" is not valid`);
  }

  // Careful here, that is a hidden eval() equivalent..
  // Risk should be reasonable though since we test the plural_form through regex before
  // taken from https://github.com/Orange-OpenSource/gettext.js/blob/master/lib.gettext.js
  // TODO: should test if https://github.com/soney/jsep present and use it if so
  // tslint:disable-next-line
  return new Function(
    'n',
    'var plural, nplurals; ' +
      pluralForm +
      ' return { nplurals: nplurals, plural: (plural === true ? 1 : (plural ? plural : 0)) };',
  );
};

// Proper translation function that handle plurals and directives
// Contains juicy parts of
// https://github.com/Orange-OpenSource/gettext.js/blob/master/lib.gettext.js
const t = function (messages: any, n: any, options: any) {
  // Singular is very easy, just pass dictionnary message through strfmt
  if (!options.plural_form) {
    return strfmt.apply(
      undefined,
      [removeContext(messages[0])].concat(Array.prototype.slice.call(arguments, 3)),
    );
  }
  let plural;

  // if a plural func is given, use that one
  if (options.plural_func) {
    plural = options.plural_func(n);

    // if plural form never interpreted before, do it now and store it
  } else if (!pluralFuncs[locale]) {
    pluralFuncs[locale] = getPluralFunc(pluralForms[locale]);
    plural = pluralFuncs[locale](n);

    // we have the plural function, compute the plural result
  } else {
    plural = pluralFuncs[locale](n);
  }

  // If there is a problem with plurals, fallback to singular one
  if (
    plural.plural === undefined ||
    plural.plural > plural.nplurals ||
    messages.length <= plural.plural
  ) {
    plural.plural = 0;
  }

  return strfmt.apply(
    undefined,
    [removeContext(messages[plural.plural]), n].concat(Array.prototype.slice.call(arguments, 3)),
  );
};

export function setMessages(domain: any, locale: any, messages: any, pf: any) {
  if (!domain || !locale || !messages) {
    throw new Error('You must provide a domain, a locale and messages');
  }

  if ('string' !== typeof domain || 'string' !== typeof locale || !_.isObject(messages)) {
    throw new Error('Invalid arguments');
  }

  if (pf) {
    pluralForms[locale] = pf;
  }

  if (!dictionary[domain]) {
    dictionary[domain] = {};
  }

  dictionary[domain][locale] = messages;
}

export function loadJSON(jsonDataP: any, domain: any) {
  let jsonData;
  if (!_.isObject(jsonDataP)) {
    jsonData = JSON.parse(jsonDataP);
  } else {
    jsonData = jsonDataP;
  }

  if (!jsonData[''] || !jsonData['']['language'] || !jsonData['']['plural-forms']) {
    throw new Error(
      'Wrong JSON, it must have an empty key ("") with "language" and "plural-forms" information',
    );
  }

  const headers = jsonData[''];
  delete jsonData[''];

  return setMessages(
    domain || defaults.domain,
    headers['language'],
    jsonData,
    headers['plural-forms'],
  );
}

export function setLocale(loc: any) {
  locale = loc;
}
export function getLocale() {
  return locale;
}
// getter/setter for domain
export function textdomain(d: any) {
  if (!d) {
    return domain;
  }
  domain = d;
}

export function gettext(msgid: any) {
  return dcnpgettext.apply(
    undefined,
    [undefined, undefined, msgid, undefined, undefined].concat(
      Array.prototype.slice.call(arguments, 1),
    ),
  );
}

export function ngettext(msgid: any, msgidPlural: any, n: any) {
  return dcnpgettext.apply(
    undefined,
    [undefined, undefined, msgid, msgidPlural, n].concat(Array.prototype.slice.call(arguments, 3)),
  );
}

export function pgettext(msgctxt: any, msgid: any) {
  return dcnpgettext.apply(
    undefined,
    [undefined, msgctxt, msgid, undefined, undefined].concat(
      Array.prototype.slice.call(arguments, 2),
    ),
  );
}

export function dcnpgettext(d: any, msgctxt: any, msgid: any, msgidPlural: any, n: any) {
  domain = d || domain;

  if ('string' !== typeof msgid) {
    throw new Error(`Msgid "${msgid}" is not a valid translatable string`);
  }

  let translation;
  const options: any = { plural_form: false };
  const key = msgctxt ? msgctxt + ctxtDelimiter + msgid : msgid;
  let exist;
  const locales = expandLocale(locale);

  for (const i in locales) {
    locale = locales[i];
    exist = dictionary[domain] && dictionary[domain][locale] && dictionary[domain][locale][key];

    // because it's not possible to define both a singular and a plural form of the same msgid,
    // we need to check that the stored form is the same as the expected one.
    // if not, we'll just ignore the translation and consider it as not translated.
    if (msgidPlural) {
      exist = exist && 'string' !== typeof dictionary[domain][locale][key];
    } else {
      exist = exist && 'string' === typeof dictionary[domain][locale][key];
    }
    if (exist) {
      break;
    }
  }

  if (!exist) {
    translation = msgid;
    options.plural_func = defaults.plural_func;
  } else {
    translation = dictionary[domain][locale][key];
  }

  // Singular form
  if (!msgidPlural) {
    return t.apply(
      undefined,
      [[translation], n, options].concat(Array.prototype.slice.call(arguments, 5)),
    );
  }

  // Plural one
  options.plural_form = true;
  return t.apply(
    undefined,
    [exist ? translation : [msgid, msgidPlural], n, options].concat(
      Array.prototype.slice.call(arguments, 5),
    ),
  );
}
/*eslint-enable */
