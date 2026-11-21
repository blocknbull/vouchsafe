// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// Shield (src/Antibody.sol) resolves an address to the Agent ID identity it acts for: itself if it holds an
/// Agent ID, or the identity it is linked to through Agent Link. Errands reuses that instead of re-implementing it.
interface IShieldIdentity {
    function identityOf(address who) external view returns (address);
}

/// @title  Errands
/// @notice A job board for agents on BNB Chain. A poster locks a BNB reward in escrow for a task; another Agent ID
///         holder takes it, delivers a result hash before the deadline, and is paid when the poster releases (or
///         automatically claimable after a review window if the poster goes silent). Every completed, rejected and
///         expired errand is counted against the Agent ID identities involved, so reputation belongs to a person
///         and cannot be farmed with fresh wallets.
///
/// @dev    PERMISSIONS: none. No owner, admin, pauser, upgrade path, fee, token or withdrawal by anyone but the
///         party owed. Escrowed BNB can go to exactly two places: the worker's payee address, or back to the
///         wallet that funded the errand. Nothing else in this contract can move it.
///
///         Rules, in full:
///         - post:    an Agent ID identity locks 0 < reward <= MAX_REWARD with a deadline, a review window of
///                    1 to 14 days, and optionally an assignee.
///         - cancel:  the poster (its identity, or the funding wallet), while the errand is OPEN, gets a full refund.
///         - take:    a different identity (not the poster's, not the poster's linked wallet, never the funding
///                    wallet) accepts, before the deadline; if the poster named an assignee, only that identity.
///                    The address that takes it is where payment goes, and stays so even if it is later unlinked.
///         - deliver: the worker's identity submits a result hash, before the deadline.
///         - release: the poster's identity pays the worker after delivery.
///         - reject:  the poster's identity refunds itself after delivery, within the review window. Recorded
///                    publicly as a rejection issued (poster) and received (worker).
///         - claim:   the worker's identity takes payment once the review window has passed with no decision.
///         - reclaim: the poster's identity refunds itself if the deadline passed without delivery. Recorded as an
///                    expiry against the worker.
///         The funding wallet always acts as the poster and the taking wallet always acts as the worker, so no
///         errand can strand funds if an Agent ID is ever lost. A payment to an address that refuses it is credited
///         to `owed` and collected with `withdraw()`.
contract Errands {
    uint256 public constant MAX_REWARD = 1 ether; //    beta cap; fixed, since nothing can change it
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 90 days;
    uint256 public constant MIN_REVIEW = 1 days; //   long enough that a junk delivery can't slip past an offline poster
    uint256 public constant MAX_REVIEW = 14 days;

    IShieldIdentity public immutable shield;

    enum Status {
        NONE,
        OPEN,
        TAKEN,
        DELIVERED,
        PAID,
        REJECTED,
        REFUNDED, // deadline passed without delivery
        CANCELLED
    }

    struct Errand {
        address poster; //      identity
        address funder; //      wallet that paid; refunds go here
        address worker; //      identity
        address payee; //       wallet that took it; payment goes here
        address assignee; //    if set, the only identity that may take it
        uint96 reward;
        uint40 deadline;
        uint40 deliveredAt;
        uint32 reviewWindow;
        Status status;
        bytes32 task; //        hash of the task description
        bytes32 result; //      hash of the delivered result
    }

    struct Record {
        uint32 posted;
        uint32 completedAsWorker;
        uint32 paidAsPoster;
        uint32 rejectionsReceived;
        uint32 rejectionsIssued;
        uint32 expiredAsWorker;
    }

    Errand[] internal _errands;
    mapping(address => Record) public records; // identity => record
    mapping(address => uint256) public owed; //   payments that could not be pushed

    uint256 private _lock = 1;

    event Posted(uint256 indexed id, address indexed poster, uint256 reward, uint40 deadline, uint32 reviewWindow, bytes32 task, address assignee);
    event Cancelled(uint256 indexed id);
    event Taken(uint256 indexed id, address indexed worker, address payee);
    event Delivered(uint256 indexed id, bytes32 result);
    event Paid(uint256 indexed id, address indexed worker, address payee, uint256 amount, bool claimed);
    event Rejected(uint256 indexed id, address indexed worker);
    event Reclaimed(uint256 indexed id, address indexed worker);
    event Withdrawn(address indexed to, uint256 amount);

    error NotAgent();
    error BadReward();
    error BadDeadline();
    error BadReview();
    error NotPoster();
    error NotWorker();
    error OwnErrand();
    error WrongStatus();
    error TooLate();
    error TooEarly();
    error NothingOwed();
    error Reentrant();
    error UnknownErrand();
    error NotAssignee();

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrant();
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(IShieldIdentity shield_) {
        shield = shield_;
    }

    // ------------------------------------------------------------------ views

    function errand(uint256 id) external view returns (Errand memory) {
        if (id >= _errands.length) revert UnknownErrand();
        return _errands[id];
    }

    function count() external view returns (uint256) {
        return _errands.length;
    }

    // ------------------------------------------------------------------ poster

    /// @notice Lock `msg.value` as the reward for a task. `task` is the hash of the task description, published
    ///         wherever the poster likes; the contract only stores the hash. `assignee` is an Agent ID identity that
    ///         alone may take it, or address(0) to open it to any Agent ID holder.
    function post(bytes32 task, uint40 deadline, uint32 reviewWindow, address assignee)
        external
        payable
        nonReentrant
        returns (uint256 id)
    {
        address me = _identity(msg.sender);
        if (msg.value == 0 || msg.value > MAX_REWARD) revert BadReward();
        if (deadline < block.timestamp + MIN_DURATION || deadline > block.timestamp + MAX_DURATION) revert BadDeadline();
        if (reviewWindow < MIN_REVIEW || reviewWindow > MAX_REVIEW) revert BadReview();

        id = _errands.length;
        _errands.push(
            Errand({
                poster: me,
                funder: msg.sender,
                worker: address(0),
                payee: address(0),
                assignee: assignee,
                reward: uint96(msg.value),
                deadline: deadline,
                deliveredAt: 0,
                reviewWindow: reviewWindow,
                status: Status.OPEN,
                task: task,
                result: bytes32(0)
            })
        );
        records[me].posted += 1;
        emit Posted(id, me, msg.value, deadline, reviewWindow, task, assignee);
    }

    /// @notice Withdraw an errand nobody has taken. Full refund to the funding wallet.
    function cancel(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isPoster(e)) revert NotPoster();
        if (e.status != Status.OPEN) revert WrongStatus();
        e.status = Status.CANCELLED;
        emit Cancelled(id);
        _pay(e.funder, e.reward);
    }

    /// @notice Accept the delivery and pay the worker.
    function release(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isPoster(e)) revert NotPoster();
        if (e.status != Status.DELIVERED) revert WrongStatus();
        _settlePaid(id, e, false);
    }

    /// @notice Refuse the delivery within the review window. The refund goes to the funding wallet, and the
    ///         rejection is recorded publicly against both identities.
    function reject(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isPoster(e)) revert NotPoster();
        if (e.status != Status.DELIVERED) revert WrongStatus();
        if (block.timestamp >= uint256(e.deliveredAt) + e.reviewWindow) revert TooLate();
        e.status = Status.REJECTED;
        records[e.poster].rejectionsIssued += 1;
        records[e.worker].rejectionsReceived += 1;
        emit Rejected(id, e.worker);
        _pay(e.funder, e.reward);
    }

    /// @notice The deadline passed and nothing was delivered: refund the poster, record the expiry on the worker.
    function reclaim(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isPoster(e)) revert NotPoster();
        if (e.status != Status.TAKEN) revert WrongStatus();
        if (block.timestamp <= e.deadline) revert TooEarly();
        e.status = Status.REFUNDED;
        records[e.worker].expiredAsWorker += 1;
        emit Reclaimed(id, e.worker);
        _pay(e.funder, e.reward);
    }

    // ------------------------------------------------------------------ worker

    /// @notice Take an open errand. Payment will go to the address that calls this.
    function take(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        address me = _identity(msg.sender);
        if (e.status != Status.OPEN) revert WrongStatus();
        if (me == e.poster || msg.sender == e.funder) revert OwnErrand();
        if (e.assignee != address(0) && me != e.assignee) revert NotAssignee();
        if (block.timestamp >= e.deadline) revert TooLate();
        e.status = Status.TAKEN;
        e.worker = me;
        e.payee = msg.sender;
        emit Taken(id, me, msg.sender);
    }

    /// @notice Submit the hash of the result before the deadline.
    function deliver(uint256 id, bytes32 result) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isWorker(e)) revert NotWorker();
        if (e.status != Status.TAKEN) revert WrongStatus();
        if (block.timestamp > e.deadline) revert TooLate();
        e.status = Status.DELIVERED;
        e.deliveredAt = uint40(block.timestamp);
        e.result = result;
        emit Delivered(id, result);
    }

    /// @notice The poster made no decision within the review window: the worker takes the payment.
    function claim(uint256 id) external nonReentrant {
        Errand storage e = _get(id);
        if (!_isWorker(e)) revert NotWorker();
        if (e.status != Status.DELIVERED) revert WrongStatus();
        if (block.timestamp < uint256(e.deliveredAt) + e.reviewWindow) revert TooEarly();
        _settlePaid(id, e, true);
    }

    // ------------------------------------------------------------------ payments

    /// @notice Collect a payment that could not be pushed to you.
    function withdraw() external {
        withdrawTo(payable(msg.sender));
    }

    /// @notice Collect a payment owed to you, sent to another address (for a wallet that cannot receive BNB itself).
    function withdrawTo(address payable to) public nonReentrant {
        uint256 amount = owed[msg.sender];
        if (amount == 0) revert NothingOwed();
        owed[msg.sender] = 0;
        emit Withdrawn(to, amount);
        (bool ok,) = to.call{value: amount}("");
        require(ok, "withdraw failed");
    }

    // ------------------------------------------------------------------ internal

    function _identity(address who) internal view returns (address id) {
        id = shield.identityOf(who);
        if (id == address(0)) revert NotAgent();
    }

    /// The poster is the identity that posted, or the wallet that funded it. The second clause means an errand
    /// can always be cancelled or refunded even if the poster's Agent ID were ever lost.
    function _isPoster(Errand storage e) internal view returns (bool) {
        return msg.sender == e.funder || shield.identityOf(msg.sender) == e.poster;
    }

    /// The worker is the identity that took it, or the wallet that took it (the payee).
    function _isWorker(Errand storage e) internal view returns (bool) {
        if (e.worker == address(0)) return false;
        return msg.sender == e.payee || shield.identityOf(msg.sender) == e.worker;
    }

    function _get(uint256 id) internal view returns (Errand storage) {
        if (id >= _errands.length) revert UnknownErrand();
        return _errands[id];
    }

    function _settlePaid(uint256 id, Errand storage e, bool claimed) internal {
        e.status = Status.PAID;
        records[e.worker].completedAsWorker += 1;
        records[e.poster].paidAsPoster += 1;
        emit Paid(id, e.worker, e.payee, e.reward, claimed);
        _pay(e.payee, e.reward);
    }

    /// Push the payment; if the recipient refuses it, credit it instead so one bad address can't block anything.
    /// Every caller has already moved the errand to a final status, and holds the reentrancy lock.
    function _pay(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount, gas: 30_000}("");
        if (!ok) owed[to] += amount;
    }
}
