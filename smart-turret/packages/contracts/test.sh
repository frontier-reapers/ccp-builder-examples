#!/bin/bash

set -euo pipefail

# Environment (Default: prod)
ENV="${1:-prod}"

# Source environment variables if file exists
if [ -f ".env.${ENV}" ]; then
  source ".env.${ENV}"
fi

# Colors
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Ship Type ID (Default: 87698 - Wend, vs. 87847 - Reflex)
# SHIP_TYPE_ID="${2:-87698}" # Wend
SHIP_TYPE_ID="${2:-87847}" # Reflex

echo -e "${ORANGE}Environment:${NC} $ENV"
echo -e "${ORANGE}World Address:${NC} $WORLD_ADDRESS"
echo -e "${ORANGE}RPC URL:${NC} $RPC_URL"
echo -e "${ORANGE}System ID:${NC} $SYSTEM_ID"
echo -e "${ORANGE}Character ID:${NC} $CHAR_ID"
echo -e "${ORANGE}Turret ID:${NC} $TURRET_ID"
echo -e "${ORANGE}Ship Type ID:${NC} $SHIP_TYPE_ID"

# Call data for inProximity
# SmartTurretTarget: (shipId:1, shipTypeId:SHIP_TYPE_ID, characterId:CHAR_ID, hp:100, shield:100, armor:100)
# Turret: (1, 1, 100)
# priorityQueue: []
CALLDATA=$(cast calldata "inProximity(uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256))" \
  $TURRET_ID "[]" "(1,1,100)" "(1,$SHIP_TYPE_ID,$CHAR_ID,100,100,100)")

# Execute the call via the World
RESULT=$(cast call $WORLD_ADDRESS "call(bytes32,bytes)(bytes)" "$SYSTEM_ID" "$CALLDATA" --rpc-url $RPC_URL)

echo -e "${ORANGE}Raw Result:${NC} $RESULT"

# Decode the result
# Return type: TargetPriority[]
# TargetPriority: (SmartTurretTarget target, uint256 priority)
# SmartTurretTarget: (uint256 shipId, uint256 shipTypeId, uint256 characterId, uint256 hp, uint256 shield, uint256 armor)
DECODED=$(cast abi-decode "inProximity(uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256)) returns (((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[])" "$RESULT")

echo -e "${ORANGE}Decoded Result:${NC} $DECODED"

