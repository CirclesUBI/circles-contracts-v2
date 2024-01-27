RPC_URL=https://rpc.chiado.gnosis.gateway.fm
PRIVATE_KEY=$1

V1_HUB_ADDRESS='0xdbF22D4e8962Db3b2F1d9Ff55be728A887e47710'

echo "Deploying MintSplitter..."
MINT_SPLITTER_DEPLOYMENT=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/mint/MintSplitter.sol:MintSplitter \
  --constructor-args ${V1_HUB_ADDRESS})

MINT_SPLITTER_ADDRESS=$(echo "$MINT_SPLITTER_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
echo "MintSplitter deployed at ${MINT_SPLITTER_ADDRESS}"

echo "Deploying TimeCircle..."
TIME_CIRCLE_DEPLOYMENT=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/circles/TimeCircle.sol:TimeCircle)

TIME_CIRCLE_ADDRESS=$(echo "$TIME_CIRCLE_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
echo "TimeCircle deployed at ${TIME_CIRCLE_ADDRESS}"

echo "Deploying GroupCircle..."
GROUP_CIRCLES_DEPLOYMENT=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/circles/GroupCircle.sol:GroupCircle)

GROUP_CIRCLES_ADDRESS=$(echo "$GROUP_CIRCLES_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
echo "GroupCircle deployed at ${GROUP_CIRCLES_ADDRESS}"

echo "Deploying Graph..."
GRAPH_DEPLOYMENT=$(forge create \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  src/graph/Graph.sol:Graph \
  --constructor-args ${MINT_SPLITTER_ADDRESS} '0x0000000000000000000000000000000000000000' ${TIME_CIRCLE_ADDRESS} ${GROUP_CIRCLES_ADDRESS})

GRAPH_ADDRESS=$(echo "$GRAPH_DEPLOYMENT" | grep "Deployed to:" | awk '{print $3}')
echo "Graph deployed at ${GRAPH_ADDRESS}"

echo ""
echo "Summary:"
echo "========"
echo "MintSplitter: ${MINT_SPLITTER_ADDRESS}"
echo "TimeCircle: ${TIME_CIRCLE_ADDRESS}"
echo "GroupCircle: ${GROUP_CIRCLES_ADDRESS}"
echo "Graph: ${GRAPH_ADDRESS}"
