// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error WrappedAsset__ZeroAmount();
error WrappedAsset__NotMinter();
error WrappedAsset__InvalidAddress();

contract WrappedAsset is ERC20, ERC20Burnable, ERC20Pausable, Ownable2Step, ReentrancyGuard {
    string public ibkrSymbol;
    string public assetClass;
    uint256 public lastPriceUSD;
    uint256 public lastPriceTimestamp;
    address public minter;

    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        if (msg.sender != minter) revert WrappedAsset__NotMinter();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _ibkrSymbol,
        string memory _assetClass,
        address _owner,
        address _minter
    ) ERC20(_name, _symbol) Ownable(_owner) {
        if (_minter == address(0)) revert WrappedAsset__InvalidAddress();
        ibkrSymbol = _ibkrSymbol;
        assetClass = _assetClass;
        minter = _minter;
    }

    function mint(address to, uint256 amount) external nonReentrant onlyMinter {
        if (amount == 0) revert WrappedAsset__ZeroAmount();
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override nonReentrant onlyMinter {
        super.burnFrom(account, amount);
    }

    function updatePrice(uint256 _priceUSD) external onlyMinter {
        lastPriceUSD = _priceUSD;
        lastPriceTimestamp = block.timestamp;
        emit PriceUpdated(_priceUSD, block.timestamp);
    }

    function setMinter(address _newMinter) external onlyOwner {
        if (_newMinter == address(0)) revert WrappedAsset__InvalidAddress();
        address oldMinter = minter;
        minter = _newMinter;
        emit MinterUpdated(oldMinter, _newMinter);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}