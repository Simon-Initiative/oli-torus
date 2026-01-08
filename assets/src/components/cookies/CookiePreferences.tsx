import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { consentOptions, setCookies } from 'components/cookies/utils';
import { ChevronDown } from 'components/misc/icons/Icons';
import { Modal } from 'components/modal/Modal';

const userOptions = consentOptions();

export interface CookiePreferencesProps {
  privacyPoliciesUrl: string;
}

export const CookiePreferences = (props: CookiePreferencesProps) => {
  const [functionalActive, setFunctionalActive] = useState(true);
  const [analyticsActive, setAnalyticActive] = useState(true);
  const [targetingActive, setTargetingActive] = useState(false);
  const [expandedSections, setExpandedSections] = useState({
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

  const prefChange = (id: string, checked: boolean) => {
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

  const toggleSection = (sectionId: string) => {
    setExpandedSections((prev) => ({
      ...prev,
      [sectionId]: !prev[sectionId as keyof typeof prev],
    }));
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
        <div className="accordion-item border-0">
          <div className="accordion-header mb-0 flex justify-content-between" id="headingOne">
            <div className="flex flex-row">
              <button
                className="flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#collapseOne"
                aria-expanded="true"
                aria-controls="collapseOne"
                onClick={() => toggleSection('strictCookies')}
              >
                Strictly Necessary Cookies
                <ChevronDown
                  className={`ml-2 transition-transform duration-200 ${
                    expandedSections.strictCookies ? 'rotate-180' : 'rotate-0'
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
                aria-label="Strictly Necessary Cookies"
                className="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top focus:outline-none cursor-pointer shadow-sm"
                id="strictCookies"
                checked
                disabled
              />
            </div>
          </div>
          <div
            id="collapseOne"
            className="accordion-collapse collapse"
            aria-labelledby="headingOne"
            data-parent="#preferenceAccordion"
          >
            <div className="accordion-body py-4 px-0">
              <div className="mb-2 text-Text-text-low-alpha">
                <p>
                  These cookies are necessary for our website to function properly and cannot be
                  switched off in our systems.
                </p>
                <p>
                  You can set your browser to block or alert you about these cookies, but some parts
                  of the site will not then work. These cookies do not store any personally
                  identifiable information.
                </p>
              </div>
              <div className="small">
                <a
                  href="#demo"
                  data-bs-toggle="collapse"
                  className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
                >
                  View Cookies
                </a>
                <div id="demo" className="collapse">
                  <div className="mt-2 overflow-x-auto max-w-full">
                    <table className="table table-striped">
                      <thead>
                        <tr>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Domain
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Cookies
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Type
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Description
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu</td>
                          <td>
                            _oli_key, _cky_opt_in, _cky_opt_in_dismiss, _cky_opt_choices,
                            _legacy_normandy_session, log_session_id, _csrf_token
                          </td>
                          <td>1st Party</td>
                          <td>
                            This cookies are usually only set in response to actions made by you
                            which amount to a request for services, such as setting your privacy
                            preferences, logging in or where they’re essential to provide you with a
                            service you have requested.
                          </td>
                        </tr>
                      </tbody>
                    </table>{' '}
                  </div>{' '}
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="accordion-item border-0">
          <div className="accordion-header mb-0 flex justify-content-between" id="headingTwo">
            <div className="flex flex-row">
              <button
                className="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#collapseTwo"
                aria-expanded="false"
                aria-controls="collapseTwo"
                onClick={() => toggleSection('functionalCookies')}
              >
                Functionality Cookies
                <ChevronDown
                  className={`ml-2 transition-transform duration-200 ${
                    expandedSections.functionalCookies ? 'rotate-180' : 'rotate-0'
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
                aria-label="Functionality Cookies"
                className="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                id="functionalCookies"
                checked={functionalActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)}
              />
            </div>
          </div>
          <div
            id="collapseTwo"
            className="accordion-collapse collapse"
            aria-labelledby="headingTwo"
            data-parent="#preferenceAccordion"
          >
            <div className="accordion-body py-4 px-0">
              <div className="mb-2 text-Text-text-low-alpha">
                <p>
                  These cookies are used to provide you with a more personalized experience on our
                  website and to remember choices you make when you use our website.
                </p>
                <p>
                  For example, we may use functionality cookies to remember your language
                  preferences or remember your login details.
                </p>
              </div>
              <div className="small">
                <a
                  href="#demo"
                  data-bs-toggle="collapse"
                  className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
                >
                  View Cookies
                </a>
                <div id="demo" className="collapse">
                  <div className="mt-2 overflow-x-auto max-w-full">
                    <table className="table table-striped">
                      <thead>
                        <tr>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Domain
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Cookies
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Type
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Description
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>None</td>
                          <td></td>
                          <td></td>
                          <td></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="accordion-item border-0">
          <div className="accordion-header mb-0 flex justify-content-between" id="headingThree">
            <div className="flex flex-row">
              <button
                className="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#collapseThree"
                aria-expanded="false"
                aria-controls="collapseThree"
                onClick={() => toggleSection('analyticsCookies')}
              >
                Analytics Cookies
                <ChevronDown
                  className={`ml-2 transition-transform duration-200 ${
                    expandedSections.analyticsCookies ? 'rotate-180' : 'rotate-0'
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
                aria-label="Analytics Cookies"
                className="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                id="analyticsCookies"
                checked={analyticsActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)}
              />
            </div>
          </div>
          <div
            id="collapseThree"
            className="accordion-collapse collapse"
            aria-labelledby="headingThree"
            data-parent="#preferenceAccordion"
          >
            <div className="accordion-body py-4 px-0">
              <div className="mb-2 text-Text-text-low-alpha">
                <p>
                  These cookies are used to collect information to analyze the traffic to our
                  website and how visitors are using our website.
                </p>
                <p>
                  For example, these cookies may track things such as how long you spend on the
                  website or the pages you visit which helps us to understand how we can improve our
                  website site for you.
                </p>
                <p>
                  The information collected through these tracking and performance cookies do not
                  identify any individual visitor.
                </p>
              </div>
              <div className="small">
                <a
                  href="#demo"
                  data-bs-toggle="collapse"
                  className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
                >
                  View Cookies
                </a>
                <div id="demo" className="collapse">
                  <div className="mt-2 overflow-x-auto max-w-full">
                    <table className="table table-striped">
                      <thead>
                        <tr>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Domain
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Cookies
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Type
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Description
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu</td>
                          <td>_gid, _ga, _ga_xxxxxxx, _utma, _utmb, _utmc, _utmz, nmstat</td>
                          <td>1st Party</td>
                          <td>
                            This cookies record basic website information such as: repeat visits;
                            page usage; country of origin for use in Google analytics and other site
                            improvements
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="accordion-item border-0">
          <div className="accordion-header mb-0 flex justify-content-between" id="headingFour">
            <div className="flex flex-row">
              <button
                className="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#collapseFour"
                aria-expanded="false"
                aria-controls="collapseFour"
                onClick={() => toggleSection('targetingCookies')}
              >
                Targeting Cookies
                <ChevronDown
                  className={`ml-2 transition-transform duration-200 ${
                    expandedSections.targetingCookies ? 'rotate-180' : 'rotate-0'
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
                aria-label="Targeting Cookies"
                className="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                id="targetingCookies"
                checked={targetingActive}
                onChange={(e: any) => prefChange(e.target.id, e.target.checked)}
              />
            </div>
          </div>
          <div
            id="collapseFour"
            className="accordion-collapse collapse"
            aria-labelledby="headingFour"
            data-parent="#preferenceAccordion"
          >
            <div className="accordion-body py-4 px-0">
              <div className="mb-2 text-Text-text-low-alpha">
                <p>
                  These cookies are used to show advertising that is likely to be of interest to you
                  based on your browsing habits.
                </p>
                <p>
                  These cookies, as served by our content and/or advertising providers, may combine
                  information they collected from our website with other information they have
                  independently collected relating to your web browser&apos;s activities across
                  their network of websites.
                </p>
                <p>
                  If you choose to remove or disable these targeting or advertising cookies, you
                  will still see adverts but they may not be relevant to you.
                </p>
              </div>
              <div className="small">
                <a
                  href="#demo"
                  data-bs-toggle="collapse"
                  className="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
                >
                  View Cookies
                </a>
                <div id="demo" className="collapse">
                  <div className="mt-2 overflow-x-auto max-w-full">
                    <table className="table table-striped">
                      <thead>
                        <tr>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Domain
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Cookies
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Type
                          </th>
                          <th scope="col" className="text-Text-text-high bg-Background-bg-primary">
                            Description
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>None</td>
                          <td></td>
                          <td></td>
                          <td></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
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
