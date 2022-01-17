export const getFormattedVariables = (initStateFacts: Record<string, any>) => {
  const formattedVariables = Object.keys(initStateFacts).reduce((acc: any, key: string) => {
    let target = key;
    const lstVars = key.split('|')[1];
    if (lstVars?.length > 1) {
      target = lstVars[1];
    }
    acc[target] = initStateFacts[key];
    return acc;
  }, {});
  return formattedVariables;
};
