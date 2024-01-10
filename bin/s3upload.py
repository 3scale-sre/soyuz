#!/usr/bin/python3

import argparse
import boto3
import os
from urllib import parse

aws_default_region = 'us-east-1'


def upload_file_to_s3(file_name, bucket, key, tags):

    # Retrieve AWS credentials and region from environment variables
    aws_access_key_id = os.environ.get('AWS_ACCESS_KEY_ID')
    aws_secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
    aws_region = os.environ.get('AWS_REGION') if os.environ.get(
        'AWS_REGION') != "" else aws_default_region

    # Initialize an S3 client
    s3 = boto3.client(
        's3',
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key,
        region_name=aws_region
    )

    # Upload the file to S3 with tags as metadata
    with open(file_name, 'rb') as file:
        s3.upload_fileobj(
            file,
            bucket,
            key,
            ExtraArgs={'Tagging': parse.urlencode(tags)}
        )
    print(
        f"File '{file_name}' uploaded to S3 bucket '{bucket}' with tags: {tags}")


def parse_tags(tags_arg):
    tags = {}
    for kv in tags_arg:
        try:
            tag = kv.split("=", 1)
            if len(tag) != 2:
                raise TypeError(
                    f"Unable to parse tag '{kv}', format should be key=value.")
            if tag[0] == "":
                raise TypeError(f"Key from '{kv}' is missing.")
        except TypeError as error:
            print(error)
            exit(1)
        tags[tag[0]] = tag[1]
    return tags


if __name__ == "__main__":
    # Create ArgumentParser object
    parser = argparse.ArgumentParser(
        description="Upload a file to S3 with specified tags")

    # Add arguments to the parser
    parser.add_argument("--file", help="A file-like object to upload.",
                        required=True, type=str)
    parser.add_argument("--bucket", help="The name of the bucket to upload to.",
                        required=True, type=str)
    parser.add_argument("--key", help=" The name of the key to upload to.",
                        required=True, type=str)
    parser.add_argument("--tags", help="List of tags for the object metadata. Format: key1=value1 key2=value2 ...",
                        required=False, type=str, action="extend", nargs="+")

    # Parse the arguments
    args = parser.parse_args()

    # Extract the file, bucket, key and tags from the parsed arguments
    file_name = args.file
    bucket = args.bucket
    key = args.key
    tags = parse_tags(args.tags)

    # Upload the file to S3 with the specified tags and bucket name
    upload_file_to_s3(file_name, bucket, key, tags)
