#!/bin/bash

# Colors
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Current World ID from /config
WORLD_ADDRESS="0x1dacc0b64b7da0cc6e2b2fe1bd72f58ebd37363c"

# RPC URL for OP Sepolia (CCP)
RPC_URL="https://op-sepolia-ext-sync-node-rpc.live.tech.evefrontier.com"

# Using scetrov namespace based on our constants.sol
# sy:scetrov:SmartTurretSyste
SYSTEM_ID="0x737973636574726f7600000000000000536d6172745475727265745379737465"

# Character ID: https://evedataco.re/explore/characters/0x7954f10e127f58cfb45be07eb347383af01ec3ca (Zazar)
CHAR_ID="110087922946826710992697440478738810351357686058559476408012444533381068253566"

# Turret ID: https://evedataco.re/explore/assemblies/20851558268142977134151945697829752210257594985013462540523571104937171768449
TURRET_ID="20851558268142977134151945697829752210257594985013462540523571104937171768449"

# Ship Type ID (Default: 87698 - Wend, vs. 87847 - Reflex)
# SHIP_TYPE_ID="${1:-87698}" # Wend
SHIP_TYPE_ID="${1:-87847}" # Reflex

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
CALLDATA=$(cast calldata "inProximity(uint256,uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256))" \
  $TURRET_ID 1 "[]" "(1,1,100)" "(1,$SHIP_TYPE_ID,$CHAR_ID,100,100,100)")

# Execute the call via the World
RESULT=$(cast call $WORLD_ADDRESS "call(bytes32,bytes)(bytes)" "$SYSTEM_ID" "$CALLDATA" --rpc-url $RPC_URL)

echo -e "${ORANGE}Raw Result:${NC} $RESULT"

# Decode the result
# Return type: TargetPriority[]
# TargetPriority: (SmartTurretTarget target, uint256 priority)
# SmartTurretTarget: (uint256 shipId, uint256 shipTypeId, uint256 characterId, uint256 hp, uint256 shield, uint256 armor)
DECODED=$(cast abi-decode "inProximity(uint256,uint256,((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[],(uint256,uint256,uint256),(uint256,uint256,uint256,uint256,uint256,uint256)) returns (((uint256,uint256,uint256,uint256,uint256,uint256),uint256)[])" "$RESULT")

echo -e "${ORANGE}Decoded Result:${NC} $DECODED"

