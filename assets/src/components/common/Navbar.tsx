import React, { PropsWithChildren, useCallback, useState } from 'react';
import { Transition } from '@tailwindui/react';
import { useClickOutside } from 'components/hooks/useClickOutside';
import { MediaSize, useMediaQuery } from 'hooks/media_query';
import { classNames } from 'utils/classNames';
import { TechSupportButton } from './TechSupportButton';
import { Routes, User, UserAccountMenu } from './UserAccountMenu';

/**
 * Loads a react component by react-phoenix identifier with given props
 * E.g. `renderComponent('Components.Example', { foo: 'bar' })`
 *
 * @param componentName react-phoenix component identifier
 * @param props component props
 * @returns react element
 */
const renderComponent = (componentName: string, props: any) => {
  const reactClass = Array.prototype.reduce.call(
    componentName.split('.'),
    (acc: any, el: any) => {
      return acc[el];
    },
    window,
  );

  return React.createElement(reactClass, props);
};

interface Logo {
  href: string;
  src: { light: string; dark: string };
}

interface Link {
  name: string;
  active: boolean;
  href: string;
  popout?: {
    component: string;
    props: any;
  };
}

interface NavbarProps {
  logo: Logo;
  links: Link[];
  user: User;
  preview: boolean;
  routes: Routes;
  sectionSlug: string;
  timezones: [string, string][];
}

interface Popout {
  component: string;
  props: any;
}

export const Navbar = ({
  logo,
  links,
  user,
  preview,
  routes,
  sectionSlug,
  timezones,
}: NavbarProps) => {
  const [showNavbar, setShowNavbar] = useState(false);
  const [popoutContainer, setPopoutContainer] = useState<Popout>();
  const isLargeScreen = useMediaQuery(MediaSize.lg);
  const ref = useClickOutside<HTMLDivElement>(useCallback(() => setPopoutContainer(undefined), []));

  return (
    <div ref={ref}>
      <nav className="flex flex-col w-full lg:fixed lg:top-0 lg:left-0 lg:bottom-0 lg:w-[200px] py-2 bg-white dark:bg-gray-800 relative shadow-lg lg:flex select-none z-30">
        <div className="w-full">
          <a className="block w-[200px] lg:p-2 lg:mb-14 mx-auto" href={logo.href}>
            <img src={logo.src.light} className="inline-block dark:hidden" alt="OLI Torus logo" />
            <img src={logo.src.dark} className="hidden dark:inline-block" alt="OLI Torus logo" />
          </a>

          <button
            className="
            lg:hidden
            text-gray-500
            border-0
            absolute right-0 top-0
            hover:shadow-none hover:no-underline
            p-2.5
            bg-transparent
            focus:outline-none focus:ring-0 focus:shadow-none focus:no-underline
          "
            type="button"
            aria-controls="navbarSupportedContent"
            aria-expanded="false"
            aria-label="Toggle navigation"
            onClick={() => setShowNavbar(!showNavbar)}
          >
            <svg
              aria-hidden="true"
              focusable="false"
              data-prefix="fas"
              data-icon="bars"
              className="w-6"
              role="img"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 448 512"
            >
              <path
                fill="currentColor"
                d="M16 132h416c8.837 0 16-7.163 16-16V76c0-8.837-7.163-16-16-16H16C7.163 60 0 67.163 0 76v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16z"
              ></path>
            </svg>
          </button>
        </div>

        <div className={`lg:!flex flex-grow flex flex-col ${showNavbar ? '' : 'hidden'}`}>
          <div className="flex-1 items-center lg:items-start">
            {links.map(({ name, active, popout, href }) =>
              popout ? (
                <NavExpand
                  key={name}
                  name={name}
                  active={active}
                  popout={popout}
                  popoutContainer={popoutContainer}
                  setPopoutContainer={setPopoutContainer}
                />
              ) : (
                <NavLink key={name} name={name} active={active} href={href} />
              ),
            )}
          </div>

          <TechSupportButton />

          <hr className="border-t border-gray-300 dark:border-gray-700" />

          <UserAccountMenu
            preview={preview}
            user={user}
            routes={routes}
            sectionSlug={sectionSlug}
            timezones={timezones}
          />
        </div>
      </nav>

      {isLargeScreen && (
        <LargePopoutContainer show={!!popoutContainer} setPopoutContainer={setPopoutContainer}>
          {popoutContainer && renderComponent(popoutContainer?.component, popoutContainer?.props)}
        </LargePopoutContainer>
      )}
    </div>
  );
};

interface NavLinkProps {
  name: string;
  active: boolean;
  href: string;
}

const NavLink = ({ href, active, name }: NavLinkProps) => (
  <a
    href={href}
    className="block no-underline px-6 py-2 hover:no-underline text-current hover:text-delivery-primary-hover hover:dark:text-delivery-primary-dark-hover"
  >
    <div
      className={classNames(
        'border-b-2',
        active
          ? 'font-bold border-delivery-primary dark:border-delivery-primary-dark text-delivery-primary dark:text-delivery-primary-dark'
          : 'border-transparent',
      )}
    >
      {name}
    </div>
  </a>
);

interface NavExpandProps {
  name: string;
  active: boolean;
  popout: Popout;
  popoutContainer?: Popout;
  setPopoutContainer: (p: Popout | undefined) => void;
}

const NavExpand = ({
  name,
  popout,
  active,
  popoutContainer,
  setPopoutContainer,
}: PropsWithChildren<NavExpandProps>) => {
  const [show, setShow] = useState(false);
  const isLargeScreen = useMediaQuery(MediaSize.lg);

  const ref = useClickOutside<HTMLDivElement>(useCallback(() => setShow(false), []));

  return (
    <div ref={ref}>
      <div
        className="block no-underline px-6 py-2 cursor-pointer hover:no-underline text-current hover:text-delivery-primary-hover dark:hover:text-delivery-primary-dark-hover"
        onClick={() => {
          popoutContainer ? setPopoutContainer(undefined) : setPopoutContainer(popout);
          setShow(!show);
        }}
      >
        <div
          className={classNames(
            'border-b-2',
            active
              ? 'font-bold border-delivery-primary dark:border-delivery-primary-dark text-delivery-primary dark:text-delivery-primary-dark'
              : 'border-transparent',
          )}
        >
          {name}
        </div>
      </div>
      {!isLargeScreen && (
        <SmallInlineContainer show={show}>
          {show && renderComponent(popout.component, popout.props)}
        </SmallInlineContainer>
      )}
    </div>
  );
};

interface LargePopoutContainerProps {
  show: boolean;
  setPopoutContainer: (p: Popout | undefined) => void;
}

const LargePopoutContainer = ({ show, children }: PropsWithChildren<LargePopoutContainerProps>) => (
  <Transition
    show={show}
    enter="transition-all duration-200"
    enterFrom="opacity-0 w-0"
    enterTo="opacity-100 w-[600px]"
    leave="transition-all duration-250"
    leaveFrom="opacity-100 w-[600px]"
    leaveTo="opacity-0 w-0"
    className="overflow-y-auto overflow-x-hidden hidden lg:block lg:fixed lg:left-0 lg:top-0 lg:bottom-0 pl-4 lg:pl-[200px] lg:bg-white/80 dark:lg:bg-gray-900/80 lg:backdrop-blur-xl z-20 lg:h-screen lg:shadow-lg"
  >
    {children}
  </Transition>
);

interface InlineContainerProps {
  show: boolean;
}

const SmallInlineContainer = ({ show, children }: PropsWithChildren<InlineContainerProps>) => (
  <Transition
    show={show}
    enter="transition-all duration-200"
    enterFrom="opacity-0 h-0"
    enterTo="opacity-100"
    leave="transition-all duration-250"
    leaveFrom="opacity-100"
    leaveTo="opacity-0 h-0"
    className="overflow-y-auto overflow-x-hidden h-[400px] lg:hidden pl-4"
  >
    {children}
  </Transition>
);
