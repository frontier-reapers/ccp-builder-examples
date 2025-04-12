// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { InventoryItem } from "@eveworld/world/src/modules/inventory/types.sol";
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import { SmartDeployableLib } from "@eveworld/world/src/modules/smart-deployable/SmartDeployableLib.sol";
import { Coord, WorldPosition, EntityRecordData } from "@eveworld/world/src/modules/smart-storage-unit/types.sol";
import { SmartObjectData } from "@eveworld/world/src/modules/smart-deployable/types.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { GlobalDeployableState } from "@eveworld/world/src/codegen/tables/GlobalDeployableState.sol";
import { SmartTurretLib } from "@eveworld/world/src/modules/smart-turret/SmartTurretLib.sol";
import { EntityRecordLib } from "@eveworld/world/src/modules/entity-record/EntityRecordLib.sol";
import { SmartCharacterLib } from "@eveworld/world/src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordData as CharacterEntityRecord } from "@eveworld/world/src/modules/smart-character/types.sol";
import { EntityRecordOffchainTableData } from "@eveworld/world/src/codegen/tables/EntityRecordOffchainTable.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";
import { DeployableState, DeployableStateData } from "@eveworld/world/src/codegen/tables/DeployableState.sol";
import { State } from "@eveworld/world/src/modules/smart-deployable/types.sol";
import { EphemeralInvItemTableData, EphemeralInvItemTable } from "@eveworld/world/src/codegen/tables/EphemeralInvItemTable.sol";
import { GlobalDeployableState } from "@eveworld/world/src/codegen/tables/GlobalDeployableState.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";

import { SmartTurretSystem } from "../src/systems/SmartTurretSystem.sol";
import { TargetPriority, Turret, SmartTurretTarget } from "@eveworld/world/src/modules/smart-turret/types.sol";

contract SmartTurretTest is MudTest {
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartTurretLib for SmartTurretLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using SmartCharacterLib for SmartCharacterLib.World;
  using SmartDeployableUtils for bytes14;

  SmartDeployableLib.World smartDeployable;
  SmartTurretLib.World smartTurret;
  EntityRecordLib.World entityRecord;
  SmartCharacterLib.World smartCharacter;
  ResourceId systemId = Utils.smartTurretSystemId();

  IWorld world;

  uint256 smartTurretId;
  uint256 testCharacterId = 11111;
  uint256 testReapersCharacterId = 32123;
  uint256 testReapersIICharacterId = 32124;
  uint256 testReapersIIICharacterId = 32125;
  uint256 testReapersIVCharacterId = 32126;

  uint256 testCharacterId2 = 22222;
  uint256 testCharacterId3 = 33333;
  uint256 testCharacterId4 = 44444;
  uint256 testCharacterId5 = 55555;

  //Setup for the tests
  function setUp() public override {
    super.setUp();
    world = IWorld(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.addr(deployerPrivateKey);

    uint256 playerPrivateKey = vm.envUint("TEST_PLAYER_PRIVATE_KEY");
    address player = vm.addr(playerPrivateKey);

    smartDeployable = SmartDeployableLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });
    smartTurret = SmartTurretLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    entityRecord = EntityRecordLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    smartCharacter = SmartCharacterLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    if (CharactersByAddressTable.get(admin) == 0) {
      smartCharacter.createCharacter(
        123,
        admin,
        200003,
        CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
        EntityRecordOffchainTableData({ name: "ron", dappURL: "noURL", description: "." }),
        ""
      );
    }
    if (CharactersByAddressTable.get(player) == 0) {
      smartCharacter.createCharacter(
        456,
        player,
        200004,
        CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
        EntityRecordOffchainTableData({ name: "harryporter", dappURL: "noURL", description: "." }),
        ""
      );
    }

    // Create test characters with known corp IDs that aren’t blocked
    smartCharacter.createCharacter(
      testCharacterId,
      address(0x111),
      200005,
      CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
      EntityRecordOffchainTableData({ name: "testchar1", dappURL: "none", description: "test" }),
      ""
    );

    smartCharacter.createCharacter(
      testCharacterId2,
      address(0x222),
      200006,
      CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
      EntityRecordOffchainTableData({ name: "testchar2", dappURL: "none", description: "test" }),
      ""
    );

    smartCharacter.createCharacter(
      testReapersCharacterId,
      address(0x333),
      98000002, // Reapers
      CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
      EntityRecordOffchainTableData({ name: "reaperChar", dappURL: "none", description: "test" }),
      ""
    );

    smartCharacter.createCharacter(
      testReapersIICharacterId,
      address(0x444),
      98000006, // Reapers II
      CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
      EntityRecordOffchainTableData({ name: "reaper2Char", dappURL: "none", description: "test" }),
      ""
    );

    smartCharacter.createCharacter(
      testReapersIIICharacterId,
      address(0x555),
      98000018, // Reapers III
      CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
      EntityRecordOffchainTableData({ name: "reaper3Char", dappURL: "none", description: "test" }),
      ""
    );

    // smartCharacter.createCharacter(
    //   testReapersIVCharacterId,
    //   address(0x666),
    //   98000187, // Reapers IV
    //   CharacterEntityRecord({ typeId: 123, itemId: 234, volume: 100 }),
    //   EntityRecordOffchainTableData({ name: "reaper4Char", dappURL: "none", description: "test" }),
    //   ""
    // );

    smartTurretId = vm.envUint("SMART_TURRET_ID");
    createAnchorAndOnline(smartTurretId, admin);
  }

  //Test if the world exists
  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  //Test inProximity
  function testInProximity() public {
    //Execute inProximity view function and see what it returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory turretTarget = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testCharacterId3, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          SmartTurretSystem.inProximity,
          (smartTurretId, testCharacterId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 2, "Target length should now equal 2");
    assertEq(returnTargetQueue[0].weight, 1, "New target is at the beginning of the queue and has weight 1");
    assertEq(returnTargetQueue[1].weight, 100, "Old target should have shifted down");
  }

  function testReapersIInProximity() public {
    _testImmuneCharacterInProximity(testReapersCharacterId);
  }

  // function testReapersIIInProximity() public {
  //   _testImmuneCharacterInProximity(testReapersIICharacterId);
  // }

  // function testReapersIIIInProximity() public {
  //   _testImmuneCharacterInProximity(testReapersIIICharacterId);
  // }

  // function testReapersIVInProximity() public {
  //   _testImmuneCharacterInProximity(testReapersIVCharacterId);
  // }

    //Test inProximity
  function testInProximityOnWreck() public {
    //Execute inProximity view function and see what it returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({ shipId: 1, shipTypeId: 81610, characterId: testCharacterId3, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          SmartTurretSystem.inProximity,
          (smartTurretId, testCharacterId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 0, "Target length should now equal 0");
  }

  //Test inProximity
  function _testImmuneCharacterInProximity(uint256 characterId) private {
    //Execute inProximity view function and see what it returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory turretTarget = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: characterId, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    assertEq(priorityQueue.length, 1, "Target length is 1.");

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          SmartTurretSystem.inProximity,
          (smartTurretId, testCharacterId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 1, "Target length is unchanged.");
  }

  //Test aggression
  function testAggression() public {
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testCharacterId3, hpRatio: 50, shieldRatio: 50, armorRatio: 50 });
    SmartTurretTarget memory aggressor = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testCharacterId4, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });
    SmartTurretTarget memory victim = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testCharacterId5, hpRatio: 80, shieldRatio: 100, armorRatio: 100 });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    //Run aggression
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          SmartTurretSystem.aggression,
          (smartTurretId, testCharacterId, priorityQueue, turret, aggressor, victim)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 2, "Target length should now equal 2");
    assertEq(returnTargetQueue[0].weight, 1, "New target is at the beginning of the queue and has weight 1");
    assertEq(returnTargetQueue[1].weight, 100, "Old target should have shifted down");
  }

  function testAggressionFromCorp() public {
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    SmartTurretTarget memory originalTarget = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testCharacterId, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });
    priorityQueue[0] = TargetPriority({ target: originalTarget, weight: 100 });

    // Aggressor from Reapers (98000004)
    SmartTurretTarget memory aggressor = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: testReapersCharacterId, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });

    // any victim
    SmartTurretTarget memory victim = SmartTurretTarget({ shipId: 1, shipTypeId: 1, characterId: 5555, hpRatio: 100, shieldRatio: 100, armorRatio: 100 });

    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          SmartTurretSystem.aggression,
          (smartTurretId, testCharacterId, priorityQueue, turret, aggressor, victim)
        )
      ),
      (TargetPriority[])
    );

    // Should remain unchanged if aggressor belongs to a blocked corp (e.g. Reapers)
    assertEq(returnTargetQueue.length, 1, "Target length should remain 1");
  }

  function testBeforeCeasefire() public {
    uint256 testTime = 1740095999; // Wed Jan 29 2025 15:07:13 GMT+0000
    bool result = abi.decode(world.call(systemId, abi.encodeCall(SmartTurretSystem.isCeasefire, (testTime))), (bool));
    assertFalse(result);
  }

  function testEarlyBoundryOfCeasefire() public {
    uint256 testTime = 1740096000; // Fri Feb 21 2025 00:00:00 GMT+0000
    bool result = abi.decode(world.call(systemId, abi.encodeCall(SmartTurretSystem.isCeasefire, (testTime))), (bool));
    assertTrue(result);
  }

  function testMidpointOfCeasefire() public {
    uint256 testTime = 1740247200; // Sat Feb 22 2025 18:00:00 GMT+0000
    bool result = abi.decode(world.call(systemId, abi.encodeCall(SmartTurretSystem.isCeasefire, (testTime))), (bool));
    assertTrue(result);
  }

  function testLateBoundryOfCeasefire() public {
    uint256 testTime = 1740355199; // Sun Feb 23 2025 23:59:59 GMT+0000
    bool result = abi.decode(world.call(systemId, abi.encodeCall(SmartTurretSystem.isCeasefire, (testTime))), (bool));
    assertTrue(result);
  }

  function testAfterCeasefire() public {
    uint256 testTime = 1740398400; // Mon Feb 24 2025 12:00:00 GMT+0000
    bool result = abi.decode(world.call(systemId, abi.encodeCall(SmartTurretSystem.isCeasefire, (testTime))), (bool));
    assertFalse(result);
  }

  function createAnchorAndOnline(uint256 _smartTurretId, address admin) private {
    //Create and anchor the smart turret and bring online
    smartTurretId = _smartTurretId;
    smartTurret.createAndAnchorSmartTurret(
      smartTurretId,
      EntityRecordData({ typeId: 7888, itemId: 111, volume: 10 }),
      SmartObjectData({ owner: admin, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionPerMinute,
      1000000 * 1e18 // fuelMaxCapacity,
    );

    // check global state and resume if needed
    if (GlobalDeployableState.getIsPaused() == false) {
      smartDeployable.globalResume();
    }

    smartDeployable.depositFuel(smartTurretId, 200010);
    smartDeployable.bringOnline(smartTurretId);
  }
}
