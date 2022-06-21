import guid from 'utils/guid';

export interface NameField {
  family: string;
  given: string;
  'dropping-particle'?: string;
  'non-dropping-particle'?: string;
  suffix?: string;
  'comma-suffix'?: string | number | boolean;
  'static-ordering'?: string | number | boolean;
  literal?: string;
  'parse-names'?: string | number | boolean;
}

export interface DateField {
  'date-parts': string[][] | number[][];
  season?: string;
  circa?: string;
  literal?: string;
  raw?: string;
}

export interface CitationModel {
  type: string;
  id: string | number;
  'citation-key'?: string;
  categories?: string[];
  language?: string;
  journalAbbreviation?: string;
  shortTitle?: string;
  author?: NameField[];
  chair?: NameField[];
  'collection-editor'?: NameField[];
  compiler?: NameField[];
  composer?: NameField[];
  'container-author'?: NameField[];
  contributor?: NameField[];
  curator?: NameField[];
  director?: NameField[];
  editor?: NameField[];
  'editorial-director'?: NameField[];
  'executive-producer'?: NameField[];
  guest?: NameField[];
  host?: NameField[];
  interviewer?: NameField[];
  illustrator?: NameField[];
  narrator?: NameField[];
  organizer?: NameField[];
  'original-author'?: NameField[];
  performer?: NameField[];
  producer?: NameField[];
  recipient?: NameField[];
  'reviewed-author'?: NameField[];
  'script-writer'?: NameField[];
  'series-creator'?: NameField[];
  translator?: NameField[];
  accessed?: DateField;
  'available-date'?: DateField;
  'event-date'?: DateField;
  issued?: DateField;
  'original-date'?: DateField;
  submitted?: DateField;
  abstract?: string;
  annote?: string;
  archive?: string;
  archive_collection?: string;
  archive_location?: string;
  'archive-place'?: string;
  authority?: string;
  'call-number'?: string;
  'chapter-number'?: string | number;
  'citation-number'?: string | number;
  'citation-label'?: string;
  'collection-number'?: string | number;
  'collection-title'?: string;
  'container-title'?: string;
  'container-title-short'?: string;
  dimensions?: string;
  division?: string;
  doi?: string;
  event?: string;
  'event-title'?: string;
  'event-place'?: string;
  'first-reference-note-number'?: string | number;
  genre?: string;
  isbn?: string;
  issn?: string;
  issue?: string | number;
  jurisdiction?: string;
  keyword?: string;
  locator?: string | number;
  medium?: string;
  note?: string;
  number?: string | number;
  'number-of-pages'?: string | number;
  'number-of-volumes'?: string | number;
  'original-publisher'?: string;
  'original-publisher-place'?: string;
  'original-title'?: string;
  page?: string;
  'page-first'?: string | number;
  part?: string | number;
  'part-title'?: string;
  pmcid?: string;
  pmid?: string;
  printing?: string | number;
  publisher?: string;
  'publisher-place'?: string;
  references?: string;
  'reviewed-genre'?: string;
  'reviewed-title'?: string;
  scale?: string;
  section?: string;
  source?: string;
  status?: string;
  supplement?: string | number;
  title?: string;
  'title-short'?: string;
  url?: string;
  version?: string;
  volume?: string;
  'volume-title'?: string;
  'volume-title-short'?: string;
  'year-suffix'?: string;
  custom?: any;
}

export const fromEntryType = (entryType: string): CitationModel => {
  let model: CitationModel = {
    id: 'temp_id_' + guid(),
    type: entryType,
    author: [{ given: '', family: '' }],
    title: '',
    issued: { 'date-parts': [[new Date().getFullYear()]] },
    publisher: '',
    version: '',
    shortTitle: '',
    doi: '',
  };

  switch (entryType) {
    case 'article':
    case 'article-journal':
    case 'article-newspaper':
      model = {
        id: 'temp_id_' + guid(),
        type: entryType,
        author: [{ given: '', family: '' }],
        title: '',
        'container-title': '',
        issued: { 'date-parts': [[new Date().getFullYear()]] },
        volume: '',
        number: '',
        page: '',
        note: '',
        doi: '',
        issn: '',
      };
      break;
    case 'book':
      model = {
        id: 'temp_id_' + guid(),
        type: entryType,
        author: [{ given: '', family: '' }],
        editor: [{ given: '', family: '' }],
        title: '',
        publisher: '',
        issued: { 'date-parts': [[new Date().getFullYear()]] },
        volume: '',
        number: '',
        page: '',
        note: '',
        doi: '',
        issn: '',
        isbn: '',
        url: '',
      };
      break;
    default:
      break;
  }
  return model;
};

export function isNameField(val: string): boolean {
  return (
    val === 'author' ||
    val === 'chair' ||
    val === 'collection-editor' ||
    val === 'compiler' ||
    val === 'composer' ||
    val === 'container-author' ||
    val === 'contributor' ||
    val === 'curator' ||
    val === 'director' ||
    val === 'editor' ||
    val === 'editorial-director' ||
    val === 'executive-producer' ||
    val === 'guest' ||
    val === 'host' ||
    val === 'interviewer' ||
    val === 'illustrator' ||
    val === 'narrator' ||
    val === 'organizer' ||
    val === 'original-author' ||
    val === 'performer' ||
    val === 'producer' ||
    val === 'recipient' ||
    val === 'reviewed-author' ||
    val === 'script-writer' ||
    val === 'series-creator' ||
    val === 'translator'
  );
}

export function isDateField(val: string): boolean {
  return (
    val === 'accessed' ||
    val === 'available-date' ||
    val === 'event-date' ||
    val === 'issued' ||
    val === 'original-date' ||
    val === 'submitted'
  );
}
