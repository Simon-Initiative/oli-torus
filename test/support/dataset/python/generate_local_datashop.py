#!/usr/bin/env python3
"""
Generate DataShop XML from local xapi_output directory.

Usage:
    python generate_local_datashop.py --section-ids 8,9 --job-id test_001
    python generate_local_datashop.py --section-ids 8 --xapi-dir ./xapi_output --output-dir ./output
"""

import argparse
import sys
import os
from pathlib import Path

# Add the dataset directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from dataset.local_datashop import generate_datashop_from_local

def main():
    parser = argparse.ArgumentParser(description='Generate DataShop XML from local XAPI output')

    parser.add_argument('--section-ids', required=True,
                       help='Comma-separated list of section IDs to process (e.g., "8,9")')
    parser.add_argument('--job-id', required=True,
                       help='Job identifier for output file naming')
    parser.add_argument('--xapi-dir', default='./xapi_output',
                       help='Path to xapi_output directory (default: ./xapi_output)')
    parser.add_argument('--output-dir', default='./',
                       help='Output directory for generated XML (default: ./)')
    parser.add_argument('--chunk-size', type=int, default=50,
                       help='Number of files to process per chunk (default: 50)')
    parser.add_argument('--project-id', type=int,
                       help='Specific project ID to filter (optional)')
    parser.add_argument('--anonymize', action='store_true',
                       help='Anonymize student IDs in output')
    parser.add_argument('--lookup-file',
                       help='Path to lookup JSON file (optional)')
    parser.add_argument('--ignored-students',
                       help='Comma-separated list of student IDs to ignore (optional)')

    args = parser.parse_args()

    # Parse section IDs
    try:
        section_ids = [int(sid.strip()) for sid in args.section_ids.split(',')]
    except ValueError:
        print("Error: section-ids must be comma-separated integers")
        sys.exit(1)

    # Parse ignored students if provided
    ignored_student_ids = []
    if args.ignored_students:
        try:
            ignored_student_ids = [int(sid.strip()) for sid in args.ignored_students.split(',')]
        except ValueError:
            print("Error: ignored-students must be comma-separated integers")
            sys.exit(1)

    # Validate input directory
    if not os.path.exists(args.xapi_dir):
        print(f"Error: XAPI directory does not exist: {args.xapi_dir}")
        sys.exit(1)

    # Build context
    context = {
        "xapi_output_dir": args.xapi_dir,
        "section_ids": section_ids,
        "job_id": args.job_id,
        "chunk_size": args.chunk_size,
        "output_dir": args.output_dir,
        "project_id": args.project_id,
        "ignored_student_ids": ignored_student_ids,
        "anonymize": args.anonymize,
    }

    if args.lookup_file:
        context["lookup_file"] = args.lookup_file

    print("Starting DataShop generation with configuration:")
    print(f"  XAPI Directory: {args.xapi_dir}")
    print(f"  Section IDs: {section_ids}")
    print(f"  Job ID: {args.job_id}")
    print(f"  Output Directory: {args.output_dir}")
    print(f"  Chunk Size: {args.chunk_size}")
    if args.project_id:
        print(f"  Project ID Filter: {args.project_id}")
    if args.anonymize:
        print(f"  Anonymize: Yes")
    if ignored_student_ids:
        print(f"  Ignored Students: {ignored_student_ids}")
    print()

    try:
        output_file = generate_datashop_from_local(context)

        if output_file:
            print(f"\n✅ DataShop generation completed successfully!")
            print(f"📄 Output file: {output_file}")

            # Show file size
            if os.path.exists(output_file):
                file_size = os.path.getsize(output_file)
                print(f"📊 File size: {file_size:,} bytes")
        else:
            print("\n❌ DataShop generation failed - no output file created")
            sys.exit(1)

    except Exception as e:
        print(f"\n❌ Error during DataShop generation: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
