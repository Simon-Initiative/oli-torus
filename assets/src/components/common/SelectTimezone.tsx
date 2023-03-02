import React, { useRef } from 'react';

interface SelectTimezoneProps {
  timezones: [string, string][];
  browserTimezone: string;
  selectedTimezone?: string;
  submitAction: string;
}

export const SelectTimezone: React.FC<SelectTimezoneProps> = ({
  timezones,
  browserTimezone,
  selectedTimezone,
  submitAction,
}) => {
  const ref = useRef<HTMLFormElement>(null);
  const onSelect = ({ target: { value } }: any) => {
    console.log(value);
    ref.current?.submit();
  };

  const csrfToken = (document as any)
    .querySelector('meta[name="csrf-token"]')
    .getAttribute('content');
  const relativePath = window.location.pathname + window.location.search;

  return (
    <form ref={ref} action={submitAction} method="post">
      <input type="hidden" name="_csrf_token" value={csrfToken} />
      <input
        id="hidden-redirect-to"
        name="timezone[redirect_to]"
        type="hidden"
        value={relativePath}
      />
      <select
        onChange={onSelect}
        name="timezone[timezone]"
        className="max-w-[300px] border-gray-300 rounded-md w-full disabled:bg-gray-100 disabled:text-gray-600 dark:bg-delivery-body-dark dark:border-gray-700"
      >
        {selectedTimezone !== browserTimezone && (
          <option key="browser" value={browserTimezone}>
            Browser Timezone - {browserTimezone}
          </option>
        )}
        {timezones.map(([label, value]) => (
          <option key={value} value={value} selected={value === selectedTimezone}>
            {label}
          </option>
        ))}
      </select>
    </form>
  );
};
