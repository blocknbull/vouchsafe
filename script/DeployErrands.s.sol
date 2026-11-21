// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Errands, IShieldIdentity} from "../src/Errands.sol";

interface VmScriptE {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// FOUNDRY_PROFILE=fork forge script script/DeployErrands.s.sol --rpc-url bsc --account <keystore-name> --broadcast
/// Errands has no owner: the deployer gets no privileges. It resolves identities through the live Shield.
contract DeployErrands {
    VmScriptE constant vm = VmScriptE(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant SHIELD = 0x81f1A94Ad7E4d6f9a8c349f21E4749d694751F5B;

    function run() external returns (Errands er) {
        require(SHIELD.code.length > 0, "Shield not found on this chain");
        vm.startBroadcast();
        er = new Errands(IShieldIdentity(SHIELD));
        vm.stopBroadcast();
    }
}
