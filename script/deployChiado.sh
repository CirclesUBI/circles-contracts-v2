#!/bin/bash

# Set the environment variables, also for use in node script
export PRIVATE_KEY=$1
export RPC_URL=https://rpc.chiado.gnosis.gateway.fm

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


# Run the Node.js script to predict contract addresses
# Assuming predictAddresses.js is in the current directory
read HUB_ADDRESS_01 MIGRATION_ADDRESS_02 NAMEREGISTRY_ADDRESS_03 \
ERC20LIFT_ADDRESS_04 STANDARD_TREASURY_ADDRESS_05 BASE_GROUPMINTPOLICY_ADDRESS_06 \
<<< $(node predictDeploymentAddresses.js)

# Log the predicted deployment addresses
echo "Predicted deployment addresses:"
echo "==============================="
echo "Hub: ${HUB_ADDRESS_01}"
echo "Migration: ${MIGRATION_ADDRESS_02}"
echo "NameRegistry: ${NAMEREGISTRY_ADDRESS_03}"
echo "ERC20Lift: ${ERC20LIFT_ADDRESS_04}"
echo "StandardTreasury: ${STANDARD_TREASURY_ADDRESS_05}"
echo "BaseGroupMintPolicy: ${BASE_GROUPMINTPOLICY_ADDRESS_06}"

# Deploy the contracts

echo "Deploying ERC1155 Hub..."
MULTITOKEN_HUB=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/hub/Hub.sol:Hub \
  --constructor-args ${V1_HUB_ADDRESS} ${NAMEREGISTRY_ADDRESS_03} \
  ${MIGRATION_ADDRESS_02} ${ERC20LIFT_ADDRESS_04} \
  ${STANDARD_TREASURY_ADDRESS_05} ${INFLATION_DAY_ZERO} \
  ${BOOTSTRAP_ONE_YEAR} ${URI} 
  
echo ""
echo "Summary:"
echo "========"
echo "Hub: ${HUB_ADDRESS_01}"
  
# echo "Deploying MintSplitter..."
# MINT_SPLITTER_DEPLOYMENT=$(forge create \
#   --rpc-url ${RPC_URL} \
#   --private-key ${PRIVATE_KEY} \
#   src/mint/MintSplitter.sol:MintSplitter \
#   --constructor-args ${V1_HUB_ADDRESS})

# MINT_SPLITTER_ADDRESS=$(echo "$MINT_SPLITTER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
# echo "MintSplitter deployed at ${MINT_SPLITTER_ADDRESS}"

# echo "Deploying TimeCircle..."
# TIME_CIRCLE_DEPLOYMENT=$(forge create \
#   --rpc-url ${RPC_URL} \
#   --private-key ${PRIVATE_KEY} \
#   src/circles/TimeCircle.sol:TimeCircle)

# TIME_CIRCLE_ADDRESS=$(echo "$TIME_CIRCLE_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
# echo "TimeCircle deployed at ${TIME_CIRCLE_ADDRESS}"

# echo "Deploying GroupCircle..."
# GROUP_CIRCLES_DEPLOYMENT=$(forge create \
#   --rpc-url ${RPC_URL} \
#   --private-key ${PRIVATE_KEY} \
#   src/circles/GroupCircle.sol:GroupCircle)

# GROUP_CIRCLES_ADDRESS=$(echo "$GROUP_CIRCLES_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
# echo "GroupCircle deployed at ${GROUP_CIRCLES_ADDRESS}"

# echo "Deploying Graph..."
# GRAPH_DEPLOYMENT=$(forge create \
#   --rpc-url ${RPC_URL} \
#   --private-key ${PRIVATE_KEY} \
#   src/graph/Graph.sol:Graph \
#   --constructor-args ${MINT_SPLITTER_ADDRESS} '0x0000000000000000000000000000000000000000' ${TIME_CIRCLE_ADDRESS} ${GROUP_CIRCLES_ADDRESS})

# GRAPH_ADDRESS=$(echo "$GRAPH_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
# echo "Graph deployed at ${GRAPH_ADDRESS}"

# echo ""
# echo "Summary:"
# echo "========"
# echo "MintSplitter: ${MINT_SPLITTER_ADDRESS}"
# echo "TimeCircle: ${TIME_CIRCLE_ADDRESS}"
# echo "GroupCircle: ${GROUP_CIRCLES_ADDRESS}"
# echo "Graph: ${GRAPH_ADDRESS}"
