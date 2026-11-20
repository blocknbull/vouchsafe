// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Antibody, IAgentID} from "../src/Antibody.sol";

interface VmScript {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// FOUNDRY_PROFILE=fork forge script script/Deploy.s.sol --rpc-url bsc --account <keystore-name> --broadcast
/// The deployer gets no privileges: Antibody has no owner. Use an encrypted keystore (`cast wallet import`),
/// never a key in an environment variable.
contract Deploy {
    VmScript constant vm = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));
    IAgentID constant AGENT_ID = IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    function run() external returns (Antibody ab) {
        require(address(AGENT_ID).code.length > 0, "Agent ID contract not found on this chain");
        vm.startBroadcast();
        ab = new Antibody(AGENT_ID);
        vm.stopBroadcast();
    }
}
