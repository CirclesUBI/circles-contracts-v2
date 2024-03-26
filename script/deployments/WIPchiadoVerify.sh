#!/bin/bash

# note 26 march 2024: this does not work yet, the compiler version gets rejected

# Script to verify deployed contracts on a block explorer

# Function to verify contract on Block Explorer
verify_contract() {
  local contractName=$1
  local deployedAddress=$2
  local sourcePath=$3
  local constructorArgsFile=$4
  local compilerVersion=$5

  echo "Verifying ${contractName} at ${deployedAddress} with source ${sourcePath}"

  # Perform verification using forge with constructor args from file
  forge verify-contract --flatten --watch --compiler-version "${compilerVersion}" \
    --constructor-args-path "${constructorArgsFile}" \
    --chain-id 10200 \
    --verifier-url $VERIFIER_URL \
    --verifier $VERIFIER \
    --etherscan-api-key ${VERIFIER_API_KEY} \
    --delay 10 \
    "${deployedAddress}" "${sourcePath}"

  echo "Verification command for ${contractName} executed."
}

# Set the environment variables, also for use in node script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/../../.env"

# The identifier containing deployment details
DEPLOYMENT_IDENTIFIER=$1
# The file containing deployment details
ARTEFACTS_FILE="${DEPLOYMENT_IDENTIFIER}/${DEPLOYMENT_IDENTIFIER}.txt"
PATH_CONSTRUCTOR_ARGS="${DEPLOYMENT_IDENTIFIER}"

echo "Using artefacts file: ${ARTEFACTS_FILE}"

# taking parameters from .env file for Chiado
VERIFIER_URL=$BLOCKSCOUT_URL_CHIADO
VERIFIER_API_KEY=$BLOCKSCOUT_API_KEY
VERIFIER=$BLOCKSCOUT_VERIFIER
COMPILER_VERSION="v0.8.23+commit.f704f362"

# Assuming jq is installed for JSON parsing
# Reading the JSON file and extracting required information
while IFS= read -r line; do
  contractName=$(echo "$line" | jq -r '.contractName')
  deployedAddress=$(echo "$line" | jq -r '.deployedAddress')
  sourcePath=$(echo "$line" | jq -r '.sourcePath')
  argumentsFile="${PATH_CONSTRUCTOR_ARGS}/$(echo "$line" | jq -r '.argumentsFile')"
  compilerVersion=${COMPILER_VERSION}

  # Construct the full path to the constructor args file
  constructorArgsFile="${DIR}/${argumentsFile}"

  verify_contract "$contractName" "$deployedAddress" "$sourcePath" "$constructorArgsFile" "$compilerVersion"
done < "${ARTEFACTS_FILE}"

echo "All contracts submitted for verification."


# deploy_and_verify() {
#   local contract_name=$1
#   local precalculated_address=$2
#   local deployment_output
#   local deployed_address

#   echo "" >&2
#   echo "Deploying ${contract_name}..." >&2
#   deployment_output=$(forge create \
#     --rpc-url ${RPC_URL} \
#     --private-key ${PRIVATE_KEY} \
#     --optimizer-runs 200 \
#     --chain-id 10200 \
#     --verify \
#     --verifier-url $VERIFIER_URL \
#     --verifier $VERIFIER \
#     --etherscan-api-key ${VERIFIER_API_KEY} \
#     --delay 20 \
#     "${@:3}") # Passes all arguments beyond the second to forge create

#   deployed_address=$(echo "$deployment_output" | grep "Deployed to:" | awk '{print $3}')
#   echo "${contract_name} deployed at ${deployed_address}" >&2

#   # Verify that the deployed address matches the precalculated address
#   if [ "$deployed_address" = "$precalculated_address" ]; then
#     echo "Verification Successful: Deployed address matches the precalculated address for ${contract_name}." >&2
#   else
#     echo "Verification Failed: Deployed address does not match the precalculated address for ${contract_name}." >&2
#     echo "Precalculated Address: $precalculated_address" >&2
#     echo "Deployed Address: $deployed_address" >&2
#     # exit the script if the addresses don't match
#     exit 1
#   fi

#   echo "sleeping for 10 seconds to allow verifier to verify" >&2
#   sleep 10

#   echo "$deployed_address"
# }