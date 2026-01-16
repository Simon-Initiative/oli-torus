import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { consentOptions, setCookies } from 'components/cookies/utils';
import { ChevronDown } from 'components/misc/icons/Icons';
import { Modal } from 'components/modal/Modal';

const userOptions = consentOptions();

export interface CookiePreferencesProps {
  privacyPoliciesUrl: string;
}

type CookiePreferenceKey = 'functionalCookies' | 'analyticsCookies' | 'targetingCookies';
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
  const [functionalActive, setFunctionalActive] = useState(true);
  const [analyticsActive, setAnalyticActive] = useState(true);
  const [targetingActive, setTargetingActive] = useState(false);
  const [expandedSections, setExpandedSections] = useState<Record<CookieSectionKey, boolean>>({
    strictCookies: false,
    functionalCookies: false,
    analyticsCookies: false,
    targetingCookies: false,
  });

  useEffect(() => {
    const userOptions = consentOptions();
    prefChange('functionalCookies', userOptions.functionality);
    prefChange('analyticsCookies', userOptions.analytics);
    prefChange('targetingCookies', userOptions.targeting);
  }, []);

  const prefChange = (id: CookiePreferenceKey, checked: boolean) => {
    switch (id) {
      case 'functionalCookies':
        setFunctionalActive(checked);
        userOptions.functionality = checked;
        break;
      case 'analyticsCookies':
        setAnalyticActive(checked);
        userOptions.analytics = checked;
        break;
      case 'targetingCookies':
        setTargetingActive(checked);
        userOptions.targeting = checked;
        break;
      default:
        console.error('Unsupported cookie preference');
    }
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
          domain: 'canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu',
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
        'These cookies are used to collect information to analyze the traffic to our website and how visitors are using our website.',
        'For example, these cookies may track things such as how long you spend on the website or the pages you visit which helps us to understand how we can improve our website site for you.',
        'The information collected through these tracking and performance cookies do not identify any individual visitor.',
      ],
      cookies: [
        {
          domain: 'canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu',
          cookies: '_gid, _ga, _ga_xxxxxxx, _utma, _utmb, _utmc, _utmz, nmstat',
          type: '1st Party',
          description:
            'This cookies record basic website information such as: repeat visits; page usage; country of origin for use in Google analytics and other site improvements',
        },
      ],
      disabled: false,
    },
    {
      key: 'targetingCookies',
      title: 'Targeting Cookies',
      description: [
        'These cookies are used to show advertising that is likely to be of interest to you based on your browsing habits.',
        'These cookies, as served by our content and/or advertising providers, may combine information they collected from our website with other information they have independently collected relating to your web browser&apos;s activities across their network of websites.',
        'If you choose to remove or disable these targeting or advertising cookies, you will still see adverts but they may not be relevant to you.',
      ],
      cookies: [{ domain: 'None', cookies: '', type: '', description: '' }],
      disabled: false,
    },
  ];

  const sectionChecked = (sectionKey: CookieSectionKey) => {
    switch (sectionKey) {
      case 'strictCookies':
        return true;
      case 'functionalCookies':
        return functionalActive;
      case 'analyticsCookies':
        return analyticsActive;
      case 'targetingCookies':
        return targetingActive;
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
      <div className="accordion flex flex-col gap-y-8" id="preferenceAccordion">
        {cookieSections.map((section, index) => {
          const collapseId = `collapse-${section.key}`;
          const headingId = `heading-${section.key}`;
          const tableId = `${section.key}-cookies`;
          const expanded = expandedSections[section.key];
          const checked = sectionChecked(section.key);

          return (
            <div key={section.key} className="accordion-item border-0">
              <div className="accordion-header mb-0 flex justify-content-between" id={headingId}>
                <div className="flex flex-row">
                  <button
                    className={`flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha ${
                      expanded ? '' : 'collapsed'
                    }`}
                    type="button"
                    data-bs-toggle="collapse"
                    data-bs-target={`#${collapseId}`}
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
              <div
                id={collapseId}
                className="accordion-collapse collapse"
                aria-labelledby={headingId}
                data-parent="#preferenceAccordion"
              >
                <div className="accordion-body py-4 px-0">
                  <div className="mb-2 text-Text-text-low-alpha">
                    {section.description.map((paragraph, paragraphIndex) => (
                      <p key={`${section.key}-description-${paragraphIndex}`}>{paragraph}</p>
                    ))}
                  </div>
                  <div className="small">
                    <a
                      href={`#${tableId}`}
                      data-bs-toggle="collapse"
                      className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
                    >
                      View Cookies
                    </a>
                    <div id={tableId} className="collapse">
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

const savePreferences = () => {
  const days = 365 * 24 * 60 * 60 * 1000;
  setCookies([
    { name: '_cky_opt_choices', value: JSON.stringify(userOptions), duration: days },
    { name: '_cky_opt_in', value: 'true', duration: days },
  ]);
};

export function selectCookiePreferences(props: CookiePreferencesProps): void {
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
        savePreferences();
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
        <CookiePreferences privacyPoliciesUrl={props.privacyPoliciesUrl} />
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
