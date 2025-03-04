import React, { useState } from 'react';

interface RespondedUsersListProps {
  users: string[];
}

const INITIAL_MAX_LIST_SIZE = 5;

export const RespondedUsersList = ({ users }: RespondedUsersListProps) => {
  const [showAll, setShowAll] = useState(false);

  // Pull out and aggregate the count of the 'Guest Student' users
  const usersMinusGuests = users.filter((user) => user !== 'Guest Student');
  const guestCount = users.length - usersMinusGuests.length;

  // If there are any 'Guest Student' users, add a line item for them at the top of the list
  const virtualUsers =
    guestCount > 0
      ? [guestCount + ' guest student' + (guestCount == 1 ? '' : 's')].concat(usersMinusGuests)
      : users;

  // Now render the list of users, with a button to show/hide the full list if it's long
  return virtualUsers.length > INITIAL_MAX_LIST_SIZE ? (
    <ul className="list-disc pl-4">
      {virtualUsers
        .slice(0, showAll ? virtualUsers.length : INITIAL_MAX_LIST_SIZE)
        .map((user, index) => (
          <li key={index}>{user}</li>
        ))}
      <button className="mt-3 btn-sm btn btn-secondary" onClick={() => setShowAll(!showAll)}>
        {showAll ? 'Show less' : 'Show all ' + virtualUsers.length}
      </button>
    </ul>
  ) : (
    <ul className="list-disc pl-4">
      {virtualUsers.map((user, index) => (
        <li key={index}>{user}</li>
      ))}
    </ul>
  );
};
