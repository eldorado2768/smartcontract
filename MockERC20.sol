// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// This is a simple mock ERC20 token for testing purposes.
// It includes a mint function to easily get tokens in the Remix VM.
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint some initial tokens to the deployer for easy testing
        _mint(msg.sender, 1_000_000 * 10**decimals()); // Mints 1,000,000 tokens
    }

    // Function to mint new tokens to a specified address
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}