import React, { PropsWithChildren, useState } from 'react';
import { Popover } from 'react-tiny-popover';
import { CreateAccountPopup } from 'components/messages/CreateAccountPopup';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { classNames } from 'utils/classNames';
import { SelectTimezone } from './SelectTimezone';

enum Roles {
  Independent = 'open_and_free',
  Administrator = 'administrator',
  Instructor = 'instructor',
  Student = 'student',
  SystemAdmin = 'system_admin',
}

export interface Routes {
  signin: string;
  signout: string;
  projects: string;
  linkAccount: string;
  editAccount: string;
  updateTimezone: string;
  openAndFreeIndex: string;
}

export interface User {
  picture?: string;
  name: string;
  role: string;
  roleLabel: string;
  guest: boolean;
  roleColor: string;
  isGuest: boolean;
  isIndependentInstructor: boolean;
  isIndependentLearner: boolean;
  linkedAuthorAccount?: { email: string };
  selectedTimezone?: string;
}

interface UserAccountMenuProps {
  user?: User;
  preview: boolean;
  routes: Routes;
  sectionSlug?: string;
  timezones: [string, string][];
}

export const UserAccountMenu = ({
  preview,
  user,
  routes,
  sectionSlug,
  timezones,
}: UserAccountMenuProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const csrfToken = (document as any)
    .querySelector('meta[name="csrf-token"]')
    .getAttribute('content');

  if (preview) return <PreviewUser />;

  return user ? (
    <Popover
      isOpen={isPopoverOpen}
      onClickOutside={() => setIsPopoverOpen(false)}
      positions={['top', 'bottom', 'left', 'right']}
      containerClassName="flex"
      containerStyle={{ zIndex: '200' }}
      content={
        <Dropdown>
          <>
            {user.guest && (
              <React.Fragment key="signin">
                <DropdownItem>
                  <a href={routes.signin} className="btn">
                    Sign in / Create account
                  </a>
                </DropdownItem>

                <CreateAccountPopup sectionSlug={sectionSlug} />
              </React.Fragment>
            )}
            {(!(user.role === Roles.Student || user.isIndependentLearner) ||
              user.isIndependentInstructor) &&
              (user.linkedAuthorAccount ? (
                <>
                  <DropdownItem>
                    <h6>
                      <b>Linked:</b> {user.linkedAuthorAccount}
                    </h6>
                    <a
                      href={routes.projects}
                      className="py-1 block w-full"
                      rel="noreferrer"
                      target="_blank"
                    >
                      Go to Course Author{' '}
                      <i className="fas fa-external-link-alt float-right mt-[2px]"></i>
                    </a>
                  </DropdownItem>
                  <DropdownItem>
                    <a
                      href={routes.linkAccount}
                      className="py-1 block w-full"
                      rel="noreferrer"
                      target="_blank"
                    >
                      Link a different account
                    </a>
                  </DropdownItem>
                </>
              ) : (
                <DropdownItem>
                  <a
                    href={routes.linkAccount}
                    className="py-1 block w-full"
                    rel="noreferrer"
                    target="_blank"
                  >
                    Link Existing Account
                  </a>
                </DropdownItem>
              ))}
            {user.isIndependentLearner && (
              <>
                <DropdownItem>
                  <a href={routes.editAccount} className="py-1 block w-full">
                    Edit Account
                  </a>
                </DropdownItem>

                <DropdownDivider />
              </>
            )}

            <DropdownItem>
              <div className="py-1">
                Dark Mode
                <DarkModeSelector />
              </div>
            </DropdownItem>

            <DropdownItem>
              <div className="py-1">
                Timezone
                <br />
                <SelectTimezone
                  selectedTimezone={user.selectedTimezone}
                  submitAction={routes.updateTimezone}
                />
              </div>
            </DropdownItem>

            {(user.isIndependentLearner || user.isIndependentInstructor) && (
              <>
                <DropdownDivider />

                <DropdownItem>
                  <a href={routes.openAndFreeIndex} className="py-1 block w-full">
                    My Courses
                  </a>
                </DropdownItem>
              </>
            )}

            <DropdownDivider />

            <DropdownItem>
              <a
                href={routes.signout}
                className={classNames(
                  'py-1 block w-full',
                  // disable sign out if inside an iframe
                  window.location !== window.parent.location ? 'disabled' : '',
                )}
                data-csrf={csrfToken}
                data-method="delete"
                data-to={routes.signout}
              >
                {user.isGuest ? 'Leave course' : 'Sign out'}
              </a>
            </DropdownItem>
          </>
        </Dropdown>
      }
    >
      <button
        className="
          flex flex-row
          px-3
          py-2
          font-medium
          text-sm
          leading-tight
          transition
          duration-150
          ease-in-out
          whitespace-nowrap
          text-left
        "
        onClick={() => setIsPopoverOpen(!isPopoverOpen)}
      >
        <div className="self-center">
          <div className="username">{user.name}</div>
        </div>
        <div className="user-icon ml-4 self-center">
          <UserIcon user={user} />
        </div>
      </button>
    </Popover>
  ) : (
    <></>
  );
};

interface DropdownProps {}

const Dropdown: React.FC<PropsWithChildren<DropdownProps>> = ({ children }) => (
  <ul className="p-2 list-none text-left rounded-lg shadow-lg mt-1 m-0 bg-clip-padding border-none bg-body dark:bg-body-dark min-w-[300px]">
    {children}
  </ul>
);

interface DropdownItemProps {}

const DropdownItem: React.FC<PropsWithChildren<DropdownItemProps>> = ({ children }) => (
  <li className="py-1 px-4 font-normal block w-full whitespace-nowrap bg-transparent">
    {children}
  </li>
);

interface DropdownDividerProps {}

const DropdownDivider: React.FC<PropsWithChildren<DropdownDividerProps>> = (
  _props: DropdownDividerProps,
) => (
  <li className="py-1 px-4 font-normal block w-full whitespace-nowrap bg-transparent">
    <hr className="border-t border-gray-200 dark:border-gray-700 my-1" />
  </li>
);

const PreviewUser = () => (
  <div className="flex flex-row">
    <button
      className="
            px-6
            py-2.5
            font-medium
            text-sm
            leading-tight
            transition
            duration-150
            ease-in-out
            flex
            flex-1
            items-center
            whitespace-nowrap
          "
    >
      <div className="user-icon">
        <UserIcon />
      </div>
      <div className="block lg:inline-block lg:mt-0 text-grey-darkest mx-2">
        <div className="username">Preview</div>
      </div>
    </button>
  </div>
);

interface UserIconProps {
  user?: User;
}

const UserIcon = ({ user }: UserIconProps) => {
  return user && user.picture ? (
    <div className="user-icon">
      <img src={user.picture} className="rounded-full" referrerPolicy="no-referrer" />
    </div>
  ) : (
    <div className="user-icon">
      <div className="user-img rounded-full">
        <i className="fa-solid fa-circle-user fa-2xl mt-[-1px] ml-[-1px] text-gray-600"></i>
      </div>
    </div>
  );
};
