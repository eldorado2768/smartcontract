// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDex} from "./IDex.sol"; // Import the IDex interface

contract FlashLoanArbitrageTest {
    using SafeERC20 for IERC20;

    // Address of the mock DEX contract, now using the IDex interface
    IDex public immutable dex; 

    // Arbitrage profit threshold (e.g., 0.01% profit)
    uint256 public constant PROFIT_THRESHOLD = 100; // Represents 0.01% (100 basis points) for 10,000 basis points total

    // Constants for DAI and USDC token addresses (PLACEHOLDERS - YOU'LL UPDATE THESE AFTER DEPLOYING MOCK TOKENS)
    address public constant DAI_ADDRESS = 0x0000000000000000000000000000000000000000; // Placeholder for Mock DAI
    address public constant USDC_ADDRESS = 0x0000000000000000000000000000000000000000; // Placeholder for Mock USDC

    // Event to log arbitrage results
    event ArbitrageExecuted(
        address indexed assetBorrowed,
        uint256 amountBorrowed,
        uint256 initialBalance,
        uint256 finalBalance,
        int256 profit
    );

    // Constructor to initialize the DEX contract address
    constructor(address _dex) {
        // Ensure the DEX address is not zero
        require(_dex != address(0), "FLA: Zero DEX address");
        dex = IDex(_dex); 
        // These checks will be valid once you update the constants after mock token deployment
        // require(DAI_ADDRESS != address(0), "FLA: Zero DAI address constant");
        // require(USDC_ADDRESS != address(0), "FLA: Zero USDC address constant");
    }

    /**
     * @notice Simulates a flash loan and executes the arbitrage logic.
     * This function is for testing purposes only and does not involve
     * an actual flash loan from Aave. It directly provides the
     * loaned amount and asset to trigger the arbitrage flow.
     * @param _loanedAsset The address of the token that is 'flash loaned'.
     * @param _loanedAmount The amount of the token that is 'flash loaned'.
     * @return bool True if the arbitrage was profitable and executed, false otherwise.
     */
    function testArbitrage(address _loanedAsset, uint256 _loanedAmount) external returns (bool) {
        require(_loanedAsset != address(0), "FLA: Zero loaned asset");
        require(_loanedAmount > 0, "FLA: Zero loaned amount");

        // Simulate receiving the flash loaned amount
        // For testing, we assume the contract already holds this amount.
        // In a real flash loan, Aave would transfer tokens here.

        // Get initial balance of the loaned asset in this contract
        uint256 initialBalance = IERC20(_loanedAsset).balanceOf(address(this));
        require(initialBalance >= _loanedAmount, "FLA: Insufficient balance for simulated loan");

        // Determine which pair to trade (DAI/USDC or USDC/DAI)
        // This is a simplified example. A real bot would check multiple DEXes and pairs.
        if (_loanedAsset == DAI_ADDRESS) {
            // Scenario 1: Borrowed DAI, try to arbitrage DAI/USDC
            // Buy USDC with DAI, then sell USDC for DAI
            uint256 amountOutFromBuy = dex.buyToken(DAI_ADDRESS, USDC_ADDRESS, _loanedAmount);
            require(amountOutFromBuy > 0, "FLA: Buy operation failed or yielded zero");

            // Approve DEX to spend the received USDC
            IERC20(USDC_ADDRESS).approve(address(dex), amountOutFromBuy);

            uint256 finalAmountOfTokenA = dex.sellToken(USDC_ADDRESS, DAI_ADDRESS, amountOutFromBuy);
            require(finalAmountOfTokenA > 0, "FLA: Sell operation failed or yielded zero");

            return _checkProfitAndEmit(DAI_ADDRESS, _loanedAmount, finalAmountOfTokenA);

        } else if (_loanedAsset == USDC_ADDRESS) {
            // Scenario 2: Borrowed USDC, try to arbitrage USDC/DAI
            // Buy DAI with USDC, then sell DAI for USDC
            uint256 amountOutFromBuy = dex.buyToken(USDC_ADDRESS, DAI_ADDRESS, _loanedAmount);
            require(amountOutFromBuy > 0, "FLA: Buy operation failed or yielded zero");

            // Approve DEX to spend the received DAI
            IERC20(DAI_ADDRESS).approve(address(dex), amountOutFromBuy);

            uint256 finalAmountOfTokenA = dex.sellToken(DAI_ADDRESS, USDC_ADDRESS, amountOutFromBuy);
            require(finalAmountOfTokenA > 0, "FLA: Sell operation failed or yielded zero");

            return _checkProfitAndEmit(USDC_ADDRESS, _loanedAmount, finalAmountOfTokenA);

        } else {
            revert("FLA: Unexpected flash loan asset for arbitrage");
        }
    }

    /**
     * @notice Internal function to calculate profit and emit event.
     * @param _assetBorrowed The address of the token that was borrowed.
     * @param _amountBorrowed The initial amount borrowed.
     * @param _finalAmountOfAsset The final amount of the borrowed asset after trades.
     * @return bool True if profitable, false otherwise.
     */
    function _checkProfitAndEmit(
        address _assetBorrowed,
        uint256 _amountBorrowed,
        uint256 _finalAmountOfAsset
    ) internal returns (bool) {
        // For simplicity in testing, let's assume a fixed fee percentage for now, e.g., 0.09%
        // Aave V3 flash loan fee is 0.09% = 9 basis points (0.0009)
        // Fee = amountBorrowed * 9 / 10000
        uint256 flashLoanFee = (_amountBorrowed * 9) / 10000;
        uint256 amountToRepay = _amountBorrowed + flashLoanFee;

        int256 profit = int256(_finalAmountOfAsset) - int256(amountToRepay);

        // Check for profitability against a threshold
        // (finalAmountOfTokenA * 10000) > (amountToRepay * (10000 + PROFIT_THRESHOLD))
        bool isProfitable = (_finalAmountOfAsset * 10000) > (amountToRepay * (10000 + PROFIT_THRESHOLD));

        // Emit event with results
        emit ArbitrageExecuted(
            _assetBorrowed,
            _amountBorrowed,
            _amountBorrowed, // Initial balance of loaned asset in contract (simulated)
            _finalAmountOfAsset, // Final balance of loaned asset in contract
            profit
        );

        return isProfitable;
    }

    /**
     * @notice Allows the owner to withdraw any ERC20 tokens from the contract.
     * Useful for funding the contract for testing or withdrawing profits.
     * @param _tokenAddress The address of the ERC20 token to withdraw.
     */
    function withdrawToken(address _tokenAddress) external {
        // In a real scenario, you'd add an `onlyOwner` modifier here.
        // For testing, we'll keep it simple to allow easy funding/withdrawal.
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    // Fallback function to receive ETH (if needed for gas, though not for flash loan itself)
    receive() external payable {}
}
