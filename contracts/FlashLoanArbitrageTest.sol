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

    // The constructor now uses 'address payable' for the Dex contract's address
    // because Dex.sol likely has a payable fallback or receive function.
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
        // Ensure the contract has enough balance to simulate the flash loan
        uint256 startBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        // This function call assumes your Dex.sol contract has a public 'flashLoan' function
        // with the signature: flashLoan(address _token, uint256 _amount, address _borrower)
        dex.flashLoan(_loanedAsset, _loanedAmount, address(this));

        // After the flash loan and arbitrage, check the final balance
        uint256 finalBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        // The profit is the difference between the final balance and the initial balance
        int256 profit = int256(finalBalance) - int256(startBalance);

        emit ArbitrageExecuted(
            _loanedAsset,
            _loanedAmount,
            finalBalance,
            0, // We are no longer tracking 'received' since the repayment logic is now fully contained within the loan callback.
            profit
        );

        return profit > 0;
    }

    function executeFlashLoan(address _loanedAsset, uint256 _loanedAmount) external {
        require(msg.sender == address(dex), "Only Dex can call this");
        
        uint256 daiAmount;
        uint256 usdcAmount;
        address loanedToken;
        
        if (_loanedAsset == address(dai)) {
            daiAmount = _loanedAmount;
            loanedToken = address(dai);
        } else if (_loanedAsset == address(usdc)) {
            usdcAmount = _loanedAmount;
            loanedToken = address(usdc);
        } else {
            revert("Unsupported token for flash loan");
        }
        
        // --- Arbitrage logic starts here ---
        
        // Step 1: Swap loaned DAI for USDC
        uint256 amountOut1 = dex.swap(loanedToken, address(usdc), _loanedAmount);
        
        // Step 2: Swap the received USDC back to DAI
        uint256 amountOut2 = dex.swap(address(usdc), loanedToken, amountOut1);
        
        // --- Arbitrage logic ends here ---
        
        // Repay the loan plus the fee
        uint256 repaymentAmount = _loanedAmount + (_loanedAmount * dex.SWAP_FEE / 10000);

        // The remaining balance is the profit which stays in the contract
        IERC20(loanedToken).safeTransfer(msg.sender, repaymentAmount);
    }
}
