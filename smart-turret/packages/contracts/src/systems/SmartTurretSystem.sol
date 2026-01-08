// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";

import { 
  Turret, 
  SmartTurretTarget, 
  TargetPriority, 
  AggressionParams 
} from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";

import { Characters } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/Characters.sol";
import { accessSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";

/**
 * @dev This contract is an example for implementing logic to a smart turret
 */
contract SmartTurretSystem is System {
  error SmartTurretError(string message);

  /**
   * @dev a function to implement logic for Smart Turret based on proximity
   * @param smartTurretId The Smart Turret id
   * @param priorityQueue is the queue of existing targets ordered by priority, index 0 being the lowest priority
   * @param turret is the turret data
   * @param turretTarget is the player in the zone
   * This runs on a tick based cycle when the player is in proximity of the Smart Turret
   * The game receives the new priority queue, and select targets based on the reverse order of the new queue. 
   * Meaning the targets with the highest index will be picked first.
   */
  function inProximity(
    uint256 smartTurretId,
    TargetPriority[] memory priorityQueue,
    Turret memory turret,
    SmartTurretTarget memory turretTarget
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    if (smartTurretId == 0) {
      revert SmartTurretError("Invalid smartTurretId");
    }

    if (turret.weaponTypeId == 0) {
      revert SmartTurretError("Invalid turret");
    }

    if (turretTarget.characterId == 0) {
      revert SmartTurretError("Invalid characterId");
    }

    if (turretTarget.shipTypeId == 0) {
      revert SmartTurretError("Invalid shipTypeId");
    }

    if (turretTarget.hpRatio > 100 || turretTarget.shieldRatio > 100 || turretTarget.armorRatio > 100) {
      revert SmartTurretError("Invalid ratio");
    }

    // Get the corp ID of the player that is in proximity of the Smart Turret
    uint256 characterCorp = Characters.getTribeId(turretTarget.characterId);

    // Find if the player is already in the queue. 
    // This might happen if the player joins the corp while in proximity.
    bool foundInPriorityQueue = getIsTargetInQueue(priorityQueue, turretTarget.characterId);
    
    // Check if the player shouldn't be targeted
    if (characterCorp == 98000367 || isAllowedTypeId(turretTarget.shipTypeId)) {
      if (!foundInPriorityQueue) {
        // Return the unchanged array
        return priorityQueue;     
      }

      // If found, create a new array without the character
      return removeTargetFromQueue(priorityQueue, turretTarget.characterId);
    }

    // Prioritize ships with the lowest total health percentage. hPRatio, shieldRatio and armorRatio are between [0-100]
    uint256 calculatedWeight = calculateWeight(turretTarget);

    // Weight is not currently used in-game as the game uses the position of elements in the array, however we set it for the bubble sort algorithm to use
    // If already in the queue, update the weight and sort the array
    if (foundInPriorityQueue) {
      for (uint i = 0; i < priorityQueue.length; i++) {
        if (priorityQueue[i].target.characterId == turretTarget.characterId) {
          priorityQueue[i].target = turretTarget;
          break;
        }
      }
      return updateWeight(priorityQueue);
    }

    // Create the new priority
    TargetPriority memory newTarget = TargetPriority({ target: turretTarget, weight: calculatedWeight }); 

    // If not already in the queue, add to the queue
    return addTargetToQueue(priorityQueue, newTarget);
  }

  /**
   * @dev a function to check if a target is in the queue
   * @param priorityQueue is the queue to check
   * @param characterId is the character ID to check
   * @return isInQueue is true if the target is in the queue
   */
  function getIsTargetInQueue(
    TargetPriority[] memory priorityQueue, 
    uint256 characterId
  ) public pure returns (bool isInQueue) {
    for (uint i = 0; i < priorityQueue.length; i++) {
      if (priorityQueue[i].target.characterId == characterId) {
        return true;
      }
    }

    return false;
  }

  /**
   * @dev a function to remove a target from the queue
   * @param priorityQueue is the queue to remove the target from
   * @param characterId is the character ID to remove
   * @return updatedPriorityQueue is the updated queue
   */
  function removeTargetFromQueue(
    TargetPriority[] memory priorityQueue, 
    uint256 characterId
  ) public pure returns (TargetPriority[] memory updatedPriorityQueue) {
      // Create the smaller temporary array
      updatedPriorityQueue = new TargetPriority[](priorityQueue.length - 1);

      // Loop over the queue and only set if not the character
      uint256 j = 0;
      for (uint i = 0; i < priorityQueue.length; i++) {
        if (priorityQueue[i].target.characterId != characterId) {
          updatedPriorityQueue[j] = priorityQueue[i];
          j++;
        }
      }

      // Sort the array (Only if logic changes, but removing preserves order. 
      // However, if we want to be safe or if weights changed elsewhere:
      // In this specific function, weights don't change, so checking order is preserved.)
      // optimization: removing an element from a sorted array keeps it sorted.
      // updatedPriorityQueue = insertionSortTargetPriorityArray(updatedPriorityQueue);

      return updatedPriorityQueue;
  }

  /**
   * @dev a function to update all of the weights in the queue
   * @param priorityQueue is the queue to update the weights of the targets in
   * @return updatedPriorityQueue is the updated queue
   */
  function updateWeight(
    TargetPriority[] memory priorityQueue
  ) public pure returns (TargetPriority[] memory updatedPriorityQueue) {
    for (uint i = 0; i < priorityQueue.length; i++) {
      priorityQueue[i].weight = calculateWeight(priorityQueue[i].target);
    }

    // Sort the array
    priorityQueue = insertionSortTargetPriorityArray(priorityQueue);

    return priorityQueue;
  }

  /**
   * @dev a function to add a target to the queue
   * @param priorityQueue is the queue to add the target to
   * @param newTarget is the target to add
   * @return updatedPriorityQueue is the updated queue
   */
  function addTargetToQueue(
    TargetPriority[] memory priorityQueue, 
    TargetPriority memory newTarget
  ) public pure returns (TargetPriority[] memory updatedPriorityQueue) {
    // Create the larger temporary array
    updatedPriorityQueue = new TargetPriority[](priorityQueue.length + 1);

    // Clone the priority queue to the temp array
    for (uint i = 0; i < priorityQueue.length; i++) {
      updatedPriorityQueue[i] = priorityQueue[i];
    }

    // Set the new target to the end of the temp array
    updatedPriorityQueue[priorityQueue.length] = newTarget;      

    // Sort the array
    updatedPriorityQueue = insertionSortTargetPriorityArray(updatedPriorityQueue);

    return updatedPriorityQueue;
  }

  /**
   * @dev a function to sort the priority queue by weight, using the insertion sort algorithm
   * @param priorityQueue is the queue to sort
   */
  function insertionSortTargetPriorityArray(
    TargetPriority[] memory priorityQueue
  ) public pure returns (TargetPriority[] memory sortedPriorityQueue) {
    uint256 length = priorityQueue.length;

    for (uint256 i = 1; i < length; i++) {
        TargetPriority memory key = priorityQueue[i];
        uint256 j = i;
        while ((j > 0) && (priorityQueue[j - 1].weight > key.weight)) {
            priorityQueue[j] = priorityQueue[j - 1];
            j--;
        }
        priorityQueue[j] = key;
    }

    return priorityQueue;
  }

  /**
   * @dev a function to calculate the weight of the target
   * @param target is the target
   * This calculates weight so that the higher the weight, the higher the priority. 
   * As the targets are prioritized and the game selects the targets in reverse order they are returned.
   */
  function calculateWeight(SmartTurretTarget memory target) internal pure returns (uint256 weight) {
    uint256 MAX_COMBINED_HP_RATIO = 300;

    weight = MAX_COMBINED_HP_RATIO - (
      target.hpRatio + 
      target.shieldRatio + 
      target.armorRatio
    );

    return weight;
  }

  /**
   * @dev a function to implement logic for smart turret based on aggression
   * @param aggressionParams is the aggression parameters
   */
  function aggression(
    AggressionParams memory aggressionParams
  ) public returns (TargetPriority[] memory updatedPriorityQueue) {
    if (aggressionParams.smartObjectId == 0) {
      revert SmartTurretError("Invalid smartTurretId");
    }

    if (aggressionParams.turret.weaponTypeId == 0) {
      revert SmartTurretError("Invalid turret");
    }

    if (aggressionParams.aggressor.characterId == 0) {
      revert SmartTurretError("Invalid aggressor characterId");
    }

    if (aggressionParams.victim.characterId == 0) {
      revert SmartTurretError("Invalid victim characterId");
    }

    if (aggressionParams.aggressor.characterId == aggressionParams.victim.characterId) {
      revert SmartTurretError("Aggressor and victim cannot be the same");
    }

    return aggressionParams.priorityQueue;
  }

  function isAllowedTypeId(uint256 targetTypeId) internal pure returns (bool) {
    // Refuge
    if (targetTypeId == 87160) {
      return true;
    }

    // Refinery
    if (targetTypeId == 87161) {
      return true;
    }

    // Printer
    if (targetTypeId == 87162) {
      return true;
    }

    // Storage
    if (targetTypeId == 87566) {
      return true;
    }

    // Wend
    if (targetTypeId == 87698) {
      return true;
    }

    // Wreck
    if (targetTypeId == 81610) {
      return true;
    }

    return false;
  }
}
