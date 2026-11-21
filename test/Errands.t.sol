// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Antibody, IAgentID} from "../src/Antibody.sol";
import {Errands, IShieldIdentity} from "../src/Errands.sol";

interface VmE {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes4) external;
    function expectRevert() external;
    function warp(uint256) external;
    function deal(address, uint256) external;
    function assume(bool) external;
}

contract MockID is IAgentID {
    mapping(address => uint256) public balanceOf;

    function set(address a, uint256 n) external {
        balanceOf[a] = n;
    }
}

/// Re-enters on receiving BNB.
contract Reenterer {
    Errands public target;
    uint256 public id;
    bool public tried;
    bool public reentered;

    function arm(Errands t, uint256 i) external {
        target = t;
        id = i;
    }

    function take(Errands t, uint256 i) external {
        t.take(i);
    }

    function deliver(Errands t, uint256 i) external {
        t.deliver(i, bytes32("r"));
    }

    function doClaim(Errands t, uint256 i) external {
        t.claim(i);
    }

    receive() external payable {
        if (!tried) {
            tried = true;
            try target.claim(id) {
                reentered = true;
            } catch {}
        }
    }
}

/// Refuses all BNB.
contract Refuser {
    function take(Errands t, uint256 i) external {
        t.take(i);
    }

    function deliver(Errands t, uint256 i) external {
        t.deliver(i, bytes32("r"));
    }

    function doWithdraw(Errands t) external {
        t.withdraw();
    }

    function doWithdrawTo(Errands t, address to) external {
        t.withdrawTo(payable(to));
    }

    bool public accept;

    function open() external {
        accept = true;
    }

    receive() external payable {
        require(accept, "no");
    }
}

contract ErrandsTest {
    VmE constant vm = VmE(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockID agent;
    Antibody shield;
    Errands er;

    address poster = address(0xA11CE); //  Agent ID holder
    address posterHot = address(0xA1); //  linked to poster
    address worker = address(0xB0B); //    Agent ID holder
    address workerHot = address(0xB1); //  linked to worker
    address eve = address(0xE7E); //      no Agent ID

    uint40 constant T0 = 1_800_000_000;
    bytes32 constant TASK = keccak256("write a token audit summary");

    function setUp() public {
        vm.warp(T0);
        agent = new MockID();
        shield = new Antibody(agent);
        er = new Errands(IShieldIdentity(address(shield)));
        agent.set(poster, 1);
        agent.set(worker, 1);
        _link(poster, posterHot);
        _link(worker, workerHot);
        vm.deal(poster, 10 ether);
        vm.deal(posterHot, 10 ether);
        vm.deal(worker, 1 ether);
        vm.deal(eve, 10 ether);
    }

    function _link(address id, address wallet) internal {
        vm.prank(id);
        shield.offerLink(wallet);
        vm.prank(wallet);
        shield.acceptLink(id);
    }

    function _eq(uint256 a, uint256 b, string memory m) internal pure {
        require(a == b, m);
    }

    function _post(address from, uint256 reward) internal returns (uint256 id) {
        vm.prank(from);
        id = er.post{value: reward}(TASK, T0 + 1 days, 1 days, address(0));
    }

    function _status(uint256 id) internal view returns (Errands.Status) {
        return er.errand(id).status;
    }

    // ------------------------------------------------------------------ posting

    function test_post_locksReward() public {
        uint256 id = _post(poster, 0.1 ether);
        _eq(address(er).balance, 0.1 ether, "escrowed");
        Errands.Errand memory e = er.errand(id);
        require(e.poster == poster && e.funder == poster && e.status == Errands.Status.OPEN, "stored");
        (uint32 posted,,,,,) = er.records(poster);
        _eq(posted, 1, "posted count");
    }

    function test_post_byLinkedWallet_countsForIdentity() public {
        uint256 id = _post(posterHot, 0.1 ether);
        Errands.Errand memory e = er.errand(id);
        require(e.poster == poster && e.funder == posterHot, "identity vs funder");
    }

    function test_post_requiresAgentID() public {
        vm.expectRevert(Errands.NotAgent.selector);
        vm.prank(eve);
        er.post{value: 0.1 ether}(TASK, T0 + 1 days, 1 days, address(0));
    }

    function test_post_rewardBounds() public {
        vm.expectRevert(Errands.BadReward.selector);
        vm.prank(poster);
        er.post{value: 0}(TASK, T0 + 1 days, 1 days, address(0));
        vm.expectRevert(Errands.BadReward.selector);
        vm.prank(poster);
        er.post{value: 1 ether + 1}(TASK, T0 + 1 days, 1 days, address(0));
    }

    function test_post_deadlineAndReviewBounds() public {
        vm.startPrank(poster);
        vm.expectRevert(Errands.BadDeadline.selector);
        er.post{value: 1}(TASK, T0 + 30 minutes, 1 days, address(0));
        vm.expectRevert(Errands.BadDeadline.selector);
        er.post{value: 1}(TASK, T0 + 91 days, 1 days, address(0));
        vm.expectRevert(Errands.BadReview.selector);
        er.post{value: 1}(TASK, T0 + 1 days, 23 hours, address(0));
        vm.expectRevert(Errands.BadReview.selector);
        er.post{value: 1}(TASK, T0 + 1 days, 15 days, address(0));
        vm.stopPrank();
    }

    // ------------------------------------------------------------------ cancel

    function test_cancel_refundsFunder() public {
        uint256 id = _post(posterHot, 0.2 ether);
        uint256 before = posterHot.balance;
        vm.prank(poster); // identity may cancel; refund goes to the funding wallet
        er.cancel(id);
        _eq(posterHot.balance, before + 0.2 ether, "refund to funder");
        _eq(address(er).balance, 0, "empty");
        require(_status(id) == Errands.Status.CANCELLED, "cancelled");
    }

    function test_cancel_onlyPoster_onlyOpen() public {
        uint256 id = _post(poster, 0.1 ether);
        vm.expectRevert(Errands.NotPoster.selector);
        vm.prank(worker);
        er.cancel(id);
        vm.prank(worker);
        er.take(id);
        vm.expectRevert(Errands.WrongStatus.selector);
        vm.prank(poster);
        er.cancel(id);
    }

    // ------------------------------------------------------------------ take

    function test_take_rules() public {
        uint256 id = _post(poster, 0.1 ether);
        vm.expectRevert(Errands.NotAgent.selector);
        vm.prank(eve);
        er.take(id);
        vm.expectRevert(Errands.OwnErrand.selector);
        vm.prank(poster);
        er.take(id);
        vm.expectRevert(Errands.OwnErrand.selector); // the poster's linked wallet is the same person
        vm.prank(posterHot);
        er.take(id);

        vm.prank(workerHot); // a linked wallet can take for its identity; payment goes to it
        er.take(id);
        Errands.Errand memory e = er.errand(id);
        require(e.worker == worker && e.payee == workerHot, "worker identity, payee wallet");

        vm.expectRevert(Errands.WrongStatus.selector);
        vm.prank(worker);
        er.take(id);
    }

    function test_take_afterDeadline() public {
        uint256 id = _post(poster, 0.1 ether);
        vm.warp(T0 + 1 days);
        vm.expectRevert(Errands.TooLate.selector);
        vm.prank(worker);
        er.take(id);
    }

    // ------------------------------------------------------------------ deliver, release, claim, reject

    function _takenDelivered() internal returns (uint256 id) {
        id = _post(poster, 0.5 ether);
        vm.prank(workerHot);
        er.take(id);
        vm.prank(worker);
        er.deliver(id, bytes32("result"));
    }

    function test_deliver_onlyWorker_beforeDeadline() public {
        uint256 id = _post(poster, 0.1 ether);
        vm.expectRevert(Errands.NotWorker.selector); // not taken yet
        vm.prank(worker);
        er.deliver(id, 0);
        vm.prank(worker);
        er.take(id);
        vm.expectRevert(Errands.NotWorker.selector);
        vm.prank(eve);
        er.deliver(id, 0);
        vm.warp(T0 + 1 days + 1);
        vm.expectRevert(Errands.TooLate.selector);
        vm.prank(worker);
        er.deliver(id, 0);
    }

    function test_release_paysPayee_andRecords() public {
        uint256 id = _takenDelivered();
        uint256 before = workerHot.balance;
        vm.prank(posterHot); // poster's linked wallet may release
        er.release(id);
        _eq(workerHot.balance, before + 0.5 ether, "paid to payee");
        _eq(address(er).balance, 0, "empty");
        (, uint32 done,,,,) = er.records(worker);
        (,, uint32 paid,,,) = er.records(poster);
        _eq(done, 1, "worker completed");
        _eq(paid, 1, "poster paid");
        vm.expectRevert(Errands.WrongStatus.selector); // no double payment
        vm.prank(poster);
        er.release(id);
    }

    function test_release_onlyAfterDelivery_onlyPoster() public {
        uint256 id = _post(poster, 0.1 ether);
        vm.prank(worker);
        er.take(id);
        vm.expectRevert(Errands.WrongStatus.selector);
        vm.prank(poster);
        er.release(id);
        vm.prank(worker);
        er.deliver(id, 0);
        vm.expectRevert(Errands.NotPoster.selector);
        vm.prank(worker);
        er.release(id);
    }

    function test_claim_afterReviewWindow() public {
        uint256 id = _takenDelivered();
        vm.warp(T0 + 1 days - 1); // review window is 1 day from delivery at T0
        vm.expectRevert(Errands.TooEarly.selector);
        vm.prank(worker);
        er.claim(id);
        vm.warp(T0 + 1 days);
        uint256 before = workerHot.balance;
        vm.prank(worker);
        er.claim(id);
        _eq(workerHot.balance, before + 0.5 ether, "claimed");
        vm.expectRevert(Errands.WrongStatus.selector);
        vm.prank(poster);
        er.reject(id);
    }

    function test_claim_onlyWorker() public {
        uint256 id = _takenDelivered();
        vm.warp(T0 + 2 days);
        vm.expectRevert(Errands.NotWorker.selector);
        vm.prank(eve);
        er.claim(id);
    }

    function test_reject_withinWindow_refunds_andRecordsBothSides() public {
        uint256 id = _takenDelivered();
        uint256 before = poster.balance;
        vm.prank(poster);
        er.reject(id);
        _eq(poster.balance, before + 0.5 ether, "refunded");
        (,,, uint32 recv,,) = er.records(worker);
        (,,,, uint32 issued,) = er.records(poster);
        _eq(recv, 1, "worker rejection received");
        _eq(issued, 1, "poster rejection issued");
        require(_status(id) == Errands.Status.REJECTED, "rejected");
    }

    function test_reject_afterWindow_fails() public {
        uint256 id = _takenDelivered();
        vm.warp(T0 + 1 days);
        vm.expectRevert(Errands.TooLate.selector);
        vm.prank(poster);
        er.reject(id);
    }

    // ------------------------------------------------------------------ reclaim

    function test_reclaim_afterMissedDeadline() public {
        uint256 id = _post(poster, 0.3 ether);
        vm.prank(worker);
        er.take(id);
        vm.expectRevert(Errands.TooEarly.selector);
        vm.prank(poster);
        er.reclaim(id);
        vm.warp(T0 + 1 days + 1);
        uint256 before = poster.balance;
        vm.prank(poster);
        er.reclaim(id);
        _eq(poster.balance, before + 0.3 ether, "reclaimed");
        (,,,,, uint32 expired) = er.records(worker);
        _eq(expired, 1, "expiry recorded");
    }

    function test_reclaim_notAfterDelivery() public {
        uint256 id = _takenDelivered();
        vm.warp(T0 + 3 days);
        vm.expectRevert(Errands.WrongStatus.selector);
        vm.prank(poster);
        er.reclaim(id);
    }

    // ------------------------------------------------------------------ lost Agent ID cannot strand funds

    function test_lostAgentID_funderCanStillCancel() public {
        uint256 id = _post(poster, 0.4 ether);
        agent.set(poster, 0);
        uint256 before = poster.balance;
        vm.prank(poster);
        er.cancel(id);
        _eq(poster.balance, before + 0.4 ether, "funder refunded without Agent ID");
    }

    function test_lostAgentID_payeeCanStillClaim() public {
        uint256 id = _takenDelivered();
        agent.set(worker, 0); // workerHot's link no longer resolves
        vm.warp(T0 + 2 days);
        uint256 before = workerHot.balance;
        vm.prank(workerHot);
        er.claim(id);
        _eq(workerHot.balance, before + 0.5 ether, "payee claimed without Agent ID");
    }

    // ------------------------------------------------------------------ hostile payees

    function test_reentrantPayee_cannotDoublePay() public {
        Reenterer r = new Reenterer();
        agent.set(address(r), 1);
        uint256 id = _post(poster, 0.5 ether);
        r.take(er, id);
        r.deliver(er, id);
        r.arm(er, id);
        vm.warp(T0 + 2 days);
        uint256 before = address(r).balance;
        r.doClaim(er, id);
        require(r.tried() && !r.reentered(), "reentry blocked");
        // the push used 30k gas; a reverting reentry inside receive() is caught, so the push itself succeeds
        _eq(address(r).balance + er.owed(address(r)), before + 0.5 ether, "paid exactly once");
        _eq(address(er).balance, er.owed(address(r)), "escrow holds only what is owed");
    }

    function test_refusingPayee_isCredited_thenWithdraws() public {
        Refuser bad = new Refuser();
        agent.set(address(bad), 1);
        uint256 id = _post(poster, 0.5 ether);
        bad.take(er, id);
        bad.deliver(er, id);
        vm.prank(poster);
        er.release(id); // must not revert even though the payee refuses BNB
        _eq(er.owed(address(bad)), 0.5 ether, "credited");
        _eq(address(er).balance, 0.5 ether, "held until withdrawn");
        bad.open();
        bad.doWithdraw(er);
        _eq(address(bad).balance, 0.5 ether, "withdrawn");
        _eq(er.owed(address(bad)), 0, "cleared");
        vm.expectRevert(Errands.NothingOwed.selector);
        bad.doWithdraw(er);
    }

    function test_assignee_onlyThatIdentityTakes() public {
        agent.set(eve, 1); // a third holder
        vm.prank(poster);
        uint256 id = er.post{value: 0.1 ether}(TASK, T0 + 1 days, 1 days, worker);
        vm.expectRevert(Errands.NotAssignee.selector);
        vm.prank(eve);
        er.take(id);
        vm.prank(workerHot); // the assignee's linked wallet counts as the assignee
        er.take(id);
        require(er.errand(id).worker == worker, "assignee took it");
    }

    function test_funderCannotTakeOwnErrand_evenAfterRelinking() public {
        uint256 id = _post(posterHot, 0.1 ether);
        address other = address(0x0717);
        agent.set(other, 1);
        vm.prank(posterHot);
        shield.unlink();
        vm.prank(other);
        shield.offerLink(posterHot);
        vm.prank(posterHot);
        shield.acceptLink(other); // posterHot now resolves to a different identity
        vm.expectRevert(Errands.OwnErrand.selector);
        vm.prank(posterHot);
        er.take(id);
    }

    function test_withdrawTo_forWalletsThatCannotReceive() public {
        Refuser bad = new Refuser();
        agent.set(address(bad), 1);
        uint256 id = _post(poster, 0.5 ether);
        bad.take(er, id);
        bad.deliver(er, id);
        vm.prank(poster);
        er.release(id);
        address rescue = address(0x5AFE);
        bad.doWithdrawTo(er, rescue); // never opens its own receive()
        _eq(rescue.balance, 0.5 ether, "paid out to the named address");
        _eq(er.owed(address(bad)), 0, "cleared");
    }

    function test_unknownErrand() public {
        vm.expectRevert(Errands.UnknownErrand.selector);
        er.errand(0);
        vm.expectRevert(Errands.UnknownErrand.selector);
        vm.prank(worker);
        er.take(7);
    }

    // ------------------------------------------------------------------ conservation (fuzz)

    /// Any reward, any path: the contract never holds more or less than the rewards of unsettled errands,
    /// and every settled errand's reward lands with exactly one party.
    function testFuzz_conservation(uint96 reward, uint8 path, uint32 lateBy) public {
        vm.assume(reward > 0 && reward <= 1 ether);
        uint256 id = _post(poster, reward);
        uint256 p0 = poster.balance;
        uint256 w0 = workerHot.balance;
        uint8 p = path % 5;
        if (p == 0) {
            vm.prank(poster);
            er.cancel(id);
            _eq(poster.balance, p0 + reward, "cancel");
        } else {
            vm.prank(workerHot);
            er.take(id);
            if (p == 4) {
                vm.warp(uint256(T0) + 1 days + 1 + (lateBy % 30 days));
                vm.prank(poster);
                er.reclaim(id);
                _eq(poster.balance, p0 + reward, "reclaim");
            } else {
                vm.prank(worker);
                er.deliver(id, bytes32("x"));
                if (p == 1) {
                    vm.prank(poster);
                    er.release(id);
                    _eq(workerHot.balance, w0 + reward, "release");
                } else if (p == 2) {
                    vm.prank(poster);
                    er.reject(id);
                    _eq(poster.balance, p0 + reward, "reject");
                } else {
                    vm.warp(uint256(T0) + 1 days + (lateBy % 30 days));
                    vm.prank(worker);
                    er.claim(id);
                    _eq(workerHot.balance, w0 + reward, "claim");
                }
            }
        }
        _eq(address(er).balance, 0, "nothing left behind");
    }
}
