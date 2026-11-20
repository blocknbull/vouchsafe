// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Antibody, IAgentID} from "../src/Antibody.sol";

// No forge-std: the few cheatcodes needed are declared here, so the repo has zero dependencies.
interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes4) external;
    function warp(uint256) external;
}

contract MockAgentID is IAgentID {
    mapping(address => uint256) public balanceOf;

    function set(address a, uint256 n) external {
        balanceOf[a] = n;
    }
}

contract Owned {
    address public owner;

    constructor(address o) {
        owner = o;
    }
}

contract AntibodyTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockAgentID id;
    Antibody ab;

    address alice = address(0xA11CE); // Agent ID holder
    address bob = address(0xB0B); //     Agent ID holder
    address eve = address(0xE7E); //     no Agent ID
    address aliceHot = address(0xA1); // Alice's ordinary wallet
    address token = address(0x70CE);

    function setUp() public {
        id = new MockAgentID();
        ab = new Antibody(id);
        id.set(alice, 1);
        id.set(bob, 1);
    }

    function _eq(uint256 a, uint256 b, string memory m) internal pure {
        require(a == b, m);
    }

    // ---------------------------------------------------------------- reporting

    function test_holderReports() public {
        vm.prank(alice);
        ab.report(token, Antibody.Verdict.HONEYPOT, bytes32("ev1"));
        (uint32[6] memory c, uint32 total) = ab.riskOf(token);
        _eq(c[uint8(Antibody.Verdict.HONEYPOT)], 1, "honeypot count");
        _eq(total, 1, "total");
        (Antibody.Verdict v,, bytes32 ev) = ab.votes(token, alice);
        require(v == Antibody.Verdict.HONEYPOT && ev == bytes32("ev1"), "stored vote");
    }

    function test_nonHolderCannotReport() public {
        vm.expectRevert(Antibody.NotAgent.selector);
        vm.prank(eve);
        ab.report(token, Antibody.Verdict.RUG, 0);
    }

    function test_oneVotePerIdentity_changeReplaces() public {
        vm.startPrank(alice);
        ab.report(token, Antibody.Verdict.SAFE, 0);
        ab.report(token, Antibody.Verdict.RUG, 0);
        ab.report(token, Antibody.Verdict.RUG, 0);
        vm.stopPrank();
        (uint32[6] memory c, uint32 total) = ab.riskOf(token);
        _eq(c[uint8(Antibody.Verdict.SAFE)], 0, "safe moved away");
        _eq(c[uint8(Antibody.Verdict.RUG)], 1, "rug once");
        _eq(total, 1, "still one vote");
    }

    function test_twoHoldersTwoVotes() public {
        vm.prank(alice);
        ab.report(token, Antibody.Verdict.DRAINER, 0);
        vm.prank(bob);
        ab.report(token, Antibody.Verdict.DRAINER, 0);
        (, uint32 total) = ab.riskOf(token);
        _eq(total, 2, "two identities");
    }

    function test_retract() public {
        vm.startPrank(alice);
        ab.report(token, Antibody.Verdict.PHISHING, 0);
        ab.retract(token);
        vm.stopPrank();
        (, uint32 total) = ab.riskOf(token);
        _eq(total, 0, "retracted");
        vm.expectRevert(Antibody.NoVote.selector);
        vm.prank(alice);
        ab.retract(token);
    }

    function test_rejectsNoneVerdictAndBadTarget() public {
        vm.expectRevert(Antibody.BadVerdict.selector);
        vm.prank(alice);
        ab.report(token, Antibody.Verdict.NONE, 0);
        vm.expectRevert(Antibody.BadTarget.selector);
        vm.prank(alice);
        ab.report(address(0), Antibody.Verdict.RUG, 0);
        vm.expectRevert(Antibody.BadTarget.selector);
        vm.prank(alice);
        ab.report(address(ab), Antibody.Verdict.RUG, 0);
    }

    function test_lostAgentIdCannotReport() public {
        id.set(alice, 0);
        vm.expectRevert(Antibody.NotAgent.selector);
        vm.prank(alice);
        ab.report(token, Antibody.Verdict.RUG, 0);
    }

    // ---------------------------------------------------------------- Agent Link

    function _link() internal {
        vm.prank(alice);
        ab.offerLink(aliceHot);
        vm.prank(aliceHot);
        ab.acceptLink(alice);
    }

    function test_linkedWalletActsForIdentity_withoutSecondVote() public {
        _link();
        require(ab.isAgentBacked(aliceHot), "linked wallet backed");
        require(ab.identityOf(aliceHot) == alice, "identity");

        vm.prank(alice);
        ab.report(token, Antibody.Verdict.SAFE, 0);
        vm.prank(aliceHot);
        ab.report(token, Antibody.Verdict.HONEYPOT, 0);

        (uint32[6] memory c, uint32 total) = ab.riskOf(token);
        _eq(total, 1, "same identity, one vote");
        _eq(c[uint8(Antibody.Verdict.HONEYPOT)], 1, "latest verdict wins");
        (Antibody.Verdict v,,) = ab.votes(token, alice);
        require(v == Antibody.Verdict.HONEYPOT, "keyed by identity");
    }

    function test_linkNeedsBothSides() public {
        vm.expectRevert(Antibody.NoOffer.selector);
        vm.prank(aliceHot);
        ab.acceptLink(alice);

        vm.prank(alice);
        ab.offerLink(aliceHot);
        require(!ab.isAgentBacked(aliceHot), "offer alone is not a link");

        vm.expectRevert(Antibody.NoOffer.selector); // eve cannot take an offer made to aliceHot
        vm.prank(eve);
        ab.acceptLink(alice);
    }

    function test_nonHolderCannotOffer() public {
        vm.expectRevert(Antibody.NotAgent.selector);
        vm.prank(eve);
        ab.offerLink(aliceHot);
    }

    function test_cannotLinkAnotherHolderOrSelf() public {
        vm.expectRevert(Antibody.BadWallet.selector);
        vm.prank(alice);
        ab.offerLink(bob);
        vm.expectRevert(Antibody.BadWallet.selector);
        vm.prank(alice);
        ab.offerLink(alice);
    }

    function test_walletServesOneIdentity() public {
        _link();
        vm.prank(bob);
        ab.offerLink(aliceHot);
        vm.expectRevert(Antibody.BadWallet.selector);
        vm.prank(aliceHot);
        ab.acceptLink(bob);
    }

    function test_relinkReplacesOldWallet() public {
        _link();
        address newHot = address(0xA2);
        vm.prank(alice);
        ab.offerLink(newHot);
        vm.prank(newHot);
        ab.acceptLink(alice);
        require(!ab.isAgentBacked(aliceHot), "old wallet released");
        require(ab.identityOf(newHot) == alice, "new wallet linked");
    }

    function test_eitherSideUnlinks() public {
        _link();
        vm.prank(aliceHot);
        ab.unlink();
        require(!ab.isAgentBacked(aliceHot), "wallet side unlinked");

        _link();
        vm.prank(alice);
        ab.unlink();
        require(!ab.isAgentBacked(aliceHot), "identity side unlinked");
        require(ab.isAgentBacked(alice), "holder still backed");

        vm.expectRevert(Antibody.NotLinked.selector);
        vm.prank(eve);
        ab.unlink();
    }

    function test_linkedWalletLosesBackingIfIdentityLosesAgentId() public {
        _link();
        id.set(alice, 0);
        require(!ab.isAgentBacked(aliceHot), "backing follows the Agent ID");
        vm.expectRevert(Antibody.NotAgent.selector);
        vm.prank(aliceHot);
        ab.report(token, Antibody.Verdict.RUG, 0);
    }

    // ---------------------------------------------------------------- respond

    function test_ownerResponds_othersCannot() public {
        address dev = address(0xDE5);
        Owned proj = new Owned(dev);
        vm.prank(dev);
        ab.respond(address(proj), bytes32("audit"));

        vm.expectRevert(Antibody.NotTargetOwner.selector);
        vm.prank(eve);
        ab.respond(address(proj), 0);

        vm.expectRevert(Antibody.NotTargetOwner.selector); // no owner() at all
        vm.prank(dev);
        ab.respond(token, 0);

        Owned renounced = new Owned(address(0));
        vm.expectRevert(Antibody.NotTargetOwner.selector);
        vm.prank(address(0));
        ab.respond(address(renounced), 0);
    }
}
