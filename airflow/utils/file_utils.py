import os
import zipfile

import requests
import shutil
import boto3

from urllib.parse import urlparse
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

from config.general_config import XTF_OUTPUT_DIR

import logging
# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from config.general_config import XTF_INPUT_DIR, XTF_OUTPUT_DIR


def download_or_copy_xtf(process_id: str, source: str) -> str:
    """
    Downloads or copies a .xtf file to the XTF_INPUT_DIR using the process_id as the filename.

    If `source` is a URL (http/https), the file is downloaded.
    If `source` is a local file path, it is copied.

    Args:
        source (str): URL or local file path of the .xtf file.
        process_id (str): Identifier used to name the destination file.

    Returns:
        str: Full path to the downloaded or copied .xtf file.
    """
    # Ensure output directory exists
    os.makedirs(XTF_INPUT_DIR, exist_ok=True)

    # Set target path
    dest_path = os.path.join(XTF_INPUT_DIR, f"{process_id}.xtf")

    # Validate destination extension
    if not dest_path.endswith('.xtf'):
        raise ValueError("The destination file must have a .xtf extension")

    parsed = urlparse(source)

    if parsed.scheme in ('http', 'https'):
        # It's a remote file, download it
        if not source.lower().endswith('.xtf'):
            raise ValueError("The URL does not point to a .xtf file")
        
        with requests.get(source, stream=True) as r:
            r.raise_for_status()
            with open(dest_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
    else:
        # It's a local file, copy it
        if not os.path.isfile(source):
            raise FileNotFoundError(f"Local file not found: {source}")
        if not source.lower().endswith('.xtf'):
            raise ValueError("The local file does not have a .xtf extension")
        
        shutil.copy2(source, dest_path)

    return dest_path



def upload_file_to_aws_s3(
        file_path: str | os.PathLike,
        folder_name: str | None=None,
        object_name: str | None=None
    ):
    """Upload a file to an S3 bucket

    :param file_path: File to upload
    :param object_name: S3 object name. If not specified then file_name is used
    :param folder_name: Folder in the bucket to upload to. If not specified, the file is uploaded to the root of the bucket
    """

    bucket_name = os.getenv("S3_AWS_BUCKET_NAME")

    s3_client = boto3.client(
        's3',
        region_name=os.getenv("S3_AWS_REGION_NAME"),
        aws_access_key_id=os.getenv("S3_AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("S3_AWS_SECRET_ACCESS_KEY")
    )

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = os.path.basename(file_path)

    try:
        object_name = object_name if folder_name is None else f"{folder_name}/{object_name}"
        s3_client.upload_file(
            file_path,
            bucket_name,
            object_name
        )

        logger.info(f"File {file_path} uploaded to {bucket_name}/{object_name} successfully.")
        return f"{bucket_name}/{object_name}"

    except FileNotFoundError:
        msg = f"The file {file_path} was not found."
        logger.error(msg)
        raise msg

    except NoCredentialsError:
        msg = "Credentials not available."
        logger.error(msg)
        raise msg
    except PartialCredentialsError:
        msg = "Incomplete credentials provided."
        logger.error(msg)
        raise msg
    except Exception as e:
        msg = f"An error occurred: {e}"
        logger.error(msg)
        raise msg

def compress_xtf_file(file_path: str) -> str:
    """
    Compress a plan text file into a ZIP file and store it in OUTPUT_DIR.

    Args:
        file_path (str): Full path to the original plan file (TXT).

    Returns:
        str: Full path to the created ZIP file.
    """
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"The file {file_path} does not exist.")

    if not os.path.exists(XTF_OUTPUT_DIR):
        os.makedirs(XTF_OUTPUT_DIR)

    file_name = os.path.basename(file_path)
    zip_file_name = os.path.splitext(file_name)[0] + ".zip"
    zip_full_path = os.path.join(XTF_OUTPUT_DIR, zip_file_name)

    with zipfile.ZipFile(zip_full_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(file_path, arcname=file_name)

    return zip_full_path
