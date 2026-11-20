// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Antibody, IAgentID} from "../../src/Antibody.sol";

interface VmFork {
    function createSelectFork(string calldata) external returns (uint256);
    function prank(address) external;
    function expectRevert(bytes4) external;
}

/// Runs against BNB Chain mainnet state. Run with:  forge test --match-path 'test/fork/*'
/// Agent ID contract from the Agent ID Hackathon announcement (binance.com, 2026-11-18).
contract AntibodyForkTest {
    VmFork constant vm = VmFork(address(uint160(uint256(keccak256("hevm cheat code")))));

    IAgentID constant AGENT_ID = IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);
    address constant HOLDER = 0xc75550Bbd81eA3B0c356BfD57c232C4Ba5dfeFcc; // an agentic wallet holding an Agent ID
    address constant NON_HOLDER = 0xB5E82271D2c355F608032606995359A613809d49; // the Antibody deployer: holds no Agent ID
    address constant TARGET = 0x55d398326f99059fF775485246999027B3197955; // any contract; BSC-USD used here

    Antibody ab;

    function setUp() public {
        vm.createSelectFork("bsc");
        require(AGENT_ID.balanceOf(HOLDER) > 0, "fixture: holder must hold an Agent ID");
        require(AGENT_ID.balanceOf(NON_HOLDER) == 0, "fixture: non-holder must not");
        ab = new Antibody(AGENT_ID);
    }

    function test_realHolderReports_realNonHolderRefused() public {
        vm.prank(HOLDER);
        ab.report(TARGET, Antibody.Verdict.SAFE, bytes32("fork"));
        (, uint32 total) = ab.riskOf(TARGET);
        require(total == 1, "one vote");

        vm.expectRevert(Antibody.NotAgent.selector);
        vm.prank(NON_HOLDER);
        ab.report(TARGET, Antibody.Verdict.RUG, 0);
    }

    function test_realLink() public {
        vm.prank(HOLDER);
        ab.offerLink(NON_HOLDER);
        vm.prank(NON_HOLDER);
        ab.acceptLink(HOLDER);
        require(ab.isAgentBacked(NON_HOLDER), "linked wallet backed by a real Agent ID");

        vm.prank(NON_HOLDER);
        ab.report(TARGET, Antibody.Verdict.SAFE, 0);
        (Antibody.Verdict v,,) = ab.votes(TARGET, HOLDER);
        require(v == Antibody.Verdict.SAFE, "vote recorded against the identity");
    }
}
