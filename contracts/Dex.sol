// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IFlashLoanBorrower.sol";

contract Dex {
    using SafeERC20 for IERC20;

    uint256 public constant SWAP_FEE = 30; // 0.3% fee
    uint256 public daiReserve;
    uint256 public usdcReserve;
    IERC20 public dai;
    IERC20 public usdc;

    constructor(address _dai, address _usdc) {
        dai = IERC20(_dai);
        usdc = IERC20(_usdc);
    }

    function addLiquidity(uint256 _daiAmount, uint256 _usdcAmount) public {
        dai.safeTransferFrom(msg.sender, address(this), _daiAmount);
        usdc.safeTransferFrom(msg.sender, address(this), _usdcAmount);
        daiReserve += _daiAmount;
        usdcReserve += _usdcAmount;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (daiReserve, usdcReserve);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) public returns (uint256) {
        // Calculate the amount of tokenOut to send
        uint256 amountInWithFee = _amountIn * (10000 - SWAP_FEE);
        uint256 amountOut;

        if (_tokenIn == address(dai)) {
            require(_tokenOut == address(usdc), "Invalid token pair");
            require(daiReserve > 0 && usdcReserve > 0, "Insufficient liquidity");
            amountOut = (amountInWithFee * usdcReserve) / (daiReserve * 10000 + amountInWithFee);
            
            dai.safeTransferFrom(msg.sender, address(this), _amountIn);
            usdc.safeTransfer(msg.sender, amountOut);

            daiReserve += _amountIn;
            usdcReserve -= amountOut;
        } else if (_tokenIn == address(usdc)) {
            require(_tokenOut == address(dai), "Invalid token pair");
            require(daiReserve > 0 && usdcReserve > 0, "Insufficient liquidity");
            amountOut = (amountInWithFee * daiReserve) / (usdcReserve * 10000 + amountInWithFee);
            
            usdc.safeTransferFrom(msg.sender, address(this), _amountIn);
            dai.safeTransfer(msg.sender, amountOut);

            usdcReserve += _amountIn;
            daiReserve -= amountOut;
        } else {
            revert("Unsupported token for swap");
        }

        return amountOut;
    }

    function flashLoan(address _token, uint256 _amount, address _borrower) public {
        IERC20(_token).safeTransfer(_borrower, _amount);
        
        IFlashLoanBorrower borrower = IFlashLoanBorrower(_borrower);
        borrower.executeFlashLoan(_token, _amount);

        uint256 repaymentAmount = _amount + (_amount * SWAP_FEE / 10000);
        
        require(IERC20(_token).balanceOf(address(this)) >= repaymentAmount, "Flash loan repayment failed");
    }

    receive() external payable {}
}
