export const dragEndHandler = (
  setActiveDragId: React.Dispatch<React.SetStateAction<string | null>>,
) => () => {
  setActiveDragId(null);
};
