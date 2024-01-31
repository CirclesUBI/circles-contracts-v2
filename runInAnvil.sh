#!/bin/bash
anvil --fork-url https://rpc.chiado.gnosis.gateway.fm --fork-block-number 7969160 --port 8545 --gas-limit 8000000 --accounts 10 &
ANVIL_PID=$!

is_anvil_ready() {
    curl -X POST --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' -H "Content-Type: application/json" http://127.0.0.1:8545 &>/dev/null
    return $?
}

echo "Waiting for anvil to be ready..."
while ! is_anvil_ready; do
   sleep 1
done
echo "Anvil is ready. Deploying contracts..."

RPC_URL=http://localhost:8545
PRIVATE_KEY='0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
STANDARD_GROUP_MINT_POLICY='0x0000000000000000000000000000000000000000'

echo "Deploying ERC1155 Hub..."
MULTITOKEN_HUB=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/multitoken-graph/Hub.sol:Hub \
  --constructor-args ${STANDARD_GROUP_MINT_POLICY})

MULTITOKEN_HUB_ADDRESS=$(echo "$MULTITOKEN_HUB" | grep "Deployed to:" | awk '{print $3}')
echo "ERC1155 Hub deployed at ${MULTITOKEN_HUB_ADDRESS}"

# Function to kill anvil when the script exits
cleanup() {
    echo "Killing anvil..."
    kill $ANVIL_PID
}

# Set trap to call cleanup function when the script exits
trap cleanup EXIT

# Press any key to kill anvil
read -n 1 -s -r -p "Press any key to kill anvil"
