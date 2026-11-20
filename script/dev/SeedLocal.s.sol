// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Antibody, IAgentID} from "../../src/Antibody.sol";

// LOCAL DEMO DATA ONLY. Builds a fake Agent ID, fake tokens and a spread of votes on a local anvil node, so the
// indexer and page can be developed before real reports exist. Never run against a public chain.
//
//   anvil --auto-impersonate &
//   forge script script/dev/SeedLocal.s.sol --rpc-url http://127.0.0.1:8545 --unlocked --sender 0x00000000000000000000000000000000000de710 --broadcast --tc SeedLocal

interface VmSeed {
    function startBroadcast(address) external;
    function stopBroadcast() external;
}

contract FakeAgentID is IAgentID {
    mapping(address => uint256) public balanceOf;

    function give(address a) external {
        balanceOf[a] = 1;
    }
}

contract FakeToken {
    string public name;
    string public symbol;
    address public owner;

    constructor(string memory n, string memory s, address o) {
        name = n;
        symbol = s;
        owner = o;
    }
}

contract SeedLocal {
    VmSeed constant vm = VmSeed(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant DEPLOYER = address(0xdE710);

    function run() external {
        require(block.chainid == 31337, "local anvil only");
        vm.startBroadcast(DEPLOYER);
        FakeAgentID id = new FakeAgentID();
        Antibody ab = new Antibody(id);
        address dev = address(0xD0D0);
        FakeToken good = new FakeToken("Steady Coin", "STDY", dev);
        FakeToken pot = new FakeToken("Moon Inu", "MINU", dev);
        FakeToken rug = new FakeToken("Agent Gold", "AGLD", address(0));
        address drainer = address(0xBADBADBADBAD);
        address phish = address(0x5CA3);
        vm.stopBroadcast();

        address[9] memory who;
        for (uint160 i = 0; i < 9; i++) {
            who[i] = address(0x1000 + i);
            vm.startBroadcast(DEPLOYER);
            id.give(who[i]);
            vm.stopBroadcast();
        }

        // Steady Coin: settles SAFE, one dissent
        _vote(ab, who[0], address(good), Antibody.Verdict.SAFE);
        _vote(ab, who[1], address(good), Antibody.Verdict.SAFE);
        _vote(ab, who[2], address(good), Antibody.Verdict.SAFE);
        _vote(ab, who[3], address(good), Antibody.Verdict.SAFE);
        _vote(ab, who[4], address(good), Antibody.Verdict.HONEYPOT);

        // Moon Inu: settles harmful; who[5] first says SAFE, then changes to HONEYPOT; owner responds
        _vote(ab, who[5], address(pot), Antibody.Verdict.SAFE);
        _vote(ab, who[0], address(pot), Antibody.Verdict.HONEYPOT);
        _vote(ab, who[1], address(pot), Antibody.Verdict.HONEYPOT);
        _vote(ab, who[6], address(pot), Antibody.Verdict.HONEYPOT);
        _vote(ab, who[5], address(pot), Antibody.Verdict.HONEYPOT);
        _vote(ab, who[7], address(pot), Antibody.Verdict.SAFE);
        vm.startBroadcast(dev);
        ab.respond(address(pot), keccak256("our sell tax is 10%, see docs"));
        vm.stopBroadcast();

        // Agent Gold: rug, ownership renounced (cannot respond)
        _vote(ab, who[2], address(rug), Antibody.Verdict.RUG);
        _vote(ab, who[3], address(rug), Antibody.Verdict.RUG);
        _vote(ab, who[8], address(rug), Antibody.Verdict.RUG);

        // An EOA drainer, and a phishing address with too few votes to settle
        _vote(ab, who[0], drainer, Antibody.Verdict.DRAINER);
        _vote(ab, who[6], drainer, Antibody.Verdict.DRAINER);
        _vote(ab, who[7], drainer, Antibody.Verdict.DRAINER);
        _vote(ab, who[8], drainer, Antibody.Verdict.DRAINER);
        _vote(ab, who[4], phish, Antibody.Verdict.PHISHING);

        // a retraction, and an Agent Link whose wallet then votes for its identity
        _vote(ab, who[3], phish, Antibody.Verdict.PHISHING);
        vm.startBroadcast(who[3]);
        ab.retract(phish);
        ab.offerLink(address(0xA0A0));
        vm.stopBroadcast();
        vm.startBroadcast(address(0xA0A0));
        ab.acceptLink(who[3]);
        ab.report(phish, Antibody.Verdict.PHISHING, keccak256("lookalike of a known dApp"));
        vm.stopBroadcast();
    }

    function _vote(Antibody ab, address from, address target, Antibody.Verdict v) internal {
        vm.startBroadcast(from);
        ab.report(target, v, keccak256(abi.encode(from, target, v)));
        vm.stopBroadcast();
    }
}
