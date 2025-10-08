import os
import json
import glob
import re
from pathlib import Path
import xml.etree.ElementTree as ET

# Global context for tracking state across messages
global_context = {
    'last_good_context_message_id': None
}

def unescape_numeric_entities(xml_str: str) -> str:
    """Restore &#x...; and &#...; sequences that were escaped."""
    return re.sub(r"&amp;(#x[0-9A-Fa-f]+;|#[0-9]+;)", r"&\1", xml_str)

def parse_attempt(value, context):
    """Parse XAPI JSON into a structured part_attempt object."""
    faux_full_context = {'lookup': context, 'anonymize': context.get('anonymize', False)}

    return {
        'timestamp': value["timestamp"],
        'user_id': determine_student_id(faux_full_context, value),
        'section_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"],
        'project_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/project_id"],
        'publication_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/publication_id"],
        'page_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/page_id"],
        'activity_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/activity_id"],
        'activity_revision_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/activity_revision_id"],
        'attached_objectives': value["context"]["extensions"]["http://oli.cmu.edu/extensions/attached_objectives"],
        'page_attempt_guid': value["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"],
        'page_attempt_number': value["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_number"],
        'part_id': value["context"]["extensions"]["http://oli.cmu.edu/extensions/part_id"],
        'part_attempt_guid': value["context"]["extensions"]["http://oli.cmu.edu/extensions/part_attempt_guid"],
        'part_attempt_number': value["context"]["extensions"]["http://oli.cmu.edu/extensions/part_attempt_number"],
        'activity_attempt_number': value["context"]["extensions"]["http://oli.cmu.edu/extensions/activity_attempt_number"],
        'activity_attempt_guid': value["context"]["extensions"]["http://oli.cmu.edu/extensions/activity_attempt_guid"],
        'score': value["result"]["score"]["raw"],
        'out_of': value["result"]["score"]["max"],
        'hints': value["context"]["extensions"]["http://oli.cmu.edu/extensions/hints_requested"],
        'response': value["result"]["response"],
        'feedback': value["result"]["extensions"]["http://oli.cmu.edu/extensions/feedback"],
    }

def determine_student_id(context, value):
    """Determine student ID, with optional anonymization."""
    student_id = value["actor"]["account"]["name"]
    if context.get('anonymize', False):
        # Simple anonymization - could be enhanced
        return f"student_{hash(str(student_id)) % 10000}"
    return str(student_id)

def expand_context(context, part_attempt):
    """Expand context with additional information needed for DataShop XML generation."""
    datashop_session_id = part_attempt.get('datashop_session_id', today(part_attempt))
    problem_name = f"Activity {part_attempt['activity_id']}, Part {part_attempt['part_id']}"

    activity_id = part_attempt['activity_id']
    part_id = part_attempt['part_id']

    activity = context.get('activities', {}).get(str(activity_id), {'parts': {part_id: {'hints': []}}})
    parts = activity.get('parts', {'parts': {}})
    part = parts.get(part_id, {'hints': []})
    hints = part.get('hints', [])

    if not hints or not isinstance(hints, list):
        hints = []

    hint_text = [get_text_from_content(h) for h in hints]
    total_hints_available = len([h for h in hint_text if h])

    expanded = {
        'time': part_attempt['timestamp'],
        'user_id': str(part_attempt['user_id']),
        'session_id': datashop_session_id,
        'datashop_session_id': datashop_session_id,
        'context_message_id': unique_id(part_attempt),
        'activity_slug': str(activity_id),
        'problem_name': problem_name,
        'transaction_id': unique_id(part_attempt),
        'dataset_name': context.get('dataset_name', 'local_dataset'),
        'part_attempt': part_attempt,
        'hierarchy': context.get('hierarchy', {}),
        'activities': context.get('activities', {}),
        'skill_titles': context.get('skill_titles', {}),
        'skill_ids': part_attempt['attached_objectives'],
        'total_hints_available': total_hints_available,
        'time_zone': 'GMT'
    }
    context.update(expanded)
    return context

def unique_id(part_attempt):
    """Generate a unique ID for the part attempt."""
    import random
    import string
    random_suffix = ''.join(random.choice(string.ascii_letters) for i in range(8))
    return f"{part_attempt['activity_id']}-part{part_attempt['part_id']}-{random_suffix}"

def today(part_attempt):
    """Generate a session ID based on date and user ID."""
    timestamp = part_attempt['timestamp']
    date = timestamp.split('T')[0]
    return date + '-' + str(part_attempt['user_id'])

def get_text_from_content(hint):
    """Extract text content from hint structure."""
    if isinstance(hint, dict):
        content = hint.get('content', [])
        if isinstance(content, list) and content:
            return content[0].get('text', 'Unknown hint')
        return hint.get('text', 'Unknown hint')
    return str(hint)

def to_xml_message(j, lookup):
    """
    Convert XAPI attempt_evaluated JSON to DataShop XML message format.
    This matches the original to_xml_message function in datashop.py.
    """
    try:
        # First, parse the XAPI JSON into a part_attempt structure
        part_attempt = parse_attempt(j, lookup)

        # Add activity type information
        part_attempt['activity_type'] = lookup.get('activities', {}).get(str(part_attempt['activity_id']), {'type': 'Unknown'})['type']

        # Expand the context with additional information
        context = expand_context(lookup, part_attempt)

        all_messages = []

        # Add START_PROBLEM context message for first attempts or when no previous context
        if (part_attempt['part_attempt_number'] == 1 and part_attempt['activity_attempt_number'] == 1) or global_context["last_good_context_message_id"] is None:
            c_message = context_message("START_PROBLEM", context)
            all_messages.append(c_message)

        # Create hint message pairs
        hint_message_pairs = create_hint_message_pairs(part_attempt, context)

        # Generate unique transaction ID for attempt/result pairs
        context["transaction_id"] = unique_id(part_attempt)

        # Add all messages: hints + tool message (ATTEMPT) + tutor message (RESULT)
        all_messages = all_messages + hint_message_pairs + [
            tool_message("ATTEMPT", "ATTEMPT", context),
            tutor_message("RESULT", context)
        ]

        # Join all messages and return
        joined = "\n".join(all_messages)
        return unescape_numeric_entities(joined)

    except Exception as e:
        print(f"Error converting XAPI to DataShop XML: {e}")
        import traceback
        traceback.print_exc()
        return None

def create_hint_message_pairs(part_attempt, context):
    """Create hint message pairs for the part attempt."""
    hints = get_hints_for_part(part_attempt, context)
    hint_message_pairs = []

    for hint_index, hint_text in enumerate(hints):
        hint_context = {
            "date": part_attempt["timestamp"],
            "current_hint_number": hint_index + 1,
            "hint_text": hint_text
        }
        hint_context.update(context)

        tool_hint = tool_message("HINT", "HINT_REQUEST", hint_context)
        tutor_hint = tutor_message("HINT_MSG", hint_context)
        hint_message_pairs.extend([tool_hint, tutor_hint])

    return hint_message_pairs

def get_hints_for_part(part_attempt, context):
    """Retrieve hints for the part attempt."""
    hints = part_attempt.get("hints", [])
    part_id = part_attempt.get("part_id")
    activity_id = part_attempt.get("activity_id")

    text = []

    # Create hint map from activities
    activity = context.get("activities", {}).get(str(activity_id), {'parts': {part_id: {'hints': []}}})
    parts = activity.get('parts', {'parts': []})
    if parts is None or not isinstance(parts, dict):
        parts = {}
    part = parts.get(part_id, {'hints': []})
    if part is None or not isinstance(part, dict):
        part = {}
    all_hints = part.get('hints', [])
    if all_hints is None or not isinstance(all_hints, list):
        all_hints = []

    hint_map = {hint.get("id", str(i)): hint for i, hint in enumerate(all_hints)}

    for hint in hints:
        h = hint_map.get(hint, {'content': [{'text': 'Unknown hint'}]})
        text.append(get_text_from_content(h))

    return text

def context_message(name, context):
    """Create a context message XML element."""
    context_id = context.get("context_message_id", "Unknown")
    global_context["last_good_context_message_id"] = context_id

    return f'''<context_message context_message_id="{sanitize_attribute_value(context_id)}" name="{sanitize_attribute_value(name)}">
{meta_xml(context)}
{dataset_xml(context)}
</context_message>'''

def tool_message(event_descriptor_type, semantic_event_type, context):
    """Create a tool message XML element."""
    context_id = global_context.get("last_good_context_message_id", "Unknown")

    return f'''<tool_message context_message_id="{sanitize_attribute_value(context_id)}">
{meta_xml(context)}
{problem_name_xml(context)}
{semantic_event_xml(semantic_event_type, context)}
{event_descriptor_xml(event_descriptor_type, context)}
</tool_message>'''

def tutor_message(message_type, context):
    """Create a tutor message XML element."""
    context_id = global_context.get("last_good_context_message_id", "Unknown")

    tutor_advice_xml = ""
    if message_type == "HINT_MSG":
        tutor_advice_xml = f'<tutor_advice>{sanitize_element_text(context.get("hint_text", "Unknown Hint"))}</tutor_advice>'

    return f'''<tutor_message context_message_id="{sanitize_attribute_value(context_id)}">
{meta_xml(context)}
{problem_name_xml(context)}
{semantic_event_xml(message_type, context)}
{event_descriptor_xml(message_type, context)}
{action_evaluation_xml(context)}
{tutor_advice_xml}
{skills_xml(context)}
</tutor_message>'''

def meta_xml(context):
    """Create meta XML element."""
    return f'''<meta>
<user_id>{sanitize_element_text(context.get("user_id", "Unknown"))}</user_id>
<session_id>{sanitize_element_text(context.get("session_id", "Unknown"))}</session_id>
<time>{sanitize_element_text(format_time(context.get("time")))}</time>
<time_zone>{sanitize_element_text(context.get("time_zone", "GMT"))}</time_zone>
</meta>'''

def dataset_xml(context):
    """Create dataset XML element."""
    dataset_name = context.get("dataset_name", "local_dataset")
    problem_name = context.get("problem_name", "Unknown Problem")

    return f'''<dataset>
<name>{sanitize_element_text(dataset_name)}</name>
<level type="container">
<name>Local Course</name>
<level type="Page">
<name>Local Page</name>
<problem tutorFlag="tutor">
<name>{sanitize_element_text(problem_name)}</name>
</problem>
</level>
</level>
</dataset>'''

def problem_name_xml(context):
    """Create problem name XML element."""
    return f'<problem_name>{sanitize_element_text(context.get("problem_name", "Unknown Problem"))}</problem_name>'

def semantic_event_xml(event_type, context):
    """Create semantic event XML element."""
    transaction_id = context.get("transaction_id", "unknown")
    return f'<semantic_event transaction_id="{sanitize_attribute_value(transaction_id)}" name="{sanitize_attribute_value(event_type)}"/>'

def event_descriptor_xml(event_type, context):
    """Create event descriptor XML element."""
    part_attempt = context.get("part_attempt", {})
    response = part_attempt.get("response", {})
    input_data = response.get("input", "Unknown input")

    return f'''<event_descriptor>
<selection>P1</selection>
<action>UpdateComboBox</action>
<input><![CDATA[{input_data}]]></input>
</event_descriptor>'''

def action_evaluation_xml(context):
    """Create action evaluation XML element."""
    part_attempt = context.get("part_attempt", {})
    score = part_attempt.get("score", 0)
    evaluation = "CORRECT" if score > 0 else "INCORRECT"
    return f'<action_evaluation>{evaluation}</action_evaluation>'

def skills_xml(context):
    """Create skills XML elements."""
    skill_ids = context.get("skill_ids", [])
    skill_titles = context.get("skill_titles", {})

    skills_elements = []
    for skill_id in skill_ids:
        skill_name = skill_titles.get(str(skill_id), f"Skill {skill_id}")
        skills_elements.append(f'<skill><name>{sanitize_element_text(skill_name)}</name></skill>')

    return '\n'.join(skills_elements)

def format_time(time_obj):
    """Format time object to DataShop format."""
    if isinstance(time_obj, str):
        # Convert from '2024-09-02T18:24:33Z' to '2024-09-02 18:24:33'
        return time_obj.replace('T', ' ').replace('Z', '')
    return str(time_obj)

def sanitize_attribute_value(value):
    """Sanitize XML attribute values."""
    if value is None:
        return "Unknown"
    return str(value).replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;')

def sanitize_element_text(text):
    """Sanitize XML element text content."""
    if text is None:
        return "Unknown"
    return str(text).replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;')

def generate_datashop_from_local(context):
    """
    Generate DataShop format from local xapi_output directory instead of S3.

    Args:
        context: Dictionary containing:
            - xapi_output_dir: Path to local xapi_output directory (default: "./xapi_output")
            - section_ids: List of section IDs to process
            - job_id: Job identifier
            - chunk_size: Number of files to process per chunk
            - Other context parameters for lookup and processing
    """

    # Define key parameters
    xapi_output_dir = context.get("xapi_output_dir", "./xapi_output")
    section_ids = context["section_ids"]
    chunk_size = context.get("chunk_size", 100)

    print(f"Processing local XAPI output from: {xapi_output_dir}")
    print(f"Section IDs: {section_ids}")

    # Get file paths for attempt_evaluated and tutor_message categories
    file_paths = list_local_files(xapi_output_dir, section_ids, ["attempt_evaluated", "tutor_message"])

    print(f"Found {len(file_paths)} files to process")

    if len(file_paths) == 0:
        print("No files found to process. Check your xapi_output_dir and section_ids.")
        return None

    # Retrieve the datashop lookup context
    lookup = retrieve_lookup_local(context)
    context['lookup'] = lookup

    # Process files in chunks
    all_part_attempts = []
    total_chunks = (len(file_paths) + chunk_size - 1) // chunk_size

    for chunk_index, chunk_files in enumerate(chunkify(file_paths, chunk_size)):
        try:
            print(f"Processing chunk {chunk_index + 1}/{total_chunks} ({len(chunk_files)} files)")

            # Process each file in the chunk
            for file_path in chunk_files:
                part_attempts = process_local_jsonl_file(file_path, context)
                all_part_attempts.extend(part_attempts)

        except Exception as e:
            print(f"Error processing chunk {chunk_index + 1}: {e}")

    print(f"Total part attempts processed: {len(all_part_attempts)}")

    # Generate output
    return generate_datashop_output(all_part_attempts, context)

def list_local_files(xapi_output_dir, section_ids, categories):
    """
    List all JSONL files in the local xapi_output directory for specified sections and categories.

    Args:
        xapi_output_dir: Base directory path
        section_ids: List of section IDs to include
        categories: List of categories (e.g., ["attempt_evaluated", "tutor_message"])

    Returns:
        List of file paths matching the criteria
    """
    file_paths = []

    for section_id in section_ids:
        for category in categories:
            # Pattern: xapi_output/section/{section_id}/{category}/*.jsonl
            pattern = os.path.join(xapi_output_dir, "section", str(section_id), category, "*.jsonl")
            matching_files = glob.glob(pattern)
            file_paths.extend(matching_files)

            print(f"Section {section_id}, Category {category}: Found {len(matching_files)} files")

    return sorted(file_paths)

def process_local_jsonl_file(file_path, context):
    """
    Process a single local JSONL file and extract DataShop-compatible data.

    Args:
        file_path: Path to the JSONL file
        context: Processing context with lookup tables

    Returns:
        List of processed part attempts
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()

        # Process the content using adapted logic
        return handle_datashop_content(content, context)

    except Exception as e:
        print(f"Error processing file {file_path}: {e}")
        return []

def handle_datashop_content(content, context):
    """
    Process JSONL content and convert to DataShop format.
    Adapted from the original handle_datashop function.
    """
    values = []
    lookup = context['lookup']
    lookup['anonymize'] = context.get('anonymize', False)

    # Reset global context for this file
    global_context['last_good_context_message_id'] = None

    for line in content.splitlines():
        if not line.strip():
            continue

        try:
            # Parse JSON line
            j = json.loads(line)

            student_id = j["actor"]["account"]["name"]
            project_matches = (context.get("project_id") is None or
                             context.get("project_id") == j["context"]["extensions"]["http://oli.cmu.edu/extensions/project_id"])

            if student_id not in context.get("ignored_student_ids", []) and project_matches:
                # Process different types of messages
                obj_type = j["object"]["definition"]["type"]

                if obj_type == "http://adlnet.gov/expapi/activities/question":
                    # Handle attempt_evaluated messages
                    o = to_xml_message(j, lookup)
                    values.append(o)

                elif obj_type == "http://oli.cmu.edu/extensions/tutor_message":
                    # Handle tutor_message messages
                    o = process_tutor_message_local(j, lookup)
                    if o:
                        values.append(o)

        except json.JSONDecodeError as e:
            print(f"Error parsing JSON line: {e}")
            continue
        except Exception as e:
            print(f"Error processing line: {e}")
            continue

    return values

def process_tutor_message_local(j, lookup):
    """
    Process tutor message from local XAPI data.
    Extracts the XML content and replaces the meta element with a generated one.
    """
    try:
        # Extract the message content from the XAPI JSON
        message_content = j["result"]["message"]

        message_root = ET.fromstring(message_content)

        # Create context for generating new meta element
        faux_full_context = {'lookup': lookup, 'anonymize': lookup.get('anonymize', False)}
        user_id = determine_student_id(faux_full_context, j)

        context = {
            'user_id': user_id,
            'session_id': f"{user_id} {j['timestamp'].replace('T', ' ').replace('Z', '')}",
            'time': j['timestamp'],
            'time_zone': 'GMT'
        }

        updated_xml = ""
        for child in message_root:
            # Find and remove existing meta element
            existing_meta = child.find('meta')
            if existing_meta is not None:
                child.remove(existing_meta)

            # Create new meta element using our generator
            new_meta_xml = meta_xml(context)
            new_meta_element = ET.fromstring(new_meta_xml)

            # Insert the new meta element at the beginning
            child.insert(0, new_meta_element)

            updated_xml += ET.tostring(child, encoding='unicode')

        # Clean up any escaped entities
        cleaned_message = unescape_numeric_entities(updated_xml)

        # Add proper indentation for readability
        cleaned_message = "  " + cleaned_message.replace("\n", "\n  ")

        return cleaned_message

    except Exception as e:
        print(f"Error processing tutor message: {e}")
        import traceback
        traceback.print_exc()
        return None

def retrieve_lookup_local(context):
    """
    Retrieve lookup tables for local processing.
    This creates a basic lookup structure or loads from a local file.
    """
    lookup_file = context.get("lookup_file")
    if lookup_file and os.path.exists(lookup_file):
        try:
            with open(lookup_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading lookup file {lookup_file}: {e}")

    # Return a basic lookup structure
    return {
        'problems': {},
        'skills': {},
        'students': {},
        'anonymize': context.get('anonymize', False)
    }

def chunkify(lst, chunk_size):
    """Split a list into chunks of specified size."""
    for i in range(0, len(lst), chunk_size):
        yield lst[i:i + chunk_size]

def generate_datashop_output(all_part_attempts, context):
    """
    Generate the final DataShop XML output.
    """
    job_id = context["job_id"]
    output_dir = context.get("output_dir", "./")
    output_file = os.path.join(output_dir, f"datashop_{job_id}.xml")

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Generate XML content
    xml_content = create_datashop_xml(all_part_attempts, context)

    # Write to local file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_content)

    print(f"DataShop XML generated: {output_file}")
    return output_file

def create_datashop_xml(part_attempts, context):
    """
    Create DataShop XML format from processed part attempts.
    """
    # XML header
    xml_header = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml_header += '<tutor_related_message_sequence version_number="4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://pslcdatashop.org/dtd/tutor_message_v4.xsd">\n'

    # XML footer
    xml_footer = '</tutor_related_message_sequence>\n'

    # Combine all part attempts
    xml_body = '\n'.join(part_attempts)

    return xml_header + xml_body + xml_footer
