// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

error ThesisEngine__InvalidThesisId();
error ThesisEngine__ThesisNotActive();
error ThesisEngine__NotThesisOwner();
error ThesisEngine__EmptyTicker();
error ThesisEngine__InvalidTimeframe();
error ThesisEngine__MaxTickersExceeded();

contract ThesisEngine is Ownable2Step, ReentrancyGuard, Pausable {
    uint256 public constant MAX_TICKERS_PER_THESIS = 20;

    enum ThesisDirection { LONG, SHORT, NEUTRAL }
    enum ThesisStatus { ACTIVE, CLOSED, INVALIDATED }

    struct DCFParams {
        uint256 discountRateBps;
        uint256 terminalGrowthBps;
        uint256 projectionYears;
        uint256 computedFairValueUSD;
        uint256 currentPriceUSD;
        uint256 marginOfSafetyBps;
    }

    struct Thesis {
        uint256 id;
        address trader;
        string[] tickers;
        ThesisDirection direction;
        ThesisStatus status;
        uint256 entryPriceUSD;
        uint256 targetPriceUSD;
        uint256 stopLossUSD;
        uint256 holdPeriodDays;
        uint256 convictionScore;
        bytes32 catalystHash;
        DCFParams dcf;
        uint256 createdAt;
        uint256 closedAt;
        string closingNotes;
    }

    uint256 private _nextThesisId;
    mapping(uint256 => Thesis) public theses;
    mapping(address => uint256[]) public traderTheses;

    event ThesisCreated(
        uint256 indexed thesisId,
        address indexed trader,
        ThesisDirection direction,
        uint256 convictionScore
    );
    event ThesisClosed(uint256 indexed thesisId, ThesisStatus status, string notes);
    event DCFUpdated(uint256 indexed thesisId, uint256 fairValue, uint256 marginOfSafety);
    event ConvictionUpdated(uint256 indexed thesisId, uint256 oldScore, uint256 newScore);

    constructor(address _owner) Ownable(_owner) {}

    function createThesis(
        string[] memory _tickers,
        ThesisDirection _direction,
        uint256 _entryPriceUSD,
        uint256 _targetPriceUSD,
        uint256 _stopLossUSD,
        uint256 _holdPeriodDays,
        uint256 _convictionScore,
        bytes32 _catalystHash,
        DCFParams calldata _dcf
    ) external nonReentrant whenNotPaused returns (uint256 thesisId) {
        if (_tickers.length == 0) revert ThesisEngine__EmptyTicker();
        if (_tickers.length > MAX_TICKERS_PER_THESIS) revert ThesisEngine__MaxTickersExceeded();
        if (_holdPeriodDays == 0 || _holdPeriodDays > 56) revert ThesisEngine__InvalidTimeframe();

        thesisId = _nextThesisId++;

        Thesis storage t = theses[thesisId];
        t.id = thesisId;
        t.trader = msg.sender;
        t.tickers = _tickers;
        t.direction = _direction;
        t.status = ThesisStatus.ACTIVE;
        t.entryPriceUSD = _entryPriceUSD;
        t.targetPriceUSD = _targetPriceUSD;
        t.stopLossUSD = _stopLossUSD;
        t.holdPeriodDays = _holdPeriodDays;
        t.convictionScore = _convictionScore;
        t.catalystHash = _catalystHash;
        t.dcf = _dcf;
        t.createdAt = block.timestamp;

        traderTheses[msg.sender].push(thesisId);

        emit ThesisCreated(thesisId, msg.sender, _direction, _convictionScore);
    }

    function closeThesis(uint256 _thesisId, ThesisStatus _status, string calldata _notes) external nonReentrant {
        Thesis storage t = theses[_thesisId];
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        t.status = _status;
        t.closedAt = block.timestamp;
        t.closingNotes = _notes;

        emit ThesisClosed(_thesisId, _status, _notes);
    }

    function updateDCF(uint256 _thesisId, DCFParams calldata _dcf) external {
        Thesis storage t = theses[_thesisId];
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        t.dcf = _dcf;
        emit DCFUpdated(_thesisId, _dcf.computedFairValueUSD, _dcf.marginOfSafetyBps);
    }

    function updateConviction(uint256 _thesisId, uint256 _newScore) external {
        Thesis storage t = theses[_thesisId];
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        uint256 oldScore = t.convictionScore;
        t.convictionScore = _newScore;
        emit ConvictionUpdated(_thesisId, oldScore, _newScore);
    }

    function getTraderThesisCount(address _trader) external view returns (uint256) {
        return traderTheses[_trader].length;
    }

    function getTraderThesisIds(address _trader) external view returns (uint256[] memory) {
        return traderTheses[_trader];
    }

    function getThesisTickers(uint256 _thesisId) external view returns (string[] memory) {
        return theses[_thesisId].tickers;
    }

    function getThesisDCF(uint256 _thesisId) external view returns (DCFParams memory) {
        return theses[_thesisId].dcf;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}