// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "./Dex.sol";
import "./MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultiDexArbitrage {
    using SafeERC20 for IERC20;

    Dex public dexA;
    Dex public dexB;
    MockERC20 public dai;
    MockERC20 public usdc;

    constructor(address payable _dexA, address payable _dexB, address _dai, address _usdc) {
        dexA = Dex(_dexA);
        dexB = Dex(_dexB);
        dai = MockERC20(_dai);
        usdc = MockERC20(_usdc);
    }

    event ArbitrageExecuted(
        address indexed loanedAsset,
        uint256 loanedAmount,
        uint256 finalBalance,
        int256 profit
    );

    function testArbitrage(address _loanedAsset, uint256 _loanedAmount) public returns (bool) {
        uint256 startBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        // This time we get the flash loan from DexA
        dexA.flashLoan(_loanedAsset, _loanedAmount, address(this));

        uint256 finalBalance = IERC20(_loanedAsset).balanceOf(address(this));
        
        int256 profit = int256(finalBalance) - int256(startBalance);

        emit ArbitrageExecuted(
            _loanedAsset,
            _loanedAmount,
            finalBalance,
            profit
        );

        return profit > 0;
    }

    function executeFlashLoan(address _loanedAsset, uint256 _loanedAmount) external {
        require(msg.sender == address(dexA), "Only DexA can call this");
        
        address loanedToken;
        if (_loanedAsset == address(dai)) {
            loanedToken = address(dai);
        } else if (_loanedAsset == address(usdc)) {
            loanedToken = address(usdc);
        } else {
            revert("Unsupported token for flash loan");
        }
        
        // --- Arbitrage logic using two DEXes ---
        
        // Step 1: Swap borrowed token on DexA
        IERC20(loanedToken).approve(address(dexA), _loanedAmount);
        uint256 amountOut1 = dexA.swap(loanedToken, address(usdc), _loanedAmount);
        
        // Step 2: Swap the received token on DexB
        IERC20(address(usdc)).approve(address(dexB), amountOut1);
        dexB.swap(address(usdc), loanedToken, amountOut1);
        
        // --- End of arbitrage logic ---
        
        // Repay the loan to DexA
        uint256 repaymentAmount = _loanedAmount + (_loanedAmount * dexA.SWAP_FEE() / 10000);
        IERC20(loanedToken).safeTransfer(address(dexA), repaymentAmount);

        // The remaining balance is the profit which stays in the contract
    }
}
