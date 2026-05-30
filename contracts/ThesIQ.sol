// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ThesIQ is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    event BurnerAdded(address indexed account);
    event BurnerRemoved(address indexed account);
    
    modifier onlyMinter() {
        require(minters[msg.sender], "ThesIQ: caller is not a minter");
        _;
    }
    
    modifier onlyBurner() {
        require(burners[msg.sender], "ThesIQ: caller is not a burner");
        _;
    }
    
    constructor(address initialOwner) ERC20("ThesIQ", "IQ") ERC20Permit("ThesIQ") Ownable(initialOwner) {
        require(initialOwner != address(0), "ThesIQ: invalid initial owner");
        minters[initialOwner] = true;
        burners[initialOwner] = true;
    }
    
    function mint(address to, uint256 amount) public onlyMinter {
        require(to != address(0), "ThesIQ: cannot mint to zero address");
        require(totalSupply() + amount <= MAX_SUPPLY, "ThesIQ: exceeds max supply");
        _mint(to, amount);
    }
    
    function burn(uint256 amount) public override onlyBurner {
        super.burn(amount);
    }
    
    function burnFrom(address account, uint256 amount) public override onlyBurner {
        super.burnFrom(account, amount);
    }
    
    function addMinter(address account) public onlyOwner {
        require(account != address(0), "ThesIQ: invalid address");
        minters[account] = true;
        emit MinterAdded(account);
    }
    
    function removeMinter(address account) public onlyOwner {
        minters[account] = false;
        emit MinterRemoved(account);
    }
    
    function addBurner(address account) public onlyOwner {
        require(account != address(0), "ThesIQ: invalid address");
        burners[account] = true;
        emit BurnerAdded(account);
    }
    
    function removeBurner(address account) public onlyOwner {
        burners[account] = false;
        emit BurnerRemoved(account);
    }
    
    function isMinter(address account) public view returns (bool) {
        return minters[account];
    }
    
    function isBurner(address account) public view returns (bool) {
        return burners[account];
    }
}