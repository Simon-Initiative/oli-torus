type PlainObject = {
  [key: string]: string | PlainObject | string[];
};

function formDataToObject(formData: FormData): PlainObject {
  const obj: PlainObject = {};
  for (const [key, value] of (formData as any).entries()) {
    const keys = key.split(/[\[\]]/).filter((k: string) => k); //eslint-disable-line
    keys.reduce((acc: PlainObject, key: string, index: number) => {
      if (index === keys.length - 1) {
        acc[key] =
          acc[key] && Array.isArray(acc[key])
            ? [...(acc[key] as any), value]
            : acc[key]
            ? [acc[key], value]
            : value;
      } else if (!acc[key]) {
        acc[key] = {};
      }
      return acc[key];
    }, obj);
  }
  return obj;
}

/**
 * This hook is used to get the data from a form and return it to the server.
 * @form_id - The id of the form to get the data from.
 * @target_id - The id of the LiveView to send the data to.
 * @params - Other params that are received from the server and will be sent back to the server.
 */
export const SubmitForm = {
  mounted() {
    this.handleEvent(
      'js_form_data_request',
      ({ form_id, target_id, ...params }: { [key: string]: any }) => {
        const formData = new FormData(document.getElementById(form_id) as HTMLFormElement);
        const payload = formDataToObject(formData);

        this.pushEventTo(`#${target_id}`, 'js_form_data_response', { ...payload, ...params });
      },
    );
  },
};
