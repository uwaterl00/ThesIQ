// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {WrappedAsset} from "./WrappedAsset.sol";

error AssetFactory__InvalidAddress();
error AssetFactory__AssetAlreadyExists();
error AssetFactory__AssetNotFound();

contract AssetFactory is Ownable2Step, Pausable {
    mapping(string => address) public wrappedAssets;
    string[] public assetSymbols;

    event AssetCreated(string indexed ibkrSymbol, address indexed tokenAddress, string name, string assetClass);
    event AssetRemoved(string indexed ibkrSymbol, address indexed tokenAddress);

    constructor(address _owner) Ownable(_owner) {}

    function createWrappedAsset(
        string calldata _name,
        string calldata _symbol,
        string calldata _ibkrSymbol,
        string calldata _assetClass,
        address _minter
    ) external onlyOwner whenNotPaused returns (address) {
        if (wrappedAssets[_ibkrSymbol] != address(0)) revert AssetFactory__AssetAlreadyExists();
        if (_minter == address(0)) revert AssetFactory__InvalidAddress();

        WrappedAsset asset = new WrappedAsset(
            _name,
            _symbol,
            _ibkrSymbol,
            _assetClass,
            msg.sender,
            _minter
        );

        address assetAddr = address(asset);
        wrappedAssets[_ibkrSymbol] = assetAddr;
        assetSymbols.push(_ibkrSymbol);

        emit AssetCreated(_ibkrSymbol, assetAddr, _name, _assetClass);
        return assetAddr;
    }

    function getAsset(string calldata _ibkrSymbol) external view returns (address) {
        address asset = wrappedAssets[_ibkrSymbol];
        if (asset == address(0)) revert AssetFactory__AssetNotFound();
        return asset;
    }

    function getAssetCount() external view returns (uint256) {
        return assetSymbols.length;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}