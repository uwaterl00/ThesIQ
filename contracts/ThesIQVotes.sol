// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ThesIQVotes is ERC20, ERC20Burnable, ERC20Votes, ERC20Permit, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    
    mapping(address => bool) public minters;
    
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    
    modifier onlyMinter() {
        require(minters[msg.sender], "ThesIQVotes: caller is not a minter");
        _;
    }
    
    constructor(address initialOwner) ERC20("ThesIQ Votes", "vIQ") ERC20Permit("ThesIQ Votes") Ownable(initialOwner) {
        require(initialOwner != address(0), "ThesIQVotes: invalid initial owner");
        minters[initialOwner] = true;
    }
    
    function mint(address to, uint256 amount) public onlyMinter {
        require(to != address(0), "ThesIQVotes: cannot mint to zero address");
        require(totalSupply() + amount <= MAX_SUPPLY, "ThesIQVotes: exceeds max supply");
        _mint(to, amount);
    }
    
    function addMinter(address account) public onlyOwner {
        require(account != address(0), "ThesIQVotes: invalid address");
        minters[account] = true;
        emit MinterAdded(account);
    }
    
    function removeMinter(address account) public onlyOwner {
        minters[account] = false;
        emit MinterRemoved(account);
    }
    
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, amount);
    }
    
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}