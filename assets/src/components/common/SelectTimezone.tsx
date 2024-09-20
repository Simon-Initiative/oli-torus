import React, { useEffect, useRef, useState } from 'react';

interface SelectTimezoneProps {
  selectedTimezone?: string;
  submitAction: string;
}

export const SelectTimezone: React.FC<SelectTimezoneProps> = ({
  selectedTimezone,
  submitAction,
}) => {
  const ref = useRef<HTMLFormElement>(null);
  const onSelect = ({ target: { value }, isTrusted, nativeEvent }: any) => {
    // Only submit the form if the change event was triggered by a user action to
    // prevent this from being triggered by the browser's autofill feature or
    // any react re-renders.
    if (!isTrusted || !nativeEvent) return;
    ref.current?.submit();
  };

  const [timezones, setTimezones] = useState<[string, string][]>();

  useEffect(() => {
    fetch('/timezones')
      .then((response) => response.json())
      .then((data) => {
        const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const timezoneOptions = [
          [`Browser Default (${browserTimezone})`, 'browser'],
          ...data.timezones,
        ];

        setTimezones(timezoneOptions);
      });
  }, []);

  const csrfToken = (document as any)
    .querySelector('meta[name="csrf-token"]')
    .getAttribute('content');
  const relativePath = window.location.pathname + window.location.search;

  return timezones ? (
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
        className="max-w-[300px] dark:text-white text-sm font-normal font-['Roboto'] rounded-md border-gray-300 w-full disabled:bg-gray-100 disabled:text-gray-600 dark:bg-delivery-body-dark dark:border-gray-700"
        value={selectedTimezone}
      >
        {timezones.map(([label, value]) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
    </form>
  ) : (
    <>
      <div className="relative isolate overflow-hidden rounded-2xl before:absolute before:inset-0 before:-translate-x-full before:animate-[shimmer_2s_infinite] before:bg-gradient-to-r before:from-transparent before:via-gray-500/10 before:to-transparent">
        <div className="h-3 rounded-full bg-gray-200/25 dark:bg-gray-700/25 w-48"></div>
      </div>
    </>
  );
};
