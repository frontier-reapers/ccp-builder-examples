// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { console } from "forge-std/console.sol";

import { IBaseWorld } from "@eveworld/world-v2/src/codegen/world/IWorld.sol";
import { SmartCharacterSystem, smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { Location, LocationData } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/Location.sol";
import { DeployableState } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { FuelSystem, fuelSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { FuelParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/fuel/types.sol";
import { SmartAssemblySystem, smartAssemblySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { EntityRecordSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/EntityRecordSystem.sol";
import { entityRecordSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { Tenant, Characters, CharactersByAccount, EntityRecord } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";
import { State } from "@eveworld/world-v2/src/codegen/common.sol";
import { Turret, SmartTurretTarget } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";
import { SmartTurretSystem, smartTurretSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/SmartTurretSystem.sol";
import { TargetPriority } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";

import { SmartTurretSystem as CustomSmartTurretSystem } from "../src/systems/SmartTurretSystem.sol";

import { AggressionParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-turret/types.sol";

contract SmartTurretTest is MudTest {
  ResourceId systemId = Utils.smartTurretSystemId();

  IWorld world;
  bytes32 tenantId;

  address admin;
  address player;
  address player2;
  address player3;

  //Character Smart Object IDs (These are generated from the character IDs)
  uint256 adminCharacterSmartId;
  uint256 playerCharacterSmartId;
  uint256 player2CharacterSmartId;
  uint256 player3CharacterSmartId;

  //Smart Turret ID
  uint256 smartTurretId;

  //Tribe that does not get targeted
  uint256 ALLOWED_TRIBE_ID = 98000367;

  //Character IDs
  uint256 ADMIN_CHARACTER_ID = 35000;
  uint256 PLAYER_CHARACTER_ID = 1;
  uint256 PLAYER2_CHARACTER_ID = 2;
  uint256 PLAYER3_CHARACTER_ID = 3;

  //Gate IDs
  uint256 SOURCE_GATE_ID = 9000;
  uint256 DESTINATION_GATE_ID = 9001; 

  //Type IDs
  uint256 CHARACTER_TYPE_ID = 42000000100;
  uint256 SMART_TURRET_TYPE_ID = 84556;
  uint256 FUEL_TYPE_ID = 84868;

  function safeCreateCharacter(address account, uint256 smartObjectId, uint256 characterId, uint256 tribeId, string memory name) private {
    if (CharactersByAccount.get(account) != 0) return;

    smartCharacterSystem.createCharacter(
      smartObjectId, 
      account, 
      tribeId, 
      EntityRecordParams({ tenantId: tenantId, typeId: CHARACTER_TYPE_ID, itemId: characterId, volume: 100 }), 
      EntityMetadataParams({ name: name, dappURL: "noURL", description: "." })
    );
  }

  //Setup for the tests
  function setUp() public override {
    super.setUp();
    world = IWorld(worldAddress);
    
    tenantId = Tenant.getTenantId();

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    admin = vm.addr(deployerPrivateKey);

    // Deploy and Register the LOCAL SmartTurretSystem to OVERRIDE the existing one on the fork
    vm.startPrank(admin);
    CustomSmartTurretSystem newSystem = new CustomSmartTurretSystem();
    world.registerSystem(systemId, newSystem, true);
    vm.stopPrank();

    // Using the last 3 automatically generated public addresses from Anvil.
    // These are different to the mock data to ensure there is no overlap
    player = address(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955);
    player2 = address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f);
    player3 = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);

    // Calculate smartTurretId BEFORE using it
    smartTurretId = ObjectIdLib.calculateObjectId(tenantId, SOURCE_GATE_ID);
    
    adminCharacterSmartId = ObjectIdLib.calculateObjectId(tenantId, ADMIN_CHARACTER_ID);
    playerCharacterSmartId = ObjectIdLib.calculateObjectId(tenantId, PLAYER_CHARACTER_ID);
    player2CharacterSmartId = ObjectIdLib.calculateObjectId(tenantId, PLAYER2_CHARACTER_ID);
    player3CharacterSmartId = ObjectIdLib.calculateObjectId(tenantId, PLAYER3_CHARACTER_ID);

    vm.startPrank(player, admin);

    safeCreateCharacter(admin, adminCharacterSmartId, ADMIN_CHARACTER_ID, ALLOWED_TRIBE_ID, "adminCharacter");
    safeCreateCharacter(player, playerCharacterSmartId, PLAYER_CHARACTER_ID, ALLOWED_TRIBE_ID, "playerCharacter");
    safeCreateCharacter(player2, player2CharacterSmartId, PLAYER2_CHARACTER_ID, 123, "player2Character");
    safeCreateCharacter(player3, player3CharacterSmartId, PLAYER3_CHARACTER_ID, 1234, "player3Character");

    vm.stopPrank();

    // Add delegation setup
    vm.startPrank(player);
    world.registerDelegation(admin, UNLIMITED_DELEGATION, new bytes(0));
    vm.stopPrank();

    vm.startPrank(player, admin);

    if(DeployableState.getCurrentState(smartTurretId) != State.NULL){
      console.log("Smart turret already exists");
    } else{
      createAnchorAndOnline(smartTurretId, SOURCE_GATE_ID, player);
    }

    vm.stopPrank();
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

  //Test inProximity with a player that should not be targeted
  function testInProximityInTribe() public {
    //Execute inProximity view function and see what is returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    //Total Weight: 0
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: playerCharacterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });
    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 0, "There should be no targets");
  }

  //Test inProximity with a player that should not be targeted and is already in the queue
  function testInProximityNotInTribe() public {
    //Execute inProximity view function and see what is returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    //Total Weight: 0
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player2CharacterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });
    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 1, "There should be 1 target");
  }

  //Test inProximity with a player that should not be targeted and is already in the queue
  function testInProximityNotInTribeNew() public {
    //Execute inProximity view function and see what is returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    //Total Weight: 0
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player3CharacterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 1, "There should be 1 target");
  }

  //Test inProximity with a player that should not be targeted and is already in the queue
  function testInProximityNotInTribePriority() public {
    //Execute inProximity view function and see what is returns
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    //Total Weight: 150
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player3CharacterSmartId,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    
    //Total Weight: 200
    SmartTurretTarget memory turretTarget2 = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player2CharacterSmartId,
      hpRatio: 50,
      shieldRatio: 0,
      armorRatio: 50
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 150 });
    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget2)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 2, "There should be 2 targets");

    assertEq(returnTargetQueue[0].target.characterId, player3CharacterSmartId, "The first target should be turretTarget2, as it has the lowest total health. Test 1");
    assertEq(returnTargetQueue[0].weight, 150, "The first target should be with 100 weight, as it has the lowest total health. Test 1");
    

    //Test with the lowest health being originally second
    priorityQueue[0] = TargetPriority({ target: turretTarget2, weight: 100 });
    //Run inProximity
    returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 2, "There should be 2 targets");

    assertEq(returnTargetQueue[0].target.characterId, player2CharacterSmartId, "The first target should be turretTarget2, as it has the lowest total health. Test 2");
  }

  //Test aggression
  function testAggression() public {    
    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: playerCharacterSmartId,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player2CharacterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player3CharacterSmartId,
      hpRatio: 80,
      shieldRatio: 100,
      armorRatio: 100
    });

    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 100 });

    AggressionParams memory aggressionParams = AggressionParams({
      smartObjectId: smartTurretId,
      priorityQueue: priorityQueue,
      turret: turret,
      aggressor: aggressor,
      victim: victim
    });

    //Run aggression
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (aggressionParams)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 1, "Target length should equal 1");
  }

  function testInProximityReflexCO86() public {
    uint256 REFLEX_SHIP_TYPE_ID = 87847;
    uint256 CO86_TRIBE_ID = 1000167;
    uint256 CHARACTER_ID = 444;
    address player4 = address(0x444);
    uint256 characterSmartId = ObjectIdLib.calculateObjectId(tenantId, CHARACTER_ID);

    vm.startPrank(player4, admin);
    safeCreateCharacter(player4, characterSmartId, CHARACTER_ID, CO86_TRIBE_ID, "reflexCharacter");
    vm.stopPrank();

    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: REFLEX_SHIP_TYPE_ID,
      characterId: characterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 1, "Reflex in CO86 should be targeted");
    assertEq(returnTargetQueue[0].target.characterId, characterSmartId, "Character ID should match");
  }

  function testInProximityWendCO86() public {
    uint256 WEND_SHIP_TYPE_ID = 87698;
    uint256 CO86_TRIBE_ID = 1000167;
    uint256 CHARACTER_ID = 555;
    address player5 = address(0x555);
    uint256 characterSmartId = ObjectIdLib.calculateObjectId(tenantId, CHARACTER_ID);

    vm.startPrank(player5, admin);
    safeCreateCharacter(player5, characterSmartId, CHARACTER_ID, CO86_TRIBE_ID, "wendCharacter");
    vm.stopPrank();

    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: WEND_SHIP_TYPE_ID,
      characterId: characterSmartId,
      hpRatio: 100,
      shieldRatio: 100,
      armorRatio: 100
    });

    //Run inProximity
    TargetPriority[] memory returnTargetQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, turretTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(returnTargetQueue.length, 0, "Wend in CO86 should not be targeted");
  }

  function createAnchorAndOnline(uint256 smartAssemblyId, uint256 itemId, address ownerAddress) private {
    LocationData memory locationParams = LocationData({ solarSystemId: 30000042, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_TURRET_TYPE_ID,
      itemId: itemId,
      volume: 1000
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: smartAssemblyId,
      assemblyType: "ST",
      entityRecordParams: entityRecordParams,
      owner: ownerAddress,
      locationData: locationParams
    });

    world.callFrom(
      ownerAddress,
      smartTurretSystem.toResourceId(),
      abi.encodeCall(
        SmartTurretSystem.createAndAnchorTurret,
        (deployableParams, 0)
      )
    );

    entityRecordSystem.createMetadata(smartAssemblyId, EntityMetadataParams({
      name: "Name Here",
      dappURL: "",
      description: "Example SSU for the Smart Assembly Scaffold"
    }));

    vm.stopPrank();

    vm.startPrank(admin);

    uint256 fuelSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, FUEL_TYPE_ID);

    fuelSystem.configureFuelParameters(smartAssemblyId, FuelParams({
      fuelMaxCapacity: 100000000,
      fuelBurnRateInSeconds: 100000000
    }));

    vm.stopPrank();

    vm.startPrank(player, admin);

    fuelSystem.depositFuel(smartAssemblyId, fuelSmartObjectId, 1000);

    deployableSystem.bringOnline(smartAssemblyId);
  }

  // Test removal from queue if target becomes invalid
  function testRemoveFromQueue() public {
    SmartTurretTarget memory turretTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1, // Valid type initially
      characterId: playerCharacterSmartId,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });

    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    priorityQueue[0] = TargetPriority({ target: turretTarget, weight: 150 });

    // Now call inProximity with the same character but with an IGNORED ship type (Wend = 87698)
    SmartTurretTarget memory ignoredTarget = turretTarget;
    ignoredTarget.shipTypeId = 87698; // Wend

    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    TargetPriority[] memory outputQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, ignoredTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(outputQueue.length, 0, "Target should be removed from queue because of allowed ship type");
  }

  // Test coverage for all allowed types
  function testAllAllowedTypes() public {
    uint256[] memory types = new uint256[](6);
    types[0] = 87160;
    types[1] = 87161;
    types[2] = 87162;
    types[3] = 87566;
    types[4] = 87698;
    types[5] = 81610;

    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);

    for(uint i=0; i<types.length; i++) {
        SmartTurretTarget memory target = SmartTurretTarget({
            shipId: 1,
            shipTypeId: types[i],
            characterId: player2CharacterSmartId, // Use player2 (not in allowed tribe) to force check of shipTypeId
            hpRatio: 50, 
            shieldRatio: 50, 
            armorRatio: 50
        });

        TargetPriority[] memory outputQueue = abi.decode(
          world.call(
            systemId,
            abi.encodeCall(
              CustomSmartTurretSystem.inProximity,
              (smartTurretId, priorityQueue, turret, target)
            )
          ),
          (TargetPriority[])
        );
        
        assertEq(outputQueue.length, 0, "Should be ignored");
    }
  }

  function testUpdateExistingTargetWeight() public {
     SmartTurretTarget memory target = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: player2CharacterSmartId, // Use player 2 (not in allowed tribe)
      hpRatio: 100, // weight 0
      shieldRatio: 100,
      armorRatio: 100
    });

    TargetPriority[] memory priorityQueue = new TargetPriority[](1);
    priorityQueue[0] = TargetPriority({ target: target, weight: 0 });

    // Update target with lower health (higher weight)
    SmartTurretTarget memory updatedTarget = target;
    updatedTarget.hpRatio = 50; // weight 50
    updatedTarget.shieldRatio = 50;
    updatedTarget.armorRatio = 50;
    // New weight should be 300 - 150 = 150

    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    TargetPriority[] memory outputQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, updatedTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(outputQueue.length, 1);
    assertEq(outputQueue[0].weight, 150, "Weight should update to 150");
  }

  function testRemoveFromQueueWithOthers() public {
     SmartTurretTarget memory target1 = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: playerCharacterSmartId,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
     SmartTurretTarget memory target2 = SmartTurretTarget({
      shipId: 2,
      shipTypeId: 1,
      characterId: player2CharacterSmartId,
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });

    TargetPriority[] memory priorityQueue = new TargetPriority[](2);
    priorityQueue[0] = TargetPriority({ target: target1, weight: 150 });
    priorityQueue[1] = TargetPriority({ target: target2, weight: 150 });

    // Remove target1 by making it ignored (Wend)
    SmartTurretTarget memory ignoredTarget = target1;
    ignoredTarget.shipTypeId = 87698; // Wend

    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    TargetPriority[] memory outputQueue = abi.decode(
      world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, ignoredTarget)
        )
      ),
      (TargetPriority[])
    );

    assertEq(outputQueue.length, 1, "Should have 1 remaining");
    assertEq(outputQueue[0].target.characterId, player2CharacterSmartId, "Player 2 should remain");
  }

  function testInProximityInvalidInputs() public {
    SmartTurretTarget memory invalidTarget = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 0, // Invalid
      hpRatio: 50,
      shieldRatio: 50,
      armorRatio: 50
    });
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);

    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid characterId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, invalidTarget)
        )
    );

    // Reset invalidTarget check as we fix it to proceed to next check
    invalidTarget.characterId = playerCharacterSmartId;

    // Test smartTurretId = 0
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid smartTurretId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (0, priorityQueue, turret, invalidTarget)
        )
    );

    // Test invalid turret
    Turret memory invalidTurret = Turret({ weaponTypeId: 0, ammoTypeId: 1, chargesLeft: 100 });
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid turret"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, invalidTurret, invalidTarget)
        )
    );

    invalidTarget.shipTypeId = 0; // Invalid
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid shipTypeId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, invalidTarget)
        )
    );

    invalidTarget.shipTypeId = 1;
    invalidTarget.hpRatio = 101; // Invalid
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid ratio"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.inProximity,
          (smartTurretId, priorityQueue, turret, invalidTarget)
        )
    );
  }

  function testAggressionInvalidInputs() public {
    SmartTurretTarget memory aggressor = SmartTurretTarget({
      shipId: 1,
      shipTypeId: 1,
      characterId: 0, // Invalid
      hpRatio: 100, shieldRatio: 100, armorRatio: 100
    });
    SmartTurretTarget memory victim = SmartTurretTarget({
      shipId: 2,
      shipTypeId: 1,
      characterId: player2CharacterSmartId,
      hpRatio: 100, shieldRatio: 100, armorRatio: 100
    });
    TargetPriority[] memory priorityQueue = new TargetPriority[](0);
    Turret memory turret = Turret({ weaponTypeId: 1, ammoTypeId: 1, chargesLeft: 100 });

    AggressionParams memory params = AggressionParams({
      smartObjectId: smartTurretId,
      priorityQueue: priorityQueue,
      turret: turret,
      aggressor: aggressor,
      victim: victim
    });

    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid aggressor characterId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (params)
        )
    );

    // Fix aggressor
    params.aggressor.characterId = playerCharacterSmartId;

    // Test invalid smartObjectId
    uint256 validId = params.smartObjectId;
    params.smartObjectId = 0;
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid smartTurretId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (params)
        )
    );
    params.smartObjectId = validId; // restore

    // Test invalid turret
    params.turret.weaponTypeId = 0;
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid turret"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (params)
        )
    );
    params.turret.weaponTypeId = 1; // restore

    params.victim.characterId = 0; // Invalid
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Invalid victim characterId"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (params)
        )
    );

    params.victim.characterId = playerCharacterSmartId; // Same as aggressor
    vm.expectRevert(abi.encodeWithSelector(CustomSmartTurretSystem.SmartTurretError.selector, "Aggressor and victim cannot be the same"));
    world.call(
        systemId,
        abi.encodeCall(
          CustomSmartTurretSystem.aggression,
          (params)
        )
    );
  }
}