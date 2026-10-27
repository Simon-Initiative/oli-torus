import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { ConsentPreferences, consentOptions, saveConsent } from 'components/cookies/consent';
import { ChevronDown } from 'components/misc/icons/Icons';
import { Modal } from 'components/modal/Modal';

export interface CookiePreferencesProps {
  privacyPoliciesUrl: string;
  preferences?: unknown;
  isMobileOrTablet?: boolean;
  onChange?: (preferences: ConsentPreferences) => void;
}

type CookiePreferenceKey = 'functionalCookies' | 'analyticsCookies';
type CookieSectionKey = 'strictCookies' | CookiePreferenceKey;

type CookieRow = {
  domain: string;
  cookies: string;
  type: string;
  description: string;
};

type CookieSectionConfig = {
  key: CookieSectionKey;
  title: string;
  description: string[];
  cookies: CookieRow[];
  disabled: boolean;
};

export const CookiePreferences = (props: CookiePreferencesProps) => {
  const [userOptions, setUserOptions] = useState(consentOptions);
  const [expandedSections, setExpandedSections] = useState<Record<CookieSectionKey, boolean>>({
    strictCookies: false,
    functionalCookies: false,
    analyticsCookies: false,
  });

  const prefChange = (id: CookiePreferenceKey, checked: boolean) => {
    const next = {
      ...userOptions,
      [id === 'functionalCookies' ? 'functionality' : 'analytics']: checked,
    };
    setUserOptions(next);
    props.onChange?.(next);
  };

  const toggleSection = (sectionId: CookieSectionKey) => {
    setExpandedSections((prev) => ({
      ...prev,
      [sectionId]: !prev[sectionId as keyof typeof prev],
    }));
  };

  const cookieSections: CookieSectionConfig[] = [
    {
      key: 'strictCookies',
      title: 'Strictly Necessary Cookies',
      description: [
        'These cookies are necessary for our website to function properly and cannot be switched off in our systems.',
        'You can set your browser to block or alert you about these cookies, but some parts of the site will not then work. These cookies do not store any personally identifiable information.',
      ],
      cookies: [
        {
          domain: window.location.hostname,
          cookies:
            '_oli_key, _cky_opt_in, _cky_opt_in_dismiss, _cky_opt_choices, _legacy_normandy_session, log_session_id, _csrf_token',
          type: '1st Party',
          description:
            'This cookies are usually only set in response to actions made by you which amount to a request for services, such as setting your privacy preferences, logging in or where they’re essential to provide you with a service you have requested.',
        },
      ],
      disabled: true,
    },
    {
      key: 'functionalCookies',
      title: 'Functionality Cookies',
      description: [
        'These cookies are used to provide you with a more personalized experience on our website and to remember choices you make when you use our website.',
        'For example, we may use functionality cookies to remember your language preferences or remember your login details.',
      ],
      cookies: [{ domain: 'None', cookies: '', type: '', description: '' }],
      disabled: false,
    },
    {
      key: 'analyticsCookies',
      title: 'Analytics Cookies',
      description: [
        'With your permission, Google Analytics cookies help us understand how Torus is used and improve it.',
        'What we measure: pages visited by type, features used, and videos started or completed, in aggregate.',
        'Analytics is off until you accept. You can change your choice at any time.',
      ],
      cookies: [
        {
          domain: window.location.hostname,
          cookies: '_ga, _ga_<measurement-id>',
          type: '1st Party',
          description:
            'Google Analytics cookies distinguish visits and maintain session state after you accept analytics.',
        },
      ],
      disabled: false,
    },
  ];

  const sectionChecked = (sectionKey: CookieSectionKey) => {
    switch (sectionKey) {
      case 'strictCookies':
        return true;
      case 'functionalCookies':
        return userOptions.functionality;
      case 'analyticsCookies':
        return userOptions.analytics;
      default:
        return false;
    }
  };

  return (
    <div>
      <div className="mb-4">
        <p className="text-Text-text-low-alpha">
          We are committed to privacy and data protection. When you provide us with your personal
          data, including preferences, we will only process information that is necessary for the
          purpose for which it has been collected.
        </p>
        <p>
          <a
            className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
            href={props.privacyPoliciesUrl}
          >
            Privacy Notice
          </a>
        </p>
      </div>
      <div className="flex flex-col gap-y-8" id="preferenceAccordion">
        {cookieSections.map((section, index) => {
          const collapseId = `collapse-${section.key}`;
          const headingId = `heading-${section.key}`;
          const tableId = `${section.key}-cookies`;
          const expanded = expandedSections[section.key];
          const checked = sectionChecked(section.key);

          return (
            <div key={section.key} className="border-0">
              <div className="mb-0 flex items-start justify-between gap-3" id={headingId}>
                <div className="flex flex-row">
                  <button
                    className={`flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha ${
                      expanded ? '' : 'collapsed'
                    }`}
                    type="button"
                    aria-expanded={expanded}
                    aria-controls={collapseId}
                    onClick={() => toggleSection(section.key)}
                  >
                    {section.title}
                    <ChevronDown
                      className={`ml-2 transition-transform duration-200 ${
                        expanded ? 'rotate-180' : 'rotate-0'
                      }`}
                      width={20}
                      height={20}
                    />
                  </button>
                </div>
                <div className="form-check form-switch">
                  <input
                    type="checkbox"
                    role="switch"
                    aria-label={section.title}
                    className="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                    id={section.key}
                    checked={checked}
                    disabled={section.disabled}
                    onChange={(event) => {
                      const target = event.target as HTMLInputElement;

                      if (!section.disabled) {
                        prefChange(target.id as CookiePreferenceKey, target.checked);
                      }
                    }}
                  />
                </div>
              </div>
              <div id={collapseId} hidden={!expanded} aria-labelledby={headingId}>
                <div className="accordion-body py-4 px-0">
                  <div className="mb-2 text-Text-text-low-alpha">
                    {section.description.map((paragraph, paragraphIndex) => (
                      <p key={`${section.key}-description-${paragraphIndex}`}>{paragraph}</p>
                    ))}
                  </div>
                  <div className="small">
                    <details>
                      <summary className="cursor-pointer font-bold text-Text-text-button">
                        View Cookies
                      </summary>
                      <div id={tableId}>
                        <div className="mt-2 overflow-x-auto max-w-full">
                          <table className="table table-striped w-full">
                            <thead>
                              <tr>
                                <th
                                  scope="col"
                                  className="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/4"
                                >
                                  Domain
                                </th>
                                <th
                                  scope="col"
                                  className="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/4"
                                >
                                  Cookies
                                </th>
                                <th
                                  scope="col"
                                  className="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/6"
                                >
                                  Type
                                </th>
                                <th
                                  scope="col"
                                  className="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/3"
                                >
                                  Description
                                </th>
                              </tr>
                            </thead>
                            <tbody>
                              {section.cookies.map((cookie, cookieIndex) => (
                                <tr key={`${section.key}-cookie-${cookieIndex}`}>
                                  <td className="px-2 py-1 text-xs sm:text-sm break-words">
                                    {cookie.domain}
                                  </td>
                                  <td className="px-2 py-1 text-xs sm:text-sm break-words">
                                    {cookie.cookies}
                                  </td>
                                  <td className="px-2 py-1 text-xs sm:text-sm">{cookie.type}</td>
                                  <td className="px-2 py-1 text-xs sm:text-sm break-words leading-tight">
                                    {cookie.description}
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </details>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export function selectCookiePreferences(props: CookiePreferencesProps): void {
  let draft = consentOptions();
  const cookiePreference = (
    <Modal
      title="Cookie Preferences"
      titleClassName="font-open-sans text-[18px] leading-[24px] tracking-[0px] font-bold text-Text-text-high"
      contentClassName="!bg-Background-bg-primary"
      headerClassName="!bg-Background-bg-primary"
      bodyClassName="!p-0 !pt-0"
      footerClassName="!bg-Background-bg-primary"
      reverseButtonOrder={true}
      onOk={() => {
        dismiss();
        void saveConsent(draft);
      }}
      onCancel={() => {
        dismiss();
      }}
      okLabel="Save my preferences"
      okClassName="bg-Fill-Buttons-fill-primary flex gap-0 items-center justify-center px-6 py-3 rounded-md"
      okTextClassName="font-open-sans font-semibold text-[14px] leading-[16px] tracking-normal text-center align-middle text-white"
      cancelLabel="Cancel"
      cancelClassName="bg-Background-bg-primary border border-Border-border-bold flex gap-0 items-center justify-center px-6 py-3 rounded-md hover:no-underline"
      cancelTextClassName="font-open-sans font-semibold text-[14px] leading-[16px] tracking-normal text-center align-middle text-Specially-Tokens-Text-text-button-secondary"
    >
      <div className="bg-Background-bg-primary p-4 pt-0">
        <CookiePreferences
          {...props}
          onChange={(preferences) => {
            draft = preferences;
          }}
        />
      </div>
    </Modal>
  );

  display(cookiePreference);
}

const display = (c: any) => {
  let cookiePrefs = document.querySelector('#cookie_prefs_display');
  if (!cookiePrefs) {
    cookiePrefs = document.createElement('div');
    cookiePrefs.id = 'cookie_prefs_display';
    document.body.appendChild(cookiePrefs);
  }
  ReactDOM.render(c, cookiePrefs);
};

const dismiss = () => {
  const cookiePrefs = document.querySelector('#cookie_prefs_display');
  if (cookiePrefs) {
    ReactDOM.unmountComponentAtNode(cookiePrefs);
  }
};
