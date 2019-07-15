#!/bin/bash

# Script to start/terminate AWS F1 instance for fractalvalley.net.

# Usage:
#   Run from this directory as:
#   $0 <command> [<aws-credentials-tfvars-file>]
#       <command>: apply/destroy
#       <aws-credentials-tfvars-file>: relative/absolute path to file containing Terraform variables for AWS credentials. Prompted if omitted.

cd "$( dirname "${BASH_SOURCE[0]}" )"

command="$1"
if [[ "$1" != "apply" && "$1" != "destroy" ]]
then
  echo "Unrecognized command: $command"
  exit 1
fi
if [[ -n "$2" ]]
then
  aws_cred_tfvars=" $2"
else
  aws_cred_tfvars=""
fi

../../../framework/terraform/deployment/run_tf $command "f1$aws_cred_tfvars" 'fractalvalley_f1'