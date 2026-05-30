// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ThesisEngine} from "./ThesisEngine.sol";

error SolutionFitTest__InvalidAddress();
error SolutionFitTest__TestNotFound();
error SolutionFitTest__AlreadyCommitted();
error SolutionFitTest__TestExpired();
error SolutionFitTest__MaxTestsReached();
error SolutionFitTest__NotParticipant();

contract SolutionFitTest is Ownable2Step, ReentrancyGuard {
    uint256 public constant MAX_TESTS = 3;

    enum CommitmentLevel { NONE, INTERESTED, TIME_COMMITTED, PORTFOLIO_COMMITTED, FULL_PILOT }

    struct TestParticipant {
        address trader;
        uint256 thesisId;
        CommitmentLevel commitment;
        uint256 convictionBefore;
        uint256 convictionAfter;
        bool researchFrustrationResolved;
        bool willingToCommitTicker;
        bool willingToCommitTime;
        string feedback;
        uint256 enrolledAt;
        uint256 completedAt;
    }

    ThesisEngine public immutable thesisEngine;
    uint256 public testCount;
    uint256 public testDeadline;
    mapping(uint256 => TestParticipant) public participants;
    mapping(address => bool) public enrolled;

    event ParticipantEnrolled(uint256 indexed testIndex, address indexed trader, uint256 thesisId);
    event ConvictionRecorded(uint256 indexed testIndex, uint256 before_, uint256 after_);
    event CommitmentMade(uint256 indexed testIndex, CommitmentLevel level);
    event FeedbackSubmitted(uint256 indexed testIndex, string feedback);
    event TestCompleted(uint256 indexed testIndex, bool passed);

    constructor(address _owner, address _thesisEngine, uint256 _deadlineDays) Ownable(_owner) {
        if (_thesisEngine == address(0)) revert SolutionFitTest__InvalidAddress();
        thesisEngine = ThesisEngine(_thesisEngine);
        testDeadline = block.timestamp + (_deadlineDays * 1 days);
    }

    function enrollParticipant(uint256 _thesisId) external nonReentrant {
        if (testCount >= MAX_TESTS) revert SolutionFitTest__MaxTestsReached();
        if (block.timestamp > testDeadline) revert SolutionFitTest__TestExpired();

        (,,address thesisTrader,,,,,,,,,,,,) = thesisEngine.theses(_thesisId);
        if (thesisTrader != msg.sender) revert SolutionFitTest__NotParticipant();

        uint256 idx = testCount++;
        TestParticipant storage p = participants[idx];
        p.trader = msg.sender;
        p.thesisId = _thesisId;
        p.commitment = CommitmentLevel.INTERESTED;
        p.enrolledAt = block.timestamp;

        enrolled[msg.sender] = true;

        emit ParticipantEnrolled(idx, msg.sender, _thesisId);
    }

    function recordConviction(uint256 _testIndex, uint256 _before, uint256 _after) external {
        TestParticipant storage p = participants[_testIndex];
        if (p.trader != msg.sender) revert SolutionFitTest__NotParticipant();

        p.convictionBefore = _before;
        p.convictionAfter = _after;

        emit ConvictionRecorded(_testIndex, _before, _after);
    }

    function makeCommitment(
        uint256 _testIndex,
        CommitmentLevel _level,
        bool _researchResolved,
        bool _willingTicker,
        bool _willingTime
    ) external {
        TestParticipant storage p = participants[_testIndex];
        if (p.trader != msg.sender) revert SolutionFitTest__NotParticipant();

        p.commitment = _level;
        p.researchFrustrationResolved = _researchResolved;
        p.willingToCommitTicker = _willingTicker;
        p.willingToCommitTime = _willingTime;

        emit CommitmentMade(_testIndex, _level);
    }

    function submitFeedback(uint256 _testIndex, string calldata _feedback) external {
        TestParticipant storage p = participants[_testIndex];
        if (p.trader != msg.sender) revert SolutionFitTest__NotParticipant();

        p.feedback = _feedback;
        p.completedAt = block.timestamp;

        bool passed = p.commitment >= CommitmentLevel.TIME_COMMITTED
            && p.convictionAfter > p.convictionBefore
            && (p.willingToCommitTicker || p.willingToCommitTime);

        emit FeedbackSubmitted(_testIndex, _feedback);
        emit TestCompleted(_testIndex, passed);
    }

    function getTestResult(uint256 _testIndex) external view returns (
        address trader,
        CommitmentLevel commitment,
        uint256 convictionDelta,
        bool researchResolved,
        bool passed
    ) {
        TestParticipant storage p = participants[_testIndex];
        trader = p.trader;
        commitment = p.commitment;
        convictionDelta = p.convictionAfter > p.convictionBefore ? p.convictionAfter - p.convictionBefore : 0;
        researchResolved = p.researchFrustrationResolved;
        passed = p.commitment >= CommitmentLevel.TIME_COMMITTED
            && p.convictionAfter > p.convictionBefore
            && (p.willingToCommitTicker || p.willingToCommitTime);
    }

    function getOverallResult() external view returns (uint256 totalTests, uint256 passedTests, bool pilotReady) {
        totalTests = testCount;
        for (uint256 i; i < testCount; ++i) {
            TestParticipant storage p = participants[i];
            if (
                p.commitment >= CommitmentLevel.TIME_COMMITTED
                && p.convictionAfter > p.convictionBefore
                && (p.willingToCommitTicker || p.willingToCommitTime)
            ) {
                ++passedTests;
            }
        }
        pilotReady = passedTests >= 2;
    }
}