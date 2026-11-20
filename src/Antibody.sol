// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// Agent ID on BNB Chain: one non-transferable ERC-721 per Binance user, held by their agentic wallet.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

interface IOwnable {
    function owner() external view returns (address);
}

/// @title  Antibody
/// @notice A public scam registry for BNB Chain in which every Agent ID holds exactly one vote per target.
///
///         Agentic wallets already simulate every transaction before it is signed. Antibody lets the holder
///         turn what that simulation revealed (a honeypot, a rug, a drainer) into a signed, public report,
///         and lets any wallet, dApp or agent read the result with a free view call before it signs.
///
///         Because an Agent ID cannot be transferred and each user can claim only one, a flood of reports
///         needs a flood of distinct real users, not a flood of fresh addresses.
///
/// @dev    PERMISSIONS: none. There is no owner, admin, pauser, upgrade path, fee, token or withdrawal.
///         The contract holds no funds and cannot move anyone's assets. Every state change is made by the
///         reporting or linking address itself, for itself.
///
///         Counts on-chain are unweighted (one identity, one vote). Reputation weighting, which rewards
///         reporters whose verdicts were later confirmed on-chain, is computed off-chain from the events and
///         is advisory; it is never able to change what is stored here.
contract Antibody {
    enum Verdict {
        NONE, //     no vote / retracted
        SAFE, //     simulated buy and sell both behaved as expected
        HONEYPOT, // buy works, sell reverts or is taxed away
        RUG, //      liquidity pulled, or owner minted / drained supply
        DRAINER, //  takes approvals or assets beyond what the call says
        PHISHING //  impersonates another project or address
    }

    uint256 internal constant VERDICTS = 6;

    IAgentID public immutable agentId;

    struct Vote {
        Verdict verdict;
        uint64 at;
        bytes32 evidence; // sha256 of the evidence document (simulation output, tx hashes, notes)
    }

    /// target => identity => that identity's current vote
    mapping(address => mapping(address => Vote)) public votes;
    /// target => count of current votes per verdict
    mapping(address => uint32[VERDICTS]) internal _tally;

    // ------------------------------------------------------------------ Agent Link
    // An agentic wallet cannot connect to dApps. Agent Link lets the holder name ONE ordinary wallet that
    // acts for the same identity here (and that other contracts may treat as Agent-ID-backed). It takes two
    // signatures, one from each side, and either side can end it. A linked wallet never adds a second vote:
    // votes are keyed by the identity, not by the address that sent them.

    mapping(address => address) public pendingLink; //  identity => wallet offered
    mapping(address => address) public linkedWallet; // identity => wallet
    mapping(address => address) public identityOfWallet; // wallet => identity

    event Reported(
        address indexed target, address indexed identity, Verdict verdict, Verdict previous, bytes32 evidence
    );
    event Responded(address indexed target, address indexed responder, bytes32 evidence);
    event LinkOffered(address indexed identity, address indexed wallet);
    event Linked(address indexed identity, address indexed wallet);
    event Unlinked(address indexed identity, address indexed wallet);

    error NotAgent();
    error BadTarget();
    error BadVerdict();
    error NoVote();
    error BadWallet();
    error NoOffer();
    error NotTargetOwner();
    error NotLinked();

    constructor(IAgentID agentId_) {
        agentId = agentId_;
    }

    // ------------------------------------------------------------------ identity

    function _holds(address a) internal view returns (bool) {
        return agentId.balanceOf(a) > 0;
    }

    /// @notice The Agent ID identity an address acts for: itself if it holds an Agent ID, its linked identity
    ///         if it is a linked wallet whose identity still holds one, otherwise address(0).
    function identityOf(address who) public view returns (address) {
        if (_holds(who)) return who;
        address id = identityOfWallet[who];
        if (id != address(0) && _holds(id)) return id;
        return address(0);
    }

    /// @notice True if `who` is an Agent ID holder or a wallet linked to one. Returns no name, by design.
    function isAgentBacked(address who) external view returns (bool) {
        return identityOf(who) != address(0);
    }

    // ------------------------------------------------------------------ reports

    /// @notice Record (or replace) the caller's identity's verdict on `target`.
    function report(address target, Verdict verdict, bytes32 evidence) external {
        address id = identityOf(msg.sender);
        if (id == address(0)) revert NotAgent();
        if (target == address(0) || target == address(this)) revert BadTarget();
        if (verdict == Verdict.NONE) revert BadVerdict();

        Vote storage v = votes[target][id];
        Verdict prev = v.verdict;
        if (prev != Verdict.NONE) _tally[target][uint8(prev)] -= 1;
        _tally[target][uint8(verdict)] += 1;
        v.verdict = verdict;
        v.at = uint64(block.timestamp);
        v.evidence = evidence;

        emit Reported(target, id, verdict, prev, evidence);
    }

    /// @notice Withdraw the caller's identity's vote on `target`.
    function retract(address target) external {
        address id = identityOf(msg.sender);
        if (id == address(0)) revert NotAgent();
        Vote storage v = votes[target][id];
        Verdict prev = v.verdict;
        if (prev == Verdict.NONE) revert NoVote();
        _tally[target][uint8(prev)] -= 1;
        delete votes[target][id];
        emit Reported(target, id, Verdict.NONE, prev, bytes32(0));
    }

    /// @notice A reported project answers with its own evidence. Only the target's `owner()` may respond, so a
    ///         contract whose ownership was renounced cannot; that is visible to readers and is itself a signal.
    function respond(address target, bytes32 evidence) external {
        // Low-level call: a try/catch would not catch a target with no code or one returning malformed data.
        (bool ok, bytes memory ret) = target.staticcall(abi.encodeCall(IOwnable.owner, ()));
        if (!ok || ret.length != 32 || target.code.length == 0) revert NotTargetOwner();
        address o = abi.decode(ret, (address));
        if (o != msg.sender || o == address(0)) revert NotTargetOwner();
        emit Responded(target, msg.sender, evidence);
    }

    /// @notice Current vote counts for `target`, indexed by `Verdict`, and their total.
    function riskOf(address target) external view returns (uint32[VERDICTS] memory counts, uint32 total) {
        counts = _tally[target];
        for (uint256 i = 1; i < VERDICTS; i++) total += counts[i];
    }

    // ------------------------------------------------------------------ Agent Link

    /// @notice Step 1, sent by the Agent ID holder: offer a link to `wallet`. Replaces any earlier offer.
    function offerLink(address wallet) external {
        if (!_holds(msg.sender)) revert NotAgent();
        if (wallet == address(0) || wallet == msg.sender || _holds(wallet)) revert BadWallet();
        pendingLink[msg.sender] = wallet;
        emit LinkOffered(msg.sender, wallet);
    }

    /// @notice Step 2, sent by the wallet: accept the identity's offer. Replaces the identity's previous link.
    function acceptLink(address identity) external {
        if (pendingLink[identity] != msg.sender) revert NoOffer();
        if (!_holds(identity)) revert NotAgent();
        if (identityOfWallet[msg.sender] != address(0) || _holds(msg.sender)) revert BadWallet();

        address old = linkedWallet[identity];
        if (old != address(0)) {
            delete identityOfWallet[old];
            emit Unlinked(identity, old);
        }
        delete pendingLink[identity];
        linkedWallet[identity] = msg.sender;
        identityOfWallet[msg.sender] = identity;
        emit Linked(identity, msg.sender);
    }

    /// @notice Either side ends the link (and the identity's pending offer, if any).
    function unlink() external {
        address id;
        address wallet;
        if (linkedWallet[msg.sender] != address(0)) {
            id = msg.sender;
            wallet = linkedWallet[msg.sender];
        } else if (identityOfWallet[msg.sender] != address(0)) {
            id = identityOfWallet[msg.sender];
            wallet = msg.sender;
        } else if (pendingLink[msg.sender] != address(0)) {
            delete pendingLink[msg.sender];
            return;
        } else {
            revert NotLinked();
        }
        delete linkedWallet[id];
        delete identityOfWallet[wallet];
        delete pendingLink[id];
        emit Unlinked(id, wallet);
    }
}
