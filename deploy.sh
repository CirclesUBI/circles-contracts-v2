RPC_URL=https://rpc.chiado.gnosis.gateway.fm
PRIVATE_KEY=$1

STANDARD_TREASURY='0x0000000000000000000000000000000000000000'

echo "Deploying Circles v1 Hub..."
CIRCLE_V1_HUB=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/circles-v1-graph/Hub.sol:Hub \
  --constructor-args ${STANDARD_GROUP_MINT_POLICY})

CIRCLE_V1_HUB_ADDRESS=$(echo "$CIRCLE_V1_HUB" | grep "Deployed to:" | awk '{print $3}')
echo "Circles v1 Hub deployed at ${CIRCLE_V1_HUB_ADDRESS}"

echo "Deploying ERC1155 Hub..."
MULTITOKEN_HUB=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/multitoken-graph/Hub.sol:Hub \
  --constructor-args ${CIRCLE_V1_HUB_ADDRESS} ${STANDARD_TREASURY} "https://example.com/")
MULTITOKEN_HUB_ADDRESS=$(echo "$MULTITOKEN_HUB" | grep "Deployed to:" | awk '{print $3}')
echo "ERC1155 Hub deployed at ${MULTITOKEN_HUB_ADDRESS}"

echo ""
echo "Summary:"
echo "========"
echo "Circles v1 Hub: ${CIRCLE_V1_HUB_ADDRESS}"
echo "Circles v2 Hub: ${MULTITOKEN_HUB_ADDRESS}"
