// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This interface defines the expected public functions of the Dex contract.
// It allows other contracts (like FlashLoanArbitrageTest) to interact with
// a deployed Dex contract by knowing its function signatures, without needing
// the full implementation details.
interface IDex {
    // Functions for adding liquidity (if needed for external calls, though owner-only in Dex)
    // function addLiquidity(address _tokenAddress, uint256 _amount) external;

    // Functions for swapping tokens
    function buyToken(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256);
    function sellToken(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256);

    // Function to get the current price of a token pair
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256);

    // Function to get the balance of a specific token held by this DEX contract
    function getBalance(address _tokenAddress) external view returns (uint256);
}
