export const group1 = [
  "Bold",
  "Italic",
  "Code",
  "Link (⌘L)",
  "Underline",
  "Strikethrough",
  "Subscript",
  "Double Subscript",
  "Superscript",
  "Term",
  "Deemphasis",
  "Cite",
  "Foreign",
  "Popup Content",
  "Image (Inline)",
  "Formula (Inline)",
  "Callout",
  "Command Button",
] as const;
export const group2 = [
  "Format",
  "List",
  "Bulleted List",
  "Numbered List",
  "Decrease Indent",
  "Increase Indent",
  "Bullet Style",
  "No Bullet",
  "Disc",
  "Circle",
  "Square",
  "No Bullet",
  "Decimal - 1",
  "Zero Decimal - 01",
  "Lower Roman - i",
  "Upper Roman - I",
  "Lower Alpha - a",
  "Upper Alpha - A",
] as const;
export const group3 = ["Heading", "Heading 1", "Heading 2"] as const;
export const group4 = [
  "Insert Table",
  "Insert Image",
  "YouTube",
  "Insert...",
  "Video",
  "Audio Clip",
  "Webpage",
  "Code (Block)",
  "Formula",
  "Figure",
  "Theorem",
  "Callout",
  "Page Link",
  "Description List",
  "Definition",
  "Dialog",
  "Conjugation",
  "Switch to Markdown editor",
  "Change To  Right-to-Left  text direction",
  "Change To  Left-to-Right  text direction",
] as const;
export const group5 = ["Undo", "Redo"] as const;

export type ToolbarTypes =
  | (typeof group1)[number]
  | (typeof group2)[number]
  | (typeof group3)[number]
  | (typeof group4)[number]
  | (typeof group5)[number];
