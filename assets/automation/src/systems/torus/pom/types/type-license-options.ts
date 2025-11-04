export const TYPE_LICENSE_OPTIONS = {
  none: { value: 'none', visible: 'Non-CC / Copyrighted / Other' },
  custom: { value: 'custom', visible: 'Custom' },
  cc_by: { value: 'cc_by', visible: 'CC BY: Attribution' },
  cc_by_sa: { value: 'cc_by_sa', visible: 'CC BY-SA: Attribution-ShareAlike' },
  cc_by_nd: { value: 'cc_by_nd', visible: 'CC BY-ND: Attribution-NoDerivatives' },
  cc_by_nc: { value: 'cc_by_nc', visible: 'CC BY-NC: Attribution-NonCommercial' },
  cc_by_nc_sa: {
    value: 'cc_by_nc_sa',
    visible: 'CC BY-NC-SA: Attribution-NonCommercial-ShareAlike',
  },
  cc_by_nc_nd: {
    value: 'cc_by_nc_nd',
    visible: 'CC BY-NC-ND: Attribution-NonCommercial-NoDerivatives',
  },
} as const;

export type TypeLicenseOption = keyof typeof TYPE_LICENSE_OPTIONS;
