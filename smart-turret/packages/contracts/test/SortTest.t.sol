// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { SmartTurretSystem } from "../src/systems/SmartTurretSystem.sol";
import { TargetPriority, SmartTurretTarget } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";

contract SortTest is Test {
    SmartTurretSystem system;

    function setUp() public {
        system = new SmartTurretSystem();
    }

    function createTargetPriority(uint256 weight, uint256 characterId) internal pure returns (TargetPriority memory) {
        SmartTurretTarget memory target = SmartTurretTarget({
            shipId: 1,
            shipTypeId: 1,
            characterId: characterId,
            hpRatio: 1,
            shieldRatio: 1,
            armorRatio: 1
        });
        return TargetPriority({
            target: target,
            weight: weight
        });
    }

    function testSortEmpty() public {
        TargetPriority[] memory queue = new TargetPriority[](0);
        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        assertEq(sorted.length, 0);
    }

    function testSortSingle() public {
        TargetPriority[] memory queue = new TargetPriority[](1);
        queue[0] = createTargetPriority(100, 1);
        
        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        assertEq(sorted.length, 1);
        assertEq(sorted[0].weight, 100);
    }

    function testSortAlreadySorted() public {
        TargetPriority[] memory queue = new TargetPriority[](3);
        queue[0] = createTargetPriority(10, 1);
        queue[1] = createTargetPriority(20, 2);
        queue[2] = createTargetPriority(30, 3);

        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        
        assertEq(sorted[0].weight, 10);
        assertEq(sorted[1].weight, 20);
        assertEq(sorted[2].weight, 30);
    }

    function testSortReverseSorted() public {
        TargetPriority[] memory queue = new TargetPriority[](3);
        queue[0] = createTargetPriority(30, 3);
        queue[1] = createTargetPriority(20, 2);
        queue[2] = createTargetPriority(10, 1);

        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        
        assertEq(sorted[0].weight, 10);
        assertEq(sorted[1].weight, 20);
        assertEq(sorted[2].weight, 30);
    }

    function testSortMixed() public {
        TargetPriority[] memory queue = new TargetPriority[](4);
        queue[0] = createTargetPriority(20, 2);
        queue[1] = createTargetPriority(40, 4);
        queue[2] = createTargetPriority(10, 1);
        queue[3] = createTargetPriority(30, 3);

        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        
        assertEq(sorted[0].weight, 10);
        assertEq(sorted[1].weight, 20);
        assertEq(sorted[2].weight, 30);
        assertEq(sorted[3].weight, 40);
    }

    function testSortDuplicates() public {
        TargetPriority[] memory queue = new TargetPriority[](4);
        queue[0] = createTargetPriority(20, 2); // id 2
        queue[1] = createTargetPriority(20, 1); // id 1
        queue[2] = createTargetPriority(10, 3);
        queue[3] = createTargetPriority(30, 4);

        TargetPriority[] memory sorted = system.insertionSortTargetPriorityArray(queue);
        
        assertEq(sorted[0].weight, 10);
        assertEq(sorted[1].weight, 20);
        assertEq(sorted[2].weight, 20);
        assertEq(sorted[3].weight, 30);
    }

    function testGetIsTargetInQueue() public {
        TargetPriority[] memory queue = new TargetPriority[](2);
        queue[0] = createTargetPriority(10, 1);
        queue[1] = createTargetPriority(20, 2);

        assertTrue(system.getIsTargetInQueue(queue, 1));
        assertTrue(system.getIsTargetInQueue(queue, 2));
        assertFalse(system.getIsTargetInQueue(queue, 3));
    }

    function testRemoveTargetFromQueueDirect() public {
        TargetPriority[] memory queue = new TargetPriority[](3);
        queue[0] = createTargetPriority(10, 1);
        queue[1] = createTargetPriority(20, 2);
        queue[2] = createTargetPriority(30, 3);

        TargetPriority[] memory result = system.removeTargetFromQueue(queue, 2);

        assertEq(result.length, 2);
        assertEq(result[0].target.characterId, 1);
        assertEq(result[1].target.characterId, 3);
    }
}
