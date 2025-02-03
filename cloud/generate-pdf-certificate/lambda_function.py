import json
import boto3
from weasyprint import HTML
import os

def lambda_handler(event, context):
    try:
        # Ensure the required fields are in the event
        if 'html' not in event or 'certificate_id' not in event:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields: html or certificate_id'})
            }

        # Retrieve HTML and certificate ID from the event
        html_content = event['html']
        certificate_id = event['certificate_id']

        # Define S3 bucket and file path
        bucket_name = os.environ.get('S3_BUCKET')
        if not bucket_name:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'S3_BUCKET environment variable is not set'})
            }
        s3_file_path = f"certificates/{certificate_id}.pdf"

        # Generate PDF from HTML using WeasyPrint
        pdf_file_path = f"/tmp/{certificate_id}.pdf"
        HTML(string=html_content).write_pdf(pdf_file_path)

        # Upload the PDF to S3
        s3 = boto3.client('s3')
        with open(pdf_file_path, 'rb') as pdf_file:
            s3.upload_fileobj(pdf_file, bucket_name, s3_file_path)

        # Cleanup local file
        os.remove(pdf_file_path)

        return {
            'statusCode': 200,
            'body': json.dumps({
                's3Path': f"s3://{bucket_name}/{s3_file_path}"
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
