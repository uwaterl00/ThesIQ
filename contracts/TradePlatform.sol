// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WrappedAsset} from "./WrappedAsset.sol";
import {AssetFactory} from "./AssetFactory.sol";
import {ThesisEngine} from "./ThesisEngine.sol";

error TradePlatform__InvalidAddress();
error TradePlatform__InsufficientBalance();
error TradePlatform__AssetNotSupported();
error TradePlatform__TradeNotFound();
error TradePlatform__NotTradeOwner();
error TradePlatform__TradeAlreadyClosed();
error TradePlatform__ZeroAmount();
error TradePlatform__InvalidThesis();

contract TradePlatform is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    enum TradeStatus { OPEN, CLOSED, STOPPED_OUT }

    struct Trade {
        uint256 id;
        address trader;
        address wrappedAsset;
        uint256 thesisId;
        uint256 amount;
        uint256 entryPriceUSD;
        uint256 exitPriceUSD;
        TradeStatus status;
        uint256 openedAt;
        uint256 closedAt;
    }

    AssetFactory public immutable assetFactory;
    ThesisEngine public immutable thesisEngine;

    uint256 private _nextTradeId;
    mapping(uint256 => Trade) public trades;
    mapping(address => uint256[]) public traderTrades;
    mapping(address => bool) public supportedAssets;

    event TradeOpened(
        uint256 indexed tradeId,
        address indexed trader,
        address indexed wrappedAsset,
        uint256 thesisId,
        uint256 amount,
        uint256 entryPrice
    );
    event TradeClosed(uint256 indexed tradeId, uint256 exitPrice, TradeStatus status);
    event AssetSupported(address indexed asset, bool supported);

    constructor(
        address _owner,
        address _assetFactory,
        address _thesisEngine
    ) Ownable(_owner) {
        if (_assetFactory == address(0) || _thesisEngine == address(0)) revert TradePlatform__InvalidAddress();
        assetFactory = AssetFactory(_assetFactory);
        thesisEngine = ThesisEngine(_thesisEngine);
    }

    function openTrade(
        address _wrappedAsset,
        uint256 _thesisId,
        uint256 _amount,
        uint256 _entryPriceUSD
    ) external nonReentrant whenNotPaused returns (uint256 tradeId) {
        if (!supportedAssets[_wrappedAsset]) revert TradePlatform__AssetNotSupported();
        if (_amount == 0) revert TradePlatform__ZeroAmount();

        (,address thesisTrader,,,,,,,,,,,,) = thesisEngine.theses(_thesisId);
        if (thesisTrader != msg.sender) revert TradePlatform__InvalidThesis();

        IERC20(_wrappedAsset).safeTransferFrom(msg.sender, address(this), _amount);

        tradeId = _nextTradeId++;
        Trade storage t = trades[tradeId];
        t.id = tradeId;
        t.trader = msg.sender;
        t.wrappedAsset = _wrappedAsset;
        t.thesisId = _thesisId;
        t.amount = _amount;
        t.entryPriceUSD = _entryPriceUSD;
        t.status = TradeStatus.OPEN;
        t.openedAt = block.timestamp;

        traderTrades[msg.sender].push(tradeId);

        emit TradeOpened(tradeId, msg.sender, _wrappedAsset, _thesisId, _amount, _entryPriceUSD);
    }

    function closeTrade(uint256 _tradeId, uint256 _exitPriceUSD) external nonReentrant {
        Trade storage t = trades[_tradeId];
        if (t.trader != msg.sender) revert TradePlatform__NotTradeOwner();
        if (t.status != TradeStatus.OPEN) revert TradePlatform__TradeAlreadyClosed();

        t.exitPriceUSD = _exitPriceUSD;
        t.status = TradeStatus.CLOSED;
        t.closedAt = block.timestamp;

        IERC20(t.wrappedAsset).safeTransfer(msg.sender, t.amount);

        emit TradeClosed(_tradeId, _exitPriceUSD, TradeStatus.CLOSED);
    }

    function setSupportedAsset(address _asset, bool _supported) external onlyOwner {
        if (_asset == address(0)) revert TradePlatform__InvalidAddress();
        supportedAssets[_asset] = _supported;
        emit AssetSupported(_asset, _supported);
    }

    function getTraderTradeIds(address _trader) external view returns (uint256[] memory) {
        return traderTrades[_trader];
    }

    function getTraderTradeCount(address _trader) external view returns (uint256) {
        return traderTrades[_trader].length;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}