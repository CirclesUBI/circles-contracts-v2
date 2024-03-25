#!/bin/bash

# Function to deploy contract and store deployment details
deploy_and_store_details() {
  local contract_name=$1
  local precalculated_address=$2
  local deployment_output
  local deployed_address

  echo "" >&2
  echo "Deploying ${contract_name}..." >&2
  deployment_output=$(forge create \
    --rpc-url ${RPC_URL} \
    --private-key ${PRIVATE_KEY} \
    --optimizer-runs 200 \
    --chain-id 10200 \
    "${@:3}") # Passes all arguments beyond the second to forge create

  deployed_address=$(echo "$deployment_output" | grep "Deployed to:" | awk '{print $3}')
  echo "${contract_name} deployed at ${deployed_address}" >&2

  # Verify that the deployed address matches the precalculated address
  if [ "$deployed_address" = "$precalculated_address" ]; then
    echo "Verification Successful: Deployed address matches the precalculated address for ${contract_name}." >&2
  else
    echo "Verification Failed: Deployed address does not match the precalculated address for ${contract_name}." >&2
    echo "Precalculated Address: $precalculated_address" >&2
    echo "Deployed Address: $deployed_address" >&2
    # exit the script if the addresses don't match
    exit 1
  fi

  # Define the filename for constructor arguments based on the contract name
  arguments_file="constructorArgs_${contract_name}.txt"
  arguments_path="${OUT_DIR}/${arguments_file}"
  # Save constructor arguments to the file, skip "--constructor-args"
  echo "${@:5}" > "${arguments_path}"

  # Store deployment details in a file
  echo "{\"contractName\":\"${contract_name}\",\"deployedAddress\":\"${deployed_address}\",\"sourcePath\":\"$2\",\"constructor-args\":\"${@:4}\",\"argumentsFile\":\"${arguments_file}\"}" >> "${deployment_details_file}"

  # return the deployed address
  echo "$deployed_address"
}

# Function to generate a compact and short identifier
generate_identifier() {
    # Fetch the current Git commit hash and take the first 7 characters
    local git_commit_short=$(git rev-parse HEAD | cut -c1-7)

    # Get the current date and time in a compact format (YYMMDD-HMS)
    local deployment_date=$1

    # Fetch version from package.json
    local version=$(node -p "require('./package.json').version")

    # Define the summary file name with version, short git commit, and compact date
    echo "${version}-${git_commit_short}-${deployment_date}"
}

# Set the environment variables, also for use in node script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/../../.env"

# declare Chiado constants
V1_HUB_ADDRESS='0xdbF22D4e8962Db3b2F1d9Ff55be728A887e47710'
# chiado v1 deployment time is 1675244965 unix time, 
# or 9:49:25 am UTC  |  Wednesday, February 1, 2023
# but like on mainnet we want to offset this to midnight to start day zero 
# on the Feb 1 2023, which has unix time 1675209600
INFLATION_DAY_ZERO=1675209600
# put a long bootstrap time for testing bootstrap 
BOOTSTRAP_ONE_YEAR=31540000
# fallback URI 
URI='https://fallback.aboutcircles.com/v1/circles/{id}.json'

# re-export the variables for use here and in the general calculation JS script
export PRIVATE_KEY=$PRIVATE_KEY_CHIADO
export RPC_URL=$RPC_URL_CHIADO
VERIFIER_URL=$BLOCKSCOUT_URL_CHIADO
VERIFIER_API_KEY=$BLOCKSCOUT_API_KEY
VERIFIER=$BLOCKSCOUT_VERIFIER

# Get the current date and time in a compact format (YYMMDD-HMS) outside the functions
deployment_date=$(date "+%y%m%d-%H%M%S")
deployment_date_long=$(date "+%Y-%m-%d %H:%M:%S")
identifier=$(generate_identifier $deployment_date)

# Run the Node.js script to predict contract addresses
# Assuming predictAddresses.js is in the current directory
read DEPLOYER_ADDRESS NONCE_USED HUB_ADDRESS_01 MIGRATION_ADDRESS_02 NAMEREGISTRY_ADDRESS_03 \
ERC20LIFT_ADDRESS_04 STANDARD_TREASURY_ADDRESS_05 BASE_GROUPMINTPOLICY_ADDRESS_06 \
MASTERCOPY_DEMURRAGE_ERC20_ADDRESS_07 MASTERCOPY_INFLATIONARY_ERC20_ADDRESS_08 \
MASTERCOPY_STANDARD_VAULT_09 \
<<< $(node predictDeploymentAddresses.js)

# Create a directory for the deployment and go there after calling node script
mkdir -p "$DIR/chiado-$identifier"
OUT_DIR="$DIR/chiado-$identifier"

# Use DEPLOYER_ADDRESS and NONCE_USED as needed
echo "Deployer Address: $DEPLOYER_ADDRESS, Nonce Used: $NONCE_USED"

# Log the predicted deployment addresses
echo "Predicted deployment addresses:"
echo "==============================="
echo "Hub: ${HUB_ADDRESS_01}"
echo "Migration: ${MIGRATION_ADDRESS_02}"
echo "NameRegistry: ${NAMEREGISTRY_ADDRESS_03}"
echo "ERC20Lift: ${ERC20LIFT_ADDRESS_04}"
echo "StandardTreasury: ${STANDARD_TREASURY_ADDRESS_05}"
echo "BaseGroupMintPolicy: ${BASE_GROUPMINTPOLICY_ADDRESS_06}"
echo "MastercopyDemurrageERC20: ${MASTERCOPY_DEMURRAGE_ERC20_ADDRESS_07}"
echo "MastercopyInflationaryERC20: ${MASTERCOPY_INFLATIONARY_ERC20_ADDRESS_08}"
echo "MastercopyStandardVault: ${MASTERCOPY_STANDARD_VAULT_09}"

Deploy the contracts

export deployment_details_file="${OUT_DIR}/chiado-artefacts-${identifier}.json"
echo "Deployment details will be stored in $deployment_details_file"

echo ""
echo "Starting deployment..."
echo "======================"

HUB=$(deploy_and_store_details "Hub" $HUB_ADDRESS_01 \
  src/hub/Hub.sol:Hub \
  --constructor-args $V1_HUB_ADDRESS \
  $NAMEREGISTRY_ADDRESS_03 $MIGRATION_ADDRESS_02 $ERC20LIFT_ADDRESS_04 \
  $STANDARD_TREASURY_ADDRESS_05 $INFLATION_DAY_ZERO \
  $BOOTSTRAP_ONE_YEAR $URI)

MIGRATION=$(deploy_and_store_details "Migration" $MIGRATION_ADDRESS_02 \
  src/migration/Migration.sol:Migration \
  --constructor-args $V1_HUB_ADDRESS $HUB_ADDRESS_01)

NAME_REGISTRY=$(deploy_and_store_details "NameRegistry" $NAMEREGISTRY_ADDRESS_03 \
  src/names/NameRegistry.sol:NameRegistry \
  --constructor-args $HUB_ADDRESS_01)

ERC20LIFT=$(deploy_and_store_details "ERC20Lift" $ERC20LIFT_ADDRESS_04 \
  src/lift/ERC20Lift.sol:ERC20Lift \
  --constructor-args $HUB_ADDRESS_01 \
  $NAMEREGISTRY_ADDRESS_03 $MASTERCOPY_DEMURRAGE_ERC20_ADDRESS_07 \
  $MASTERCOPY_INFLATIONARY_ERC20_ADDRESS_08)

STANDARD_TREASURY=$(deploy_and_store_details "StandardTreasury" $STANDARD_TREASURY_ADDRESS_05 \
  src/treasury/StandardTreasury.sol:StandardTreasury \
  --constructor-args $HUB_ADDRESS_01 $MASTERCOPY_STANDARD_VAULT_09)

BASE_MINTPOLICY=$(deploy_and_store_details "BaseGroupMintPolicy" $BASE_GROUPMINTPOLICY_ADDRESS_06 \
  src/groups/BaseMintPolicy.sol:MintPolicy)

MC_ERC20_DEMURRAGE=$(deploy_and_store_details "MastercopyDemurrageERC20" $MASTERCOPY_DEMURRAGE_ERC20_ADDRESS_07 \
  src/lift/DemurrageCircles.sol:DemurrageCircles)

MC_ERC20_INFLATION=$(deploy_and_store_details "MastercopyInflationaryERC20" $MASTERCOPY_INFLATIONARY_ERC20_ADDRESS_08 \
  src/lift/InflationaryCircles.sol:InflationaryCircles)

MC_STANDARD_VAULT=$(deploy_and_store_details "MastercopyStandardVault" $MASTERCOPY_STANDARD_VAULT_09 \
  src/treasury/StandardVault.sol:StandardVault)

# log to file

# Use the function to generate the file name
summary_file="${OUT_DIR}/chiado-${identifier}.log"

# Now you can use $summary_file for logging
{
    echo "Chiado deployment"
    echo "================="
    echo "Deployment Date: $deployment_date_long"
    echo "Version: $(node -p "require('./package.json').version")"
    echo "Git Commit: $(git rev-parse HEAD)"
    echo "Deployer Address: $DEPLOYER_ADDRESS"
    echo "Deployer Nonce: $NONCE_USED"
    echo ""
    echo "Deployed Contracts:"
    echo "Hub: ${HUB}"
    echo "Migration: ${MIGRATION}"
    echo "NameRegistry: ${NAME_REGISTRY}"
    echo "ERC20Lift: ${ERC20LIFT}"
    echo "StandardTreasury: ${STANDARD_TREASURY}"
    echo "BaseGroupMintPolicy: ${BASE_MINTPOLICY}"
    echo "MastercopyDemurrageERC20: ${MC_ERC20_DEMURRAGE}"
    echo "MastercopyInflationaryERC20: ${MC_ERC20_INFLATION}"
    echo "MastercopyStandardVault: ${MC_STANDARD_VAULT}"
} >> "$summary_file"
