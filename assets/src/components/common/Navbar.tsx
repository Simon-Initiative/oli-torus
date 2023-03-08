import React, { PropsWithChildren, useState } from 'react';
import { classNames } from 'utils/classNames';
import { UserAccountMenu, User, Routes } from './UserAccountMenu';

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
  browserTimezone: string;
  defaultTimezone: string;
  timezones: [string, string][];
}

export const Navbar = ({
  logo,
  links,
  user,
  preview,
  routes,
  sectionSlug,
  browserTimezone,
  defaultTimezone,
  timezones,
}: NavbarProps) => {
  const [showNavbar, setShowNavbar] = useState(false);

  return (
    <nav className="flex flex-col w-full lg:fixed lg:top-0 lg:left-0 lg:bottom-0 lg:w-[200px] py-2 bg-white dark:bg-gray-900 relative shadow-lg lg:flex select-none z-20">
      <div className="w-full">
        <a className="block w-[200px] lg:mb-14 mx-auto" href={logo.href}>
          <img src={logo.src.light} className="inline-block dark:hidden" alt="logo" />
          <img src={logo.src.dark} className="hidden dark:inline-block" alt="logo dark" />
        </a>

        <button
          className="
            lg:hidden
            text-gray-500
            border-0
            absolute right-2 top-2
            hover:shadow-none hover:no-underline
            py-2
            px-2.5
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
              <NavExpand key={name} name={name} active={active} popout={popout} />
            ) : (
              <NavLink key={name} name={name} active={active} href={href} />
            ),
          )}
        </div>
        <UserAccountMenu
          preview={preview}
          user={user}
          routes={routes}
          sectionSlug={sectionSlug}
          browserTimezone={browserTimezone}
          defaultTimezone={defaultTimezone}
          timezones={timezones}
        />
        <hr className="border-t border-gray-300" />
        <button
          className="
          block
          no-underline
          m-4
          text-delivery-body-color
          font-bold
          hover:no-underline
          border-b
          border-transparent
          hover:text-delivery-primary
          active:text-delivery-primary-600
        "
          data-bs-toggle="modal"
          data-bs-target="#help-modal"
        >
          Tech Support
        </button>
      </div>
    </nav>
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
    className={classNames(
      'block no-underline px-6 py-2 hover:no-underline border-b border-transparent text-current hover:text-delivery-primary-400',
      active && 'font-bold border-b border-delivery-primary !text-delivery-primary',
    )}
  >
    {name}
  </a>
);

interface NavExpandProps {
  name: string;
  active: boolean;
  popout: {
    component: string;
    props: any;
  };
}

const NavExpand = ({ name, popout, active }: PropsWithChildren<NavExpandProps>) => {
  const [show, setShow] = useState(false);

  return (
    <div>
      <div
        className={classNames(
          'block no-underline px-6 py-2 cursor-pointer hover:no-underline border-b border-transparent text-current hover:text-delivery-primary-400',
          active && 'font-bold border-b border-delivery-primary !text-delivery-primary',
        )}
        onClick={() => setShow(!show)}
      >
        <div>{name}</div>
      </div>
      <PopoutContainer show={show}>
        {renderComponent(popout.component, popout.props)}
      </PopoutContainer>
    </div>
  );
};

interface PopoutContainerProps {
  show: boolean;
}

const PopoutContainer = ({ show, children }: PropsWithChildren<PopoutContainerProps>) => (
  <div
    className={`${
      show ? '' : 'hidden'
    } overflow-y-auto lg:fixed lg:left-0 lg:top-0 lg:bottom-0 lg:w-[600px] lg:pl-[200px] lg:bg-white dark:lg:bg-gray-900 lg:z-[-1] h-[400px] lg:h-screen lg:shadow`}
  >
    {children}
  </div>
);
