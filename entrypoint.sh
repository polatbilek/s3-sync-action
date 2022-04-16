#!/bin/sh

set -e

if [ -z "$AWS_S3_BUCKET" ]; then
  echo "AWS_S3_BUCKET is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
fi

# Default to us-east-1 if AWS_REGION not set.
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi


# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
# https://github.com/jakejarvis/s3-sync-action/issues/1
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

sh -c "zip -rq ./${PROJECT_NAME}.zip ./${PROJECT_NAME}/"
sh -c "aws s3 cp ./${PROJECT_NAME}.zip s3://${AWS_S3_BUCKET}/${DEST_DIR} --profile s3-sync-action --no-progress"

reqcontains="$(aws s3api list-objects-v2 --bucket ${AWS_REQUIREMENTS_BUCKET} --query "contains(Contents[].Key, 'requirements.txt')")"


echo $reqcontains

# Deploy Requirements package if needed
if [[ $reqcontains =~ "true" ]]; then
  echo "inside"


  sh -c "mv requirements.txt orig_req.txt"
  echo "1"
  sh -c "aws s3 cp s3://${AWS_REQUIREMENTS_BUCKET}/requirements.txt . --profile s3-sync-action --no-progress"
  echo "2"
  echo "$(ls -a)"
  echo "2.2"
  echo "$(diff -q orig_req.txt requirements.txt)"
  echo "2.5"
  getdiff="$(diff -q orig_req.txt requirements.txt)"
  echo "3"

  if [ -f ./requirements.txt ]; then
    if [ -n "$getdiff" ]; then
      sh -c "pip install -r orig_req.txt --target ./python"
      sh -c "rm -rf ./python/*.dist-info"
      sh -c "zip -rq ./python.zip ./python/"
      sh -c "rm -rf ./python"
      sh -c "aws s3 cp ./python.zip s3://$(PROJECT_NAME)-requirements --profile s3-sync-action --no-progress"
      sh -c "rm -rf ./python.zip"
      sh -c "rm -rf requirements.txt"
      sh -c "mv orig_req.txt requirements.txt"
      sh -c "aws s3 cp ./requirements.txt s3://${AWS_REQUIREMENTS_BUCKET}/requirements.txt --profile s3-sync-action --no-progress"
      echo "Deployed requirements"
      else
        echo "diff yok"
    fi
    else
      echo "dosya yok"
  fi

  else
    echo "outside"
fi


# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
null
null
null
text
EOF
