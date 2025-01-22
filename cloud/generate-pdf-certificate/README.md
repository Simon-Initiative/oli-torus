# AWS Lambda Function: Generate PDF Certificate

This Lambda function generates a PDF certificate from an HTML payload using WeasyPrint and uploads it to an S3 bucket. The resulting certificate can then be accessed via a public URL.

---

## How It Works

1. **Input**: The function takes an HTML string and a `certificate_id` as input.
2. **PDF Generation**: It uses the [WeasyPrint](https://weasyprint.org/) library to convert the HTML into a PDF.
3. **S3 Upload**: The generated PDF is uploaded to a specified S3 bucket using the `certificate_id` as part of the file path.
4. **Public URL**: The uploaded PDF is accessible via a URL based on the S3 bucket configuration.

---

## Setup Instructions

1. **Deploy the Lambda Function**:
   - Create a new Lambda function in the AWS Management Console.
   - Copy the provided Python code into the function.

2. **Set Environment Variables**:
   - Configure the following environment variables in the Lambda console under the "Configuration" tab:
     - `FONTCONFIG_PATH`: `/opt/fonts`
     - `GDK_PIXBUF_MODULE_FILE`: `/opt/lib/loaders.cache`
     - `XDG_DATA_DIRS`: `/opt/lib`
     - `S3_BUCKET`: `torus-pdf-certificates` (or your specific bucket name)

3. **Add a Layer for WeasyPrint**:
   - Use the [WeasyPrint lambda layer](https://github.com/kotify/cloud-print-utils).
   - Attach the layer to your Lambda function.

4. **IAM Role Permissions**:
   - Ensure the Lambda execution role has the necessary permissions to upload files to S3:

---

## Environment Variables

| Variable Name          | Description                            | Example Value           |
|------------------------|----------------------------------------|-------------------------|
| `FONTCONFIG_PATH`      | Path to font configurations           | `/opt/fonts`           |
| `GDK_PIXBUF_MODULE_FILE` | Path to GDK Pixbuf loaders cache     | `/opt/lib/loaders.cache` |
| `S3_BUCKET`            | Name of the S3 bucket to upload PDFs  | `torus-pdf-certificates` |
| `XDG_DATA_DIRS`        | Additional library paths              | `/opt/lib`             |

---

## Input Payload Example

The function expects a JSON payload with the following structure:

```json
{
  "html": "<!doctype html><meta charset=utf-8><h1>Hello Certificate</h1>",
  "certificate_id": "00000000-0000-0000-0000-000000000000"
}
```

## S3 Path Format

The PDF is uploaded to the following path in the specified S3 bucket:

```
s3://{S3_BUCKET}/certificates/{certificate_id}.pdf
```

For example, given `S3_BUCKET=torus-pdf-certificates` and `certificate_id=00000000-0000-0000-0000-000000000000`, the PDF URL would be:

```
https://torus-pdf-certificates.s3.amazonaws.com/certificates/00000000-0000-0000-0000-000000000000.pdf
```

---

## Error Handling

The function returns the following HTTP status codes:

- **200**: Success. Returns the S3 path of the uploaded PDF.
- **400**: Bad Request. Missing required fields (`html` or `certificate_id`).
- **500**: Internal Server Error. Indicates issues like:
  - Environment variables not set.
  - PDF generation failure.
  - S3 upload failure.

### Example Error Responses:

#### Missing Required Fields
```json
{
  "statusCode": 400,
  "body": "{\"error\": \"Missing required fields: html or certificate_id\"}"
}
```

#### S3 Bucket Environment Variable Not Set
```json
{
  "statusCode": 500,
  "body": "{\"error\": \"S3_BUCKET environment variable is not set\"}"
}
```

#### Unexpected Error
```json
{
  "statusCode": 500,
  "body": "{\"error\": \"An unexpected error occurred\"}"
}
```

---

## Testing the Function

### Trigger the Function

1. **AWS Lambda Console**:
   - Navigate to the Lambda function in the AWS Console.
   - Use the "Test" button to invoke the function.

2. **Input Payload Example**:

```json
{
  "html": "<!doctype html><meta charset=utf-8><h1>Hello Certificate</h1>",
  "certificate_id": "00000000-0000-0000-0000-000000000000"
}
```

### Verify the Output

- Check the response for the S3 path.
- Use the returned URL to access the PDF in the browser or via an HTTP client.

---

## Notes

1. **Public Access to PDFs**:
   - Ensure the S3 bucket policy allows public read access to the uploaded PDFs if required.

2. **Base64 Inline Images**:
   - To embed images in the HTML, encode them in Base64 format and include them directly in the `<img>` tags.

```html
<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA...">
```

3. **Temporary Storage**:
   - The Lambda function stores the generated PDF in the `/tmp` directory, which is cleared after execution.

4. **Performance**:
   - The Lambda function typically executes within 5000ms.
   - It requires less than 128MB of memory to run effectively.
