// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20.sol";
import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";

import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "@eveworld/world/src/codegen/tables/EntityRecordTable.sol";
import { Utils as EntityRecordUtils } from "@eveworld/world/src/modules/entity-record/Utils.sol";
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as SmartCharacterUtils } from "@eveworld/world/src/modules/smart-character/Utils.sol";
import { CharactersTableData, CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "@eveworld/world/src/modules/smart-turret/types.sol";

/**
 * @dev This contract is an example for implementing logic to a smart turret
 */
contract SmartTurretSystem is System {
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;

  function isCeasefire(uint256 timestamp) public pure returns (bool) {
    uint256 startTime = 1740096000; // Fri Feb 21 2025 00:00:00 GMT+0000
    uint256 endTime = 1740355199; // Sun Feb 23 2025 23:59:59 GMT+0000

    if (timestamp >= startTime && timestamp <= endTime) {
      return true;
    }
  }

  /**
   * @dev a function to implement logic for smart turret based on proximity
   * @param smartTurretId The smart turret id
   * @param characterId is the owner of the smart turret
   * @param priorityQueue is the queue of existing targets ordered by priority, index 0 being the lowest priority
   * @param turret is the turret data
   * @param turretTarget is the target data
   */
  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    if (turretTarget.shipTypeId == 81610) {
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    uint256 turretTargetCorp = CharactersTable.getCorpId(turretTarget.characterId);
    uint256 smartTurretOwnerCorp = CharactersTable.getCorpId(characterId);

    if (isCeasefire(block.timestamp)) {
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    if (isReapersCorp(turretTargetCorp)) {
      // Reapers
      // do not add to targeting
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    if (turretTargetCorp == smartTurretOwnerCorp) {
      // do not add to targeting
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    // we didn't early return so therefore we target
    updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
    for (uint256 i = 0; i < priorityQueue.length; i++) {
      updatedPriorityQueue[i + 1] = priorityQueue[i];
    }

    // should the weight be 1? or the heighest of all weights in the array ?
    updatedPriorityQueue[0] = TargetPriority({ target: turretTarget, weight: 1 });
    return updatedPriorityQueue;
  }

  /**
   * @dev a function to implement logic for smart turret based on aggression
   * @param smartTurretId The smart turret id
   * @param characterId is the owner of the smart turret
   * @param priorityQueue is the queue of existing targets ordered by priority, index 0 being the lowest priority
   * @param turret is the turret data
   * @param aggressor is the aggressor
   * @param victim is the victim
   */
  function aggression(
    uint256 smartTurretId,
    uint256 characterId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory aggressor,
    SmartTurretTarget memory victim
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    uint256 agressorCorp = CharactersTable.getCorpId(aggressor.characterId);
    uint256 smartTurretOwnerCorp = CharactersTable.getCorpId(characterId);

    if (isReapersCorp(agressorCorp)) {
      // do not add to targeting
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    if (agressorCorp == smartTurretOwnerCorp) {
      // do not add to targeting
      updatedPriorityQueue = priorityQueue;
      return updatedPriorityQueue;
    }

    // we didn't early return so therefore we target
    updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);
    for (uint256 i = 0; i < priorityQueue.length; i++) {
      updatedPriorityQueue[i + 1] = priorityQueue[i];
    }

    // should the weight be 1? or the heighest of all weights in the array ?
    updatedPriorityQueue[0] = TargetPriority({ target: aggressor, weight: 1 });
    return updatedPriorityQueue;
  }

  function isReapersCorp(uint256 targetCorp) internal pure returns (bool) {
    if (targetCorp == 98000003) {
      // Reapers
      return true;
    }

    if (targetCorp == 98000006) {
      // Reapers II
      return true;
    }

    if (targetCorp == 98000018) {
      // Reapers III
      return true;
    }

    return false;
  }

  function _namespace() internal pure returns (bytes14 namespace) {
    return DEPLOYMENT_NAMESPACE;
  }
}
