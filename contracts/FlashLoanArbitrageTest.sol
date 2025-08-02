// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "./Dex.sol";
import "./MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FlashLoanArbitrageTest {
    using SafeERC20 for IERC20;

    Dex public dex;
    MockERC20 public dai;
    MockERC20 public usdc;

    constructor(address payable _dex, address _dai, address _usdc) {
        dex = Dex(_dex);
        dai = MockERC20(_dai);
        usdc = MockERC20(_usdc);
    }

    event ArbitrageExecuted(
        address indexed loanedAsset,
        uint256 loanedAmount,
        uint256 finalBalance,
        uint256 received,
        int256 profit
    );

    function testArbitrage(address _loanedAsset, uint256 _loanedAmount) public returns (bool) {
        uint256 startBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        dex.flashLoan(_loanedAsset, _loanedAmount, address(this));

        uint256 finalBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        int256 profit = int256(finalBalance) - int256(startBalance);

        emit ArbitrageExecuted(
            _loanedAsset,
            _loanedAmount,
            finalBalance,
            0,
            profit
        );

        return profit > 0;
    }

    function executeFlashLoan(address _loanedAsset, uint256 _loanedAmount) external {
        require(msg.sender == address(dex), "Only Dex can call this");
        
        address loanedToken;
        
        if (_loanedAsset == address(dai)) {
            loanedToken = address(dai);
        } else if (_loanedAsset == address(usdc)) {
            loanedToken = address(usdc);
        } else {
            revert("Unsupported token for flash loan");
        }
        
        // --- Arbitrage logic starts here ---
        
        // Approve the Dex to spend the borrowed token
        IERC20(loanedToken).safeApprove(address(dex), _loanedAmount);

        // Step 1: Swap the loaned token for the other token
        uint256 amountOut1 = dex.swap(loanedToken, address(usdc), _loanedAmount);
        
        // Step 2: Approve the Dex to spend the USDC we just received
        usdc.safeApprove(address(dex), amountOut1);

        // Step 3: Swap the received token back to the original loaned token.
        dex.swap(address(usdc), loanedToken, amountOut1);
        
        // --- Arbitrage logic ends here ---
        
        // Repay the loan plus the fee
        uint256 repaymentAmount = _loanedAmount + (_loanedAmount * dex.SWAP_FEE() / 10000);

        // The remaining balance is the profit which stays in the contract
        IERC20(loanedToken).safeTransfer(msg.sender, repaymentAmount);
    }
}
