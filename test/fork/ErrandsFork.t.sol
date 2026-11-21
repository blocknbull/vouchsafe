// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Errands, IShieldIdentity} from "../../src/Errands.sol";

interface VmF {
    function createSelectFork(string calldata) external returns (uint256);
    function prank(address) external;
    function deal(address, uint256) external;
    function warp(uint256) external;
    function expectRevert(bytes4) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
}

interface IBal {
    function balanceOf(address) external view returns (uint256);
}

/// Errands wired to the LIVE Shield (0x81f1…1F5B) and the LIVE Agent ID contract on BNB Chain.
/// The poster is a real agentic wallet holding a real Agent ID. No second holder's address is used here, so the
/// worker's Agent ID is mocked at the Agent ID contract (balanceOf -> 1 for one test address); everything else,
/// including Shield's identity resolution, runs as deployed.
/// Run with: FOUNDRY_PROFILE=fork forge test --match-path 'test/fork/*'
contract ErrandsForkTest {
    VmF constant vm = VmF(address(uint160(uint256(keccak256("hevm cheat code")))));

    address constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    address constant SHIELD = 0x81f1A94Ad7E4d6f9a8c349f21E4749d694751F5B;
    address constant HOLDER = 0xc75550Bbd81eA3B0c356BfD57c232C4Ba5dfeFcc; // real Agent ID holder
    address constant NON_HOLDER = 0xB5E82271D2c355F608032606995359A613809d49; // the deployer, no Agent ID
    address constant WORKER = address(0xB0B0B0); //                          mocked holder

    Errands er;

    function setUp() public {
        vm.createSelectFork("bsc");
        require(IBal(AGENT_ID).balanceOf(HOLDER) > 0, "fixture: holder");
        require(IBal(AGENT_ID).balanceOf(NON_HOLDER) == 0, "fixture: non-holder");
        er = new Errands(IShieldIdentity(SHIELD));
        vm.mockCall(AGENT_ID, abi.encodeWithSelector(IBal.balanceOf.selector, WORKER), abi.encode(uint256(1)));
        vm.deal(HOLDER, 1 ether);
        vm.deal(NON_HOLDER, 1 ether);
    }

    function test_liveIdentity_fullLifecycle() public {
        vm.prank(HOLDER);
        uint256 id = er.post{value: 0.01 ether}(keccak256("fork task"), uint40(block.timestamp + 1 days), 1 days, address(0));

        vm.expectRevert(Errands.OwnErrand.selector);
        vm.prank(HOLDER);
        er.take(id);

        vm.expectRevert(Errands.NotAgent.selector);
        vm.prank(NON_HOLDER);
        er.take(id);

        vm.prank(WORKER);
        er.take(id);
        vm.prank(WORKER);
        er.deliver(id, keccak256("fork result"));

        uint256 before = WORKER.balance;
        vm.prank(HOLDER);
        er.release(id);
        require(WORKER.balance == before + 0.01 ether, "worker paid");
        require(address(er).balance == 0, "escrow empty");
        (, uint32 done,,,,) = er.records(WORKER);
        require(done == 1, "completion recorded against identity");
    }

    function test_liveIdentity_nonHolderCannotPost() public {
        vm.expectRevert(Errands.NotAgent.selector);
        vm.prank(NON_HOLDER);
        er.post{value: 0.01 ether}(bytes32(0), uint40(block.timestamp + 1 days), 1 days, address(0));
    }
}
